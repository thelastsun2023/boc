part of 'server.dart';

Future<bool> _isMallTask(int id) async {
  final rows = await _conn.execute(
      'SELECT 1 FROM todo_tasks WHERE id=\$1 AND mall_order_id IS NOT NULL',
      parameters: [id]);
  return rows.isNotEmpty;
}

Future<void> _initMall() async {
  for (final sql in [
    '''ALTER TABLE users ADD COLUMN IF NOT EXISTS mall_enabled BOOLEAN NOT NULL DEFAULT FALSE''',
    '''CREATE TABLE IF NOT EXISTS mall_sessions (token_hash TEXT PRIMARY KEY, username TEXT NOT NULL, expires_at TIMESTAMP NOT NULL)''',
    '''ALTER TABLE raw_materials ADD COLUMN IF NOT EXISTS mall_out_of_stock BOOLEAN NOT NULL DEFAULT FALSE''',
    '''CREATE TABLE IF NOT EXISTS mall_orders (
      id SERIAL PRIMARY KEY, owner_username TEXT NOT NULL, store_code TEXT NOT NULL,
      store_name TEXT NOT NULL, submission_key TEXT NOT NULL, created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
      UNIQUE(owner_username, submission_key))''',
    '''CREATE TABLE IF NOT EXISTS mall_order_items (
      id SERIAL PRIMARY KEY, order_id INTEGER NOT NULL REFERENCES mall_orders(id) ON DELETE CASCADE,
      product_code TEXT NOT NULL, name TEXT NOT NULL, specification TEXT NOT NULL,
      quantity NUMERIC(12,2) NOT NULL CHECK(quantity > 0), purchased BOOLEAN NOT NULL DEFAULT FALSE,
      out_of_stock BOOLEAN NOT NULL DEFAULT FALSE, CHECK(NOT(purchased AND out_of_stock)))''',
    '''ALTER TABLE mall_order_items ADD COLUMN IF NOT EXISTS name_en TEXT NOT NULL DEFAULT '' ''',
    '''ALTER TABLE todo_tasks ADD COLUMN IF NOT EXISTS mall_order_id INTEGER REFERENCES mall_orders(id)''',
    '''CREATE UNIQUE INDEX IF NOT EXISTS mall_task_order_unique ON todo_tasks(mall_order_id) WHERE mall_order_id IS NOT NULL''',
    '''CREATE INDEX IF NOT EXISTS mall_order_owner ON mall_orders(owner_username)''',
    '''CREATE INDEX IF NOT EXISTS mall_item_order ON mall_order_items(order_id)''',
  ]) {
    await _conn.execute(sql);
  }
}

Future<String> _issueMallToken(String username) async {
  final random = Random.secure();
  final token = base64Url.encode(List.generate(32, (_) => random.nextInt(256)));
  await _conn.execute(
      'INSERT INTO mall_sessions VALUES(\$1,\$2,CURRENT_TIMESTAMP + INTERVAL \'7 days\')',
      parameters: [sha256.convert(utf8.encode(token)).toString(), username]);
  return token;
}

class _MallError implements Exception {
  final int status;
  final String message;
  _MallError(this.status, this.message);
}

Response _mallJson(Object data, [int status = 200]) => Response(status,
    body: jsonEncode(data), headers: {'Content-Type': 'application/json'});
Future<Response> _mallCall(Request request,
    Future<Response> Function(_UserScope, Map<String, dynamic>) action) async {
  try {
    final auth = request.headers['authorization'] ?? '';
    if (!auth.startsWith('Bearer ')) throw _MallError(401, '请重新登录');
    final rows = await _conn.execute(
        'SELECT username FROM mall_sessions WHERE token_hash=\$1 AND expires_at>CURRENT_TIMESTAMP',
        parameters: [
          sha256.convert(utf8.encode(auth.substring(7))).toString()
        ]);
    if (rows.isEmpty) throw _MallError(401, '登录已过期，请重新登录');
    final scope = await _getUserScopeByUsername(rows.first[0] as String);
    if (scope == null) throw _MallError(401, '用户不存在');
    if (!scope.isAdmin) {
      final permissions = await _conn.execute(
          'SELECT mall_enabled FROM users WHERE LOWER(username)=LOWER(\$1)',
          parameters: [scope.username]);
      if (permissions.isEmpty || permissions.first[0] != true)
        throw _MallError(403, '未开通商城与采购权限，请联系 ADMIN');
    }
    if (!scope.isAdmin &&
        (scope.storeCode == null || !await _storeExists(scope.storeCode!)))
      throw _MallError(403, '用户必须归属有效门店，请联系 ADMIN');
    final data = request.method == 'GET'
        ? <String, dynamic>{}
        : jsonDecode(await request.readAsString()) as Map<String, dynamic>;
    return await action(scope, data);
  } on _MallError catch (e) {
    return _mallJson({'error': e.message}, e.status);
  } on FormatException {
    return _mallJson({'error': '请求格式无效'}, 400);
  } on TypeError {
    return _mallJson({'error': '请求字段类型无效'}, 400);
  } catch (e, st) {
    stderr.writeln('Mall request failed: $e\n$st');
    return _mallJson({'error': '保存失败，请稍后重试'}, 500);
  }
}

void _mallAdmin(_UserScope scope) {
  if (!scope.isAdmin) throw _MallError(403, '只有 ADMIN 可以修改采购和缺货状态');
}

Future<Response> _mallProducts(Request request) =>
    _mallCall(request, (scope, data) async {
      final rows = await _conn.execute(
          '''SELECT r.code,r.name_cn,r.name_en,COALESCE(r.specification,''),r.category_code,
    COALESCE(c.name,'未分类'),r.image_path,r.mall_out_of_stock,r.notes_rich
    FROM raw_materials r LEFT JOIN raw_material_categories c ON c.code=r.category_code
    ${scope.isAdmin ? '' : 'WHERE NOT EXISTS(SELECT 1 FROM raw_material_hidden_stores h WHERE h.material_code=r.code AND h.store_code=\$1)'}
    ORDER BY c.name,r.name_cn''',
          parameters: scope.isAdmin ? [] : [scope.storeCode]);
      final products = rows
          .map((r) => {
                'code': r[0],
                'name': r[1],
                'nameEN': r[2],
                'specification': r[3],
                'categoryCode': r[4],
                'categoryName': r[5],
                'imagePath': _imageUrlFromPath(r[6] as String?),
                'outOfStock': false,
                'notesRich': r[8]
              })
          .toList();
      return _mallJson({'products': products});
    });

Future<Response> _mallCreateOrder(Request request) =>
    _mallCall(request, (scope, data) async {
      final store = scope.isAdmin
          ? _normalizedStoreCode(data['storeCode'])
          : scope.storeCode;
      if (store == null) throw _MallError(400, '请选择门店');
      final items = data['items'];
      final key = data['submissionKey'];
      if (items is! List ||
          items.isEmpty ||
          items.length > 200 ||
          key is! String ||
          key.isEmpty ||
          key.length > 100) throw _MallError(400, '购物车为空或提交标识无效');
      final codes = <String>{};
      for (final item in items) {
        if (item is! Map ||
            item['code'] is! String ||
            !codes.add(item['code'] as String))
          throw _MallError(400, '商品无效或重复');
        final q = item['quantity'];
        if (q is! num ||
            !q.isFinite ||
            q <= 0 ||
            q > 1000000 ||
            (q * 100 - (q * 100).round()).abs() > 0.00001)
          throw _MallError(400, '数量须大于 0，最多两位小数');
      }
      final id = await _conn.runTx((tx) async {
        final stores = await tx.execute(
            'SELECT name FROM stores WHERE code=\$1 FOR SHARE',
            parameters: [store]);
        if (stores.isEmpty) throw _MallError(400, '门店不存在');
        final inserted = await tx.execute(
            '''INSERT INTO mall_orders(owner_username,store_code,store_name,submission_key)
      VALUES(\$1,\$2,\$3,\$4) ON CONFLICT(owner_username,submission_key) DO NOTHING RETURNING id''',
            parameters: [scope.username, store, stores.first[0], key]);
        if (inserted.isEmpty) {
          final existing = await tx.execute(
              'SELECT id FROM mall_orders WHERE owner_username=\$1 AND submission_key=\$2',
              parameters: [scope.username, key]);
          return existing.first[0] as int;
        }
        final orderId = inserted.first[0] as int;
        final lines = <String>[];
        for (final item in items) {
          final hidden = await tx.execute(
              'SELECT 1 FROM raw_material_hidden_stores WHERE material_code=\$1 AND store_code=\$2',
              parameters: [item['code'], store]);
          if (hidden.isNotEmpty) throw _MallError(403, '该商品不在此门店的商城中显示，请刷新');
          final rows = await tx.execute(
              'SELECT name_cn,COALESCE(specification,\'\'),COALESCE(name_en,\'\') FROM raw_materials WHERE code=\$1 FOR SHARE',
              parameters: [item['code']]);
          if (rows.isEmpty) throw _MallError(400, '商品已删除，请刷新购物车');
          await tx.execute(
              'INSERT INTO mall_order_items(order_id,product_code,name,specification,quantity,name_en) VALUES(\$1,\$2,\$3,\$4,\$5,\$6)',
              parameters: [
                orderId,
                item['code'],
                rows.first[0],
                rows.first[1],
                item['quantity'],
                rows.first[2]
              ]);
          lines.add(
              '${rows.first[0]} / ${rows.first[2]} ${rows.first[1]} × ${item['quantity']}');
        }
        await tx
            .execute('''INSERT INTO todo_tasks(title,content,due_date_time,status,owner_username,store_code,task_type,mall_order_id)
      VALUES(\$1,\$2,CURRENT_TIMESTAMP,'未做完','admin',\$3,'MALL_ORDER',\$4)''',
                parameters: [
              '商城采购订单 #$orderId · ${stores.first[0]}',
              lines.join('\n'),
              store,
              orderId
            ]);
        return orderId;
      });
      return _mallJson({'success': true, 'id': id});
    });

Future<Response> _mallOrders(Request request) =>
    _mallCall(request, (scope, data) async {
      final rows = await _conn.execute(
          '''SELECT id,owner_username,store_code,store_name,created_at::text FROM mall_orders
    ${scope.isAdmin ? '' : 'WHERE LOWER(owner_username)=LOWER(\$1)'} ORDER BY id DESC''',
          parameters: scope.isAdmin ? [] : [scope.username]);
      final orders = <Map<String, dynamic>>[];
      for (final r in rows) {
        final items = await _conn.execute(
            'SELECT id,product_code,name,specification,quantity::text,purchased,out_of_stock,name_en FROM mall_order_items WHERE order_id=\$1 ORDER BY id',
            parameters: [r[0]]);
        final lines = items
            .map((i) => {
                  'id': i[0],
                  'code': i[1],
                  'name': i[2],
                  'specification': i[3],
                  'quantity': i[4],
                  'purchased': i[5],
                  'outOfStock': i[6],
                  'nameEN': i[7]
                })
            .toList();
        final status = lines.every((x) => x['purchased'] == true)
            ? '已采购完成'
            : lines.any((x) => x['outOfStock'] == true)
                ? '有缺货'
                : '待采购';
        orders.add({
          'id': r[0],
          'username': r[1],
          'storeCode': r[2],
          'storeName': r[3],
          'createdAt': r[4],
          'status': status,
          'items': lines
        });
      }
      return _mallJson({'orders': orders});
    });

Future<Response> _mallUpdateItem(Request request, String id, String itemId) =>
    _mallCall(request, (scope, data) async {
      _mallAdmin(scope);
      if (int.tryParse(id) == null ||
          int.tryParse(itemId) == null ||
          data['purchased'] is! bool ||
          data['outOfStock'] is! bool ||
          (data['purchased'] == true && data['outOfStock'] == true))
        throw _MallError(400, '采购完成与缺货不能同时勾选');
      await _conn.runTx((tx) async {
        final order = await tx.execute(
            'SELECT id FROM mall_orders WHERE id=\$1 FOR UPDATE',
            parameters: [int.parse(id)]);
        if (order.isEmpty) throw _MallError(404, '订单不存在');
        final item = await tx.execute(
            'UPDATE mall_order_items SET purchased=\$1,out_of_stock=\$2 WHERE order_id=\$3 AND id=\$4',
            parameters: [
              data['purchased'],
              data['outOfStock'],
              int.parse(id),
              int.parse(itemId)
            ]);
        if (item.affectedRows == 0) throw _MallError(404, '订单商品不存在');
        final counts = await tx.execute(
            'SELECT bool_and(purchased),bool_or(out_of_stock) FROM mall_order_items WHERE order_id=\$1',
            parameters: [int.parse(id)]);
        final status = counts.first[0] == true
            ? '已做完'
            : counts.first[1] == true
                ? '有问题'
                : '未做完';
        final lines = await tx.execute(
            'SELECT name,specification,quantity::text,purchased,out_of_stock,name_en FROM mall_order_items WHERE order_id=\$1 ORDER BY id',
            parameters: [int.parse(id)]);
        final content = lines
            .map((r) =>
                '${r[3] == true ? "[已采购]" : r[4] == true ? "[缺货]" : "[待采购]"} ${r[0]} / ${r[5]} ${r[1]} × ${r[2]}')
            .join('\n');
        await tx.execute(
            'UPDATE todo_tasks SET status=\$1,content=\$2 WHERE mall_order_id=\$3',
            parameters: [status, content, int.parse(id)]);
      });
      return _mallJson({'success': true});
    });

Future<Response?> _requireUserAdmin(Request request) async {
  final auth = request.headers['authorization'] ?? '';
  if (!auth.startsWith('Bearer ')) return _mallJson({'error': '请重新登录'}, 401);
  final rows = await _conn.execute(
    'SELECT u.role FROM mall_sessions s JOIN users u ON LOWER(u.username)=LOWER(s.username) WHERE s.token_hash=\$1 AND s.expires_at>CURRENT_TIMESTAMP',
    parameters: [sha256.convert(utf8.encode(auth.substring(7))).toString()],
  );
  if (rows.isEmpty) return _mallJson({'error': '登录已过期'}, 401);
  if (rows.first[0] != 'ADMIN')
    return _mallJson({'error': '只有 ADMIN 可以管理用户权限'}, 403);
  return null;
}

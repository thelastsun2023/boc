part of 'server.dart';

Future<void> _initProcurement() async {
  await _conn.execute('''CREATE TABLE IF NOT EXISTS procurement_items (
    store_code TEXT NOT NULL, demand_date DATE NOT NULL,
    product_code TEXT NOT NULL, specification TEXT NOT NULL,
    purchase_quantity NUMERIC(14,2) NOT NULL CHECK(purchase_quantity >= 0),
    purchased BOOLEAN NOT NULL DEFAULT FALSE,
    confirmed_demand NUMERIC(14,2) NOT NULL DEFAULT 0,
    updated_by TEXT NOT NULL, updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(store_code,demand_date,product_code,specification))''');
}

String _procurementKey(String store, String date, String code, String unit) =>
    jsonEncode([store, date, code, unit]);

// Read demand from the original submissions, so retries and page refreshes never
// add demand twice. Procurement progress is stored separately from demand.
Future<List<Map<String, dynamic>>> _procurementDemand() async {
  final rows = await _conn.execute('''
    SELECT o.store_code,COALESCE(s.name,o.store_name),
      (o.created_at AT TIME ZONE 'UTC' AT TIME ZONE 'America/Edmonton')::date::text,
      i.product_code,i.name,i.name_en,i.specification,i.quantity::text,
      COALESCE(r.primary_supplier_code,''),COALESCE(p.name,'未指定供应商'),
      '商城',o.id::text,COALESCE(o.owner_username,'历史记录')
    FROM mall_orders o JOIN mall_order_items i ON i.order_id=o.id
    LEFT JOIN stores s ON s.code=o.store_code
    LEFT JOIN raw_materials r ON r.code=i.product_code
    LEFT JOIN suppliers p ON p.code=r.primary_supplier_code
    UNION ALL
    SELECT o.store_code,COALESCE(s.name,o.store_code),o.order_date::text,
      d->>'code',COALESCE(d->>'nameCN',r.name_cn,d->>'code'),
      COALESCE(d->>'nameEN',r.name_en,''),COALESCE(r.specification,''),
      d->>'orderQuantity',COALESCE(r.primary_supplier_code,''),
      COALESCE(p.name,'未指定供应商'),'点货',o.id::text,COALESCE(o.owner_username,'历史记录')
    FROM stock_orders o
    CROSS JOIN LATERAL jsonb_array_elements(
      CASE WHEN jsonb_typeof(o.details::jsonb)='array' THEN o.details::jsonb ELSE '[]'::jsonb END) d
    LEFT JOIN stores s ON s.code=o.store_code
    LEFT JOIN raw_materials r ON r.code=d->>'code'
    LEFT JOIN suppliers p ON p.code=r.primary_supplier_code
    WHERE o.is_deleted=FALSE AND o.is_confirmed=TRUE AND o.store_code IS NOT NULL
      AND COALESCE(d->>'categorySelected','true')='true'
    ''');
  final groups = <String, Map<String, dynamic>>{};
  for (final r in rows) {
    final quantity = double.tryParse('${r[7]}') ?? 0;
    if (!quantity.isFinite || quantity <= 0 || r[3] == null) continue;
    final store = r[0] as String;
    final date = r[2] as String;
    final code = r[3] as String;
    final unit = r[6] as String;
    final key = _procurementKey(store, date, code, unit);
    final item = groups.putIfAbsent(
        key,
        () => {
              'storeCode': store,
              'storeName': r[1],
              'date': date,
              'code': code,
              'nameCN': r[4],
              'nameEN': r[5],
              'unit': unit,
              'supplierCode': r[8],
              'supplierName': r[9],
              'demandQuantity': 0.0,
              'sources': <String>[],
              'submitters': <String>[],
            });
    item['demandQuantity'] = ((item['demandQuantity'] as double) + quantity);
    final source = '${r[10]} #${r[11]}';
    if (!(item['sources'] as List).contains(source))
      (item['sources'] as List).add(source);
    if (!(item['submitters'] as List).contains(r[12]))
      (item['submitters'] as List).add(r[12]);
  }
  final states = await _conn.execute(
      '''SELECT store_code,demand_date::text,product_code,specification,
    purchase_quantity::text,purchased,confirmed_demand::text FROM procurement_items''');
  final saved = {
    for (final r in states)
      _procurementKey(
          r[0] as String, r[1] as String, r[2] as String, r[3] as String): r
  };
  for (final entry in groups.entries) {
    final item = entry.value;
    item['demandQuantity'] =
        double.parse((item['demandQuantity'] as double).toStringAsFixed(2));
    final state = saved[entry.key];
    item['purchaseQuantity'] = state == null
        ? item['demandQuantity']
        : double.parse(state[4] as String);
    item['purchased'] = state != null &&
        state[5] == true &&
        double.parse(state[6] as String) >= (item['demandQuantity'] as double);
  }
  return groups.values.toList();
}

Future<Response> _procurementOrders(Request request) =>
    _mallCall(request, (scope, data) async {
      _mallAdmin(scope);
      final items = await _procurementDemand();
      final orders = <String, Map<String, dynamic>>{};
      for (final item in items) {
        final key = jsonEncode([item['storeCode'], item['date']]);
        final order = orders.putIfAbsent(
            key,
            () => {
                  'storeCode': item['storeCode'],
                  'storeName': item['storeName'],
                  'date': item['date'],
                  'items': <Map<String, dynamic>>[],
                });
        (order['items'] as List).add(item);
      }
      for (final order in orders.values) {
        final lines = order['items'] as List;
        order['purchased'] = lines.isNotEmpty &&
            lines.every((line) => line['purchased'] == true);
        order['purchasedCount'] =
            lines.where((line) => line['purchased'] == true).length;
      }
      final result = orders.values.toList()
        ..sort((a, b) {
          final date = (b['date'] as String).compareTo(a['date'] as String);
          return date != 0
              ? date
              : (a['storeCode'] as String).compareTo(b['storeCode'] as String);
        });
      return _mallJson({'orders': result});
    });

Future<Response> _procurementUpdate(Request request) =>
    _mallCall(request, (scope, data) async {
      _mallAdmin(scope);
      final quantity = data['purchaseQuantity'];
      if (data['storeCode'] is! String ||
          data['date'] is! String ||
          data['code'] is! String ||
          data['unit'] is! String ||
          data['purchased'] is! bool ||
          quantity is! num ||
          !quantity.isFinite ||
          quantity < 0 ||
          quantity > 100000000 ||
          (quantity * 100 - (quantity * 100).round()).abs() > .00001) {
        throw _MallError(400, '采购数量须为不小于 0 的数字，最多两位小数');
      }
      final key = _procurementKey(
          data['storeCode'], data['date'], data['code'], data['unit']);
      final matches = (await _procurementDemand()).where((item) =>
          _procurementKey(
              item['storeCode'], item['date'], item['code'], item['unit']) ==
          key);
      if (matches.isEmpty) throw _MallError(404, '采购项目不存在或需求已撤销');
      final item = matches.first;
      if (data['expectedDemand'] != item['demandQuantity']) {
        throw _MallError(409, '需求数量已变化，请刷新后重新确认');
      }
      await _conn.execute('''INSERT INTO procurement_items
    (store_code,demand_date,product_code,specification,purchase_quantity,purchased,confirmed_demand,updated_by)
    VALUES(\$1,\$2::date,\$3,\$4,\$5,\$6,\$7,\$8)
    ON CONFLICT(store_code,demand_date,product_code,specification) DO UPDATE SET
      purchase_quantity=EXCLUDED.purchase_quantity,purchased=EXCLUDED.purchased,
      confirmed_demand=EXCLUDED.confirmed_demand,updated_by=EXCLUDED.updated_by,updated_at=CURRENT_TIMESTAMP''',
          parameters: [
            data['storeCode'],
            data['date'],
            data['code'],
            data['unit'],
            quantity,
            data['purchased'],
            item['demandQuantity'],
            scope.username
          ]);
      return _mallJson({'success': true});
    });

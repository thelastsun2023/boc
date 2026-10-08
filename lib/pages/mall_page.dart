import '../widgets/material_notes.dart';
import '../widgets/product_image.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/mall_service.dart';
import '../services/session_service.dart';
import '../services/system_service.dart';
import '../services/browser_print.dart';

class MallPage extends StatefulWidget {
  const MallPage({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<MallPage> createState() => _MallPageState();
}

class _MallPageState extends State<MallPage> {
  final service = MallService();
  final cart = <String, double>{};
  final selectedQuantities = <String, double>{};
  List<Map<String, dynamic>> products = [], orders = [], stores = [];
  String search = '', category = '', submissionKey = '';
  String? error, store;
  bool loading = true, busy = false;
  int tab = 0;
  bool gridView = true;
  bool get admin => SessionService().isAdmin;
  @override
  void initState() {
    super.initState();
    tab = widget.initialTab;
    _load();
  }

  void _newKey() {
    submissionKey =
        '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 30)}';
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        service.products(),
        service.orders(),
        if (admin) SystemService().getStores(),
      ]);
      if (!mounted) return;
      setState(() {
        products = values[0];
        orders = values[1];
        if (admin) stores = values[2];
        error = null;
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = '$e';
          loading = false;
        });
      }
    }
  }

  Future<void> _change(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      await _load();
    } catch (e) {
      _message('$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _cart() async {
    if (cart.isEmpty) {
      _message('购物车为空，请先选择商品');
      return;
    }
    if (submissionKey.isEmpty) _newKey();
    final controllers = {
      for (final code in cart.keys)
        code: TextEditingController(text: cart[code].toString()),
    };
    final form = GlobalKey<FormState>();
    bool sending = false;
    String? failure;
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (ctx, update) => AlertDialog(
            title: const Text('购物车 · 确认数量后提交'),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (admin)
                        DropdownButtonFormField<String>(
                          initialValue: store,
                          decoration: const InputDecoration(
                            labelText: '订单归属门店',
                          ),
                          items: stores
                              .map(
                                (x) => DropdownMenuItem(
                                  value: x['code'] as String,
                                  child: Text('${x['name']} (${x['code']})'),
                                ),
                              )
                              .toList(),
                          onChanged: sending
                              ? null
                              : (value) {
                                  store = value;
                                  _newKey();
                                },
                          validator: (v) => v == null ? '请选择门店' : null,
                        ),
                      if (!admin)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '归属门店：${SessionService().storeCode ?? "未绑定"}',
                          ),
                        ),
                      for (final code in controllers.keys.toList())
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _productName(
                                    products.firstWhere(
                                      (x) => x['code'] == code,
                                      orElse: () => {'name': code},
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 140,
                                child: TextFormField(
                                  controller: controllers[code],
                                  enabled: !sending,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: '数量',
                                  ),
                                  validator: (text) {
                                    final q = double.tryParse(text ?? '');
                                    return q == null ||
                                            !q.isFinite ||
                                            q <= 0 ||
                                            q > 1000000 ||
                                            !RegExp(
                                              r'^\d+(\.\d{1,2})?$',
                                            ).hasMatch(text ?? '')
                                        ? '大于0，最多2位小数'
                                        : null;
                                  },
                                  onChanged: (_) => _newKey(),
                                ),
                              ),
                              IconButton(
                                tooltip: '移除商品',
                                onPressed: sending
                                    ? null
                                    : () {
                                        update(
                                          () => controllers
                                              .remove(code)
                                              ?.dispose(),
                                        );
                                        setState(() => cart.remove(code));
                                        _newKey();
                                      },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        ),
                      if (controllers.isEmpty) const Text('购物车为空'),
                      if (failure != null)
                        Text(
                          failure!,
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending
                    ? null
                    : () {
                        for (final x in controllers.entries) {
                          final q = double.tryParse(x.value.text);
                          if (q != null && q.isFinite && q > 0) cart[x.key] = q;
                        }
                        setState(() {});
                        Navigator.pop(dialogContext);
                      },
                child: const Text('继续选购'),
              ),
              FilledButton(
                onPressed: sending || controllers.isEmpty
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        update(() {
                          sending = true;
                          failure = null;
                        });
                        try {
                          final items = controllers.entries
                              .map(
                                (x) => {
                                  'code': x.key,
                                  'quantity': double.parse(x.value.text),
                                },
                              )
                              .toList();
                          final id = await service.submit(
                            items,
                            submissionKey,
                            store,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (mounted) {
                            setState(() {
                              cart.clear();
                              submissionKey = '';
                              tab = 1;
                            });
                            _message('订单 #$id 已提交，ADMIN 采购任务已生成');
                            await _load();
                          }
                        } catch (e) {
                          if (dialogContext.mounted) {
                            update(() {
                              sending = false;
                              failure = '$e';
                            });
                          }
                        }
                      },
                child: Text(sending ? '提交中…' : '提交订单'),
              ),
            ],
          ),
        ),
      );
    } finally {
      for (final c in controllers.values) {
        c.dispose();
      }
    }
  }

  Future<void> _print(Map<String, dynamic> order) async {
    const escape = HtmlEscape();
    String e(Object? value) => escape.convert(value?.toString() ?? '');
    final lines = List<Map<String, dynamic>>.from(order['items']);
    final rows = lines
        .map(
          (x) =>
              '<tr><td>${e(_productName(x))}</td><td>${e(x["specification"])}</td><td>${e(x["quantity"])}</td><td>${x["purchased"] == true
                  ? "☑ 已采购"
                  : x["outOfStock"] == true
                  ? "缺货"
                  : "☐ 待采购"}</td></tr>',
        )
        .join();
    final success = await printHtmlDocument(
      title: '商城订单 #${order["id"]}',
      htmlContent:
          '''<style>body{font-family:Arial,sans-serif;padding:24px}table{width:100%;border-collapse:collapse}th,td{border:1px solid #333;padding:10px;text-align:left}@page{size:A4;margin:15mm}</style><h1>商城采购订单 #${e(order['id'])}</h1><p>门店：${e(order['storeName'])} (${e(order['storeCode'])})</p><p>提交人：${e(order['username'])} · 时间：${e(order['createdAt'])}</p><p>状态：${e(order['status'])}</p><table><thead><tr><th>商品</th><th>规格</th><th>数量</th><th>采购状态</th></tr></thead><tbody>$rows</tbody></table><p>采购人签字：________________　日期：________________</p>''',
    );
    if (!success) _message('无法打开打印窗口，请允许浏览器弹窗');
  }

  String _productName(Map<String, dynamic> p) {
    final cn = (p['name'] ?? '').toString().trim();
    final en = (p['nameEN'] ?? '').toString().trim();
    return [cn, en].where((name) => name.isNotEmpty).join(' / ');
  }

  String _quantityText(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  void _adjustQuantity(String code, double delta) {
    final value = ((selectedQuantities[code] ?? 0) + delta)
        .clamp(0, 1000000)
        .toDouble();
    setState(() {
      if (value == 0) {
        selectedQuantities.remove(code);
      } else {
        selectedQuantities[code] = double.parse(value.toStringAsFixed(2));
      }
    });
  }

  Widget _product(Map<String, dynamic> p, bool tiled) {
    final code = p['code'] as String;
    final quantity = selectedQuantities[code] ?? 0;
    final image = p['imagePath'] as String?;
    final picture = ProductImage(
      url: image,
      title: _productName(p),
      width: tiled ? double.infinity : 80,
      height: tiled ? 150 : 80,
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _productName(p),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${p["code"]} · ${p["categoryName"]}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          '规格：${p["specification"]}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (hasMaterialNotes(p['notesRich'] as String?))
          TextButton.icon(
            onPressed: () => showMaterialNotes(
              context,
              _productName(p),
              p['notesRich'] as String,
            ),
            icon: const Icon(Icons.notes, size: 16),
            label: const Text('备注 / Notes'),
          ),
      ],
    );
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: '减少 ${p["name"]}',
          onPressed: quantity <= 0 ? null : () => _adjustQuantity(code, -1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 52,
          child: Text(
            _quantityText(quantity),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton.filled(
          tooltip: '增加 ${p["name"]}',
          onPressed: quantity >= 1000000
              ? null
              : () => _adjustQuantity(code, 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
    final addToCart = FilledButton.icon(
      onPressed: quantity <= 0 || (cart[code] ?? 0) + quantity > 1000000
          ? null
          : () {
              setState(() {
                cart[code] = double.parse(
                  ((cart[code] ?? 0) + quantity).toStringAsFixed(2),
                );
                selectedQuantities.remove(code);
              });
              _newKey();
              _message(
                '${_productName(p)} × ${_quantityText(quantity)} 已加入购物车 / Added to cart',
              );
            },
      icon: const Icon(Icons.add_shopping_cart, size: 18),
      label: const Text('添加到购物车 / Add to cart', textAlign: TextAlign.center),
    );
    return Card(
      margin: tiled ? EdgeInsets.zero : const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: tiled
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  picture,
                  const SizedBox(height: 10),
                  details,
                  const Spacer(),
                  Align(alignment: Alignment.centerRight, child: controls),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity, child: addToCart),
                ],
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final information = Row(
                    children: [
                      picture,
                      const SizedBox(width: 12),
                      Expanded(child: details),
                    ],
                  );
                  final actions = Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [controls, addToCart],
                  );
                  if (constraints.maxWidth >= 760) {
                    return Row(
                      children: [
                        Expanded(child: information),
                        const SizedBox(width: 16),
                        actions,
                      ],
                    );
                  }
                  return Column(
                    children: [
                      information,
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: actions),
                    ],
                  );
                },
              ),
      ),
    );
  }

  Widget _catalog() {
    final categories = {
      for (final p in products)
        (p['categoryCode'] ?? 'uncategorized').toString(): p['categoryName']
            .toString(),
    };
    final shown = products
        .where(
          (p) =>
              (category.isEmpty ||
                  (p['categoryCode'] ?? 'uncategorized') == category) &&
              '${p["name"]} ${p["nameEN"]} ${p["code"]} ${p["specification"]}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: '搜索商品名称、编码或规格',
            ),
            onChanged: (v) => setState(() => search = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('全部分类'),
                  selected: category.isEmpty,
                  onSelected: (_) => setState(() => category = ''),
                ),
                for (final c in categories.entries)
                  ChoiceChip(
                    label: Text(c.value),
                    selected: category == c.key,
                    onSelected: (_) => setState(() => category = c.key),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Expanded(child: Text('共 ${shown.length} 件商品')),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.grid_view),
                    label: Text('图文'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.view_list),
                    label: Text('列表'),
                  ),
                ],
                selected: {gridView},
                onSelectionChanged: (value) =>
                    setState(() => gridView = value.first),
              ),
            ],
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? const Center(child: Text('暂无商品；ADMIN 可在系统管理中维护原材料及分类'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    if (!gridView) {
                      return ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: shown.length,
                        itemBuilder: (_, index) =>
                            _product(shown[index], false),
                      );
                    }
                    final columns = max(
                      1,
                      (constraints.maxWidth / 260).floor(),
                    );
                    return GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: 450,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: shown.length,
                      itemBuilder: (_, index) => _product(shown[index], true),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _orderList() => orders.isEmpty
      ? const Center(child: Text('暂无订单'))
      : ListView(
          padding: const EdgeInsets.all(12),
          children: orders.map((order) {
            final lines = List<Map<String, dynamic>>.from(order['items']);
            return Card(
              child: ExpansionTile(
                title: Text(
                  '#${order["id"]} · ${order["storeName"]} · ${order["status"]}',
                ),
                subtitle: Text('${order["username"]} · ${order["createdAt"]}'),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _print(order),
                      icon: const Icon(Icons.print),
                      label: const Text('打印纸质订单'),
                    ),
                  ),
                  for (final item in lines)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 280,
                            child: Text(
                              '${_productName(item)} · ${item["specification"]}\n数量：${item["quantity"]}',
                            ),
                          ),
                          if (admin) ...[
                            SizedBox(
                              width: 155,
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('采购完成'),
                                value: item['purchased'] == true,
                                onChanged: busy
                                    ? null
                                    : (value) => _change(
                                        () => service.item(
                                          order['id'] as int,
                                          item['id'] as int,
                                          value == true,
                                          value == true
                                              ? false
                                              : item['outOfStock'] == true,
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(
                              width: 140,
                              child: CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('缺货'),
                                value: item['outOfStock'] == true,
                                onChanged: busy
                                    ? null
                                    : (value) => _change(
                                        () => service.item(
                                          order['id'] as int,
                                          item['id'] as int,
                                          value == true
                                              ? false
                                              : item['purchased'] == true,
                                          value == true,
                                        ),
                                      ),
                              ),
                            ),
                          ] else
                            Text(
                              item['purchased'] == true
                                  ? '已采购'
                                  : item['outOfStock'] == true
                                  ? '缺货'
                                  : '待采购',
                              style: TextStyle(
                                color: item['outOfStock'] == true
                                    ? Colors.red
                                    : Colors.black87,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        );
  @override
  Widget build(BuildContext context) {
    if (!admin &&
        (SessionService().storeCode == null ||
            SessionService().storeCode!.isEmpty)) {
      return const Center(child: Text('请先联系 ADMIN 为你的账户绑定门店'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '商城',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              ChoiceChip(
                label: const Text('商品'),
                selected: tab == 0,
                onSelected: (_) => setState(() => tab = 0),
              ),
              ChoiceChip(
                label: Text(admin ? '采购订单' : '我的订单'),
                selected: tab == 1,
                onSelected: (_) {
                  setState(() => tab = 1);
                  _load();
                },
              ),
              FilledButton.icon(
                onPressed: loading ? null : _cart,
                icon: const Icon(Icons.shopping_cart),
                label: Text('购物车 (${cart.length})'),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        if (busy) const LinearProgressIndicator(),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(child: Text(error!))
              : tab == 0
              ? _catalog()
              : _orderList(),
        ),
      ],
    );
  }
}

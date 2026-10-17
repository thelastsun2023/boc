import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/mall_service.dart';
import '../services/browser_print.dart';

String _number(dynamic value) {
  final n = double.tryParse('$value') ?? 0;
  return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
}

class ProcurementPage extends StatefulWidget {
  const ProcurementPage({super.key});
  @override
  State<ProcurementPage> createState() => _ProcurementPageState();
}

class _ProcurementPageState extends State<ProcurementPage> {
  final service = MallService();
  List<Map<String, dynamic>> orders = [];
  String store = '', supplier = '', status = '', search = '', sort = 'supplier';
  String? date, error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await service.call('procurement');
      if (!mounted) return;
      setState(() {
        orders = List<Map<String, dynamic>>.from(data['orders']);
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

  Future<void> _save(
    Map<String, dynamic> item,
    double quantity,
    bool purchased,
  ) async {
    try {
      await service.call(
        'procurement/items',
        method: 'PUT',
        body: {
          'storeCode': item['storeCode'],
          'date': item['date'],
          'code': item['code'],
          'unit': item['unit'],
          'purchaseQuantity': quantity,
          'purchased': purchased,
          'expectedDemand': item['demandQuantity'],
        },
      );
    } finally {
      await _load();
    }
  }

  List<Map<String, dynamic>> _lines(Map<String, dynamic> order) {
    final lines = List<Map<String, dynamic>>.from(order['items']).where((item) {
      return (supplier.isEmpty ||
              (item['supplierCode'] == ''
                      ? '__none__'
                      : item['supplierCode']) ==
                  supplier) &&
          (status.isEmpty ||
              (item['purchased'] == true) == (status == 'done')) &&
          '${item['nameCN']} ${item['nameEN']} ${item['code']}'
              .toLowerCase()
              .contains(search.toLowerCase());
    }).toList();
    lines.sort((a, b) {
      final comparison = switch (sort) {
        'supplierDesc' => '${b['supplierName']}'.compareTo(
          '${a['supplierName']}',
        ),
        'quantity' => (b['demandQuantity'] as num).compareTo(
          a['demandQuantity'] as num,
        ),
        'name' => '${a['nameCN']}'.compareTo('${b['nameCN']}'),
        _ => '${a['supplierName']}'.compareTo('${b['supplierName']}'),
      };
      return comparison != 0
          ? comparison
          : '${a['code']}'.compareTo('${b['code']}');
    });
    return lines;
  }

  Future<void> _print(
    Map<String, dynamic> order,
    List<Map<String, dynamic>> lines,
  ) async {
    const escape = HtmlEscape();
    String e(Object? v) => escape.convert('${v ?? ''}');
    final rows = lines
        .map(
          (item) =>
              '<tr><td>${e(item['nameCN'])}<br>${e(item['nameEN'])}</td><td>${e(item['supplierName'])}</td><td>${e(item['unit'])}</td><td>${e(_number(item['demandQuantity']))}</td><td>${e(_number(item['purchaseQuantity']))}</td><td>${item['purchased'] == true ? '已采购' : '未采购'}</td></tr>',
        )
        .join();
    final success = await printHtmlDocument(
      title: '每日采购单',
      htmlContent:
          '''
      <style>body{font-family:Arial,sans-serif;padding:24px}table{width:100%;border-collapse:collapse}td,th{border:1px solid #aaa;padding:8px;text-align:left}</style>
      <h1>每日采购单</h1><p>${e(order['date'])} · ${e(order['storeName'])} (${e(order['storeCode'])})</p>
      <p>整单状态：${order['purchased'] == true ? '已采购' : '未采购'}；以下为当前筛选项目。</p>
      <table><tr><th>商品 / Product</th><th>采购单位（供应商）</th><th>规格</th><th>需求数量</th><th>采购数量</th><th>状态</th></tr>$rows</table>''',
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请允许弹出打印窗口')));
    }
  }

  Widget _select(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> changed, {
    double width = 190,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<String>(
      key: ValueKey('$label-$value'),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) setState(() => changed(v));
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final stores = <String, String>{'': '全部门店'};
    final suppliers = <String, String>{'': '全部采购单位'};
    for (final order in orders) {
      stores[order['storeCode']] = '${order['storeName']}';
      for (final item in order['items']) {
        // Empty supplier codes represent materials without a supplier.
        suppliers[item['supplierCode'] == ''
                ? '__none__'
                : item['supplierCode']] =
            '${item['supplierName']}';
      }
    }
    final visible = orders
        .where(
          (order) =>
              (store.isEmpty || order['storeCode'] == store) &&
              (date == null || order['date'] == date) &&
              _lines(order).isNotEmpty,
        )
        .toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '采购详情',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: '刷新采购单',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text('每店每天一张，汇总商城订单和已确认点货需求。整单状态包含该单全部项目。'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _select('门店', store, stores, (v) => store = v),
              _select(
                '采购单位（供应商）',
                supplier,
                suppliers,
                (v) => supplier = v,
                width: 220,
              ),
              _select(
                '项目状态',
                status,
                {'': '全部状态', 'pending': '未采购', 'done': '已采购'},
                (v) => status = v,
                width: 150,
              ),
              _select('排序', sort, {
                'supplier': '采购单位 ↑',
                'supplierDesc': '采购单位 ↓',
                'name': '商品名称',
                'quantity': '需求数量 ↓',
              }, (v) => sort = v),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range),
                label: Text(date ?? '全部日期'),
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.tryParse(date ?? '') ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (selected != null && mounted) {
                    setState(
                      () => date = selected.toIso8601String().substring(0, 10),
                    );
                  }
                },
              ),
              if (date != null)
                TextButton(
                  onPressed: () => setState(() => date = null),
                  child: const Text('清除日期'),
                ),
              SizedBox(
                width: 230,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '搜索商品名称／编号',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => search = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? const Center(child: Text('暂无符合条件的采购单'))
                : ListView.builder(
                    key: const PageStorageKey('procurement-order-list'),
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final order = visible[index],
                          lines = _lines(visible[index]);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ExpansionTile(
                          key: PageStorageKey(
                            'procurement-${order['storeCode']}-${order['date']}',
                          ),
                          initiallyExpanded: index == 0,
                          title: Text(
                            '${order['date']} · ${order['storeName']}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${order['purchased'] == true ? '已采购' : '未采购'}  ·  ${order['purchasedCount']} / ${(order['items'] as List).length} 项已采购  ·  当前显示 ${lines.length} 项',
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _print(order, lines),
                                icon: const Icon(Icons.print),
                                label: const Text('打印采购单'),
                              ),
                            ),
                            SingleChildScrollView(
                              // Keep scroll offsets separate from ExpansionTile's boolean state.
                              key: PageStorageKey(
                                'procurement-items-scroll-${order['storeCode']}-${order['date']}',
                              ),
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: 1080,
                                child: Column(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 300,
                                            child: Text('商品 / Product'),
                                          ),
                                          SizedBox(
                                            width: 180,
                                            child: Text('采购单位（供应商）'),
                                          ),
                                          SizedBox(
                                            width: 90,
                                            child: Text('规格'),
                                          ),
                                          SizedBox(
                                            width: 110,
                                            child: Text('需求数量'),
                                          ),
                                          SizedBox(
                                            width: 210,
                                            child: Text('采购数量'),
                                          ),
                                          Text('采购状态'),
                                        ],
                                      ),
                                    ),
                                    for (final item in lines)
                                      _ProcurementItem(
                                        key: ValueKey(
                                          jsonEncode([
                                            item['storeCode'],
                                            item['date'],
                                            item['code'],
                                            item['unit'],
                                          ]),
                                        ),
                                        item: item,
                                        onSave: (q, p) => _save(item, q, p),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProcurementItem extends StatefulWidget {
  const _ProcurementItem({super.key, required this.item, required this.onSave});
  final Map<String, dynamic> item;
  final Future<void> Function(double, bool) onSave;
  @override
  State<_ProcurementItem> createState() => _ProcurementItemState();
}

class _ProcurementItemState extends State<_ProcurementItem> {
  late final TextEditingController quantity;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    quantity = TextEditingController(
      text: _number(widget.item['purchaseQuantity']),
    );
  }

  @override
  void didUpdateWidget(covariant _ProcurementItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item['purchaseQuantity'] != widget.item['purchaseQuantity']) {
      quantity.text = _number(widget.item['purchaseQuantity']);
    }
  }

  @override
  void dispose() {
    quantity.dispose();
    super.dispose();
  }

  Future<void> _save(bool purchased) async {
    final q = double.tryParse(quantity.text.trim());
    if (q == null ||
        !q.isFinite ||
        q < 0 ||
        q > 100000000 ||
        (q * 100 - (q * 100).round()).abs() > .00001) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('采购数量须不小于 0，最多两位小数')));
      return;
    }
    setState(() => saving = true);
    try {
      await widget.onSave(q, purchased);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item, purchased = item['purchased'] == true;
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xffeeeeee))),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 300,
            child: Tooltip(
              message:
                  '来源：${(item['sources'] as List).join('、')}\n提交人：${(item['submitters'] as List).join('、')}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${item['nameCN']}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('${item['nameEN']}'),
                  Text(
                    '${item['code']}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 180, child: Text('${item['supplierName']}')),
          SizedBox(width: 90, child: Text('${item['unit']}')),
          SizedBox(
            width: 110,
            child: Text(
              _number(item['demandQuantity']),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 210,
            child: Row(
              children: [
                SizedBox(
                  width: 115,
                  child: TextField(
                    controller: quantity,
                    enabled: !saving,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: '采购数量',
                    ),
                    onSubmitted: (_) => _save(purchased),
                  ),
                ),
                IconButton(
                  tooltip: '保存采购数量',
                  onPressed: saving ? null : () => _save(purchased),
                  icon: const Icon(Icons.save_outlined),
                ),
              ],
            ),
          ),
          if (saving)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ActionChip(
              avatar: Icon(
                purchased ? Icons.check_circle : Icons.radio_button_unchecked,
                color: purchased ? Colors.green : Colors.grey,
                size: 18,
              ),
              label: Text(purchased ? '已采购' : '未采购'),
              onPressed: () => _save(!purchased),
            ),
        ],
      ),
    );
  }
}

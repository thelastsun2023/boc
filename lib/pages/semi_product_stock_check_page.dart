import 'package:flutter/material.dart';

import '../services/browser_print.dart';
import '../services/session_service.dart';
import '../services/system_service.dart';

enum StockChecklistPeriod { weekday, weekend, holiday }

class SemiProductStockCheckPage extends StatefulWidget {
  const SemiProductStockCheckPage({super.key});

  @override
  State<SemiProductStockCheckPage> createState() =>
      _SemiProductStockCheckPageState();
}

class _SemiProductStockCheckPageState extends State<SemiProductStockCheckPage> {
  final SystemService _service = SystemService();
  final List<Map<String, dynamic>> _checks = [];
  final List<Map<String, dynamic>> _semiProducts = [];
  final List<Map<String, dynamic>> _regions = [];

  bool _isLoading = true;
  String? _error;
  StockChecklistPeriod _selectedPeriod = StockChecklistPeriod.weekday;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final checks = await _service.getSemiProductStockChecks();
      final semiProducts = await _service.getSemiProducts();
      final regions = await _service.getRegions();

      if (!mounted) {
        return;
      }

      setState(() {
        _checks
          ..clear()
          ..addAll(checks);
        _semiProducts
          ..clear()
          ..addAll(semiProducts);
        _regions
          ..clear()
          ..addAll(regions);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  double _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _formatStock(dynamic value) {
    final normalized = _toDouble(value).toStringAsFixed(2);
    return normalized
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _semiProductLabel(Map<String, dynamic> item) {
    final code = item['code'] as String? ?? '';
    final nameCN = item['nameCN'] as String? ?? '';
    final nameEN = item['nameEN'] as String? ?? '';
    if (nameEN.trim().isEmpty) {
      return '$nameCN ($code)';
    }
    final nameText = SessionService().isEnglish
        ? '$nameEN / $nameCN'
        : '$nameCN / $nameEN';
    return '$nameText ($code)';
  }

  String _regionLabel(Map<String, dynamic> item) {
    final code = item['code'] as String? ?? '';
    final nameCN = item['nameCN'] as String? ?? '';
    final nameEN = item['nameEN'] as String? ?? '';
    if (nameEN.trim().isEmpty) {
      return '$nameCN ($code)';
    }
    final nameText = SessionService().isEnglish
        ? '$nameEN / $nameCN'
        : '$nameCN / $nameEN';
    return '$nameText ($code)';
  }

  String _periodLabel(StockChecklistPeriod period) {
    switch (period) {
      case StockChecklistPeriod.weekday:
        return '平日';
      case StockChecklistPeriod.weekend:
        return '周末';
      case StockChecklistPeriod.holiday:
        return '重大节日';
    }
  }

  String _stockValueForPeriod(Map<String, dynamic> item) {
    switch (_selectedPeriod) {
      case StockChecklistPeriod.weekday:
        return _formatStock(item['weekdayStock']);
      case StockChecklistPeriod.weekend:
        return _formatStock(item['weekendStock']);
      case StockChecklistPeriod.holiday:
        return _formatStock(item['holidayStock']);
    }
  }

  Map<String, List<Map<String, dynamic>>> get _groupedChecks {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final item in _checks) {
      final regionName =
          (item['regionNameCN'] as String?)?.trim().isNotEmpty == true
          ? item['regionNameCN'] as String
          : (item['regionCode'] as String? ?? '未分区');
      groups.putIfAbsent(regionName, () => []).add(item);
    }
    return groups;
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _buildPrintHtml() {
    final buffer = StringBuffer();
    final groupedChecks = _groupedChecks;
    buffer.write('''
<style>
  body {
    font-family: "Microsoft YaHei", "PingFang SC", sans-serif;
    margin: 24px;
    color: #111827;
  }
  h1 {
    margin: 0 0 8px;
    font-size: 28px;
  }
  .meta {
    margin: 0 0 20px;
    color: #6b7280;
    font-size: 14px;
  }
  .group {
    margin-bottom: 24px;
    page-break-inside: avoid;
  }
  .group-title {
    margin-bottom: 10px;
    font-size: 18px;
    font-weight: 700;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    table-layout: fixed;
  }
  th, td {
    border: 1px solid #d1d5db;
    padding: 10px 12px;
    text-align: left;
    vertical-align: top;
    word-break: break-word;
    font-size: 13px;
  }
  th {
    background: #f3f4f6;
    font-weight: 700;
  }
  .blank {
    height: 24px;
  }
</style>
''');
    buffer.write('<h1>${_escapeHtml('半成品存量检查单')}</h1>');
    buffer.write(
      '<div class="meta">检查类型：${_escapeHtml(_periodLabel(_selectedPeriod))}，共 ${_checks.length} 条记录</div>',
    );

    for (final entry in groupedChecks.entries) {
      buffer.write('<section class="group">');
      buffer.write(
        '<div class="group-title">区域：${_escapeHtml(entry.key)}</div>',
      );
      buffer.write('<table><thead><tr>');
      for (final header in ['编号', '半成品名称', '区域', '目标存量', '实际存量', '检查备注']) {
        buffer.write('<th>${_escapeHtml(header)}</th>');
      }
      buffer.write('</tr></thead><tbody>');

      for (final item in entry.value) {
        final code = item['semiProductCode'] as String? ?? '-';
        final nameCN = item['semiProductNameCN'] as String? ?? '-';
        final nameEN = item['semiProductNameEN'] as String? ?? '';
        final regionName =
            item['regionNameCN'] as String? ??
            item['regionCode'] as String? ??
            '-';
        final displayName = nameEN.trim().isEmpty
            ? nameCN
            : '$nameCN / $nameEN';
        buffer.write('<tr>');
        for (final cell in [
          code,
          displayName,
          regionName,
          _stockValueForPeriod(item),
          '',
          '',
        ]) {
          buffer.write(
            cell.isEmpty
                ? '<td class="blank"></td>'
                : '<td>${_escapeHtml(cell)}</td>',
          );
        }
        buffer.write('</tr>');
      }

      buffer.write('</tbody></table></section>');
    }

    return buffer.toString();
  }

  Future<void> _printChecklist() async {
    final success = await printHtmlDocument(
      title: '半成品存量检查单',
      htmlContent: _buildPrintHtml(),
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前平台暂不支持直接打印')));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除这条半成品存量检查记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final success = await _service.deleteSemiProductStockCheck(id);
      if (success) {
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('删除失败: $e');
      }
    }
  }

  Future<void> _showCheckDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    String? selectedSemiProductCode = item?['semiProductCode'] as String?;
    String? selectedRegionCode = item?['regionCode'] as String?;
    final weekdayController = TextEditingController(
      text: _formatStock(item?['weekdayStock'] ?? 0),
    );
    final weekendController = TextEditingController(
      text: _formatStock(item?['weekendStock'] ?? 0),
    );
    final holidayController = TextEditingController(
      text: _formatStock(item?['holidayStock'] ?? 0),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '编辑半成品存量检查' : '添加半成品存量检查'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownMenu<String>(
                      width: 380,
                      initialSelection: selectedSemiProductCode,
                      enableFilter: true,
                      enableSearch: true,
                      requestFocusOnTap: true,
                      label: const Text('半成品'),
                      hintText: '选择半成品编号 / 名称',
                      onSelected: (value) {
                        setDialogState(() {
                          selectedSemiProductCode = value;
                        });
                      },
                      dropdownMenuEntries: _semiProducts.map((item) {
                        final code = item['code'] as String;
                        return DropdownMenuEntry<String>(
                          value: code,
                          label: _semiProductLabel(item),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    DropdownMenu<String>(
                      width: 380,
                      initialSelection: selectedRegionCode,
                      enableFilter: true,
                      enableSearch: true,
                      requestFocusOnTap: true,
                      label: const Text('区域'),
                      hintText: '选择区域编号 / 名称',
                      onSelected: (value) {
                        setDialogState(() {
                          selectedRegionCode = value;
                        });
                      },
                      dropdownMenuEntries: _regions.map((item) {
                        final code = item['code'] as String;
                        return DropdownMenuEntry<String>(
                          value: code,
                          label: _regionLabel(item),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weekdayController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '平日存量'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: weekendController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '周末存量'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: holidayController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '重大节日存量'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () async {
                  final semiProductCode = selectedSemiProductCode?.trim() ?? '';
                  final regionCode = selectedRegionCode?.trim() ?? '';
                  final weekdayStock =
                      double.tryParse(weekdayController.text.trim()) ?? 0;
                  final weekendStock =
                      double.tryParse(weekendController.text.trim()) ?? 0;
                  final holidayStock =
                      double.tryParse(holidayController.text.trim()) ?? 0;

                  if (semiProductCode.isEmpty || regionCode.isEmpty) {
                    _showMessage('请选择半成品和区域');
                    return;
                  }

                  final duplicate = _checks.any(
                    (element) =>
                        element['semiProductCode'] == semiProductCode &&
                        element['regionCode'] == regionCode &&
                        (!isEdit || element['id'] != item['id']),
                  );
                  if (duplicate) {
                    _showMessage('同一区域下该半成品已存在存量检查记录');
                    return;
                  }

                  try {
                    final success = isEdit
                        ? await _service.updateSemiProductStockCheck(
                            item['id'] as int,
                            semiProductCode,
                            regionCode,
                            weekdayStock,
                            weekendStock,
                            holidayStock,
                          )
                        : await _service.addSemiProductStockCheck(
                            semiProductCode,
                            regionCode,
                            weekdayStock,
                            weekendStock,
                            holidayStock,
                          );
                    if (success) {
                      await _loadData();
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      _showMessage('${isEdit ? '保存' : '创建'}失败: $e');
                    }
                  }
                },
                child: Text(isEdit ? '保存' : '添加'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('半成品存量检查')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _showCheckDialog(),
                        icon: const Icon(Icons.add),
                        label: const Text('添加检查数据'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _checks.isEmpty ? null : _printChecklist,
                        icon: const Icon(Icons.print_outlined),
                        label: const Text('生成网页检查单'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '检查单类型',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: StockChecklistPeriod.values.map((period) {
                              return ChoiceChip(
                                label: Text(_periodLabel(period)),
                                selected: _selectedPeriod == period,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      _selectedPeriod = period;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '当前将生成 ${_periodLabel(_selectedPeriod)} 检查单，按区域分组展示。',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _checks.isEmpty
                        ? const Center(child: Text('没有存量检查数据'))
                        : ListView.builder(
                            itemCount: _checks.length,
                            itemBuilder: (context, index) {
                              final item = _checks[index];
                              final regionName =
                                  (item['regionNameCN'] as String?)
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? item['regionNameCN'] as String
                                  : (item['regionCode'] as String? ?? '-');
                              final nameCN =
                                  item['semiProductNameCN'] as String? ?? '-';
                              final nameEN =
                                  item['semiProductNameEN'] as String? ?? '';
                              final nameText = nameEN.trim().isEmpty
                                  ? nameCN
                                  : (SessionService().isEnglish
                                        ? '$nameEN / $nameCN'
                                        : '$nameCN / $nameEN');
                              return Card(
                                child: ListTile(
                                  title: Text(
                                    '${item['semiProductCode']} - $nameText',
                                  ),
                                  subtitle: Text(
                                    '区域: $regionName\n平日: ${_formatStock(item['weekdayStock'])}  周末: ${_formatStock(item['weekendStock'])}  重大节日: ${_formatStock(item['holidayStock'])}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Wrap(
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _showCheckDialog(item: item),
                                        icon: const Icon(Icons.edit_outlined),
                                        tooltip: '编辑',
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _confirmDelete(item['id'] as int),
                                        icon: const Icon(Icons.delete_outline),
                                        tooltip: '删除',
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

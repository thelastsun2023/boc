import 'package:flutter/material.dart';

import '../services/browser_print.dart';
import '../services/session_service.dart';
import '../services/system_service.dart';

class RawMaterialOverviewPage extends StatefulWidget {
  const RawMaterialOverviewPage({super.key});

  @override
  State<RawMaterialOverviewPage> createState() =>
      _RawMaterialOverviewPageState();
}

class _RawMaterialOverviewPageState extends State<RawMaterialOverviewPage> {
  final SystemService _systemService = SystemService();
  final List<Map<String, dynamic>> _rawMaterials = [];
  final List<Map<String, dynamic>> _suppliers = [];
  final ScrollController _verticalScrollController = ScrollController();
  final ScrollController _horizontalScrollController = ScrollController();
  bool _isLoading = true;
  String? _error;
  String? _selectedCategory;

  bool get _isEnglish => SessionService().isEnglish;

  String _orderedName(String? nameCN, String? nameEN) {
    final cn = (nameCN ?? '').trim();
    final en = (nameEN ?? '').trim();
    if (cn.isEmpty || cn == '-') {
      return en.isEmpty ? '-' : en;
    }
    if (en.isEmpty || en == '-') {
      return cn;
    }
    return _isEnglish ? '$en / $cn' : '$cn / $en';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _verticalScrollController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final materials = await _systemService.getRawMaterials();
      final suppliers = await _systemService.getSuppliers();

      if (!mounted) return;

      setState(() {
        _rawMaterials
          ..clear()
          ..addAll(materials);
        _suppliers
          ..clear()
          ..addAll(suppliers);
        final validSelections = _categoryOptions
            .map((option) => option['key'] as String?)
            .toSet();
        if (!validSelections.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _displayString(dynamic value) {
    if (value == null) return '-';
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? '-' : trimmed;
    }
    return value.toString();
  }

  String _categoryLabel(Map<String, dynamic> item) {
    final nameCN = (item['categoryNameCN'] as String?)?.trim();
    final nameEN = (item['categoryNameEN'] as String?)?.trim();
    final ordered = _orderedName(nameCN, nameEN);
    if (ordered != '-') {
      return ordered;
    }
    final categoryName = (item['categoryName'] as String?)?.trim();
    if (categoryName == null || categoryName.isEmpty || categoryName == '-') {
      return '未分类';
    }
    return categoryName;
  }

  String _supplierName(String? code) {
    if (code == null || code.isEmpty) {
      return '-';
    }
    final supplier = _suppliers.firstWhere(
      (item) => item['code'] == code,
      orElse: () => {},
    );
    return _displayString(
      supplier['name'] ?? supplier['nameCN'] ?? supplier['nameEN'] ?? code,
    );
  }

  List<Map<String, dynamic>> get _categoryOptions {
    final counts = <String, int>{};
    for (final item in _rawMaterials) {
      final label = _categoryLabel(item);
      counts[label] = (counts[label] ?? 0) + 1;
    }

    final sortedLabels = counts.keys.toList()..sort();
    return [
      {'key': null, 'label': '全部', 'count': _rawMaterials.length},
      ...sortedLabels.map(
        (label) => {'key': label, 'label': label, 'count': counts[label] ?? 0},
      ),
    ];
  }

  List<Map<String, dynamic>> get _visibleRawMaterials {
    if (_selectedCategory == null) {
      return _rawMaterials;
    }
    return _rawMaterials
        .where((item) => _categoryLabel(item) == _selectedCategory)
        .toList();
  }

  List<MapEntry<String, List<Map<String, dynamic>>>> get _groupedRawMaterials {
    final groups = <String, List<Map<String, dynamic>>>{};

    for (final item in _visibleRawMaterials) {
      final categoryName = _categoryLabel(item);
      groups.putIfAbsent(categoryName, () => []).add(item);
    }

    final entries = groups.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));
    return entries;
  }

  List<DataColumn> get _columns => const [
    DataColumn(label: Text('编号')),
    DataColumn(label: Text('名称')),
    DataColumn(label: Text('规格')),
    DataColumn(label: Text('最小订货量')),
    DataColumn(label: Text('主要供货商')),
    DataColumn(label: Text('次要供货商')),
  ];

  List<DataRow> _buildRows(List<Map<String, dynamic>> items) {
    return items.map((item) {
      final code = _displayString(item['code']);
      final nameCN = _displayString(item['nameCN']);
      final nameEN = _displayString(item['nameEN']);
      final displayName = _orderedName(nameCN, nameEN);
      final spec = _displayString(item['specification']);
      final minQuantity = _displayString(item['minQuantity']);
      final primarySupplier = _supplierName(
        item['primarySupplierCode'] as String?,
      );
      final secondarySupplier = _supplierName(
        item['secondarySupplierCode'] as String?,
      );
      return DataRow(
        cells: [
          DataCell(Text(code)),
          DataCell(Text(displayName)),
          DataCell(Text(spec)),
          DataCell(Text(minQuantity)),
          DataCell(Text(primarySupplier)),
          DataCell(Text(secondarySupplier)),
        ],
      );
    }).toList();
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
    final title = _selectedCategory == null
        ? '原材料一览'
        : '原材料一览 - $_selectedCategory';

    buffer.write('''
<style>
  body {
    font-family: "Microsoft YaHei", "PingFang SC", sans-serif;
    margin: 24px;
    color: #1f2937;
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
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 10px;
    font-size: 18px;
    font-weight: 700;
  }
  .badge {
    display: inline-block;
    padding: 2px 10px;
    border-radius: 999px;
    background: #dbeafe;
    color: #1d4ed8;
    font-size: 12px;
    font-weight: 600;
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
  @media print {
    body {
      margin: 12mm;
    }
  }
</style>
''');
    buffer.write('<h1>${_escapeHtml(title)}</h1>');
    buffer.write(
      '<div class="meta">共 ${_visibleRawMaterials.length} 条原材料记录</div>',
    );

    for (final group in _groupedRawMaterials) {
      buffer.write('<section class="group">');
      buffer.write(
        '<div class="group-title">'
        '<span>${_escapeHtml(group.key)}</span>'
        '<span class="badge">${group.value.length} 个</span>'
        '</div>',
      );
      buffer.write('<table><thead><tr>');
      for (final header in ['编号', '名称', '规格', '最小订货量', '主要供货商', '次要供货商']) {
        buffer.write('<th>${_escapeHtml(header)}</th>');
      }
      buffer.write('</tr></thead><tbody>');

      for (final item in group.value) {
        final code = _displayString(item['code']);
        final nameCN = _displayString(item['nameCN']);
        final nameEN = _displayString(item['nameEN']);
        final displayName = _orderedName(nameCN, nameEN);
        final spec = _displayString(item['specification']);
        final minQuantity = _displayString(item['minQuantity']);
        final primarySupplier = _supplierName(
          item['primarySupplierCode'] as String?,
        );
        final secondarySupplier = _supplierName(
          item['secondarySupplierCode'] as String?,
        );
        buffer.write('<tr>');
        for (final cell in [
          code,
          displayName,
          spec,
          minQuantity,
          primarySupplier,
          secondarySupplier,
        ]) {
          buffer.write('<td>${_escapeHtml(cell)}</td>');
        }
        buffer.write('</tr>');
      }

      buffer.write('</tbody></table>');
      buffer.write('</section>');
    }

    return buffer.toString();
  }

  Future<void> _printPage() async {
    final success = await printHtmlDocument(
      title: '原材料一览',
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '原材料一览',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _isLoading || _rawMaterials.isEmpty
                    ? null
                    : _printPage,
                icon: const Icon(Icons.print_outlined),
                label: const Text('打印'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_isLoading && _rawMaterials.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categoryOptions.map((option) {
                final key = option['key'] as String?;
                final label = option['label'] as String;
                final count = option['count'] as int;
                return ChoiceChip(
                  selected: _selectedCategory == key,
                  onSelected: (_) {
                    setState(() {
                      _selectedCategory = key;
                    });
                  },
                  label: Text('$label ($count)'),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(
                      child: Text(
                        '加载失败：$_error',
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : _visibleRawMaterials.isEmpty
                  ? const Center(child: Text('没有原材料数据'))
                  : Scrollbar(
                      controller: _verticalScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _verticalScrollController,
                        padding: const EdgeInsets.all(16),
                        child: Scrollbar(
                          controller: _horizontalScrollController,
                          thumbVisibility: true,
                          notificationPredicate: (notification) =>
                              notification.metrics.axis == Axis.horizontal,
                          child: SingleChildScrollView(
                            controller: _horizontalScrollController,
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 900),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _groupedRawMaterials.map((group) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                group.key,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade50,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  '${group.value.length} 个',
                                                  style: TextStyle(
                                                    color: Colors.blue.shade800,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: DataTable(
                                            headingRowColor:
                                                WidgetStateProperty.resolveWith(
                                                  (states) =>
                                                      Colors.grey.shade100,
                                                ),
                                            columns: _columns,
                                            rows: _buildRows(group.value),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

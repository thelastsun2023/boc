import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../services/browser_print.dart';
import '../services/system_service.dart';

enum FinanceFilterPeriod { all, year, month, week, day }

enum FinanceRecordTypeFilter { all, income, expense }

class FinancePage extends StatefulWidget {
  const FinancePage({super.key});

  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  final SystemService _service = SystemService();
  final ScrollController _financeListController = ScrollController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _records = [];
  FinanceFilterPeriod _selectedPeriod = FinanceFilterPeriod.all;
  FinanceRecordTypeFilter _selectedTypeFilter = FinanceRecordTypeFilter.all;
  DateTime _selectedFilterDate = DateTime.now();

  bool _matchesSelectedTypeFilter(Map<String, dynamic> item) {
    final type = (item['type'] as String? ?? '').trim();
    switch (_selectedTypeFilter) {
      case FinanceRecordTypeFilter.all:
        return true;
      case FinanceRecordTypeFilter.income:
        return type == '收入';
      case FinanceRecordTypeFilter.expense:
        return type == '支出';
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    final selected = _selectedFilterDate;
    final startOfWeek = selected.subtract(Duration(days: selected.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    final filtered = _records.where((item) {
      if (!_matchesSelectedTypeFilter(item)) {
        return false;
      }

      final dateText = item['recordDate'] as String?;
      if (dateText == null || dateText.isEmpty) {
        return _selectedPeriod == FinanceFilterPeriod.all;
      }
      final date = _parseRecordDate(dateText);
      if (date == null) {
        return _selectedPeriod == FinanceFilterPeriod.all;
      }
      switch (_selectedPeriod) {
        case FinanceFilterPeriod.all:
          return true;
        case FinanceFilterPeriod.year:
          return date.year == selected.year;
        case FinanceFilterPeriod.month:
          return date.year == selected.year && date.month == selected.month;
        case FinanceFilterPeriod.week:
          return date.isAfter(
                startOfWeek.subtract(const Duration(seconds: 1)),
              ) &&
              date.isBefore(endOfWeek);
        case FinanceFilterPeriod.day:
          return date.year == selected.year &&
              date.month == selected.month &&
              date.day == selected.day;
      }
    }).toList();

    // 按日期从小到大排序
    filtered.sort((a, b) {
      final dateA = _parseRecordDate(a['recordDate'] as String? ?? '');
      final dateB = _parseRecordDate(b['recordDate'] as String? ?? '');
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateA.compareTo(dateB);
    });

    return filtered;
  }

  Set<DateTime> get _datesWithRecords {
    final dates = <DateTime>{};
    for (final record in _records) {
      final dateText = record['recordDate'] as String?;
      if (dateText != null && dateText.isNotEmpty) {
        final date = _parseRecordDate(dateText);
        if (date != null) {
          dates.add(DateTime(date.year, date.month, date.day));
        }
      }
    }
    return dates;
  }

  Map<DateTime, ({bool hasIncome, bool hasExpense})> get _dateFinanceMarkers {
    final markers = <DateTime, ({bool hasIncome, bool hasExpense})>{};
    for (final record in _records) {
      if (!_matchesSelectedTypeFilter(record)) {
        continue;
      }

      final dateText = record['recordDate'] as String?;
      if (dateText == null || dateText.isEmpty) {
        continue;
      }

      final parsedDate = _parseRecordDate(dateText);
      if (parsedDate == null) {
        continue;
      }

      final normalizedDate = DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
      );
      final type = (record['type'] as String? ?? '').trim();
      final currentMarker =
          markers[normalizedDate] ?? (hasIncome: false, hasExpense: false);

      markers[normalizedDate] = (
        hasIncome: currentMarker.hasIncome || type == '收入',
        hasExpense: currentMarker.hasExpense || type == '支出',
      );
    }
    return markers;
  }

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  @override
  void dispose() {
    _financeListController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });
      final records = await _service.getFinanceRecords();
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _displayImageUrl(String imageUrl) {
    if (imageUrl.startsWith('http://127.0.0.1')) {
      return imageUrl.replaceFirst('http://127.0.0.1', 'http://localhost');
    }
    return imageUrl;
  }

  DateTime? _parseRecordDate(String dateText) {
    try {
      return DateTime.parse(dateText);
    } catch (_) {
      try {
        return DateTime.parse(dateText.replaceAll(' ', 'T'));
      } catch (_) {
        return null;
      }
    }
  }

  String _filterLabel(FinanceFilterPeriod period) {
    switch (period) {
      case FinanceFilterPeriod.all:
        return '全局';
      case FinanceFilterPeriod.year:
        return '年';
      case FinanceFilterPeriod.month:
        return '月';
      case FinanceFilterPeriod.week:
        return '周';
      case FinanceFilterPeriod.day:
        return '天';
    }
  }

  String _typeFilterLabel(FinanceRecordTypeFilter typeFilter) {
    switch (typeFilter) {
      case FinanceRecordTypeFilter.all:
        return '全部';
      case FinanceRecordTypeFilter.income:
        return '收入';
      case FinanceRecordTypeFilter.expense:
        return '支出';
    }
  }

  String _filterSelectionLabel() {
    switch (_selectedPeriod) {
      case FinanceFilterPeriod.all:
        return '当前: 全部';
      case FinanceFilterPeriod.year:
        return '当前年份: ${_selectedFilterDate.year}';
      case FinanceFilterPeriod.month:
        return '当前月份: ${_selectedFilterDate.year}年${_selectedFilterDate.month}月';
      case FinanceFilterPeriod.week:
        final startOfWeek = _selectedFilterDate.subtract(
          Duration(days: _selectedFilterDate.weekday - 1),
        );
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '当前周: ${_formatFriendlyDate(startOfWeek)} - ${_formatFriendlyDate(endOfWeek)}';
      case FinanceFilterPeriod.day:
        return '当前日期: ${_formatFriendlyDate(_selectedFilterDate)}';
    }
  }

  String _formatFriendlyDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickFilterDate() async {
    final selected = await showDialog<DateTime>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 400,
          height: 500,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('选择日期', style: Theme.of(context).textTheme.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _buildCustomCalendar()),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      setState(() {
        _selectedFilterDate = selected;
      });
    }
  }

  Widget _buildCustomCalendar() {
    DateTime currentMonth = DateTime(
      _selectedFilterDate.year,
      _selectedFilterDate.month,
      1,
    );

    return StatefulBuilder(
      builder: (context, setState) {
        final markers = _dateFinanceMarkers;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(
                        currentMonth.year,
                        currentMonth.month - 1,
                        1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '${currentMonth.year}年${currentMonth.month}月',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      currentMonth = DateTime(
                        currentMonth.year,
                        currentMonth.month + 1,
                        1,
                      );
                    });
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Weekday headers
            Row(
              children: ['日', '一', '二', '三', '四', '五', '六']
                  .map(
                    (day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 8),
            // Calendar grid
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
                ),
                itemCount: 42, // 6 weeks * 7 days
                itemBuilder: (context, index) {
                  final firstDayOfMonth = DateTime(
                    currentMonth.year,
                    currentMonth.month,
                    1,
                  );
                  final weekdayOfFirstDay =
                      firstDayOfMonth.weekday % 7; // 0 = Sunday
                  final dayOffset = index - weekdayOfFirstDay;
                  final date = firstDayOfMonth.add(Duration(days: dayOffset));

                  final isCurrentMonth = date.month == currentMonth.month;
                  final isSelected =
                      date.year == _selectedFilterDate.year &&
                      date.month == _selectedFilterDate.month &&
                      date.day == _selectedFilterDate.day;
                  final normalizedDate = DateTime(
                    date.year,
                    date.month,
                    date.day,
                  );
                  final marker = markers[normalizedDate];
                  final hasIncome = marker?.hasIncome ?? false;
                  final hasExpense = marker?.hasExpense ?? false;
                  final hasRecord = hasIncome || hasExpense;

                  Color? textColor;
                  if (!isCurrentMonth) {
                    textColor = Colors.grey;
                  } else if (isSelected && !hasRecord) {
                    textColor = Colors.white;
                  } else if (hasIncome && !hasExpense) {
                    textColor = Colors.red.shade800;
                  } else if (!hasIncome && hasExpense) {
                    textColor = Colors.blue.shade800;
                  } else if (hasIncome && hasExpense) {
                    textColor = Colors.black87;
                  }

                  return GestureDetector(
                    onTap: isCurrentMonth
                        ? () => Navigator.of(context).pop(date)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2,
                              )
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (isCurrentMonth && hasRecord)
                              if (hasIncome && hasExpense)
                                Column(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        color: Colors.red.shade200,
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        color: Colors.blue.shade200,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Container(
                                  color: hasIncome
                                      ? Colors.red.shade200
                                      : Colors.blue.shade200,
                                )
                            else if (isSelected)
                              Container(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            Center(
                              child: Text(
                                date.day.toString(),
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Map<String, double> _calculateSummary(List<Map<String, dynamic>> records) {
    double income = 0;
    double expense = 0;
    for (final item in records) {
      final type = item['type'] as String?;
      final amount = item['amount'];
      final value = amount is num
          ? amount.toDouble()
          : double.tryParse(amount?.toString() ?? '') ?? 0;
      if (type == '收入') {
        income += value;
      } else if (type == '支出') {
        expense += value;
      }
    }
    return {
      'income': income,
      'expense': expense,
      'remaining': income - expense,
    };
  }

  Widget _buildSummaryTile(BuildContext context, String label, double amount) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            '￥${amount.toStringAsFixed(2)}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    if (amount is num) {
      return amount.toStringAsFixed(2);
    }
    if (amount is String) {
      return double.tryParse(amount)?.toStringAsFixed(2) ?? amount;
    }
    return '0.00';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _currentFilterDescription() {
    final periodText = _selectedPeriod == FinanceFilterPeriod.all
        ? '全部时间'
        : _filterSelectionLabel().replaceFirst('当前', '筛选');
    final typeText = _typeFilterLabel(_selectedTypeFilter);
    return '$periodText | 类型：$typeText';
  }

  String _buildExportHtml() {
    final filtered = _filteredRecords;
    final summary = _calculateSummary(filtered);
    final buffer = StringBuffer();
    double runningRemaining = 0;

    buffer.write('''
<section class="finance-report">
  <div class="report-header">
    <div>
      <h1>财务记录导出</h1>
      <p>导出时间：${_escapeHtml(_formatFriendlyDate(DateTime.now()))}</p>
      <p>筛选条件：${_escapeHtml(_currentFilterDescription())}</p>
    </div>
    <div class="summary-grid">
      <div class="summary-card income">
        <span>收入总计</span>
        <strong>￥${(summary['income'] ?? 0).toStringAsFixed(2)}</strong>
      </div>
      <div class="summary-card expense">
        <span>支出总计</span>
        <strong>￥${(summary['expense'] ?? 0).toStringAsFixed(2)}</strong>
      </div>
      <div class="summary-card remaining">
        <span>剩余金额</span>
        <strong>￥${(summary['remaining'] ?? 0).toStringAsFixed(2)}</strong>
      </div>
    </div>
  </div>
  <table>
    <thead>
      <tr>
        <th>日期</th>
        <th>备注</th>
        <th>收入</th>
        <th>支出</th>
        <th>剩余</th>
      </tr>
    </thead>
    <tbody>
''');

    if (filtered.isEmpty) {
      buffer.write('<tr><td colspan="5" class="empty">当前筛选条件下没有财务记录</td></tr>');
    } else {
      for (final item in filtered) {
        final type = (item['type'] as String? ?? '').trim();
        final amount = item['amount'] is num
            ? (item['amount'] as num).toDouble()
            : double.tryParse(item['amount']?.toString() ?? '') ?? 0;
        final income = type == '收入' ? amount : 0;
        final expense = type == '支出' ? amount : 0;
        runningRemaining += income - expense;
        final note = (item['note'] as String? ?? '').trim();
        final dateText = item['recordDate'] as String? ?? '-';

        buffer.write('<tr>');
        buffer.write('<td>${_escapeHtml(dateText)}</td>');
        buffer.write('<td>${_escapeHtml(note.isEmpty ? '-' : note)}</td>');
        buffer.write(
          '<td class="income-cell">${income == 0 ? '' : '￥${income.toStringAsFixed(2)}'}</td>',
        );
        buffer.write(
          '<td class="expense-cell">${expense == 0 ? '' : '￥${expense.toStringAsFixed(2)}'}</td>',
        );
        buffer.write(
          '<td class="remaining-cell">￥${runningRemaining.toStringAsFixed(2)}</td>',
        );
        buffer.write('</tr>');
      }
    }

    buffer.write('''
    </tbody>
  </table>
</section>

<style>
  body {
    font-family: "Microsoft YaHei", "PingFang SC", sans-serif;
    color: #1f2937;
    background: #f7f7f5;
  }
  .finance-report {
    padding: 24px;
  }
  .report-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 24px;
    margin-bottom: 20px;
  }
  .report-header h1 {
    margin: 0 0 8px;
    font-size: 28px;
  }
  .report-header p {
    margin: 4px 0;
    color: #4b5563;
  }
  .summary-grid {
    display: grid;
    grid-template-columns: repeat(3, minmax(140px, 1fr));
    gap: 12px;
    min-width: 460px;
  }
  .summary-card {
    padding: 14px 16px;
    border-radius: 14px;
    color: white;
  }
  .summary-card span {
    display: block;
    font-size: 13px;
    opacity: 0.9;
    margin-bottom: 8px;
  }
  .summary-card strong {
    font-size: 22px;
  }
  .summary-card.income {
    background: linear-gradient(135deg, #dc2626, #f87171);
  }
  .summary-card.expense {
    background: linear-gradient(135deg, #1d4ed8, #60a5fa);
  }
  .summary-card.remaining {
    background: linear-gradient(135deg, #047857, #34d399);
  }
  table {
    width: 100%;
    border-collapse: collapse;
    background: white;
    border-radius: 16px;
    overflow: hidden;
  }
  th, td {
    border: 1px solid #e5e7eb;
    padding: 12px 14px;
    text-align: left;
    font-size: 14px;
  }
  th {
    background: #f3f4f6;
    font-weight: 700;
  }
  .income-cell {
    color: #b91c1c;
    font-weight: 700;
  }
  .expense-cell {
    color: #1d4ed8;
    font-weight: 700;
  }
  .remaining-cell {
    color: #047857;
    font-weight: 700;
  }
  .empty {
    text-align: center;
    color: #6b7280;
    padding: 32px 0;
  }
</style>
''');

    return buffer.toString();
  }

  Future<void> _exportRecords() async {
    final success = await printHtmlDocument(
      title: '财务记录导出',
      htmlContent: _buildExportHtml(),
    );
    if (!mounted) {
      return;
    }
    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('当前平台暂不支持直接导出')));
    }
  }

  Future<void> _showZoomableImage({
    Uint8List? imageBytes,
    String? imageUrl,
  }) async {
    if ((imageBytes == null || imageBytes.isEmpty) &&
        (imageUrl == null || imageUrl.trim().isEmpty)) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(12),
        content: SizedBox(
          width: 720,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.75,
            ),
            child: SingleChildScrollView(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: imageBytes != null && imageBytes.isNotEmpty
                    ? Image.memory(imageBytes, fit: BoxFit.contain)
                    : Image.network(
                        _displayImageUrl(imageUrl!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              height: 240,
                              child: Center(child: Icon(Icons.broken_image)),
                            ),
                      ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<({Uint8List bytes, String fileName})?> _pickAndCropPhoto() async {
    final picker = ImagePicker();
    final imageFile = await picker.pickImage(source: ImageSource.gallery);
    if (imageFile == null) {
      return null;
    }

    final bytes = await imageFile.readAsBytes();
    final controller = CropController();
    var isCropping = false;

    return showDialog<({Uint8List bytes, String fileName})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('裁剪照片'),
            content: SizedBox(
              width: 360,
              height: 520,
              child: Column(
                children: [
                  Expanded(
                    child: Crop(
                      controller: controller,
                      image: bytes,
                      aspectRatio: 1,
                      interactive: true,
                      withCircleUi: false,
                      baseColor: Colors.black,
                      maskColor: Colors.black.withOpacity(0.45),
                      radius: 12,
                      onCropped: (result) {
                        switch (result) {
                          case CropSuccess(:final croppedImage):
                            final decoded = img.decodeImage(croppedImage);
                            if (decoded == null) {
                              if (mounted) {
                                Navigator.of(context).pop();
                              }
                              return;
                            }
                            final resized = img.copyResize(
                              decoded,
                              width: 600,
                              height: 600,
                            );
                            final finalBytes = Uint8List.fromList(
                              img.encodeJpg(resized, quality: 90),
                            );
                            if (mounted) {
                              Navigator.of(context).pop((
                                bytes: finalBytes,
                                fileName: imageFile.name,
                              ));
                            }
                          case CropFailure():
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Drag and zoom the image, then save the 600 x 600 result.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: isCropping
                        ? null
                        : () {
                            setDialogState(() {
                              isCropping = true;
                            });
                            controller.crop();
                          },
                    child: Text(isCropping ? '正在裁剪...' : '保存照片'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showRecordDialog({Map<String, dynamic>? item}) async {
    final isEdit = item != null;
    final typeOptions = ['收入', '支出'];
    String selectedType = item?['type'] as String? ?? '收入';
    final dateController = TextEditingController(
      text: item != null ? item['recordDate'] as String? ?? '' : '',
    );
    final amountController = TextEditingController(
      text: item != null ? (item['amount']?.toString() ?? '') : '',
    );
    final noteController = TextEditingController(
      text: item?['note'] as String? ?? '',
    );
    Uint8List? imageBytes = item?['imageBytes'] as Uint8List?;
    String? imageUrl = item?['imagePath'] as String?;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '编辑财务记录' : '添加财务记录'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: typeOptions.map((option) {
                        final selected = selectedType == option;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedType = option;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(labelText: '金额'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dateController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: '日期'),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: item != null
                              ? DateTime.tryParse(
                                      item['recordDate'] as String,
                                    ) ??
                                    DateTime.now()
                              : DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (selected != null) {
                          setDialogState(() {
                            dateController.text = selected
                                .toIso8601String()
                                .split('T')
                                .first;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: '备注'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.image),
                      label: Text(
                        imageBytes != null || (imageUrl?.isNotEmpty == true)
                            ? '更换照片'
                            : '选择照片',
                      ),
                      onPressed: () async {
                        final picked = await _pickAndCropPhoto();
                        if (picked != null) {
                          setDialogState(() {
                            imageBytes = picked.bytes;
                            imageUrl = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    if (imageBytes != null)
                      GestureDetector(
                        onTap: () => _showZoomableImage(imageBytes: imageBytes),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            imageBytes!,
                            width: 180,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else if (imageUrl?.isNotEmpty == true)
                      GestureDetector(
                        onTap: () => _showZoomableImage(imageUrl: imageUrl),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _displayImageUrl(imageUrl!),
                            width: 180,
                            height: 180,
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.photo,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
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
                  final amount =
                      double.tryParse(amountController.text.trim()) ?? 0;
                  final selectedDate = dateController.text.trim();
                  if (selectedDate.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('请选择日期')));
                    }
                    return;
                  }
                  try {
                    final success = isEdit
                        ? await _service.updateFinanceRecord(
                            item!['id'] as int,
                            selectedType,
                            selectedDate,
                            imageBytes,
                            amount,
                            noteController.text.trim(),
                          )
                        : await _service.addFinanceRecord(
                            selectedType,
                            selectedDate,
                            imageBytes,
                            amount,
                            noteController.text.trim(),
                          );
                    if (success) {
                      await _loadRecords();
                      if (mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      _showMessage('保存失败: $e');
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

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    final summary = _calculateSummary(filtered);
    return Scaffold(
      appBar: AppBar(
        title: const Text('财务'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadRecords),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : Column(
                children: [
                  // 日期显示区域
                  Card(
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '当前日期: ${_formatFriendlyDate(DateTime.now())}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('添加财务记录'),
                          onPressed: () => _showRecordDialog(),
                        ),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.print_outlined),
                          label: const Text('导出财务记录'),
                          onPressed: _isLoading ? null : _exportRecords,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _records.isEmpty
                        ? const Center(child: Text('没有记录'))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Card(
                                elevation: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: [
                                          _buildSummaryTile(
                                            context,
                                            '收入总计',
                                            summary['income'] ?? 0,
                                          ),
                                          _buildSummaryTile(
                                            context,
                                            '支出总计',
                                            summary['expense'] ?? 0,
                                          ),
                                          _buildSummaryTile(
                                            context,
                                            '剩余金额',
                                            summary['remaining'] ?? 0,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: FinanceFilterPeriod.values
                                              .map((period) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: ChoiceChip(
                                                    label: Text(
                                                      _filterLabel(period),
                                                    ),
                                                    selected:
                                                        _selectedPeriod ==
                                                        period,
                                                    onSelected: (selected) {
                                                      if (selected) {
                                                        setState(() {
                                                          _selectedPeriod =
                                                              period;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Row(
                                          children: FinanceRecordTypeFilter
                                              .values
                                              .map((typeFilter) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 8.0,
                                                      ),
                                                  child: ChoiceChip(
                                                    label: Text(
                                                      _typeFilterLabel(
                                                        typeFilter,
                                                      ),
                                                    ),
                                                    selected:
                                                        _selectedTypeFilter ==
                                                        typeFilter,
                                                    onSelected: (selected) {
                                                      if (selected) {
                                                        setState(() {
                                                          _selectedTypeFilter =
                                                              typeFilter;
                                                        });
                                                      }
                                                    },
                                                  ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (_selectedPeriod !=
                                          FinanceFilterPeriod.all)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _filterSelectionLabel(),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ),
                                            FilledButton.icon(
                                              icon: const Icon(
                                                Icons.date_range,
                                              ),
                                              label: const Text('选择日期'),
                                              onPressed: _pickFilterDate,
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: Scrollbar(
                                  controller: _financeListController,
                                  thumbVisibility: true,
                                  child: ListView.builder(
                                    controller: _financeListController,
                                    physics:
                                        const AlwaysScrollableScrollPhysics(),
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final item = filtered[index];
                                      final imagePath =
                                          item['imagePath'] as String?;
                                      return Card(
                                        child: ListTile(
                                          leading: GestureDetector(
                                            onTap:
                                                imagePath != null &&
                                                    imagePath.isNotEmpty
                                                ? () => _showZoomableImage(
                                                    imageUrl: imagePath,
                                                  )
                                                : null,
                                            child: Container(
                                              width: 62,
                                              height: 62,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                color: Colors.grey[200],
                                              ),
                                              child:
                                                  imagePath != null &&
                                                      imagePath.isNotEmpty
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                      child: Image.network(
                                                        _displayImageUrl(
                                                          imagePath,
                                                        ),
                                                        width: 62,
                                                        height: 62,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.photo,
                                                      size: 32,
                                                      color: Colors.grey,
                                                    ),
                                            ),
                                          ),
                                          title: Text(
                                            '${item['type']}  ￥${_formatAmount(item['amount'])}',
                                          ),
                                          subtitle: Text(
                                            '${item['recordDate']} · ${item['note'] ?? ''}',
                                          ),
                                          trailing: Wrap(
                                            spacing: 4,
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                onPressed: () =>
                                                    _showRecordDialog(
                                                      item: item,
                                                    ),
                                                tooltip: '编辑',
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () => _confirmDelete(
                                                  item['id'] as int,
                                                ),
                                                tooltip: '删除',
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这条记录吗？'),
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
    if (confirmed == true) {
      try {
        final success = await _service.deleteFinanceRecord(id);
        if (success) {
          await _loadRecords();
        }
      } catch (e) {
        _showMessage('删除失败: $e');
      }
    }
  }
}

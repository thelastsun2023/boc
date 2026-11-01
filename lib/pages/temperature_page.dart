import 'dart:math' as math;
import 'dart:convert';
import '../services/browser_print.dart';

import 'package:flutter/material.dart';

import '../services/system_service.dart';
import '../widgets/product_image.dart';

class TemperaturePage extends StatefulWidget {
  const TemperaturePage({super.key});

  @override
  State<TemperaturePage> createState() => _TemperaturePageState();
}

class _TemperaturePageState extends State<TemperaturePage> {
  final _service = SystemService();
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _service.getTemperatureDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _addRecord(Map<String, dynamic> device) async {
    final temperatureController = TextEditingController();
    final noteController = TextEditingController();
    var recordedAt = DateTime.now();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('记录温度 · ${device['name']}'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: temperatureController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '温度（°C）',
                    suffixText: '°C',
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('记录时间'),
                  subtitle: Text(_dateTimeText(recordedAt)),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: recordedAt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(recordedAt),
                    );
                    if (time == null) return;
                    setDialogState(() {
                      recordedAt = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        time.hour,
                        time.minute,
                      );
                    });
                  },
                ),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    final value = double.tryParse(temperatureController.text.trim());
    if (value == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请输入正确的温度')),
        );
      }
      return;
    }
    try {
      await _service.addTemperatureRecord(
        deviceId: device['id'] as int,
        temperature: value,
        recordedAt: recordedAt,
        note: noteController.text.trim(),
      );
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败：$e')),
        );
      }
    }
  }

  bool _isAlert(Map<String, dynamic> device) {
    final value = (device['latestTemperature'] as num?)?.toDouble();
    if (value == null) return false;
    final low = (device['lowerLimit'] as num).toDouble();
    final high = (device['upperLimit'] as num).toDouble();
    return value < low || value > high;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('温度记录'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _devices.isEmpty
                  ? const Center(child: Text('暂无温度设备，请先在系统管理中添加。'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 430,
                          mainAxisExtent: 190,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          final latest =
                              (device['latestTemperature'] as num?)?.toDouble();
                          final alert = _isAlert(device);
                          return Card(
                            color: alert ? Colors.red.shade50 : null,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) => TemperatureDetailPage(
                                        device: device,
                                      ),
                                    ),
                                  )
                                  .then((_) => _load()),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Row(
                                  children: [
                                    ProductImage(
                                      url: device['imageUrl'] as String? ??
                                          device['imagePath'] as String?,
                                      title: device['name'] as String? ?? '',
                                      width: 108,
                                      height: 140,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            device['name'] as String? ?? '',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge,
                                          ),
                                          Text('位置：${device['location']}'),
                                          const Spacer(),
                                          Text(
                                            latest == null
                                                ? '暂无记录'
                                                : '${latest.toStringAsFixed(1)} °C',
                                            style: Theme.of(context)
                                                .textTheme
                                                .headlineMedium
                                                ?.copyWith(
                                                  color: alert
                                                      ? Colors.red
                                                      : Colors.teal,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                          Text(
                                            '范围 ${device['lowerLimit']} ～ ${device['upperLimit']} °C',
                                          ),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('点击查看曲线'),
                                              IconButton(
                                                tooltip: '记录温度',
                                                onPressed: () => _addRecord(device),
                                                icon: const Icon(Icons.add_chart),
                                              ),
                                            ],
                                          ),
                                        ],
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
    );
  }
}

class TemperatureDetailPage extends StatefulWidget {
  const TemperatureDetailPage({super.key, required this.device});
  final Map<String, dynamic> device;

  @override
  State<TemperatureDetailPage> createState() => _TemperatureDetailPageState();
}

class _TemperatureDetailPageState extends State<TemperatureDetailPage> {
  final _service = SystemService();
  bool _month = false;
  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  List<Map<String, dynamic>> _records = [];
  String? _error;

  DateTime get _start {
    if (_month) return DateTime(_selectedDate.year, _selectedDate.month, 1);
    final day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  DateTime get _end => _month
      ? DateTime(_start.year, _start.month + 1, 1)
      : _start.add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await _service.getTemperatureRecords(
        deviceId: widget.device['id'] as int,
        from: _start,
        to: _end,
      );
      if (!mounted) return;
      setState(() {
        _records = records;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lower = (widget.device['lowerLimit'] as num).toDouble();
    final upper = (widget.device['upperLimit'] as num).toDouble();
    return Scaffold(
      appBar: AppBar(title: Text('${widget.device['name']} · 温度曲线'), actions: [
        TextButton(onPressed: () async {
          final date = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2026, 5),
            lastDate: DateTime.now(),
            helpText: _month ? '选择月份内任意日期' : '选择星期内任意日期',
          );
          if (date != null) {
            setState(() => _selectedDate = date);
            await _load();
          }
        }, child: const Text('选择日期')),
        TextButton(onPressed: _loading ? null : () async {
          const escape=HtmlEscape();
          final rows=_records.map((r)=>'<tr><td>${escape.convert(r['recordedAt'].toString())}</td><td>${r['temperature']}</td><td>${escape.convert((r['note']??'').toString())}</td></tr>').join();
          await printHtmlDocument(title:'温度记录',htmlContent:'<h1>${escape.convert(widget.device['name'].toString())}</h1><p>${_dateText(_start)} ~ ${_dateText(_end.subtract(const Duration(days:1)))}</p><table border="1" cellpadding="8"><tr><th>时间 / Time</th><th>温度 / °C</th><th>备注 / Corrective action</th></tr>$rows</table>');
        }, child: const Text('导出 / PDF')),
      ]),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('本周')),
                    ButtonSegment(value: true, label: Text('本月')),
                  ],
                  selected: {_month},
                  onSelectionChanged: (value) {
                    setState(() => _month = value.first);
                    _load();
                  },
                ),
                const SizedBox(width: 16),
                Text(
                  '${_dateText(_start)} ～ ${_dateText(_end.subtract(const Duration(days: 1)))}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Text('正常范围：$lower ～ $upper °C'),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 340,
              width: double.infinity,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(child: Text(_error!))
                          : _records.isEmpty
                              ? const Center(child: Text('此时间段暂无温度记录'))
                              : CustomPaint(
                                  painter: _TemperatureChartPainter(
                                    records: _records,
                                    start: _start,
                                    end: _end,
                                    lowerLimit: lower,
                                    upperLimit: upper,
                                  ),
                                  child: const SizedBox.expand(),
                                ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('详细记录', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _records.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final record = _records[_records.length - 1 - index];
                  final value = (record['temperature'] as num).toDouble();
                  final alert = value < lower || value > upper;
                  return ListTile(
                    leading: Icon(
                      alert ? Icons.warning_amber : Icons.thermostat,
                      color: alert ? Colors.red : Colors.teal,
                    ),
                    title: Text('${value.toStringAsFixed(1)} °C'),
                    subtitle: Text(
                      '${record['recordedAt']}${(record['note'] ?? '').toString().isEmpty ? '' : ' · ${record['note']}'}',
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

class _TemperatureChartPainter extends CustomPainter {
  const _TemperatureChartPainter({
    required this.records,
    required this.start,
    required this.end,
    required this.lowerLimit,
    required this.upperLimit,
  });

  final List<Map<String, dynamic>> records;
  final DateTime start;
  final DateTime end;
  final double lowerLimit;
  final double upperLimit;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 48.0;
    const bottom = 30.0;
    const top = 16.0;
    final width = size.width - left - 10;
    final height = size.height - top - bottom;
    final values = records
        .map((record) => (record['temperature'] as num).toDouble())
        .toList();
    final minValue = (math.min(
              lowerLimit,
              values.reduce((a, b) => math.min(a, b).toDouble()),
            ) -
            1)
        .toDouble();
    final maxValue = (math.max(
              upperLimit,
              values.reduce((a, b) => math.max(a, b).toDouble()),
            ) +
            1)
        .toDouble();
    final valueRange = math.max(1.0, maxValue - minValue);
    final timeRange = end.difference(start).inMilliseconds.toDouble();
    final axisPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1;
    canvas.drawLine(
      const Offset(left, top),
      Offset(left, top + height),
      axisPaint,
    );
    canvas.drawLine(
      Offset(left, top + height),
      Offset(left + width, top + height),
      axisPaint,
    );

    double yFor(double value) =>
        top + height - ((value - minValue) / valueRange) * height;
    double xFor(DateTime time) => left +
        (time.difference(start).inMilliseconds / timeRange)
                .clamp(0.0, 1.0)
                .toDouble() *
            width;

    void limitLine(double value, Color color, String label) {
      final y = yFor(value);
      canvas.drawLine(
        Offset(left, y),
        Offset(left + width, y),
        Paint()
          ..color = color.withValues(alpha: .65)
          ..strokeWidth = 1.5,
      );
      _drawText(canvas, label, Offset(2, y - 8), color, 11);
    }

    limitLine(upperLimit, Colors.red, '${upperLimit.toStringAsFixed(1)}°');
    limitLine(lowerLimit, Colors.orange, '${lowerLimit.toStringAsFixed(1)}°');

    final points = <Offset>[];
    for (final record in records) {
      final time = DateTime.tryParse(record['recordedAt'].toString());
      if (time == null) continue;
      points.add(
        Offset(
          xFor(time),
          yFor((record['temperature'] as num).toDouble()),
        ),
      );
    }
    if (points.isNotEmpty) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.teal
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      for (var i = 0; i < points.length; i++) {
        final value = values[i];
        final alert = value < lowerLimit || value > upperLimit;
        canvas.drawCircle(
          points[i],
          4,
          Paint()..color = alert ? Colors.red : Colors.teal,
        );
      }
    }
    _drawText(canvas, _dateText(start), Offset(left, top + height + 8), Colors.grey.shade700, 11);
    final endLabel = _dateText(end.subtract(const Duration(days: 1)));
    _drawText(canvas, endLabel, Offset(left + width - 62, top + height + 8), Colors.grey.shade700, 11);
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size)),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TemperatureChartPainter oldDelegate) => true;
}

String _two(int value) => value.toString().padLeft(2, '0');
String _dateText(DateTime value) => '${value.year}-${_two(value.month)}-${_two(value.day)}';
String _dateTimeText(DateTime value) =>
    '${_dateText(value)} ${_two(value.hour)}:${_two(value.minute)}';

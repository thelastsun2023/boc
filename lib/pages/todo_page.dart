import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/session_service.dart';
import '../services/system_service.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final SystemService _service = SystemService();
  final List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _error;
  String _statusFilter = '全部';
  DateTime? _startDate;
  DateTime? _endDate;

  static const List<String> _statusOptions = ['未做完', '已做完', '有问题'];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
      final tasks = await _service.getTodoTasks();
      if (!mounted) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(tasks);
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

  List<Map<String, dynamic>> get _filteredTasks {
    return _tasks.where((task) {
      final status = task['status'] as String? ?? '';
      if (_statusFilter != '全部' && status != _statusFilter) {
        return false;
      }

      final dueText = task['dueDateTime'] as String?;
      if (dueText != null && dueText.isNotEmpty) {
        final due = DateTime.tryParse(dueText);
        if (due != null) {
          if (_startDate != null && due.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null &&
              due.isAfter(
                _endDate!
                    .add(const Duration(days: 1))
                    .subtract(const Duration(milliseconds: 1)),
              )) {
            return false;
          }
        }
      }
      return true;
    }).toList();
  }

  String _formatDateTime(String? value) {
    if (value == null || value.isEmpty) {
      return '-';
    }
    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) {
      return value;
    }
    return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _statusCardColor(String status) {
    switch (status) {
      case '已做完':
        return Colors.green.shade50;
      case '未做完':
        return Colors.yellow.shade100;
      case '有问题':
        return Colors.red.shade50;
      default:
        return Colors.grey.shade50;
    }
  }

  Color _statusChipColor(String status) {
    switch (status) {
      case '已做完':
        return Colors.green.shade100;
      case '未做完':
        return Colors.yellow.shade200;
      case '有问题':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _statusLabelColor(String status) {
    return Colors.black87;
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null) {
      return null;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _showTaskDialog({Map<String, dynamic>? task}) async {
    final isEdit = task != null;
    final titleController = TextEditingController(
      text: task?['title'] as String? ?? '',
    );
    final contentController = TextEditingController(
      text: task?['content'] as String? ?? '',
    );
    final noteController = TextEditingController(
      text: task?['note'] as String? ?? '',
    );
    final dueDateTimeController = TextEditingController(
      text: _formatDateTime(task?['dueDateTime'] as String?),
    );
    String selectedStatus = task?['status'] as String? ?? '未做完';
    DateTime? selectedDateTime = task?['dueDateTime'] != null
        ? DateTime.tryParse(task!['dueDateTime'] as String)
        : null;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? '编辑要做的事' : '添加要做的事'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: '主标题'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      decoration: const InputDecoration(labelText: '内容'),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(labelText: '备注'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(labelText: '状态'),
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dueDateTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: '日期时间'),
                      onTap: () async {
                        final picked = await _pickDateTime(selectedDateTime);
                        if (picked != null) {
                          setDialogState(() {
                            selectedDateTime = picked;
                            dueDateTimeController.text = _formatDateTime(
                              picked.toIso8601String(),
                            );
                          });
                        }
                      },
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
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  final note = noteController.text.trim();
                  if (title.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('请输入主标题')));
                    }
                    return;
                  }
                  if (selectedDateTime == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('请选择日期时间')));
                    }
                    return;
                  }
                  try {
                    final success = isEdit
                        ? await _service.updateTodoTask(
                            task['id'] as int,
                            title,
                            content,
                            note,
                            selectedDateTime!.toIso8601String(),
                            selectedStatus,
                            ownerUsername:
                                task['ownerUsername'] as String? ??
                                SessionService().username,
                          )
                        : await _service.addTodoTask(
                            title,
                            content,
                            note,
                            selectedDateTime!.toIso8601String(),
                            selectedStatus,
                            ownerUsername: SessionService().username,
                          );
                    if (success) {
                      await _loadTasks();
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

  Future<void> _confirmDelete(int id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确认删除 "$title" 吗？'),
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

    if (confirmed != true) return;
    try {
      final success = await _service.deleteTodoTask(id);
      if (success) {
        await _loadTasks();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('删除失败: $e');
      }
    }
  }

  Future<void> _markCompleted(Map<String, dynamic> task) async {
    try {
      final id = task['id'] as int;
      await _service.updateTodoTask(
        id,
        task['title'] as String? ?? '',
        task['content'] as String? ?? '',
        task['note'] as String? ?? '',
        task['dueDateTime'] as String? ?? DateTime.now().toIso8601String(),
        '已做完',
      );
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        _showMessage('标记已完成失败: $e');
      }
    }
  }

  Future<void> _copyTaskToClipboard(Map<String, dynamic> task) async {
    final title = task['title'] as String? ?? '';
    final dateTime = _formatDateTime(task['dueDateTime'] as String?);
    final content = task['content'] as String? ?? '';
    final copyText = '$title $dateTime $content';
    await Clipboard.setData(ClipboardData(text: copyText));
    if (mounted) {
      _showMessage('已复制：$title $dateTime');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTasks;
    return Scaffold(
      appBar: AppBar(
        title: const Text('要做的事'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildFilterSection(),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : filtered.isEmpty
                  ? const Center(child: Text('没有任务'))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final task = filtered[index];
                        final ownerUsername = (task['ownerUsername'] as String?)
                            ?.trim();
                        final storeCode =
                          (task['storeCode'] as String?)?.trim() ?? '';
                        final status = task['status'] as String? ?? '未做完';
                        return Card(
                          color: _statusCardColor(status),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        task['title'] as String? ?? '',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Chip(
                                      backgroundColor: _statusChipColor(status),
                                      label: Text(
                                        status,
                                        style: TextStyle(
                                          color: _statusLabelColor(status),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '日期时间: ${_formatDateTime(task['dueDateTime'] as String?)}',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '归属人: ${ownerUsername?.isNotEmpty == true ? ownerUsername : (SessionService().username ?? '-')}',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '门店: ${storeCode.isEmpty ? '未标记' : storeCode}',
                                ),
                                const SizedBox(height: 8),
                                Text('内容: ${task['content'] as String? ?? ''}'),
                                const SizedBox(height: 6),
                                Text('备注: ${task['note'] as String? ?? ''}'),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if ((task['status'] as String?) != '已做完')
                                      FilledButton(
                                        onPressed: () => _markCompleted(task),
                                        child: const Text('已完成'),
                                      ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () =>
                                          _copyTaskToClipboard(task),
                                      icon: const Icon(Icons.copy_outlined),
                                      tooltip: '复制到剪贴板',
                                    ),
                                    IconButton(
                                      onPressed: () =>
                                          _showTaskDialog(task: task),
                                      icon: const Icon(Icons.edit_outlined),
                                      tooltip: '编辑',
                                    ),
                                    IconButton(
                                      onPressed: () => _confirmDelete(
                                        task['id'] as int,
                                        task['title'] as String? ?? '',
                                      ),
                                      icon: const Icon(Icons.delete_outline),
                                      tooltip: '删除',
                                    ),
                                  ],
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTaskDialog(),
        icon: const Icon(Icons.add),
        label: const Text('添加任务'),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(labelText: '状态筛选'),
                    items: const [
                      DropdownMenuItem(value: '全部', child: Text('全部')),
                      DropdownMenuItem(value: '未做完', child: Text('未做完')),
                      DropdownMenuItem(value: '已做完', child: Text('已做完')),
                      DropdownMenuItem(value: '有问题', child: Text('有问题')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _statusFilter = value;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '开始日期'),
                      child: Text(
                        _startDate == null
                            ? '全部'
                            : '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setState(() {
                          _endDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: '结束日期'),
                      child: Text(
                        _endDate == null
                            ? '全部'
                            : '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _statusFilter = '全部';
                      _startDate = null;
                      _endDate = null;
                    });
                  },
                  child: const Text('清除筛选'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

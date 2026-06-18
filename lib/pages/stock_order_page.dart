import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/session_service.dart';
import '../services/system_service.dart';

class StockOrderPage extends StatefulWidget {
  final bool showAppBar;

  const StockOrderPage({super.key, this.showAppBar = true});

  @override
  State<StockOrderPage> createState() => _StockOrderPageState();
}

class _StockOrderPageState extends State<StockOrderPage> {
  final SystemService _service = SystemService();
  final List<Map<String, dynamic>> _orders = [];
  final List<Map<String, dynamic>> _rawMaterials = [];
  final Map<String, ScrollController> _tabScrollControllers = {};
  final Set<int> _processingOrderIds = <int>{};
  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> get _visibleRawMaterials {
    final session = SessionService();
    if (session.isAdmin) {
      return _rawMaterials;
    }
    return _rawMaterials.where((item) {
      return session.canAccessCategory(item['categoryCode'] as String?);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  ScrollController _controllerForCategory(String category) {
    return _tabScrollControllers.putIfAbsent(
      category,
      () => ScrollController(),
    );
  }

  @override
  void dispose() {
    for (final controller in _tabScrollControllers.values) {
      controller.dispose();
    }
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
      final materials = await _service.getRawMaterials();
      final orders = await _service.getStockOrders();
      if (!mounted) return;
      setState(() {
        _rawMaterials
          ..clear()
          ..addAll(materials);
        _orders
          ..clear()
          ..addAll(orders);
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

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.round() ?? 0;
    }
    return 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  String _formatDate(String value) {
    if (value.isEmpty) return '-';
    final dateTime = DateTime.tryParse(value);
    if (dateTime == null) return value;
    return '${dateTime.year.toString().padLeft(4, '0')}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
  }

  String _formatChineseDate(DateTime date) {
    return '${date.year}年${date.month.toString().padLeft(2, '0')}月${date.day.toString().padLeft(2, '0')}日';
  }

  int _suggestedOrderQuantity(int currentStock, double minQuantity) {
    return max(0, minQuantity.ceil() - currentStock);
  }

  String _normalizedSupplierCode(dynamic value) {
    final code = (value as String? ?? '').trim();
    return code.isEmpty ? 'UNKNOWN' : code;
  }

  String _bilingualText(String? nameCN, String? nameEN) {
    final cn = (nameCN ?? '').trim();
    final en = (nameEN ?? '').trim();
    if (cn.isEmpty) {
      return en;
    }
    if (en.isEmpty) {
      return cn;
    }
    return SessionService().isEnglish ? '$en / $cn' : '$cn / $en';
  }

  List<Map<String, dynamic>> _normalizeOrderDetails(dynamic details) {
    if (details is List) {
      return details.map((item) {
        if (item is Map<String, dynamic>) {
          return item;
        }
        if (item is Map) {
          return Map<String, dynamic>.from(item);
        }
        return <String, dynamic>{};
      }).toList();
    }
    if (details is String) {
      try {
        final decoded = jsonDecode(details);
        if (decoded is List) {
          return decoded.map((item) {
            if (item is Map<String, dynamic>) {
              return item;
            }
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return <String, dynamic>{};
          }).toList();
        }
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  Future<void> _showOrderDialog({Map<String, dynamic>? order}) async {
    final bool isEdit = order != null;
    final DateTime orderDate = isEdit
        ? DateTime.parse(order['orderDate'] as String)
        : DateTime.now();
    bool isConfirmed = order?['isConfirmed'] == true;
    bool isSubmitting = false;

    final List<Map<String, dynamic>> items = [];

    if (isEdit) {
      final existingDetails = _normalizeOrderDetails(order['details']);
      for (final raw in existingDetails) {
        items.add({
          'code': raw['code'] ?? '',
          'nameCN': raw['nameCN'] ?? '',
          'nameEN': raw['nameEN'] ?? '',
          'description': raw['description'] ?? '',
          'currentStock': _toInt(raw['currentStock']),
          'minQuantity': _toDouble(raw['minQuantity']),
          'orderQuantity': _toInt(raw['orderQuantity']),
          'primarySupplierCode': raw['primarySupplierCode'],
          'primarySupplierName': raw['primarySupplierName'],
          'secondarySupplierCode': raw['secondarySupplierCode'],
          'secondarySupplierName': raw['secondarySupplierName'],
          'categoryName': raw['categoryName'] ?? '未分类',
        });
      }
    } else {
      for (final raw in _visibleRawMaterials) {
        final minQuantity = _toDouble(raw['minQuantity']);
        items.add({
          'code': raw['code'] ?? '',
          'nameCN': raw['nameCN'] ?? '',
          'nameEN': raw['nameEN'] ?? '',
          'description': raw['specification'] ?? '',
          'currentStock': 0,
          'minQuantity': minQuantity,
          'orderQuantity': _suggestedOrderQuantity(0, minQuantity),
          'primarySupplierCode': raw['primarySupplierCode'],
          'primarySupplierName': raw['primarySupplierName'],
          'secondarySupplierCode': raw['secondarySupplierCode'],
          'secondarySupplierName': raw['secondarySupplierName'],
          'categoryName': raw['categoryName'] ?? '未分类',
        });
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final categoryGroups = <String, List<Map<String, dynamic>>>{};
            for (final item in items) {
              final category =
                  (item['categoryName'] as String?)?.trim().isNotEmpty == true
                  ? item['categoryName'] as String
                  : '未分类';
              categoryGroups.putIfAbsent(category, () => []).add(item);
            }
            final categories = categoryGroups.keys.toList();
            return AlertDialog(
              title: Text(isEdit ? '编辑点货记录' : '新建点货'),
              content: SizedBox(
                width: 920,
                height: 560,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('点货日期：${_formatDate(orderDate.toIso8601String())}'),
                    const SizedBox(height: 12),
                    Expanded(
                      child: items.isEmpty
                          ? const Center(child: Text('没有原材料记录'))
                          : DefaultTabController(
                              length: categories.length,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    child: TabBar(
                                      isScrollable: true,
                                      labelColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      unselectedLabelColor: Colors.black54,
                                      indicatorColor: Theme.of(
                                        context,
                                      ).primaryColor,
                                      tabs: categories
                                          .map(
                                            (category) => Tab(text: category),
                                          )
                                          .toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Expanded(
                                    child: TabBarView(
                                      children: categories.map((category) {
                                        final groupItems =
                                            categoryGroups[category]!;
                                        final controller =
                                            _controllerForCategory(category);
                                        return Scrollbar(
                                          controller: controller,
                                          thumbVisibility: true,
                                          interactive: true,
                                          child: ListView.builder(
                                            controller: controller,
                                            physics:
                                                const AlwaysScrollableScrollPhysics(),
                                            padding: EdgeInsets.zero,
                                            itemCount: groupItems.length,
                                            itemBuilder: (context, index) {
                                              final item = groupItems[index];
                                              final currentStock = _toInt(
                                                item['currentStock'],
                                              );
                                              final minQuantity = _toDouble(
                                                item['minQuantity'],
                                              );
                                              final orderQuantity = _toInt(
                                                item['orderQuantity'],
                                              );
                                              final suggested =
                                                  _suggestedOrderQuantity(
                                                    currentStock,
                                                    minQuantity,
                                                  );
                                              return Container(
                                                margin:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 6,
                                                    ),
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: Colors.grey.shade300,
                                                  ),
                                                ),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _bilingualText(
                                                        item['nameCN']
                                                            as String?,
                                                        item['nameEN']
                                                            as String?,
                                                      ),
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      item['description'] ?? '',
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Wrap(
                                                      spacing: 18,
                                                      runSpacing: 8,
                                                      crossAxisAlignment:
                                                          WrapCrossAlignment
                                                              .center,
                                                      children: [
                                                        _buildStepper(
                                                          label: '当前库存',
                                                          value: currentStock,
                                                          onChanged: (value) {
                                                            final newValue =
                                                                max(0, value);
                                                            setDialogState(() {
                                                              item['currentStock'] =
                                                                  newValue;
                                                              item['orderQuantity'] =
                                                                  _suggestedOrderQuantity(
                                                                    newValue,
                                                                    minQuantity,
                                                                  );
                                                            });
                                                          },
                                                        ),
                                                        Text(
                                                          '最少储存：${minQuantity.toStringAsFixed(minQuantity.truncateToDouble() == minQuantity ? 0 : 2)}',
                                                        ),
                                                        _buildStepper(
                                                          label: '订货数量',
                                                          value: orderQuantity,
                                                          onChanged: (value) {
                                                            setDialogState(() {
                                                              item['orderQuantity'] =
                                                                  max(0, value);
                                                            });
                                                          },
                                                        ),
                                                        FilledButton(
                                                          style: FilledButton.styleFrom(
                                                            backgroundColor:
                                                                Colors
                                                                    .grey
                                                                    .shade200,
                                                            foregroundColor:
                                                                Colors.black87,
                                                            minimumSize:
                                                                const Size(
                                                                  120,
                                                                  40,
                                                                ),
                                                          ),
                                                          onPressed: () {
                                                            setDialogState(() {
                                                              item['orderQuantity'] =
                                                                  0;
                                                            });
                                                          },
                                                          child: const Text(
                                                            '今天不定',
                                                          ),
                                                        ),
                                                        Text('建议订货：$suggested'),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                OutlinedButton(
                  onPressed: isConfirmed || isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          final selectedItems = items
                              .where(
                                (item) => _toInt(item['orderQuantity']) > 0,
                              )
                              .toList();
                          if (selectedItems.isEmpty) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先填写订货数量')),
                              );
                            }
                            return;
                          }

                          try {
                            final details = items.map((item) {
                              return {
                                'code': item['code'],
                                'nameCN': item['nameCN'],
                                'nameEN': item['nameEN'],
                                'description': item['description'],
                                'currentStock': item['currentStock'],
                                'minQuantity': item['minQuantity'],
                                'orderQuantity': item['orderQuantity'],
                                'primarySupplierCode':
                                    item['primarySupplierCode'],
                                'primarySupplierName':
                                    item['primarySupplierName'],
                                'secondarySupplierCode':
                                    item['secondarySupplierCode'],
                                'secondarySupplierName':
                                    item['secondarySupplierName'],
                                'categoryName': item['categoryName'],
                              };
                            }).toList();

                            final orderDateString =
                                '${orderDate.year.toString().padLeft(4, '0')}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';
                            if (isEdit) {
                              await _service.updateStockOrder(
                                order['id'] as int,
                                details,
                                false,
                              );
                            } else {
                              final createdOrderId = await _service
                                  .addStockOrder(
                                    orderDateString,
                                    details,
                                    false,
                                  );
                              if (createdOrderId == null) {
                                throw Exception('点货单创建失败，未返回编号');
                              }
                            }

                            await _loadData();
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('整单已保存，可继续修改后再确认'),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('保存整单失败: $e')),
                              );
                            }
                          }
                        },
                  child: Text(isEdit ? '保存整单' : '生成整单'),
                ),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setDialogState(() {
                            isSubmitting = true;
                          });
                          final selectedItems = items
                              .where(
                                (item) => _toInt(item['orderQuantity']) > 0,
                              )
                              .toList();
                          if (selectedItems.isEmpty) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('请先填写订货数量')),
                              );
                            }
                            return;
                          }

                          try {
                            int orderId;
                            final details = items.map((item) {
                              return {
                                'code': item['code'],
                                'nameCN': item['nameCN'],
                                'nameEN': item['nameEN'],
                                'description': item['description'],
                                'currentStock': item['currentStock'],
                                'minQuantity': item['minQuantity'],
                                'orderQuantity': item['orderQuantity'],
                                'primarySupplierCode':
                                    item['primarySupplierCode'],
                                'primarySupplierName':
                                    item['primarySupplierName'],
                                'secondarySupplierCode':
                                    item['secondarySupplierCode'],
                                'secondarySupplierName':
                                    item['secondarySupplierName'],
                                'categoryName': item['categoryName'],
                              };
                            }).toList();

                            final orderDateString =
                                '${orderDate.year.toString().padLeft(4, '0')}-${orderDate.month.toString().padLeft(2, '0')}-${orderDate.day.toString().padLeft(2, '0')}';
                            if (isEdit) {
                              orderId = order['id'] as int;
                              await _service.updateStockOrder(
                                orderId,
                                details,
                                true,
                              );
                            } else {
                              final createdOrderId = await _service
                                  .addStockOrder(
                                    orderDateString,
                                    details,
                                    true,
                                  );
                              if (createdOrderId == null) {
                                throw Exception('点货单创建失败，未返回编号');
                              }
                              orderId = createdOrderId;
                            }

                            await _syncTodoTasksForOrder(
                              orderId,
                              orderDate,
                              selectedItems,
                            );
                            isConfirmed = true;

                            await _loadData();
                            if (mounted) {
                              Navigator.of(context).pop();
                            }
                          } catch (e) {
                            setDialogState(() {
                              isSubmitting = false;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('保存失败: $e')),
                              );
                            }
                          }
                        },
                  child: Text(isConfirmed ? '更新已确认任务' : '确认并生成任务'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _syncTodoTasksForOrder(
    int stockOrderId,
    DateTime orderDate,
    List<Map<String, dynamic>> selectedItems,
  ) async {
    if (selectedItems.isEmpty) {
      final existingTasks = await _service.getTodoTasks();
      final linkedTasks = existingTasks.where((task) {
        final taskStockOrderId = _toInt(task['stockOrderId']);
        return (task['taskType'] as String? ?? '').trim() == 'stock_order' &&
            taskStockOrderId == stockOrderId;
      }).toList();
      for (final task in linkedTasks) {
        await _service.deleteTodoTask(_toInt(task['id']));
      }
      return;
    }

    final Map<String, Map<String, dynamic>> supplierGroups = {};

    for (final item in selectedItems) {
      final supplierCode =
          (item['primarySupplierCode'] as String?)?.trim().isNotEmpty == true
          ? _normalizedSupplierCode(item['primarySupplierCode'])
          : ((item['secondarySupplierCode'] as String?)?.trim().isNotEmpty ==
                    true
                ? _normalizedSupplierCode(item['secondarySupplierCode'])
                : 'UNKNOWN');
      final supplierName =
          (item['primarySupplierName'] as String?)?.trim().isNotEmpty == true
          ? item['primarySupplierName'] as String
          : ((item['secondarySupplierName'] as String?)?.trim().isNotEmpty ==
                    true
                ? item['secondarySupplierName'] as String
                : '未知供应商');

      final group = supplierGroups.putIfAbsent(supplierCode, () {
        return {
          'supplierName': supplierName,
          'items': <Map<String, dynamic>>[],
        };
      });
      (group['items'] as List<Map<String, dynamic>>).add(item);
    }

    final existingTasks = await _service.getTodoTasks();
    final linkedTasks = existingTasks.where((task) {
      final taskStockOrderId = _toInt(task['stockOrderId']);
      return (task['taskType'] as String? ?? '').trim() == 'stock_order' &&
          taskStockOrderId == stockOrderId;
    }).toList();
    final linkedTasksBySupplier = <String, List<Map<String, dynamic>>>{};
    for (final task in linkedTasks) {
      final supplierCode = _normalizedSupplierCode(task['supplierCode']);
      linkedTasksBySupplier.putIfAbsent(supplierCode, () => []).add(task);
    }
    final primaryTaskBySupplier = <String, Map<String, dynamic>>{};
    final duplicateTaskIdsToDelete = <int>{};
    for (final entry in linkedTasksBySupplier.entries) {
      final tasks = List<Map<String, dynamic>>.from(entry.value)
        ..sort(
          (left, right) => _toInt(right['id']).compareTo(_toInt(left['id'])),
        );
      primaryTaskBySupplier[entry.key] = tasks.first;
      for (final duplicateTask in tasks.skip(1)) {
        duplicateTaskIdsToDelete.add(_toInt(duplicateTask['id']));
      }
    }

    final dueDateTime = DateTime(
      orderDate.year,
      orderDate.month,
      orderDate.day,
      9,
      0,
    ).toIso8601String();

    for (final entry in supplierGroups.entries) {
      final supplierCode = entry.key;
      final supplierName = entry.value['supplierName'] as String;
      final items = entry.value['items'] as List<Map<String, dynamic>>;
      final categoryGroups = <String, List<Map<String, dynamic>>>{};
      for (final item in items) {
        final categoryName =
            (item['categoryName'] as String?)?.trim().isNotEmpty == true
            ? item['categoryName'] as String
            : '未分类';
        categoryGroups.putIfAbsent(categoryName, () => []).add(item);
      }

      final content = categoryGroups.entries
          .map((categoryEntry) {
            final lines = categoryEntry.value
                .map((item) {
                  final nameCN = item['nameCN'] as String? ?? '';
                  final nameEN = item['nameEN'] as String? ?? '';
                  final quantity = _toInt(item['orderQuantity']);
                  final nameText = _bilingualText(nameCN, nameEN);
                  return '$nameText: $quantity';
                })
                .join('；');
            return '${categoryEntry.key}：$lines';
          })
          .join('\n');

      final title = '${_formatChineseDate(orderDate)} 向$supplierName 订货';
      final existingTask = primaryTaskBySupplier[supplierCode];

      if (existingTask == null) {
        await _service.addTodoTask(
          title,
          content,
          '',
          dueDateTime,
          '未做完',
          ownerUsername: SessionService().username,
          stockOrderId: stockOrderId,
          supplierCode: supplierCode,
          taskType: 'stock_order',
        );
        continue;
      }

      await _service.updateTodoTask(
        existingTask['id'] as int,
        title,
        content,
        existingTask['note'] as String? ?? '',
        dueDateTime,
        existingTask['status'] as String? ?? '未做完',
        ownerUsername:
            existingTask['ownerUsername'] as String? ??
            SessionService().username,
        stockOrderId: stockOrderId,
        supplierCode: supplierCode,
        taskType: 'stock_order',
      );
    }

    final desiredSupplierCodes = supplierGroups.keys.toSet();
    for (final task in linkedTasks) {
      final supplierCode = _normalizedSupplierCode(task['supplierCode']);
      final taskId = _toInt(task['id']);
      if (!desiredSupplierCodes.contains(supplierCode) ||
          duplicateTaskIdsToDelete.contains(taskId)) {
        await _service.deleteTodoTask(taskId);
      }
    }
  }

  Future<void> _confirmDeleteOrder(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定删除该点货记录吗？'),
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
      await _service.deleteStockOrder(id);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  Future<void> _confirmOrder(Map<String, dynamic> order) async {
    final orderId = _toInt(order['id']);
    if (_processingOrderIds.contains(orderId)) {
      return;
    }
    final details = _normalizeOrderDetails(order['details']);
    final selectedItems = details
        .where((item) => _toInt(item['orderQuantity']) > 0)
        .toList();
    if (selectedItems.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('该整单还没有订货项，无法确认')));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认生成任务'),
        content: const Text('确认后会按供应商同步任务，后续仍可编辑并再次更新任务。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      if (mounted) {
        setState(() {
          _processingOrderIds.add(orderId);
        });
      }
      await _service.updateStockOrder(orderId, details, true);
      await _syncTodoTasksForOrder(
        orderId,
        DateTime.parse(order['orderDate'] as String),
        selectedItems,
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('确认失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingOrderIds.remove(orderId);
        });
      }
    }
  }

  Widget _buildStepper({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label：'),
        IconButton(
          iconSize: 32,
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          splashRadius: 30,
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => onChanged(value - 1),
        ),
        Container(
          width: 56,
          alignment: Alignment.center,
          child: Text(
            value.toString(),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          iconSize: 32,
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          splashRadius: 30,
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('点货'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '总记录：${_orders.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => _showOrderDialog(),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('新建点货'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _orders.isEmpty
                        ? const Center(child: Text('暂无点货记录'))
                        : ListView.builder(
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              final details = _normalizeOrderDetails(
                                order['details'],
                              );
                              final selectedDetails = details
                                  .where(
                                    (item) => _toInt(item['orderQuantity']) > 0,
                                  )
                                  .toList();
                              final isConfirmed = order['isConfirmed'] == true;
                              final storeCode =
                                  (order['storeCode'] as String?)?.trim() ?? '';
                              final ownerUsername =
                                  (order['ownerUsername'] as String?)?.trim() ??
                                  '';
                              final isProcessing = _processingOrderIds.contains(
                                _toInt(order['id']),
                              );
                              final orderCount = selectedDetails.length;
                              final supplierNames = selectedDetails
                                  .map(
                                    (item) =>
                                        (item['primarySupplierName'] as String?)
                                                ?.trim()
                                                .isNotEmpty ==
                                            true
                                        ? item['primarySupplierName']
                                        : (item['secondarySupplierName']
                                                      as String?)
                                                  ?.trim()
                                                  .isNotEmpty ==
                                              true
                                        ? item['secondarySupplierName']
                                        : '未知供应商',
                                  )
                                  .toSet()
                                  .join('、');
                              final groupedByCategory =
                                  <String, List<Map<String, dynamic>>>{};
                              for (final item in selectedDetails) {
                                final categoryName =
                                    (item['categoryName'] as String?)
                                            ?.trim()
                                            .isNotEmpty ==
                                        true
                                    ? item['categoryName'] as String
                                    : '未分类';
                                groupedByCategory
                                    .putIfAbsent(categoryName, () => [])
                                    .add(item);
                              }
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '点货日期：${order['orderDate']}',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: '编辑',
                                            onPressed: () =>
                                                _showOrderDialog(order: order),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: '删除',
                                            onPressed: () =>
                                                _confirmDeleteOrder(
                                                  order['id'] as int,
                                                ),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '状态：${isConfirmed ? '已确认' : '整单草稿'}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '门店：${storeCode.isEmpty ? '未标记' : storeCode}  归属人：${ownerUsername.isEmpty ? '-' : ownerUsername}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '订货项：$orderCount，供应商：$supplierNames',
                                      ),
                                      const SizedBox(height: 10),
                                      if (!isConfirmed)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: FilledButton.tonalIcon(
                                            onPressed: isProcessing
                                                ? null
                                                : () => _confirmOrder(order),
                                            icon: const Icon(Icons.task_alt),
                                            label: Text(
                                              isProcessing
                                                  ? '正在生成任务...'
                                                  : '确认生成任务',
                                            ),
                                          ),
                                        ),
                                      if (groupedByCategory.isEmpty)
                                        const Text('暂无订货项')
                                      else
                                        ...groupedByCategory.entries.map((
                                          entry,
                                        ) {
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 8,
                                                  children: entry.value.map((
                                                    item,
                                                  ) {
                                                    final qty = _toInt(
                                                      item['orderQuantity'],
                                                    );
                                                    return Chip(
                                                      label: Text(
                                                        '${_bilingualText(item['nameCN'] as String?, item['nameEN'] as String?)} x$qty',
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
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

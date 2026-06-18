import 'package:flutter/material.dart';

import '../services/menu_service.dart';
import '../services/session_service.dart';

class MenuManagementPage extends StatefulWidget {
  const MenuManagementPage({super.key});

  @override
  State<MenuManagementPage> createState() => _MenuManagementPageState();
}

class _MenuManagementPageState extends State<MenuManagementPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final MenuService _menuService = MenuService();

  final List<Map<String, dynamic>> _menuCategories = [];
  final List<Map<String, dynamic>> _menus = [];

  bool _isLoading = true;
  String? _error;

  bool get _isEnglish => SessionService().isEnglish;

  String _orderedName(String? nameCN, String? nameEN) {
    final cn = nameCN?.trim() ?? '';
    final en = nameEN?.trim() ?? '';
    if (cn.isEmpty) {
      return en.isEmpty ? '-' : en;
    }
    if (en.isEmpty) {
      return cn;
    }
    return _isEnglish ? '$en / $cn' : '$cn / $en';
  }

  String _generateCode(String prefix, int currentCount) {
    return '$prefix${(currentCount + 1).toString().padLeft(3, '0')}';
  }

  String _orDash(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? '-' : text;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final categories = await _menuService.getMenuCategories();
      final menus = await _menuService.getMenus();

      if (!mounted) {
        return;
      }

      setState(() {
        _menuCategories
          ..clear()
          ..addAll(categories);
        _menus
          ..clear()
          ..addAll(menus);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmDelete({
    required String title,
    required Future<bool> Function() onDelete,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Delete $title from the database?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      final success = await onDelete();
      if (success) {
        await _loadAllData();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Delete failed: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('菜单管理')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('菜单管理')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadAllData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('菜单管理'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          indicatorColor: Colors.black,
          tabs: const [
            Tab(text: '菜单分类'),
            Tab(text: '菜单'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildMenuCategoriesTab(), _buildMenusTab()],
      ),
    );
  }

  Widget _buildMenuCategoriesTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddMenuCategoryDialog(),
            icon: const Icon(Icons.add),
            label: const Text('添加菜单分类'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _menuCategories.length,
            itemBuilder: (context, index) {
              final category = _menuCategories[index];
              final displayName = _orderedName(
                category['name_cn'] as String?,
                category['name_en'] as String?,
              );
              return ListTile(
                title: Text('${category['code']} - $displayName'),
                subtitle: const SizedBox.shrink(),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditMenuCategoryDialog(category),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDelete(
                        title: displayName,
                        onDelete: () =>
                            _menuService.deleteMenuCategory(category['code']),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenusTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: () => _showAddMenuDialog(),
            icon: const Icon(Icons.add),
            label: const Text('添加菜单'),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _menus.length,
            itemBuilder: (context, index) {
              final menu = _menus[index];
              final displayName = _orderedName(
                menu['name_cn'] as String?,
                menu['name_en'] as String?,
              );
              final categoryDisplayName = _orderedName(
                menu['category_name_cn'] as String?,
                menu['category_name_en'] as String?,
              );
              return ListTile(
                title: Text('${menu['code']} - $displayName'),
                subtitle: Text('分类: ${_orDash(categoryDisplayName)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditMenuDialog(menu),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _confirmDelete(
                        title: displayName,
                        onDelete: () => _menuService.deleteMenu(menu['code']),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddMenuCategoryDialog() {
    final codeController = TextEditingController(
      text: _generateCode('MC', _menuCategories.length),
    );
    final nameCnController = TextEditingController();
    final nameEnController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加菜单分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(labelText: '自动编号'),
              readOnly: true,
            ),
            TextField(
              controller: nameCnController,
              decoration: const InputDecoration(labelText: '中文名称'),
            ),
            TextField(
              controller: nameEnController,
              decoration: const InputDecoration(labelText: '英文名称'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final success = await _menuService.addMenuCategory(
                  codeController.text,
                  nameCnController.text,
                  nameEnController.text.isEmpty ? null : nameEnController.text,
                );
                if (success) {
                  Navigator.of(context).pop();
                  await _loadAllData();
                }
              } catch (e) {
                _showMessage('添加失败: $e');
              }
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
  }

  void _showEditMenuCategoryDialog(Map<String, dynamic> category) {
    final nameCnController = TextEditingController(text: category['name_cn']);
    final nameEnController = TextEditingController(
      text: category['name_en'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑菜单分类'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: TextEditingController(text: category['code']),
              decoration: const InputDecoration(labelText: '自动编号'),
              readOnly: true,
            ),
            TextField(
              controller: nameCnController,
              decoration: const InputDecoration(labelText: '中文名称'),
            ),
            TextField(
              controller: nameEnController,
              decoration: const InputDecoration(labelText: '英文名称'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              try {
                final success = await _menuService.updateMenuCategory(
                  category['code'],
                  nameCnController.text,
                  nameEnController.text.isEmpty ? null : nameEnController.text,
                );
                if (success) {
                  Navigator.of(context).pop();
                  await _loadAllData();
                }
              } catch (e) {
                _showMessage('更新失败: $e');
              }
            },
            child: const Text('更新'),
          ),
        ],
      ),
    );
  }

  void _showAddMenuDialog() {
    final codeController = TextEditingController(
      text: _generateCode('M', _menus.length),
    );
    final nameCnController = TextEditingController();
    final nameEnController = TextEditingController();
    String? selectedCategoryCode;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('添加菜单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: '自动编号'),
                readOnly: true,
              ),
              TextField(
                controller: nameCnController,
                decoration: const InputDecoration(labelText: '中文名称'),
              ),
              TextField(
                controller: nameEnController,
                decoration: const InputDecoration(labelText: '英文名称'),
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedCategoryCode,
                decoration: const InputDecoration(labelText: '选择菜单分类'),
                items: _menuCategories.map((category) {
                  final displayName = _orderedName(
                    category['name_cn'] as String?,
                    category['name_en'] as String?,
                  );
                  return DropdownMenuItem<String>(
                    value: category['code'],
                    child: Text(displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedCategoryCode = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final success = await _menuService.addMenu(
                    codeController.text,
                    nameCnController.text,
                    nameEnController.text.isEmpty
                        ? null
                        : nameEnController.text,
                    selectedCategoryCode,
                  );
                  if (success) {
                    Navigator.of(context).pop();
                    await _loadAllData();
                  }
                } catch (e) {
                  _showMessage('添加失败: $e');
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditMenuDialog(Map<String, dynamic> menu) {
    final nameCnController = TextEditingController(text: menu['name_cn']);
    final nameEnController = TextEditingController(text: menu['name_en'] ?? '');
    String? selectedCategoryCode = menu['category_code'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('编辑菜单'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: TextEditingController(text: menu['code']),
                decoration: const InputDecoration(labelText: '自动编号'),
                readOnly: true,
              ),
              TextField(
                controller: nameCnController,
                decoration: const InputDecoration(labelText: '中文名称'),
              ),
              TextField(
                controller: nameEnController,
                decoration: const InputDecoration(labelText: '英文名称'),
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedCategoryCode,
                decoration: const InputDecoration(labelText: '选择菜单分类'),
                items: [
                  const DropdownMenuItem<String>(value: null, child: Text('无')),
                  ..._menuCategories.map((category) {
                    final displayName = _orderedName(
                      category['name_cn'] as String?,
                      category['name_en'] as String?,
                    );
                    return DropdownMenuItem<String>(
                      value: category['code'],
                      child: Text(displayName),
                    );
                  }),
                ],
                onChanged: (value) {
                  setState(() => selectedCategoryCode = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final success = await _menuService.updateMenu(
                    menu['code'],
                    nameCnController.text,
                    nameEnController.text.isEmpty
                        ? null
                        : nameEnController.text,
                    selectedCategoryCode,
                  );
                  if (success) {
                    Navigator.of(context).pop();
                    await _loadAllData();
                  }
                } catch (e) {
                  _showMessage('更新失败: $e');
                }
              },
              child: const Text('更新'),
            ),
          ],
        ),
      ),
    );
  }
}

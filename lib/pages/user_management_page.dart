import 'package:flutter/material.dart';

import '../services/system_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final SystemService _systemService = SystemService();
  final List<Map<String, dynamic>> _users = [];
  final List<Map<String, dynamic>> _rawMaterialCategories = [];
  final List<Map<String, dynamic>> _stores = [];

  bool _isLoading = true;
  String? _error;

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

      final users = await _systemService.getUsers();
      final categories = await _systemService.getRawMaterialCategories();
      final stores = await _systemService.getStores();

      if (!mounted) {
        return;
      }

      setState(() {
        _users
          ..clear()
          ..addAll(users);
        _rawMaterialCategories
          ..clear()
          ..addAll(categories);
        _stores
          ..clear()
          ..addAll(stores);
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

  String _categorySummary(Map<String, dynamic> user) {
    final names = List<String>.from(user['allowedCategoryNames'] ?? const []);
    if (names.isEmpty) {
      return '未勾选点货分类';
    }
    return names.join('、');
  }

  Future<void> _showUserDialog({Map<String, dynamic>? user}) async {
    final isEdit = user != null;
    final usernameController = TextEditingController(
      text: user?['username'] as String? ?? '',
    );
    final passwordController = TextEditingController();
    String? selectedStoreCode =
        (user?['storeCode'] as String?)?.trim().isNotEmpty == true
        ? (user?['storeCode'] as String?)!.trim()
        : null;
    String selectedUiLanguage =
        ((user?['uiLanguage'] as String?)?.trim().toUpperCase() == 'EN')
        ? 'EN'
        : 'ZH';
    String selectedRole = (user?['role'] as String? ?? 'USER').toUpperCase();
    final selectedCategoryCodes = <String>{
      ...List<String>.from(user?['allowedCategoryCodes'] ?? const []),
    };
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? '编辑用户' : '新增用户'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: usernameController,
                    readOnly: isEdit,
                    decoration: const InputDecoration(labelText: '用户名'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: isEdit ? '新密码（留空则不修改）' : '密码',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: '角色'),
                    items: const [
                      DropdownMenuItem(value: 'USER', child: Text('普通用户')),
                      DropdownMenuItem(value: 'ADMIN', child: Text('管理员')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedRole = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedUiLanguage,
                    decoration: const InputDecoration(labelText: '网站语言'),
                    items: const [
                      DropdownMenuItem(value: 'ZH', child: Text('中文')),
                      DropdownMenuItem(value: 'EN', child: Text('English')),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setDialogState(() {
                        selectedUiLanguage = value;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedRole == 'ADMIN')
                    const Text('管理员不绑定门店')
                  else
                    DropdownButtonFormField<String>(
                      value:
                          _stores.any(
                            (store) =>
                                (store['code'] as String?) == selectedStoreCode,
                          )
                          ? selectedStoreCode
                          : null,
                      decoration: const InputDecoration(labelText: '门店'),
                      items: _stores.map((store) {
                        final code = store['code'] as String? ?? '';
                        final name = store['name'] as String? ?? code;
                        return DropdownMenuItem<String>(
                          value: code,
                          child: Text('$code - $name'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedStoreCode = value;
                        });
                      },
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    '可点货分类',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (selectedRole == 'ADMIN')
                    const Text('管理员默认可见全部分类，无需勾选。')
                  else if (_rawMaterialCategories.isEmpty)
                    const Text('暂无原材料分类可供勾选。')
                  else
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView(
                        shrinkWrap: true,
                        children: _rawMaterialCategories.map((category) {
                          final code = category['code'] as String? ?? '';
                          final name = category['name'] as String? ?? code;
                          return CheckboxListTile(
                            dense: true,
                            value: selectedCategoryCodes.contains(code),
                            title: Text(name),
                            subtitle: Text(code),
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == true) {
                                  selectedCategoryCodes.add(code);
                                } else {
                                  selectedCategoryCodes.remove(code);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting
                  ? null
                  : () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final username = usernameController.text.trim();
                      final password = passwordController.text;
                      final storeCode = selectedStoreCode?.trim() ?? '';
                      if (username.isEmpty) {
                        return;
                      }
                      if (!isEdit && password.isEmpty) {
                        return;
                      }
                      if (selectedRole != 'ADMIN' && storeCode.isEmpty) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('普通用户必须选择门店')),
                          );
                        }
                        return;
                      }

                      setDialogState(() {
                        isSubmitting = true;
                      });

                      try {
                        final success = isEdit
                            ? await _systemService.updateUser(
                                username: username,
                                password: password.isEmpty ? null : password,
                                role: selectedRole,
                                storeCode: selectedRole == 'ADMIN'
                                    ? null
                                    : storeCode,
                                uiLanguage: selectedUiLanguage,
                                allowedCategoryCodes: selectedRole == 'ADMIN'
                                    ? const []
                                    : selectedCategoryCodes.toList(),
                              )
                            : await _systemService.addUser(
                                username: username,
                                password: password,
                                role: selectedRole,
                                storeCode: selectedRole == 'ADMIN'
                                    ? null
                                    : storeCode,
                                uiLanguage: selectedUiLanguage,
                                allowedCategoryCodes: selectedRole == 'ADMIN'
                                    ? const []
                                    : selectedCategoryCodes.toList(),
                              );

                        if (!success) {
                          return;
                        }
                        await _loadData();
                        if (mounted) {
                          Navigator.of(context).pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                        }
                      } finally {
                        setDialogState(() {
                          isSubmitting = false;
                        });
                      }
                    },
              child: Text(isEdit ? '保存' : '新增'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final username = user['username'] as String? ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除用户'),
        content: Text('确定删除用户 $username 吗？'),
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
      await _systemService.deleteUser(username);
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        actions: [
          IconButton(
            onPressed: _loadData,
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () => _showUserDialog(),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('新增用户'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _users.isEmpty
                        ? const Center(child: Text('暂无用户'))
                        : ListView.builder(
                            itemCount: _users.length,
                            itemBuilder: (context, index) {
                              final user = _users[index];
                              final role = user['role'] as String? ?? 'USER';
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
                                              user['username'] as String? ??
                                                  '-',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Chip(label: Text(role)),
                                          IconButton(
                                            onPressed: () =>
                                                _showUserDialog(user: user),
                                            tooltip: '编辑',
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                          IconButton(
                                            onPressed:
                                                role == 'ADMIN' &&
                                                    (user['username']
                                                                as String?)
                                                            ?.toLowerCase() ==
                                                        'admin'
                                                ? null
                                                : () => _deleteUser(user),
                                            tooltip: '删除',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '门店: ${((user['storeCode'] as String?) ?? '').trim().isEmpty ? '未绑定' : user['storeCode']}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '语言: ${((user['uiLanguage'] as String?)?.toUpperCase() == 'EN') ? 'English' : '中文'}',
                                      ),
                                      const SizedBox(height: 4),
                                      Text('点货分类: ${_categorySummary(user)}'),
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

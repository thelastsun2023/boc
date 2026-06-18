import 'package:flutter/material.dart';

import '../services/session_service.dart';
import 'login_page.dart';
import 'stock_order_page.dart';
import 'system_view_page.dart';
import 'todo_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;

  String _t(String zh, String en) => SessionService().isEnglish ? en : zh;

  List<Map<String, dynamic>> _menuItems() => [
    {
      'index': 0,
      'icon': Icons.settings,
      'label': _t('系统设置(只读)', 'System (Read Only)'),
      'page': const SystemViewPage(),
    },
    {
      'index': 1,
      'icon': Icons.shopping_cart_checkout,
      'label': _t('点货', 'Stock Order'),
      'page': const StockOrderPage(),
    },
    {
      'index': 2,
      'icon': Icons.task_alt,
      'label': _t('待办事项', 'Todo'),
      'page': const TodoPage(),
    },
  ];

  void _logout() {
    SessionService().clear();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menuItems = _menuItems();
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: _isSidebarCollapsed ? 72 : 240,
            color: const Color(0xFF263238),
            child: Column(
              children: [
                Container(
                  height: 60,
                  color: const Color(0xFF1B2327),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (!_isSidebarCollapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t('用户菜单', 'User Menu'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSidebarCollapsed = !_isSidebarCollapsed;
                          });
                        },
                        icon: Icon(
                          _isSidebarCollapsed
                              ? Icons.arrow_forward_ios
                              : Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isSelected = _selectedIndex == item['index'];
                      return Container(
                        color: isSelected
                            ? Colors.teal.withValues(alpha: 0.18)
                            : Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            item['icon'] as IconData,
                            color: isSelected ? Colors.teal : Colors.grey[400],
                          ),
                          title: _isSidebarCollapsed
                              ? null
                              : Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.teal
                                        : Colors.grey[300],
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                          onTap: () {
                            setState(() {
                              _selectedIndex = item['index'] as int;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.grey[700]!)),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.teal,
                      child: Icon(Icons.person_outline, color: Colors.white),
                    ),
                    title: Text(
                      SessionService().username ?? _t('用户', 'User'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      _t('点击退出登录', 'Tap to Sign Out'),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                    trailing: const Icon(
                      Icons.logout,
                      color: Colors.grey,
                      size: 18,
                    ),
                    onTap: _logout,
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: menuItems[_selectedIndex]['page'] as Widget),
        ],
      ),
    );
  }
}

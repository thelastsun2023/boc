import '../widgets/section_navigation.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import 'finance_page.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'menu_management_page.dart';
import 'raw_material_overview_page.dart';
import 'semi_product_page.dart';
import 'semi_product_stock_check_page.dart';
import 'stock_order_page.dart';
import 'system_management_page.dart';
import 'todo_page.dart';
import 'user_management_page.dart';
import 'mall_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedIndex = 0;
  final _sectionTabs = <int, int>{};
  final _sectionKeys = <int, int>{};
  bool _isSidebarCollapsed = false;

  String _t(String zh, String en) => SessionService().isEnglish ? en : zh;

  List<Map<String, dynamic>> _menuItems() => [
    {
      'index': 0,
      'icon': Icons.dashboard,
      'label': _t('系统管理', 'System Management'),
      'page': SystemManagementPage(
        key: ValueKey(_sectionKeys[0] ?? 0),
        initialTabIndex: (_sectionTabs[0] ?? 0) < 9
            ? (_sectionTabs[0] ?? 0)
            : 0,
        initialAction: (_sectionTabs[0] ?? 0) >= 9 ? (_sectionTabs[0]! - 8) : 0,
      ),
    },
    {
      'index': 1,
      'icon': Icons.restaurant_menu,
      'label': _t('菜单管理', 'Menu Management'),
      'page': MenuManagementPage(
        key: ValueKey(_sectionTabs[1] ?? 0),
        initialTabIndex: _sectionTabs[1] ?? 0,
      ),
    },
    {
      'index': 2,
      'icon': Icons.inventory_2,
      'label': _t('原材料一览', 'Raw Material Overview'),
      'page': RawMaterialOverviewPage(
        key: ValueKey(_sectionKeys[2] ?? 0),
        initialAction: _sectionTabs[2] ?? 0,
      ),
    },
    {
      'index': 3,
      'icon': Icons.layers,
      'label': _t('半成品', 'Semi Product'),
      'page': SemiProductPage(
        key: ValueKey(_sectionKeys[3] ?? 0),
        initialAction: _sectionTabs[3] ?? 0,
      ),
    },
    {
      'index': 4,
      'icon': Icons.fact_check,
      'label': _t('半成品存量检查', 'Semi Product Stock Check'),
      'page': SemiProductStockCheckPage(
        key: ValueKey(_sectionKeys[4] ?? 0),
        initialAction: _sectionTabs[4] ?? 0,
      ),
    },
    {
      'index': 5,
      'icon': Icons.account_balance_wallet,
      'label': _t('财务', 'Finance'),
      'page': FinancePage(
        key: ValueKey(_sectionKeys[5] ?? 0),
        initialAction: _sectionTabs[5] ?? 0,
      ),
    },
    {
      'index': 6,
      'icon': Icons.shopping_cart_checkout,
      'label': _t('点货', 'Stock Order'),
      'page': StockOrderPage(
        key: ValueKey(_sectionKeys[6] ?? 0),
        initialAction: _sectionTabs[6] ?? 0,
      ),
    },
    {
      'index': 7,
      'icon': Icons.task_alt,
      'label': _t('待办事项', 'Todo'),
      'page': TodoPage(
        key: ValueKey(_sectionKeys[7] ?? 0),
        initialAction: _sectionTabs[7] ?? 0,
      ),
    },
    {
      'index': 8,
      'icon': Icons.manage_accounts,
      'label': _t('用户管理', 'User Management'),
      'page': UserManagementPage(
        key: ValueKey(_sectionKeys[8] ?? 0),
        initialAction: _sectionTabs[8] ?? 0,
      ),
    },
    {
      'index': 9,
      'icon': Icons.storefront,
      'label': _t('商城与采购订单', 'Mall & Orders'),
      'page': MallPage(
        key: ValueKey(_sectionTabs[9] ?? 0),
        initialTab: _sectionTabs[9] ?? 0,
      ),
    },
  ];

  List<String> _sectionLabels(int index) => switch (index) {
    0 => [
      _t('原材料', 'Raw Materials'),
      _t('供应商', 'Suppliers'),
      _t('单位', 'Units'),
      _t('区域', 'Regions'),
      _t('门店', 'Stores'),
      _t('厨具', 'Kitchen Tools'),
      _t('工艺', 'Processes'),
      _t('工具', 'Tools'),
      _t('提醒', 'Reminders'),
      _t('原材料分类', 'Material Categories'),
      _t('存放位置', 'Storage Locations'),
    ],
    1 => [_t('菜单分类', 'Menu Categories'), _t('菜单列表', 'Menus')],
    2 => [_t('原材料列表', 'Material List'), _t('打印一览', 'Print Overview')],
    3 => [
      _t('半成品列表', 'Semi Products'),
      _t('新增半成品', 'Add Semi Product'),
      _t('分类管理', 'Categories'),
    ],
    4 => [
      _t('检查记录', 'Check History'),
      _t('添加检查数据', 'Add Check'),
      _t('生成网页检查单', 'Print Checklist'),
    ],
    5 => [
      _t('财务记录', 'Finance Records'),
      _t('添加财务记录', 'Add Record'),
      _t('导出财务记录', 'Export Records'),
    ],
    6 => [_t('点货记录', 'Stock Order History'), _t('新建点货', 'New Stock Order')],
    7 => [_t('任务列表', 'Task List'), _t('添加任务', 'Add Task')],
    8 => [_t('用户列表', 'Users'), _t('新增用户', 'Add User')],
    9 => [_t('商品列表', 'Product List'), _t('历史订单', 'Order History')],
    _ => const [],
  };

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
            width: _isSidebarCollapsed ? 72 : 260,
            color: const Color(0xFF222d32),
            child: Column(
              children: [
                Container(
                  height: 60,
                  color: const Color(0xFF1a1f23),
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      Container(
                        width: 35,
                        height: 35,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      if (!_isSidebarCollapsed) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _t('管理后台', 'Admin Console'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      IconButton(
                        icon: Icon(
                          _isSidebarCollapsed
                              ? Icons.arrow_forward_ios
                              : Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 16,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSidebarCollapsed = !_isSidebarCollapsed;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final section = item['index'] as int;
                      final labels = _sectionLabels(section);
                      if (labels.isNotEmpty) {
                        return SectionNavigation(
                          title: item['label'] as String,
                          icon: item['icon'] as IconData,
                          labels: labels,
                          collapsed: _isSidebarCollapsed,
                          selected: _selectedIndex == section,
                          tab: _sectionTabs[section] ?? 0,
                          onSelected: (tab) => setState(() {
                            _selectedIndex = section;
                            _sectionTabs[section] = tab;
                            _sectionKeys[section] =
                                (_sectionKeys[section] ?? 0) + 1;
                          }),
                        );
                      }
                      final isSelected = _selectedIndex == item['index'];
                      return Container(
                        color: isSelected
                            ? Colors.blue.withValues(alpha: 0.2)
                            : Colors.transparent,
                        child: ListTile(
                          leading: Icon(
                            item['icon'] as IconData,
                            color: isSelected ? Colors.blue : Colors.grey[400],
                            size: 22,
                          ),
                          title: _isSidebarCollapsed
                              ? null
                              : Text(
                                  item['label'] as String,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.grey[300],
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 14,
                                  ),
                                ),
                          onTap: () {
                            setState(
                              () => _selectedIndex = item['index'] as int,
                            );
                          },
                          hoverColor: Colors.blue.withValues(alpha: 0.1),
                          minLeadingWidth: 0,
                          dense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: _isSidebarCollapsed ? 8 : 16,
                          ),
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
                      backgroundColor: Colors.blue,
                      child: Text('A', style: TextStyle(color: Colors.white)),
                    ),
                    title: Text(
                      _t('管理员', 'Administrator'),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    subtitle: Text(
                      SessionService().username ?? _t('在线', 'Online'),
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
          Expanded(
            child: Column(
              children: [
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        menuItems[_selectedIndex]['label'] as String,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(
                          Icons.home_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const HomePage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF4F4F4),
                    child: menuItems[_selectedIndex]['page'] as Widget,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

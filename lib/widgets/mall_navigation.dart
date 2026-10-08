import 'package:flutter/material.dart';
import '../services/session_service.dart';

class MallNavigation extends StatelessWidget {
  const MallNavigation({
    super.key,
    required this.collapsed,
    required this.selected,
    required this.tab,
    required this.onSelected,
  });
  final bool collapsed, selected;
  final int tab;
  final ValueChanged<int> onSelected;
  String _t(String zh, String en) => SessionService().isEnglish ? en : zh;

  @override
  Widget build(BuildContext context) {
    final labels = [_t('商品列表', 'Product List'), _t('历史订单', 'Order History')];
    if (collapsed) {
      return PopupMenuButton<int>(
        tooltip: _t('商城与采购', 'Mall & Procurement'),
        icon: Icon(
          Icons.storefront,
          color: selected ? Colors.blue : Colors.grey,
        ),
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (var i = 0; i < 2; i++)
            PopupMenuItem(value: i, child: Text(labels[i])),
        ],
      );
    }
    return ExpansionTile(
      initiallyExpanded: selected,
      collapsedIconColor: Colors.grey,
      iconColor: Colors.blue,
      leading: Icon(
        Icons.storefront,
        color: selected ? Colors.blue : Colors.grey,
      ),
      title: Text(
        _t('商城与采购', 'Mall & Procurement'),
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      children: [
        for (var i = 0; i < 2; i++)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 44, right: 12),
            selected: selected && tab == i,
            selectedTileColor: Colors.blue.withValues(alpha: .18),
            leading: Icon(
              i == 0 ? Icons.list_alt : Icons.receipt_long,
              color: selected && tab == i ? Colors.blue : Colors.grey,
              size: 20,
            ),
            title: Text(
              labels[i],
              style: TextStyle(
                color: selected && tab == i
                    ? Colors.blue
                    : Colors.grey.shade300,
                fontSize: 13,
              ),
            ),
            onTap: () => onSelected(i),
          ),
      ],
    );
  }
}

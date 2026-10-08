import 'package:flutter/material.dart';

class SectionNavigation extends StatelessWidget {
  const SectionNavigation({
    super.key,
    required this.collapsed,
    required this.selected,
    required this.tab,
    required this.onSelected,
    required this.title,
    required this.labels,
    required this.icon,
  });
  final String title;
  final List<String> labels;
  final IconData icon;
  final bool collapsed, selected;
  final int tab;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return PopupMenuButton<int>(
        tooltip: title,
        icon: Icon(icon, color: selected ? Colors.blue : Colors.grey),
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (var i = 0; i < labels.length; i++)
            PopupMenuItem(value: i, child: Text(labels[i])),
        ],
      );
    }
    return ExpansionTile(
      initiallyExpanded: selected,
      collapsedIconColor: Colors.grey,
      iconColor: Colors.blue,
      leading: Icon(icon, color: selected ? Colors.blue : Colors.grey),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      children: [
        for (var i = 0; i < labels.length; i++)
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

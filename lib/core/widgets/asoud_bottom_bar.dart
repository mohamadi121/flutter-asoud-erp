import 'package:flutter/material.dart';

import '../theme/asoud_colors.dart';

class AsoudBottomBarItem {
  const AsoudBottomBarItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}

class AsoudBottomBar extends StatelessWidget {
  const AsoudBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    super.key,
  });

  final List<AsoudBottomBarItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AsoudColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: SizedBox(
              height: 64,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    _item(i, i == selectedIndex),
                ],
              ),
            ),
          ),
        ),
      );

  Widget _item(int index, bool selected) {
    final item = items[index];
    return Expanded(
      child: InkWell(
        key: ValueKey('asoud-bar-item-$index'),
        onTap: () => onSelected(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              key: selected ? const ValueKey('asoud-bar-indicator') : null,
              width: 26,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? AsoudColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 5),
            Icon(
              selected ? (item.selectedIcon ?? item.icon) : item.icon,
              size: 22,
              color: selected ? AsoudColors.primary : AsoudColors.muted,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                color: selected ? AsoudColors.primary : AsoudColors.muted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

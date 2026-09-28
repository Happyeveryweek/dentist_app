import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// 材料类型筛选。标题和「全部」固定在顶部，其余类型在下面滚动。
class MaterialTypeFilterMenu extends StatelessWidget {
  const MaterialTypeFilterMenu({
    super.key,
    this.title = '材料类型',
    required this.value,
    required this.items,
    required this.onSelected,
  });

  final String title;
  final String value;
  final List<String> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scrollableItems = [
      for (final item in items)
        if (item != '全部') item,
    ];
    final hasAll = items.contains('全部');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (hasAll)
          _TypeTile(
            label: '全部',
            selected: value == '全部',
            onTap: () => onSelected('全部'),
          ),
        if (hasAll) const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: scrollableItems.length,
            itemBuilder: (context, index) {
              final label = scrollableItems[index];
              return _TypeTile(
                label: label,
                selected: value == label,
                onTap: () => onSelected(label),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TypeTile extends StatelessWidget {
  const _TypeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.primaryColor : AppTheme.primaryText;
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
      trailing:
          selected
              ? const Icon(Icons.check_rounded, color: AppTheme.primaryColor)
              : null,
      onTap: onTap,
    );
  }
}

Future<String?> showMaterialTypeFilter({
  required BuildContext context,
  required String value,
  required List<String> items,
}) {
  final height = MediaQuery.sizeOf(context).height * 0.7;
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: SizedBox(
          height: height > 520 ? 520 : height,
          child: MaterialTypeFilterMenu(
            value: value,
            items: items,
            onSelected: (selected) => Navigator.of(context).pop(selected),
          ),
        ),
      );
    },
  );
}

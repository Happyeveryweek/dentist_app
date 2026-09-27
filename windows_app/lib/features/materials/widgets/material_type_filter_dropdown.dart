import 'package:flutter/material.dart';

import '../../../theme/theme_context_extensions.dart';

const double _kTypeMenuMaxHeight = 320;
const double _kTypeMenuWidth = 260;
const double _kTypeHeaderHeight = 52;
const double _kTypeOptionHeight = 38;
const double _kTypeDividerHeight = 1;

double _typeMenuHeight({
  required bool hasPinnedAll,
  required int scrollableCount,
}) {
  var height = _kTypeHeaderHeight;
  if (hasPinnedAll) {
    height += _kTypeDividerHeight + _kTypeOptionHeight;
  }
  if (scrollableCount > 0) {
    height += _kTypeDividerHeight + scrollableCount * _kTypeOptionHeight;
  }
  return height > _kTypeMenuMaxHeight ? _kTypeMenuMaxHeight : height;
}

/// 材料管理顶部的类型筛选。标题和「全部」固定在菜单顶部，其余类型在其下滚动。
class MaterialTypeFilterDropdown extends StatefulWidget {
  const MaterialTypeFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  State<MaterialTypeFilterDropdown> createState() =>
      _MaterialTypeFilterDropdownState();
}

class _MaterialTypeFilterDropdownState
    extends State<MaterialTypeFilterDropdown> {
  bool _isHover = false;

  @override
  Widget build(BuildContext context) {
    final hasPinnedAll = widget.items.contains('全部');
    final scrollableItems = [
      for (final item in widget.items)
        if (item != '全部') item,
    ];
    final menuHeight = _typeMenuHeight(
      hasPinnedAll: hasPinnedAll,
      scrollableCount: scrollableItems.length,
    );
    final highlighted = widget.value != '全部' || _isHover;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHover = true),
      onExit: (_) => setState(() => _isHover = false),
      child: Container(
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: highlighted
                ? context.tokens.primaryAccent.withValues(alpha: 0.6)
                : context.tokens.border,
            width: 1.5,
          ),
          boxShadow: [
            if (_isHover)
              BoxShadow(
                color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: PopupMenuButton<String>(
          onSelected: widget.onChanged,
          menuPadding: EdgeInsets.zero,
          constraints: BoxConstraints(
            maxHeight: menuHeight,
            minWidth: _kTypeMenuWidth,
          ),
          offset: const Offset(0, 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          // 标题栏渐变贴着弹出窗上沿，需要裁进圆角，避免两角看起来是直角。
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          itemBuilder: (context) => [
            _MaterialTypeMenu(
              scrollableItems: scrollableItems,
              hasPinnedAll: hasPinnedAll,
              selected: widget.value,
              menuHeight: menuHeight,
              totalCount: widget.items.length,
            ),
          ],
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_list_rounded,
                    size: 18,
                    color: highlighted
                        ? context.tokens.primaryAccent
                        : context.tokens.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: highlighted
                          ? context.tokens.primaryAccent
                          : context.tokens.textMuted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: highlighted
                        ? context.tokens.primaryAccent
                        : context.tokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MaterialTypeMenu extends PopupMenuEntry<String> {
  const _MaterialTypeMenu({
    required this.scrollableItems,
    required this.hasPinnedAll,
    required this.selected,
    required this.menuHeight,
    required this.totalCount,
  });

  final List<String> scrollableItems;
  final bool hasPinnedAll;
  final String selected;
  final double menuHeight;
  final int totalCount;

  @override
  double get height => menuHeight;

  @override
  bool represents(String? value) => false;

  @override
  State<_MaterialTypeMenu> createState() => _MaterialTypeMenuState();
}

class _MaterialTypeMenuState extends State<_MaterialTypeMenu> {
  @override
  Widget build(BuildContext context) {
    final listHeight = widget.menuHeight -
        _kTypeHeaderHeight -
        (widget.hasPinnedAll ? _kTypeDividerHeight + _kTypeOptionHeight : 0) -
        (widget.scrollableItems.isEmpty ? 0 : _kTypeDividerHeight);

    return SizedBox(
      width: _kTypeMenuWidth,
      height: widget.menuHeight,
      child: Column(
        children: [
          _TypeMenuHeader(totalCount: widget.totalCount),
          if (widget.hasPinnedAll) ...[
            _menuDivider(context),
            _TypeOption(
              label: '全部',
              selected: widget.selected == '全部',
              onTap: () => Navigator.pop(context, '全部'),
            ),
          ],
          if (widget.scrollableItems.isNotEmpty) ...[
            _menuDivider(context),
            SizedBox(
              height: listHeight,
              child: ListView(
                padding: EdgeInsets.zero,
                primary: false,
                itemExtent: _kTypeOptionHeight,
                children: [
                  for (final type in widget.scrollableItems)
                    _TypeOption(
                      label: type,
                      selected: type == widget.selected,
                      onTap: () => Navigator.pop(context, type),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _menuDivider(BuildContext context) {
  return SizedBox(
    height: _kTypeDividerHeight,
    child: ColoredBox(color: context.tokens.divider),
  );
}

class _TypeMenuHeader extends StatelessWidget {
  const _TypeMenuHeader({required this.totalCount});

  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kTypeHeaderHeight,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: context.tokens.primaryHeaderGradient,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  Icons.category_rounded,
                  size: 18,
                  color: context.tokens.cardBackground,
                ),
                const SizedBox(width: 10),
                Text(
                  '材料类型',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.tokens.cardBackground,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.tokens.cardBackground.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$totalCount项',
                    style: TextStyle(
                      fontSize: 11,
                      color: context.tokens.cardBackground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      mouseCursor: SystemMouseCursors.click,
      child: SizedBox(
        height: _kTypeOptionHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? context.tokens.primaryAccent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: selected
                          ? context.tokens.primaryHeaderGradient
                          : null,
                      border: Border.all(
                        color: selected
                            ? Colors.transparent
                            : context.tokens.border,
                        width: 2,
                      ),
                    ),
                    child: selected
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: context.tokens.cardBackground,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? context.tokens.primaryAccent
                            : context.colors.onSurface,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            context.tokens.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '已选',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.tokens.primaryAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

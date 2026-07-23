import 'package:flutter/material.dart';

import '../theme/theme_context_extensions.dart';

class CompactDropdownItem<T> {
  const CompactDropdownItem({
    required this.value,
    required this.child,
    this.enabled = true,
  });

  final T value;
  final Widget child;
  final bool enabled;
}

class CompactDropdownFormField<T> extends StatelessWidget {
  const CompactDropdownFormField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.decoration,
    this.hint,
    this.selectedItemBuilder,
    this.enabled = true,
    this.itemHeight = 36,
    this.menuMaxHeight = 188,
    this.menuWidth,
    this.borderRadius = 12,
    this.centerSelectedItem = false,
  });

  final T? value;
  final List<CompactDropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final InputDecoration decoration;
  final Widget? hint;
  final Widget Function(BuildContext context, T value)? selectedItemBuilder;
  final bool enabled;
  final double itemHeight;
  final double menuMaxHeight;
  final double? menuWidth;
  final double borderRadius;
  final bool centerSelectedItem;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final resolvedEnabled = enabled && items.any((item) => item.enabled);

    return CompactPopupMenuButton<T>(
      value: value,
      items: items,
      enabled: resolvedEnabled,
      itemHeight: itemHeight,
      menuMaxHeight: menuMaxHeight,
      menuWidth: menuWidth,
      borderRadius: borderRadius,
      onSelected: onChanged,
      childBuilder: (context, isOpen) => InputDecorator(
        isEmpty: value == null,
        isFocused: isOpen,
        textAlignVertical: TextAlignVertical.center,
        decoration: decoration.copyWith(enabled: resolvedEnabled),
        child: centerSelectedItem && value != null
            ? Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: selectedItemBuilder?.call(context, value as T) ??
                        _selectedItem(value as T),
                  ),
                  Positioned(
                    right: 0,
                    child: Icon(
                      isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      size: 18,
                      color: resolvedEnabled
                          ? tokens.iconMuted
                          : tokens.disabledText,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: value == null
                        ? hint ?? const SizedBox.shrink()
                        : selectedItemBuilder?.call(context, value as T) ??
                            _selectedItem(value as T),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                    size: 18,
                    color: resolvedEnabled
                        ? tokens.iconMuted
                        : tokens.disabledText,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _selectedItem(T value) {
    for (final item in items) {
      if (item.value == value) {
        return item.child;
      }
    }
    return Text('$value', overflow: TextOverflow.ellipsis);
  }
}

class CompactPopupMenuButton<T> extends StatefulWidget {
  const CompactPopupMenuButton({
    super.key,
    required this.value,
    required this.items,
    required this.onSelected,
    required this.childBuilder,
    this.enabled = true,
    this.itemHeight = 36,
    this.menuMaxHeight = 188,
    this.menuWidth,
    this.borderRadius = 12,
    this.offset = const Offset(0, 4),
  });

  final T? value;
  final List<CompactDropdownItem<T>> items;
  final ValueChanged<T?> onSelected;
  final Widget Function(BuildContext context, bool isOpen) childBuilder;
  final bool enabled;
  final double itemHeight;
  final double menuMaxHeight;
  final double? menuWidth;
  final double borderRadius;
  final Offset offset;

  @override
  State<CompactPopupMenuButton<T>> createState() =>
      _CompactPopupMenuButtonState<T>();
}

class _CompactPopupMenuButtonState<T> extends State<CompactPopupMenuButton<T>> {
  bool _isOpen = false;

  void _setOpen(bool value) {
    if (_isOpen == value) {
      return;
    }
    setState(() => _isOpen = value);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final enabled = widget.enabled && widget.items.any((item) => item.enabled);

    return LayoutBuilder(
      builder: (context, constraints) {
        final anchorWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : 200.0;
        final resolvedMenuWidth = widget.menuWidth ?? anchorWidth;

        return MouseRegion(
          cursor:
              enabled ? SystemMouseCursors.click : SystemMouseCursors.forbidden,
          child: PopupMenuButton<T>(
            enabled: enabled,
            initialValue: widget.value,
            tooltip: '',
            position: PopupMenuPosition.under,
            offset: widget.offset,
            color: tokens.cardBackground,
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              side: BorderSide(color: tokens.border),
            ),
            constraints: BoxConstraints(
              minWidth: resolvedMenuWidth,
              maxWidth: resolvedMenuWidth,
              maxHeight: widget.menuMaxHeight,
            ),
            onOpened: () => _setOpen(true),
            onCanceled: () => _setOpen(false),
            onSelected: (value) {
              _setOpen(false);
              widget.onSelected(value);
            },
            itemBuilder: (context) => widget.items
                .map(
                  (item) => _CompactPopupMenuEntry<T>(
                    value: item.value,
                    enabled: item.enabled,
                    itemHeight: widget.itemHeight,
                    selected: item.value == widget.value,
                    child: item.child,
                  ),
                )
                .toList(),
            child: MouseRegion(
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.forbidden,
              child: widget.childBuilder(context, _isOpen),
            ),
          ),
        );
      },
    );
  }
}

class _CompactPopupMenuEntry<T> extends PopupMenuEntry<T> {
  const _CompactPopupMenuEntry({
    required this.value,
    required this.child,
    required this.itemHeight,
    required this.selected,
    required this.enabled,
  });

  final T value;
  final Widget child;
  final double itemHeight;
  final bool selected;
  final bool enabled;

  @override
  double get height => itemHeight;

  @override
  bool represents(T? value) => value == this.value;

  @override
  State<_CompactPopupMenuEntry<T>> createState() =>
      _CompactPopupMenuEntryState<T>();
}

class _CompactPopupMenuEntryState<T> extends State<_CompactPopupMenuEntry<T>> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isPressed = false;

  bool get _isInteractive => _isHovered || _isFocused || _isPressed;

  Color _backgroundColor(AppThemeTokens tokens) {
    if (widget.selected && _isInteractive) {
      return tokens.menuItemSelectedHoverBackground;
    }
    if (_isInteractive) {
      return tokens.menuItemHoverBackground;
    }
    if (widget.selected) {
      return tokens.selectedBackground;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.selected,
      child: InkWell(
        onTap: widget.enabled
            ? () => Navigator.pop<T>(context, widget.value)
            : null,
        onHover: widget.enabled
            ? (value) => setState(() => _isHovered = value)
            : null,
        onFocusChange: widget.enabled
            ? (value) => setState(() => _isFocused = value)
            : null,
        onHighlightChanged: widget.enabled
            ? (value) => setState(() => _isPressed = value)
            : null,
        mouseCursor: widget.enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.forbidden,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        highlightColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: widget.itemHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
            color: _backgroundColor(tokens),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.45,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

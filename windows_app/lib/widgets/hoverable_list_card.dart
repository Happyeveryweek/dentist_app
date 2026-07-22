import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 通用列表项悬浮卡片
///
/// 提供统一的鼠标悬浮背景色变化效果，适用于各业务列表
/// （财务、患者、预约、采购、材料、仪表盘、模板等）。
///
/// 悬浮时使用列表专用悬浮 token，与选中状态保持清晰层级。
class HoverableListCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double borderRadius;
  final bool showShadow;

  /// 未悬浮时的背景色，默认使用 `tokens.cardBackground`。
  /// 当卡片嵌入在卡片容器内需要层次感时，可传入 `tokens.pageBackground` 等。
  final Color? background;

  const HoverableListCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 8),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.borderRadius = AppTheme.borderRadius,
    this.showShadow = true,
    this.background,
  });

  @override
  State<HoverableListCard> createState() => _HoverableListCardState();
}

class _HoverableListCardState extends State<HoverableListCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final Widget container = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: widget.margin,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: _isHovered
            ? tokens.listItemHoverBackground
            : (widget.background ?? tokens.cardBackground),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        boxShadow: widget.showShadow ? tokens.cardShadow : null,
      ),
      child: widget.child,
    );

    final Widget content = widget.onTap != null
        ? InkWell(
            onTap: widget.onTap,
            mouseCursor: SystemMouseCursors.click,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            child: container,
          )
        : container;

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: content,
    );
  }
}

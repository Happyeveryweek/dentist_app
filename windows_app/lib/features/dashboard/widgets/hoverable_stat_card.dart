import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

// 可悬浮的统计卡片组件
class HoverableStatCard extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const HoverableStatCard({
    Key? key,
    this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  State<HoverableStatCard> createState() => HoverableStatCardState();
}

class HoverableStatCardState extends State<HoverableStatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: widget.onTap != null
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered && widget.onTap != null
                ? tokens.primaryAccent.withValues(alpha: 0.1)
                : tokens.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: tokens.shadow,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

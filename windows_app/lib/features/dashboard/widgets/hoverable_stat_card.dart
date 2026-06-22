import 'package:flutter/material.dart';

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
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered && widget.onTap != null
                ? Color(0xFFE3F2FD)  // 淡蓝色
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
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

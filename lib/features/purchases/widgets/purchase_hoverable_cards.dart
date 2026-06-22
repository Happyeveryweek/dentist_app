import 'package:flutter/material.dart';
// 可悬浮的采购记录卡片组件
class HoverablePurchaseRecordCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool isPurpleTheme;
  final Widget child;

  const HoverablePurchaseRecordCard({
    Key? key,
    required this.onTap,
    required this.isPurpleTheme,
    required this.child,
  }) : super(key: key);

  @override
  State<HoverablePurchaseRecordCard> createState() => HoverablePurchaseRecordCardState();
}

class HoverablePurchaseRecordCardState extends State<HoverablePurchaseRecordCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered 
                ? Color(0xFFE3F2FD)  // 淡蓝色
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

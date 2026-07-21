import 'package:flutter/material.dart';

/// 通用可点击容器。
///
/// 统一鼠标悬停时显示小手光标的行为，替代散落各处手写的
/// `MouseRegion(cursor: SystemMouseCursors.click) + GestureDetector` 组合。
///
/// 仅负责光标与点击事件；需要悬停视觉状态变化的卡片仍应使用各自的
/// hoverable 组件（它们需要 MouseRegion 的 onEnter/onExit 维护状态）。
class Clickable extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// 点击命中测试行为，默认 [HitTestBehavior.opaque] 以保证空白区域也可点击。
  final HitTestBehavior behavior;

  const Clickable({
    super.key,
    required this.child,
    this.onTap,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: onTap,
        behavior: behavior,
        child: child,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 默认头像图标组件
class DefaultAvatarIcon extends StatelessWidget {
  const DefaultAvatarIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// 登录底部装饰组件
class LoginBottomDecorations extends StatelessWidget {
  final bool isSmallScreen;

  const LoginBottomDecorations({super.key, required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    final textSize = isSmallScreen ? 12.0 : 14.0;
    final spacing = isSmallScreen ? 4.0 : 8.0;

    return Column(
      children: [
        SizedBox(height: spacing * 2.5),
        Text(
          '技术支持: 牙科诊所管理系统',
          style: TextStyle(
            fontSize: textSize,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        SizedBox(height: spacing),
        Container(
          width: isSmallScreen ? 40 : 50,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

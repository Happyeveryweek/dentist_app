import 'package:flutter/material.dart';

/// 登录底部装饰组件
class LoginBottomDecorations extends StatelessWidget {
  final bool isSmallScreen;

  const LoginBottomDecorations({super.key, required this.isSmallScreen});

  @override
  Widget build(BuildContext context) {
    final spacing = isSmallScreen ? 4.0 : 8.0;

    return Column(
      children: [SizedBox(height: spacing * 2.5), SizedBox(height: spacing)],
    );
  }
}

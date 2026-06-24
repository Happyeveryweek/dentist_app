import 'package:flutter/material.dart';

/// 登录按钮组件
class LoginButton extends StatelessWidget {
  final bool isInitializing;
  final VoidCallback onPressed;
  final bool isSmallScreen;

  const LoginButton({
    super.key,
    required this.isInitializing,
    required this.onPressed,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 350;
        return Container(
          width: double.infinity,
          height: isSmall ? 48 : 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors:
                  isInitializing
                      ? [
                        Colors.grey.shade400,
                        Colors.grey.shade500,
                        Colors.grey.shade600,
                      ]
                      : [
                        Colors.blue.shade600,
                        Colors.blue.shade500,
                        Colors.indigo.shade400,
                      ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    isInitializing
                        ? Colors.grey.shade400.withValues(alpha: 0.3)
                        : Colors.blue.shade400.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isInitializing ? null : onPressed,
              child: Container(
                alignment: Alignment.center,
                child:
                    isInitializing
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '初始化中...',
                              style: TextStyle(
                                fontSize: isSmall ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.login_rounded,
                              color: Colors.white,
                              size: isSmall ? 20 : 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '登录',
                              style: TextStyle(
                                fontSize: isSmall ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
          ),
        );
      },
    );
  }
}

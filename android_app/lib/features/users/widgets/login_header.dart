import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 登录头部组件
class LoginHeader extends StatelessWidget {
  final double logoSize;
  final double fontSize;

  const LoginHeader({
    super.key,
    required this.logoSize,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 应用图标 - 使用牙齿图标
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
            child: Container(
              width: logoSize,
              height: logoSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.7),
                    Colors.blue.shade50.withOpacity(0.5),
                    Colors.indigo.shade50.withOpacity(0.5),
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 背景装饰圆圈
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                      child: Container(
                        width: logoSize * 0.8,
                        height: logoSize * 0.8,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade100.withOpacity(0.15),
                              Colors.indigo.shade100.withOpacity(0.08),
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  // 牙齿图标
                  Icon(
                    FontAwesomeIcons.tooth,
                    size: logoSize * 0.48,
                    color: Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 应用名称
        Text(
          '牙科诊所管理系统',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: 1.0,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.4),
                offset: const Offset(0, 2),
                blurRadius: 6,
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // 副标题
        Text(
          'Dental Clinic Management System',
          style: TextStyle(
            fontSize: fontSize * 0.57,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 1),
                blurRadius: 4,
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // 装饰性分隔线
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
            child: Container(
              width: logoSize * 0.6,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.blue.shade200.withOpacity(0.5),
                    Colors.indigo.shade200.withOpacity(0.5),
                    Colors.white.withOpacity(0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // 装饰性图标
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _DecorIcon(FontAwesomeIcons.tooth, Colors.blue.shade300),
            const SizedBox(width: 12),
            _DecorIcon(FontAwesomeIcons.teeth, Colors.indigo.shade300),
            const SizedBox(width: 12),
            _DecorIcon(FontAwesomeIcons.heartbeat, Colors.purple.shade300),
          ],
        ),
      ],
    );
  }
}

/// 装饰性图标组件
class _DecorIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DecorIcon(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

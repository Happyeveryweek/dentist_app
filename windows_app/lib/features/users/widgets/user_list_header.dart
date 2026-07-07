import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class UserListHeader extends StatelessWidget {
  final int userCount;
  final int adminCount;

  const UserListHeader({
    Key? key,
    required this.userCount,
    required this.adminCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.tokens.primaryHeaderGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.tokens.primaryAccent.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            color: context.tokens.cardBackground,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '系统用户管理',
                style: TextStyle(
                  color: context.tokens.cardBackground,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '共 $userCount 个用户账户',
                style: TextStyle(
                  color: context.tokens.cardBackground.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: context.tokens.cardBackground.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings,
                    color: context.tokens.cardBackground, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$adminCount 管理员',
                  style: TextStyle(
                      color: context.tokens.cardBackground,
                      fontWeight: FontWeight.w500,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

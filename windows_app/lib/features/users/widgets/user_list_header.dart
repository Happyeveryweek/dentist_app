import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

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
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '系统用户管理',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '共 $userCount 个用户账户',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$adminCount 管理员',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

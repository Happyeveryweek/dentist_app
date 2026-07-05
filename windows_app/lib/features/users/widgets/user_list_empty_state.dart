import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../widgets/dental_icons.dart';

class UserListEmptyState extends StatelessWidget {
  final VoidCallback onAddUser;

  const UserListEmptyState({
    Key? key,
    required this.onAddUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.tokens.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: context.tokens.shadow.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.people_outline,
              color: context.tokens.textMuted,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无用户数据',
              style: TextStyle(
                color: context.tokens.iconMuted,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加第一个用户',
              style: TextStyle(color: context.tokens.textMuted),
            ),
            const SizedBox(height: 24),
            DentalGradientButton(
              text: '添加用户',
              icon: Icons.person_add,
              onPressed: onAddUser,
            ),
          ],
        ),
      ),
    );
  }
}

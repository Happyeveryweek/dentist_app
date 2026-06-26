import 'package:flutter/material.dart';
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
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
              color: Colors.grey.shade400,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无用户数据',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮添加第一个用户',
              style: TextStyle(color: Colors.grey.shade500),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../../providers/user_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/success_toast.dart';

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;
  final String? requiredRole;
  final String? moduleId; // 模块标识符，用于权限检查

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
    this.requiredRole,
    this.moduleId,
  });
}

class UserInfoSection extends StatelessWidget {
  const UserInfoSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 只监听UserProvider的变化，不监听AppState
    final userProvider = Provider.of<UserProvider>(context);
    final currentUser = userProvider.currentUser;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color(0xFFF3E5F5),  // 淡紫色
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE1BEE7)),  // 淡紫色边框
        ),
        child: Row(
          children: [
            // 用户头像
            currentUser != null
                ? Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: DentalColors.primary, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: currentUser.imageData != null && currentUser.imageData!.isNotEmpty
                          ? Image.memory(
                              Uint8List.fromList(currentUser.imageData!),
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.error_outline,
                                    size: 18,
                                    color: Colors.grey.shade400,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade100,
                              child: currentUser.role == 'doctor' || currentUser.role == 'admin'
                                  ? Image.asset(
                                      'assets/icons/doctor.png',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/icons/nurse.png',
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                    ),
                  )
                : Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: DentalColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.person_rounded,
                      color: DentalColors.primary,
                      size: 24,
                    ),
                  ),
            const SizedBox(width: 12),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser?.username ?? 'admin',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.grey[800],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentUser?.roleDisplay ?? '管理员',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // 退出登录按钮
            IconButton(
              icon: Icon(
                Icons.logout_rounded,
                color: Colors.grey[600],
                size: 20,
              ),
              onPressed: () async {
                // 使用公共退出登录确认框组件
                final confirmed = await LogoutConfirmDialogManager.show(
                  context,
                  username: currentUser?.username ?? 'admin',
                );
                
                if (confirmed) {
                  // 退出登录
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              tooltip: '退出登录',
            ),
          ],
        ),
      ),
    );
  }
}

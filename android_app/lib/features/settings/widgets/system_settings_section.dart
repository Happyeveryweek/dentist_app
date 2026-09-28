import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/settings_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/screens/users_screen.dart';
import 'package:dentist_app/features/users/services/user_permission_service.dart';
import 'package:dentist_app/widgets/user_avatar.dart';

/// 系统设置区域组件
/// 负责显示通知设置、账户管理、退出登录等功能
class SystemSettingsSection extends StatelessWidget {
  final VoidCallback onLogout;

  const SystemSettingsSection({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallBorderRadius,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '通知设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('预约提醒'),
                        subtitle: const Text('开启后将在预约时间前提醒'),
                        value: settingsProvider.appointmentReminder,
                        onChanged: (value) {
                          settingsProvider.updateAppointmentReminder(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 账户管理卡片
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.smallBorderRadius,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.padding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '账户管理',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 当前用户信息
                      Consumer<UserProvider>(
                        builder: (context, userProvider, _) {
                          final currentUser = userProvider.currentUser;
                          return Column(
                            children: [
                              if (currentUser != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.smallBorderRadius,
                                    ),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      UserAvatar(
                                        imageData: currentUser.imageData,
                                        username: currentUser.username,
                                        role: currentUser.role,
                                        radius: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentUser.username,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '角色: ${currentUser.role}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (UserPermissionService.canManageUsers(
                                currentUser,
                              ))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(
                                    Icons.people_rounded,
                                    color: AppTheme.navigationBusiness,
                                  ),
                                  title: const Text('用户管理'),
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey.shade600,
                                  ),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder:
                                            (context) => const UsersScreen(),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // 退出登录按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: onLogout,
                          icon: const Icon(Icons.logout, color: Colors.white),
                          label: const Text(
                            '退出登录',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.errorColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppTheme.smallBorderRadius,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

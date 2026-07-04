import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'dart:typed_data';
import '../../../models/user.dart';
import '../../../theme/app_theme.dart';

class UserCard extends StatelessWidget {
  final User user;
  final VoidCallback onResetPassword;
  final VoidCallback onEdit;
  final VoidCallback onPermissionPreview;
  final VoidCallback onDelete;

  const UserCard({
    Key? key,
    required this.user,
    required this.onResetPassword,
    required this.onEdit,
    required this.onPermissionPreview,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final doctorName = user.doctor?.trim();
    final displayName =
        doctorName != null && doctorName.isNotEmpty ? doctorName : user.username;
    final showUsername = doctorName != null &&
        doctorName.isNotEmpty &&
        user.username.trim().isNotEmpty &&
        user.username.trim() != displayName;

    final roleColors = {
      'admin': AppTheme.dangerGradient,
      'doctor': AppTheme.successGradient,
      'assistant': AppTheme.warningGradient,
      'receptionist': AppTheme.infoGradient,
    };

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧：用户头像和信息
            Expanded(
              child: Row(
                children: [
                  // 用户头像
                  _buildUserAvatar(),
                  const SizedBox(width: 12),

                  // 用户信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: roleColors[user.role] ??
                                    AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                user.roleDisplay,
                                style: TextStyle(
                                  color: context.tokens.cardBackground,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (showUsername) ...[
                          Text(
                            '@${user.username}',
                            style: TextStyle(
                              color: context.tokens.iconMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                        ],
                        Builder(builder: (context) {
                          final email = user.email;
                          if (email == null || email.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Row(
                            children: [
                              Icon(Icons.email,
                                  size: 12, color: context.tokens.iconMuted),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  email,
                                  style: TextStyle(
                                    color: context.tokens.iconMuted,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          );
                        }),

                        // 显示权限信息（仅对非管理员用户）
                        if (user.role != 'admin') ...[
                          const SizedBox(height: 4),
                          _buildPermissionTags(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 右侧：操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.lock,
                        color: AppTheme.primaryColor, size: 16),
                    tooltip: '修改密码',
                    onPressed: onResetPassword,
                    padding: const EdgeInsets.all(6),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.edit,
                        color: AppTheme.successColor, size: 16),
                    tooltip: '编辑',
                    onPressed: onEdit,
                    padding: const EdgeInsets.all(6),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                if (user.role != 'admin') ...[
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.security,
                          color: AppTheme.infoColor, size: 16),
                      tooltip: '权限配置',
                      onPressed: onPermissionPreview,
                      padding: const EdgeInsets.all(6),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ],
                if (user.role != 'admin') ...[
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.delete,
                          color: AppTheme.errorColor, size: 16),
                      tooltip: '删除',
                      onPressed: onDelete,
                      padding: const EdgeInsets.all(6),
                      constraints:
                          const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryColor, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Builder(builder: (context) {
          final imageData = user.imageData;
          if (imageData != null && imageData.isNotEmpty) {
            return Image.memory(
              Uint8List.fromList(imageData),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: context.tokens.border,
                  child: Icon(
                    Icons.error_outline,
                    size: 20,
                    color: context.tokens.textMuted,
                  ),
                );
              },
            );
          }
          return Container(
            color: Colors.grey.shade100,
            child: user.role == 'doctor' || user.role == 'admin'
                ? Image.asset(
                    'assets/icons/doctor.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  )
                : Image.asset(
                    'assets/icons/nurse.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildPermissionTags() {
    final moduleInfo = {
      'patients': {'name': '患者', 'color': AppTheme.successColor},
      'appointments': {'name': '预约', 'color': AppTheme.infoColor},
      'financial': {'name': '财务', 'color': AppTheme.warningColor},
      'materials': {'name': '材料', 'color': AppTheme.primaryColor},
      'purchase': {'name': '采购', 'color': AppTheme.errorColor},
      'medical_records': {'name': '病历', 'color': Colors.teal},
    };

    final allowedModules = user.allowedModules
        .where((module) => module != 'dashboard') // 排除仪表盘
        .toList();

    if (allowedModules.isEmpty) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            '仅可访问仪表盘',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: allowedModules.take(3).map((module) {
        final info = moduleInfo[module];
        if (info == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (info['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (info['color'] as Color).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            info['name'] as String,
            style: TextStyle(
              color: info['color'] as Color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList()
        ..addAll(allowedModules.length > 3
            ? [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${allowedModules.length - 3}',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]
            : []),
    );
  }
}

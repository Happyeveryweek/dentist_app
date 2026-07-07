import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'dart:typed_data';
import '../../../models/user.dart';

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
      'admin': LinearGradient(colors: [
        context.tokens.error,
        context.tokens.error.withValues(alpha: 0.75),
      ]),
      'doctor': LinearGradient(colors: [
        context.tokens.success,
        context.tokens.success.withValues(alpha: 0.75),
      ]),
      'assistant': LinearGradient(colors: [
        context.tokens.warning,
        context.tokens.warning.withValues(alpha: 0.75),
      ]),
      'receptionist': LinearGradient(colors: [
        context.tokens.info,
        context.tokens.info.withValues(alpha: 0.75),
      ]),
    };

    return Container(
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.tokens.shadow.withValues(alpha: 0.12),
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
                  _buildUserAvatar(context),
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
                                    context.tokens.primaryHeaderGradient,
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
                          _buildPermissionTags(context),
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
                    color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.lock,
                        color: context.tokens.primaryAccent, size: 16),
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
                      color: context.tokens.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit,
                        color: context.tokens.success, size: 16),
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
                      color: context.tokens.info.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.security,
                          color: context.tokens.info, size: 16),
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
                      color: context.tokens.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete,
                          color: context.tokens.error, size: 16),
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

  Widget _buildUserAvatar(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.tokens.primaryAccent, width: 2),
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
              gaplessPlayback: true,
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
            color: context.tokens.mutedBackground,
            child: user.role == 'doctor' || user.role == 'admin'
                ? Image.asset(
                    'assets/icons/doctor.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : Image.asset(
                    'assets/icons/nurse.png',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          );
        }),
      ),
    );
  }

  Widget _buildPermissionTags(BuildContext context) {
    final moduleInfo = {
      'patients': {'name': '患者', 'color': context.tokens.success},
      'appointments': {'name': '预约', 'color': context.tokens.info},
      'financial': {'name': '财务', 'color': context.tokens.warning},
      'materials': {'name': '材料', 'color': context.tokens.primaryAccent},
      'purchase': {'name': '采购', 'color': context.tokens.error},
      'medical_records': {'name': '病历', 'color': context.tokens.secondaryAccent},
    };

    final allowedModules = user.allowedModules
        .where((module) => module != 'dashboard') // 排除仪表盘
        .toList();

    if (allowedModules.isEmpty) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 12, color: context.tokens.textMuted),
          const SizedBox(width: 4),
          Text(
            '仅可访问仪表盘',
            style: TextStyle(
              color: context.tokens.textMuted,
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
                    color: context.tokens.disabledBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${allowedModules.length - 3}',
                    style: TextStyle(
                      color: context.colors.onSurfaceVariant,
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

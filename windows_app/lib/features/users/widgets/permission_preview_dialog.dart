import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../models/user.dart';
import '../../../widgets/dental_icons.dart';

/// 权限预览对话框
/// 用于显示用户的权限配置
class PermissionPreviewDialog extends StatelessWidget {
  final User user;
  final VoidCallback? onEditPermission;

  const PermissionPreviewDialog({
    Key? key,
    required this.user,
    this.onEditPermission,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final moduleInfo = {
      'dashboard': {
        'name': '仪表盘',
        'icon': Icons.dashboard,
        'color': context.tokens.primaryAccent
      },
      'patients': {
        'name': '患者管理',
        'icon': Icons.people,
        'color': context.tokens.success
      },
      'appointments': {
        'name': '预约管理',
        'icon': Icons.calendar_today,
        'color': context.tokens.info
      },
      'financial': {
        'name': '财务管理',
        'icon': Icons.account_balance_wallet,
        'color': context.tokens.warning
      },
      'materials': {
        'name': '材料管理',
        'icon': Icons.inventory,
        'color': context.tokens.primaryAccent
      },
      'purchase': {
        'name': '采购管理',
        'icon': Icons.shopping_cart,
        'color': context.tokens.error
      },
      'medical_records': {
        'name': '病历管理',
        'icon': Icons.medical_services,
        'color': context.tokens.secondaryAccent
      },
    };
    final accentColor = context.tokens.primaryAccent;
    final textColor = context.colors.onSurface;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.security, color: accentColor, size: 24),
          const SizedBox(width: 12),
          Text(
            '${user.username} 的权限配置',
            style: TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      content: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '当前用户可以访问以下功能模块：',
              style: TextStyle(
                color: context.tokens.iconMuted,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: moduleInfo.entries.map((entry) {
                  final module = entry.key;
                  final info = entry.value;
                  final hasPermission = user.hasModulePermission(module);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: hasPermission
                          ? (info['color'] as Color).withValues(alpha: 0.1)
                          : context.tokens.mutedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasPermission
                            ? (info['color'] as Color).withValues(alpha: 0.3)
                            : context.tokens.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          info['icon'] as IconData,
                          color: hasPermission
                              ? (info['color'] as Color)
                              : context.tokens.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            info['name'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: hasPermission
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: hasPermission
                                  ? (info['color'] as Color)
                                  : context.tokens.iconMuted,
                            ),
                          ),
                        ),
                        Icon(
                          hasPermission ? Icons.check_circle : Icons.cancel,
                          color: hasPermission
                              ? context.tokens.success
                              : context.tokens.textMuted,
                          size: 20,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        DentalGradientButton(
          text: '编辑权限',
          icon: Icons.edit,
          onPressed: () {
            Navigator.of(context).pop();
            onEditPermission?.call();
          },
        ),
        const SizedBox(width: 12),
        DentalGradientButton(
          text: '关闭',
          onPressed: () => Navigator.of(context).pop(),
          isOutlined: true,
        ),
      ],
    );
  }
}

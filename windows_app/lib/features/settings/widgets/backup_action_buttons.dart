import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/dental_icons.dart';
import 'setting_item.dart';

/// 备份操作按钮组件
/// 包含数据备份和恢复备份两个按钮
class BackupActionButtons extends StatelessWidget {
  final bool isBackingUp;
  final bool isRestoring;
  final VoidCallback onBackup;
  final VoidCallback onRestore;

  const BackupActionButtons({
    Key? key,
    required this.isBackingUp,
    required this.isRestoring,
    required this.onBackup,
    required this.onRestore,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    // 数据备份和恢复备份功能 - 放在同一行，各占一半空间
    return Row(
      children: [
        // 数据备份功能 - 左侧
        Expanded(
          child: SettingItem(
            icon: Icons.backup,
            title: '数据备份',
            subtitle: settingsProvider.backupDataSource == 'mysql'
                ? '将MySQL数据库导出为SQL文件'
                : '将SQLite数据库文件直接复制备份',
            trailing: isBackingUp
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.tokens.primaryAccent),
                      strokeWidth: 2,
                    ),
                  )
                : DentalGradientButton(
                    text: '备份',
                    icon: Icons.save,
                    onPressed: onBackup,
                  ),
          ),
        ),

        const SizedBox(width: 16), // 两个功能之间的间距

        // 恢复备份功能 - 右侧
        Expanded(
          child: SettingItem(
            icon: Icons.restore,
            title: '恢复备份',
            subtitle: settingsProvider.dataSourceType == 'mysql'
                ? '从SQL文件恢复MySQL数据库'
                : '从.db文件恢复SQLite数据库',
            trailing: isRestoring
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: CircularProgressIndicator(
                      valueColor:
                          AlwaysStoppedAnimation<Color>(context.tokens.primaryAccent),
                      strokeWidth: 2,
                    ),
                  )
                : DentalGradientButton(
                    text: '选择文件',
                    icon: Icons.file_open,
                    onPressed: onRestore,
                  ),
          ),
        ),
      ],
    );
  }
}

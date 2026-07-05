import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';

class DataSourceSelectionDialog extends StatelessWidget {
  const DataSourceSelectionDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.storage, color: context.tokens.primaryAccent),
          const SizedBox(width: 12),
          const Text('选择检测数据源'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '请选择要检测的数据库类型：',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),

          // SQLite选项
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            child: ElevatedButton.icon(
              icon: Icon(Icons.storage, color: tokens.primaryAccent),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SQLite 本地数据库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tokens.primaryAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '检测本地SQLite数据库表结构',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.primaryAccent,
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primaryAccent.withValues(alpha: 0.1),
                foregroundColor: tokens.primaryAccent,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: tokens.primaryAccent.withValues(alpha: 0.2)),
                ),
              ),
              onPressed: () => Navigator.of(context).pop('sqlite'),
            ),
          ),

          // MySQL选项
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.cloud, color: tokens.success),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MySQL 远程数据库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: tokens.success,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    settingsProvider.isMySQLSettingsComplete()
                        ? '检测MySQL远程数据库表结构'
                        : '需要先配置MySQL连接参数',
                    style: TextStyle(
                      fontSize: 12,
                      color: settingsProvider.isMySQLSettingsComplete()
                          ? tokens.success
                          : tokens.error,
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: settingsProvider.isMySQLSettingsComplete()
                    ? tokens.successContainer
                    : tokens.inputBackground,
                foregroundColor: settingsProvider.isMySQLSettingsComplete()
                    ? tokens.success
                    : tokens.iconMuted,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: settingsProvider.isMySQLSettingsComplete()
                        ? tokens.success.withValues(alpha: 0.2)
                        : tokens.divider,
                  ),
                ),
              ),
              onPressed: settingsProvider.isMySQLSettingsComplete()
                  ? () => Navigator.of(context).pop('mysql')
                  : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

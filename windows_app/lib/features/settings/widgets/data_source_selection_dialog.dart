import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/settings_provider.dart';

class DataSourceSelectionDialog extends StatelessWidget {
  const DataSourceSelectionDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.storage, color: AppTheme.primaryColor),
          SizedBox(width: 12),
          Text('选择检测数据源'),
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
              icon: Icon(Icons.storage, color: Colors.blue.shade700),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SQLite 本地数据库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '检测本地SQLite数据库表结构',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.tokens.primaryAccent,
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue.shade200),
                ),
              ),
              onPressed: () => Navigator.of(context).pop('sqlite'),
            ),
          ),

          // MySQL选项
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: Icon(Icons.cloud, color: context.tokens.success),
              label: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MySQL 远程数据库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.tokens.success,
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
                          ? Colors.green.shade600
                          : context.tokens.error,
                    ),
                  ),
                ],
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: settingsProvider.isMySQLSettingsComplete()
                    ? Colors.green.shade50
                    : Colors.grey.shade100,
                foregroundColor: settingsProvider.isMySQLSettingsComplete()
                    ? context.tokens.success
                    : context.tokens.iconMuted,
                padding: const EdgeInsets.all(16),
                alignment: Alignment.centerLeft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: settingsProvider.isMySQLSettingsComplete()
                        ? Colors.green.shade200
                        : Colors.grey.shade300,
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';

class BackupInfoDisplay extends StatelessWidget {
  const BackupInfoDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tokens.infoContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.info),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: tokens.primaryAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前备份数据源',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: tokens.primaryAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  settingsProvider.backupDataSource == 'mysql'
                      ? 'MySQL 远程数据库 (SQL导出备份)'
                      : 'SQLite 本地数据库 (文件复制备份)',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.primaryAccent,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: settingsProvider.backupDataSource == 'mysql'
                  ? tokens.successContainer
                  : tokens.infoContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: settingsProvider.backupDataSource == 'mysql'
                    ? tokens.success
                    : tokens.primaryAccent,
                width: 1,
              ),
            ),
            child: Text(
              settingsProvider.backupDataSource == 'mysql' ? 'MySQL' : 'SQLite',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: settingsProvider.backupDataSource == 'mysql'
                    ? tokens.success
                    : tokens.primaryAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

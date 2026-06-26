import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/settings_provider.dart';

class AutoBackupSettings extends StatelessWidget {
  const AutoBackupSettings({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final lastBackupDate = settingsProvider.lastBackupDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.schedule,
                  color: AppTheme.primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '自动备份',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    settingsProvider.autoBackup
                        ? '每${settingsProvider.backupInterval}天自动备份一次'
                        : '自动备份已关闭',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: settingsProvider.autoBackup,
              activeThumbColor: AppTheme.primaryColor,
              onChanged: (value) async {
                await settingsProvider.setAutoBackup(value);
              },
            ),
          ],
        ),

        // 显示上次备份时间（无论是否启用自动备份）
        if (lastBackupDate != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.history,
                    size: 16, color: AppTheme.secondaryText),
                const SizedBox(width: 8),
                Text(
                  '上次备份: ${DateFormat('yyyy-MM-dd HH:mm').format(lastBackupDate)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),

        // 仅当自动备份开启时显示备份间隔设置
        if (settingsProvider.autoBackup)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 8, bottom: 16),
            child: Row(
              children: [
                const Text('备份间隔: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: settingsProvider.backupInterval,
                  items: [1, 3, 5, 7, 14, 30].map((days) {
                    return DropdownMenuItem<int>(
                      value: days,
                      child: Text('$days 天'),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      await settingsProvider.setBackupInterval(value);
                    }
                  },
                ),
              ],
            ),
          ),

        const Divider(),
      ],
    );
  }
}

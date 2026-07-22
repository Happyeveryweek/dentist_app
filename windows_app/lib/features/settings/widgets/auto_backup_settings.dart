import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/compact_dropdown_form_field.dart';

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
                color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.schedule,
                  color: context.tokens.primaryAccent, size: 20),
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
                      color: context.colors.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              mouseCursor: SystemMouseCursors.click,
              value: settingsProvider.autoBackup,
              activeThumbColor: context.tokens.primaryAccent,
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
                Icon(Icons.history, size: 16, color: context.tokens.textMuted),
                const SizedBox(width: 8),
                Text(
                  '上次备份: ${DateFormat('yyyy-MM-dd HH:mm').format(lastBackupDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.tokens.textMuted,
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
                SizedBox(
                  width: 100,
                  child: CompactDropdownFormField<int>(
                    value: settingsProvider.backupInterval,
                    menuMaxHeight: 220,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.tokens.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: context.tokens.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            BorderSide(color: context.tokens.primaryAccent),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: [1, 3, 5, 7, 14, 30].map((days) {
                      return CompactDropdownItem<int>(
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
                ),
              ],
            ),
          ),

        const Divider(),
      ],
    );
  }
}

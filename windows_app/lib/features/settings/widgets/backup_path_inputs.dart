import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/theme_context_extensions.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/dental_icons.dart';

/// 备份目录输入组件
/// 包含两个备份目录的输入框和浏览按钮
class BackupPathInputs extends StatelessWidget {
  final TextEditingController backupPathController;
  final TextEditingController backupPath2Controller;
  final Function(bool) onSelectDirectory;

  const BackupPathInputs({
    Key? key,
    required this.backupPathController,
    required this.backupPath2Controller,
    required this.onSelectDirectory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 备份目录1
        Expanded(
          child: _buildBackupPathInput(
            context,
            settingsProvider,
            backupPathController,
            '备份目录 1:',
            false,
          ),
        ),
        const SizedBox(width: 24),
        // 备份目录2
        Expanded(
          child: _buildBackupPathInput(
            context,
            settingsProvider,
            backupPath2Controller,
            '备份目录 2:',
            true,
          ),
        ),
      ],
    );
  }

  Widget _buildBackupPathInput(
    BuildContext context,
    SettingsProvider settingsProvider,
    TextEditingController controller,
    String label,
    bool isSecondPath,
  ) {
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.folder, color: tokens.secondaryAccent, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.secondaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '请输入备份目录或留空',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: tokens.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: tokens.secondaryAccent, width: 2),
                  ),
                  filled: true,
                  fillColor: tokens.cardBackground,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _getSuffixIcon(
                      settingsProvider, controller, isSecondPath),
                ),
                onChanged: (value) async {
                  if (isSecondPath) {
                    await settingsProvider.setBackupPath2(value);
                  } else {
                    await settingsProvider.setBackupPath(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            DentalGradientButton(
              text: '浏览',
              icon: Icons.folder_open,
              onPressed: () => onSelectDirectory(isSecondPath),
              isOutlined: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget? _getSuffixIcon(
    SettingsProvider settingsProvider,
    TextEditingController controller,
    bool isSecondPath,
  ) {
    final path = isSecondPath
        ? settingsProvider.backupPath2
        : settingsProvider.backupPath;
    if (path.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear, size: 18),
        onPressed: () async {
          if (isSecondPath) {
            await settingsProvider.setBackupPath2('');
          } else {
            await settingsProvider.setBackupPath('');
          }
          controller.text = '';
        },
      );
    }
    return null;
  }
}

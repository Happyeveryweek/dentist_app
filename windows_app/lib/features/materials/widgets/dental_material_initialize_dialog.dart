import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class DentalMaterialInitializeDialog extends StatelessWidget {
  const DentalMaterialInitializeDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.cardBackground,
              tokens.warningContainer,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: tokens.shadow.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tokens.warning, tokens.warning.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tokens.cardBackground.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_backup_restore_rounded,
                      color: tokens.cardBackground,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '初始化默认材料',
                      style: TextStyle(
                        color: tokens.cardBackground,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 内容区域
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tokens.warningContainer,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tokens.warning.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: tokens.warning,
                          size: 32,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '这将初始化系统默认的牙科材料清单，包括常用药品、器械等。此操作不可撤销。',
                            style: TextStyle(
                              fontSize: 14,
                              color: tokens.warning,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('取消'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tokens.warning,
                          foregroundColor: tokens.cardBackground,
                        ),
                        child: const Text('确认初始化'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

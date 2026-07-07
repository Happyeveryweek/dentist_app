import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 病历模板初始化确认对话框
class MedicalTemplateInitializeConfirmDialog extends StatelessWidget {
  final VoidCallback onConfirm;

  const MedicalTemplateInitializeConfirmDialog({
    Key? key,
    required this.onConfirm,
  }) : super(key: key);

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
                  colors: [tokens.warning, tokens.warningAccent],
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
                      color: context.tokens.cardBackground.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_backup_restore_rounded,
                      color: context.tokens.cardBackground,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '初始化病历模板数据',
                      style: TextStyle(
                        color: context.tokens.cardBackground,
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
                            '此操作将初始化病历模板数据，包括：\n\n'
                            '• 牙科疾病类型（龋齿、牙周病、根尖周病等）\n'
                            '• 全身疾病类型（高血压、糖尿病、心脏病等）\n'
                            '• 过敏类型（药物过敏、食物过敏等）\n\n'
                            '⚠️ 重要提醒：此操作将清空现有模板数据并重新初始化！\n\n'
                            '✅ 安全提示：此操作不会影响现有的患者病历数据。\n\n'
                            '如果您需要重置病历模板数据，请执行此操作。',
                            style: TextStyle(
                              fontSize: 16,
                              color: tokens.warning,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 按钮栏
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: tokens.mutedBackground,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: context.tokens.textMuted),
                      ),
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                      onConfirm();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tokens.warning,
                      foregroundColor: tokens.cardBackground,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    child: const Text(
                      '开始初始化',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

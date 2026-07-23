import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 采购记录表单的操作按钮区域
/// 包含：取消按钮、保存/更新按钮
class PurchaseFormActionsSection extends StatelessWidget {
  final bool isEditing;
  final bool isLoading;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  const PurchaseFormActionsSection({
    super.key,
    required this.isEditing,
    required this.isLoading,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 16,
      runSpacing: 12,
      children: [
        OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('取消'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: isLoading ? null : onSave,
          icon: isLoading
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: tokens.cardBackground,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save, size: 18),
          label: Text(isLoading ? '保存中...' : '保存'),
          style: ElevatedButton.styleFrom(
            backgroundColor: tokens.primaryAccent,
            foregroundColor: context.colors.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          ),
        ),
      ],
    );
  }
}

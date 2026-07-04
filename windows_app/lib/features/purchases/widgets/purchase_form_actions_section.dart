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
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 16,
      runSpacing: 12,
      children: [
        // 取消按钮
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade100,
                context.tokens.border,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onCancel,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: context.tokens.iconMuted,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.tokens.iconMuted,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // 保存/更新按钮
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.teal.shade400,
                Colors.teal.shade600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.teal.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isLoading ? null : onSave,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading) ...[
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: context.tokens.cardBackground,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isEditing ? '更新中...' : '保存中...',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.cardBackground,
                        ),
                      ),
                    ] else ...[
                      Icon(
                        isEditing ? Icons.update : Icons.add,
                        size: 16,
                        color: context.tokens.cardBackground,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEditing ? '更新记录' : '添加记录',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.cardBackground,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

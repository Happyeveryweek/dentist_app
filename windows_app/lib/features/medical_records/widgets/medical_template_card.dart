import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/medical_template.dart';

/// 医疗模板卡片组件
/// 显示单个模板卡片，包含图标、标题、类型标签、内容预览、编辑/删除按钮
class MedicalTemplateCard extends StatelessWidget {
  final MedicalTemplate template;
  final String templateType;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MedicalTemplateCard({
    Key? key,
    required this.template,
    required this.templateType,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final isTreatment = templateType == 'treatment';
    final cardColor = isTreatment ? tokens.info : tokens.success;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: cardColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 模板图标
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    cardColor,
                    cardColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                isTreatment ? Icons.healing_rounded : Icons.note_add_rounded,
                color: tokens.cardBackground,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),

            // 模板信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 模板标题
                  Text(
                    template.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 模板类型标签
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cardColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isTreatment ? '治疗方案模板' : '医嘱模板',
                      style: TextStyle(
                        fontSize: 12,
                        color: cardColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 模板内容预览
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.mutedBackground,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tokens.border,
                      ),
                    ),
                    child: Text(
                      template.content,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.iconMuted,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // 操作按钮
            Column(
              children: [
                // 编辑按钮
                Container(
                  decoration: BoxDecoration(
                    color: tokens.primaryAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: tokens.primaryAccent,
                    tooltip: '编辑模板',
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
                const SizedBox(height: 8),

                // 删除按钮
                Container(
                  decoration: BoxDecoration(
                    color: tokens.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: tokens.error,
                    tooltip: '删除模板',
                    padding: const EdgeInsets.all(8),
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

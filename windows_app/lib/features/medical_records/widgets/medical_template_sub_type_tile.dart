import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/medical_record_template.dart';
import '../helpers/medical_template_category_style_helper.dart';

/// 病历模板子类型列表项
class MedicalTemplateSubTypeTile extends StatelessWidget {
  final MedicalRecordTemplate subType;
  final String category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const MedicalTemplateSubTypeTile({
    Key? key,
    required this.subType,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 子类型图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: MedicalTemplateCategoryStyleHelper.getCategoryColor(
                        category)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.subdirectory_arrow_right,
                color: MedicalTemplateCategoryStyleHelper.getCategoryColor(
                    category),
                size: 16,
              ),
            ),
            const SizedBox(width: 12),

            // 子类型信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subType.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  if (subType.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subType.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.tokens.iconMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 编辑按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    color: Colors.blue,
                    tooltip: '编辑',
                    padding: const EdgeInsets.all(6),
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ),
                const SizedBox(width: 6),
                // 删除按钮
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 16),
                    color: Colors.red,
                    tooltip: '删除',
                    padding: const EdgeInsets.all(6),
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
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

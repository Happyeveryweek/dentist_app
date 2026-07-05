import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/medical_template.dart';
import 'medical_template_card.dart';

/// 医疗模板列表组件
/// 显示模板列表，包含工具栏（标题、统计、添加按钮）和列表内容
class MedicalTemplateList extends StatelessWidget {
  final List<MedicalTemplate> templates;
  final String templateType;
  final String title;
  final VoidCallback onAdd;
  final Function(MedicalTemplate) onEdit;
  final Function(MedicalTemplate) onDelete;

  const MedicalTemplateList({
    Key? key,
    required this.templates,
    required this.templateType,
    required this.title,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final isTreatment = templateType == 'treatment';
    final themeColor = isTreatment ? tokens.primaryAccent : tokens.success;

    return Column(
      children: [
        // 美化的工具栏
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeColor.withValues(alpha: 0.1),
                themeColor.withValues(alpha: 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: themeColor.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              // 图标和标题
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTreatment ? Icons.healing_rounded : Icons.note_add_rounded,
                  color: themeColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '共 ${templates.length} 个模板',
                      style: TextStyle(
                        fontSize: 14,
                        color: themeColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              // 添加按钮
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor, themeColor.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: onAdd,
                  icon: Icon(Icons.add_rounded, color: colors.onPrimary),
                  label: Text(
                    '添加模板',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 列表内容
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 16),
            itemCount: templates.length,
            itemBuilder: (context, index) {
              final template = templates[index];
              return MedicalTemplateCard(
                template: template,
                templateType: templateType,
                onEdit: () => onEdit(template),
                onDelete: () => onDelete(template),
              );
            },
          ),
        ),
      ],
    );
  }

}

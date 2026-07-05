import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/medical_template.dart';
import '../../../services/medical_template_service.dart';

/// 模板选择组件
class TemplateSelectionWidget extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String hint;
  final List<Map<String, String>> templates;
  final Set<String> selectedTemplates;
  final Function(String title, String content) onTemplateSelected;

  const TemplateSelectionWidget({
    Key? key,
    required this.title,
    required this.icon,
    required this.color,
    required this.hint,
    required this.templates,
    required this.selectedTemplates,
    required this.onTemplateSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              Text(
                hint,
                style: TextStyle(
                  fontSize: 14,
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: templates.map((template) {
                  final templateTitle = template['title'] ?? '';
                  final templateContent = template['content'] ?? '';
                  final isSelected = selectedTemplates.contains(templateTitle);

                  return isSelected
                      ? ElevatedButton(
                          onPressed: () {
                            onTemplateSelected(templateTitle, templateContent);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: color,
                            foregroundColor: context.tokens.cardBackground,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                templateTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle, size: 14),
                            ],
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () {
                            onTemplateSelected(templateTitle, templateContent);
                          },
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: color),
                            foregroundColor: color,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          child: Text(
                            templateTitle,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 治疗方案模板组件
class TreatmentTemplateWidget extends StatelessWidget {
  final Set<String> selectedTreatmentTemplates;
  final TextEditingController treatmentPlanController;
  final Function(Set<String>, String) onTemplateChanged;

  const TreatmentTemplateWidget({
    Key? key,
    required this.selectedTreatmentTemplates,
    required this.treatmentPlanController,
    required this.onTemplateChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MedicalTemplate>>(
      future: MedicalTemplateService.getTreatmentTemplates(),
      builder: (context, snapshot) {
        final treatmentTemplates = snapshot.data ?? [];

        // 如果没有加载到模板，使用默认模板
        if (treatmentTemplates.isEmpty) {
          final defaultTemplates = [
            {
              'title': '洁牙治疗',
              'content': '1. 超声波洁牙\n2. 抛光处理\n3. 氟化物涂布\n4. 口腔卫生指导'
            },
            {
              'title': '充填治疗',
              'content': '1. 局部麻醉\n2. 去除龋坏组织\n3. 窝洞预备\n4. 充填材料填充\n5. 形态调整和抛光'
            },
            {
              'title': '根管治疗',
              'content': '1. 开髓引流\n2. 根管预备\n3. 根管消毒\n4. 根管充填\n5. 冠部修复'
            },
            {
              'title': '牙周治疗',
              'content': '1. 龈上洁治\n2. 龈下刮治\n3. 根面平整\n4. 局部药物治疗\n5. 维护期治疗'
            },
            {
              'title': '拔牙术',
              'content': '1. 术前检查\n2. 局部麻醉\n3. 牙齿拔除\n4. 创口处理\n5. 术后护理指导'
            },
          ];

          return TemplateSelectionWidget(
            title: '常用治疗方案模板',
            icon: Icons.library_books_rounded,
            color: context.tokens.secondaryAccent,
            hint: '点击下方模板快速填入治疗方案',
            templates: defaultTemplates,
            selectedTemplates: selectedTreatmentTemplates,
            onTemplateSelected: (title, content) {
              onTemplateChanged(selectedTreatmentTemplates, content);
            },
          );
        }

        return TemplateSelectionWidget(
          title: '常用治疗方案模板',
          icon: Icons.library_books_rounded,
          color: context.tokens.secondaryAccent,
          hint: '点击下方模板快速填入治疗方案',
          templates: treatmentTemplates
              .map((t) => {'title': t.title, 'content': t.content})
              .toList(),
          selectedTemplates: selectedTreatmentTemplates,
          onTemplateSelected: (title, content) {
            onTemplateChanged(selectedTreatmentTemplates, content);
          },
        );
      },
    );
  }
}

/// 医嘱模板组件
class NotesTemplateWidget extends StatelessWidget {
  final Set<String> selectedNotesTemplates;
  final TextEditingController notesController;
  final Function(Set<String>, String, String) onTemplateChanged;

  const NotesTemplateWidget({
    Key? key,
    required this.selectedNotesTemplates,
    required this.notesController,
    required this.onTemplateChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MedicalTemplate>>(
      future: MedicalTemplateService.getNotesTemplates(),
      builder: (context, snapshot) {
        final notesTemplates = snapshot.data ?? [];

        // 如果没有加载到模板，使用默认模板
        if (notesTemplates.isEmpty) {
          final defaultTemplates = [
            {
              'title': '术后护理',
              'content': '1. 术后2小时内禁食\n2. 24小时内避免刷牙漱口\n3. 避免用患侧咀嚼\n4. 如有异常及时复诊'
            },
            {
              'title': '用药指导',
              'content': '1. 按时服用抗生素\n2. 疼痛时可服用止痛药\n3. 注意药物过敏反应\n4. 完成整个疗程'
            },
            {
              'title': '口腔卫生',
              'content': '1. 早晚刷牙，饭后漱口\n2. 使用软毛牙刷\n3. 配合使用牙线\n4. 定期口腔检查'
            },
            {
              'title': '复诊安排',
              'content': '1. 一周后复查\n2. 观察愈合情况\n3. 必要时调整治疗方案\n4. 长期随访观察'
            },
            {
              'title': '饮食建议',
              'content': '1. 避免过硬食物\n2. 减少甜食摄入\n3. 多吃富含维生素食物\n4. 充足饮水'
            },
          ];

          return TemplateSelectionWidget(
            title: '常用医嘱模板',
            icon: Icons.note_add_rounded,
            color: context.tokens.info,
            hint: '点击下方模板快速填入注意事项',
            templates: defaultTemplates,
            selectedTemplates: selectedNotesTemplates,
            onTemplateSelected: (title, content) {
              onTemplateChanged(selectedNotesTemplates, title, content);
            },
          );
        }

        return TemplateSelectionWidget(
          title: '常用医嘱模板',
          icon: Icons.note_add_rounded,
          color: context.tokens.info,
          hint: '点击下方模板快速填入注意事项',
          templates: notesTemplates
              .map((t) => {'title': t.title, 'content': t.content})
              .toList(),
          selectedTemplates: selectedNotesTemplates,
          onTemplateSelected: (title, content) {
            onTemplateChanged(selectedNotesTemplates, title, content);
          },
        );
      },
    );
  }
}

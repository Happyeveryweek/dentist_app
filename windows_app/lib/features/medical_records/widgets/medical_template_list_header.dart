import 'package:flutter/material.dart';
import '../helpers/medical_template_category_style_helper.dart';

/// 病历模板列表工具栏
/// 显示图标、标题、统计、添加按钮
class MedicalTemplateListHeader extends StatelessWidget {
  final String category;
  final String title;
  final int count;
  final VoidCallback onAdd;

  const MedicalTemplateListHeader({
    Key? key,
    required this.category,
    required this.title,
    required this.count,
    required this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MedicalTemplateCategoryStyleHelper.getCategoryColor(category).withOpacity(0.1),
            MedicalTemplateCategoryStyleHelper.getCategoryColor(category).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MedicalTemplateCategoryStyleHelper.getCategoryColor(category).withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          // 图标和标题
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: MedicalTemplateCategoryStyleHelper.getCategoryColor(category).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              MedicalTemplateCategoryStyleHelper.getCategoryIcon(category),
              color: MedicalTemplateCategoryStyleHelper.getCategoryColor(category),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: MedicalTemplateCategoryStyleHelper.getCategoryColorDark(category),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '共 $count 个疾病类型',
                  style: TextStyle(
                    fontSize: 12,
                    color: MedicalTemplateCategoryStyleHelper.getCategoryColorMedium(category),
                  ),
                ),
              ],
            ),
          ),
          // 添加按钮 - 紧凑版
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  MedicalTemplateCategoryStyleHelper.getCategoryColor(category),
                  MedicalTemplateCategoryStyleHelper.getCategoryColorMedium(category),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: MedicalTemplateCategoryStyleHelper.getCategoryColor(category).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: const Text(
                '添加类型',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

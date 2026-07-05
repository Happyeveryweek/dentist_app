import 'package:flutter/material.dart';
import '../../../models/medical_record_template.dart';
import '../../../theme/medical_semantic_colors.dart';

/// 病历模板类别样式辅助类
/// 提供类别相关的颜色、图标等样式获取方法
class MedicalTemplateCategoryStyleHelper {
  /// 获取类别颜色
  static Color getCategoryColor(String category) {
    return MedicalSemanticColors.templateCategory(category);
  }

  /// 获取类别颜色的深色变体
  static Color getCategoryColorDark(String category) {
    return MedicalSemanticColors.templateCategoryDark(category);
  }

  /// 获取类别颜色的中等变体
  static Color getCategoryColorMedium(String category) {
    return MedicalSemanticColors.templateCategoryMedium(category);
  }

  /// 获取类别图标
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Icons.medical_services;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Icons.health_and_safety;
      case MedicalRecordTemplateCategory.allergy:
        return Icons.warning_amber;
      default:
        return Icons.category;
    }
  }
}

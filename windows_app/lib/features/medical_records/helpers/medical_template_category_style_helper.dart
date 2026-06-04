import 'package:flutter/material.dart';
import '../../../models/medical_record_template.dart';

/// 病历模板类别样式辅助类
/// 提供类别相关的颜色、图标等样式获取方法
class MedicalTemplateCategoryStyleHelper {
  /// 获取类别颜色
  static Color getCategoryColor(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Colors.blue;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Colors.green;
      case MedicalRecordTemplateCategory.allergy:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// 获取类别颜色的深色变体
  static Color getCategoryColorDark(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Colors.blue.shade700;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Colors.green.shade700;
      case MedicalRecordTemplateCategory.allergy:
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade700;
    }
  }

  /// 获取类别颜色的中等变体
  static Color getCategoryColorMedium(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return Colors.blue.shade600;
      case MedicalRecordTemplateCategory.systemicDisease:
        return Colors.green.shade600;
      case MedicalRecordTemplateCategory.allergy:
        return Colors.orange.shade600;
      default:
        return Colors.grey.shade600;
    }
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

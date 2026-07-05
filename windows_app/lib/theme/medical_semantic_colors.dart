import 'package:flutter/material.dart';

import '../models/medical_record_template.dart';

/// Medical and patient identity colors that should remain stable across themes.
///
/// These colors encode clinical/category meaning, not app appearance.
class MedicalSemanticColors {
  const MedicalSemanticColors._();

  // Patient identity colors.
  static const Color femaleGender = Color(0xFFE91E63);
  static const Color maleGender = Color(0xFF2196F3);
  static const Color unknownGender = Color(0xFFBDBDBD);

  // Medical record template category base colors.
  static const Color dentalDisease = Color(0xFF2196F3);
  static const Color systemicDisease = Color(0xFF4CAF50);
  static const Color allergy = Color(0xFFFF9800);
  static const Color uncategorized = Color(0xFF9E9E9E);

  // Dark variants used where the existing UI expects stronger category text.
  static const Color dentalDiseaseDark = Color(0xFF1976D2);
  static const Color systemicDiseaseDark = Color(0xFF388E3C);
  static const Color allergyDark = Color(0xFFF57C00);
  static const Color uncategorizedDark = Color(0xFF616161);

  // Medium variants used for icons and medium-emphasis category marks.
  static const Color dentalDiseaseMedium = Color(0xFF1E88E5);
  static const Color systemicDiseaseMedium = Color(0xFF43A047);
  static const Color allergyMedium = Color(0xFFFB8C00);
  static const Color uncategorizedMedium = Color(0xFF757575);

  // Dental clinical identity colors.
  static const Color toothIcon = Color(0xFF2196F3);
  static const Color dentalRecordTeal = Color(0xFF009688);

  static Color templateCategory(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return dentalDisease;
      case MedicalRecordTemplateCategory.systemicDisease:
        return systemicDisease;
      case MedicalRecordTemplateCategory.allergy:
        return allergy;
      default:
        return uncategorized;
    }
  }

  static Color templateCategoryDark(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return dentalDiseaseDark;
      case MedicalRecordTemplateCategory.systemicDisease:
        return systemicDiseaseDark;
      case MedicalRecordTemplateCategory.allergy:
        return allergyDark;
      default:
        return uncategorizedDark;
    }
  }

  static Color templateCategoryMedium(String category) {
    switch (category) {
      case MedicalRecordTemplateCategory.dentalDisease:
        return dentalDiseaseMedium;
      case MedicalRecordTemplateCategory.systemicDisease:
        return systemicDiseaseMedium;
      case MedicalRecordTemplateCategory.allergy:
        return allergyMedium;
      default:
        return uncategorizedMedium;
    }
  }

  static Color gender(String gender) {
    final normalized = gender.toLowerCase();
    if (gender == '女' || normalized == 'female') {
      return femaleGender;
    }
    if (gender == '男' || normalized == 'male') {
      return maleGender;
    }
    return unknownGender;
  }
}

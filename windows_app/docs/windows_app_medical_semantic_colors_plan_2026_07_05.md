# Windows 端医学识别色集中治理方案

## 文档定位

本文件只处理阶段 7 之后剩余的医学识别色、患者识别色和医疗业务固定色，不处理普通主题色。

目标是把散落在页面里的 `Colors.blue`、`Colors.green`、`Colors.orange`、`Colors.grey`、`Color(0xFF009688)`、`DentalColors.femalePink`、`DentalColors.maleBlue` 集中到一个医学语义颜色入口，后续主题扩展时不需要逐页面查找。

本方案给其它模型直接实施使用，不需要重新扫描、重新判断。

## 当前结论

阶段 7 普通主题色迁移已基本完成；剩余颜色不是页面背景、边框、按钮、弱文字这类普通主题色，而是医学/患者识别语义色。

当前剩余直接颜色扫描结果：

```text
direct_colors: 19
```

这 19 处集中在 6 个文件：

| 文件 | 剩余数量 | 类型 |
| --- | ---: | --- |
| `lib/features/medical_records/helpers/medical_template_category_style_helper.dart` | 12 | 病历模板类别识别色 |
| `lib/features/medical_records/widgets/disease_type_edit_dialog.dart` | 3 | 疾病类型下拉图标识别色 |
| `lib/features/appointments/widgets/appointment_details_teeth_section.dart` | 1 | 牙齿图标识别色 |
| `lib/features/financial/helpers/financial_calculation_helper.dart` | 1 | 未知性别头像中性色 |
| `lib/features/patients/widgets/patient_form_sections.dart` | 1 | 病历/牙科青色识别色定义 |
| `lib/features/patients/widgets/patient_medical_record_detail_dialog.dart` | 1 | 病历/牙科青色识别色定义 |

当前剩余 `DentalColors.`：

```text
dental_colors: 26
```

这些全部是患者性别识别色 `DentalColors.femalePink` / `DentalColors.maleBlue`，也应该纳入同一个医学语义入口。

## 设计原则

1. 医学识别色可以固定，但不能散落写死在业务页面。
2. 医学识别色不放进 `AppThemeTokens`，因为它们不是医疗蓝、紫粉灰、绿色清新这类外观主题色。
3. 医学识别色新建独立入口：`MedicalSemanticColors`。
4. 页面和组件不再直接写 `Colors.blue`、`Colors.green`、`Colors.orange`、`Colors.grey`、`Color(0xFF009688)`。
5. `DentalColors.femalePink` / `DentalColors.maleBlue` 最终也应迁到 `MedicalSemanticColors`，让 `DentalColors` 不再承担业务语义色职责。
6. 第一轮只集中现有色值，不改变视觉效果。

## 新增文件

新增：

`lib/theme/medical_semantic_colors.dart`

文件内容按下面实现，不要放到 `app_theme_tokens.dart`：

```dart
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
```

说明：

- `Color(0xFFBDBDBD)` 对应当前 `Colors.grey.shade400`。
- `Color(0xFF1976D2)` 对应当前 `Colors.blue.shade700`。
- `Color(0xFF388E3C)` 对应当前 `Colors.green.shade700`。
- `Color(0xFFF57C00)` 对应当前 `Colors.orange.shade700`。
- `Color(0xFF616161)` 对应当前 `Colors.grey.shade700`。
- `Color(0xFF1E88E5)` 对应当前 `Colors.blue.shade600`。
- `Color(0xFF43A047)` 对应当前 `Colors.green.shade600`。
- `Color(0xFFFB8C00)` 对应当前 `Colors.orange.shade600`。
- `Color(0xFF757575)` 对应当前 `Colors.grey.shade600`。

## 第一阶段：治理 19 处直接医学识别色

### 1. `medical_template_category_style_helper.dart`

文件：

`lib/features/medical_records/helpers/medical_template_category_style_helper.dart`

当前问题：

```dart
return Colors.blue;
return Colors.green;
return Colors.orange;
return Colors.grey;
return Colors.blue.shade700;
return Colors.green.shade700;
return Colors.orange.shade700;
return Colors.grey.shade700;
return Colors.blue.shade600;
return Colors.green.shade600;
return Colors.orange.shade600;
return Colors.grey.shade600;
```

修改：

1. 添加 import：

```dart
import '../../../theme/medical_semantic_colors.dart';
```

2. `getCategoryColor` 整个方法替换为：

```dart
static Color getCategoryColor(String category) {
  return MedicalSemanticColors.templateCategory(category);
}
```

3. `getCategoryColorDark` 整个方法替换为：

```dart
static Color getCategoryColorDark(String category) {
  return MedicalSemanticColors.templateCategoryDark(category);
}
```

4. `getCategoryColorMedium` 整个方法替换为：

```dart
static Color getCategoryColorMedium(String category) {
  return MedicalSemanticColors.templateCategoryMedium(category);
}
```

5. 保留 `getCategoryIcon` 不动。

6. 保留 `package:flutter/material.dart` import，因为文件仍使用 `Color` 和 `Icons`。

### 2. `disease_type_edit_dialog.dart`

文件：

`lib/features/medical_records/widgets/disease_type_edit_dialog.dart`

当前问题：

```dart
Icon(Icons.medical_services, size: 16, color: Colors.blue)
Icon(Icons.health_and_safety, size: 16, color: Colors.green)
Icon(Icons.warning_amber, size: 16, color: Colors.orange)
```

修改：

1. 添加 import：

```dart
import '../../../theme/medical_semantic_colors.dart';
```

2. 替换下拉项图标颜色：

```dart
Icon(
  Icons.medical_services,
  size: 16,
  color: MedicalSemanticColors.dentalDisease,
)
```

```dart
Icon(
  Icons.health_and_safety,
  size: 16,
  color: MedicalSemanticColors.systemicDisease,
)
```

```dart
Icon(
  Icons.warning_amber,
  size: 16,
  color: MedicalSemanticColors.allergy,
)
```

3. 当前 `items: const [...]` 可以继续保留，因为 `MedicalSemanticColors.*` 是 `static const Color`。

4. `backgroundColor: Colors.transparent` 保留，不属于医学识别色治理。

### 3. `appointment_details_teeth_section.dart`

文件：

`lib/features/appointments/widgets/appointment_details_teeth_section.dart`

当前问题：

```dart
const Icon(DentalIcons.tooth, color: Colors.blue, size: 18)
```

修改：

1. 添加 import：

```dart
import '../../../theme/medical_semantic_colors.dart';
```

2. 替换为：

```dart
const Icon(
  DentalIcons.tooth,
  color: MedicalSemanticColors.toothIcon,
  size: 18,
)
```

3. 这里可以继续保留 `const Icon`，因为 `toothIcon` 是 `static const Color`。

### 4. `financial_calculation_helper.dart`

文件：

`lib/features/financial/helpers/financial_calculation_helper.dart`

当前问题：

```dart
return DentalColors.femalePink;
return DentalColors.maleBlue;
return Colors.grey.shade400;
```

第一阶段只处理直接 `Colors.grey.shade400`：

1. 添加 import：

```dart
import '../../../theme/medical_semantic_colors.dart';
```

2. 替换未知性别返回值：

```dart
return MedicalSemanticColors.unknownGender;
```

3. 如果同步做第二阶段，则直接把整个方法替换为：

```dart
static Color getAvatarBackgroundColor(Patient patient) {
  return MedicalSemanticColors.gender(patient.gender);
}
```

4. 如果做了上一步，删除 `../../../widgets/dental_icons.dart` import；该文件当前只为了 `DentalColors` 使用它。

### 5. `patient_form_sections.dart`

文件：

`lib/features/patients/widgets/patient_form_sections.dart`

当前问题：

```dart
const Color dentalTeal = Color(0xFF009688);
```

实际使用：

```dart
color: dentalTeal.withValues(alpha: 0.1),
```

修改：

1. 添加 import：

```dart
import '../../../theme/medical_semantic_colors.dart';
```

2. 删除文件顶部局部常量：

```dart
const Color dentalTeal = Color(0xFF009688);
```

3. 替换使用：

```dart
color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.1),
```

### 6. `patient_medical_record_detail_dialog.dart`

文件：

`lib/features/patients/widgets/patient_medical_record_detail_dialog.dart`

当前问题：

```dart
const dentalTeal = Color(0xFF009688);
```

实际使用位置：

```text
line 629: Border.all(color: dentalTeal.withValues(alpha: 0.3), width: 1.5)
line 632: color: dentalTeal.withValues(alpha: 0.1)
line 649: color: dentalTeal.withValues(alpha: 0.05)
line 702: dentalTeal.withValues(alpha: 0.8)
line 703: dentalTeal.withValues(alpha: 0.6)
line 771: color: dentalTeal
line 784: color: dentalTeal.withValues(alpha: 0.6)
line 791: color: dentalTeal.withValues(alpha: 0.6)
line 866: color: dentalTeal.withValues(alpha: 0.6)
```

修改：

1. 添加 import：

```dart
import '../../../theme/medical_semantic_colors.dart';
```

2. 删除文件顶部局部常量：

```dart
const dentalTeal = Color(0xFF009688);
```

3. 逐项替换：

```dart
dentalTeal
```

替换为：

```dart
MedicalSemanticColors.dentalRecordTeal
```

示例：

```dart
Border.all(
  color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.3),
  width: 1.5,
)
```

```dart
colors: [
  MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.8),
  MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.6),
],
```

## 第二阶段：治理患者性别识别色

第二阶段建议一起做，但可以和第一阶段分开提交。

目标：不再让业务组件直接依赖 `DentalColors.femalePink` / `DentalColors.maleBlue`。

### 需要替换的文件

| 文件 | 当前字段 | 改法 |
| --- | --- | --- |
| `lib/screens/filtered_patients_screen.dart:125` | `DentalColors.femalePink.withValues(alpha: 0.2)` | `MedicalSemanticColors.femaleGender.withValues(alpha: 0.2)` |
| `lib/screens/filtered_patients_screen.dart:126` | `DentalColors.maleBlue.withValues(alpha: 0.2)` | `MedicalSemanticColors.maleGender.withValues(alpha: 0.2)` |
| `lib/screens/filtered_patients_screen.dart:128` | `DentalColors.femalePink : DentalColors.maleBlue` | `MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender` |
| `lib/screens/modern_dashboard_screen.dart:798` | `DentalColors.femalePink` | `MedicalSemanticColors.femaleGender` |
| `lib/screens/modern_dashboard_screen.dart:799` | `DentalColors.maleBlue` | `MedicalSemanticColors.maleGender` |
| `lib/screens/modern_dashboard_screen.dart:989` | `DentalColors.femalePink : DentalColors.maleBlue` | `MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender` |
| `lib/features/appointments/widgets/appointment_details_patient_card.dart:22` | `DentalColors.femalePink` | `MedicalSemanticColors.femaleGender` |
| `lib/features/appointments/widgets/appointment_details_patient_card.dart:23` | `DentalColors.maleBlue` | `MedicalSemanticColors.maleGender` |
| `lib/features/financial/helpers/financial_calculation_helper.dart:43` | `DentalColors.femalePink` | `MedicalSemanticColors.femaleGender` or `MedicalSemanticColors.gender(patient.gender)` |
| `lib/features/financial/helpers/financial_calculation_helper.dart:46` | `DentalColors.maleBlue` | `MedicalSemanticColors.maleGender` or `MedicalSemanticColors.gender(patient.gender)` |
| `lib/features/financial/widgets/financial_patient_info_section.dart:24` | `DentalColors.femalePink : DentalColors.maleBlue` | `MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender` |
| `lib/features/financial/widgets/financial_record_edit_dialog.dart:177` | `DentalColors.femalePink : DentalColors.maleBlue` | `MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender` |
| `lib/features/patients/widgets/patient_card.dart:74` | `DentalColors.femalePink` | `MedicalSemanticColors.femaleGender` |
| `lib/features/patients/widgets/patient_card.dart:75` | `DentalColors.maleBlue` | `MedicalSemanticColors.maleGender` |
| `lib/features/patients/widgets/patient_detail_financial_widgets.dart:289` | `(isFemale ? DentalColors.femalePink : DentalColors.maleBlue).withValues(alpha: 0.1)` | `(isFemale ? MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender).withValues(alpha: 0.1)` |
| `lib/features/patients/widgets/patient_detail_financial_widgets.dart:298` | `isFemale ? DentalColors.femalePink : DentalColors.maleBlue` | `isFemale ? MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender` |
| `lib/features/patients/widgets/patient_list_item.dart:40` | `DentalColors.femalePink.withValues(alpha: 0.2)` | `MedicalSemanticColors.femaleGender.withValues(alpha: 0.2)` |
| `lib/features/patients/widgets/patient_list_item.dart:41` | `DentalColors.maleBlue.withValues(alpha: 0.1)` | `MedicalSemanticColors.maleGender.withValues(alpha: 0.1)` |
| `lib/features/patients/widgets/patient_list_item.dart:43` | `DentalColors.femalePink : DentalColors.maleBlue` | `MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender` |

每个文件都需要添加：

```dart
import 'package:dentist_app_windows/theme/medical_semantic_colors.dart';
```

或按现有相对路径添加：

```dart
import '../../../theme/medical_semantic_colors.dart';
```

选择规则：

- `lib/screens/*.dart` 用 package import 更稳：
  `import 'package:dentist_app_windows/theme/medical_semantic_colors.dart';`
- `lib/features/**/widgets/*.dart` 可用相对路径：
  `import '../../../theme/medical_semantic_colors.dart';`
- `lib/features/**/helpers/*.dart` 可用相对路径：
  `import '../../../theme/medical_semantic_colors.dart';`

替换后，如果 `../../../widgets/dental_icons.dart` 或其它 `dental_icons.dart` import 只剩为了 `DentalColors`，删除该 import。

## 不要修改的内容

以下内容本方案不处理：

- `Colors.transparent`
- `context.tokens.chartPalette`
- `chartColors[index % chartColors.length]`
- `context.colors.*`
- `context.tokens.*`
- `AppTheme.standardTheme()`
- `AppTheme.smallBorderRadius`
- `AppTheme.dangerGradient`

## 验收命令

第一阶段完成后，运行：

```powershell
python scripts\theme_migration_assistant.py --scan --top 40
```

期望：

```text
direct_colors: 0
```

如果没有执行第二阶段，`dental_colors` 仍会剩余性别色，属于已知状态。

第二阶段完成后，运行：

```powershell
python scripts\theme_migration_assistant.py --scan --top 40
```

期望：

```text
dental_colors: 0
direct_colors: 0
purple: 0
```

允许 `app_theme: 3` 左右继续存在，但只能是：

- `AppTheme.standardTheme()`
- `AppTheme.smallBorderRadius`
- `AppTheme.dangerGradient`

 targeted analyze：

```powershell
flutter analyze lib/theme/medical_semantic_colors.dart lib/features/medical_records/helpers/medical_template_category_style_helper.dart lib/features/medical_records/widgets/disease_type_edit_dialog.dart lib/features/appointments/widgets/appointment_details_teeth_section.dart lib/features/financial/helpers/financial_calculation_helper.dart lib/features/patients/widgets/patient_form_sections.dart lib/features/patients/widgets/patient_medical_record_detail_dialog.dart
```

如果执行第二阶段，再运行：

```powershell
flutter analyze lib/screens/filtered_patients_screen.dart lib/screens/modern_dashboard_screen.dart lib/features/appointments/widgets/appointment_details_patient_card.dart lib/features/financial/widgets/financial_patient_info_section.dart lib/features/financial/widgets/financial_record_edit_dialog.dart lib/features/patients/widgets/patient_card.dart lib/features/patients/widgets/patient_detail_financial_widgets.dart lib/features/patients/widgets/patient_list_item.dart
```

最终全量验证：

```powershell
flutter analyze
```

## 文档同步要求

实施完成后更新：

- `docs/windows_app_theme_migration_progress_2026_07_02.md`
- `docs/windows_app_theme_migration_actual_status_2026_07_04.md`
- `docs/windows_app_theme_tokens_and_rules_2026_07_02.md`
- 根目录 `ROADMAP.md`

更新内容必须写明：

- 医学识别色已经从页面散落硬编码集中到 `MedicalSemanticColors`。
- 阶段 7 普通主题色仍保持完成。
- 如执行第二阶段，`DentalColors.femalePink` / `DentalColors.maleBlue` 已从业务组件迁出。
- 扫描结果和 `flutter analyze` 结果。

## 实施完成后的判断口径

第一阶段完成：

- `direct_colors: 0`
- 医学识别色不再散落写死。
- 阶段 7 质量进一步提升，但 `DentalColors` 仍有性别语义色。

第二阶段完成：

- `direct_colors: 0`
- `dental_colors: 0`
- 业务组件不再依赖 `DentalColors`。
- `MedicalSemanticColors` 成为医学识别色唯一入口。


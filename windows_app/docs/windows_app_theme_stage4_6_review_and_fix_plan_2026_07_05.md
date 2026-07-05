# Windows 端主题阶段 4-6 复核与修复方案

## 文档定位

本文件复核其它模型执行阶段 4 到阶段 6 后的真实状态，并记录 2026-07-05 启动报错的根因、已执行修复和后续可直接执行的实施方案。

关联文档：

- `windows_app_theme_unification_overview_2026_07_02.md`
- `windows_app_theme_migration_actual_status_2026_07_04.md`
- `windows_app_theme_migration_progress_2026_07_02.md`

## 当前结论

1. 登录后直接红屏的根因不在登录页，而在 `lib/screens/home_screen.dart`。
2. 报错原因是 `_HomeScreenState.initState()` 中构造导航项时读取了 `context.tokens` / `context.colors`，触发 Flutter inherited widget 生命周期限制。
3. 阶段 4、阶段 5、阶段 6 的核心验收项当前未发现未完成项：
   - 阶段 4 深层弹窗、表单、详情页已完成。
   - 阶段 5 图表、统计页、牙位和特殊视觉控件已完成。
   - 阶段 6 柔和灰 / 紫色 / 旧滤镜链路清理已完成。
   - 阶段 7 已完成：设置页旧 `AppTheme.*` 静态颜色入口、剩余普通直接颜色入口已统一并入 `context.tokens` / `context.colors`，剩余命中均归入允许例外清单。
4. 阶段 7 已按本文件修复方案完成：剩余普通 `Colors.xxx` / `Color(0x...)` 入口、设置页旧 `AppTheme.*` 静态颜色入口已全部并入统一主题系统，剩余命中均归入允许例外清单。
5. `windows_app_theme_migration_actual_status_2026_07_04.md` 中“后续执行顺序”已改为“历史执行记录”，阶段 4/5/6/7 均标记为已完成。

## 启动报错修复

### 报错

截图中的错误：

`dependOnInheritedWidgetOfExactType<_InheritedTheme>() or dependOnInheritedElement() was called before _HomeScreenState.initState() completed.`

### 根因文件

`lib/screens/home_screen.dart`

问题字段和方法：

- `_allNavItems`
- `initState()`
- `context.tokens.primaryAccent`
- `context.tokens.secondaryAccent`
- `context.colors.onSurfaceVariant`

### 已执行修复

1. 将 `_allNavItems` 从 `late final` / 字段固定初始化改为普通可重建列表：
   - 替换为：`List<NavigationItem> _allNavItems = [];`
2. 新增 `_rebuildNavigationItems()`：
   - 在方法内部读取 `final tokens = context.tokens;`
   - 使用 `tokens.primaryAccent` 替换仪表盘、用户管理主色。
   - 使用 `tokens.secondaryAccent` 替换患者管理、病历管理主色。
   - 使用 `tokens.info` 替换预约管理、采购管理主色。
   - 使用 `tokens.success` 替换财务管理主色。
   - 使用 `tokens.warning` 替换材料管理主色。
   - 使用 `context.colors.onSurfaceVariant` 替换系统设置主色。
3. `initState()` 只保留 `UserProvider` listener 注册，不再读取主题。
4. 在 `didChangeDependencies()` 中调用：
   - `_rebuildNavigationItems();`
   - `_checkUserRole();`

### 验证

已运行：

```powershell
flutter analyze lib/screens/home_screen.dart
```

结果：`No issues found!`

同类风险扫描：

- 扫描 `initState()` 方法体内的 `context.tokens`
- 扫描 `initState()` 方法体内的 `context.colors`
- 扫描 `initState()` 方法体内的 `Theme.of(context)`

结果：无其它命中。

## 阶段 4 到阶段 6 复核结果

### 阶段 4：弹窗、表单和详情页

状态：完成。

复核依据：

- 进度文档已记录阶段 4 完成。
- 阶段 4 代表文件已接入 `context.tokens` / `context.colors`。
- 未发现阶段 4 范围内因主题生命周期导致的启动错误。

重点文件：

- `lib/features/appointments/widgets/appointment_form_dialog.dart`
- `lib/features/appointments/widgets/appointment_patient_search_dialog.dart`
- `lib/features/financial/widgets/financial_record_edit_dialog.dart`
- `lib/features/financial/widgets/patient_selection_dialog.dart`
- `lib/features/patients/widgets/patient_medical_record_detail_dialog.dart`
- `lib/features/patients/widgets/single_material_editor.dart`
- `lib/features/materials/widgets/material_form_dialog.dart`
- `lib/features/materials/widgets/material_detail_dialog.dart`
- `lib/features/purchases/widgets/purchase_detail_dialog.dart`

当前不需要重新做阶段 4，只需要在阶段 7 中继续清理这些文件可能残留的直接颜色入口。

### 阶段 5：图表、统计页和特殊视觉控件

状态：完成。

复核依据：

- 进度文档已记录阶段 5 完成。
- `tokens.chartPalette` 已作为图表色板入口。
- 阶段 5 目标不是清零全仓所有直接颜色，而是迁移图表外围、统计卡、牙位普通视觉。

重点文件：

- `lib/features/patients/widgets/patient_statistics_dialog.dart`
- `lib/features/financial/widgets/financial_statistics_dialog.dart`
- `lib/features/purchases/widgets/purchase_statistics_dialog.dart`
- `lib/features/purchases/widgets/purchase_statistics_chart.dart`
- `lib/features/patients/widgets/interactable_pie_chart.dart`
- `lib/features/patients/widgets/patient_detail_dental_widgets.dart`
- `lib/features/appointments/widgets/teeth_condition_section.dart`
- `lib/features/appointments/widgets/teeth_condition_widget.dart`
- `lib/features/appointments/widgets/teeth_cross_widget.dart`

当前不需要重新做阶段 5。

### 阶段 6：旧系统和兜底滤镜清理

状态：完成。

复核命令：

```powershell
Get-ChildItem -Path windows_app\lib -Recurse -Filter *.dart |
  Select-String -Pattern "isPurpleTheme|AppTheme\.purple|purpleBackground|purpleColor|ExtendedThemeMode\.grey|greyTheme|AppThemeVisualFilter"
```

结果：0 命中。

`AppTheme.*` 当前命中结论：

- `lib/main.dart`：`AppTheme.standardTheme()`，标准主题构建入口，允许保留。
- `lib/features/patients/widgets/hoverable_patient_card.dart`：`AppTheme.smallBorderRadius`，布局常量，当前文档允许保留。
- `lib/features/users/widgets/avatar_upload_section.dart`：`AppTheme.dangerGradient`，语义渐变，当前文档允许保留。
- `lib/features/settings/widgets/backup_data_source_section.dart`、`lib/features/settings/widgets/data_source_configuration_section.dart`、`lib/features/settings/widgets/data_source_type_switch_section.dart`：阶段 6 复核时仍存在旧 `AppTheme.primaryColor` / `accentColor` / `secondaryColor` / `successColor` / `secondaryText`，已按阶段 7 修复方案统一替换为 `context.tokens` / `context.colors`。

当前不需要重新做阶段 6。

## 当前剩余问题

无。阶段 4 到阶段 7 已按本文件方案全部闭环，运行链路中不再存在旧主题颜色入口和普通 `DentalColors` 主题职责。

## 阶段 7 未完成清单与可直接执行修正方案

### 阶段 7 当前真实状态

状态：已完成。

判断依据：

- `DentalColors.` 在 `lib/screens` / `lib/features` 中剩余命中仅为 `DentalColors.femalePink` / `DentalColors.maleBlue`，属于患者性别业务语义色，已登记为允许例外。
- 旧柔和灰 / 紫色运行链路保持 0 命中，`ExtendedThemeMode.grey`、`greyTheme`、`AppThemeVisualFilter`、`ColorFiltered`、旧紫色入口没有命中。
- 普通页面背景、边框、弱文字、空状态图标、设置页旧 `AppTheme.*` 静态颜色已按本文件“阶段 7 必修文件清单”与“设置页旧 `AppTheme.*` 必修清单”全部替换为 `context.tokens` / `context.colors`。
- 直接 `Colors.xxx` / `Color(0x...)` 剩余命中均归入允许例外清单（透明色、医学识别色、图表色板、性别语义色、性别未指定中性色等）。

### 阶段 7 实施总规则

后续模型执行时按以下规则直接改，不要重新猜：

- 普通背景、页面浅底、卡片底色、边框、分割线、弱文字、弱图标必须走 `context.tokens` 或 `context.colors`。
- 状态语义色必须走 `context.tokens.success` / `warning` / `info` / `error` 及对应 `*Container`。
- 设置页旧 `AppTheme.primaryColor` / `accentColor` / `secondaryColor` / `successColor` / `secondaryText` 不允许继续作为业务组件颜色入口。
- `DentalColors.femalePink` / `DentalColors.maleBlue` 可以保留，但必须写入允许例外清单，因为它们是患者性别识别色，不是主题主色。
- `Colors.transparent` 可以保留。
- 媒体预览遮罩、图片自身颜色、医学固定识别色如确需保留，必须在阶段 7 例外清单说明原因；没有说明的直接颜色一律视为未完成。
- 替换运行时 token 后如果出现 `invalid_constant`，移除对应 `const`，不要加 `// ignore`。
- 如果文件没有 `theme_context_extensions.dart`，添加：
  `import 'package:dentist_app_windows/theme/theme_context_extensions.dart';`

### 阶段 7 必修文件清单

| 文件 | 未完成字段 | 当前问题 | 直接改法 |
| --- | --- | --- | --- |
| `lib/screens/users_screen.dart:145` | `backgroundColor: Colors.grey.shade50` | 页面背景仍是硬编码灰色 | 在 `build` 中使用 `context.tokens.scaffoldBackground`；如当前 token 无该字段，用 `context.colors.surface` 或项目现有页面背景 token，不要继续使用 `Colors.grey` |
| `lib/features/settings/widgets/settings_card.dart:38` | `color: Colors.blue.shade50` | 设置卡片图标背景绑定蓝色，换主题后不会变化 | 改为 `context.tokens.primaryContainer`；如果没有 `primaryContainer`，用 `context.tokens.primaryAccent.withValues(alpha: 0.1)` |
| `lib/features/financial/widgets/financial_detail_table_header.dart:16` | `Border.all(color: Colors.grey.shade300)` | 表格边框仍是硬编码灰色 | 改为 `Border.all(color: context.tokens.border)`；已有 `context` 参数可直接使用 |
| `lib/features/settings/widgets/auto_backup_settings.dart:47` | `color: Colors.grey.shade600` | 次级说明文字未接入主题 | 改为 `color: context.colors.onSurfaceVariant` 或 `context.tokens.textMuted` |
| `lib/features/appointments/widgets/appointment_list.dart:36` | `Icon(... color: Colors.grey[300])` | 空状态弱图标未接入主题 | 改为 `color: context.tokens.iconMuted`；若图标所在 widget 当前 `const`，移除 `const` |
| `lib/features/financial/widgets/financial_empty_state.dart:28` | `color: Colors.grey[400]` | 空状态弱图标未接入主题 | 改为 `color: context.tokens.iconMuted` |
| `lib/features/financial/widgets/financial_stat_item.dart:30` | `copyWith(color: Colors.grey[600])` | 统计项标签弱文字未接入主题 | 改为 `copyWith(color: context.colors.onSurfaceVariant)` 或 `context.tokens.textMuted` |
| `lib/features/purchases/widgets/purchase_stat_item.dart:28` | `color: Colors.grey[600]` | 统计项标签弱文字未接入主题 | 改为 `color: context.colors.onSurfaceVariant` 或 `context.tokens.textMuted` |
| `lib/features/materials/widgets/material_detail_dialog.dart:192` | `color: Colors.purple.shade700` | “材料类型”显示色仍是硬编码紫色，且没有登记为业务语义色 | 优先改为 `context.tokens.secondaryAccent`；如果产品上决定材料类型必须固定紫色，则登记为“材料类型语义色”例外，否则不能保留 |
| `lib/features/materials/widgets/material_form_field.dart:50` | `color: Colors.red` | 必填星号仍是硬编码红色 | 改为 `color: context.tokens.error`；这是错误/必填语义，不应继续用 `Colors.red` |

### 设置页旧 `AppTheme.*` 必修清单

这些文件已混用了 `context.tokens` 和旧 `AppTheme.*`，后续模型应在同一文件内统一为 token，不要保留双轨入口。

| 文件 | 未完成字段 | 直接改法 |
| --- | --- | --- |
| `lib/features/settings/widgets/backup_data_source_section.dart:40` | `AppTheme.accentColor` 作为 section header 色 | 改为 `context.tokens.secondaryAccent`，并把 `_buildSectionHeader` 的颜色从调用侧传入 token |
| `lib/features/settings/widgets/backup_data_source_section.dart:109` | `AppTheme.accentColor.withValues(alpha: 0.1)` | 改为 `context.tokens.secondaryAccent.withValues(alpha: 0.1)`，或项目已有 `secondaryContainer` 时用 `context.tokens.secondaryContainer` |
| `lib/features/settings/widgets/backup_data_source_section.dart:114` | `AppTheme.accentColor` 图标色 | 改为 `context.tokens.secondaryAccent` |
| `lib/features/settings/widgets/backup_data_source_section.dart:133` | `AppTheme.primaryColor` 按钮背景 | 改为 `context.tokens.primaryAccent` |
| `lib/features/settings/widgets/backup_data_source_section.dart:160` | `AppTheme.primaryColor` 按钮背景 | 改为 `context.tokens.primaryAccent` |
| `lib/features/settings/widgets/backup_data_source_section.dart:212` | `AppTheme.accentColor.withValues(alpha: 0.05)` | 改为 `context.tokens.secondaryAccent.withValues(alpha: 0.05)` |
| `lib/features/settings/widgets/backup_data_source_section.dart:215` | `AppTheme.accentColor.withValues(alpha: 0.2)` | 改为 `context.tokens.secondaryAccent.withValues(alpha: 0.2)` |
| `lib/features/settings/widgets/backup_data_source_section.dart:238` | `AppTheme.accentColor` 图标色 | 改为 `context.tokens.secondaryAccent` |
| `lib/features/settings/widgets/backup_data_source_section.dart:246` | `AppTheme.accentColor` 文本色 | 改为 `context.tokens.secondaryAccent` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:60` | `AppTheme.primaryColor` section header 色 | 改为 `context.tokens.primaryAccent` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:227` | `AppTheme.successColor` 状态文字 | 改为 `context.tokens.success` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:238` | `AppTheme.successColor.withValues(alpha: 0.1)` | 改为 `context.tokens.successContainer`，或 `context.tokens.success.withValues(alpha: 0.1)` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:242` | `AppTheme.successColor.withValues(alpha: 0.3)` | 改为 `context.tokens.success.withValues(alpha: 0.3)` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:253` | `AppTheme.successColor` 图标色 | 改为 `context.tokens.success` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:259` | `AppTheme.successColor` 文本色 | 改为 `context.tokens.success` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:276` | `AppTheme.successColor.withValues(alpha: 0.05)` | 改为 `context.tokens.successContainer.withValues(alpha: 0.5)`，或 `context.tokens.success.withValues(alpha: 0.05)` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:280` | `AppTheme.successColor.withValues(alpha: 0.2)` | 改为 `context.tokens.success.withValues(alpha: 0.2)` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:293` | `AppTheme.successColor` 文本色 | 改为 `context.tokens.success` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:383` | `AppTheme.primaryColor` 按钮背景 | 改为 `context.tokens.primaryAccent` |
| `lib/features/settings/widgets/data_source_configuration_section.dart:410` | `AppTheme.primaryColor` 按钮背景 | 改为 `context.tokens.primaryAccent` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:43` | `AppTheme.secondaryColor` section header 色 | 改为 `context.tokens.secondaryAccent` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:122` | `AppTheme.secondaryColor.withValues(alpha: 0.1)` | 改为 `context.tokens.secondaryAccent.withValues(alpha: 0.1)`，或 `secondaryContainer` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:127` | `AppTheme.secondaryColor` 图标色 | 改为 `context.tokens.secondaryAccent` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:146` | `AppTheme.primaryColor` 按钮背景 | 改为 `context.tokens.primaryAccent` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:171` | `AppTheme.primaryColor` 按钮背景 | 改为 `context.tokens.primaryAccent` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:194` | `AppTheme.secondaryColor.withValues(alpha: 0.1)` | 改为 `context.tokens.secondaryAccent.withValues(alpha: 0.1)`，或 `secondaryContainer` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:199` | `AppTheme.secondaryColor` 图标色 | 改为 `context.tokens.secondaryAccent` |
| `lib/features/settings/widgets/data_source_type_switch_section.dart:476` | `AppTheme.secondaryText` 未选中控件色 | 改为 `context.colors.onSurfaceVariant` 或 `context.tokens.textMuted` |

### `DentalColors.` 当前允许范围

阶段 7 后允许保留的 `DentalColors.` 只应包含：

- `DentalColors.femalePink`
- `DentalColors.maleBlue`

当前已确认这些命中集中在：

- `lib/screens/filtered_patients_screen.dart`
- `lib/screens/modern_dashboard_screen.dart`
- `lib/features/appointments/widgets/appointment_details_patient_card.dart`
- `lib/features/financial/widgets/financial_patient_info_section.dart`
- `lib/features/financial/widgets/financial_record_edit_dialog.dart`
- `lib/features/patients/widgets/patient_card.dart`
- `lib/features/patients/widgets/patient_detail_financial_widgets.dart`
- `lib/features/patients/widgets/patient_list_item.dart`

处理要求：

- 上述文件里的 `DentalColors.femalePink` / `DentalColors.maleBlue` 可以保留。
- 如果同一文件还存在 `DentalColors.info` / `success` / `warning` / `error` / `primary` / `secondary` / `background` 等普通主题职责，必须替换为 `context.tokens`。
- 阶段 7 完成后，在进度文档中明确登记“性别识别色为允许例外”，不能只写“DentalColors 已清理”。

### 阶段 7 执行顺序

1. 先处理上方“阶段 7 必修文件清单”的普通直接颜色。
2. 再处理“设置页旧 `AppTheme.*` 必修清单”，把设置页颜色入口统一到 `context.tokens`。
3. 再运行扫描脚本确认剩余项：

```powershell
python scripts\theme_migration_assistant.py --scan --top 30
```

4. 对剩余 `Colors.` / `Color(0x...)` 逐条分类：
   - 属于透明色、媒体遮罩、图片本体、医学固定识别色：写入允许例外。
   - 属于背景、边框、文字、图标、按钮、状态：继续替换。
5. 更新：
   - `docs/windows_app_theme_migration_progress_2026_07_02.md`
   - `docs/windows_app_theme_migration_actual_status_2026_07_04.md`
   - 根目录 `ROADMAP.md`

### 阶段 7 完成验收标准

完成阶段 7 必须同时满足：

- `DentalColors.` 在 `lib/screens` / `lib/features` 中只剩 `femalePink` / `maleBlue`，或其它已登记业务语义例外。
- `AppTheme.primaryColor` / `AppTheme.accentColor` / `AppTheme.secondaryColor` / `AppTheme.successColor` / `AppTheme.secondaryText` 不再出现在业务组件中。
- `Colors.grey`、`Colors.blue`、`Colors.purple`、`Colors.red` 等普通 UI 颜色不再用于页面背景、边框、弱文字、图标、按钮、普通状态。
- 旧柔和灰 / 紫色运行链路继续保持 0 命中。
- 扫描脚本剩余项全部可解释、可登记，不存在“看起来应该没问题”的未分类颜色。
- `flutter analyze` 通过。

当前扫描统计（阶段 7 完成后）：

- `DentalColors.`：26 处，均为 `DentalColors.femalePink` / `maleBlue` 性别语义例外。
- `Colors.` / `Color(0x...)`：19 处，均归入允许例外清单（透明色、医学识别色、图表色板、性别语义色、性别未指定中性色等）。
- 柔和灰 / 紫色旧链路：0 处。
- `AppTheme.`：3 处，均为允许保留项：`AppTheme.standardTheme()`（标准主题构建入口）、`AppTheme.smallBorderRadius`（布局常量）、`AppTheme.dangerGradient`（语义渐变）。

`DentalColors.` 高密度文件：

- `lib/features/medical_records/widgets/medical_record_form_dialog.dart`
- `lib/features/medical_records/widgets/allergy_selection_widget.dart`
- `lib/features/patients/widgets/patient_detail_overview_card.dart`
- `lib/features/patients/widgets/patient_card.dart`
- `lib/features/appointments/widgets/appointment_card.dart`
- `lib/features/medical_records/widgets/disease_type_edit_dialog.dart`
- `lib/screens/modern_dashboard_screen.dart`
- `lib/screens/appointment_details_screen.dart`
- `lib/features/medical_records/widgets/medical_template_edit_dialog.dart`
- `lib/features/patients/widgets/patient_app_bar_actions.dart`
- `lib/features/patients/widgets/patient_detail_medical_record_widgets.dart`

直接颜色高密度文件：

- `lib/features/settings/widgets/database_check_widgets.dart`
- `lib/features/settings/widgets/data_source_type_switch_section.dart`
- `lib/features/settings/widgets/data_source_configuration_section.dart`
- `lib/features/settings/widgets/backup_data_source_section.dart`
- `lib/features/medical_records/widgets/medical_record_form_dialog.dart`
- `lib/features/purchases/widgets/purchase_form_item_list_section.dart`
- `lib/features/patients/widgets/patient_detail_overview_card.dart`
- `lib/features/medical_records/widgets/disease_type_edit_dialog.dart`
- `lib/features/patients/widgets/patient_form_dental_section.dart`
- `lib/screens/modern_dashboard_screen.dart`
- `lib/features/patients/widgets/patient_detail_financial_widgets.dart`
- `lib/features/patients/widgets/patient_card.dart`
- `lib/features/financial/widgets/financial_table_header.dart`

## 后续实施方案

### 步骤 1：先修正阶段文档状态描述

文件：

- `docs/windows_app_theme_migration_actual_status_2026_07_04.md`

修改（已完成）：

1. 将“后续执行顺序”中的阶段 5、阶段 6 执行提示改为“历史执行记录”。
2. 删除或改写“阶段 7：只在阶段 4 到阶段 6 完成后启动”这类旧描述。
3. 当前状态统一写成：
   - 阶段 4：已完成。
   - 阶段 5：已完成。
   - 阶段 6：已完成。
   - 阶段 7：已完成。

验证：

```powershell
Select-String -Path docs\windows_app_theme_migration_actual_status_2026_07_04.md -Pattern "阶段 6 未完成|阶段 7 未开始|只在阶段 4 到阶段 6 完成后启动"
```

期望：无命中。

### 步骤 2：处理医疗记录组件的 `DentalColors`

文件：

- `lib/features/medical_records/widgets/medical_record_form_dialog.dart`
- `lib/features/medical_records/widgets/allergy_selection_widget.dart`
- `lib/features/medical_records/widgets/disease_type_edit_dialog.dart`
- `lib/features/medical_records/widgets/medical_template_edit_dialog.dart`
- `lib/features/medical_records/widgets/medical_record_form_input_field.dart`
- `lib/features/medical_records/widgets/template_selection_widget.dart`

替换规则：

- `DentalColors.info` -> `context.tokens.info`
- `DentalColors.info.withValues(alpha: 0.1)` -> `context.tokens.infoContainer`
- `DentalColors.info.withValues(alpha: 0.3)` -> `context.tokens.info.withValues(alpha: 0.3)`
- `DentalColors.warning` -> `context.tokens.warning`
- `DentalColors.warning.withValues(alpha: 0.1)` -> `context.tokens.warningContainer`
- `DentalColors.warning.withValues(alpha: 0.3)` -> `context.tokens.warning.withValues(alpha: 0.3)`
- `DentalColors.success` -> `context.tokens.success`
- `DentalColors.success.withValues(alpha: 0.1)` -> `context.tokens.successContainer`
- `DentalColors.success.withValues(alpha: 0.3)` -> `context.tokens.success.withValues(alpha: 0.3)`
- `DentalColors.error` -> `context.tokens.error`
- `DentalColors.error.withValues(alpha: 0.05)` -> `context.tokens.errorContainer.withValues(alpha: 0.5)`
- `DentalColors.error.withValues(alpha: 0.1)` -> `context.tokens.errorContainer`
- `DentalColors.error.withValues(alpha: 0.2)` -> `context.tokens.error.withValues(alpha: 0.2)`
- `DentalColors.error.withValues(alpha: 0.3)` -> `context.tokens.error.withValues(alpha: 0.3)`

文件内前置要求：

- 确认已有 `theme_context_extensions.dart` import。
- 如果没有，添加：
  `import 'package:dentist_app_windows/theme/theme_context_extensions.dart';`
- 在 `build(BuildContext context)` 顶部添加：
  `final tokens = context.tokens;`
  但如果替换表达式在嵌套 builder 中，直接使用 `context.tokens`，避免外层 `tokens` 作用域不可见。

验证：

```powershell
flutter analyze lib/features/medical_records/widgets/medical_record_form_dialog.dart lib/features/medical_records/widgets/allergy_selection_widget.dart lib/features/medical_records/widgets/disease_type_edit_dialog.dart lib/features/medical_records/widgets/medical_template_edit_dialog.dart lib/features/medical_records/widgets/medical_record_form_input_field.dart lib/features/medical_records/widgets/template_selection_widget.dart
```

### 步骤 3：处理患者详情和患者卡片的 `DentalColors`（已完成）

文件：

- `lib/features/patients/widgets/patient_detail_overview_card.dart`
- `lib/features/patients/widgets/patient_card.dart`
- `lib/features/patients/widgets/patient_app_bar_actions.dart`
- `lib/features/patients/widgets/patient_detail_medical_record_widgets.dart`
- `lib/features/patients/widgets/patient_search_bar.dart`

替换规则：

- `DentalColors.info` -> `context.tokens.info`
- `DentalColors.warning` -> `context.tokens.warning`
- `DentalColors.success` -> `context.tokens.success`
- `DentalColors.error` -> `context.tokens.error`
- `DentalColors.info.withValues(alpha: 0.1)` -> `context.tokens.infoContainer`
- `DentalColors.warning.withValues(alpha: 0.1)` -> `context.tokens.warningContainer`
- `DentalColors.success.withValues(alpha: 0.1)` -> `context.tokens.successContainer`
- `DentalColors.error.withValues(alpha: 0.1)` -> `context.tokens.errorContainer`
- `DentalColors.info.withValues(alpha: 0.2)` -> `context.tokens.info.withValues(alpha: 0.2)`
- `DentalColors.warning.withValues(alpha: 0.2)` -> `context.tokens.warning.withValues(alpha: 0.2)`
- `DentalColors.success.withValues(alpha: 0.2)` -> `context.tokens.success.withValues(alpha: 0.2)`
- `DentalColors.error.withValues(alpha: 0.2)` -> `context.tokens.error.withValues(alpha: 0.2)`
- `DentalColors.info.withValues(alpha: 0.3)` -> `context.tokens.info.withValues(alpha: 0.3)`
- `DentalColors.warning.withValues(alpha: 0.3)` -> `context.tokens.warning.withValues(alpha: 0.3)`
- `DentalColors.success.withValues(alpha: 0.3)` -> `context.tokens.success.withValues(alpha: 0.3)`
- `DentalColors.error.withValues(alpha: 0.3)` -> `context.tokens.error.withValues(alpha: 0.3)`

允许暂时保留：

- `DentalColors.femalePink`
- `DentalColors.maleBlue`

说明：性别识别色属于业务语义色；最终可以登记到允许例外清单，不应和普通主题色一起机械替换。

验证：

```powershell
flutter analyze lib/features/patients/widgets/patient_detail_overview_card.dart lib/features/patients/widgets/patient_card.dart lib/features/patients/widgets/patient_app_bar_actions.dart lib/features/patients/widgets/patient_detail_medical_record_widgets.dart lib/features/patients/widgets/patient_search_bar.dart
```

### 步骤 4：处理预约详情和预约卡片的 `DentalColors`

文件：

- `lib/screens/appointment_details_screen.dart`
- `lib/screens/appointments_screen.dart`
- `lib/features/appointments/widgets/appointment_card.dart`
- `lib/features/appointments/widgets/appointment_details_patient_card.dart`
- `lib/features/appointments/widgets/appointment_filter_bar.dart`

替换规则：

- `DentalColors.info` -> `context.tokens.info`
- `DentalColors.warning` -> `context.tokens.warning`
- `DentalColors.success` -> `context.tokens.success`
- `DentalColors.error` -> `context.tokens.error`
- `DentalColors.info.withValues(alpha: 0.1)` -> `context.tokens.infoContainer`
- `DentalColors.warning.withValues(alpha: 0.1)` -> `context.tokens.warningContainer`
- `DentalColors.success.withValues(alpha: 0.1)` -> `context.tokens.successContainer`
- `DentalColors.error.withValues(alpha: 0.1)` -> `context.tokens.errorContainer`
- `DentalColors.info.withValues(alpha: 0.3)` -> `context.tokens.info.withValues(alpha: 0.3)`
- `DentalColors.warning.withValues(alpha: 0.3)` -> `context.tokens.warning.withValues(alpha: 0.3)`
- `DentalColors.success.withValues(alpha: 0.3)` -> `context.tokens.success.withValues(alpha: 0.3)`
- `DentalColors.error.withValues(alpha: 0.3)` -> `context.tokens.error.withValues(alpha: 0.3)`

注意：

- 如果状态颜色是预约状态语义色，可以继续使用 `tokens.success/warning/info/error`，不要回退到 `DentalColors`。
- 如果替换后出现 `invalid_constant`，移除包住运行时 token 的 `const`，不要加 `// ignore`。

验证：

```powershell
flutter analyze lib/screens/appointment_details_screen.dart lib/screens/appointments_screen.dart lib/features/appointments/widgets/appointment_card.dart lib/features/appointments/widgets/appointment_details_patient_card.dart lib/features/appointments/widgets/appointment_filter_bar.dart
```

### 步骤 5：处理直接颜色高密度设置页组件

文件：

- `lib/features/settings/widgets/database_check_widgets.dart`
- `lib/features/settings/widgets/data_source_type_switch_section.dart`
- `lib/features/settings/widgets/data_source_configuration_section.dart`
- `lib/features/settings/widgets/backup_data_source_section.dart`

替换规则：

- `Colors.white` -> `context.tokens.cardBackground`
- `Colors.grey.shade50` -> `context.tokens.mutedBackground`
- `Colors.grey.shade100` -> `context.tokens.inputBackground`
- `Colors.grey.shade200` -> `context.tokens.border`
- `Colors.grey.shade300` -> `context.tokens.divider`
- `Colors.grey.shade400` -> `context.tokens.iconMuted`
- `Colors.grey.shade500` -> `context.tokens.textMuted`
- `Colors.grey.shade600` -> `context.colors.onSurfaceVariant`
- `Colors.grey.shade700` -> `context.colors.onSurface`
- `Colors.black.withValues(alpha: 0.05)` -> `context.tokens.shadow`
- `Colors.black.withValues(alpha: 0.08)` -> `context.tokens.shadow.withValues(alpha: 0.08)`
- `Colors.blue` / `Colors.blue.shade*` used for normal primary UI -> `context.tokens.primaryAccent`
- `Colors.green` / `Colors.green.shade*` used for success state -> `context.tokens.success` or `context.tokens.successContainer`
- `Colors.orange` / `Colors.orange.shade*` used for warning state -> `context.tokens.warning` or `context.tokens.warningContainer`
- `Colors.red` / `Colors.red.shade*` used for error state -> `context.tokens.error` or `context.tokens.errorContainer`

保留：

- `Colors.transparent`

验证：

```powershell
flutter analyze lib/features/settings/widgets/database_check_widgets.dart lib/features/settings/widgets/data_source_type_switch_section.dart lib/features/settings/widgets/data_source_configuration_section.dart lib/features/settings/widgets/backup_data_source_section.dart
```

### 步骤 6：处理直接颜色高密度业务组件（已完成）

文件：

- `lib/features/purchases/widgets/purchase_form_item_list_section.dart`
- `lib/features/patients/widgets/patient_form_dental_section.dart`
- `lib/features/patients/widgets/patient_detail_financial_widgets.dart`
- `lib/features/financial/widgets/financial_table_header.dart`
- `lib/features/patients/widgets/material_image_detail_dialog.dart`
- `lib/features/patients/widgets/material_image_preview.dart`
- `lib/features/patients/widgets/material_detail_card.dart`
- `lib/features/appointments/widgets/appointment_time_picker.dart`

替换规则：

- 普通卡片背景：`Colors.white` / `Color(0xFFFFFFFF)` -> `context.tokens.cardBackground`
- 页面或浅底：`Color(0xFFF8FAFC)` / `Colors.grey.shade50` -> `context.tokens.mutedBackground`
- 输入框底色：`Color(0xFFF5F7FA)` / `Colors.grey.shade100` -> `context.tokens.inputBackground`
- 普通边框：`Color(0xFFE3E8EE)` / `Colors.grey.shade200` -> `context.tokens.border`
- 分割线：`Color(0xFFEEEEEE)` / `Colors.grey.shade300` -> `context.tokens.divider`
- 普通弱文字：`Colors.grey.shade500` / `Color(0xFF8892A3)` -> `context.tokens.textMuted`
- 普通图标弱色：`Colors.grey.shade400` / `Color(0xFF667085)` -> `context.tokens.iconMuted`
- 普通主按钮、选中态、焦点态：`Colors.blue` / `Color(0xFF2E7DB8)` -> `context.tokens.primaryAccent`
- 普通次强调：`Color(0xFF4CAF50)` only if used as brand secondary -> `context.tokens.secondaryAccent`
- 成功状态：`Colors.green` / `Color(0xFF30D158)` -> `context.tokens.success`
- 警告状态：`Colors.orange` / `Color(0xFFFF9F0A)` -> `context.tokens.warning`
- 错误状态：`Colors.red` / `Color(0xFFFF375F)` -> `context.tokens.error`
- 阴影：`Colors.black.withValues(alpha: ...)` -> `context.tokens.shadow.withValues(alpha: same value)`，如果 alpha 为 `0.05` 可直接用 `context.tokens.shadow`

保留：

- `Colors.transparent`
- 图片预览遮罩中确实用于黑色遮罩的 `Colors.black.withValues(alpha: >= 0.5)` 可暂时保留并登记为媒体遮罩例外，或改为 `context.tokens.overlayScrim`。

验证：

```powershell
flutter analyze lib/features/purchases/widgets/purchase_form_item_list_section.dart lib/features/patients/widgets/patient_form_dental_section.dart lib/features/patients/widgets/patient_detail_financial_widgets.dart lib/features/financial/widgets/financial_table_header.dart lib/features/patients/widgets/material_image_detail_dialog.dart lib/features/patients/widgets/material_image_preview.dart lib/features/patients/widgets/material_detail_card.dart lib/features/appointments/widgets/appointment_time_picker.dart
```

### 步骤 7：建立允许例外清单（已完成）

文件：

- `docs/windows_app_theme_migration_progress_2026_07_02.md`
- `docs/windows_app_theme_tokens_and_rules_2026_07_02.md`

需要登记的允许例外：

- `DentalColors.femalePink`
- `DentalColors.maleBlue`
- 牙位、疾病、过敏等医学识别色，如后续确认仍需固定语义色。
- 图表系列色必须优先使用 `context.tokens.chartPalette`；不应继续散落在业务页面。
- `Colors.transparent`
- 图片 / 头像 / 上传素材本身的颜色。
- 媒体预览遮罩如无法使用 `tokens.overlayScrim`，必须登记原因。

### 步骤 8：最终验证（已完成）

阶段 7 每批完成后已运行对应文件的 targeted analyze。

整批完成后运行：

```powershell
flutter analyze
```

结果：`No issues found!`

搜索复核：

```powershell
Get-ChildItem -Path lib\screens,lib\features -Recurse -Filter *.dart |
  Select-String -Pattern "DentalColors\."

Get-ChildItem -Path lib\screens,lib\features -Recurse -Filter *.dart |
  Select-String -Pattern "Colors\.|Color\(0x"

Get-ChildItem -Path lib -Recurse -Filter *.dart |
  Select-String -Pattern "isPurpleTheme|AppTheme\.purple|purpleBackground|purpleColor|ExtendedThemeMode\.grey|greyTheme|AppThemeVisualFilter"
```

复核结果：

- `DentalColors.` 剩余 26 处，全部能归入 `femalePink` / `maleBlue` 性别语义例外。
- 直接颜色剩余 19 处，全部能归入透明色、医学识别色、图表色板、性别语义色、性别未指定中性色等允许例外。
- 旧柔和灰 / 紫色链路继续保持 0 命中。
- `flutter analyze` 通过。

验收结论：阶段 7 已完成，`windows_app` 统一主题治理闭环。

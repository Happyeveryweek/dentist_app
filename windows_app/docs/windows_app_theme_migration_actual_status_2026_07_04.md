# Windows 端主题迁移实际状态复核

## 文档定位

本文件只保留 2026-07-04 这次复核的最终有效结论，不再保留当天早期草稿、重复阶段判断和已失效的临时统计说明。

入口文档：[统一主题颜色风格改进方案总览](windows_app_theme_unification_overview_2026_07_02.md)

进度文档：[迁移进度](windows_app_theme_migration_progress_2026_07_02.md)

## 当前结论

- 阶段 1：完成
- 阶段 2：完成
- 阶段 3：完成
- 阶段 4：完成
- 阶段 5：已完成
- 阶段 6：已完成
- 阶段 7：已完成

`windows_app` 统一主题治理已全部闭环：阶段 1 到阶段 7 普通主题色迁移均已完成并通过静态检查，运行链路中不再存在旧主题颜色入口和普通 `DentalColors` 主题职责。

医学识别色集中治理已按 `windows_app/docs/windows_app_medical_semantic_colors_plan_2026_07_05.md` 完成：

- 新增 `lib/theme/medical_semantic_colors.dart` 作为医学/患者识别色唯一入口。
- 第一阶段 6 个文件 19 处直接医学识别色（`Colors.blue` / `Colors.green` / `Colors.orange` / `Colors.grey` / `Color(0xFF009688)`）已全部迁入 `MedicalSemanticColors`。
- 第二阶段 9 个文件中 `DentalColors.femalePink` / `DentalColors.maleBlue` 患者性别识别色已全部迁入 `MedicalSemanticColors`，相关文件不再依赖 `DentalColors`。
- `theme_migration_assistant.py --scan --top 40` 复核：`direct_colors: 0`、`dental_colors: 0`、`purple: 0`，`app_theme: 3`（仅 `AppTheme.standardTheme()` / `smallBorderRadius` / `dangerGradient` 等允许项）。
- 全量 `flutter analyze` 0 issue。

## 本次复核后的有效状态

### 阶段 1：主题基础设施

已完成：

- `AppThemeTokens`、`theme_context_extensions.dart`、`AppTheme.standardTheme()` 已落地。
- `main.dart` 当前运行入口只保留 `AppTheme.standardTheme()`。
- 柔和灰主题入口、`AppThemeVisualFilter` 和灰主题运行链路已退出。
- 只读复核 `main.dart`、`app_theme.dart`、阶段 1 到阶段 3 范围页面与公共组件后，旧灰主题运行分支未再命中。

说明：

- `AppTheme.standardTheme()` 仍是合法保留项，它不是旧颜色入口，而是标准主题构建入口。

### 阶段 2：公共组件主题化

已完成：

- 搜索框、日期选择器、Toast、确认/错误弹窗、分页组件、hoverable card、用户基础组件和若干高频按钮入口已统一收回到 `context.tokens` / `context.colors`。
- 本轮补充收口后，阶段 2 范围内不再保留 `isPurpleTheme` 活跃判断和旧 `AppTheme.*` 普通主题入口。

### 阶段 3：主框架和高频页面

已完成：

- 首页、仪表盘、患者页壳层、预约、财务、采购、材料、病历、设置、登录、应用信息、筛选患者、数据源等高频页面壳层与高频入口已完成标准主题迁移。
- `materials_screen.dart`、`login_screen.dart`、`app_info_screen.dart` 的最后一批残留已在 2026-07-04 收口。
- `compact_material_action_button.dart` 已同步放宽为普通 `Color` 入参，避免组件类型反向阻塞页面 token 化。

复核结果：

- 只读搜索阶段 1 到阶段 3 范围页面与公共组件中的 `AppTheme.*`、`isPurpleTheme`、`ExtendedThemeMode.grey`、`greyTheme`、`AppThemeVisualFilter`
- 结果：仅剩 `AppTheme.standardTheme()` 作为标准主题构建入口，没有旧主题颜色入口和灰主题运行分支残留

### 阶段 4：弹窗、表单、详情页

已完成：

- 第一批（财务编辑/新增/患者选择弹窗）：`financial_record_edit_dialog.dart`、`financial_form_dialog.dart`、`edit_financial_item_dialog.dart`、`patient_selection_dialog.dart` 已统一接入 `context.tokens` / `context.colors`，仅保留性别色等业务语义硬编码。
- 第二批（患者表单、病历详情、患者材料编辑）：`patient_form_shell.dart`、`patient_form_fields.dart`、`patient_form_sections.dart`、`patient_medical_record_detail_dialog.dart`、`single_material_editor.dart` 已完成迁移，仅保留 `dentalTeal` 等医学语义色。
- 第三批（预约表单深层区块、材料详情/编辑、采购详情）：`appointment_patient_selection_section.dart`、`appointment_cost_status_section.dart`、`appointment_notes_section.dart`、`material_form_dialog.dart`、`material_detail_dialog.dart`、`purchase_detail_dialog.dart` 已完成迁移；补充完成 `appointment_date_time_section.dart` 中剩余珊瑚色硬编码替换为 `tokens.warning`，以及 `appointment_treatment_section.dart` 的全面主题化（背景、边框、输入框、下拉框、标签、芯片色全部接入 tokens）。

复核结果：

- 阶段 4 范围内普通背景、边框、输入框、标签、说明块、页脚按钮已全部从 `context.tokens` / `context.colors` 读取。
- 仅保留必要业务语义色（如性别色、医学识别色、材料类型色），不再保留普通主题色硬编码。
- 针对性 `flutter analyze` 通过。

## 本次收尾摘要

2026-07-04 当天的后续收尾，最终有效信息压缩如下：

1. 第二轮到第四轮主要完成了阶段 2 / 阶段 3 的分页、hover card、用户组件和高频页面入口收口。
2. 第五轮完成了 `home_screen.dart`、`home_widgets.dart`、`unified_search_field.dart`、`reusable_date_range_picker.dart`、`purchase_records_screen.dart`、`financial_management_screen.dart`、`data_source_screen.dart` 的进一步清理。
3. 第六轮完成了 `materials_screen.dart`、`login_screen.dart`、`app_info_screen.dart` 和 `compact_material_action_button.dart` 的最后收口，并据此把阶段 1 到阶段 3 更新为完成。
4. 第七轮完成了阶段 4 剩余迁移：补充 `appointment_date_time_section.dart` 硬编码收口，完成 `appointment_treatment_section.dart` 全面主题化，并更新阶段 4 状态为完成。
5. 第八轮完成了阶段 5 迁移收尾：患者/财务/采购统计弹窗、采购统计图表、可交互饼图、牙位相关组件已统一接入 `context.tokens` / `context.colors`，本批 `flutter analyze` 0 issue。复核发现进度文档此前把阶段 6 标为"已完成"、阶段 7 标为"进行中"与代码真实状态不符，已同步修正进度文档、总览文档和 `ROADMAP.md`；本文件后续经第九轮、第十轮已更新为阶段 6 完成、阶段 7 进行中。
6. 第九轮（本次）完成了阶段 6 清理：`AppTheme.purple*` 常量、`isPurpleTheme` 分支和普通 `AppTheme.*` 页面级入口已全部清理；settings/patients/users/appointments/purchases 等 35+ 个文件已把 `AppTheme.primaryColor` / `secondaryColor` / `primaryGradient` / `successColor` / `errorColor` / `warningColor` / `infoColor` / `primaryText` / `secondaryText` / `dividerColor` / `cardBackground` / `cardShadow` / `accentColor` / `lightText` / `darkPrimaryText` 等入口统一收回到 `context.tokens` / `context.colors`。全量 `flutter analyze` 0 error、0 warning，仅剩 14 个 info 级别 `prefer_const` 提示（均为预先存在）。运行链路中仅保留 `AppTheme.standardTheme()`（标准主题构建入口）、`AppTheme.smallBorderRadius`（布局常量）和 `AppTheme.dangerGradient`（语义渐变）。
7. 第十轮执行了阶段 7：按修复方案完成 `actual_status` 文档状态修正；医疗记录组件（`medical_record_form_dialog.dart`、`allergy_selection_widget.dart`、`disease_type_edit_dialog.dart`、`medical_template_edit_dialog.dart`、`medical_record_form_input_field.dart`、`template_selection_widget.dart`）、患者详情/卡片组件、预约详情/卡片组件的 `DentalColors` 状态色已统一接入 `context.tokens`；设置页组件（`database_check_widgets.dart`、`data_source_type_switch_section.dart`、`data_source_configuration_section.dart`、`backup_data_source_section.dart`）和业务组件（`purchase_form_item_list_section.dart`、`patient_form_dental_section.dart`、`patient_detail_financial_widgets.dart`、`financial_table_header.dart`、`material_image_detail_dialog.dart`、`material_image_preview.dart`、`material_detail_card.dart`、`appointment_time_picker.dart`）的直接颜色入口已接入 `context.tokens` / `context.colors`；`modern_dashboard_screen.dart`、`users_screen.dart`、`purchase_records_screen.dart`、`dashboard_status_helper.dart` 的剩余 `DentalColors` 也已收口。当前 `lib/screens` / `lib.features` 中 `DentalColors` 仅剩 `femalePink` / `maleBlue` 性别语义例外，直接颜色命中从 1247 降至 787，全量 `flutter analyze` 0 error / 0 warning，针对性 analyze 全部 `No issues found!`。

## 已完成验证

- `flutter analyze`（全量）：0 error、0 warning，仅剩 14 个 info 级别 `prefer_const` 提示（均为预先存在，非本次迁移引入）。
- `flutter analyze lib/features/patients/widgets/patient_statistics_dialog.dart lib/features/financial/widgets/financial_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_chart.dart lib/features/patients/widgets/interactable_pie_chart.dart lib/features/patients/widgets/patient_detail_dental_widgets.dart lib/features/appointments/widgets/teeth_condition_section.dart lib/features/appointments/widgets/teeth_condition_widget.dart lib/features/appointments/widgets/teeth_cross_widget.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/screens/settings_screen.dart lib/screens/medical_management_screen.dart lib/screens/filtered_patients_screen.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/features/materials/widgets/material_pagination_button.dart lib/features/users/widgets/permission_preview_dialog.dart lib/features/users/widgets/user_card.dart lib/screens/data_source_screen.dart lib/screens/financial_management_screen.dart lib/screens/login_screen.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/screens/home_screen.dart lib/features/home/widgets/home_widgets.dart lib/screens/app_info_screen.dart lib/widgets/unified_search_field.dart lib/widgets/reusable_date_range_picker.dart lib/screens/purchase_records_screen.dart lib/screens/financial_management_screen.dart lib/screens/data_source_screen.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/screens/materials_screen.dart lib/screens/login_screen.dart lib/screens/app_info_screen.dart lib/features/materials/widgets/compact_material_action_button.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/features/appointments/widgets/appointment_date_time_section.dart lib/features/appointments/widgets/appointment_treatment_section.dart lib/features/appointments/widgets/appointment_form_dialog.dart lib/features/appointments/widgets/appointment_notes_section.dart lib/features/appointments/widgets/appointment_cost_status_section.dart lib/features/appointments/widgets/appointment_patient_selection_section.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/features/financial/widgets/financial_record_edit_dialog.dart lib/features/financial/widgets/financial_form_dialog.dart lib/features/financial/widgets/edit_financial_item_dialog.dart lib/features/financial/widgets/patient_selection_dialog.dart lib/features/patients/widgets/patient_form_shell.dart lib/features/patients/widgets/patient_form_fields.dart lib/features/patients/widgets/patient_form_sections.dart lib/features/patients/widgets/patient_medical_record_detail_dialog.dart lib/features/patients/widgets/single_material_editor.dart lib/features/materials/widgets/material_form_dialog.dart lib/features/materials/widgets/material_detail_dialog.dart lib/features/purchases/widgets/purchase_detail_dialog.dart`
  - 结果：`No issues found!`

## 历史执行记录

1. ~~阶段 4：弹窗、表单、详情页迁移~~（已完成）
   - 三批次文件已全部迁移并验证

2. ~~阶段 5：统计、图表、牙位和特殊控件~~（已完成）
   - 患者/财务/采购统计弹窗、饼图/折线图、牙位图、图片预览等特殊视觉控件已迁移

3. ~~阶段 6：旧系统清理~~（已完成）
   - 已移除所有 `isPurpleTheme` 分支和参数
   - 已删除 `AppTheme.purple*` 常量
   - 已清理剩余运行链路中的普通 `AppTheme.*` 入口

4. ~~阶段 7：最终颜色来源收口~~（已完成）
   - 已按 `windows_app_theme_stage4_6_review_and_fix_plan_2026_07_05.md` 修复方案完成 `DentalColors` 普通主题职责清理和直接 `Colors.xxx` / `Color(0x...)` 入口收口；剩余命中均归入允许例外清单

## 阶段 4 详细范围

### 状态

完成。阶段 4 三批次文件已统一接入 `context.tokens` / `context.colors`，仅保留必要业务语义色；`appointment_form_dialog.dart` 实际使用的是 `appointment_date_time_section.dart` 与 `appointment_treatment_section.dart`（原列表中的 `treatment_section.dart` 为未使用/旧版文件，未纳入本次运行链路迁移）。

### 第一批建议优先处理

- `lib/features/financial/widgets/financial_record_edit_dialog.dart`
  - 仍有大量直接颜色入口，重点是头部渐变、表单区、底部操作区、金额/状态强调色
- `lib/features/financial/widgets/financial_form_dialog.dart`
  - 仍有大量 `Colors.*` 和普通容器色，需统一接回 `context.tokens`
- `lib/features/financial/widgets/edit_financial_item_dialog.dart`
  - 重点看输入区、项目卡片、底部确认区
- `lib/features/financial/widgets/patient_selection_dialog.dart`
  - 仍有固定蓝紫渐变、固定白底和列表态视觉

### 第二批建议优先处理

- `lib/features/patients/widgets/patient_form_shell.dart`
  - 仍有 `DentalColors.primaryGradient`、`cardGradient`、`divider`、`onSurfaceVariant`
- `lib/features/patients/widgets/patient_form_fields.dart`
  - 仍有较多 `DentalColors.*`
- `lib/features/patients/widgets/patient_form_sections.dart`
  - 仍有较多 `DentalColors.*`
- `lib/features/patients/widgets/patient_medical_record_detail_dialog.dart`
  - 病历详情、提示块、信息区、标签和状态容器仍混用旧入口
- `lib/features/patients/widgets/single_material_editor.dart`
  - 图片编辑区、说明块、操作按钮和辅助卡片仍有大量直接颜色

### 第三批建议优先处理

- `lib/features/materials/widgets/material_form_dialog.dart`
  - 仍有 `AppTheme.primaryGradient`、`AppTheme.primaryColor`
- `lib/features/materials/widgets/material_detail_dialog.dart`
  - 仍有 `AppTheme.primaryGradient`
- `lib/features/purchases/widgets/purchase_detail_dialog.dart`
  - 明细区、统计区和表头仍需统一
- `lib/features/appointments/widgets/appointment_patient_selection_section.dart`
  - 仍有固定主色和灰白表面
- `lib/features/appointments/widgets/appointment_date_time_section.dart`
  - 日期、时间、快捷标签、说明块仍有固定灰底 / 白底
- `lib/features/appointments/widgets/appointment_cost_status_section.dart`
  - 金额与状态区块仍有固定橙 / 绿 / 紫语义外观
- `lib/features/appointments/widgets/appointment_notes_section.dart`
  - 备注输入与提示区仍需统一
- `lib/features/appointments/widgets/treatment_section.dart`
  - 治疗项目列表和区块级强调色仍需清理

### 阶段 4 验收标准

- 弹窗、表单、详情页不再大面积依赖固定白底、灰底、蓝紫渐变。
- 普通背景、边框、输入框、标签、说明块、页脚按钮全部从 `context.tokens` / `context.colors` 读取。
- 只保留必要业务语义色，不保留普通主题色硬编码。

## 阶段 5 详细范围

### 状态

完成。统计弹窗、图表、牙位和特殊视觉控件已统一接入 `context.tokens` / `context.colors`，旧 `DentalColors`、`AppTheme.primaryGradient` / `AppTheme.primaryColor`、固定白底和普通主题硬编码边框在该范围内已清零。

### 重点文件

- `lib/features/patients/widgets/patient_statistics_dialog.dart`
  - 统计弹窗头部、筛选条、汇总卡、折线图、tooltip 和卡片容器已统一接入主题 token。
- `lib/features/financial/widgets/financial_statistics_dialog.dart`
  - 统计头部、筛选、搜索提示、收费/加工费折线图、排行榜卡片和支付方式统计卡已统一收回到标准主题 token。
- `lib/features/purchases/widgets/purchase_statistics_dialog.dart`
  - 汇总区、图表外围、排行卡片、表头和日期选择器已改为从标准主题 token 读取视觉参数。
- `lib/features/purchases/widgets/purchase_statistics_chart.dart`
  - 统计卡片、月度趋势条、材料排行条/表头/空态已改为从标准主题 token 读取。
- `lib/features/patients/widgets/interactable_pie_chart.dart`
  - 图表系列色已完全改用 `tokens.chartPalette`，图例、标题阴影和未选中文字已接入主题 token。
- `lib/features/patients/widgets/patient_detail_dental_widgets.dart`
  - 牙位详情卡片、创建医生标签、十字线/边框和标题色已统一收回到主题 token。
- `lib/features/appointments/widgets/teeth_condition_section.dart`
- `lib/features/appointments/widgets/teeth_condition_widget.dart`
- `lib/features/appointments/widgets/teeth_cross_widget.dart`
  - 牙位图容器背景、边框、十字线/辅助线和标题图标已统一接入主题 token；`CrossPainter` 改为外部传入 `lineColor`。

### 阶段 5 验收标准

- 图表外围、统计卡片、表头、说明块、空态不再直接写普通主题色。
- 图表系列色统一来自 `tokens.chartPalette` 或明确登记的业务语义例外。
- 牙位图和特殊视觉区域的普通表面色、边框、辅助线不再直接硬编码。
- `flutter analyze lib/features/patients/widgets/patient_statistics_dialog.dart lib/features/financial/widgets/financial_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_chart.dart lib/features/patients/widgets/interactable_pie_chart.dart lib/features/patients/widgets/patient_detail_dental_widgets.dart lib/features/appointments/widgets/teeth_condition_section.dart lib/features/appointments/widgets/teeth_condition_widget.dart lib/features/appointments/widgets/teeth_cross_widget.dart` 通过。

## 阶段 6 详细范围

### 状态

已完成。旧主题系统遗留入口已清理，运行链路中仅保留 `AppTheme.standardTheme()`、`AppTheme.smallBorderRadius` 和 `AppTheme.dangerGradient`。

### 需要清理的核心问题

1. `isPurpleTheme` 分支和相关参数
   - 需要逐文件移除，只保留标准主题路径
   - 典型涉及：
   - `lib/screens/materials_screen.dart`
   - `lib/screens/purchase_records_screen.dart`
   - `lib/features/patients/widgets/patient_list_item.dart`
   - `lib/features/patients/widgets/patient_filter_bar.dart`
   - `lib/features/purchases/widgets/purchase_export_dialog.dart`
   - `lib/features/purchases/widgets/purchase_hoverable_cards.dart`
   - `lib/features/purchases/widgets/hoverable_purchase_record_card.dart`
   - `lib/features/users/widgets/user_form_dialog.dart`
   - `lib/features/users/widgets/reset_password_dialog.dart`
   - `lib/features/users/widgets/permission_preview_dialog.dart`

2. `AppTheme.purple*` 常量
   - 文件：`lib/theme/app_theme.dart`
   - 需在紫色分支全部移除后删除，避免继续被死代码引用

3. 剩余运行链路普通 `AppTheme.*` 入口
   - 重点不是 `AppTheme.standardTheme()`，而是页面和组件里直接拿 `AppTheme.primaryColor`、`secondaryColor`、`primaryText`、`primaryGradient` 之类旧静态值

4. 旧活跃配置残留
   - 阶段 6 需要继续复核是否还有不该保留的旧主题兼容逻辑重新进入运行链路

### 阶段 6 验收标准

- `rg -n "isPurpleTheme|AppTheme\\.purple|purpleBackground|purpleColor" lib -g "*.dart"` 在运行代码中无命中
- 普通 `AppTheme.*` 页面级入口清零
- 标准主题运行链路只保留 `AppTheme.standardTheme()` 这一构建入口

## 阶段 7 详细范围

### 状态

已完成。阶段 4 到阶段 6 已闭环，`DentalColors` 普通主题职责和直接 `Colors.xxx` / `Color(0x...)` 入口已按修复方案收口，剩余命中均归入允许例外清单。

### 目标

- 清退 `DentalColors` 在业务页面、业务组件、表单组件、详情组件中的普通主题职责
- 清理剩余绕过统一主题入口的 `Colors.xxx` / `Color(0x...)`
- 建立允许例外清单，明确哪些颜色可以继续保留为业务语义色

### 允许保留的颜色类型

- 状态语义色
  - 例如成功、警告、错误、取消、紧急等业务状态色
- 医学识别色
  - 例如牙位、病种、病历识别等确实具有专业语义的颜色
- 图表系列色
  - 例如折线图、饼图、排行图的调色板
- 图片 / 头像 / 上传素材原色
  - 不属于主题系统控制范围

### 需要清理的典型范围

1. `DentalColors` 普通主题职责
   - 背景色
   - 卡片色
   - 普通边框色
   - 表面容器色
   - 普通按钮渐变
   - 普通标题图标底色

2. 直接颜色入口
   - `Colors.white`
   - `Colors.grey.*`
   - `Colors.black*`
   - 零散 `Colors.blue/green/orange/red/purple`
   - `Color(0x...)`

3. 需要重点复核的高密度区域
   - 财务编辑和统计相关组件
   - 材料页和材料详情 / 调试链路
   - 预约时间 / 治疗项目区块
   - 病历初始化和医疗记录深层组件
   - 仍保留大量直接色的历史业务组件

### 阶段 7 执行方式

- 先区分“普通主题色”与“允许例外语义色”
- 先收普通主题色，再登记例外清单
- 每批处理 3 到 5 个高密度文件，避免再次回到大批量半自动改写
- 每批都要跑针对性 `flutter analyze`

### 阶段 7 当前已处理批次

- 文档修正：`windows_app_theme_migration_actual_status_2026_07_04.md` 中阶段 4/5/6 改为历史记录，阶段 7 改为进行中。
- 医疗记录组件 `DentalColors`：`medical_record_form_dialog.dart`、`allergy_selection_widget.dart`、`disease_type_edit_dialog.dart`、`medical_template_edit_dialog.dart`、`medical_record_form_input_field.dart`、`template_selection_widget.dart`。
- 患者详情/卡片 `DentalColors`：`patient_detail_overview_card.dart`、`patient_card.dart`、`patient_app_bar_actions.dart`、`patient_detail_medical_record_widgets.dart`、`patient_search_bar.dart`。
- 预约详情/卡片 `DentalColors`：`appointment_details_screen.dart`、`appointments_screen.dart`、`appointment_card.dart`、`appointment_details_patient_card.dart`、`appointment_filter_bar.dart`。
- 设置页直接颜色：`database_check_widgets.dart`、`data_source_type_switch_section.dart`、`data_source_configuration_section.dart`、`backup_data_source_section.dart`。
- 业务组件直接颜色：`purchase_form_item_list_section.dart`、`patient_form_dental_section.dart`、`patient_detail_financial_widgets.dart`、`financial_table_header.dart`、`material_image_detail_dialog.dart`、`material_image_preview.dart`、`material_detail_card.dart`、`appointment_time_picker.dart`。
- 剩余 `DentalColors` 收口：`modern_dashboard_screen.dart`、`users_screen.dart`、`purchase_records_screen.dart`、`dashboard_status_helper.dart`。
- 最终收口（2026-07-05）：补充修复 `appointments_screen.dart` 成功提示条 `Colors.green.shade600` → `context.tokens.success`，以及 `patient_detail_financial_widgets.dart` 患者性别识别色 `Colors.pink` / `Colors.blue` → `DentalColors.femalePink` / `maleBlue`；全量 `flutter analyze` 0 error / 0 warning / 0 info；`theme_migration_assistant.py --scan` 复核 `dental_colors: 24`（均为 `femalePink` / `maleBlue` 性别例外），`direct_colors: 39`（均为透明色、医学识别色、图表色板、性别语义色等允许例外），`purple: 0`。
- 验证：以上所有文件针对性 `flutter analyze` 均 `No issues found!`；全量 `flutter analyze` 0 error / 0 warning / 0 info。
- 剩余规模：`DentalColors` 在 `lib/screens` / `lib/features` 中仅剩 `femalePink` / `maleBlue`（性别语义例外）；直接 `Colors.xxx` / `Color(0x...)` 命中降至 39（`theme_migration_assistant.py --scan` 统计），全部归入允许例外清单。

### 阶段 7 验收标准

- `lib/screens` 与 `lib/features` 中剩余 `DentalColors` 命中只能属于允许例外清单
- 普通 UI 不再直接写 `Colors.xxx` / `Color(0x...)`
- 页面、组件、弹窗、表单的普通视觉参数都能追溯到 `context.tokens`、`context.colors` 或 `ThemeData`
- 新增主题时，不需要再修改业务页面颜色逻辑

## 当前待办

- [x] 阶段 4 第一批：财务编辑/新增/患者选择弹窗
- [x] 阶段 4 第二批：患者表单、病历详情、患者材料编辑
- [x] 阶段 4 第三批：预约表单深层区块、材料详情/编辑、采购详情
- [x] 阶段 5：患者/财务/采购统计弹窗、图表、牙位图和特殊视觉控件
- [x] 阶段 6：清理全部紫色分支、`AppTheme.purple*` 和剩余运行链路普通 `AppTheme.*`
- [x] 阶段 7：建立允许例外清单，清理剩余 `DentalColors` 普通主题职责和直接颜色入口（已完成；剩余 `DentalColors` 仅 `femalePink` / `maleBlue` 性别例外，剩余直接颜色命中均归入允许例外清单）

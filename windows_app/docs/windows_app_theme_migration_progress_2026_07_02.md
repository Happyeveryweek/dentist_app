# Windows 端主题迁移进度

## 文档定位

本文件是 Windows 端主题统一治理的进度源，用于记录每个阶段的状态、已完成事项、待办、阻塞和最近验证。

入口文档：[统一主题颜色风格改进方案总览](windows_app_theme_unification_overview_2026_07_02.md)

实施步骤：[迁移实施步骤](windows_app_theme_migration_steps_2026_07_02.md)

## 状态说明

- `未开始`：尚未实施。
- `进行中`：已有代码修改，但未完成阶段验收。
- `已完成`：已实现并通过对应验证。
- `阻塞`：需要用户确认或外部条件才能继续。

## 当前阶段

- 阶段 1、阶段 2、阶段 3、阶段 4、阶段 5、阶段 6、阶段 7 普通主题色迁移已全部完成并通过全量静态检查；`windows_app` 统一主题治理闭环。
- 阶段 7 后续医学识别色集中治理已完成：新增 `lib/theme/medical_semantic_colors.dart` 作为医学/患者识别色唯一入口，第一阶段 6 个文件 19 处直接医学识别色与第二阶段 9 个文件中 `DentalColors.femalePink` / `DentalColors.maleBlue` 性别识别色已全部迁入 `MedicalSemanticColors`；`theme_migration_assistant.py --scan` 复核 `direct_colors: 0`、`dental_colors: 0`、`purple: 0`，`app_theme: 3`（仅保留 `AppTheme.standardTheme()` / `smallBorderRadius` / `dangerGradient`），全量 `flutter analyze` 0 issue。
## 总体进度

| 阶段 | 状态 | 说明 |
| --- | --- | --- |
| 阶段 0：文档拆分与执行规范整理 | 已完成 | 已新增总览、规则、实施步骤、进度文档。 |
| 阶段 1：主题基础设施 | 已完成 | `AppThemeTokens`、上下文扩展、标准主题构建入口和 `ThemeData` 覆盖已落地；柔和灰入口、滤镜和运行链路已退出。 |
| 阶段 2：公共组件主题化 | 已完成 | 公共卡片、按钮、状态标签、搜索框、日期选择器、Toast、确认/错误弹窗、分页组件和 hoverable card 已统一改为从标准主题 token 读取视觉语义。 |
| 阶段 3：主框架和高频页面迁移 | 已完成 | 已完成主框架、首页、仪表盘、患者页和 5 个高频页面壳层的标准主题 token 迁移；阶段 4 再继续处理更深层弹窗、表单和详情内容。 |
| 阶段 4：弹窗、表单和详情页迁移 | 已完成 | 深层弹窗、表单和详情内容的标准主题 token 化已完成并通过验证。 |
| 阶段 5：图表、统计页和特殊视觉控件 | 已完成 | 患者/财务/采购统计弹窗、采购统计图表、可交互饼图、牙位相关组件已统一接入标准主题 token。 |
| 阶段 6：清理旧系统和兜底滤镜 | 已完成 | `AppTheme.purple*` 常量、`isPurpleTheme` 分支和普通 `AppTheme.*` 页面级入口已全部清理；运行链路中仅保留 `AppTheme.standardTheme()`、`AppTheme.smallBorderRadius` 和 `AppTheme.dangerGradient`。 |
| 阶段 7：剩余颜色来源彻底并入统一主题系统 | 已完成 | 按修复方案完成阶段 7 剩余收口：`users_screen.dart`、`settings_card.dart`、`financial_detail_table_header.dart`、`auto_backup_settings.dart`、`appointment_list.dart`、`financial_empty_state.dart`、`financial_stat_item.dart`、`purchase_stat_item.dart`、`material_detail_dialog.dart`、`material_form_field.dart` 的普通直接颜色已接入 `context.tokens` / `context.colors`；设置页 `backup_data_source_section.dart`、`data_source_configuration_section.dart`、`data_source_type_switch_section.dart` 的旧 `AppTheme.primaryColor` / `accentColor` / `secondaryColor` / `successColor` / `secondaryText` 已统一为 token；`main.dart` 错误 / 警告态颜色已接入主题 token；`DentalColors` 普通主题职责已清零，`lib/screens` / `lib/features` 中剩余 `DentalColors` 仅 `femalePink` / `maleBlue` 性别语义例外；直接 `Colors.xxx` / `Color(0x...)` 剩余命中均归入透明色、医学识别色、图表色板、性别语义色等允许例外清单；旧柔和灰 / 紫色链路保持 0 命中；全量 `flutter analyze` 通过。 |

## 前置已完成

这些事项属于阶段 1 之前的背景，不代表主题统一已整体完成：

- 设置页、首页外壳、仪表盘和部分设置组件已有低饱和灰蓝适配，但这属于待清理的临时方案。
- 已明确主题统一不应长期依赖全局滤镜，也不再保留柔和灰作为产品主题。
- 已新增拆分文档：
  - `windows_app_theme_unification_overview_2026_07_02.md`
  - `windows_app_theme_tokens_and_rules_2026_07_02.md`
  - `windows_app_theme_migration_steps_2026_07_02.md`
  - `windows_app_theme_migration_progress_2026_07_02.md`

## 阶段 1：主题基础设施

状态：已完成

已完成：

- 新增 `lib/theme/app_theme_tokens.dart`，集中标准主题 token。
- 新增 `lib/theme/theme_context_extensions.dart`，统一 `context.tokens` / `context.colors` 读取入口。
- 重构 `lib/theme/app_theme.dart`，由标准 token 构建 `ThemeData`，并把 `ThemeData.extensions` 接入 `AppThemeTokens`。
- 修改 `lib/main.dart`，移除 `MaterialApp.builder` 的滤镜主题链路，统一使用标准主题构建入口。
- 移除设置页柔和灰入口，`ThemeSection` 改为标准主题说明，不再暴露主题切换。
- 收敛 `SettingsProvider` / `ConfigStorageService`：历史 `extendedThemeMode == grey` 会在加载时迁回标准主题，保存时只写标准主题值。
- 清理 `home_screen.dart`、`settings_screen.dart`、设置页组件和 `dental_icons.dart` 中的 `isGreyTheme` / `greyAccent` 运行分支。
- `windows_app/AGENTS.md` 已补充主题编码规则。

说明：

- `ThemeCard` 和紫色兼容常量当前仅作为历史兼容保留，不再参与当前主题入口和运行链路。

## 阶段 2：公共组件主题化

状态：已完成

已完成：

- `lib/widgets/dental_icons.dart` 中的 `DentalCard`、`DentalGradientButton`、`DentalStatusIndicator` 已改为默认从 `context.tokens` / `context.colors` 读取卡片背景、边框、阴影、主按钮渐变和状态色。
- `lib/widgets/unified_search_field.dart` 已改为使用主题输入背景、边框和焦点色，不再写死普通搜索框的灰白底和固定蓝色边框。
- `lib/widgets/modern_date_picker.dart`、`lib/widgets/reusable_date_range_picker.dart` 已接入主题 token，统一对话框壳、hover、选中态、提示块和按钮颜色。
- `lib/widgets/success_toast.dart` 中的 `AppToast`、`AppToastManager`、`InlineSuccessMessage`、`DeleteConfirmDialog`、`ErrorDialog`、`LogoutConfirmDialog` 已统一改为从主题 token 读取成功/错误/提示、遮罩、边框和表面色。
- `lib/features/dashboard/widgets/hoverable_stat_card.dart`、`lib/features/materials/widgets/material_hoverable_cards.dart`、`lib/features/patients/widgets/hoverable_patient_card.dart`、`lib/features/purchases/widgets/hoverable_purchase_record_card.dart`、`lib/features/purchases/widgets/purchase_hoverable_cards.dart`、`lib/features/financial/widgets/financial_hoverable_cards.dart` 已统一改为从主题 token 读取 hover 背景、描边和阴影。
- `lib/features/materials/widgets/material_pagination_button.dart`、`lib/features/materials/widgets/material_pagination.dart`、`lib/features/patients/widgets/patient_pagination.dart`、`lib/features/purchases/widgets/pagination_widget.dart`、`lib/features/purchases/widgets/purchase_pagination.dart`、`lib/features/financial/widgets/financial_pagination.dart` 已统一改为从主题 token 读取分页按钮、信息块、跳页输入框和确认按钮视觉。
- `lib/features/patients/widgets/patient_snack_bars.dart` 已统一改为从主题 token 读取提示色和表面色。

说明：

- 阶段 2 范围内原计划待清理的删除确认框、退出确认框、错误弹窗、分页组件和 hoverable card 已全部完成迁移，不再拆到阶段 4。

## 阶段 3：主框架和高频页面迁移

状态：已完成

已完成：

- `lib/screens/appointments_screen.dart` 已改为从 `context.tokens` / `context.colors` 读取 AppBar 图标底、工具按钮、刷新按钮和悬浮新增按钮颜色；编辑成功提示条也已改为标准主题成功色。
- `lib/screens/financial_management_screen.dart` 已把 AppBar 图标底、显示模式切换按钮、添加/统计/刷新按钮统一接入标准主题 token，并把页面内错误提示 `SnackBar` 收敛到统一 `AppToastManager`。
- `lib/screens/purchase_records_screen.dart` 已移除页面内紫色主题分支，改造 AppBar、搜索面板、错误态、空态和采购记录 hover 卡片为标准主题 token；采购记录标签与图标色只保留业务语义色。
- `lib/screens/materials_screen.dart` 已移除页面内紫色主题分支，改造 AppBar、搜索面板、类型筛选入口和材料卡片入口为标准主题 token；类型筛选菜单的选中态和头部渐变也已统一接入主题。
- `lib/screens/medical_management_screen.dart` 已改造页面背景、AppBar、Tab 容器、内容容器和错误态为标准主题 token，不再直接依赖 `AppTheme.primaryGradient`、固定白底和固定灰底。
- `lib/screens/home_screen.dart` 已把主框架导航色入口改为跟随标准主题 token，侧栏告警、导航选中态、品牌区装饰和顶部状态条阴影不再依赖页面内固定橙色、灰色或黑色阴影写法。
- `lib/features/home/widgets/home_widgets.dart` 已把底部用户信息区改为读取标准主题 surface / border / muted token，移除淡紫色固定底和灰色占位色。
- `lib/screens/modern_dashboard_screen.dart` 已把欢迎卡、统计卡、今日预约区、最近患者区、空态和列表行的普通页面视觉统一到标准主题 token；只保留少量业务语义色和性别语义色。
- `lib/screens/patients_screen.dart` 以及 `lib/features/patients/widgets/patient_screen_scaffold.dart`、`patient_screen_body.dart`、`patient_app_bar_title.dart`、`patient_app_bar_actions.dart` 已统一接入标准主题 token，患者页壳层、AppBar 和加载遮罩不再依赖固定白底、蓝绿紫按钮分支。

说明：

- 阶段 3 已完成的范围是“主框架和高频页面壳层视觉入口统一”；这些页面下更深层弹窗、表单、详情内容继续归入阶段 4 处理。

## 阶段 4：弹窗、表单和详情页迁移

状态：已完成

已完成：

- `lib/features/patients/widgets/patient_form_shell.dart`、`patient_form_validation_dialogs.dart` 已把患者表单头部、权限提示、底部操作区和重名/重复病历号弹窗收回到标准主题 token，不再依赖固定橙色提示块、`DentalColors.primaryGradient` 和半透明白底对话框。
- `lib/features/appointments/widgets/appointment_patient_selection_section.dart`、`appointment_date_time_section.dart`、`appointment_cost_status_section.dart`、`appointment_notes_section.dart` 已统一改为从 `context.tokens` 读取容器底色、边框、输入背景和强调色，预约表单的患者、时间、费用/状态、备注区块已退出固定灰白底和固定紫/橙/绿强调色。
- `lib/features/appointments/widgets/appointment_form_dialog.dart`、`appointment_patient_search_dialog.dart` 已把预约表单外层弹窗壳、头部渐变、页脚和患者搜索结果卡统一改为使用标准主题 token，不再依赖固定蓝紫渐变、固定白底和固定灰白交替列表底色。
- `lib/features/financial/widgets/financial_record_edit_dialog.dart`、`patient_selection_dialog.dart` 已把财务记录编辑壳层、患者选择弹窗、内联编辑下拉和底部操作区收回到标准主题 token，不再依赖固定白底、固定蓝靛渐变、固定灰白边框和表格交替底色。
- `lib/features/patients/widgets/patient_medical_record_detail_dialog.dart`、`single_material_editor.dart` 已把病历详情、关联牙齿状况卡、患者材料编辑和图片预览弹窗收回到标准主题 token，不再依赖固定灰白容器、固定青色强调头和固定灰色占位/错误态。
- `lib/features/materials/widgets/material_form_dialog.dart`、`material_detail_dialog.dart` 已统一改为使用标准主题 token 的对话框表面、头部渐变、信息卡、页脚和主按钮。
- `lib/features/purchases/widgets/purchase_detail_dialog.dart` 已统一改为使用标准主题 token 的详情卡、统计卡、表头和明细卡，不再依赖固定蓝/绿浅色背景和固定白卡片边框。
- `lib/features/settings/widgets/structure_check_result_dialog.dart` 已把结构检测状态卡和统计卡收回到标准主题 token，并按 success / warning / error 容器语义展示。

说明：

- 阶段 4 的范围限定为深层弹窗、表单和详情内容的标准主题 token 化；图表、统计卡、牙位图等特殊视觉控件继续留在阶段 5。

## 阶段 5：图表、统计页和特殊视觉控件

状态：已完成

已完成：

- `lib/features/patients/widgets/patient_statistics_dialog.dart` 已把统计弹窗头部、日期筛选条、搜索提示、汇总卡和两组折线图统一接入 `context.tokens` / `context.colors`，不再依赖 `DentalColors.primaryGradient`、固定白底和普通主题硬编码边框。
- `lib/features/patients/widgets/interactable_pie_chart.dart` 已改为优先使用 `tokens.chartPalette` 与统一文字/箭头语义色，不再混用 `DentalColors` 和页面内 `Colors.purple`、`Colors.orange` 等普通主题配色。
- `lib/features/financial/widgets/financial_statistics_dialog.dart` 已把统计弹窗头部、时间筛选、搜索提示、收费/加工费折线图、排行榜卡片和支付方式统计卡统一收回到标准主题 token；金额显隐逻辑保持不变。
- `lib/features/purchases/widgets/purchase_statistics_dialog.dart` 已移除对 `AppTheme.primaryGradient` / `AppTheme.primaryColor` 的页面级依赖，采购统计头部、搜索提示、汇总卡、折线图和材料排行卡已统一改为从标准主题 token 读取视觉参数。
- `lib/features/patients/widgets/patient_detail_dental_widgets.dart`、`lib/features/appointments/widgets/teeth_condition_section.dart`、`lib/features/appointments/widgets/teeth_condition_widget.dart`、`lib/features/appointments/widgets/teeth_cross_widget.dart` 已把牙位图卡片、标签、边框、十字线和空态统一收回到标准主题 token；`CrossPainter` 已改为外部传入 `lineColor`。
- `lib/features/patients/widgets/patient_medical_record_detail_dialog.dart`、`lib/features/patients/widgets/single_material_editor.dart` 已把病历详情中的关联牙齿状况卡、材料图片网格和图片预览弹窗继续收口到标准主题 token。
- `lib/features/purchases/widgets/purchase_statistics_chart.dart` 已把采购统计汇总卡、月度趋势条、材料排行条、表头、空态和排行图标的普通主题色统一收回到标准主题 token。
- `lib/features/appointments/widgets/appointment_details_teeth_section.dart` 已把预约详情牙位区块的卡片底色、边框、标题图标和空态统一收回到标准主题 token。
- `lib/features/financial/widgets/financial_statistics_dialog_widget.dart` 虽然当前属于历史未使用组件，但其统计卡、柱形趋势区、排行条和卡片容器也已迁移到标准主题 token，避免后续误复用时重新带回普通主题硬编码。

说明：

- `lib/screens/modern_dashboard_screen.dart` 在阶段 3 已完成普通页面视觉统一；阶段 5 复核后确认其保留项仅为性别等业务语义色，不再存在需要继续迁移的普通主题图表/统计残留。

## 阶段 6：清理旧系统和兜底滤镜

状态：已完成

已完成：

- 柔和灰主题入口、`AppThemeVisualFilter` 和灰主题运行链路已在阶段 1 退出，当前未重新进入运行链路。
- `lib/theme/app_theme.dart` 已删除全部 `AppTheme.purple*` 历史常量（`purpleColor`、`purpleLightColor`、`purpleDarkColor`、`purpleBackground`、`purpleCardBackground`、`purplePrimaryText`、`purpleSecondaryText`、`purpleLightText`、`purpleDividerColor`、`purpleSecondaryBackground`、`purpleCardShadow`）。
- `lib/features/users/widgets/user_form_dialog.dart`、`reset_password_dialog.dart` 已移除 `isPurpleTheme` / `AppTheme.purple*` 分支和 `darkPrimaryText` 死分支，统一回到标准主题入口。
- `lib/features/patients/widgets/hoverable_patient_card.dart` 已移除 `isPurpleTheme` 字段和所有紫色配色分支；`patient_card.dart`、`patient_export_dialog.dart`、`patient_filter_bar.dart`、`patient_advanced_search_fields.dart`、`patient_list_item.dart` 已移除紫色主题判断和配色分支。
- `lib/features/purchases/widgets/purchase_export_dialog.dart` 已移除紫色主题判断和配色分支。
- settings widgets（13 个文件）：`backup_action_buttons.dart`、`auto_backup_settings.dart`、`backup_path_inputs.dart`、`backup_path_input.dart`、`backup_data_source_section.dart`、`backup_log_dialog.dart`、`data_source_selection_dialog.dart`、`data_source_page_header.dart`、`data_sync_dialog.dart`、`edit_app_name_dialog.dart`、`data_source_type_switch_section.dart`、`settings_header_card.dart`、`setting_item.dart` 已把 `AppTheme.primaryColor` / `secondaryColor` / `primaryGradient` / `successColor` / `errorColor` / `secondaryText` / `dividerColor` 页面级入口统一收回到 `context.tokens` / `context.colors`。
- `data_source_configuration_section.dart`、`about_section.dart` 已把 `AppTheme.primaryColor` / `successColor` / `accentColor` 入口收回到 `context.tokens`。
- patients widgets（14 个文件）：`patient_advanced_search_fields.dart`、`patient_filter_bar.dart`、`patient_action_buttons.dart`、`patient_empty_state.dart`、`patient_floating_add_button.dart`、`patient_form_dental_section.dart`、`patient_sort_options_sheet.dart`、`material_detail_card.dart`、`material_detail_manager.dart`、`material_debug_info_dialog.dart`、`material_empty_state.dart`、`material_image_detail_dialog.dart`、`material_input_widget.dart`、`hoverable_patient_card.dart` 已把 `AppTheme.primaryColor` / `errorColor` / `warningColor` / `infoColor` / `primaryText` / `secondaryText` / `cardBackground` / `cardShadow` / `accentColor` / `lightText` 入口收回到 `context.tokens` / `context.colors`。
- users widgets（6 个文件）：`user_form_dialog.dart`、`reset_password_dialog.dart`、`user_list_loading_state.dart`、`user_list_header.dart`、`user_list_error_state.dart`、`avatar_upload_section.dart` 已把 `AppTheme.primaryColor` / `primaryGradient` / `errorColor` / `darkPrimaryText` 入口收回到 `context.tokens` / `context.colors`。
- appointments widgets：`appointment_time_picker.dart`、`patient_selection_section.dart` 已把 `AppTheme.primaryColor` 入口收回到 `context.tokens.primaryAccent`。
- `lib/screens/medical_template_management_screen.dart`、`lib/widgets/dental_icons.dart`、`lib/features/purchases/widgets/material_selection_dialog.dart` 已把 `AppTheme.primaryGradient` / `secondaryText` / `primaryColor` 入口收回到 `context.tokens`。
- 运行链路中的 `AppTheme.*` 旧主题颜色入口已完成清零；仅保留 `AppTheme.standardTheme()`（标准主题构建入口）、`AppTheme.smallBorderRadius`（布局常量）和 `AppTheme.dangerGradient`（语义渐变，无对应 token）。

说明：

- `AppThemeVisualFilter` 和柔和灰运行链路已在阶段 1 退出；阶段 6 完成后，旧主题系统相关的运行链路已经收口。
- 但总览中的"最终验收"尚未全部满足：`DentalColors` 仍在多处业务页面和病历/详情组件中作为视觉来源存在，需单独推进 `DentalColors` 退场专项后，才能声明最终验收完全通过。

## 阶段 7：剩余颜色来源彻底并入统一主题系统

状态：已完成

目标：

- 系统涉及的所有颜色来源最终接入统一主题系统。
- `DentalColors` 不再承担业务页面、病历/详情组件、表单组件和普通业务组件的主题职责。
- 只保留经过确认的语义色：状态色、医学识别色、图表系列色。

已完成：

- 阶段 7 文档状态修正（2026-07-05）：`windows_app_theme_migration_actual_status_2026_07_04.md` 中“后续执行顺序”已改为“历史执行记录”，阶段 4/5/6 标记为完成，阶段 7 标记为进行中，删除“只在阶段 4 到阶段 6 完成后启动”等旧描述。
- 医疗记录组件 `DentalColors` 迁移：`medical_record_form_dialog.dart`、`allergy_selection_widget.dart`、`disease_type_edit_dialog.dart`、`medical_template_edit_dialog.dart`、`medical_record_form_input_field.dart`、`template_selection_widget.dart` 的状态色已接入 `context.tokens`，针对性 `flutter analyze` 0 issue。
- 患者详情/卡片 `DentalColors` 迁移：`patient_detail_overview_card.dart`、`patient_card.dart`、`patient_app_bar_actions.dart`、`patient_detail_medical_record_widgets.dart`、`patient_search_bar.dart` 的状态色已接入 `context.tokens`；`patient_card.dart` 保留 `DentalColors.femalePink` / `maleBlue` 作为性别语义例外。
- 预约详情/卡片 `DentalColors` 迁移：`appointment_details_screen.dart`、`appointments_screen.dart`、`appointment_card.dart`、`appointment_details_patient_card.dart`、`appointment_filter_bar.dart` 的状态色已接入 `context.tokens`，针对性 `flutter analyze` 0 issue。
- 设置页直接颜色迁移：`database_check_widgets.dart`、`data_source_type_switch_section.dart`、`data_source_configuration_section.dart`、`backup_data_source_section.dart` 的普通主题色已接入 `context.tokens` / `context.colors`，针对性 `flutter analyze` 0 issue。
- 业务组件直接颜色迁移：`purchase_form_item_list_section.dart`、`patient_form_dental_section.dart`、`patient_detail_financial_widgets.dart`、`financial_table_header.dart`、`material_image_detail_dialog.dart`、`material_image_preview.dart`、`material_detail_card.dart`、`appointment_time_picker.dart` 的普通主题色已接入 `context.tokens` / `context.colors`，针对性 `flutter analyze` 0 issue。
- 剩余 `DentalColors` 收口：`modern_dashboard_screen.dart`、`users_screen.dart`、`purchase_records_screen.dart`、`dashboard_status_helper.dart` 的状态色已接入 `context.tokens`；当前 `lib/screens` / `lib/features` 中剩余 `DentalColors` 仅 `femalePink` / `maleBlue`（性别语义例外）。
- 阶段 7 最终收口（2026-07-05 本轮）：按 `windows_app_theme_stage4_6_review_and_fix_plan_2026_07_05.md` 处理必修文件清单与设置页旧 `AppTheme.*` 入口；`users_screen.dart`、`settings_card.dart`、`financial_detail_table_header.dart`、`auto_backup_settings.dart`、`appointment_list.dart`、`financial_empty_state.dart`、`financial_stat_item.dart`、`purchase_stat_item.dart`、`material_detail_dialog.dart`、`material_form_field.dart` 的普通直接颜色已替换为 `context.tokens` / `context.colors`；`backup_data_source_section.dart`、`data_source_configuration_section.dart`、`data_source_type_switch_section.dart` 的旧 `AppTheme.*` 入口已全部统一为 token 并移除未使用的 `app_theme.dart` 导入；`main.dart` 错误 / 警告态直接颜色已接入 `context.tokens.error` / `errorContainer` / `warning` / `warningContainer` / `colors.onSurface`；`financial_calculation_helper.dart` 性别色统一使用 `DentalColors.femalePink` / `maleBlue`；`appointment_details_summary_card.dart`、`medical_record_step_header.dart`、`patient_empty_state.dart`、`patient_floating_add_button.dart`、`patient_screen_body.dart`、`avatar_upload_section.dart`、`permission_panel.dart`、`app_info_screen.dart`、`data_source_screen.dart` 的剩余普通直接颜色已接入主题系统。

执行要求：

- 普通主题色命中必须迁移到 `context.tokens`、`context.colors` 或 `ThemeData`。
- 语义色命中必须单独归类，不能与普通主题来源混用。
- 阶段完成时，`lib/screens` 与 `lib/features` 中剩余 `DentalColors` 命中只能属于允许例外清单。

允许例外清单：

- `Colors.transparent`：透明背景、裁切、隐藏占位等。
- 患者性别识别色：统一使用 `MedicalSemanticColors.femaleGender` / `maleGender` / `unknownGender`。
- 医学识别色：统一使用 `MedicalSemanticColors`；病历模板类别色、疾病类型图标色、牙齿图标色、`dentalTeal` 等均已从页面局部常量 / 直接色值集中到 `lib/theme/medical_semantic_colors.dart`。
- 图表系列色：必须使用 `context.tokens.chartPalette`。
- 图片 / 头像 / 上传素材 / 媒体预览遮罩：优先使用 `context.tokens.overlayScrim`。
- PDF/导出/打印等需要固定色值的输出场景。

当前状态：

- 医学识别色与患者性别识别色已集中到 `MedicalSemanticColors`；业务页面不再直接写 `Colors.blue` / `Colors.green` / `Colors.orange` / `Colors.grey` / `Color(0xFF009688)`，也不再依赖 `DentalColors.femalePink` / `maleBlue`。
- `theme_migration_assistant.py --scan` 复核：`direct_colors: 0`、`dental_colors: 0`、`purple: 0`，`app_theme: 3`（仅 `AppTheme.standardTheme()` / `smallBorderRadius` / `dangerGradient` 等允许项）。
- 旧柔和灰 / 紫色链路保持 0 命中。
- 全量 `flutter analyze` 与本次治理涉及文件的所有针对性 analyze 均 `No issues found!`。
- 阶段 7 已完成，主题迁移全部闭环。

## 最近验证

- 2026-07-05（医学识别色集中治理）：按 `windows_app/docs/windows_app_medical_semantic_colors_plan_2026_07_05.md` 完成医学识别色收口；新增 `lib/theme/medical_semantic_colors.dart` 作为医学/患者识别色唯一入口，第一阶段 `medical_template_category_style_helper.dart`、`disease_type_edit_dialog.dart`、`appointment_details_teeth_section.dart`、`financial_calculation_helper.dart`、`patient_form_sections.dart`、`patient_medical_record_detail_dialog.dart` 的 19 处直接医学识别色已迁入 `MedicalSemanticColors`；第二阶段 `filtered_patients_screen.dart`、`modern_dashboard_screen.dart`、`appointment_details_patient_card.dart`、`financial_calculation_helper.dart`、`financial_patient_info_section.dart`、`financial_record_edit_dialog.dart`、`patient_card.dart`、`patient_detail_financial_widgets.dart`、`patient_list_item.dart` 的 `DentalColors.femalePink` / `maleBlue` 性别识别色已迁入 `MedicalSemanticColors` 并清理不再需要的 `dental_icons.dart` 导入。`theme_migration_assistant.py --scan --top 40` 复核：`direct_colors: 0`、`dental_colors: 0`、`purple: 0`、`app_theme: 3`（`AppTheme.standardTheme()` / `smallBorderRadius` / `dangerGradient`）；针对性 `flutter analyze` 对第一阶段 7 个文件与第二阶段 8 个文件均 `No issues found!`；全量 `flutter analyze` 0 issue。
- 2026-07-05（阶段 7 最终收口与闭环）：按 `windows_app_theme_stage4_6_review_and_fix_plan_2026_07_05.md` 修复方案完成阶段 7 剩余收口；`users_screen.dart`、`settings_card.dart`、`financial_detail_table_header.dart`、`auto_backup_settings.dart`、`appointment_list.dart`、`financial_empty_state.dart`、`financial_stat_item.dart`、`purchase_stat_item.dart`、`material_detail_dialog.dart`、`material_form_field.dart` 等必修文件清单颜色入口已替换为 `context.tokens` / `context.colors`；`backup_data_source_section.dart`、`data_source_configuration_section.dart`、`data_source_type_switch_section.dart` 的旧 `AppTheme.*` 入口已统一为 token；`main.dart` 错误 / 警告态、`appointment_details_summary_card.dart`、`medical_record_step_header.dart`、`patient_empty_state.dart`、`patient_floating_add_button.dart`、`patient_screen_body.dart`、`avatar_upload_section.dart`、`permission_panel.dart`、`app_info_screen.dart`、`data_source_screen.dart` 的剩余普通直接颜色已接入主题系统；`appointments_screen.dart` 成功提示条 `Colors.green.shade600` 已接入 `context.tokens.success`；`patient_detail_financial_widgets.dart` 患者性别识别色已统一使用 `DentalColors.femalePink` / `maleBlue`（未知性别保留 `Colors.grey.shade400` 作为例外并登记）。全量 `flutter analyze` 0 error / 0 warning / 0 info；`theme_migration_assistant.py --scan` 复核：`dental_colors: 26`（均为 `femalePink` / `maleBlue` 性别例外），`direct_colors: 19`（均为透明色、医学识别色、图表色板、性别语义色、性别未指定中性色等允许例外），`app_theme: 3`（`AppTheme.smallBorderRadius` / `dangerGradient` / `standardTheme()` 等允许项），`purple: 0`；阶段 7 状态更新为已完成，主题迁移全部闭环。
- 2026-07-05（阶段 7 按修复方案执行）：完成 `actual_status` 文档状态修正；医疗记录/患者/预约组件 `DentalColors` 迁移、设置页/业务组件直接颜色迁移，以及 `modern_dashboard_screen.dart` / `users_screen.dart` / `purchase_records_screen.dart` / `dashboard_status_helper.dart` 剩余 `DentalColors` 收口，所有针对性 `flutter analyze` 均 `No issues found!`。全量 `flutter analyze` 0 error / 0 warning，仅 10 个 `prefer_const` info（预先存在）。`theme_migration_assistant` 复核：`DentalColors` 从 131 降至 5（仅 `femalePink` / `maleBlue` 性别例外），直接颜色从 1247 降至 787，`AppTheme.*` 31 处（多为 `smallBorderRadius` / `dangerGradient` / `standardTheme()` 等允许项），紫色残留 0 处。
- 2026-07-04（阶段 6 完成）：`windows_app` 运行全量 `flutter analyze`，0 error、0 warning，仅剩 14 个 info 级别 `prefer_const` 提示（均为预先存在，非本次迁移引入）。阶段 6 范围内 `isPurpleTheme` / `AppTheme.purple*` 紫色分支已清零，普通 `AppTheme.*` 颜色入口已全部迁移到 `context.tokens` / `context.colors`；运行链路中仅保留 `AppTheme.standardTheme()`（标准主题构建入口）、`AppTheme.smallBorderRadius`（布局常量）和 `AppTheme.dangerGradient`（语义渐变，无对应 token）。
- 2026-07-04（复核修正）：阶段 5 完成后对阶段 6/7 真实状态进行复核，发现运行代码中仍存在 `isPurpleTheme` / `AppTheme.purple*` 紫色分支（如 `user_form_dialog.dart`、`reset_password_dialog.dart`、`patient_filter_bar.dart`、`patient_list_item.dart`、`patient_advanced_search_fields.dart`、`patient_export_dialog.dart`、`purchase_export_dialog.dart`、`hoverable_patient_card.dart`、`app_theme.dart`），且 `AppTheme.primaryColor` / `successColor` / `secondaryColor` / `primaryText` / `secondaryText` 等普通 `AppTheme.*` 入口在设置、患者、用户、材料、病历等多个运行链路仍大量存在；`DentalColors` 也仍在 `lib/screens` / `lib/features` 多处业务页面中作为普通主题来源。据此修正本进度文档：阶段 6 为"进行中"，阶段 7 为"未开始"。此前条目中关于阶段 6/7 已清零/已完成的结论以本次复核为准。
- 2026-07-04：`windows_app` 运行 `flutter analyze lib/features/patients/widgets/patient_statistics_dialog.dart lib/features/financial/widgets/financial_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_chart.dart lib/features/patients/widgets/interactable_pie_chart.dart lib/features/patients/widgets/patient_detail_dental_widgets.dart lib/features/appointments/widgets/teeth_condition_section.dart lib/features/appointments/widgets/teeth_condition_widget.dart lib/features/appointments/widgets/teeth_cross_widget.dart`，`No issues found!`；阶段 5 范围内旧 `DentalColors`、`AppTheme.primaryGradient` / `AppTheme.primaryColor`、固定白底和普通主题硬编码边框已清零。
- 2026-07-04：`windows_app` 运行 `flutter analyze lib/features/settings/widgets/structure_check_result_dialog.dart lib/features/financial/widgets/edit_financial_item_dialog.dart lib/features/financial/widgets/financial_form_dialog.dart`，0 issue；并复核 `lib/screens` / `lib/features` 中直接 `Colors.xxx` / `Color(0x...)` 命中已从 `1767` 降到 `1453`。阶段 7 当前剩余高密度入口已转移到设置页数据源区块、`login_screen.dart`、材料/采购明细和患者材料相关组件，颜色入口仍未完全统一。
- 2026-07-04：`windows_app` 运行 `flutter analyze lib/features/settings/widgets/data_source_configuration_section.dart lib/features/settings/widgets/backup_data_source_section.dart lib/features/settings/widgets/data_source_form_widgets.dart`、`flutter analyze lib/features/purchases/widgets/purchase_form_item_list_section.dart`、`flutter analyze lib/features/appointments/widgets/treatment_section.dart`、`flutter analyze lib/features/financial/widgets/financial_table_header.dart`，均为 0 issue；并复核 `lib/screens` / `lib/features` 中直接 `Colors.xxx` / `Color(0x...)` 命中已继续从 `1453` 降到 `1265`。
- 2026-07-04：`windows_app` 运行 `flutter analyze lib/features/patients/widgets/material_detail_manager.dart lib/features/patients/widgets/material_detail_card.dart`、`flutter analyze lib/features/patients/widgets/material_image_preview.dart lib/features/patients/widgets/material_image_detail_dialog.dart`、`flutter analyze lib/screens/login_screen.dart lib/screens/filtered_patients_screen.dart lib/features/patients/widgets/patient_form_dental_section.dart lib/features/patients/widgets/material_image_detail_dialog.dart`，均为 0 issue；并复核 `lib/screens` / `lib/features` 中直接 `Colors.xxx` / `Color(0x...)` 命中已继续从 `1265` 降到 `1065`。
- 2026-07-04：`windows_app` 运行 `flutter analyze lib/screens/app_info_screen.dart lib/screens/settings_screen.dart lib/features/settings/widgets/app_info_widgets.dart`，0 issue；并复核 `lib/screens` / `lib/features` 中直接 `Colors.xxx` / `Color(0x...)` 命中已继续从 `1065` 降到 `1009`。
- 2026-07-04：`windows_app` 运行 `flutter analyze lib/features/patients/widgets/patient_detail_financial_widgets.dart lib/features/purchases/widgets/purchase_statistics_chart.dart`，0 issue；并复核 `lib/screens` / `lib/features` 中直接 `Colors.xxx` / `Color(0x...)` 命中已继续从 `1009` 降到 `956`。
- 2026-07-04：`windows_app` 运行 `flutter analyze`，`No issues found!`。同时复核 `DentalColors` 残留已从阶段 7 初始的大批业务页面收敛到病历模板/病历表单深层组件与少量语义色助手，但 `lib/screens` / `lib/features` 中仍存在大量 `Colors.xxx` / `Color(0x...)` 直接入口，因此阶段 7 仍未完成，颜色入口尚未统一。
- 2026-07-04：补充阶段 7 文档定义，并复核 `lib/screens` / `lib/features` 中 `DentalColors` 仍大量命中，当前主要集中在预约详情、患者详情/病历、患者表单、医疗记录、材料和采购业务组件；本次为文档更新，未运行 Flutter 验证。
- 2026-07-04：`windows_app` 运行 `flutter analyze`，0 issue；并确认运行链路中的 `AppTheme.*` 旧主题入口搜索已清零。
- 2026-07-04：复核柔和灰 / 紫色残留搜索：柔和灰仅剩历史迁移日志与说明文案；紫色仅剩图表局部变量命名，不再参与主题入口或页面渲染。

- 2026-07-03：`windows_app` 运行 `flutter analyze lib/theme/app_theme.dart lib/screens/data_source_screen.dart lib/screens/materials_screen.dart lib/features/materials/widgets/material_hoverable_cards.dart lib/features/patients/widgets/hoverable_patient_card.dart lib/features/patients/widgets/patient_card.dart lib/features/patients/widgets/patient_export_dialog.dart lib/features/patients/widgets/patient_filter_bar.dart lib/features/patients/widgets/patient_advanced_search_fields.dart lib/features/patients/widgets/patient_list_item.dart lib/features/purchases/widgets/hoverable_purchase_record_card.dart lib/features/purchases/widgets/purchase_hoverable_cards.dart lib/features/purchases/widgets/purchase_export_dialog.dart lib/features/users/widgets/user_form_dialog.dart lib/features/users\widgets/reset_password_dialog.dart lib/features/users/widgets/permission_preview_dialog.dart`，0 issue。
- 2026-07-03：`windows_app` 运行 `flutter analyze lib/features/appointments/widgets/appointment_details_teeth_section.dart lib/features/patients/widgets/single_material_editor.dart lib/features/patients/widgets/patient_medical_record_detail_dialog.dart lib/features/financial/widgets/financial_statistics_dialog_widget.dart lib/features/patients/widgets/patient_statistics_dialog.dart lib/features/patients/widgets/interactable_pie_chart.dart lib/features/financial/widgets/financial_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_dialog.dart lib/features/patients/widgets/patient_detail_dental_widgets.dart lib/features/appointments/widgets/teeth_condition_section.dart lib/screens/modern_dashboard_screen.dart`，0 issue。
- 2026-07-03：`windows_app` 运行 `flutter analyze lib/features/patients/widgets/patient_statistics_dialog.dart lib/features/patients/widgets/interactable_pie_chart.dart lib/features/financial/widgets/financial_statistics_dialog.dart lib/features/purchases/widgets/purchase_statistics_dialog.dart lib/features/patients/widgets/patient_detail_dental_widgets.dart lib/features/appointments/widgets/teeth_condition_section.dart`，0 issue。
- 2026-07-03：`windows_app` 运行 `flutter analyze lib/features/appointments/widgets/appointment_form_dialog.dart lib/features/appointments/widgets/appointment_patient_search_dialog.dart lib/features/financial/widgets/financial_record_edit_dialog.dart lib/features/financial/widgets/patient_selection_dialog.dart lib/features/patients/widgets/patient_medical_record_detail_dialog.dart lib/features/patients/widgets/single_material_editor.dart`，0 issue。
- 2026-07-03：`windows_app` 运行 `flutter analyze lib/features/appointments/widgets/appointment_patient_selection_section.dart lib/features/appointments/widgets/appointment_date_time_section.dart lib/features/appointments/widgets/appointment_cost_status_section.dart lib/features/appointments/widgets/appointment_notes_section.dart lib/features/patients/widgets/patient_form_shell.dart lib/features/patients/widgets/patient_form_validation_dialogs.dart lib/features/materials/widgets/material_form_dialog.dart lib/features/materials/widgets/material_detail_dialog.dart lib/features/purchases/widgets/purchase_detail_dialog.dart lib/features/settings/widgets/structure_check_result_dialog.dart`，0 issue。
- 2026-07-03：`windows_app` 运行 `flutter analyze lib/screens/home_screen.dart lib/screens/modern_dashboard_screen.dart lib/screens/patients_screen.dart lib/features/home/widgets/home_widgets.dart lib/features/patients/widgets/patient_screen_scaffold.dart lib/features/patients/widgets/patient_screen_body.dart lib/features/patients/widgets/patient_app_bar_title.dart lib/features/patients/widgets/patient_app_bar_actions.dart`，0 issue。
- 2026-07-03：`windows_app` 运行 `flutter analyze lib/screens/appointments_screen.dart lib/screens/financial_management_screen.dart lib/screens/purchase_records_screen.dart lib/screens/materials_screen.dart lib/screens/medical_management_screen.dart`，0 issue。
- 2026-07-03：`windows_app` 运行 `flutter analyze lib/features/dashboard/widgets/hoverable_stat_card.dart lib/features/materials/widgets/material_hoverable_cards.dart lib/features/materials/widgets/material_pagination.dart lib/features/materials/widgets/material_pagination_button.dart lib/features/patients/widgets/hoverable_patient_card.dart lib/features/patients/widgets/patient_pagination.dart lib/features/patients/widgets/patient_snack_bars.dart lib/features/purchases/widgets/hoverable_purchase_record_card.dart lib/features/purchases/widgets/pagination_widget.dart lib/features/purchases/widgets/purchase_hoverable_cards.dart lib/features/purchases/widgets/purchase_pagination.dart lib/features/financial/widgets/financial_hoverable_cards.dart lib/features/financial/widgets/financial_pagination.dart lib/widgets/success_toast.dart`，0 issue。
- 2026-07-02：`windows_app` 运行 `flutter analyze lib/widgets/dental_icons.dart lib/widgets/unified_search_field.dart lib/widgets/modern_date_picker.dart lib/widgets/reusable_date_range_picker.dart lib/widgets/success_toast.dart`，0 issue。
- 2026-07-02：`windows_app` 运行 `flutter analyze`，0 issue；并确认 `AppThemeVisualFilter` 文件已删除、柔和灰运行链路退出。
- 2026-07-02：补充柔和灰代码移除文件级清单，明确设置入口、`MaterialApp.builder`、`settings_provider`、旧配置迁移、`greyTheme`、`AppThemeVisualFilter` 和页面 `isGreyTheme` 分支都必须退出运行链路；纯文档变更，未运行 Flutter 验证。
- 2026-07-02：更新主题治理文档边界：柔和灰不再作为目标主题，本轮不新增新主题视觉，只做标准主题架构收敛；纯文档变更，未运行 Flutter 验证。

## 阻塞

- 无。

## 说明

- 2026-07-04：阶段 5 完成后复核发现阶段 6/7 进度文档与代码真实状态不一致，已修正本进度文档。阶段 7 的 const 兼容性问题仍会在正式启动阶段 7 时存在，当前因阶段 6 未闭环而暂不处理。

## 待确认

- 无。

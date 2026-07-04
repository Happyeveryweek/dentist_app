# Windows 端主题迁移实施步骤

## 文档定位

本文件记录主题统一的分阶段实施步骤、每批验证方式、搜索检查和柔和灰/滤镜清理验证。

入口文档：[统一主题颜色风格改进方案总览](windows_app_theme_unification_overview_2026_07_02.md)

技术规则：[主题规则与令牌](windows_app_theme_tokens_and_rules_2026_07_02.md)

## 执行原则

- 每批控制在 3 到 8 个文件。
- 每批只做主题相关代码，不夹带业务逻辑重构。
- 每批完成后运行对应文件的 `flutter analyze`。
- 每批完成后检查标准主题视觉，并确认未重新引入柔和灰/滤镜运行链路。
- 每批完成后记录进度到 [迁移进度](windows_app_theme_migration_progress_2026_07_02.md)。
- 已迁移文件内不应留下普通主题视觉硬编码。

## 阶段 1：主题基础设施

目标：主题入口、token、`ThemeData` 全部集中。

步骤：

1. 只读检查当前主题入口。
2. 新建 `lib/theme/app_theme_tokens.dart`。
3. 实现 token 字段、`copyWith`、`lerp`、`standard()`。
4. 新建 `lib/theme/theme_context_extensions.dart`。
5. 把标准主题改为通过 token 构建。
6. 增加 `_buildColorScheme(tokens)`。
7. 增加 `_buildTheme(tokens)`，集中配置 `ThemeData` 覆盖清单。
8. 增加标准主题构建入口，例如 `AppTheme.standardTheme()`；未来新增主题时再扩展 `resolve(...)`。
9. 修改 `main.dart`，让 `MaterialApp.theme` 使用统一标准主题入口。
10. 从设置入口移除柔和灰主题。
11. 移除 `MaterialApp.builder` 中的 `AppThemeVisualFilter.grey(...)` 使用。
12. 废弃或清理 `AppTheme.greyTheme`、`ExtendedThemeMode.grey` 相关运行路径。
13. 明确本轮不新增新主题视觉，只做标准主题架构收敛。
14. 检查 `getThemeData(context)`，避免第二套主题选择逻辑。
15. 在 `windows_app/AGENTS.md` 中加入主题编码规则。

柔和灰代码移除清单：

1. `lib/features/settings/widgets/theme_section.dart`：移除“柔和灰”主题卡片和入口；如果本轮只剩标准主题，设置页不再提供主题切换控件，只保留必要的说明或直接隐藏主题选择区。
2. `lib/features/settings/widgets/theme_card.dart`：删除 `ExtendedThemeMode.grey` 分支；如果主题卡片只服务于柔和灰/标准两档切换，阶段 1 可先停止使用该组件，阶段 6 再按实际引用删除或改成未来主题通用卡片。
3. `lib/providers/settings_provider.dart`：移除 `ExtendedThemeMode.grey` 运行路径；历史保存值为 `grey` 时必须在加载阶段迁移回标准主题，不能因为枚举缩减导致读取越界或继续启用柔和灰。
4. `lib/features/settings/services/config_storage_service.dart`：停止把柔和灰作为默认或可选配置写入；如保留 `extendedThemeMode` 字段用于兼容旧数据，只能保存标准主题值。
5. `lib/main.dart`：移除 `MaterialApp.builder` 内的 `AppThemeVisualFilter.grey(...)` 包裹；移除 `getThemeData(context)` 中返回 `AppTheme.greyTheme` 的分支，主题入口统一回到标准主题。
6. `lib/theme/app_theme.dart`：停止暴露运行时会被使用的 `greyTheme`、`greyAccentColor`、`greyAccentSoft`、`greyBackground`；如果阶段 1 为降低风险暂时保留历史字段，必须确认没有任何 UI 或入口引用，阶段 6 再清理未使用代码。
7. `lib/theme/app_theme_visual_filter.dart`：移除所有引用后再删除文件；实际删除文件属于仓库红线操作，执行删除前需要按项目规则单独确认。
8. `lib/screens/home_screen.dart`：删除 `isGreyTheme` 判断和柔和灰专用渐变/颜色分支，改为从标准主题 token 或 `ThemeData` 读取。
9. `lib/screens/settings_screen.dart`、`lib/features/settings/widgets/settings_header_card.dart`、`about_section.dart`、`backup_info_display.dart`：删除通过 `theme.primaryColor == AppTheme.greyAccentColor` 判断柔和灰的逻辑，改为主题 token / `ColorScheme`。
10. `lib/widgets/dental_icons.dart`：删除 `isGreyTheme` 分支，按钮渐变、阴影和颜色全部由 token 或组件默认主题决定。
11. 新建的 `lib/theme/app_theme_tokens.dart` 只提供 `standard()`；本轮不得新增 `grey()`、`purple()` 或其他新视觉主题工厂。

历史配置迁移要求：

- 旧版本保存的 `extendedThemeMode == ExtendedThemeMode.grey.index` 必须被映射为标准主题。
- 映射后再次保存配置时，只写入标准主题值。
- 不允许为了兼容旧数据继续让 `ExtendedThemeMode.grey` 参与 UI 渲染或 `MaterialApp` 主题选择。
- 如果最终删除 `ExtendedThemeMode`，必须先确认 `themeMode`、`setThemeMode`、旧配置读取都不会因字段缺失或索引变化报错。

验收：

- `flutter analyze lib/theme lib/main.dart lib/providers/settings_provider.dart` 通过。
- `ThemeData.extensions` 包含 `AppThemeTokens`。
- `MaterialApp.builder` 不再承担主题选择职责，也不再套 `AppThemeVisualFilter`。
- 设置页不再显示柔和灰主题入口。
- 柔和灰搜索命中只允许出现在明确标注的历史兼容迁移代码中，且不得参与 UI 渲染链路。

## 阶段 2：公共组件主题化

目标：常用组件默认跟随主题，调用方不需要传背景、边框、渐变、主色。

优先处理：

- `DentalCard`
- `DentalGradientButton`
- `DentalStatusIndicator`
- `UnifiedSearchField`
- Toast / SnackBar
- 日期选择器
- 分页按钮
- hoverable card

验收：

- 公共组件默认样式不要求调用方传颜色。
- 保留的颜色参数有明确业务语义。

## 阶段 3：主框架和高频页面

推荐顺序：

1. `lib/main.dart`
2. `lib/screens/home_screen.dart`
3. `lib/screens/modern_dashboard_screen.dart`
4. `lib/screens/patients_screen.dart`
5. `lib/screens/appointments_screen.dart`
6. `lib/screens/financial_management_screen.dart`
7. `lib/screens/purchase_records_screen.dart`
8. `lib/screens/materials_screen.dart`
9. `lib/screens/medical_management_screen.dart`

验收：

- 主框架和已迁移页面均从标准主题 token / `ThemeData` 读取视觉参数。
- 已迁移页面不再直接使用普通主题视觉硬编码。
- 页面结构和业务交互不变。

## 阶段 4：弹窗、表单和详情页

推荐顺序：

1. Dialog 壳和公共弹窗区域。
2. 患者新增/编辑、患者详情、患者统计、材料图片弹窗。
3. 预约新增/编辑、患者选择、时间选择、预约详情。
4. 财务新增/编辑、收费项目编辑、财务详情、财务统计。
5. 采购新增/编辑、采购详情、材料选择、材料新增/编辑、材料详情。
6. 病历模板、疾病类型、数据源配置、备份日志、结构检查结果。

验收：

- 弹窗、表单、详情页不再出现大面积纯白或固定灰底。
- 输入框、下拉框、日期选择、按钮状态可读。

## 阶段 5：图表、统计页和特殊视觉控件

处理范围：

- 仪表盘图表和统计卡片。
- 患者统计弹窗。
- 财务统计弹窗。
- 采购统计弹窗。
- 牙位图和牙齿状态控件。
- 图片预览和材料图片区域。

验收：

- 图表系列色来自 `tokens.chartPalette`。
- 医学特殊颜色有集中定义或明确注释。
- 图片和头像不被错误污染。

## 阶段 6：清理旧系统和兜底滤镜

步骤：

1. 统计并分类剩余旧引用。
2. 逐批清理业务页面旧引用。
3. 删除或停止使用 `AppThemeVisualFilter`。
4. 清理柔和灰主题残留。
5. 清理紫色主题残留；本轮不把紫色或其他新视觉做成新主题。
6. 复核 `windows_app/AGENTS.md` 主题编码规则。
7. 更新 `ROADMAP.md` 和进度文档。

验收：

- 核心页面不依赖全局滤镜。
- 未来新增主题时只需要增加一套 `AppThemeTokens` 和主题入口。
- 允许保留的硬编码颜色有明确清单。
- `flutter analyze` 通过。

## 阶段 7：剩余颜色来源彻底并入统一主题系统

目标：让系统涉及的所有颜色来源最终统一收口到 `context.tokens`、`context.colors`、`Theme.of(context)` 和明确登记的语义色清单，彻底终止 `DentalColors` 在业务页面中的普通主题职责。

处理原则：

1. 不把 `DentalColors` 整体简单替换成另一组静态类。
2. 普通页面视觉必须迁移到主题 token / `ThemeData`。
3. 业务语义色必须分类登记，只允许保留“状态色 / 医学识别色 / 图表系列色”。
4. 一个文件内如果同时存在普通主题色和语义色，必须拆开处理，不能因为有语义色就整体保留 `DentalColors`。

推荐批次：

1. 预约详情链路
   范围：`appointment_details_screen.dart`、`appointment_details_summary_card.dart`、`appointment_details_patient_card.dart`、`appointment_details_treatment_section.dart`
   任务：移除 `DentalColors.primaryGradient`、`surface`、`divider`、`onSurface*` 等普通主题来源，统一改为主题 token；预约状态块中真正属于业务状态的 success / warning / info / error 再单独归入语义色。

2. 患者详情与病历详情链路
   范围：`patient_detail_scaffold.dart`、`patient_detail_overview_card.dart`、`patient_detail_medical_record_widgets.dart`、相关详情/摘要卡
   任务：把卡片底色、描边、标题、概览块、提示块、按钮底和渐变壳层全部收回到主题 token；保留项仅限经过确认的病历状态语义色。

3. 患者表单深层区块
   范围：`patient_form_sections.dart`、`patient_form_fields.dart`、`patient_form_dialog.dart`、`patient_search_bar.dart`
   任务：移除 `cardGradient`、`backgroundGradient`、固定 primary/info/success/error 容器色，把输入框、分组卡、错误提示、帮助提示和禁用态统一接入 `ThemeData` 与 token。

4. 医疗记录组件链路
   范围：`disease_selection_widget.dart`、`dental_disease_selection_widget.dart`、`allergy_selection_widget.dart`、`medical_template_edit_dialog.dart`、`medical_record_summary_item.dart`
   任务：把选择器、标签、筛选块、编辑弹窗和摘要项里的普通主题色退回主题系统；如过敏/疾病需要强调色，改为语义 token，而不是直接引用 `DentalColors`。

5. 材料与采购业务组件链路
   范围：`material_type_dropdown.dart`、`material_form_field.dart`、`material_dropdown_container.dart`、`purchase_stat_card.dart`、`stat_card.dart`
   任务：移除组件内部对 `DentalColors.primaryGradient`、`surface`、`onSurfaceVariant` 等普通主题来源的依赖，保证这些业务组件在未来新增主题时无需单独改色。

6. 剩余页面壳层与局部状态块复核
   范围：`purchase_records_screen.dart`、`materials_screen.dart`、`appointment_card.dart`、`appointment_filter_bar.dart`、`patient_list_item.dart`、`patient_info_row.dart`
   任务：区分普通主题颜色与少量业务语义色；普通主题颜色统一改造，局部状态颜色如有必要沉到 `tokens.status*` 或语义 token。

7. 允许例外清单建立
   范围：图表、性别、牙位、医学风险提示等少量确有业务含义的颜色
   任务：在规则文档或实现层建立“允许保留的语义色”清单，避免以后再次把普通页面视觉偷偷放回静态颜色类。

阶段 7 验收：

- `rg -n "DentalColors\\." lib/screens lib/features -g "*.dart"` 的剩余命中不再包含普通页面主题来源。
- 剩余 `DentalColors` 命中必须全部可归类为“图表系列色 / 医学语义色 / 状态语义色 / 待确认”。
- 业务页面、详情页、病历组件、表单组件和公共组件的背景、卡片、边框、标题、分割线、按钮、输入框、hover、selected、disabled 不再直接读取 `DentalColors`。
- 新增主题时，不需要再进入业务页面替换 `DentalColors`。
- 完成后运行 `flutter analyze` 并更新进度文档与 `ROADMAP.md`。

## 搜索验证清单

每批迁移后执行基础检查：

```powershell
rg -n "Colors\.white|Colors\.grey\.shade50|Colors\.grey\.shade100|DentalColors\.primaryGradient|AppTheme\.primaryGradient" lib
```

扩展检查：

```powershell
rg -n "Colors\.(blue|green|orange|red|black|black87)" lib
rg -n "Color\(0x" lib
rg -n "DentalColors\." lib
rg -n "DentalColors\." lib/screens lib/features -g "*.dart"
rg -n "AppTheme\.(primaryColor|cardBackground|primaryGradient|backgroundColor|dividerColor)" lib
rg -n "LinearGradient\(" lib
rg -n "Border\.all\(color:" lib
rg -n "BoxShadow\(.*color:" lib
rg -n "withValues\(alpha:" lib
```

检查结果处理：

- 每批必须记录命中数量变化。
- 命中数量没有下降时，必须说明原因。
- 剩余命中必须分类为“已允许例外 / 待迁移 / 待确认”。

## 柔和灰和滤镜清理验证

阶段 1 完成后检查柔和灰和滤镜是否退出运行链路：

```powershell
rg -n "ExtendedThemeMode\.grey|setExtendedThemeMode|greyTheme|greyAccent|greyBackground|AppThemeVisualFilter|ColorFiltered|柔和灰|灰色主题" lib
```

处理规则：

- 设置入口、`MaterialApp.builder`、页面运行链路中不得再命中柔和灰和滤镜。
- 如果为了兼容暂时保留类型、历史字段或旧配置迁移代码，必须确认没有被 UI 或运行链路调用，并在命中清单中标注“历史兼容”。
- 阶段 6 清理剩余历史字段和未使用代码。

# Windows 端主题迁移实际状态复核

## 文档定位

本文件只保留 2026-07-04 这次复核的最终有效结论，不再保留当天早期草稿、重复阶段判断和已失效的临时统计说明。

入口文档：[统一主题颜色风格改进方案总览](windows_app_theme_unification_overview_2026_07_02.md)

进度文档：[迁移进度](windows_app_theme_migration_progress_2026_07_02.md)

## 当前结论

- 阶段 1：完成
- 阶段 2：完成
- 阶段 3：完成
- 阶段 4：未完成
- 阶段 5：未完成
- 阶段 6：未完成
- 阶段 7：未开始，不应提前启动

当前执行边界已经从“页面壳层和高频入口”切换到“弹窗、表单、详情页和旧系统清理”。后续不应再回头把阶段 1 到阶段 3 重新当作主任务。

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

## 本次收尾摘要

2026-07-04 当天的后续收尾，最终有效信息压缩如下：

1. 第二轮到第四轮主要完成了阶段 2 / 阶段 3 的分页、hover card、用户组件和高频页面入口收口。
2. 第五轮完成了 `home_screen.dart`、`home_widgets.dart`、`unified_search_field.dart`、`reusable_date_range_picker.dart`、`purchase_records_screen.dart`、`financial_management_screen.dart`、`data_source_screen.dart` 的进一步清理。
3. 第六轮完成了 `materials_screen.dart`、`login_screen.dart`、`app_info_screen.dart` 和 `compact_material_action_button.dart` 的最后收口，并据此把阶段 1 到阶段 3 更新为完成。

## 已完成验证

- `flutter analyze lib/screens/settings_screen.dart lib/screens/medical_management_screen.dart lib/screens/filtered_patients_screen.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/features/materials/widgets/material_pagination_button.dart lib/features/users/widgets/permission_preview_dialog.dart lib/features/users/widgets/user_card.dart lib/screens/data_source_screen.dart lib/screens/financial_management_screen.dart lib/screens/login_screen.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/screens/home_screen.dart lib/features/home/widgets/home_widgets.dart lib/screens/app_info_screen.dart lib/widgets/unified_search_field.dart lib/widgets/reusable_date_range_picker.dart lib/screens/purchase_records_screen.dart lib/screens/financial_management_screen.dart lib/screens/data_source_screen.dart`
  - 结果：`No issues found!`
- `flutter analyze lib/screens/materials_screen.dart lib/screens/login_screen.dart lib/screens/app_info_screen.dart lib/features/materials/widgets/compact_material_action_button.dart`
  - 结果：`No issues found!`

## 后续执行顺序

1. 阶段 4：弹窗、表单、详情页迁移
   - 优先处理财务编辑/新增/患者选择弹窗
   - 再处理患者表单、病历详情、患者材料编辑
   - 再处理预约表单深层区块、材料详情/编辑、采购详情

2. 阶段 5：统计、图表、牙位和特殊控件
   - 先迁移患者/财务/采购统计弹窗
   - 再迁移饼图、折线图、牙位图和图片预览等特殊视觉

3. 阶段 6：旧系统清理
   - 移除所有 `isPurpleTheme` 分支和参数
   - 删除 `AppTheme.purple*` 常量
   - 清理剩余运行链路中的普通 `AppTheme.*` 入口

4. 阶段 7：最终颜色来源收口
   - 只在阶段 4 到阶段 6 完成后启动
   - 目标是清理剩余 `DentalColors` 普通主题职责和直接 `Colors.xxx` / `Color(0x...)` 入口

## 当前待办

- [ ] 阶段 4 第一批：财务编辑/新增/患者选择弹窗
- [ ] 阶段 4 第二批：患者表单、病历详情、患者材料编辑
- [ ] 阶段 4 第三批：预约表单深层区块、材料详情/编辑、采购详情
- [ ] 阶段 5：患者/财务/采购统计弹窗、图表、牙位图和特殊视觉控件
- [ ] 阶段 6：清理全部紫色分支、`AppTheme.purple*` 和剩余运行链路普通 `AppTheme.*`
- [ ] 阶段 7：建立允许例外清单，清理剩余 `DentalColors` 普通主题职责和直接颜色入口

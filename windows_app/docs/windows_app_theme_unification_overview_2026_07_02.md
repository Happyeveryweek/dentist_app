# Windows 端统一主题颜色风格改进方案总览

## 文档定位

这是 Windows 端主题统一治理的入口文档，只保留目标、判断标准、总体架构和文档索引。具体规则、实施步骤和进度拆分到独立文档，避免单个方案过长导致执行时难以定位。

原长文档 `windows_app_theme_unification_plan_2026_07_01.md` 作为历史草案保留；后续执行以本总览和下列拆分文档为准。

相关文档：

- [主题规则与令牌](windows_app_theme_tokens_and_rules_2026_07_02.md)
- [迁移实施步骤](windows_app_theme_migration_steps_2026_07_02.md)
- [迁移进度](windows_app_theme_migration_progress_2026_07_02.md)

## 背景

当前 Windows 端曾尝试增加“柔和灰”主题和全局视觉过滤，但它不是最终方向。新的目标是先去掉柔和灰主题，不新增任何新主题视觉，只把标准主题的架构收敛到统一 token 和 `ThemeData`。

主要原因不是某个页面颜色不够灰，而是主题体系没有真正统一：页面、公共组件、旧颜色类和 `ThemeData` 同时存在，很多颜色绕过了 Flutter 主题系统。

当前主要问题：

- 颜色来源分散：`Theme.of(context).colorScheme`、`AppTheme.xxx`、`DentalColors.xxx`、页面内 `Colors.xxx` 同时存在。
- `AppTheme` 职责过重：同时承担静态颜色、兼容字段、`ThemeData` 构建、按钮样式、输入框样式、渐变和卡片装饰。
- `DentalColors` 是旧设计系统入口：大量业务页面直接引用固定医疗蓝、青色、绿色、白色背景、固定渐变和固定状态色。
- 页面级硬编码颜色过多：`Colors.white`、`Colors.grey.shade50`、`DentalColors.primaryGradient`、`Color(0x...)` 分布广。
- 柔和灰主题当前依赖全局 `ColorFiltered` 兜底，后续应移除，不再作为产品主题保留。

## 核心目标

主题统一的成功标准不是“把现有页面逐个改成灰色”，而是“页面不再拥有具体颜色决策”。

具体颜色只允许集中存在于：

- `ThemeData`
- `AppThemeTokens`
- 少量经过确认的医学/图表语义色

最终目标：

- 当前只保留标准主题，主界面、卡片、弹窗、表单、按钮、搜索框、列表、图表都从统一主题层读取视觉参数。
- 系统涉及的所有颜色来源都必须最终接入统一主题系统；业务页面、详情页、病历组件、表单组件和公共组件不得再直接依赖独立旧颜色类作为主题来源。
- 后续新增主题时，只新增一套主题令牌和主题入口，不需要逐页修改。
- 后续新增页面时，只要使用统一组件和语义颜色，就自动适配所有主题。
- 改一个主题时，不需要每个模块、每个边框、每个按钮单独改。
- 不再依赖 `AppThemeVisualFilter` 或柔和灰主题兜底。

## 非目标

- 不在主题治理过程中重构业务流程、数据流、权限逻辑、数据库逻辑。
- 不为了主题统一顺手调整页面布局、字段、交互文案。
- 不把医学识别色、图表系列色、用户上传图片强行灰化。
- 不一次性全仓替换所有颜色。

## 目标架构

目标架构分四层：

1. `AppThemeTokens`
   定义业务语义颜色和视觉参数，例如页面背景、卡片背景、边框、hover、selected、disabled、状态色、图表色、阴影和圆角。

2. `ThemeData`
   覆盖 Flutter 原生组件主题，例如 `Dialog`、`InputDecoration`、`Button`、`NavigationRail`、`SnackBar`、`DataTable`、`ListTile`。

3. 主题上下文扩展
   统一通过 `context.tokens`、`context.colors`、`context.theme` 读取主题，不在业务页面判断主题类型。

4. 公共组件
   `DentalCard`、`DentalGradientButton`、`DentalStatusIndicator`、`UnifiedSearchField`、Toast、日期选择器、分页等组件内部读取主题，调用方不再传固定颜色。

## 主题入口原则

Windows 端主题治理后，当前产品只暴露标准主题：

- 柔和灰主题从设置入口移除。
- `AppThemeVisualFilter` 不再作为长期方案，迁移中应移除其使用。
- `ThemeMode` / `darkTheme` 只作为历史兼容或后续清理对象，不再作为 Windows 端主题切换主入口。
- `MaterialApp.theme` 应由统一主题构建入口提供标准主题。
- 未来新增主题时，再扩展主题枚举和 token 工厂；本轮不设计新主题视觉。

## 分阶段路线

1. 阶段 1：主题基础设施
   建立 `AppThemeTokens`、`theme_context_extensions.dart`、统一主题构建入口、完整 `ThemeData` 覆盖清单，移除柔和灰主题入口和滤镜使用，并补充 `windows_app/AGENTS.md` 主题编码规则。

2. 阶段 2：公共组件主题化
   改造高复用组件，默认从主题读取颜色，清理调用方固定颜色覆盖。

3. 阶段 3：主框架和高频页面迁移
   迁移主框架、首页、仪表盘、患者、预约、财务、采购、材料等高频页面。

4. 阶段 4：弹窗、表单和详情页迁移
   解决“主页面变灰，点进去又变亮”的问题。

5. 阶段 5：图表、统计页和特殊视觉控件
   迁移图表、统计弹窗、牙位图、图片预览等特殊视觉。

6. 阶段 6：清理旧系统和兜底滤镜
   清理旧颜色入口，复核 `AGENTS.md` 规则，确认没有柔和灰主题和滤镜残留。

7. 阶段 7：剩余颜色来源彻底并入统一主题系统
   清退 `DentalColors` 在业务页面和业务组件中的主题职责，把剩余业务 UI 的颜色入口统一收回到 `context.tokens`、`context.colors` 和 `ThemeData`；只保留经过确认的医学/图表语义色作为例外。

详细步骤见 [迁移实施步骤](windows_app_theme_migration_steps_2026_07_02.md)。

## 实施进度摘要

- 2026-07-02：阶段 1 已完成。已新增 `AppThemeTokens` 与 `theme_context_extensions.dart`，`AppTheme` 已改为通过标准 token 构建 `ThemeData`，`MaterialApp.builder` 的柔和灰滤镜链路已移除，设置页不再暴露柔和灰入口，历史 `extendedThemeMode == grey` 会在加载时迁回标准主题并仅保存标准值。
- 2026-07-02：`flutter analyze` 已通过，`AppThemeVisualFilter` 文件已删除，柔和灰运行链路已退出。
- 2026-07-03：阶段 6 第一批已启动。数据源页成功提示里的紫色分支，以及几处仅作兼容占位的 `isPurpleTheme` 参数已清理。
- 2026-07-04：阶段 5 已完成并通过针对性静态检查；阶段 5 范围内旧 `DentalColors`、`AppTheme.primaryGradient` / `AppTheme.primaryColor`、固定白底和普通主题硬编码边框已清零。
- 2026-07-04：复核发现阶段 6 尚未闭环。运行代码中仍存在 `isPurpleTheme` / `AppTheme.purple*` 紫色分支和大量普通 `AppTheme.*` 页面级入口。
- 2026-07-04：阶段 6 已完成。`AppTheme.purple*` 历史常量、`isPurpleTheme` 死分支和普通 `AppTheme.*` 页面级入口已全部清理；settings/patients/users/appointments/purchases 等 35+ 个文件已统一接入 `context.tokens` / `context.colors`。全量 `flutter analyze` 0 error、0 warning，仅剩 14 个 info 级别 `prefer_const` 提示（均为预先存在）。运行链路中仅保留 `AppTheme.standardTheme()`、`AppTheme.smallBorderRadius` 和 `AppTheme.dangerGradient`。
- 2026-07-04：阶段 7 仍为“未开始”。`DentalColors` 在 `lib/screens` / `lib/features` 多处业务页面中仍承担普通主题职责，直接 `Colors.xxx` / `Color(0x...)` 入口也仍大量存在；阶段 7 需在阶段 6 闭环后启动，目标仍是让系统涉及的所有颜色来源最终并入统一主题系统。
- 2026-07-05：阶段 7 已启动当前批次。`dental_treatment.dart`、`appointment_form_dialog.dart`、`material_detail_manager.dart` 的头部渐变、卡片/页面背景、边框、阴影、按钮、图标/文字等普通主题色已接入 `context.tokens` / `context.colors`；语义状态色（成功绿、警告橙、错误红）与 `Colors.transparent` 保留；直接颜色命中从 1247 降到 1196，针对性 `flutter analyze` 0 issue。
- 后续执行以 [迁移进度](windows_app_theme_migration_progress_2026_07_02.md) 为实时进度源，本总览只保留关键里程碑摘要。

## 最终验收

主题系统改造完成后必须满足：

- 当前只保留标准主题入口。
- 主页面、列表页、详情页、弹窗、表单、Toast、Dialog 均从统一主题层读取视觉参数。
- 背景、卡片、边框、分割线、hover、selected、disabled、阴影、图表色都有集中 token 或 `ThemeData` 定义。
- `AppThemeVisualFilter` 和柔和灰设置入口已移除。
- `DentalColors` 不再作为业务页面主题颜色来源。
- 业务页面、病历/详情组件、表单组件和公共组件不再直接把 `DentalColors` 当作普通主题颜色源；允许保留的仅是集中定义并经过确认的医学语义色、状态语义色和图表系列色。
- 新增第三套主题时，只需要新增 `AppThemeTokens.xxx()` 和主题入口，不需要改业务页面。
- `flutter analyze` 通过。

## 当前状态

当前正式主题统一治理的阶段 1 至阶段 6 已完成，阶段 7 已启动并处理当前批次。

阶段 6 已清理旧主题系统遗留入口：`AppTheme.purple*` 历史常量、`isPurpleTheme` 死分支和普通 `AppTheme.*` 页面级入口已全部清理，运行链路中仅保留 `AppTheme.standardTheme()`（标准主题构建入口）、`AppTheme.smallBorderRadius`（布局常量）和 `AppTheme.dangerGradient`（语义渐变）。

阶段 7 的目标是把剩余所有未并入统一主题系统的颜色来源彻底收口。当前批次已将 `dental_treatment.dart`、`appointment_form_dialog.dart`、`material_detail_manager.dart` 的普通主题色入口接入 `context.tokens` / `context.colors`，直接颜色命中从 1247 降至 1196；剩余 `DentalColors` 与普通 `Colors.xxx` / `Color(0x...)` 命中仍按语义例外/普通主题分批处理。

阶段 7 主要覆盖：

- 预约详情页及其摘要/患者/治疗区块。
- 患者详情、病历摘要、病历列表和患者表单深层区块。
- 病历模板、疾病/过敏/牙病选择等医疗记录组件。
- 材料下拉、材料表单字段、采购统计卡、列表局部状态块等业务组件。
- 仅用于业务语义的少量颜色命中复核，区分“允许保留的语义色”与“必须退出的普通主题来源”。
- 仍绕过统一主题入口的 `Colors.xxx` / `Color(0x...)` 直接命中治理，当前重点已进一步收敛到财务编辑、材料页、预约时间/治疗区块、材料调试与病历初始化等高密度组件。

实时进度见 [迁移进度](windows_app_theme_migration_progress_2026_07_02.md)。

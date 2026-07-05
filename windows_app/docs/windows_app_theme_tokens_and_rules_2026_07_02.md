# Windows 端主题规则与令牌

## 文档定位

本文件记录主题统一的技术规则，包括 `AppThemeTokens` 字段、`ThemeData` 覆盖清单、颜色替换规则、旧颜色入口退场规则和新增代码规则。

入口文档：[统一主题颜色风格改进方案总览](windows_app_theme_unification_overview_2026_07_02.md)

## 主题统一硬边界

- 页面不决定具体颜色，只表达“这是背景、卡片、边框、提示、状态、图表、遮罩”。
- 公共组件默认样式必须从 `ThemeData` 或 `AppThemeTokens` 读取。
- 普通业务页面不得通过 `if (isGreyTheme)`、`if (themeMode == ...)` 分支决定颜色。
- 本轮不新增新主题视觉，只保留标准主题。
- 未来新增主题时，只允许新增 token 和主题构建入口，不允许逐页改颜色。
- 柔和灰主题和 `AppThemeVisualFilter` 不再作为产品目标，应从入口和运行链路移除。

允许页面直接写的颜色：

- `Colors.transparent`。
- 明确遮罩色，但优先使用 `context.tokens.overlayScrim`。
- 深色背景上的反色文字或图标，但优先使用 `colorScheme.onPrimary`、`colorScheme.onError`。
- 图片预览、头像裁剪、用户上传内容等非主题视觉。
- 经过确认的医学/患者识别色，统一使用 `MedicalSemanticColors`；禁止在业务页面新写 `Colors.blue` / `Colors.green` / `Colors.orange` / `Colors.grey` / `Color(0xFF009688)` 或引用 `DentalColors.femalePink` / `maleBlue`。

禁止页面直接写的颜色：

- 页面背景、主内容背景。
- 卡片背景、弹窗背景、表单 section 背景。
- 普通边框、分割线、阴影。
- 普通主按钮、次按钮、hover、selected、disabled 状态。
- 普通图标强调色。
- 装饰性蓝绿渐变。
- 普通图表系列色。

硬编码颜色保留判断：

1. 它是不是业务语义色，而不是主题视觉色？
2. 未来新增主题时，它是否仍然应该保持不变？

两个答案都成立，才允许保留。

## AppThemeTokens

第一阶段建议一次性补齐常用语义，避免后续每遇到一个边框、hover、图表再临时加字段。

建议字段：

```dart
class AppThemeTokens extends ThemeExtension<AppThemeTokens> {
  final Color pageBackground;
  final Color shellBackground;
  final Color panelBackground;
  final Color cardBackground;
  final Color elevatedCardBackground;
  final Color mutedBackground;
  final Color inputBackground;

  final Color border;
  final Color divider;
  final Color shadow;
  final Color focusRing;

  final Color primaryAccent;
  final Color secondaryAccent;
  final Color dangerAccent;
  final Color warningAccent;
  final Color iconMuted;

  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  final Color successContainer;
  final Color warningContainer;
  final Color errorContainer;
  final Color infoContainer;

  final Color hoverBackground;
  final Color selectedBackground;
  final Color disabledBackground;
  final Color disabledText;

  final Color tableHeaderBackground;
  final Color listItemHoverBackground;
  final Color overlayScrim;

  final LinearGradient primaryHeaderGradient;
  final LinearGradient subtleHeaderGradient;

  final List<Color> chartPalette;

  final List<BoxShadow> cardShadow;
  final List<BoxShadow> elevatedShadow;

  final double borderRadius;
  final double smallBorderRadius;
  final double cardElevation;
}
```

实现要求：

- 必须实现 `copyWith`、`lerp`。
- 标准主题 token 尽量映射现有视觉，减少第一批视觉变化。
- 本轮只实现标准主题 token，不设计新主题视觉。
- 未来新增主题时，新增独立 token 工厂，不在页面里加主题判断。
- token 命名必须表达语义，不用 `grey1`、`blue2` 这类具体色名。

## ThemeData 覆盖清单

第一阶段应覆盖：

- `scaffoldBackgroundColor`
- `canvasColor`
- `cardColor`
- `dividerColor`
- `colorScheme`
- `textTheme`
- `appBarTheme`
- `navigationRailTheme`
- `cardTheme`
- `dialogTheme`
- `inputDecorationTheme`
- `elevatedButtonTheme`
- `outlinedButtonTheme`
- `textButtonTheme`
- `iconButtonTheme`
- `checkboxTheme`
- `switchTheme`
- `radioTheme`
- `dividerTheme`
- `listTileTheme`
- `popupMenuTheme`
- `dropdownMenuTheme`
- `menuTheme`
- `tooltipTheme`
- `snackBarTheme`
- `dataTableTheme`
- `progressIndicatorTheme`

## 统一主题入口

Windows 端主题治理后，当前产品只保留标准主题入口。`ThemeMode` / `darkTheme` / `ExtendedThemeMode.grey` 只作为历史兼容或清理对象，不再作为本轮产品主题目标。

建议新增：

```dart
class AppTheme {
  static ThemeData standardTheme() {
    final tokens = AppThemeTokens.standard();
    return _buildTheme(tokens);
  }
}
```

`MaterialApp.theme` 应由统一主题构建入口提供标准主题。未来新增主题时，再增加主题枚举、token 工厂和 `resolve(...)` 分支。

执行要求：

- 从设置入口移除柔和灰主题。
- 移除 `MaterialApp.builder` 中的 `AppThemeVisualFilter.grey(...)` 使用。
- 移除或废弃 `AppTheme.greyTheme`，除非短期为了兼容保留但不再被调用。
- 不新增替代主题视觉；本轮只完成标准主题 token 化和架构收敛。

## 颜色替换规则

- 页面背景：用 `Theme.of(context).scaffoldBackgroundColor` 或 `context.tokens.pageBackground`。
- 卡片背景：用 `context.tokens.cardBackground`。
- 次级背景：用 `context.tokens.mutedBackground`。
- 输入框背景：优先用 `Theme.of(context).inputDecorationTheme`。
- 边框和分割线：用 `context.tokens.border`、`context.tokens.divider`。
- 主强调色：用 `Theme.of(context).colorScheme.primary`、`context.tokens.primaryAccent`。
- 渐变：用 `context.tokens.primaryHeaderGradient`、`context.tokens.subtleHeaderGradient`。
- 文本：用 `colorScheme.onSurface`、`colorScheme.onSurfaceVariant`。
- 状态色：用 `context.tokens.success/warning/error/info`。
- 图表色：用 `context.tokens.chartPalette`。

## DentalColors 退场规则

长期目标不是让 `DentalColors` 换成另一套灰色常量，而是让业务页面不再依赖它。

处理方式：

1. 第一阶段保留 `DentalColors`，避免大范围编译破坏。
2. 第二阶段公共组件内部逐步改为读取 `context.tokens`。
3. 第三到第五阶段业务页面不再新增 `DentalColors` 引用。
4. 第六阶段统计剩余引用并分类处理。

柔和灰相关颜色和渐变不迁移成新主题，应随柔和灰入口一起清理；如果某些颜色仍服务于标准主题视觉，必须改名为标准主题语义 token。

禁止把 `DentalColors` 改成需要 `BuildContext` 的动态类。需要上下文的颜色应该通过 `context.tokens` 获取。

## 公共组件颜色参数规则

- 默认样式必须来自 `context.tokens` 或 `Theme.of(context)`。
- `color`、`backgroundColor`、`borderColor`、`gradient` 等参数只允许作为明确业务语义例外。
- 如果调用方传入的是固定品牌色、白色、灰底、蓝绿渐变，应迁移到 token。
- 改造组件时必须同步检查调用点。

## 阶段 7 允许例外清单

以下颜色来源不强制迁移到 `context.tokens` / `context.colors`，但新增代码应优先使用对应 token：

- `Colors.transparent`：明确用于透明背景、裁切、隐藏占位等场景。
- `DentalColors.femalePink` / `DentalColors.maleBlue`：患者性别识别色，属于业务语义色。
- 牙齿、牙龈、牙位、疾病类型、过敏等医学识别色：属于业务语义，允许保留固定色值。
- 图表系列色：必须使用 `context.tokens.chartPalette`，不允许在业务页面散落固定色板。
- 图片 / 头像 / 上传素材 / 媒体预览遮罩：优先使用 `context.tokens.overlayScrim`；若必须使用固定黑色遮罩，需在本清单登记原因。
- PDF/导出/打印等需要固定色值的输出场景：允许保留固定色值，但应尽量与主题 token 对齐。

## windows_app/AGENTS.md 规则

阶段 1 完成时建议加入；阶段 6 再复核并补充允许例外：

- 新 UI 不允许直接使用 `Colors.white` 作为页面、卡片、弹窗背景。
- 新 UI 不允许直接使用 `Colors.grey.shade50` / `Colors.grey.shade100` 作为次级背景。
- 新 UI 不允许直接使用 `Color(0x...)` 表达页面背景、卡片、边框、按钮、hover、selected、disabled 等主题视觉。
- 新 UI 不允许直接使用 `DentalColors.primaryGradient`。
- 新 UI 不允许在业务页面中直接使用 `Colors.blue`、`Colors.green`、`Colors.orange` 表示普通强调色。
- 新 UI 不允许直接使用 `BoxShadow(color: Colors.black.withValues(...))`，应使用 `context.tokens.cardShadow` 或 `elevatedShadow`。
- 新 UI 不允许直接使用 `LinearGradient` 表达品牌装饰渐变，应使用 token 渐变。
- 状态色必须使用主题令牌：`success`、`warning`、`error`、`info`。
- 页面级容器必须优先使用 `Theme.of(context)` 或 `context.tokens`。
- 公共组件必须在组件内部读取主题，不应要求调用方传固定颜色。
- `DentalColors` 只允许用于历史兼容、医学识别色、头像/图片兜底等明确例外，不允许作为业务页面主题颜色入口。
- 本轮不新增新主题视觉；未来新增主题时只能新增 token 和主题构建器，不允许在页面里增加主题判断分支。

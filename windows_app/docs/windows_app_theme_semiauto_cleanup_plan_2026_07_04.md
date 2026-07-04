# Windows 端主题迁移半自动清理执行方案

## 文档定位

本文件记录如何用脚本快速处理主题迁移中有共性的残留问题。执行基准仍是 [实际状态复核](windows_app_theme_migration_actual_status_2026_07_04.md)，本文件只定义“哪些可以半自动做、哪些必须人工审查”。

配套脚本：

```powershell
python scripts/theme_migration_assistant.py --scan
```

## 当前问题规模

以 2026-07-04 复核为准：

| 类型 | 当前数量 | 自动化策略 |
| --- | ---: | --- |
| `isPurpleTheme` | 62 | 优先半自动处理。先折叠不可达判断，再人工清理死分支。 |
| `AppTheme.*` | 357 | 只处理明确 token 映射；复杂 const、静态字段、语义色先跳过。 |
| `DentalColors.*` | 480 | 只处理普通主题色候选；状态色、性别色、医学色、图表色必须人工分类。 |
| 直接 `Colors.xxx` / `Color(0x...)` | 2257 | 先生成报表，不直接批量替换。 |

## 核心原则

- 脚本只处理可证明一致的模式。
- 默认只扫描和 dry-run，不直接改代码。
- `--write` 才允许落盘修改。
- 每批最多处理 5 到 10 个文件。
- 每批完成后运行对应文件的 `flutter analyze`。
- 任何导致 const 上下文变成动态 `context.tokens` 的替换都必须跳过。
- 任何涉及业务语义色、医学识别色、图表色、反色文字、图片/头像视觉的命中都不自动改。

## 脚本能力

### 1. 扫描统计

命令：

```powershell
python scripts/theme_migration_assistant.py --scan
```

输出：

- 全局计数：`context.tokens`、`AppTheme.*`、`DentalColors.*`、直接颜色、紫色残留。
- 按文件排序的高密度文件。
- 可半自动处理候选数量。
- 必须人工处理候选数量。

生成 Markdown 报告：

```powershell
python scripts/theme_migration_assistant.py --scan --report docs/theme_migration_semiauto_report.md
```

### 2. 安全 dry-run

命令：

```powershell
python scripts/theme_migration_assistant.py --apply-safe
```

默认不会写文件，只列出会修改的文件、替换类型和命中数量。

### 3. 写入安全替换

命令：

```powershell
python scripts/theme_migration_assistant.py --apply-safe --write --only lib/screens/materials_screen.dart lib/screens/purchase_records_screen.dart
```

只允许在指定文件或指定范围内执行，避免一次性全仓改动。

## 当前允许自动处理的内容

### 紫色主题不可达判断

允许自动把以下判断折叠为 `false`：

```dart
Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground
```

理由：

- 当前只保留标准主题入口。
- `AppTheme.purpleBackground` 已不可能成为运行时 `scaffoldBackgroundColor`。
- 折叠为 `false` 不引入新 token，也不会触发 const 问题。

注意：

- 这一步只降低运行分支复杂度。
- 死分支中的 `AppTheme.purple*` 常量引用仍需后续人工或更严格脚本清理。

### 明确 AppTheme 到 token 的映射

仅在文件已使用 `context.tokens` 或 `context.colors` 时，脚本才允许候选替换：

| 旧入口 | 候选替换 |
| --- | --- |
| `AppTheme.primaryColor` | `context.tokens.primaryAccent` |
| `AppTheme.secondaryColor` | `context.tokens.secondaryAccent` |
| `AppTheme.accentColor` | `context.tokens.info` |
| `AppTheme.successColor` | `context.tokens.success` |
| `AppTheme.warningColor` | `context.tokens.warning` |
| `AppTheme.errorColor` | `context.tokens.error` |
| `AppTheme.infoColor` | `context.tokens.info` |
| `AppTheme.primaryGradient` | `context.tokens.primaryHeaderGradient` |
| `AppTheme.cardBackground` | `context.tokens.cardBackground` |
| `AppTheme.backgroundColor` | `context.tokens.pageBackground` |
| `AppTheme.dividerColor` | `context.tokens.divider` |
| `AppTheme.primaryText` | `context.colors.onSurface` |
| `AppTheme.secondaryText` | `context.colors.onSurfaceVariant` |
| `AppTheme.lightText` | `context.tokens.textMuted` |

跳过条件：

- 当前行包含 `const`。
- 文件没有 `context.tokens` / `context.colors`。
- 文件没有 `BuildContext context`。
- 命中位于静态字段、顶层常量、Map 字面量配置中。

### 明确 DentalColors 普通主题色映射

仅处理普通主题职责，不处理业务语义色：

| 旧入口 | 候选替换 |
| --- | --- |
| `DentalColors.primaryGradient` | `context.tokens.primaryHeaderGradient` |
| `DentalColors.cardGradient` | `context.tokens.subtleHeaderGradient` |
| `DentalColors.background` | `context.tokens.pageBackground` |
| `DentalColors.surface` | `context.tokens.cardBackground` |
| `DentalColors.divider` | `context.tokens.divider` |
| `DentalColors.onSurface` | `context.colors.onSurface` |
| `DentalColors.onSurfaceVariant` | `context.colors.onSurfaceVariant` |

不自动处理：

- `DentalColors.success`
- `DentalColors.warning`
- `DentalColors.error`
- `DentalColors.info`
- `DentalColors.maleBlue`
- `DentalColors.femalePink`
- 图表调色板
- 牙位、牙龈、医学状态颜色

## 直接颜色的处理方式

`Colors.white`、`Colors.grey`、`Colors.blue`、`Color(0x...)` 暂不自动替换，只生成分类报表。

原因：

- `Colors.white` 可能是卡片背景，也可能是深色按钮文字。
- `Colors.red` 可能是错误状态，也可能是普通强调色。
- `Color(0x...)` 可能是品牌渐变，也可能是性别色、牙位色、图表色。

脚本只输出：

- 高密度文件列表。
- 行号和原始行。
- 根据上下文关键词做粗分类：背景、边框、文字、状态、图表、图片/头像、待确认。

## 推荐执行顺序

### 批次 1：紫色主题死判断折叠

目标：

- 降低 `isPurpleTheme` 链路复杂度。
- 为后续删除 `AppTheme.purple*` 常量做准备。

命令：

```powershell
python scripts/theme_migration_assistant.py --apply-safe --write --only `
  lib/screens/materials_screen.dart `
  lib/screens/purchase_records_screen.dart `
  lib/screens/data_source_screen.dart `
  lib/features/patients/widgets/patient_card.dart `
  lib/features/patients/widgets/patient_filter_bar.dart `
  lib/features/patients/widgets/patient_list_item.dart
```

验证：

```powershell
flutter analyze lib/screens/materials_screen.dart lib/screens/purchase_records_screen.dart lib/screens/data_source_screen.dart lib/features/patients/widgets/patient_card.dart lib/features/patients/widgets/patient_filter_bar.dart lib/features/patients/widgets/patient_list_item.dart
```

### 批次 2：公共组件明确 AppTheme 映射

目标：

- 处理分页、hover card、用户组件、患者工具组件中的明确 token 映射。

建议范围：

- `lib/features/patients/widgets/patient_pagination.dart`
- `lib/features/financial/widgets/financial_pagination.dart`
- `lib/features/patients/widgets/hoverable_patient_card.dart`
- `lib/features/purchases/widgets/purchase_hoverable_cards.dart`
- `lib/features/materials/widgets/material_hoverable_cards.dart`

### 批次 3：主页面明确 AppTheme 映射

目标：

- 阶段 3 收尾的一部分。

建议范围：

- `lib/screens/settings_screen.dart`
- `lib/screens/filtered_patients_screen.dart`
- `lib/screens/materials_screen.dart`
- `lib/screens/purchase_records_screen.dart`
- `lib/screens/financial_management_screen.dart`

### 批次 4：DentalColors 普通主题色候选

目标：

- 先处理 `primaryGradient`、`surface`、`background`、`divider`、`onSurface`、`onSurfaceVariant`。

建议范围：

- 患者表单
- 预约详情
- 病历详情
- 材料/采购业务小组件

### 批次 5：直接颜色报表驱动人工处理

目标：

- 不再脚本替换，改为按报表逐文件处理。

优先文件：

- `financial_form_dialog.dart`
- `financial_record_edit_dialog.dart`
- `edit_financial_item_dialog.dart`
- `database_check_widgets.dart`
- `data_source_type_switch_section.dart`
- `materials_screen.dart`
- `login_screen.dart`

## 每批完成后的记录要求

每批必须更新：

- [实际状态复核](windows_app_theme_migration_actual_status_2026_07_04.md)
- `ROADMAP.md`

记录内容：

- 本批处理文件。
- 替换前后统计。
- 剩余无法自动处理的原因。
- `flutter analyze` 结果；如果 Flutter 工具链失败，记录具体错误，不标记完成。

## 风险边界

脚本不得自动做以下事项：

- 删除文件。
- 删除 `AppTheme.purple*` 常量。
- 删除 `isPurpleTheme` 变量、参数或 widget 字段。
- 修改 `darkTheme`。
- 修改 `.env`、CI/CD、数据库 schema、数据迁移。
- 全仓直接替换 `Colors.white` 或 `Color(0x...)`。

这些事项必须在代码迁移和验证后人工处理。

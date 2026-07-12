# Windows 端无用代码清理执行计划

## 0. 文档定位

- 本计划是 [windows_app_dead_code_and_duplicate_implementation_audit_2026_07_12.md](./windows_app_dead_code_and_duplicate_implementation_audit_2026_07_12.md) 的可执行落地文档，严格按照该审核报告第 6 节五批清理方案拆解。
- 审核报告负责“证据与判定”，本计划负责“执行步骤、复核命令、回归用例和提交规范”。
- 本计划只覆盖审核报告已列为 A/B 级的 39 个候选文件；C 级不进入本轮清理。
- 所有路径均以 `windows_app/` 为根目录的相对路径书写，命令默认在 `windows_app/` 下执行。
- 行号取自审核日期 2026-07-12 的静态扫描结果，仅作规模参考；执行时以实际文件为准重新统计。

## 1. 总体执行原则

1. 每批开始前先执行 `git status --short`；工作区不干净时只处理本计划列出的文件，不覆盖用户改动。
2. 每个候选文件删除前必须再次执行精确 `import` 路径搜索和顶层符号搜索；若发现新增引用，立即停止删除该文件并回写本计划与审核报告。
3. 删除属于项目红线：每批必须先得到用户对该批文件清单的明确删除授权，再动手。
4. 每批只删除已确认文件及由该批产生的孤儿导入；不顺手重构、不迁移现用代码、不补新功能。
5. 不以“保留兼容层更安全”为由保留已确认无调用的旧路径，避免继续形成双实现。
6. 每批独立提交，提交信息使用中文并准确写明模块和批次。
7. 命令执行环境为 Windows PowerShell，Flutter 命令使用 `flutter ...`；命令默认在 `windows_app/` 目录运行。
8. 纯删除批次无需运行 `dart format`；仅当本批仍修改了 Dart 文件时才定向格式化改动文件。

## 2. 全局前置准备

- 确认当前分支干净并已拉取最新：`git status --short` 应为空。
- 确认 `windows_app/` 下 `flutter analyze` 基线为 `No issues found!`；若已有 issue，先记录基线，避免把历史问题计入本轮。
- 确认测试基线：`flutter test` 记录通过/失败数，作为各批对比起点。
- 准备好手动回归环境：可运行 Windows 应用（`flutter run -d windows`，仅在用户明确要求时启动），并准备可用的 SQLite/MySQL 数据源与测试患者、财务、采购、材料数据。

## 3. 第一批：低风险、明确替代

### 3.1 目标

删除预约旧四组件、旧时间格式工具、备份路径旧组件、采购导出兼容壳、普通孤立小组件和占位文件。预计清理约 1700 行。

### 3.2 删除文件清单

预约旧四组件（A，608 行）：

- `lib/features/appointments/widgets/cost_status_section.dart`（112 行，`CostStatusSection`）
- `lib/features/appointments/widgets/date_time_section.dart`（128 行，`DateTimeSection`）
- `lib/features/appointments/widgets/notes_section.dart`（73 行，`NotesSection`）
- `lib/features/appointments/widgets/treatment_section.dart`（295 行，`TreatmentSection`）

旧时间格式工具（A，21 行）：

- `lib/utils/date_time_formatter.dart`（`DateTimeFormatter`，注意保留文件名少一个下划线的 `lib/utils/datetime_formatter.dart`）

备份路径旧组件（A，142 行）：

- `lib/features/settings/widgets/backup_path_input.dart`（68 行）
- `lib/features/settings/widgets/backup_path_selector.dart`（74 行）

采购导出兼容壳（A，31 行）：

- `lib/features/purchases/widgets/purchase_export_service.dart`（保留 `lib/services/purchase_export_service.dart` 与 `purchase_export_dialog.dart`）

采购未接入拆分组件（A/B，420 行）：

- `lib/features/purchases/widgets/hoverable_purchase_record_card.dart`（51 行）
- `lib/features/purchases/widgets/purchase_hoverable_cards.dart`（50 行）
- `lib/features/purchases/widgets/purchase_compact_action_button.dart`（46 行）
- `lib/features/purchases/widgets/purchase_detail_item_card.dart`（94 行）
- `lib/features/purchases/widgets/purchase_pagination.dart`（134 行）
- `lib/features/purchases/widgets/purchase_stat_item.dart`（45 行）

财务辅助孤立组件（A，111 行）：

- `lib/features/financial/helpers/financial_pagination_update_helper.dart`（55 行，`FinancialPaginationUpdateHelper`、`PaginationResult`；实际路径在 `helpers/` 而非 `widgets/`）
- `lib/features/financial/widgets/financial_compact_info_item.dart`（56 行，`FinancialCompactInfoItem`）

设置页孤立组件（A，71 行）：

- `lib/features/settings/widgets/settings_card.dart`（71 行）

占位文件（A，1 行）：

- `lib/test/appointment_form_dialog.dart`（1 行，位于生产源码 `lib/test/`，非 Flutter `test/` 目录；删除后若 `lib/test/` 为空，需再次向用户确认是否删除空目录）

### 3.3 执行前复核命令

```powershell
# 1. 确认工作区干净
git status --short

# 2. 逐个符号/路径搜索，期望仅命中候选定义文件
rg -n "cost_status_section|CostStatusSection" lib test
rg -n "date_time_section|DateTimeSection" lib test
rg -n "notes_section|NotesSection" lib test
rg -n "treatment_section|TreatmentSection" lib test
rg -n "utils/date_time_formatter" lib test
rg -n "backup_path_input|backup_path_selector" lib test
rg -n "features/purchases/widgets/purchase_export_service" lib test
rg -n "hoverable_purchase_record_card|purchase_hoverable_cards|HoverablePurchaseRecordCard" lib test
rg -n "purchase_compact_action_button|purchase_detail_item_card|purchase_pagination|purchase_stat_item" lib test
rg -n "financial_pagination_update_helper|FinancialPaginationUpdateHelper|financial_compact_info_item|FinancialCompactInfoItem" lib test
rg -n "settings_card" lib test
rg -n "lib/test/appointment_form_dialog" lib test
```

### 3.4 删除后验证命令

```powershell
# 纯删除批次无需 dart format；若未改动其他 Dart 文件则跳过
flutter analyze
flutter test
git diff --check
git status --short
```

### 3.5 手动回归用例

- 预约：新增预约、编辑预约，确认表单各分段（日期/时间、治疗项目、费用状态、备注）正常显示与保存。
- 采购：采购记录列表打开、详情查看、导出（Excel/CSV）正常；分页与卡片交互仍由页面内实现承担。
- 设置：备份主路径/备路径选择、手动输入路径、清空路径、重启后持久化。
- 财务：列表分页加载、详情页紧凑信息区域显示正常。

### 3.6 提交规范

- 提交信息示例：`清理预约/采购/设置/财务模块无用组件与重复实现（第一批）`
- 在提交说明中列出本批删除的文件分类和总行数。

## 4. 第二批：财务旧实现

### 4.1 目标

删除财务旧编辑弹窗、旧统计对话框、旧统计组件。预计清理约 1718 行。

### 4.2 删除文件清单

- `lib/features/financial/widgets/edit_financial_item_dialog.dart`（891 行，`EditFinancialItemDialog`，B 级）
- `lib/features/financial/widgets/financial_statistics_dialog_widget.dart`（631 行，旧 `FinancialStatisticsDialog`，A 级）
- `lib/features/financial/widgets/financial_stats_section.dart`（96 行，`FinancialStatsSection`，A 级）

### 4.3 执行前复核命令

```powershell
git status --short
rg -n "edit_financial_item_dialog|EditFinancialItemDialog" lib test
rg -n "financial_statistics_dialog_widget|FinancialStatisticsDialog" lib test
rg -n "financial_stats_section|FinancialStatsSection" lib test
# 确认现用路径仍存在
rg -n "FinancialStatsDialog" lib
rg -n "financial_record_edit_dialog|financial_detail_editing_item_row" lib
```

期望：三个候选符号只命中各自定义文件；现用 `FinancialStatsDialog` 仍被 `financial_management_screen.dart` 实例化。

### 4.4 删除后验证命令

```powershell
flutter analyze
flutter test
git diff --check
git status --short
```

### 4.5 手动回归用例

- 新增财务记录：打开新增弹窗、填写治疗项目/费用/支付方式、保存成功。
- 编辑财务记录：从列表进入编辑、修改字段、保存成功。
- 编辑收费明细：在财务详情页编辑明细项、保存成功。
- 财务统计：打开统计入口、切换日期范围、刷新、切换金额隐藏/显示，结果与删除前一致。

### 4.6 提交规范

- 提交信息示例：`清理财务模块旧编辑弹窗与旧统计组件（第二批）`

## 5. 第三批：采购旧统计子图

### 5.1 目标

删除采购旧图表及其依赖的统计卡片。预计清理约 612 行。

### 5.2 删除文件清单

- `lib/features/purchases/widgets/purchase_statistics_chart.dart`（531 行，`PurchaseStatisticsChart`，B 级）
- `lib/features/purchases/widgets/purchase_stat_card.dart`（81 行，只被旧图表导入，B 级）

### 5.3 执行前复核命令

```powershell
git status --short
rg -n "purchase_statistics_chart|PurchaseStatisticsChart" lib test
rg -n "purchase_stat_card|PurchaseStatCard" lib test
# 确认现用路径
rg -n "PurchaseStatsDialog" lib
```

期望：两个候选只命中定义文件；`purchase_records_screen.dart` 仍实例化 `PurchaseStatsDialog`。

### 5.4 删除后验证命令

```powershell
flutter analyze
flutter test
git diff --check
git status --short
```

### 5.5 手动回归用例

- 采购统计：打开统计入口、加载完成、切换日期范围、查看材料排行。
- 空数据状态：无采购数据时统计显示空态。
- 加载失败状态：模拟 MySQL/SQLite 不可用时统计错误提示。

### 5.6 提交规范

- 提交信息示例：`清理采购模块旧统计图表子图（第三批）`

## 6. 第四批：患者材料旧子图

### 6.1 目标

删除患者材料旧编辑器 5 文件孤岛；并把 `thumbnail_manager.dart` 作为同批独立检查项。预计清理约 2302 行（不含缩略图工具）。

### 6.2 删除文件清单

主删（B 级，2302 行）：

- `lib/features/patients/widgets/material_input_widget.dart`（1205 行，`MaterialInputWidget`，无入站根文件）
- `lib/features/patients/widgets/material_debug_info_dialog.dart`（256 行，`MaterialDebugInfoDialog`，只被旧根引用）
- `lib/features/patients/widgets/material_image_detail_dialog.dart`（362 行，`MaterialImageDetailDialog`，只被旧根引用）
- `lib/features/patients/widgets/material_input_card.dart`（127 行，`MaterialInputCard`，只被旧根引用）
- `lib/features/patients/widgets/material_image_preview.dart`（352 行，`MaterialImagePreview`，只被 `material_input_card.dart` 引用）

同批独立检查项（A/B，323 行）：

- `lib/utils/thumbnail_manager.dart`（323 行，`ThumbnailManager`、`ThumbnailConfig`）
  - 删除前单独搜索 `ThumbnailManager`、`ThumbnailConfig`、`thumbnail_manager`，确认全局无调用；若有调用则保留并在本计划备注原因。

### 6.3 执行前复核命令

```powershell
git status --short
rg -n "material_input_widget|MaterialInputWidget" lib test
rg -n "material_debug_info_dialog|MaterialDebugInfoDialog" lib test
rg -n "material_image_detail_dialog|MaterialImageDetailDialog" lib test
rg -n "material_input_card|MaterialInputCard" lib test
rg -n "material_image_preview|MaterialImagePreview" lib test
rg -n "thumbnail_manager|ThumbnailManager|ThumbnailConfig" lib test
# 确认现用路径
rg -n "SingleMaterialEditor" lib
rg -n "material_detail_manager" lib
```

期望：五个旧文件符号只命中各自定义文件与子图内部；现用 `material_detail_manager.dart` 的新增/编辑入口均实例化 `SingleMaterialEditor`。

### 6.4 测试补齐要求

- 若测试未覆盖图片保存、图片删除、原图读取，先补回归测试再删除 2302 行旧子图。
- 测试通过后方可进入删除步骤。

### 6.5 删除后验证命令

```powershell
flutter analyze
flutter test
git diff --check
git status --short
```

### 6.6 手动回归用例

- 新增患者材料：打开新增入口、填写材料信息、保存成功。
- 编辑患者材料：打开编辑入口、修改字段、保存成功。
- 添加图片：在编辑器中添加图片、缩略图显示正常。
- 预览原图：点击缩略图查看大图。
- 删除图片：在编辑器中删除图片、保存后重新打开确认持久化。
- 保存失败提示：模拟保存失败，确认错误提示并可重试。
- 重新打开持久化：保存后关闭并重新打开同一患者材料，确认数据一致。

### 6.7 提交规范

- 提交信息示例：`清理患者材料旧编辑器子图（第四批）`
- 若同时删除 `thumbnail_manager.dart`，在提交说明中单独注明并附搜索证据。

## 7. 第五批：数据库/医学数据高影响候选

### 7.1 目标

逐一处理医学常量、治疗模型、数据库 schema 工具、MySQL 工具、旧数据同步弹窗、材料类型下拉。本批为高影响候选，不允许与普通 UI 死代码同批删除。

### 7.2 删除文件清单与前置条件

医学常量与治疗模型（B，1070 行）：

- `lib/models/allergy_types.dart`（182 行）
- `lib/models/dental_disease_types.dart`（71 行）
- `lib/models/systemic_disease_types.dart`（96 行）
- `lib/models/dental_treatment.dart`（716 行，含 `DentalTreatmentManager`、`TreatmentSelectionDialog`）

  前置：验证病历模板初始化、病历新增/编辑、疾病/过敏选择、预约治疗项目选择均不读取这些常量类；当前选项由模板/服务数据传给 `AllergySelectionWidget`、`DiseaseSelectionWidget`。

旧数据库 schema 工具（B，429 行）：

- `lib/models/schemas/database_initializer.dart`（187 行）
- `lib/models/schemas/schema_validator.dart`（242 行）

  前置：检查 SQLite 新库初始化、MySQL 结构检测、备份恢复测试是否在字符串层面引用表定义；确认当前初始化与结构检测走其他 service/provider 路径。

MySQL 工具（A/B，200 行）：

- `lib/utils/mysql_connection_helper.dart`（85 行，`MySqlConnectionHelper`）
- `lib/utils/mysql_migration.dart`（115 行，`MySQLMigration`）

  前置：确认全局无调用；放入数据库相关批次一起验证。

旧数据同步弹窗（A/B，313 行）：

- `lib/features/settings/widgets/data_sync_dialog.dart`（313 行，`DataSyncDialog`）

  前置：全局搜索设置页所有“同步”按钮，确认它们走当前患者同步或数据源同步流程，而非此弹窗。

材料类型下拉（A，217 行）：

- `lib/features/materials/widgets/material_type_dropdown.dart`（217 行，`MaterialTypeDropdown`）

  前置：打开 `material_form_dialog.dart` 和 `material_dropdown_field.dart`，确认当前材料表单使用的下拉实现不是本文件；删除后回归材料新增/编辑的类型选择。

### 7.3 执行前复核命令

```powershell
git status --short
rg -n "allergy_types|dental_disease_types|systemic_disease_types|dental_treatment" lib test
rg -n "AllergyTypes|DentalDiseaseTypes|SystemicDiseaseTypes|DentalTreatmentManager|TreatmentSelectionDialog" lib test
rg -n "schemas/database_initializer|schemas/schema_validator" lib test
rg -n "DatabaseInitializer|SchemaValidator" lib test
rg -n "mysql_connection_helper|MySqlConnectionHelper|mysql_migration|MySQLMigration" lib test
rg -n "data_sync_dialog|DataSyncDialog" lib test
rg -n "material_type_dropdown|MaterialTypeDropdown" lib test
```

### 7.4 验证命令（含数据库专项）

```powershell
flutter analyze
flutter test
# 数据库专项（若有相关测试文件）
flutter test test\services\database_backup_service_test.dart
git diff --check
git status --short
```

### 7.5 手动回归用例

- 数据库：SQLite 新库初始化、MySQL 结构检测、SQLite 备份/恢复、MySQL 配置读取。
- 病历：模板初始化、新增病历、编辑病历、疾病选择、过敏选择。
- 预约：治疗项目选择。
- 设置：所有“同步”按钮入口、数据源同步流程。
- 材料：新增/编辑材料的类型选择下拉。

### 7.6 提交规范

- 本批建议按子类拆为多个提交：医学常量与治疗模型一个提交、数据库 schema 工具与 MySQL 工具一个提交、旧同步弹窗与材料下拉一个提交。
- 每个提交信息准确写明删除范围，例如：`清理未接入医学常量与治疗模型（第五批-1）`。

## 8. 每批验收标准（通用）

- 候选路径在 `rg` 中无新增引用。
- `flutter analyze` 为 `No issues found!`。
- 相关测试通过；若运行全量 `flutter test`，记录测试数和失败数并与基线对比。
- 对应页面手动入口可打开、保存、重新加载，且数据结果与删除前一致。
- `git diff --check` 通过。
- 文本文件执行 `git ls-files --eol -- <file>`，工作区行尾保持 LF。
- 更新根 `ROADMAP.md`：只有已删除且验证完成的批次才能写入“已完成”；进行中的批次写入“进行中”。

## 9. 风险与回滚

- 每批独立提交，便于在发现问题时精准 `git revert <commit>`，不影响其他批次。
- B 级批次（第二、三、四、五批）涉及业务功能，删除前若手动回归发现异常，立即停止并在本计划备注阻塞原因；未确认前不合并。
- 数据库相关文件（第五批）即使静态无引用，也必须先运行数据库初始化、结构检测、备份恢复测试，确认无字符串层面依赖后再删。
- 患者材料批次（第四批）涉及图片数据，必须使用真实新增/编辑/图片预览/图片删除/重新打开流程验证，不能只做冒烟测试。

## 10. 与审核报告的对应关系

| 本计划章节 | 审核报告章节 | 候选数 | 预计行数 |
| --- | --- | --- | --- |
| 第一批 | 3.1 / 3.5 / 3.6 / 3.8 / 4.1 / 4.6 / 4.7 | 约 18 个文件 | 约 1700 行 |
| 第二批 | 3.2 / 3.3 | 3 个文件 | 约 1718 行 |
| 第三批 | 3.4 | 2 个文件 | 约 612 行 |
| 第四批 | 3.7 / 4.6（缩略图） | 5（+1 检查项） | 约 2302（+323）行 |
| 第五批 | 4.2 / 4.3 / 4.4 / 4.5 / 4.6（MySQL） | 约 9 个文件 | 约 2029 行 |

## 11. 执行进度跟踪

> 每完成一批，在本节填写：批次、删除文件数、实际删除行数、验证结果、提交哈希、ROADMAP 更新状态。

- [x] 第一批（2026-07-12 完成）
  - 删除文件数：18
  - 实际删除行数：约 1410 行
  - 验证结果：`flutter analyze` `No issues found!`；`git diff --check` 通过；`flutter test` 因网络超时无法下载 sqlite3 原生库失败（环境问题，非代码问题）
  - 路径修正：`financial_pagination_update_helper.dart` 实际路径在 `helpers/` 而非计划原写的 `widgets/`，已修正
  - 待办：手动回归预约新增/编辑、采购记录列表/详情/导出、设置页备份路径、财务列表分页
- [x] 第二批（2026-07-12 完成）
  - 删除文件数：3
  - 实际删除行数：约 1618 行
  - 验证结果：`flutter analyze` `No issues found!`；`git diff --check` 通过
  - 待办：手动回归新增财务记录、编辑财务记录、编辑收费明细、财务统计日期范围/刷新/金额隐藏
- [x] 第三批（2026-07-12 完成）
  - 删除文件数：2
  - 实际删除行数：约 612 行
  - 验证结果：`flutter analyze` `No issues found!`；`git diff --check` 通过
  - 待办：手动回归采购统计入口、日期范围、材料排行、空数据和加载失败状态
- [x] 第四批（2026-07-12 完成）
  - 删除文件数：6（5 个旧子图 + thumbnail_manager.dart）
  - 实际删除行数：约 2625 行
  - 验证结果：`flutter analyze` `No issues found!`；`git diff --check` 通过
  - 说明：计划原要求先补回归测试，用户确认旧代码已静态确认不可达、删除不影响现用 SingleMaterialEditor，授权直接删除；thumbnail_manager.dart 经搜索确认全局无调用，一并删除
  - 待办：手动回归新增/编辑患者材料、添加图片、预览原图、删除图片、保存失败提示、重新打开持久化
- [x] 第五批（2026-07-12 完成，拆 3 个提交）
  - 删除文件数：10
  - 实际删除行数：约 2224 行（1065 + 629 + 530）
  - 验证结果：`flutter analyze` `No issues found!`；`git diff --check` 通过
  - 提交拆分：
    - 第五批-1：医学常量与治疗模型 4 文件
    - 第五批-2：旧 schema 工具与 MySQL 工具 4 文件
    - 第五批-3：旧数据同步弹窗与材料类型下拉 2 文件
  - 说明：删除前符号搜索均仅命中定义文件/文档；现用病历选择走模板数据组件，材料类型走 `MaterialDropdownField`，设置页同步走患者同步/数据源流程，数据库初始化与结构检测走 `DatabaseProvider`/`DatabaseSchemaService` 等
  - 待办：手动回归病历模板/疾病过敏选择、预约治疗项目、SQLite/MySQL 初始化与结构检测、备份恢复、设置页同步入口、材料新增/编辑类型选择；`schemas/README.md` 仍保留对已删工具的文档示例，未在本批改动

## 12. 后续阶段

本计划完成后，若需继续压缩代码，按审核报告第 7 节进入第二阶段方法级审核：对可达文件建立类/方法调用图，优先检查 800 行以上 provider/service/dialog 的旧 API，并区分 UI 调用、service 间调用和测试调用。方法级清理完成后再评估大文件拆分；“拆分文件”是可维护性任务，不应与“删除死代码”混为一批。

## 13. 2026-07-12 完成状态复核

- 代码删除状态：已完成。审核报告列出的 39 个不可达候选文件均已删除，`lib/` Dart 文件数已由审核时的 392 个降为 353 个。
- 静态验证状态：已完成。五批记录均显示 `flutter analyze` 为 `No issues found!`，并通过 `git diff --check`。
- 自动化测试状态：已于 2026-07-12 修正 `appointment_state_service_test.dart` 的测试夹具。患者搜索和数据变更测试此前未关闭默认日期筛选，固定在 2026-07-05 的测试数据会被当前日期过滤为空；修正后该文件 14 个测试全部通过，全量 `flutter test` 64 个测试全部通过。
- 手动业务回归状态：未完全完成。五批记录中的预约、财务、采购、患者材料、数据库、病历和设置页回归项仍标记为待办。
- 最终结论：无用代码清理的删除实施、静态检查和现有全量自动化测试均已完成；各批手动业务回归尚未全部执行，因此运行时手动验收仍未完整完成。

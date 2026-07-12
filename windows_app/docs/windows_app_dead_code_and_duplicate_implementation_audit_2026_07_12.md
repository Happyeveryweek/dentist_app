# Windows 端无用代码与重复实现审核报告

## 1. 审核结论

审核日期：2026-07-12。

审核范围：`windows_app/lib/` 下全部 Dart 源码，同时检查 `windows_app/test/` 对候选文件的直接引用；不包含生成目录、第三方依赖、Windows Runner/CMake、安装器和资源文件。

当前 `lib/` 共 392 个 Dart 文件，约 103656 行。以 `lib/main.dart` 为根建立静态 `import`、`export`、`part` 引用图后，得到以下结果：

- 34 个文件没有任何入站引用，合计 7306 行。
- 另有 5 个文件虽然有入站引用，但引用者本身属于上述无入口子图。
- 从 `main.dart` 不可达的候选共 39 个，合计 8484 行，约占 `lib/` Dart 代码的 8.2%。
- 其中多组已经能确认是“同一功能保留了旧实现和现用实现”；不是单纯的小函数未使用，而是整文件、整套组件子图滞留。
- `flutter analyze` 即使为 0 issue，也不能证明这些文件会被应用使用。Dart 分析器通常不会把一个从未导入的完整库报告为 `unused_element`。

建议按本文第 6 节分 5 批清理，每批单独验证和提交。不要一次删除全部 39 个文件，因为患者材料、财务统计、采购统计等模块需要分别做运行时回归。

## 2. 判定方法与证据等级

### 2.1 已执行的静态检查

1. 枚举 `lib/**/*.dart`，统计文件数和行数。
2. 解析每个文件的 `import`、`export`、`part`，同时解析相对路径和 `package:dentist_app_windows/` 路径。
3. 以 `lib/main.dart` 为入口遍历引用图，找出不可达文件。
4. 对无入站文件提取顶层 `class`、`enum`、`mixin`、`typedef` 名称，并在 `lib/`、`test/` 全局复核符号与导入路径。
5. 对近义文件打开现用调用点，核对当前页面实际实例化的类，而不是仅凭文件名判断。

### 2.2 证据等级

- **A：可直接进入删除批次。** 文件无入站引用，测试也未导入；同时存在清晰的现用替代路径，或文件只是孤立工具/组件。
- **B：静态确认不可达，但删除前必须做对应页面手动回归。** 整个子图从 `main.dart` 不可达，业务内容较大或涉及图片、数据库迁移、统计等高影响功能。
- **C：不建议本轮删除。** 仅因“大文件”“类名相似”或“看起来重复”不足以证明无用；需要先增加覆盖或运行时追踪。

本文没有把“行数大”本身当作删除依据，也没有把通过静态检查当作运行时正确性的依据。

## 3. 已确认的重复实现与整块无用代码

### 3.1 预约表单存在旧版和现用版两套分段组件（A，608 行）

无引用旧文件：

- `lib/features/appointments/widgets/cost_status_section.dart`：112 行，类 `CostStatusSection`。
- `lib/features/appointments/widgets/date_time_section.dart`：128 行，类 `DateTimeSection`。
- `lib/features/appointments/widgets/notes_section.dart`：73 行，类 `NotesSection`。
- `lib/features/appointments/widgets/treatment_section.dart`：295 行，类 `TreatmentSection`。

现用路径：

- `appointment_form_dialog.dart` 明确导入 `appointment_cost_status_section.dart`、`appointment_date_time_section.dart`、`appointment_notes_section.dart`、`appointment_treatment_section.dart`。
- 对应现用类分别为 `AppointmentCostStatusSection`、`AppointmentDateTimeSection`、`AppointmentNotesSection`、`AppointmentTreatmentSection`。
- 旧版四个文件没有任何文件导入，顶层类名也只在各自定义文件出现。

判断：这是完整、明确的旧版组件残留，可作为第一批删除。删除时不要动带 `appointment_` 前缀的现用文件。

### 3.2 财务统计保留旧对话框和旧统计组件（A，727 行）

无引用旧文件：

- `lib/features/financial/widgets/financial_statistics_dialog_widget.dart`：631 行，旧类名 `FinancialStatisticsDialog`。
- `lib/features/financial/widgets/financial_stats_section.dart`：96 行，类 `FinancialStatsSection`。

现用路径：

- `lib/screens/financial_management_screen.dart` 导入 `financial_statistics_dialog.dart`。
- 页面实际实例化 `FinancialStatsDialog`，该实现支持日期范围、刷新回调、金额隐藏状态，并使用 `FinancialStatisticsService`。
- 旧 `FinancialStatisticsDialog` 直接在组件内重复计算月度、项目、支付方式和患者统计，没有任何导入者。

判断：旧对话框与当前对话框承担同一统计展示职责，但当前页面只走 `FinancialStatsDialog`。旧文件可删；删除后重点回归财务管理页“统计”入口、日期筛选、刷新、金额隐藏。

### 3.3 财务编辑弹窗存在一份 891 行的孤立旧实现（B，891 行）

候选文件：

- `lib/features/financial/widgets/edit_financial_item_dialog.dart`：891 行，类 `EditFinancialItemDialog`。

证据：

- 文件无任何入站导入。
- `EditFinancialItemDialog` 只在本文件内部出现。
- 当前财务编辑链主要由 `financial_form_dialog.dart`、`financial_record_edit_dialog.dart`、`financial_detail_editing_item_row.dart` 等文件承担。

判断：静态上已确认不可达，但该文件体量大，可能代表一次旧版财务项目编辑流程。建议单独一批删除，并回归“新增财务记录”“编辑财务记录”“编辑收费明细”三个入口，避免只验证列表页。

### 3.4 采购统计存在旧图表和当前对话框两套实现（B，612 行）

不可达旧子图：

- `lib/features/purchases/widgets/purchase_statistics_chart.dart`：531 行，类 `PurchaseStatisticsChart`。
- `lib/features/purchases/widgets/purchase_stat_card.dart`：81 行，只被旧图表导入。

现用路径：

- `lib/screens/purchase_records_screen.dart` 实例化 `PurchaseStatsDialog`。
- 当前实现位于 `purchase_statistics_dialog.dart`，直接接收 `PurchaseProvider`，加载采购明细并提供日期范围统计。
- 旧 `PurchaseStatisticsChart` 无入站引用；其 `purchase_stat_card.dart` 也只服务于旧图表。

判断：整套旧统计子图从 `main.dart` 不可达。删除前后回归采购统计入口、日期范围、材料排行、空数据和加载失败状态。

### 3.5 采购列表卡片、按钮、分页等保留未接入的拆分版本（A/B，420 行）

无引用文件：

- `hoverable_purchase_record_card.dart`：51 行。
- `purchase_hoverable_cards.dart`：50 行。两者甚至各自定义了同名 `HoverablePurchaseRecordCard`。
- `purchase_compact_action_button.dart`：46 行。
- `purchase_detail_item_card.dart`：94 行。
- `purchase_pagination.dart`：134 行。
- `purchase_stat_item.dart`：45 行。

证据：

- 上述文件均无入站导入。
- `purchase_records_screen.dart` 内部仍定义 `_HoverablePurchaseRecordCardState`，说明当前页面使用的是页面内实现，而不是这两份公共卡片文件。
- 当前统计对话框也没有使用 `purchase_stat_item.dart`。

判断：这些文件是未完成接入或重构后遗留的拆分组件。它们可以删除，但这同时暴露出当前页面仍有内嵌 UI 实现。此次优化目标是删死代码，不要借机把页面内代码迁回这些文件；如需组件化，应另开任务并先补回归测试。

### 3.6 采购导出旧兼容壳已无人使用（A，31 行）

候选文件：`lib/features/purchases/widgets/purchase_export_service.dart`。

该文件只有一个兼容包装类，把两个静态方法委托给 `lib/services/purchase_export_service.dart`。当前代码直接使用核心服务，兼容路径没有导入者。可删除兼容壳，保留 `lib/services/purchase_export_service.dart` 和 `purchase_export_dialog.dart`。

### 3.7 患者材料旧编辑器形成 5 文件孤岛（B，2302 行）

不可达子图：

- `material_input_widget.dart`：1205 行，是无入站根文件。
- `material_debug_info_dialog.dart`：256 行，只被旧 `material_input_widget.dart` 引用。
- `material_image_detail_dialog.dart`：362 行，只被旧 `material_input_widget.dart` 引用。
- `material_input_card.dart`：127 行，只被旧 `material_input_widget.dart` 引用。
- `material_image_preview.dart`：352 行，只被旧 `material_input_card.dart` 引用。

现用路径：

- `material_detail_manager.dart` 的新增和编辑入口都实例化 `SingleMaterialEditor`。
- 当前编辑器位于 `single_material_editor.dart`，包含图片加载、保存和删除处理。

判断：这是本次最大的一组整块无用代码。引用图能确认其不可达，但涉及患者材料及图片数据，必须单独删除、单独回归。需要验证新增材料、编辑材料、添加图片、预览原图、删除图片、保存失败提示和重新打开后的持久化结果。

### 3.8 设置页备份路径存在旧的单输入组件（A，142 行）

无引用旧文件：

- `backup_path_input.dart`：68 行。
- `backup_path_selector.dart`：74 行。

现用路径：

- `settings_screen.dart` 实例化 `BackupPathInputs`。
- 当前实现位于 `backup_path_inputs.dart`，统一处理主备两个路径。

判断：旧的单路径组件已经被双路径组件替代，可删。回归设置页主备路径选择、手输路径、清空和重启后持久化。

## 4. 其他无入站文件清单

以下文件没有任何 `lib/` 或 `test/` 入站引用。它们不一定都有同名替代文件，但静态上不会进入当前应用或测试编译图。

### 4.1 财务辅助组件（A，207 行）

- `financial_pagination_update_helper.dart`：55 行。
- `financial_compact_info_item.dart`：56 行。
- `financial_stats_section.dart`：96 行；已在 3.2 说明。

处理建议：删除前分别搜索 `FinancialPaginationUpdateHelper`、`PaginationResult`、`FinancialCompactInfoItem`、`FinancialStatsSection`，应只有定义文件命中。删除后验证财务列表分页和详情紧凑信息区域。

### 4.2 材料类型下拉（A，217 行）

- `material_type_dropdown.dart`：217 行，`MaterialTypeDropdown` 只在本文件出现。

处理建议：当前材料表单使用的具体下拉实现需要以后续模型再次打开 `material_form_dialog.dart` 和 `material_dropdown_field.dart` 确认；确认后删除本文件，回归材料新增/编辑的类型选择。

### 4.3 设置页孤立组件（A/B，384 行）

- `data_sync_dialog.dart`：313 行。
- `settings_card.dart`：71 行。

处理建议：`DataSyncDialog` 可能是旧数据同步入口，虽然无引用，但删除前要全局搜索设置页所有“同步”按钮，确认它们走当前患者同步或数据源同步流程；`SettingsCard` 可直接按普通孤立 UI 组件处理。

### 4.4 未接入的医学常量与治疗模型（B，1070 行）

- `models/allergy_types.dart`：182 行。
- `models/dental_disease_types.dart`：71 行。
- `models/systemic_disease_types.dart`：96 行。
- `models/dental_treatment.dart`：716 行。

证据：四个文件均无入站导入，对应顶层类名只在定义文件出现。当前病历表单的疾病、过敏选项由模板/服务数据传给 `AllergySelectionWidget`、`DiseaseSelectionWidget`，没有读取这些常量类。

风险：`dental_treatment.dart` 不只是数据模型，还包含 `DentalTreatmentManager` 和 `TreatmentSelectionDialog`，体量较大。建议把它与三个医学常量放在独立批次，回归病历模板初始化、病历新增/编辑、疾病/过敏选择以及预约治疗项目选择。

### 4.5 旧数据库 schema 工具（B，429 行）

- `models/schemas/database_initializer.dart`：187 行。
- `models/schemas/schema_validator.dart`：242 行。

证据：两文件无入站导入。当前数据库初始化与结构检测使用其他 service/provider 路径。

风险：数据库相关代码不能仅靠页面冒烟验证。删除前必须检查 SQLite 新库初始化、MySQL 结构检测和备份恢复测试是否引用字符串层面的表定义；本次只建议列入候选，不建议和 UI 死代码同批删除。

### 4.6 孤立工具类（A/B，544 行）

- `utils/date_time_formatter.dart`：21 行。注意当前广泛使用的是文件名少一个下划线的 `utils/datetime_formatter.dart`，两者都定义 `DateTimeFormatter`；前者无导入，属于明确重复工具。
- `utils/mysql_connection_helper.dart`：85 行。`MySqlConnectionHelper` 只在本文件出现。
- `utils/mysql_migration.dart`：115 行。`MySQLMigration` 只在本文件出现。
- `utils/thumbnail_manager.dart`：323 行。`ThumbnailManager`、`ThumbnailConfig` 只在本文件出现。

处理建议：时间格式旧文件可优先删除。MySQL 迁移和缩略图工具虽然不可达，但涉及数据与图片，分别放入数据库批次和患者材料批次；不要因为类名未使用就同时重写现用实现。

### 4.7 明显放错目录的占位文件（A，1 行）

- `lib/test/appointment_form_dialog.dart`：1 行。

该文件位于生产源码 `lib/test/`，不是 Flutter 的 `test/` 目录；无入站引用且只有一行。确认内容不是生成标记后删除。如果删除后 `lib/test/` 为空，删除目录属于文件系统清理，执行前仍应遵守项目的删除确认规则。

## 5. 不应据此直接删除的代码

以下情况本次不列为死代码：

- 有正常入站引用但方法可能未调用的 service/provider。文件级引用图无法证明类内每个公有方法是否无用，需要 AST 或逐方法调用链审核。
- 通过 Provider、回调、路由或 Flutter widget builder 间接实例化的类型。只要文件在 `main.dart` 可达图中，就不以符号搜索零命中直接删除。
- 大于 1000 行的现用页面和弹窗，例如 `patient_detail_screen.dart`、`financial_form_dialog.dart`。它们存在可维护性问题，但不是无用代码证据。
- `lib/services/purchase_export_service.dart`。这是当前核心采购导出实现；应删除的是旧兼容壳，而不是核心服务。
- `utils/datetime_formatter.dart`。这是当前大量数据源和模型共同使用的时间格式工具；应删除的是 `utils/date_time_formatter.dart`。

## 6. 给后续模型的可执行优化方案

### 6.1 总体原则

1. 每批开始前执行 `git status --short`，工作区不干净时只处理本文列出的文件，不覆盖用户改动。
2. 每个候选再次执行精确导入和类名搜索。若发现新增引用，停止删除该文件并更新报告。
3. 删除属于项目红线，必须先得到用户对该批文件的明确删除授权。
4. 每批只删除已确认文件及由该批产生的孤儿导入，不顺手重构现用代码。
5. 不用“保留兼容层更安全”作为默认策略。确认无调用后应删除旧路径，避免继续形成双实现。
6. 每批独立提交，提交信息使用中文并准确写明模块。

### 6.2 第一批：低风险、明确替代（建议约 1700 行）

目标：删除预约旧四组件、旧时间格式工具、备份路径旧组件、采购导出兼容壳、普通孤立小组件和占位文件。

建议文件：

- 预约旧四组件。
- `utils/date_time_formatter.dart`。
- `backup_path_input.dart`、`backup_path_selector.dart`。
- `features/purchases/widgets/purchase_export_service.dart`。
- `financial_pagination_update_helper.dart`、`financial_compact_info_item.dart`。
- `purchase_compact_action_button.dart`、`purchase_detail_item_card.dart`、`purchase_pagination.dart`、`purchase_stat_item.dart`、两个 hoverable purchase card 文件。
- `settings_card.dart`、`lib/test/appointment_form_dialog.dart`。

验证：

```powershell
dart format <仅本批仍被修改的 Dart 文件；纯删除时无需格式化>
flutter analyze
flutter test
git diff --check
git status --short
```

手动回归：预约新增/编辑、采购记录列表/详情/导出、设置页备份路径。

### 6.3 第二批：财务旧实现

目标：删除 `edit_financial_item_dialog.dart`、`financial_statistics_dialog_widget.dart`、`financial_stats_section.dart`。

执行前确认：

```powershell
rg -n "edit_financial_item_dialog|EditFinancialItemDialog|financial_statistics_dialog_widget|FinancialStatisticsDialog|FinancialStatsSection" lib test
```

期望：只命中候选定义文件。验证新增财务记录、编辑财务记录、编辑收费明细、统计日期范围、刷新和金额隐藏。

### 6.4 第三批：采购旧统计子图

目标：删除 `purchase_statistics_chart.dart`、`purchase_stat_card.dart`。

执行前确认 `purchase_records_screen.dart` 仍实例化 `PurchaseStatsDialog`。运行采购相关测试；若无覆盖，至少手动验证统计打开、加载、日期筛选、材料排行、空态和错误态。

### 6.5 第四批：患者材料旧子图

目标：删除 3.7 的 5 个文件，并把 `thumbnail_manager.dart` 是否一起删除作为同批独立检查项。

执行前：

- 确认 `material_detail_manager.dart` 的新增和编辑均走 `SingleMaterialEditor`。
- 搜索五个旧文件名及 `MaterialInputWidget`、`MaterialInputCard`、`MaterialImagePreview`、`MaterialImageDetailDialog`、`MaterialDebugInfoDialog`。
- 检查测试是否覆盖图片保存、删除和原图读取；没有则先补回归测试，再删除 2302 行旧子图。

手动回归必须使用真实的新增、编辑、图片预览、图片删除和重新打开流程。

### 6.6 第五批：数据库/医学数据高影响候选

目标：逐一处理三个医学常量、`dental_treatment.dart`、两个 schema 工具、`mysql_connection_helper.dart`、`mysql_migration.dart`、`data_sync_dialog.dart`、`material_type_dropdown.dart`。

要求：

- 不允许把这些文件和普通 UI 死代码一起批量删除。
- 数据库工具删除前，运行数据库初始化、结构检测、SQLite 备份恢复和 MySQL 配置相关测试。
- 医学常量和治疗模型删除前，验证病历模板初始化、病历新增/编辑、疾病/过敏选择、预约治疗项目选择。
- 如果某个流程没有自动化覆盖，先记录精确手动用例；若涉及真实数据写入，应在测试数据库中验证。

### 6.7 每批验收标准

- 候选路径在 `rg` 中无新增引用。
- `flutter analyze` 为 `No issues found!`。
- 相关测试通过；若运行全量 `flutter test`，记录测试数和失败数。
- 对应页面手动入口可打开、保存、重新加载，且数据结果与删除前一致。
- `git diff --check` 通过。
- 文本文件执行 `git ls-files --eol -- <file>`，工作区行尾保持 LF。
- 更新根 `ROADMAP.md`，只有已删除且验证完成的批次才能写入“已完成”。

## 7. 后续可追加的第二阶段审核

本报告解决的是“整文件/整子图不可达”和明显双实现。若还要继续压缩大量代码，下一阶段应做方法级审核：

1. 对可达文件建立类、构造函数、静态方法和公有方法调用图。
2. 优先检查 800 行以上的 provider/service/dialog 是否保留旧 API。
3. 对 Provider 方法区分 UI 调用、service 间调用和测试调用，不能只搜方法名。
4. 对重复 SQL、导出、同步、分页逻辑做行为对照，确认单一权威实现后再删除旧分支。
5. 方法级清理完成后再评估大文件拆分；“拆分文件”是可维护性任务，不应与“删除死代码”混为一批。

## 8. 本次审核限制

- 本次未运行 Windows 应用，未做运行时覆盖采样，因此 B 级候选仍要求手动回归。
- 静态引用图只分析 Dart 的 `import/export/part`；它足以证明完整 Dart 库是否进入应用编译图，但不能证明可达文件内部每个方法都会运行。
- 本次没有删除业务文件，也没有修改任何现有实现；报告中的行数会随后续代码变更漂移，执行优化时应重新统计。

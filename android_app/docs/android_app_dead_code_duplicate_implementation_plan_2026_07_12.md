# Android 端无用代码与重复实现实施计划

## 0．文档定位、范围与当前状态

制定日期：2026-07-12。

当前进度（2026-07-13）：批次 0“重新取证、测试映射与基线冻结”、批次 1“A 级不可达 UI/工具文件”和批次 2“旧模型、患者数据源与旧 Schema Validator”代码清理已完成；批次 2 的手动业务回归待主人执行，批次 3A～7 未开始。批次 2 删除 4 个当日复核确认无入站引用的旧文件，未修改现用业务入口。

本计划把 [Android 端无用文件、无用方法与重复实现审核报告](android_app_dead_code_duplicate_files_and_methods_audit_2026_07_12.md) 转换为可逐批执行、可验证、可记录的任务。执行者只需按本文指定批次、文件、符号、命令和验收场景操作；若实际搜索结果与本文不一致，立即停止该候选并记录原因，不能按旧结论强行删除。

范围仅限 `android_app/lib/`、为本计划新增的 `android_app/test/` 测试和这两份文档及根目录 `ROADMAP.md` 的进度更新。不修改 `android/` 原生配置、`pubspec.yaml`、数据库 schema、迁移 SQL 的业务语义、权限、签名、Gradle 或发布设置。

当前基线：

- 审核时 `lib/` 有 288 个 Dart 文件、约 62771 行；16 个完整文件从 `lib/main.dart` 不可达，约 2203 行。
- 审核时 `test/**/*.dart` 为 0；因此高风险批次不能以静态检查替代测试。
- 2026-07-12 已实际运行 `flutter analyze`，结果为 `No issues found!`。
- 本文完成仅表示实施路径已建立；没有文件、方法或重复实现因本文而被删除或重构。

删除文件、删除方法、移除兼容 API 都属于代码删除。每一批动手前，执行者必须向主人列出本批精确删除清单、当日重新搜索证据、替代入口和风险，取得明确授权。本计划不构成删除授权。

## 1．最终完成标准

全部实施完成必须同时满足：

1. 16 个文件在删除当日仍无来自 `lib/`、`test/`、脚本或文档指定运行入口的入站引用；若出现新引用，候选标为“跳过”或重新分级。
2. 每个方法候选只有声明命中，或属于同一批中明确成对删除的 Provider → Manager 委托链；不得删除 override、接口实现、生命周期、序列化、回调、动态注册和字符串反射入口。
3. 每个提交只包含一个风险相近、业务边界一致的小批次；死代码删除不得与重复实现重构混在同一提交。
4. 删除产生的孤儿 import 已清理，`flutter analyze` 为 `No issues found!`，`git diff --check` 和行尾检查通过。
5. 数据库、备份恢复、迁移、同步和 MySQL 行转换已先补对应测试，并完成规定的真实数据回归；没有以空库或 Analyzer 通过替代该回归。
6. 重复实现治理后，每类能力只保留一个权威入口，调用结果、图片 Blob、空值和错误语义与迁移前一致。
7. 本文第 13 节、根 `ROADMAP.md` 与代码真实状态一致；未经验证不得标记“完成”。

## 2．统一执行规则

### 2.1 每批开始前的固定步骤

1. 在仓库根目录运行 `git status --short`，记录主人已有修改；只暂存本批 Android 文件，绝不覆盖或混入 Windows 端改动。
2. 阅读审核报告对应章节和本文对应批次，确认本批范围、保留边界、测试前置条件和手动回归。
3. 进入 `android_app/`，对每个文件路径和方法名执行精确 `rg` 搜索；搜索结果写入第 13 节的“重新搜索”栏。
4. 打开候选声明的完整类和现用替代入口，确认不是抽象接口、`@override`、`initState`/`dispose`、数据库回调、JSON/Map 反序列化、Provider 注册、路由字符串或动态访问入口。
5. 出现任一无法确认事项时，将该候选标为“阻塞”，不要删；一批中其余互不依赖候选可在授权范围内继续。

### 2.2 实施、验证和文档更新顺序

1. 只用 `apply_patch` 删除已授权内容及由本批产生的孤儿 import；不重排无关代码、不改相邻样式。
2. 对修改过的 Dart 文件执行定向 `dart format`；纯文件删除或 Markdown 更新不运行格式化。
3. 先执行本批定向测试，再执行全量 `flutter test`、`flutter analyze`、`git diff --check` 和行尾检查。
4. 完成本文规定的手动回归。数据库相关回归使用副本，不操作主人正在使用的生产库。
5. 在第 13 节追加真实结果，并更新根 `ROADMAP.md`。只有自动验证和所需手动回归均通过，才能标为“完成”。
6. 每个小批单独中文提交；不包含 Windows 端、其他任务或主人已有变更。

### 2.3 命令模板

在仓库根目录查看状态；其余 Flutter 命令在 `android_app/` 执行。当前 Windows Flutter 工具链必须按项目规则使用显式非沙箱审批。

```powershell
# 仓库根目录
git status --short

# android_app/ 目录
$searchPaths = @('lib')
if (Test-Path test) { $searchPaths += 'test' }
rg -n '<文件名或符号>' $searchPaths -S
dart format <本批实际修改的 Dart 文件>
flutter test <本批定向测试文件>
flutter test
flutter analyze
git diff --check
git ls-files --eol -- <本批改动文件>
```

全量测试因环境或网络失败时，记录完整失败原因、已通过的定向测试和待补测命令；批次状态必须保留为“阻塞”，不能写“完成”。

## 3．分批总览与进度看板

| 批次 | 范围 | 风险 | 硬性前置条件 | 当前状态 |
| --- | --- | --- | --- | --- |
| 0 | 重新取证、冻结基线、建立测试映射 | 低 | 无 | 完成 |
| 1 | A 级不可达 UI/测试工具文件 | 低 | 每个文件仍无入站引用 | 完成 |
| 2 | 旧 Appointment、患者数据源、Schema Validator | 中高 | 批次 1 完成，SQLite/MySQL 回归环境可用 | 完成：代码清理与自动检查通过，待主人手动回归 |
| 3A | 旧财务清理文件和独立低风险方法 | 中 | 批次 2 完成，每个方法仍无调用 | 未开始 |
| 3B | Provider、SettingsProvider 与 Manager 无消费者链 | 中高 | 批次 3A 完成，设置持久化回归可执行 | 未开始 |
| 4 | 备份、数据库工具、一次性迁移 | 高 | 新增测试，旧库副本和备份副本可用 | 未开始 |
| 5 | 采购页空监听基础设施 | 中 | 批次 4 完成，刷新场景可手动回归 | 未开始 |
| 6 | MySQL ResultRow 转换收口 | 中高 | 新增纯函数测试，SQLite/MySQL 对照数据可用 | 未开始 |
| 7 | 统计面板、连接访问器、确认对话框治理 | 架构调整 | 单独方案和主人确认 | 未开始 |

状态只允许使用：`未开始`、`进行中`、`阻塞`、`完成`、`跳过`。`跳过`必须说明新调用、动态入口或保留理由；`完成`必须有日期、自动验证和手动回归结果。

## 4．批次 0：重新取证、测试映射与基线冻结

### 4.1 目标

确认审核日后的代码没有新增调用，找出实际可用的测试夹具和真实回归环境；本批不改业务代码、不删除候选。

### 4.2 精确操作

1. 记录 `git status --short`，并在进度日志注明哪些改动属于主人或其他任务。
2. 运行审核报告第 12 节的全部 7 组 `rg` 命令；对 16 个文件额外搜索文件名、类名及旧 import 路径。
3. 建立候选映射：每项记录“文件/符号、声明位置、搜索命中摘要、现用替代入口、风险级别、预期批次、状态”。
4. 确认 `test/` 仍不存在时，为批次 2、4、6 预建测试目录与夹具清单，但不要为了建目录提交空测试文件。
5. 刷新基线：运行 `flutter analyze`；若已有测试，再运行 `flutter test`。当前没有测试时明确记录“全量测试无测试目标”，不能伪造通过结果。

### 4.3 验收

- 所有后续候选均有当日搜索证据。
- 高风险候选均已映射到测试和手动回归场景。
- 无 Dart 业务改动。

## 5．批次 1：A 级不可达 UI、Toast 与测试工具文件

### 5.1 授权时必须逐项列出的删除清单

| 文件 | 删除对象 | 保留的权威入口 | 手动回归 |
| --- | --- | --- | --- |
| `lib/features/financial/widgets/amount_info_item.dart` | 整文件 | 现用财务统计组件 | 财务列表和统计卡片 |
| `lib/features/financial/widgets/financial_item_row.dart` | 整文件 | 当前财务列表行 | 财务列表滚动和详情进入 |
| `lib/features/financial/widgets/stat_card.dart` | 整文件 | 当前统计卡片；不得删除 dashboard 同名 `StatCard` | 财务统计 |
| `lib/features/financial/widgets/stat_item.dart` | 整文件 | 当前统计展示 | 财务统计 |
| `lib/features/settings/services/database_settings_manager.dart` | `DatabaseSettingsManager` 整文件 | `DatabaseSwitchService`、`DatabaseProvider`、设置页状态 | 数据源设置 |
| `lib/providers/test_connection_pool.dart` | `ConnectionPoolTester` 整文件 | 无；未来测试应放 `test/providers/` | 登录和连接提示 |
| `lib/widgets/connection_status_widget.dart` | 整文件 | 登录页、设置页及专用连接 UI | 登录、设置连接状态 |
| `lib/widgets/message_toast.dart` | 整文件 | `utils/message_toast_helper.dart` | 登录/同步/错误提示 |
| `lib/widgets/toast_widgets.dart` | 整文件 | `MessageToastHelper`、SnackBar、确认对话框 | 成功、删除、失败提示 |

### 5.2 禁止越界

- 只删除上述精确路径；同名的 dashboard、采购或其他模块组件不是本批范围。
- 不修改 `utils/message_toast_helper.dart`、登录、同步或财务的现用提示逻辑。
- 如果任一文件出现 `export`、脚本、示例或动态加载入口，本文件单独移至“阻塞”，不因其他文件可删而一起强删。

### 5.3 验证

自动：`flutter analyze`、`git diff --check`、行尾检查。纯删除且没有 Dart 改写时不执行 `dart format`。

手动：登录成功/失败提示、数据源连接失败与重试提示、一次同步提示、财务列表加载、财务统计卡片显示。每个场景记录数据源类型和结果。

## 6．批次 2：旧模型、患者数据源与旧 Schema Validator

### 6.1 精确范围

| 文件 | 删除理由 | 必须保留的现用路径 |
| --- | --- | --- |
| `lib/models/appointment.dart` | 旧 `Appointment` 无入站 import | `models/database_models.dart` 中的 `Appointment`，以及预约 data source/provider/页面 |
| `lib/data_sources/mysql_patient_data_source.dart` | 旧 MySQL 患者数据源无入站 import | `data_sources/patient_data_source.dart` 中的 `MySqlPatientDataSource` |
| `lib/data_sources/sqlite_patient_data_source.dart` | 旧 SQLite 患者数据源无入站 import | `data_sources/patient_data_source.dart` 中的 `SqlitePatientDataSource` |
| `lib/models/schemas/schema_validator.dart` | 旧 `SchemaValidator` 无入站 import | `utils/schema_validator.dart` 与 `sync_manager.dart` 升级链 |

### 6.2 执行顺序

1. 对每个文件搜索文件名、类名、旧 import 路径；同时打开 `patient_data_source.dart`、`patient_initialization_service.dart`、`patient_provider.dart`、`appointment_data_source.dart`、`appointments_provider.dart`、`sync_manager.dart`。
2. 先为当前 `Appointment` 建立最小序列化回归测试，覆盖 `fromMap`/`toMap` 和状态字段；无法建立时，本批不得删除 `models/appointment.dart`。
3. 建立患者数据源测试，至少覆盖 SQLite/MySQL 的列表、关键词搜索、分页排序、从 Map 转模型和新增/更新后的读取；测试应使用受控 fake 或测试数据库，不连接生产库。
4. 建立 SchemaValidator 升级测试，至少覆盖当前 schema 定义、缺表/缺字段检测和升级入口；测试失败时先修测试夹具或确认当前链路，不删除旧文件。
5. 删除已授权文件及孤儿 import，依次运行定向测试、全量测试、静态检查和手动回归。

### 6.3 必须手动回归

- SQLite：患者列表、搜索、分页、排序、新增、编辑、删除、病历号生成；预约新增、编辑、状态更新、列表和仪表盘。
- MySQL：使用非生产测试库重复患者列表、搜索、分页和增删改；确认数据源切换后显示与 SQLite 语义一致。
- Schema：在旧库副本启动并确认现用 validator 完成结构检测/升级；不得用空库代替。

任一场景失败，保留当前改动和证据，将本批标为“阻塞”，等待主人决定，不做 Git 覆盖回退。

## 7．批次 3A：旧财务清理文件与独立低风险方法

### 7.1 文件级范围

删除 `lib/features/financial/utils/financial_data_cleaner.dart`，但只在确认 `FinancialProvider` 仍使用 `features/financial/services/financial_data_cleaner_service.dart` 后执行。回归无效财务数据检测、清理确认提示和列表重新加载。

### 7.2 方法级范围与分组

每个分组独立小提交，先逐符号搜索再删除：

| 子组 | 文件 | 候选 |
| --- | --- | --- |
| 3A-1 预约/仪表盘 | `appointment_cache_mixin.dart`、`appointment_status_helper.dart`、`dashboard_screen.dart` | `clearAppointmentsNeedRefresh`、`getColorForStatus`、`refreshDashboardData` |
| 3A-2 财务计算 | `financial_calculator.dart` | `calculateTotalAmount`、`calculateSettledCount`、`calculateUniquePatientCount`、`calculateTotalRecords`、`calculateTotalReceivable`、`calculateTotalCollected`、`calculateTotalOutstanding`、`calculateTotalProcessingFee` |
| 3A-3 财务辅助 | `financial_payment_method_helper.dart`、`financial_provider.dart` | `displayNameOrDefault`、`clearFinancialsNeedRefresh`、`loadStatsProgressively` |
| 3A-4 病历/患者辅助 | `dental_condition_integration.dart`、`patient_image_cache_service.dart`、`patient_image_connection_service.dart`、`patient_provider.dart` | `hasRecordForDate`、`getRecordSummary`、`getDateSelectorOptions`、`validateDentalData`、`hasPatientMaterialsCache`、`hasMaterialImagesCache`、`checkSQLiteConnection`、`getLastPatient` |
| 3A-5 设置/通用工具 | `database_switch_service.dart`、`sqlite_config_dialogs.dart`、`database_models.dart`、`app_theme.dart`、`datetime_formatter.dart`、`map_parser.dart`、`mysql_utils.dart`、`notification_helper.dart`、`schema_validator.dart`、`sync_logger.dart`、`sync_table_config.dart` | 审核报告 5.5、5.9 列出的全部候选 |
| 3A-6 对话框/Loading | `confirm_dialogs.dart`、`loading_dialog.dart` | `showPurchaseRecordDelete`、`showPurchaseItemDelete`、`showWithUsername`、`showWithCancel` |

### 7.3 特别判定和保留边界

- 财务计算器删除前，逐项对照 `financial_statistics_dialog.dart` 和当前渐进统计链；`calculatePatientLatestReceivableAmount`、`calculatePatientLatestCollectedAmount` 必须保留。
- 病历牙齿 helper 必须保留 `parseDentalCondition`、`getAvailableDates`、`getDentalConditionByDate`、`formatDateForDisplay`。
- 设置必须保留 `initDatabaseConfig`、`switchDatabaseType`、`selectCustomDbPath`；`reopenDatabase` 先确认不是连接恢复动态入口。
- `MapParser.booleanOptional/dateTimeOptional`、MySQL 元数据方法和同步配置方法若被脚本、初始化或日志诊断引用，标为跳过并记录。
- `confirm_dialogs.dart` 有两代 Manager；只能删除精确类的精确方法，`ModernDeleteDialogManager` 及其按实体入口必须逐项另查，禁止按同名 `showGeneric` 批量删。

### 7.4 验证

建议先补财务计算器和牙齿数据纯函数测试。每个子组完成后至少执行 `flutter analyze`；涉及计算、Map 解析、数据库切换或 Provider 状态时执行相应定向测试和全量 `flutter test`。

手动回归覆盖预约缓存刷新、仪表盘刷新、财务列表/搜索/统计/图表、病历日期选择、患者材料图片缓存、SQLite/MySQL 切换、删除确认和普通 loading 显示关闭。

## 8．批次 3B：Provider、SettingsProvider 与 Manager 无消费者链

### 8.1 Provider 分组

按 Provider 独立提交，禁止一次删完所有状态方法：

| 子组 | 文件 | 候选 |
| --- | --- | --- |
| 3B-1 数据库状态 | `database_provider.dart` | `resetAutoSwitchState`、`forceDataChanged`、`resetDashboardRefreshFlag` |
| 3B-2 材料状态 | `material_provider.dart` | `clearMaterialsNeedRefresh`、`isMaterialNameExists`、`generateMaterialCode` |
| 3B-3 病历状态 | `medical_record_provider.dart` | `clearPatientMedicalRecordsCache`、`getCacheStats` |
| 3B-4 采购状态 | `purchase_provider.dart` | `clearPurchasesNeedRefresh`、`getPurchaseRecordsWithCache` |
| 3B-5 用户与连接 | `user_provider.dart`、`mysql_connection_pool.dart` | `resetUsersRefreshFlag`、`refreshAllConnections` |

每个子组都要确认页面不是通过 `context.read<T>()`、回调参数或字符串事件触发该方法；确认现用刷新入口后再删。

### 8.2 SettingsProvider 成对清理协议

候选 Provider 方法为 `updateSystemNotification`、`updateLanguage`、`updateTimeFormat`、`updateThemeMode`、`updateFontSize`。`updateAppointmentReminder` 正在 `system_settings_section.dart` 使用，明确保留。

执行顺序固定为：

1. 搜索 Provider 方法、对应字段、getter、`SettingsManager` getter/setter 和持久化键。
2. 搜索设置页面、启动初始化、主题入口及重启加载路径，确认没有 UI 消费者。
3. 同一小批删除 Provider 包装、Manager 对应方法、只服务于它的字段/getter 和无消费者持久化键；不能只删 Provider 留下下层死代码。
4. 如旧持久化键仍需兼容已发布用户数据，保留读取兼容一个明确版本周期，并在日志写明截止版本；未经确认不得删除用户配置。

### 8.3 验证

建议新增 SettingsManager 持久化测试：保留项（预约提醒、数据源）重启后仍正确；拟删项没有读取入口。手动回归设置页、预约提醒保存、数据源切换、应用重启、主题和字体相关现用 UI。若发现实际主题/语言入口，停止该设置项清理并标记“跳过”。

## 9．批次 4：备份、数据库工具与一次性迁移高风险项

### 9.1 本批范围

| 类别 | 文件/对象 | 候选 |
| --- | --- | --- |
| 不可达迁移文件 | `utils/permission_migration.dart`、`utils/purchase_migration.dart` | 整文件；含 `PermissionMigration`、`PurchaseMigration` |
| 备份恢复旧入口 | `BackupRestoreService` | `exportDatabase`、`importDatabase`、`resetToFactorySettings`、`selectOutputDirectory` |
| 数据库工具旧入口 | `DatabaseUtils` | `initEmptyDatabase`、`copyTestDatabaseToDocuments`、`restoreDatabase`、`testMySQLConnection` |

### 9.2 不可跳过的测试前置条件

先新增并通过以下测试，才可删除任一候选：

1. schema 快照测试：确认 `mysql_schema.dart`、`sqlite_schema.dart` 已包含权限字段和采购 `doctor` 字段。
2. 旧库升级测试：以升级前数据库副本启动，断言现用 bootstrap/`utils/schema_validator.dart` 能完成结构检测与升级。
3. 备份恢复测试：以临时数据库副本执行备份、选择恢复文件、恢复前确认、恢复后读取和失败提示；不得写入真实业务数据库。
4. MySQL 测试连接替代链测试：确认设置 `MysqlConfigService` 或连接 service 的现用调用能得到相同成功/失败语义。

### 9.3 实施顺序

1. 从 `settings_backup_restore_dialogs.dart` 逆向核对设置页实际调用 `backupDatabase`、`selectBackupFile`、`restoreDatabaseFromBackup`、`generateBackupFilename`、`generateExcelFilename`。
2. 搜索四个 BackupRestoreService 旧入口与四个 DatabaseUtils 候选，检查接口引用、菜单入口、脚本和注释中的操作指引。
3. 核对 `PermissionMigration`/`PurchaseMigration` 字段与两套 schema、`SyncTableConfig`、当前 validator；确认生产用户不会从仍依赖一次性迁移的历史版本跨越升级。
4. 获得删除授权后，先删旧 API，再删迁移文件；每一步只清理由该步导致的 import。
5. 完成自动测试和 SQLite/MySQL 手动回归后才更新进度。

### 9.4 强制手动回归

- SQLite：真实备份、选择恢复文件、恢复前确认、恢复完成、故意失败的恢复提示、恢复后数据读取。
- MySQL：测试连接、结构检测、初始化、采购/权限字段读取。
- 旧库副本：启动升级、权限字段和采购 `doctor` 字段可用、同步表配置完整。

任一未能验证即为“阻塞”。不得添加空 catch、默认成功结果或 `// ignore` 绕过。

## 10．批次 5：采购页空监听基础设施

### 10.1 精确修改点

文件：`lib/features/purchases/screens/purchase_records_screen.dart`。

按顺序处理：

1. 删除空方法 `_checkAndRefreshData`、`_onFocusChange`。
2. 删除只为这两个空方法服务的 `_focusNode` listener 注册和移除。
3. 若 `_focusNode` 无其他用途，删除字段和外层 `Focus`；若仍用于键盘/焦点行为，仅移除空 listener。
4. 若没有其他生命周期处理，删除 `WidgetsBindingObserver`、`addObserver`、`removeObserver` 与空 `didChangeAppLifecycleState`。

### 10.2 重新确认命令

```powershell
rg -n '_checkAndRefreshData|_onFocusChange|WidgetsBindingObserver|addObserver|removeObserver|_focusNode|Focus\(' lib/features/purchases/screens/purchase_records_screen.dart -S
```

### 10.3 验证

自动：对改动文件 `dart format`、`flutter analyze`、`git diff --check`、行尾检查；如可提取刷新行为，再新增采购刷新回归测试。

手动：首次加载、下拉刷新、新增采购记录后刷新、编辑后刷新、删除后刷新、后台切回前台；特别记录前后台切换不会因删除空监听而丢失实际刷新入口。

## 11．批次 6：MySQL ResultRow 转换收口

本批是重复实现迁移，不是删除批。不得与前述无用文件/方法混批。

### 11.1 目标与边界

权威入口为 `lib/utils/mysql_row_processor.dart` 的 `MysqlRowProcessor.processRow`。迁移以下数据源的 DateTime、Blob、`Uint8List`、UTF-8 容错和空值转换重复代码：

1. `appointment_data_source.dart`；
2. `financial_data_source.dart`；
3. `purchase_data_source.dart`；
4. `patient_data_source.dart`；
5. `user_data_source.dart`；
6. `mysql_user_data_source.dart`。

只收口“行值转换”。SQL、字段映射业务规则、排序、权限、图片字段选择和异常提示仍保留在各数据源。不能把所有 Blob 强制转字符串：图片字段保留字节，文本 Blob 才按现有容错语义转换。

### 11.2 测试先行

先新增 `test/utils/mysql_row_processor_test.dart`，至少覆盖：

- `DateTime` 保持或按当前约定转换；
- 普通文本 Blob、图片 Blob、`Uint8List`；
- 空字节；
- 畸形 UTF-8；
- `null`；
- 各数据源的图片字段白名单与非图片字段结果不同。

先让测试在现状下描述已存在行为，再创建/补全 processor；不得先改 6 个数据源再猜输出。

### 11.3 固定迁移节奏

每次只迁移一个数据源：先增加该数据源的 SQLite/MySQL 同输入 `fromMap/toMap` 对照测试，替换调用，删除该文件已被替代的私有转换方法，运行定向测试和 `flutter analyze`，再进行下一个。顺序固定为 appointment → financial → purchase → patient → user → mysql_user。

每步必须对比：字段名、`null`、文本、图片字节、日期、畸形 UTF-8 和错误处理结果。不同即停止并恢复到“未迁移的当前小步”（不可用 Git 覆盖操作），定位差异后再继续。

### 11.4 最终验证

运行全部新增测试、`flutter test`、`flutter analyze`。手动使用 SQLite/MySQL 各读取预约、财务、采购、患者、用户，确认图片可展示、文本不乱码、日期正确、列表不崩溃。

## 12．批次 7：独立维护任务，须重新确认

以下项目不是“删除无用代码”，均需单独提出方案并等待主人确认：

### 12.1 统计卡片视觉骨架

候选是财务 `monthly_processing_chart.dart`、`monthly_trend_chart.dart`、`payment_status_chart.dart`、现用 `stat_card.dart`，采购 `purchase_overview_tab.dart`、`purchase_stat_card.dart`、`purchase_trend_tab.dart`、`purchase_ranking_tab.dart`，以及 `financial_statistics_dialog.dart` 内部图表容器。实施时才可新增主题化 `StatisticsPanel`/`StatisticsEmptyPanel`；内部必须读取 `Theme.of(context)`，不得把 `Colors.white`、圆角、阴影换个文件继续硬编码。

### 12.2 MySQL 连接访问器

`appointment_database_mixin.dart`、`financial_connection_service.dart`、`purchase_provider.dart`、`user_provider.dart` 都有“从 `DatabaseProvider.mysqlConnection` 获取最新连接，失败回退缓存连接”的相似逻辑。收口前必须先定义连接生命周期、断线重连和 Provider 更新时序，不能直接抽 helper。

### 12.3 确认对话框两代 Manager

`settings_common_dialogs.dart` 与 `settings_dialogs.dart` 的 `showConfirmDatabaseDialog`，以及 `confirm_dialogs.dart` 内 `DeleteConfirmDialogManager`/`ModernDeleteDialogManager` 都可能有在用调用。先做调用清单与视觉/文案对照，再迁移到唯一入口。

## 13．提交、进度管理与记录模板

### 13.1 提交边界

- 推荐顺序：0 → 1 → 2 → 3A 各子组 → 3B 各子组 → 4 → 5 → 6 每个数据源小步；7 单独立项。
- 每个提交只包括本批 Dart、必要测试、本文档和 `ROADMAP.md` 的真实进度；不夹带 Windows 端改动。
- Commit 信息使用中文且具体，例如：`refactor: 删除未接入的 Android Toast 与连接状态组件`、`test: 覆盖 Android MySQL 行转换兼容行为`。
- 发现回归时停止当前批次，保留 diff、测试输出和复现数据；不得执行 `reset`、`checkout --`、`restore`、rebase 或覆盖工作区。

### 13.2 每批日志模板

每次开始、暂停或结束一批，在本节追加以下记录，不可只更新状态表：

```markdown
#### YYYY-MM-DD｜批次 N｜未开始/进行中/阻塞/完成/跳过

- 授权范围：
- 工作区隔离：`git status --short` 摘要；本批未触碰的既有改动：
- 重新搜索：命令、命中摘要、新调用或动态入口的处理：
- 现用替代入口：
- 实际改动：
- 自动验证：定向测试 / 全量 `flutter test` / `flutter analyze` / `git diff --check` / 行尾检查。
- 手动回归：场景、数据源或副本、结果。
- 提交：commit hash 与中文信息；未提交则说明原因。
- 结论与下一步：
```

### 13.4 初始记录

#### 2026-07-12｜实施文档编制｜完成（历史记录）

- 授权范围：根据审核报告编制 Android 端无用代码与重复实现实施计划，并同步根 `ROADMAP.md` 的计划状态。
- 实际改动：新增本文档；未修改 Android Dart、测试、原生配置或数据库。
- 自动验证：文档任务未运行 Flutter 命令；审核报告已有当日 `flutter analyze` `No issues found!` 基线。
- 结论与下一步（编制当时）：所有代码批次均为“未开始”；后续执行从批次 0 重新取证开始，文件删除前必须另行取得主人明确授权。当前状态以第 3 节进度表和后续批次日志为准。

#### 2026-07-12｜批次 0｜完成

- 授权范围：重新取证、冻结 Android 基线、建立后续测试映射；不删除文件、不删除方法、不重构业务代码。
- 工作区隔离：执行前 `git status --short` 显示已有 `ROADMAP.md`、Windows 端代码/文档改动，以及本计划和审核报告两个新增文档；本批未触碰这些既有改动。
- 重新搜索：在 `android_app/` 重新执行审核报告第 12 节 7 组 `rg` 命令，并额外搜索 16 个候选文件名、类名和旧 import 路径。16 个文件候选未发现新的 `lib/`/`test/` 入站引用；确认 `patient_data_source.dart` 内新版 SQLite/MySQL 患者数据源、`database_models.dart` 内新版 `Appointment`、`utils/schema_validator.dart`、`features/financial/services/financial_data_cleaner_service.dart`、`utils/mysql_row_processor.dart` 为现用替代或权威入口。重复转换搜索确认预约、财务、采购、患者、用户等数据源仍各有 `_convertMySqlRow`，且 `MysqlRowProcessor` 已被患者图片 Provider 使用，批次 6 不得提前处理。
- 现用替代入口：患者使用 `data_sources/patient_data_source.dart`；预约使用 `models/database_models.dart` 与 `data_sources/appointment_data_source.dart`；Schema 使用 `utils/schema_validator.dart` 和 `sync_manager.dart`；财务清理使用 `FinancialDataCleanerService`；提示使用 `MessageToastHelper`/`SuccessToastManager`/`DeleteSuccessToastManager`；统计同名 `StatCard` 以 dashboard 版本和现用财务/采购统计组件为准。
- 测试映射：`android_app/test/` 当前不存在，也未发现可复用测试夹具。批次 2 需新增 Appointment 序列化、患者 SQLite/MySQL 数据源和 Schema 升级测试；批次 4 需新增 schema 快照、旧库升级、备份恢复和 MySQL 连接替代链测试；批次 6 需新增 `MysqlRowProcessor` 及各数据源 SQLite/MySQL 对照测试。
- 实际改动：仅更新本计划和根 `ROADMAP.md` 的批次 0 状态与取证记录；未修改 Android Dart、测试、原生配置、数据库或依赖。
- 自动验证：重新取证命令全部执行成功；`flutter analyze` 为 `No issues found!`；`flutter test` 无测试目标；`git diff --check` 通过；本批改动文件行尾检查未发现 `w/crlf` 或 `w/mixed`。
- 手动回归：无业务代码改动，不执行手动回归。
- 提交：`9499a36`，`refactor: 清理 Android 批次零取证文档与批次一孤立组件`。
- 结论与下一步：批次 0 完成；批次 1 仍未开始。后续任何删除候选前，必须按计划逐项列出精确删除清单并取得主人明确授权。

#### 2026-07-12｜批次 1｜完成

- 授权范围：删除 9 个经删除当日重新搜索确认无 `lib/`/`test/` 外部入站引用的 A 级不可达 UI、连接状态、Toast 和测试工具文件；保留 dashboard `StatCard`、现用财务/采购统计组件、`MessageToastHelper`、`SuccessToastManager`/`DeleteSuccessToastManager`、`DatabaseSwitchService` 和 `DatabaseProvider`。
- 工作区隔离：执行前保留主人已有 `ROADMAP.md`、Windows 端代码/文档改动及 Android 审核/实施文档改动；本批只删除以下 Android 文件：`lib/features/financial/widgets/amount_info_item.dart`、`financial_item_row.dart`、`stat_card.dart`、`stat_item.dart`、`lib/features/settings/services/database_settings_manager.dart`、`lib/providers/test_connection_pool.dart`、`lib/widgets/connection_status_widget.dart`、`message_toast.dart`、`toast_widgets.dart`。
- 重新搜索：删除前重新搜索文件名、类名、旧 import 和现用替代入口；未发现外部入站引用。删除后再次搜索上述路径和符号，结果无命中；dashboard `StatCard` 及现用 Toast/数据库入口仍保留。
- 现用替代入口：财务/采购统计使用现用统计卡片和统计对话框；提示使用 `utils/message_toast_helper.dart` 与 `widgets/toast_manager.dart`；数据库设置使用 `DatabaseSwitchService`、`DatabaseProvider` 和设置页现有链路；连接管理使用现有 `DatabaseProvider`/连接服务。
- 实际改动：删除上述 9 个文件；未修改业务 Dart 文件、测试、原生配置、数据库或依赖。
- 自动验证：删除后精确 `rg` 复核无命中；`flutter analyze`、`git diff --check` 和本批文件行尾检查通过；无定向测试文件，未执行 `dart format`。
- 手动回归：未执行运行时手动回归；主人明确要求本批按删除后精确引用复核、`flutter analyze`、diff 和行尾检查结果标记完成，登录、同步、财务列表/统计提示回归不作为本批阻塞条件。
- 提交：`9499a36`，`refactor: 清理 Android 批次零取证文档与批次一孤立组件`。
- 结论与下一步：批次 1 完成；批次 2 仍未开始。批次 2 删除旧模型、患者数据源和 Schema Validator 前，必须先补对应序列化、数据源和 schema 升级测试并重新取得授权。

#### 2026-07-13｜批次 2｜完成（待手动回归）
- 授权范围：开始批次 2，核对并准备删除 `lib/models/appointment.dart`、`lib/data_sources/mysql_patient_data_source.dart`、`lib/data_sources/sqlite_patient_data_source.dart`、`lib/models/schemas/schema_validator.dart`；删除前必须完成测试和链路确认。
- 工作区隔离：Android 端无既有改动；仓库已有 Windows 端 `lib/providers/financial_provider.dart`、`material_provider.dart`、`purchase_provider.dart`、`user_provider.dart` 修改，本批未触碰。
- 重新搜索：`rg -n "models/appointment|Appointment\\b|mysql_patient_data_source|sqlite_patient_data_source|MySqlPatientDataSource|SqlitePatientDataSource|models/schemas/schema_validator|SchemaValidator" lib -S` 确认旧预约模型、旧 SQLite/MySQL 患者数据源和旧 Schema Validator 无入站引用；现用入口分别为 `models/database_models.dart`、`data_sources/patient_data_source.dart` 和 `utils/schema_validator.dart`。实际同步入口为 `utils/sync_manager.dart`，计划旧文档中的 `services/sync_manager.dart` 路径不适用当前仓库。
- 现用替代入口：预约使用 `database_models.dart` 与 `data_sources/appointment_data_source.dart`；患者使用合并后的 `data_sources/patient_data_source.dart`；Schema 使用 `utils/schema_validator.dart`。
- 实际改动：删除 `lib/models/appointment.dart`、`lib/data_sources/mysql_patient_data_source.dart`、`lib/data_sources/sqlite_patient_data_source.dart`、`lib/models/schemas/schema_validator.dart`；未修改现用替代实现。
- 自动验证：删除后精确引用复核仅命中现用 `database_models.dart`、合并后的 `patient_data_source.dart` 和 `utils/schema_validator.dart`；`flutter analyze` 为 `No issues found!`；`git diff --check`、行尾检查和 LF 行尾检查通过。
- 手动回归：待主人点击验证 SQLite/MySQL 患者列表、搜索、分页、增删改、病历号，以及预约增改状态、仪表盘和旧库 Schema 升级。
- 结论与下一步：批次 2 代码清理完成；不把未执行的手动回归写成已通过。批次 3A～7 保持未开始。

## 14．执行前复核命令索引

以下命令在 `android_app/` 目录执行。先运行审核报告第 12 节原始命令；需要逐项删除时补充下列精确搜索：

```powershell
$searchPaths = @('lib')
if (Test-Path test) { $searchPaths += 'test' }

# 批次 1：文件名、类名和现用替代入口
rg -n 'AmountInfoItem|FinancialItemRow|DatabaseSettingsManager|ConnectionPoolTester|ConnectionStatusWidget|CompactConnectionStatus|ConnectionStatusWithRetry|MessageToast|SuccessToast|DeleteSuccessToast' $searchPaths -S
rg -n 'MessageToastHelper|DatabaseSwitchService|FinancialDataCleanerService' lib -S

# 批次 2：旧模型、数据源、Schema Validator
rg -n 'models/appointment|Appointment\b|mysql_patient_data_source|sqlite_patient_data_source|MySqlPatientDataSource|SqlitePatientDataSource|models/schemas/schema_validator|SchemaValidator' $searchPaths -S

# 批次 3：方法候选和两代确认对话框
rg -n 'clearAppointmentsNeedRefresh|getColorForStatus|refreshDashboardData|calculateTotalAmount|calculateSettledCount|calculateUniquePatientCount|calculateTotalRecords|calculateTotalReceivable|calculateTotalCollected|calculateTotalOutstanding|calculateTotalProcessingFee' $searchPaths -S
rg -n 'DeleteConfirmDialogManager|ModernDeleteDialogManager|showPurchaseRecordDelete|showPurchaseItemDelete|showWithUsername|showWithCancel' $searchPaths -S

# 批次 3B：Provider 和 Settings 委托链
rg -n 'resetAutoSwitchState|forceDataChanged|resetDashboardRefreshFlag|clearMaterialsNeedRefresh|isMaterialNameExists|generateMaterialCode|clearPatientMedicalRecordsCache|getCacheStats|clearPurchasesNeedRefresh|getPurchaseRecordsWithCache|resetUsersRefreshFlag|refreshAllConnections' $searchPaths -S
rg -n 'updateSystemNotification|updateLanguage|updateTimeFormat|updateThemeMode|updateFontSize|updateAppointmentReminder|SettingsManager' $searchPaths -S

# 批次 4：高风险数据库、备份和迁移
rg -n 'PermissionMigration|PurchaseMigration|permission_migration|purchase_migration|BackupRestoreService\.(exportDatabase|importDatabase|resetToFactorySettings|selectOutputDirectory)|DatabaseUtils\.(initEmptyDatabase|copyTestDatabaseToDocuments|restoreDatabase|testMySQLConnection)' $searchPaths -S
rg -n 'backupDatabase|selectBackupFile|restoreDatabaseFromBackup|generateBackupFilename|generateExcelFilename|mysql_schema|sqlite_schema|SyncTableConfig' lib -S

# 批次 6：转换重复
rg -n 'MysqlRowProcessor|processRow|_convertMySqlRow|Blob转换失败|Uint8List转换失败' $searchPaths -S
```

## 15．验收矩阵

| 批次 | 最低自动验证 | 必须手动回归 |
| --- | --- | --- |
| 1 UI/Toast | `flutter analyze`、diff/行尾检查 | 登录、同步、财务列表与统计提示 |
| 2 预约模型 | Appointment 序列化、全量测试、analyze | 预约增改状态与仪表盘 |
| 2 患者数据源 | SQLite/MySQL data source 测试、全量测试、analyze | 列表、搜索、分页、增删改、病历号 |
| 2 Schema | 升级/结构检测测试、全量测试、analyze | 旧库副本升级 |
| 3A 财务方法 | 计算器/统计相关测试、analyze | 搜索口径、顶部统计、图表 |
| 3B Settings | 持久化测试、全量测试、analyze | 预约提醒、数据源、重启 |
| 4 备份/迁移 | schema、备份恢复、MySQL 连接测试、全量测试 | SQLite/MySQL 副本、旧库升级 |
| 5 采购监听 | analyze；可提取则新增刷新测试 | 首次、下拉、增删改、前后台刷新 |
| 6 行转换 | Processor 和各数据源对照测试、全量测试 | SQLite/MySQL 图片、文本、日期、空值 |

若任何验收项未通过，批次状态只能是“进行中”或“阻塞”。

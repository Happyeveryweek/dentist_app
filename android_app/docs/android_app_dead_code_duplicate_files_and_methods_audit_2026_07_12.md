# Android 端无用文件、无用方法与重复实现审核报告

## 1. 文档定位

审核日期：2026-07-12。

审核范围：`android_app/lib/**/*.dart`，并检查 `android_app/test/`、`pubspec.yaml`、现有 `android_app/docs` 和根 `ROADMAP.md`。不包含 Android 原生 Gradle、签名、权限和发布配置。

本报告只提供证据和可执行清理方案。本轮没有删除 Android 文件、没有修改 Android 业务代码、没有改变数据库 schema、路由或 Provider 架构。

目标是让后续任意模型能够按照本报告逐批执行，而不需要重新猜测：

- 哪些完整文件从应用入口不可达。
- 哪些公有方法只有声明、没有 UI/service/test 调用。
- 哪些旧兼容 API 已被现用入口替代。
- 哪些代码正在使用但存在多份重复实现，应收口而不能直接删除。
- 每批应运行哪些搜索、测试、静态检查和手动回归。

## 2. 当前基线

- `lib/` Dart 文件：288 个。
- `lib/` Dart 代码：约 62771 行。
- 从 `lib/main.dart` 可达：272 个文件。
- 从 `lib/main.dart` 不可达：16 个文件，共约 2203 行。
- `test/**/*.dart`：0 个。当前 Android 端没有自动化测试文件。
- `flutter analyze`：2026-07-12 实际运行，结果 `No issues found!`。
- 未发现 `unused_import`、`duplicate_import` 或无法解析 import。

重要结论：analyzer 全绿只证明当前编译图内的语法、类型和 lint 基线正常；它不会把未导入的完整 Dart 库或未使用的公有 API 全部报告出来。

## 3. 判定等级

### 3.1 A 级：可直接进入删除批次

满足以下条件：

- 文件不在 `main.dart` 的 `import/export/part` 可达图中，且没有测试导入；或方法在 `lib/`、`test/` 中只有声明命中。
- 不是接口方法、override、Flutter 生命周期、序列化入口、数据库回调或动态注册入口。
- 已找到当前实际使用的替代路径，或确认该能力从未接入。

### 3.2 B 级：静态不可达，但删除前必须补测试或手动回归

适用于数据库、备份恢复、登录、权限、同步、历史迁移和大块业务组件。Android 当前没有测试文件，因此 B 级不能仅以 `flutter analyze` 通过作为删除完成证据。

### 3.3 C 级：重复实现治理

多份代码都在使用，不能任选一份删除。需要先建立共享 helper/service/widget，再逐个迁移调用方。

## 4. 文件级审核：16 个完整不可达文件

### 4.1 旧患者数据源双实现（B，528 行）

候选文件：

- `lib/data_sources/mysql_patient_data_source.dart`：约 345 行。
- `lib/data_sources/sqlite_patient_data_source.dart`：约 183 行。

现用路径：

- `lib/data_sources/patient_data_source.dart` 同时定义 `PatientDataSource`、`SqlitePatientDataSource`、`MySqlPatientDataSource`。
- `patient_initialization_service.dart` 和 `patient_provider.dart` 导入的是 `patient_data_source.dart`。
- 两个候选文件没有任何入站 import。

判断：这是明确的患者数据源新旧双实现。旧文件与现用合并文件还复制了分页排序、患者 SQL、拼音和 MySQL 行转换逻辑。

删除前验证：SQLite/MySQL 患者列表、搜索、分页、排序、新增、编辑、删除和病历号生成。

### 4.2 旧财务清理工具（B，184 行）

候选：`lib/features/financial/utils/financial_data_cleaner.dart`。

包含 `FinancialDataCleaner` 和 `FinancialCleanupWidget`，只在本文件内部互相引用。

现用路径：`FinancialProvider` 使用 `FinancialDataCleanerService`，文件位于 `lib/features/financial/services/financial_data_cleaner_service.dart`。

处理：删除旧 widget/util 文件，保留现用 service。回归财务无效数据检测、清理提示和重新加载。

### 4.3 旧财务显示组件子图（A，248 行）

候选：

- `amount_info_item.dart`：34 行。
- `financial_item_row.dart`：105 行。
- `stat_card.dart`：66 行。
- `stat_item.dart`：43 行。

四个文件均无入站 import，顶层组件只在自身定义文件出现。注意项目还有 dashboard 的 `StatCard` 和采购统计卡片，删除时只能删除上述精确路径。

### 4.4 未接入的数据库设置 Manager（A，35 行）

候选：`features/settings/services/database_settings_manager.dart`。

`DatabaseSettingsManager` 没有构造或 Provider 注册调用。当前数据库配置由 `DatabaseSwitchService`、`DatabaseProvider` 和设置页状态共同管理。

### 4.5 旧 Appointment 模型（A/B，125 行）

候选：`lib/models/appointment.dart`。

现用路径：

- `lib/models/database_models.dart` 约第 860 行定义当前 `Appointment`。
- `appointment_data_source.dart`、`appointments_provider.dart` 和预约页面导入 `database_models.dart`。
- 旧 `models/appointment.dart` 没有入站 import。

处理：删除旧模型前检查是否有文档或脚本仍引用该路径；运行预约新增、编辑、状态更新、列表和仪表盘回归。

### 4.6 旧 schema validator（B，142 行）

候选：`lib/models/schemas/schema_validator.dart`。

现用路径：`lib/utils/schema_validator.dart` 被 `sync_manager.dart` 使用，负责真实结构验证和升级。

两个文件都定义 `SchemaValidator`，但旧 models 文件无入站引用。删除时保留 `utils/schema_validator.dart`。

### 4.7 生产目录中的连接池测试代码（A，47 行）

候选：`lib/providers/test_connection_pool.dart`，类 `ConnectionPoolTester`。

该文件既没有运行时入口，也不在 Flutter `test/` 目录。可删除；如果未来需要连接池测试，应在 `test/providers/` 创建使用 fake/受控连接的测试，不把测试工具留在生产代码。

### 4.8 已脱离启动链的一次性迁移文件（B，287 行）

候选：

- `utils/permission_migration.dart`：201 行。
- `utils/purchase_migration.dart`：86 行。

两个文件均无入站 import，`PermissionMigration`、`PurchaseMigration` 只在定义文件出现。

风险：它们包含 SQLite/MySQL 字段迁移 SQL。删除前必须：

1. 检查当前 schema 定义已经包含权限字段和采购 `doctor` 字段。
2. 使用旧版本数据库副本启动一次，确认现有 bootstrap/schema validator 能升级。
3. 确认生产用户不会再跨越需要这两个一次性迁移的历史版本。

### 4.9 未接入连接状态组件（A，122 行）

候选：`widgets/connection_status_widget.dart`。

其中 `ConnectionStatusWidget`、`CompactConnectionStatus`、`ConnectionStatusWithRetry` 都只在本文件出现。当前连接状态由登录页、设置页和现有连接 service 的专用 UI 表达。

### 4.10 旧消息 Toast 实现（A，251 行）

候选：`widgets/message_toast.dart`。

该文件包含 Overlay 版 `MessageToast` 和一份旧 `MessageToastHelper`。当前调用方统一导入 `utils/message_toast_helper.dart`，使用 `ScaffoldMessenger`；旧文件无入站 import。

这是明确的双实现。删除旧文件，保留 `utils/message_toast_helper.dart`。

### 4.11 旧成功/删除 Toast widgets（A，234 行）

候选：`widgets/toast_widgets.dart`。

其中 `SuccessToast`、`SuccessToastBottom`、`DeleteSuccessToast`、`DeleteSuccessToastBottom` 均无外部调用。当前提示链使用 `MessageToastHelper`、SnackBar 或确认对话框。

## 5. 方法级审核：A 级无调用方法

以下符号在 `lib/` 与 `test/` 中只有声明命中。执行时仍要重新搜索，避免报告生成后出现新调用。

### 5.1 预约与仪表盘

- `appointment_cache_mixin.dart`：`clearAppointmentsNeedRefresh`。
- `appointment_status_helper.dart`：`getColorForStatus`。
- `dashboard_screen.dart`：`refreshDashboardData`。

保留预约 cache 中正在使用的 `forceRefreshAppointments` 等入口。

### 5.2 财务计算旧汇总 API

文件：`features/financial/services/financial_calculator.dart`

无调用方法：

- `calculateTotalAmount`。
- `calculateSettledCount`。
- `calculateUniquePatientCount`。
- `calculateTotalRecords`。
- `calculateTotalReceivable`。
- `calculateTotalCollected`。
- `calculateTotalOutstanding`。
- `calculateTotalProcessingFee`。

现用页面只调用 `calculatePatientLatestReceivableAmount` 和 `calculatePatientLatestCollectedAmount`。这些旧汇总方法很可能来自统计口径调整前的实现，删除前需要对照 `financial_statistics_dialog.dart` 和当前渐进统计链。

其他无调用财务方法：

- `financial_payment_method_helper.dart`：`displayNameOrDefault`。
- `financial_provider.dart`：`clearFinancialsNeedRefresh`、`loadStatsProgressively`。

### 5.3 病历牙齿数据旧 helper

文件：`features/medical_records/utils/dental_condition_integration.dart`

候选：

- `hasRecordForDate`。
- `getRecordSummary`。
- `getDateSelectorOptions`。
- `validateDentalData`。

保留正在使用的 `parseDentalCondition`、`getAvailableDates`、`getDentalConditionByDate`、`formatDateForDisplay`。

### 5.4 患者图片缓存与连接

候选：

- `patient_image_cache_service.dart`：`hasPatientMaterialsCache`、`hasMaterialImagesCache`。
- `patient_image_connection_service.dart`：`checkSQLiteConnection`。
- `patient_provider.dart`：`getLastPatient`。

现用缓存直接使用 `getPatientMaterialsCache/getMaterialImagesCache`，连接恢复使用 `checkConnectionOnResume`。

### 5.5 设置与数据库切换旧方法

候选：

- `database_switch_service.dart`：`selectCustomDbPathAlternative`、`saveDatabaseConfig`、`isUsingCachePath`。
- `sqlite_config_dialogs.dart`：`showSqliteConfigSavedDialogWithLoadOption`。
- `database_models.dart` 中数据库类：`reopenDatabase`。

现用设置页使用 `initDatabaseConfig`、`switchDatabaseType`、`selectCustomDbPath`。

### 5.6 Provider 状态辅助旧方法

候选：

- `database_provider.dart`：`resetAutoSwitchState`、`forceDataChanged`、`resetDashboardRefreshFlag`。
- `material_provider.dart`：`clearMaterialsNeedRefresh`、`isMaterialNameExists`、`generateMaterialCode`。
- `medical_record_provider.dart`：`clearPatientMedicalRecordsCache`、`getCacheStats`。
- `purchase_provider.dart`：`clearPurchasesNeedRefresh`、`getPurchaseRecordsWithCache`。
- `user_provider.dart`：`resetUsersRefreshFlag`。
- `mysql_connection_pool.dart`：`refreshAllConnections`。

这些方法涉及 Provider 状态，按模块单独删除，不要一次修改全部 Provider。

### 5.7 SettingsProvider 未接入设置项

无 UI 消费者：

- `updateSystemNotification`。
- `updateLanguage`。
- `updateTimeFormat`。
- `updateThemeMode`。
- `updateFontSize`。

`updateAppointmentReminder` 正在 `system_settings_section.dart` 使用，必须保留。

执行时成对检查 `SettingsManager` 中对应 getter/setter。如果语言、时间格式、主题、字号、系统通知只被 Provider 内部包装调用，则应同步删除 Provider 方法、Manager 方法、无用字段和持久化键；不要只删一层留下新死代码。

### 5.8 连接、同步和初始化旧入口

候选：

- `database_sync_service.dart`：`checkAndSyncData`。
- `mysql_connection_service.dart`：`initWithParams`、`resetConnection`。
- `mysql_reconnect_service.dart`：`setOnReconnectFailed`、`resetReconnectState`。
- `sqlite_initialization_service.dart`：`ensureDatabasePath`。
- `connection_manager.dart`：`checkConnection`。

保留实际调用的 `checkConnectionOnAppResume`、`manualReconnect`、`smartConnectionCheck`、health monitoring 等路径。

### 5.9 通用工具无调用方法

- `theme/app_theme.dart`：`inputDecoration`。
- `utils/datetime_formatter.dart`：`isValidDbFormat`。
- `utils/map_parser.dart`：`booleanOptional`、`dateTimeOptional`。
- `utils/mysql_utils.dart`：`checkTablesExist`、`getTableCount`、`getLastUpdateTime`。
- `utils/notification_helper.dart`：`showDatabaseSwitchNotification`。
- `utils/schema_validator.dart` 的结果对象：`getDetails`。
- `utils/sync_logger.dart`：`getLogById`、`getLogStats`。
- `utils/sync_table_config.dart`：`isSyncTable`、`getTableSchema`。

### 5.10 确认对话框未使用入口

文件：`widgets/confirm_dialogs.dart`

候选：

- `DeleteConfirmDialogManager.showPurchaseRecordDelete`。
- `DeleteConfirmDialogManager.showPurchaseItemDelete`。
- `LogoutConfirmDialogManager.showWithUsername`。

文件内还存在 `ModernDeleteDialogManager` 及其 `showPatientDelete/showAppointmentDelete/showPurchaseDelete/showUserDelete/showGeneric`。这些入口不能仅按同名搜索批量删除；先确认各页面实际使用的 manager 类。

### 5.11 LoadingDialog 未接入取消版

文件：`widgets/loading_dialog.dart`

候选：`showWithCancel`。保留正在使用的普通 loading 显示/关闭入口。

## 6. 方法级审核：B 级高风险候选

### 6.1 BackupRestoreService 的两套备份/恢复 API

当前真实设置页使用：

- `backupDatabase`。
- `selectBackupFile`。
- `restoreDatabaseFromBackup`。
- `generateBackupFilename`。
- `generateExcelFilename`。

无调用旧入口：

- `exportDatabase`。
- `importDatabase`。
- `resetToFactorySettings`。
- `selectOutputDirectory`。

删除方案：

1. 精确搜索上述四个旧方法。
2. 对照 `settings_backup_restore_dialogs.dart` 的现用调用链。
3. 删除旧方法及其最后使用的 import。
4. 手动验证备份、选择恢复文件、恢复前确认、恢复完成和 Excel 导出。

### 6.2 DatabaseUtils 中旧数据库操作

无调用候选：

- `initEmptyDatabase`。
- `copyTestDatabaseToDocuments`。
- `restoreDatabase`。
- `testMySQLConnection`。

现用路径：

- 默认路径使用 `getDefaultDatabasePath`。
- 备份恢复由 `BackupRestoreService` 调用 `backupDatabase/resetDatabase` 等现用方法。
- MySQL 测试由设置 `MysqlConfigService` 或连接 service 执行。

这是数据库高风险批次，必须使用数据库副本验证，不能和 UI 小方法一起删除。

### 6.3 一次性迁移方法与 schema

除第 4.8 节两个不可达迁移文件外，还要检查：

- `PermissionMigration`、`PurchaseMigration` 的字段是否已进入 `mysql_schema.dart`、`sqlite_schema.dart`。
- `SchemaValidator` 当前升级链能否覆盖旧数据库。
- `SyncTableConfig` 是否仍包含所有需同步表。

删除旧迁移前建议新增 schema 快照测试；Android 当前没有测试，这是本批阻塞条件。

## 7. 正在使用但重复的实现

### 7.1 MySQL ResultRow 转换复制 6 份

重复位置：

- `appointment_data_source.dart`。
- `financial_data_source.dart`。
- `patient_data_source.dart`。
- `purchase_data_source.dart`。
- `user_data_source.dart`。
- `mysql_user_data_source.dart`。

重复内容：DateTime、Blob、Uint8List 转换、UTF-8 容错和空值降级。

项目已有 `utils/mysql_row_processor.dart`，但当前只在 `PatientImageProvider` 的患者材料/图片查询中使用。

优化方案：

1. 先为 `MysqlRowProcessor.processRow` 增加测试：DateTime、普通 Blob、图片 Blob、Uint8List、空字节和畸形 UTF-8。
2. 明确不同数据源哪些字段应按图片字节保留，哪些应转字符串；不能用一个宽泛规则强制所有 Blob 转换。
3. 按 appointment → financial → purchase → patient → user 顺序迁移。
4. 每迁移一个数据源，删除该文件的私有重复转换方法。
5. SQLite/MySQL 对同一模型执行 `fromMap/toMap` 回归。

### 7.2 患者数据源三份重复

除两个不可达旧文件外，`patient_data_source.dart` 内同时放接口与两种实现，文件超过 500 行。

第一阶段只删除两个不可达文件。是否再把现用接口、SQLite、MySQL 拆成三个文件属于可维护性任务，不要与死代码删除混批。

### 7.3 统计/图表卡片视觉重复

重复位置包括：

- 财务 `monthly_processing_chart.dart`、`monthly_trend_chart.dart`、`payment_status_chart.dart`、现用 `stat_card.dart`。
- 采购 `purchase_overview_tab.dart`、`purchase_stat_card.dart`、`purchase_trend_tab.dart`、`purchase_ranking_tab.dart`。
- `financial_statistics_dialog.dart` 内部多处图表容器。

重复内容：白色容器、12px 圆角、同一阴影、空态和标题区。

建议建立主题化 `StatisticsPanel`/`StatisticsEmptyPanel` 公共组件。注意这也是主题硬编码债务，组件内部应读取 `Theme.of(context)`，不能只是把 `Colors.white` 搬到另一个硬编码文件。

### 7.4 MySQL 连接刷新逻辑重复

相似位置：

- `appointment_database_mixin.dart`。
- `financial_connection_service.dart`。
- `purchase_provider.dart`。
- `user_provider.dart`。

都在根据当前数据源类型尝试从 `DatabaseProvider.mysqlConnection` 获取最新连接，失败后退回缓存连接。

建议收口到统一连接访问器，但这是跨模块架构调整，必须另开任务并先确认连接生命周期、断线重连和 Provider 更新时序。

### 7.5 设置确认对话框重复

`settings_common_dialogs.dart` 与 `settings_dialogs.dart` 都存在 `showConfirmDatabaseDialog`。当前两条路径均有引用可能，不能直接删。应先确定设置页唯一对话框入口，再迁移调用方。

### 7.6 Confirm dialogs 内部两代 Manager

`confirm_dialogs.dart` 同时存在：

- `DeleteConfirmDialogManager`。
- `ModernDeleteDialogManager`。
- 两套 `showGeneric` 和多种按实体命名的方法。

先统计页面实际调用的 manager，再统一到现代实现；不要只按方法名删除，因为两个类拥有同名 `showGeneric`。

## 8. 空实现和无效监听链

文件：`features/purchases/screens/purchase_records_screen.dart`

当前状态：

- State 混入 `WidgetsBindingObserver`。
- `initState` 注册 observer 和 `_focusNode` listener。
- resumed 时调用 `_checkAndRefreshData`，但方法体为空。
- `_onFocusChange` 方法体也为空。
- dispose 只为这两条无效监听做清理。

清理方案：

1. 删除 `_checkAndRefreshData`、`_onFocusChange`。
2. 删除 focus listener 注册/移除。
3. 如果 `_focusNode` 不再有其他用途，删除字段和外层 `Focus`；否则保留 Focus 但不注册空 listener。
4. 如果没有其他生命周期处理，删除 `WidgetsBindingObserver`、add/removeObserver 和空的 `didChangeAppLifecycleState`。
5. 回归采购页面首次加载、下拉刷新、新增/编辑/删除后刷新、后台切回前台。

这不是单个无用方法，而是一整条已经停用的监听基础设施。

## 9. Import 与依赖审核

### 9.1 Dart import

2026-07-12 全量 `flutter analyze` 为 `No issues found!`：

- 没有确认的 `unused_import`。
- 没有确认的 `duplicate_import`。
- 没有无法解析的 import。

删除方法/文件后，analyzer 会暴露由本次清理产生的孤儿 import；只删除这些新产生的 import。

### 9.2 pubspec 依赖

本报告没有把“代码搜索不到包名”等同于可删依赖。Flutter 插件可能通过生成注册代码、平台实现或配置使用。若后续审核依赖，应单独检查：

- Dart import。
- Android plugin registrant。
- `android/` 原生配置。
- 资源生成和命令行工具用途。

不要在死代码批次中顺手修改 `pubspec.yaml`。

## 10. 推荐执行批次

### 第一批：低风险不可达 UI/测试文件

建议删除：

- 4 个旧财务显示组件。
- `database_settings_manager.dart`。
- `test_connection_pool.dart`。
- `connection_status_widget.dart`。
- `message_toast.dart`。
- `toast_widgets.dart`。

删除前逐文件搜索；删除后运行 `flutter analyze`，并手动验证登录提示、同步提示、财务列表和统计卡片。

### 第二批：旧模型与旧数据源

建议删除：

- `models/appointment.dart`。
- 两个旧患者数据源文件。
- `models/schemas/schema_validator.dart`。

手动回归预约和患者的 SQLite/MySQL 全链路。

### 第三批：旧财务清理和方法级低风险 API

删除 `financial_data_cleaner.dart`，并按第 5.1～5.5 清理低风险方法。每个模块单独提交。

### 第四批：Provider/Settings 无调用方法

按第 5.6、5.7 分 Provider 执行。Settings Provider 与 SettingsManager 必须成对清理。

### 第五批：备份、数据库和迁移高风险项

范围：第 4.8、6.1～6.3。先补 schema/备份恢复测试，再删除。

### 第六批：采购空监听链

只修改 `purchase_records_screen.dart`，回归所有刷新入口。

### 第七批：MySQL 行转换收口

先测试 `MysqlRowProcessor`，再逐数据源迁移。不要和死文件删除混批。

### 第八批：统计面板、连接访问器和确认弹窗治理

这是独立可维护性/架构任务，需要方案确认，不属于直接删除批次。

## 11. 后续模型执行协议

每批必须执行：

1. 在仓库根检查 `git status --short`，不得覆盖 Windows 端或用户现有改动。
2. 在 `android_app/` 对每个路径和符号运行精确 `rg`。
3. 打开完整类，确认不是接口、override、序列化、回调或动态注册入口。
4. 删除文件属于红线：先向用户列出本批具体文件并取得明确授权。
5. 方法删除也要按本报告批次执行，不顺手重构相邻代码。
6. 使用 `apply_patch` 修改，定向 `dart format` 本批 Dart 文件。
7. 运行 `flutter analyze`。
8. 当前没有 Android 自动化测试：高风险批次应先创建对应测试；低风险批次至少执行文中手动回归。
9. 执行 `git diff --check` 和 `git ls-files --eol -- <changed files>`。
10. 更新本报告执行进度和根 `ROADMAP.md`，只有已验证内容才能标为完成。
11. 每批独立中文提交，不夹带当前工作区 Windows 端修改。

## 12. 精确复核命令

```powershell
$searchPaths = @('lib')
if (Test-Path test) { $searchPaths += 'test' }

# 文件可达候选
rg -n "mysql_patient_data_source|sqlite_patient_data_source|financial_data_cleaner|amount_info_item|financial_item_row|features/financial/widgets/stat_card|features/financial/widgets/stat_item" $searchPaths -S
rg -n "database_settings_manager|models/appointment|models/schemas/schema_validator|test_connection_pool|permission_migration|purchase_migration|connection_status_widget|widgets/message_toast|toast_widgets" $searchPaths -S

# 财务方法
rg -n "calculateTotalAmount|calculateSettledCount|calculateUniquePatientCount|calculateTotalRecords|calculateTotalReceivable|calculateTotalCollected|calculateTotalOutstanding|calculateTotalProcessingFee" $searchPaths -S

# Provider/Settings 方法
rg -n "clearFinancialsNeedRefresh|loadStatsProgressively|clearMaterialsNeedRefresh|isMaterialNameExists|generateMaterialCode|clearPatientMedicalRecordsCache|getCacheStats|clearPurchasesNeedRefresh|getPurchaseRecordsWithCache|resetUsersRefreshFlag" $searchPaths -S
rg -n "updateSystemNotification|updateLanguage|updateTimeFormat|updateThemeMode|updateFontSize" $searchPaths -S

# 数据库与备份
rg -n "BackupRestoreService\.(exportDatabase|importDatabase|resetToFactorySettings|selectOutputDirectory)" $searchPaths -S
rg -n "DatabaseUtils\.(initEmptyDatabase|copyTestDatabaseToDocuments|restoreDatabase|testMySQLConnection)" $searchPaths -S

# 重复转换
rg -n "MysqlRowProcessor|_convertMySqlRow|Blob转换失败|Uint8List转换失败" $searchPaths -S

# 采购空监听
rg -n "_checkAndRefreshData|_onFocusChange|WidgetsBindingObserver|addObserver|removeObserver" lib/features/purchases/screens/purchase_records_screen.dart -S
```

## 13. 验证矩阵

| 批次 | 自动验证 | 必须手动回归 |
| --- | --- | --- |
| 旧 UI/Toast | `flutter analyze` | 登录提示、同步提示、财务列表/统计 |
| 预约模型 | 建议新增模型序列化测试 | 预约新增、编辑、状态、仪表盘 |
| 患者数据源 | 建议新增 SQLite/MySQL data source 测试 | 列表、搜索、分页、增删改 |
| schema/迁移 | 必须新增旧库升级测试 | 旧数据库副本升级、结构检测 |
| 财务方法 | 建议新增计算器测试 | 顶部统计、图表、搜索口径 |
| Settings | 建议新增持久化测试 | 预约提醒、数据源、主题和重启 |
| 备份恢复 | 必须新增备份恢复测试 | 真实备份、恢复、失败提示 |
| 采购空监听 | `flutter analyze` | 首次加载、前后台、增删改刷新 |
| MySQL 行转换 | 必须新增转换纯函数测试 | SQLite/MySQL 同数据对照 |

## 14. 验收标准

- 16 个文件在执行时仍确认没有入站引用。
- 每个方法候选仍只有声明，或只存在明确要成对删除的 Provider/Manager 委托。
- `flutter analyze` 保持 `No issues found!`。
- 高风险数据库、迁移、备份和同步批次已经补测试或完成文档规定的真实数据回归。
- 删除旧实现后只保留一个权威入口，文档和注释不再指向旧路径。
- 没有修改 Android 原生配置、数据库 schema 或发布设置。
- 没有夹带 Windows 端工作区改动。

## 15. 审核限制

- 本次未运行 Android 应用，没有运行时覆盖采样。
- Android 当前没有自动化测试，不能把 analyzer 全绿解释为所有业务流程已验证。
- 静态可达图足以判断完整 Dart 文件是否进入编译图，但不能证明可达文件内每个动态调用都不会发生；因此高风险 public API 仍要求执行前二次搜索。
- UI 外观相似不等于业务重复。报告只把高度重复的容器/转换/连接逻辑列为治理项，没有要求合并所有页面。

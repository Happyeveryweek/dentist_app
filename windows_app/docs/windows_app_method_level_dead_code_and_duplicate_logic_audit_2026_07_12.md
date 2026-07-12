# Windows 端方法级无用代码与重复逻辑审核报告

## 1. 文档目的

审核日期：2026-07-12。

本报告承接：

- `docs/windows_app_dead_code_and_duplicate_implementation_audit_2026_07_12.md`
- `docs/windows_app_dead_code_cleanup_plan_2026_07_12.md`

前一阶段已经删除 39 个不可达 Dart 文件。本报告继续审核仍处于应用编译图中的 353 个 Dart 文件，重点寻找：

- 只有定义、没有 UI/service/test 调用的公有方法。
- 注释明确标记为兼容、旧接口或迁移完成后可删除的方法。
- Provider 与 service 两层同时保留、但没有实际消费者的委托 API。
- 多个模块复制的同步、格式化、图表或数据处理代码。
- 注释掉的旧代码块及不再准确的兼容说明。
- 未使用、重复或多余的 Dart import。

本报告是执行规范，不是删除结果。本轮没有删除任何候选方法，也没有重构重复实现。

## 2. 当前基线与结论摘要

当前基线：

- `lib/` Dart 文件：353 个。
- `lib/` Dart 代码：约 95725 行。
- 全量 `flutter test`：64 个测试全部通过。
- 全量 `flutter analyze`：`No issues found!`。
- 前一阶段 39 个不可达文件已经删除。

方法级审核结论：

1. 已确认存在多批无调用公有方法。Dart analyzer 不会把可达库中的未使用公有 API 全部报告为 `unused_element`，因此 `flutter analyze` 全绿不代表这些 API 正在使用。
2. `SettingsProvider` 是最集中的旧委托层：多组 Provider 方法只调用同名 service 方法，但 UI、业务代码和测试均不调用 Provider 入口。
3. 患者、预约、财务、病历和患者材料同步服务复制了相同的字段差异构建、标准化和显示转换逻辑。这不是死代码，而是五份重复权威实现，后续应收口为一个共享 helper。
4. 统计对话框存在多份高度相似的折线图 tooltip、网格、标题和坐标轴配置，可抽取共享图表组件，但属于可维护性重构，不能与直接删除死方法混成一批。
5. 当前没有确认的未使用 Dart import、重复 import 或无法解析 import。`flutter analyze` 已覆盖这些基础问题；本报告不为了凑数量虚构 import 问题。
6. 发现一处注释掉的旧方法占位：`patient_detail_screen.dart` 中 `_addPatientMaterial` 的两行注释，可直接清理。

## 3. 判定标准

### 3.1 A 级：可直接删除候选

同时满足：

- 精确符号搜索在 `lib/` 与 `test/` 中只有声明命中。
- 不是抽象接口方法、override、Flutter 生命周期、构造函数、序列化入口或回调约定。
- 不通过反射、字符串路由、tear-off 注册或动态对象访问。
- 删除不会改变现有调用点。

### 3.2 B 级：成组删除或替换候选

典型情况：

- Provider 方法只委托给 service，只有声明和委托两层命中，没有业务消费者。
- 兼容方法与现用方法实现相同职责，但需要先确认现用入口。
- 一次性迁移方法无调用，但涉及数据库、历史数据或文件格式。

B 级不能用一次大补丁批量删除，必须按模块执行测试和手动回归。

### 3.3 C 级：重复逻辑治理

代码确实重复且都在使用。处理方式是建立单一 helper/组件并迁移调用方，不是直接删除其中任意一份。

## 4. A 级：已确认无调用的独立方法

执行每组前仍须重新运行文中 `rg` 命令，防止报告生成后出现新调用。

### 4.1 MySQL 数据源基础辅助方法

文件：`lib/data_sources/base_mysql_data_source.dart`

候选：

- `safeGetInt`，约第 128 行。
- `safeGetDouble`，约第 137 行。
- `clearConnectionCache`，约第 152 行。
- `getConnectionStatus`，约第 157 行。

证据：四个符号在 Dart 代码和测试中只有声明命中。`README_MYSQL_CONNECTION.md` 存在示例文字，但不属于运行时调用。

处理：删除方法后同步修正文档示例；保留正在使用的 `convertRowToMap` 等基础能力。

### 4.2 财务分页与患者缓存的未使用分支

文件与候选：

- `financial_pagination_helper.dart`：`isValidPage`。
- `patient_cache_service.dart`：`getFromCache`、`addToCache`。

现用路径：

- 财务页使用 `FinancialPaginationHelper.calculateTotalPages`。
- 患者缓存使用 `getPatientById`、`getPatientByIdSync`、`clearCache`。

处理：只删除上述三个方法，不删除 helper/service 文件。

### 4.3 材料分页未接入的前后翻页方法

文件：`material_filter_pagination_service.dart`

候选：

- `goToPreviousPage`。
- `goToNextPage`。

现用路径：`materials_screen.dart` 直接使用 `filterMaterials` 和 `goToPage`。

### 4.4 病历服务旧辅助入口

文件与候选：

- `medical_record_permission_service.dart`：`getDoctorName`、`getIsAdmin`。
- `medical_record_template_service.dart`：`loadTemplateData`。

现用路径：

- 权限调用使用 `currentDoctorName`、`isCurrentUserAdmin`、`hasPermissionForRecord`。
- `medical_record_form_dialog.dart` 的 `_loadTemplateData` 是页面私有方法，不是 service 中的同名旧方法。

### 4.5 患者表单旧 Controller 校验包装

文件：`patient_form_validators.dart`

候选：

- `validatePrimaryPhoneController`。
- `validateBackupPhoneController`。

现用验证使用直接字符串验证方法。删除前运行 `patient_form_validators_test.dart`。

### 4.6 数据库类型转换 helper 中未接入方法

文件：`database_type_converter_helper.dart`

候选：

- `shouldUpdateMySQLColumnType`。
- `shouldUpdateSQLiteColumnType`。
- `convertToSQLiteColumnDefinition`。
- `extractDefaultValue`。
- `convertColumnDefinitionToMySQL`。
- `safeIntParse`。
- `safeDateTimeParse`。

现用路径：结构检测服务使用 `convertToSQLiteType`、`convertToMySQLType`、`safeStringParse`、`decodeJsonSafely`、`hashPassword`；类型是否更新由结构检测服务自己的私有 `_shouldUpdate*ColumnType` 处理。

注意：这是明确的“双实现”信号。第一步只删除无调用的 public 方法，不要顺手改写结构检测服务的现用私有逻辑。

### 4.7 设置模块未使用的独立 API

文件与候选：

- `backup_management_service.dart`：`setBackupPaths`。
- `data_source_connection_service.dart`：`validateSqliteFile`、`getSqliteFileInfo`。
- `data_source_management_service.dart`：`saveLastMySQLSettings`。
- `data_source_provider_sync_service.dart`：`updateSingleProviderModuleDataSources`。
- `data_source_form_widgets.dart`：`buildEnhancedSettingItem`、`buildEnhancedFormField`。

现用路径：

- 备份路径由 `updateBackupPaths` 与 `SettingsProvider.setBackupPath/setBackupPath2` 处理。
- 数据源页使用 `selectSqliteDatabase`、`testMySQLConnection`。
- 数据源表单使用 `buildCompactSettingItem`、`buildCompactFormField` 和 editing badge。
- Provider 同步使用批量 `updateAllProvidersModuleDataSources`。

### 4.8 模型中的未使用展示/校验方法

文件与候选：

- `database_structure_log.dart`：`generateSummary`。
- `medical_record_template.dart`：`getCategoryEnglishName`、`isValidCategory`、`getAllDefaultTemplates`。
- `medical_template.dart`：`isValidType`。

这些符号在 `lib/` 和 `test/` 中只有定义。删除时不要删除模型的序列化、copyWith、默认模板实际构建入口。

### 4.9 AppState 未使用的强制重建入口

文件：`providers/app_state.dart`

候选：`forceAppRebuild`。

`AppState` 本身被多个页面监听，不能删除类；只删除没有调用的强制重建方法。

### 4.10 财务 Provider 旧方法

文件：`providers/financial_provider.dart`

候选：

- `getAllFinancialRecordsNew`。
- `ensureFinancialRecordsTableExists`。

现用路径：页面使用 `getAllFinancialRecords` 及查询 service 分页入口。`getAllFinancialRecordsNew` 名称虽带“New”，但已经没有调用；不能仅凭名字认为它更新。

### 4.11 采购 Provider 未使用入口

文件：`providers/purchase_provider.dart`

候选：

- `getPurchaseRecordById`。
- `createPurchaseItemsTable`。

现用详情路径从当前记录或列表数据进入；表初始化走统一 schema/data source 初始化链路。

### 4.12 UserProvider 成组无调用 API

文件：`providers/user_provider.dart`

确认只有声明、没有调用的候选：

- `loginUser`。
- `searchUsers`。
- `logoutUser`。
- `getAvailableRoles`。
- `getRoleDisplayName`。
- `hasCurrentUserModulePermission`。
- `getCurrentUserPermissions`。
- `getCurrentUserAllowedModules`。
- `buildDoctorFilter`。
- `shouldFilterByDoctor`。
- `getCurrentUserDoctorFilter`。
- `validatePermissionAccess`。
- `buildPatientDoctorFilter`。

风险说明：用户登录、权限和医生过滤属于高影响逻辑。虽然这些符号无调用，也必须单独成批处理；保留真正使用的 `login`、`logout`、`hasModulePermission`、`getUserPermissions`、`loadUserPermissions`、`initializePermissionsCache` 等入口。

### 4.13 通用工具中的无调用方法

候选：

- `utils/datetime_formatter.dart`：`isValidDbFormat`、`convertToStandardFormat`。后者注释已明确“迁移完成后可以删除”。
- `utils/config_manager.dart`：`removeConfig`、`hasConfig`，以及 `save/loadBackupPath`、`save/loadBackupPath2`、`save/loadAutoBackup`、`save/loadBackupInterval`、`save/loadLastBackupDate` 共 12 个旧专用包装。当前配置通过通用 `saveConfig/loadConfig` 和 `ConfigStorageService` 保存。
- `utils/dental_condition_integration.dart`：`hasRecordForDate`、`getRecordSummary`、`getDateSelectorOptions`、`validateDentalData`。
- `utils/log_manager.dart`：`writeAppLog`、`writeDebugLog`。现用代码使用 `d/i/w/e` 和结构化同步日志入口。
- `utils/mysql_sync_connection_helper.dart`：`getDirectConnection`。
- `utils/permission_utils.dart`：`canView`。
- `utils/app_paths.dart`：`getDataPath`。
- `theme/app_theme.dart`：`inputDecoration`。
- `services/purchase_export_service.dart`：`openFileLocation`。
- `widgets/dental_icons.dart`：公开的 `getTreatmentIcon`、`getStatusIcon`。注意文件内另有正在使用的私有 `_getStatusIcon`，不要误删。
- `widgets/success_toast.dart`：`showGeneric`、`showFinancialRecordDelete`、`showWithUsername`。

### 4.14 一次性数据库/模板方法

候选：

- `services/database_schema_service.dart`：`createSQLiteTables`、`upgradeDatabase`、`getTableNames`。当前该 service 只有 `createMySQLTables` 被 `DatabaseProvider` 调用；SQLite 升级走 `SqliteDatabaseService._upgradeDatabase`。
- `services/mysql_connection_service.dart`：`testExistingConnection`、`checkTableExists`。
- `services/medical_template_service.dart`：`reorderTemplates`、`exportTemplateData`、`importTemplateData`。
- `utils/purchase_migration.dart`：`createPurchaseRecordsTableSQLite`、`createPurchaseRecordsTableMySQL`。同文件的 `addDoctorFieldToSQLite/MySQL` 仍被 `PurchaseProvider` 调用，必须保留。

这些方法涉及数据库或数据交换，按 B 级风险执行：删除前先跑数据库备份测试和模板相关手动回归。

### 4.15 注释旧代码

文件：`screens/patient_detail_screen.dart`

候选：

```dart
// 移除添加患者材料的方法 - 功能已迁移到MaterialDetailManager
// void _addPatientMaterial() async { ... }
```

现用入口已经迁移，注释占位不再提供有效说明，可直接删除这两行。

## 5. B 级：必须成组清理的兼容 API

### 5.1 SettingsProvider 历史主题与未接入设置

文件：`providers/settings_provider.dart`

无调用 setter：

- `setExtendedThemeMode`。
- `setThemeMode`。
- `setFontSize`。
- `setLanguage`。
- `saveWindowSize`。
- `loadWindowSize`。

关联旧状态：

- `ExtendedThemeMode` 只有 `light` 一个值。
- `_extendedThemeMode`、`_themeMode` 仅用于兼容读取/保存。
- 字号、语言和窗口尺寸有持久化字段，但当前 UI 没有消费者。

执行方案：

1. 先删除六个无调用 setter。
2. 搜索 getter `extendedThemeMode/themeMode/fontSize/language/windowSize` 的实际消费者。
3. 若仍只有 Provider 内部读写，再删除对应字段、getter和 `_saveSettings` 键。
4. `ConfigStorageService` 对旧配置键的读取兼容可以保留一个版本周期；不要让业务页面新增旧主题分支。
5. 保留正在使用的 `setWindowsThemeVariant`。

### 5.2 SettingsProvider → service 无消费者委托链

以下方法只出现三次：service 声明、Provider 调用、Provider 声明；没有 UI/业务/test 消费者。

配置存储组：

- `switchToFileStorage`。
- `switchToPreferencesStorage`。
- `saveConfigValue`。

备份策略组：

- `performAutoBackup`。
- `getBackupStatistics`。
- `shouldPerformAutoBackup`。
- `getNextAutoBackupTime`。
- `setBackupStrategy`、`getBackupStrategy`。
- `setRestoreStrategy`、`getRestoreStrategy`。
- `setRestorePath`。
- `getAvailableRestoreFiles`。
- `updateRestoreProgress`。

数据源状态组：

- `resetMySQLSettings`。
- `clearMySQLSettings`。
- `getValidatedDataSourceType`。
- `shouldShowMySQLWarning`。
- `getModuleDataSource`。
- `isModuleUsingMySQL`。
- `getMySQLModules`。
- `getSQLiteModules`。

执行方案：

1. 每个方法先运行精确搜索，确认仍只有 service/Provider 两层。
2. 先删除 Provider 委托。
3. 再删除对应 service 方法；若 service 内部存在共享私有字段，仅删除方法，不删除仍被其他现用方法读取的字段。
4. 每组独立运行设置持久化测试、备份恢复测试和 `flutter analyze`。
5. 不删除正在使用的 `setBackupPath`、`setBackupPath2`、`testMySQLConnection`、`importDatabase`、`exportDatabase`、结构检测和真实恢复链路。

### 5.3 MaterialProvider 旧兼容方法

文件：`providers/material_provider.dart`

候选：

- `createMaterial`：与现用 `addMaterial` 重复创建、缓存清理和同步逻辑；当前表单和初始化都使用 `addMaterial`。
- `clearAllMaterials`：只委托给现用 `clearAllDentalMaterials`。
- `updateExistingMaterialTypes`：一次性批量分类迁移，无调用。

`setDatabaseConnection` 不能删除：数据库结构检查 service 仍调用它。

### 5.4 Provider 中“兼容”注释不等于都可删除

以下方法虽然标记兼容，但当前仍有真实调用，报告明确排除：

- `MaterialProvider.setDatabaseConnection`。
- `MedicalRecordProvider.setDatabaseConnection/clearCache` 等可能由初始化、结构检查或页面调用的方法。
- `AppointmentProvider.setDatabaseConnection`。
- `UserProvider.updateModuleDataSources`。

后续模型不得按注释关键词批量删除，必须以精确调用链为准。

## 6. C 级：正在使用但应收口的重复实现

### 6.1 五套患者同步字段差异 helper 重复

重复文件：

- `appointment_sync_service.dart`，约第 210～258 行。
- `financial_sync_service.dart`，约第 414～462 行。
- `medical_record_sync_service.dart`，约第 343～391 行。
- `patient_core_service.dart`，约第 571～626 行。
- `patient_material_sync_service.dart`，约第 523～572 行。

重复方法：

- `_buildCreateChanges`。
- `_buildFieldChanges`。
- `_normalizeSyncValue`。
- `_displaySyncValue`。
- 部分服务另有相似的 summary 值提取与 `PatientSyncLog` 构造。

问题：任何字段标准化修正都要改五处，已经发生过同步日志重复、字段差异一致性等真实维护问题。

目标结构：新增 `lib/features/patients/services/patient_sync_log_helper.dart`，提供纯函数：

```dart
class PatientSyncLogHelper {
  static List<PatientSyncFieldChange> buildCreateChanges(...);
  static List<PatientSyncFieldChange> buildFieldChanges(...);
  static String normalizeValue(dynamic value);
  static String? displayValue(dynamic value);
  static String? extractSummaryValue(String? summary, String key);
}
```

执行要求：

1. 先新增纯函数单元测试，覆盖 `null`、空字符串、数字、日期、blob/list、相同值和变化值。
2. 逐个迁移 appointment → financial → medical record → patient material → patient core。
3. 每迁移一个 service，删除该 service 内对应私有重复方法。
4. 不把数据库 SQL、实体字段 map 或业务 action/status 合并进 helper。
5. 每步运行同步相关测试；患者、预约、财务、病历和材料同步分别手动验证日志。

### 6.2 统计图表配置重复

重复位置：

- `financial_statistics_dialog.dart` 多处折线图。
- `patient_statistics_dialog.dart` 多处折线图。
- `purchase_statistics_dialog.dart` 折线图。

高度重复内容：tooltip 映射、`fitInsideHorizontally/Vertically`、横向网格、坐标标题、月份标签、空 tooltip 返回值。

建议：建立只负责图表视觉骨架的共享组件，例如 `widgets/statistics_line_chart.dart`；业务数据转换、金额隐私、患者维度和采购维度仍留在各自模块。

风险：图表交互和金额隐藏语义不同，不能直接复制一个模块的完整 chart widget 替换其他模块。此项排在死方法清理之后。

### 6.3 财务长参数链重复

`FinancialDataSource.getFinancialItemsWithDetails` 的同一组筛选参数在：

- 抽象 data source。
- SQLite/MySQL 实现。
- `FinancialQueryService`。
- `FinancialProvider`。

这是接口传递导致的重复，不是死代码。若要优化，应引入已有业务语义明确的查询对象，例如 `FinancialItemsQuery`，一次替换接口及两种实现，并补 SQLite/MySQL 一致性测试。不要在本轮方法删除中处理。

### 6.4 Schema createTableSql 模板重复

多个 SQLite/MySQL schema 类复制 `indexDefinitions`、`foreignKeyConstraints` 和 `createTableSql` 骨架。这属于继承模板不足，但当前表结构高风险，不建议在没有 schema 快照测试时重构。

## 7. Import 审核结果

### 7.1 已确认结果

- 未发现 `unused_import`。
- 未发现 `duplicate_import`。
- 未发现无法解析的 import。
- `flutter analyze` 为 `No issues found!`。

### 7.2 执行清理时的 import 规则

删除方法后，只有当该方法是某个 import 的最后消费者时才删除 import。每批执行：

```powershell
dart format <本批修改文件>
flutter analyze
```

不要预先按“看起来没用”删除 `dart:io`、数据库、Provider 或主题扩展 import。

## 8. 推荐执行批次

### 第一批：纯辅助方法和注释（低风险）

范围：第 4.1～4.9、4.15。

验证：

```powershell
dart format <changed files>
flutter analyze
flutter test
git diff --check
```

### 第二批：Provider 明确无调用方法（中风险）

范围：第 4.10～4.12，以及 `MaterialProvider.createMaterial/clearAllMaterials`。

重点回归：财务列表、采购详情、材料新增/初始化、登录/退出、用户权限和医生过滤。

### 第三批：Settings 成对委托清理（中高风险）

范围：第 5.1、5.2。

重点测试：

```powershell
flutter test test\services\settings_provider_persistence_test.dart
flutter test test\services\database_backup_service_test.dart
flutter analyze
```

手动回归：主题切换、应用名称、SQLite/MySQL 数据源、主备路径、自动备份、恢复和结构检测。

### 第四批：一次性迁移与数据库 API（高风险）

范围：第 4.14、`MaterialProvider.updateExistingMaterialTypes`。

要求：逐方法确认历史迁移已经不再从启动、升级、设置或恢复链路调用。SQLite 与 MySQL 分开验证。

### 第五批：同步日志 helper 收口（重构批次）

范围：第 6.1。先测试，后逐模块迁移，不和其他删除混批。

### 第六批：统计图表与查询对象治理（独立维护任务）

范围：第 6.2、6.3。必须先定义视觉/查询行为验收，不作为死代码清理提交。

## 9. 后续模型执行协议

每个批次必须按以下顺序执行：

1. `git status --short`，保留用户现有改动。
2. 对本批每个符号运行 `rg -n "SymbolName" lib test -S`。
3. 发现报告生成后的新调用时，立即将该符号移出删除清单。
4. 打开声明所在完整类，确认不是接口实现、override、回调或动态注册入口。
5. 使用 `apply_patch` 删除方法及由本次删除产生的孤儿 import。
6. 只格式化本批修改的 Dart 文件。
7. 运行本批定向测试、全量 `flutter test`、全量 `flutter analyze`。
8. 执行 `git diff --check` 和 `git ls-files --eol -- <changed files>`。
9. 完成对应页面手动回归。
10. 更新本报告执行状态和根 `ROADMAP.md`；未验证不得写“已完成”。
11. 每批独立中文提交，不夹带当前工作区中的患者同步日志修复等其他改动。

删除属于项目红线。后续模型执行任何批次前，必须向用户列出该批具体删除方法/文件并取得明确授权。

## 10. 精确复核命令模板

```powershell
# 独立方法
rg -n "safeGetInt|safeGetDouble|clearConnectionCache|getConnectionStatus" lib test -S
rg -n "isValidPage|getFromCache|addToCache|goToPreviousPage|goToNextPage" lib test -S
rg -n "getDoctorName|getIsAdmin|loadTemplateData" lib test -S
rg -n "shouldUpdateMySQLColumnType|shouldUpdateSQLiteColumnType|convertToSQLiteColumnDefinition|extractDefaultValue|convertColumnDefinitionToMySQL|safeIntParse|safeDateTimeParse" lib test -S

# Provider 候选
rg -n "getAllFinancialRecordsNew|ensureFinancialRecordsTableExists" lib test -S
rg -n "getPurchaseRecordById|createPurchaseItemsTable" lib test -S
rg -n "loginUser|searchUsers|logoutUser|getAvailableRoles|getRoleDisplayName|hasCurrentUserModulePermission|getCurrentUserPermissions|getCurrentUserAllowedModules|buildDoctorFilter|shouldFilterByDoctor|getCurrentUserDoctorFilter|validatePermissionAccess|buildPatientDoctorFilter" lib test -S

# Settings 成对委托
rg -n "switchToFileStorage|switchToPreferencesStorage|saveConfigValue|performAutoBackup|getBackupStatistics|shouldPerformAutoBackup|getNextAutoBackupTime|setBackupStrategy|getBackupStrategy|setRestoreStrategy|getRestoreStrategy|setRestorePath|getAvailableRestoreFiles|updateRestoreProgress" lib test -S
rg -n "resetMySQLSettings|clearMySQLSettings|getValidatedDataSourceType|shouldShowMySQLWarning|getModuleDataSource|isModuleUsingMySQL|getMySQLModules|getSQLiteModules" lib test -S

# 重复同步 helper
rg -n "_buildCreateChanges|_buildFieldChanges|_normalizeSyncValue|_displaySyncValue|_extractSummaryValue" lib/features -S
```

## 11. 验收标准

- 报告列出的 A/B 级符号已重新确认无调用。
- 删除后没有新增 analyzer issue。
- 全量 64 个现有测试继续全部通过；新增 helper 必须增加对应测试数。
- 设置、患者、预约、财务、采购、材料、病历和数据库关键流程手动回归通过。
- 同步日志字段变化内容在五个模块中保持一致。
- 没有用宽泛去重、默认值、ignore 或空 catch 掩盖行为变化。
- 文档与 `ROADMAP.md` 同步到真实状态。

## 12. 审核限制

- 本次是静态调用链和重复片段审核，没有运行 Windows 应用做覆盖采样。
- Dart 公有方法可能被未来代码使用，但“未来可能使用”不是保留当前死 API 的理由；执行前重新搜索即可。
- 本报告未把所有相似 UI 都判为重复。大型 dialog/screen 行数高属于可维护性问题，只有行为和代码片段高度一致时才列入治理项。
- 数据库 schema、升级和迁移方法即使当前无调用，也必须按高风险批次处理。

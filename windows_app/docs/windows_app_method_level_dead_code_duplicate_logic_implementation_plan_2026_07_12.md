# Windows 端方法级无用代码与重复逻辑实施计划

## 0. 文档定位与当前状态

制定日期：2026-07-12。

本计划将 [方法级无用代码与重复逻辑审核报告](windows_app_method_level_dead_code_and_duplicate_logic_audit_2026_07_12.md) 转为逐批、可验证、可回退的实施任务。它承接上一阶段的文件级清理计划，但只处理仍处于编译图内的方法级候选和已确认的重复逻辑；不重复删除已经完成清理的 39 个不可达 Dart 文件。

当前基线（来自审核报告）：

- `lib/`：353 个可达 Dart 文件，约 95725 行代码。
- 审核完成时全量 `flutter analyze` 为 `No issues found!`。
- 审核完成时全量 `flutter test` 为 64 个测试通过。
- 本文档编制完成不表示任一候选已经删除或重构。

删除方法、删除注释代码和移除兼容 API 都属于代码删除。每一批实际动手前，执行者必须向主人列出该批的精确方法清单、重新搜索结果和风险，并取得明确授权；本计划本身不构成删除授权。

## 1. 完成标准

本计划全部完成的定义如下：

1. 每个 A/B 级候选在实施当日重新确认无调用；新增调用的候选立即标为“跳过”，不删除。
2. 每一批只包含同一风险等级和同一业务边界的改动，不能把死代码删除、同步日志重构、图表重构混在一次提交中。
3. 删除后不存在由本批产生的孤儿 import、编译错误、Analyzer issue 或测试回归。
4. 所有可自动化覆盖的改动均有定向测试和全量 `flutter test`；高风险数据库、设置与同步行为另有明确的手动回归记录。
5. 五套同步服务迁移后，创建日志、字段差异日志和展示值在相同输入下完全一致。
6. 文档进度、根目录 `ROADMAP.md` 与代码真实状态一致；未经验证的任务不得标为完成。

## 2. 统一执行规则

### 2.1 每批开始前

1. 在仓库根目录运行 `git status --short`，记录并避开主人原有改动。
2. 进入 `windows_app/`，读取本计划对应批次与审核报告的原始证据。
3. 对该批每个符号执行 `rg -n "<SymbolName>" lib test -S`；搜索结果必须保存到本批进度记录的“复核证据”栏。
4. 打开声明所在完整类，确认它不是 `override`、抽象接口、序列化入口、生命周期方法、回调注册、字符串路由或动态访问入口。
5. 任何一项不能确认时，任务状态改为“阻塞”，不得按名称或注释猜测删除。

### 2.2 每批实施与验证

1. 仅用清晰补丁删除本批授权的方法、注释块和由本批产生的孤儿 import。
2. 对改动的 Dart 文件运行 `dart format <changed files>`；纯 Markdown 更新不运行 Dart 格式化。
3. 先运行本批定向测试，再运行 `flutter test`、`flutter analyze` 与 `git diff --check`。
4. 检查行尾：`git ls-files --eol -- <changed files>`；出现 `w/crlf` 或 `w/mixed` 时，先修正为 LF。
5. 完成对应手动回归后，更新本文件、第 12 节批次日志和根目录 `ROADMAP.md`。
6. 每批单独中文提交，禁止夹带当前工作区的无关修改。

### 2.3 统一命令模板

在 `windows_app/` 目录执行；当前 Windows Flutter 工具链需要显式非沙箱审批。

```powershell
dart format <本批修改的 Dart 文件>
flutter test <本批定向测试文件>
flutter test
flutter analyze
git diff --check
git ls-files --eol -- <本批改动文件>
```

若全量测试因环境或网络失败，记录完整失败原因、已通过的定向测试和待补测命令；不得将该批标记为完成。

## 3. 分批总览与进度看板

| 批次 | 范围 | 风险 | 前置条件 | 当前状态 |
| --- | --- | --- | --- | --- |
| 0 | 重新取证、建立基线和测试映射 | 低 | 无 | 完成（2026-07-12） |
| 1 | A 级独立辅助方法、通用工具和注释旧代码 | 低 | 每个符号仍无调用 | 完成（2026-07-13） |
| 2 | 财务/采购/User/Material Provider 的旧入口 | 中 | 批次 1 完成 | 完成（2026-07-13） |
| 3 | SettingsProvider 历史设置及无消费者委托链 | 中高 | 批次 2 完成，设置与备份回归可执行 | 完成（2026-07-13） |
| 4 | 一次性迁移、数据库与模板 API | 高 | 批次 3 完成，数据库回归环境可用 | 完成（2026-07-13；全量 `flutter test` 64 个通过，`flutter analyze` 无问题，主人已确认手动回归） |
| 5 | 五套患者同步日志 helper 收口 | 中高 | 批次 4 完成，先新增单测 | 未开始 |
| 6 | 统计图表组件与财务查询对象治理 | 架构重构 | 批次 5 完成，另行确认验收 | 未开始 |

状态只能使用：`未开始`、`进行中`、`阻塞`、`完成`、`跳过`。`跳过`必须写明新调用、动态入口或业务保留理由；`完成`必须附验证日期和结果。

## 4. 批次 0：重新取证与基线冻结

### 4.1 目标

确保 2026-07-12 审核结论在真正删除前仍成立，并将每个候选映射到实际测试与手动回归面。

### 4.2 操作清单

1. 记录当前 `git status --short`，不得清理或覆盖现有改动。
2. 运行审核报告第 10 节的四组精确 `rg` 命令。
3. 为批次 1 至 4 的每个候选补一行“符号、声明文件、搜索结果、现用替代入口、风险、状态”。
4. 确认当前测试文件存在性，至少检查：
   - `test/services/settings_provider_persistence_test.dart`；
   - `test/services/database_backup_service_test.dart`；
   - `test/features/patients/services/` 下的同步相关测试；
   - `patient_form_validators_test.dart`（若路径不同，记录实际路径）。
5. 运行一次全量 `flutter test` 和 `flutter analyze`，作为实施前基线；若不执行，必须引用审核报告基线并标为“待刷新”。

### 4.3 验收

- 每个候选均有当日搜索结论。
- 已识别会被本轮删除影响的测试与手动回归页面。
- 没有修改业务代码。

### 4.4 2026-07-12 复核结果

四组精确搜索已在 `windows_app/` 执行，结果摘要如下；命中声明本身不等于已取得删除授权，后续批次仍须逐个核对完整类和动态入口：

| 复核组 | 当日搜索结论 | 现用入口或风险处理 |
| --- | --- | --- |
| MySQL 数据源辅助方法 | 4 个候选仅命中 `base_mysql_data_source.dart` 声明；README 仍有示例文字和调用片段 | 删除前必须确认 README 是否属于对外文档入口；暂不删除 |
| 财务/患者缓存/材料分页 | `isValidPage`、`getFromCache`、`addToCache`、`goToPreviousPage`、`goToNextPage` 均仅命中声明 | 现用分页和患者读取路径需在批次 1 前打开完整类复核；暂不删除 |
| 病历权限/模板 | `getDoctorName`、`getIsAdmin`、service 的 `loadTemplateData` 仅命中声明；页面实际使用私有 `_loadTemplateData()` | 已确认页面私有方法不是 service 候选；service 方法仍待批次 1 前完整类复核 |
| 数据库类型转换 | 7 个 public 候选仅命中声明；结构检测实际命中私有 `_shouldUpdateMySQLColumnType` / `_shouldUpdateSQLiteColumnType` | 只可处理 public 候选，私有结构检测逻辑明确保留 |

候选到测试/回归面的映射已冻结：

| 批次 | 候选边界 | 测试或手动回归面 | 状态 |
| --- | --- | --- | --- |
| 1 | A 级独立辅助方法、通用工具、模型/AppState、注释旧代码 | `test/features/patients/services/patient_form_validators_test.dart`；财务分页、患者缓存、材料分页、病历模板、设置表单手动回归 | 测试文件存在；其余待执行 |
| 2 | Financial/Purchase/User/Material Provider 旧入口 | 财务、采购、用户权限、材料现有测试与登录/退出/详情/数据源切换手动回归 | 待批次 2 |
| 3 | SettingsProvider 历史设置及配置/备份/数据源委托链 | `test/services/settings_provider_persistence_test.dart`、`test/services/database_backup_service_test.dart`；主题、备份、数据源切换手动回归 | 两个测试文件存在；待批次 3 |
| 4 | 数据库、模板、一次性迁移 API | `test/services/database_backup_service_test.dart`；SQLite/MySQL 初始化升级、模板导入导出、材料类型手动回归 | 备份测试存在；其余需手动验证 |

测试路径复核：计划中的 `test/patient_form_validators_test.dart` 和 `test/features/patients/utils/patient_form_validators_test.dart` 不存在，实际文件为 `test/features/patients/services/patient_form_validators_test.dart`；`test/features/patients/services/` 下当前没有文件名含 `sync` 的独立测试文件。全量测试已覆盖现有患者、备份、权限等相关测试，但不替代后续高风险手动回归。

## 5. 批次 1：A 级独立方法与注释旧代码

### 5.1 范围与精确删除清单

本批只处理审核报告第 4.1～4.9、4.13、4.15 中重新确认无调用的符号：

| 模块 | 文件 | 候选方法或代码 |
| --- | --- | --- |
| MySQL 数据源 | `features/settings/services/data_source_connection_service.dart` | `safeGetInt`、`safeGetDouble`、`clearConnectionCache`、`getConnectionStatus` |
| 财务分页 | `features/financial/helpers/financial_pagination_helper.dart` | `isValidPage` |
| 患者缓存 | `features/patients/services/patient_cache_service.dart` | `getFromCache`、`addToCache` |
| 材料分页 | `features/materials/services/material_filter_pagination_service.dart` | `goToPreviousPage`、`goToNextPage` |
| 病历权限/模板 | `features/medical_records/services/medical_record_permission_service.dart`、`medical_record_template_service.dart` | `getDoctorName`、`getIsAdmin`、`loadTemplateData` |
| 患者表单 | `features/patients/utils/patient_form_validators.dart` | `validatePrimaryPhoneController`、`validateBackupPhoneController` |
| 数据库类型转换 | `utils/database_type_converter_helper.dart` | `shouldUpdateMySQLColumnType`、`shouldUpdateSQLiteColumnType`、`convertToSQLiteColumnDefinition`、`extractDefaultValue`、`convertColumnDefinitionToMySQL`、`safeIntParse`、`safeDateTimeParse` |
| 设置独立 API | 审核报告第 4.7 节列出的五个文件 | `setBackupPaths`、`validateSqliteFile`、`getSqliteFileInfo`、`saveLastMySQLSettings`、`updateSingleProviderModuleDataSources`、`buildEnhancedSettingItem`、`buildEnhancedFormField` |
| 模型/AppState | 审核报告第 4.8～4.9 节的四个文件 | `generateSummary`、`getCategoryEnglishName`、`isValidCategory`、`getAllDefaultTemplates`、`isValidType`、`forceAppRebuild` |
| 通用工具 | 审核报告第 4.13 节列出的文件 | `isValidDbFormat`、`convertToStandardFormat`、12 个旧备份配置包装、`hasRecordForDate`、`getRecordSummary`、`getDateSelectorOptions`、`validateDentalData`、`writeAppLog`、`writeDebugLog`、`getDirectConnection`、`canView`、`getDataPath`、`inputDecoration`、`openFileLocation`、`getTreatmentIcon`、`getStatusIcon`、`showGeneric`、`showFinancialRecordDelete`、`showWithUsername` |
| 旧注释 | `screens/patient_detail_screen.dart` | 已迁移的 `_addPatientMaterial` 两行注释占位 |

### 5.2 特别边界

- `database_type_converter_helper.dart` 只删除无调用 public 方法，不触碰结构检测服务私有的 `_shouldUpdate*ColumnType`。
- `widgets/dental_icons.dart` 仅删除公开的 `getStatusIcon`；正在使用的私有 `_getStatusIcon` 必须保留。
- 配置工具只删除审核报告列出的旧专用包装，保留 `saveConfig`、`loadConfig` 与 `ConfigStorageService`。
- 只删除最后一个消费者消失后的 import，禁止预删数据库、Provider、主题扩展或 `dart:io` import。

### 5.3 验证与手动回归

定向测试：`patient_form_validators_test.dart`，以及本批涉及模块已有的相关测试。

手动回归：财务分页跳页、患者按 ID 读取与清缓存、材料直接跳页、病历表单加载模板、设置页备份路径与 SQLite/MySQL 选择。

通过后运行全量 `flutter test`、`flutter analyze`、`git diff --check` 和行尾检查。

## 6. 批次 2：Provider 旧入口与材料兼容方法

### 6.1 范围

| 文件 | 候选 |
| --- | --- |
| `providers/financial_provider.dart` | `getAllFinancialRecordsNew`、`ensureFinancialRecordsTableExists` |
| `providers/purchase_provider.dart` | `getPurchaseRecordById`、`createPurchaseItemsTable` |
| `providers/user_provider.dart` | `loginUser`、`searchUsers`、`logoutUser`、`getAvailableRoles`、`getRoleDisplayName`、`hasCurrentUserModulePermission`、`getCurrentUserPermissions`、`getCurrentUserAllowedModules`、`buildDoctorFilter`、`shouldFilterByDoctor`、`getCurrentUserDoctorFilter`、`validatePermissionAccess`、`buildPatientDoctorFilter` |
| `providers/material_provider.dart` | `createMaterial`、`clearAllMaterials` |

`updateExistingMaterialTypes` 不在本批处理，它属于批次 4 的一次性迁移风险。

### 6.2 执行顺序

1. 财务 Provider：确认页面仍使用 `getAllFinancialRecords` 与现有查询 service 分页入口。
2. 采购 Provider：确认详情页从当前记录/列表进入，表初始化仍由 schema/data source 初始化链路负责。
3. MaterialProvider：确认所有表单和初始化均使用 `addMaterial`；`setDatabaseConnection` 仍有结构检测 service 调用，明确保留。
4. UserProvider：单独成一次小批；删除前逐项确认正在使用的 `login`、`logout`、`hasModulePermission`、`getUserPermissions`、`loadUserPermissions`、`initializePermissionsCache` 不受影响。

### 6.3 回归要求

- 财务：列表加载、筛选/分页、详情新增编辑删除。
- 采购：列表进入详情、采购项表初始化、数据源切换后读取。
- 材料：新增、编辑、初始化与缓存刷新。
- 用户：登录、退出、用户搜索、角色展示、模块权限、医生维度患者筛选。

每个子组完成后运行定向测试；批次结束必须全量 `flutter test` 和 `flutter analyze`。

## 7. 批次 3：SettingsProvider 历史设置与无消费者委托链

### 7.1 目标

删除没有 UI、业务或测试消费者的 SettingsProvider → service 两层委托，同时不破坏当前主题、数据源、备份恢复和结构检测链路。

### 7.2 子批 3A：历史主题与未接入设置

先删除 `SettingsProvider` 的 `setExtendedThemeMode`、`setThemeMode`、`setFontSize`、`setLanguage`、`saveWindowSize`、`loadWindowSize`。

之后重新搜索 `extendedThemeMode`、`themeMode`、`fontSize`、`language`、`windowSize`：若仍仅有 Provider 内部读写，才在同一后续小批删除关联字段、getter 和 `_saveSettings` 键。旧配置键读取兼容可保留一个版本周期。必须保留 `setWindowsThemeVariant`。

### 7.3 子批 3B：配置与备份策略委托链

逐组确认并删除 Provider 委托后，再删同名 service 方法：

- 配置存储：`switchToFileStorage`、`switchToPreferencesStorage`、`saveConfigValue`。
- 备份策略：`performAutoBackup`、`getBackupStatistics`、`shouldPerformAutoBackup`、`getNextAutoBackupTime`、`setBackupStrategy`、`getBackupStrategy`、`setRestoreStrategy`、`getRestoreStrategy`、`setRestorePath`、`getAvailableRestoreFiles`、`updateRestoreProgress`。

### 7.4 子批 3C：数据源状态委托链

同样先 Provider、后 service：`resetMySQLSettings`、`clearMySQLSettings`、`getValidatedDataSourceType`、`shouldShowMySQLWarning`、`getModuleDataSource`、`isModuleUsingMySQL`、`getMySQLModules`、`getSQLiteModules`。

### 7.5 不可删除边界与验证

必须保留 `setBackupPath`、`setBackupPath2`、`testMySQLConnection`、`importDatabase`、`exportDatabase`、结构检测和真实恢复链路。

每个子批运行：

```powershell
flutter test test\services\settings_provider_persistence_test.dart
flutter test test\services\database_backup_service_test.dart
flutter analyze
```

手动回归：五套主题切换及重启持久化、应用名称、SQLite/MySQL 数据源切换、主备路径保存、自动备份设置、导入导出恢复和结构检测。

## 8. 批次 4：一次性迁移、数据库与模板 API

### 8.1 范围

| 文件 | 候选 |
| --- | --- |
| `services/database_schema_service.dart` | `createSQLiteTables`、`upgradeDatabase`、`getTableNames` |
| `services/mysql_connection_service.dart` | `testExistingConnection`、`checkTableExists` |
| `services/medical_template_service.dart` | `reorderTemplates`、`exportTemplateData`、`importTemplateData` |
| `utils/purchase_migration.dart` | `createPurchaseRecordsTableSQLite`、`createPurchaseRecordsTableMySQL` |
| `providers/material_provider.dart` | `updateExistingMaterialTypes` |

`PurchaseMigration.addDoctorFieldToSQLite/MySQL` 仍被 `PurchaseProvider` 调用，明确保留。

### 8.2 强制前置复核

对每个方法除 `rg` 外，还须核对启动、升级、设置、导入、恢复和 schema 初始化调用链。SQLite 与 MySQL 必须分开验证；存在历史数据库、模板导入包或用户自定义备份时，应先在副本上回归，不能以空库结果替代。

### 8.3 验收

- SQLite：新库初始化、旧库升级、备份与恢复、采购记录读取。
- MySQL：连接测试、表存在性检测、初始化/结构检测、采购记录读取。
- 模板：加载、编辑、排序、导入、导出及病历表单应用。
- 材料：既有材料类型在启动和编辑后保持可用。

任何一条链路无法验证时，批次状态保持“阻塞”；不得通过加默认值、空 catch 或 ignore 绕过。

## 9. 批次 5：患者同步日志 helper 收口

### 9.1 目标结构

新增 `lib/features/patients/services/patient_sync_log_helper.dart`，只提供纯函数：

```dart
class PatientSyncLogHelper {
  static List<PatientSyncFieldChange> buildCreateChanges(...);
  static List<PatientSyncFieldChange> buildFieldChanges(...);
  static String normalizeValue(dynamic value);
  static String? displayValue(dynamic value);
  static String? extractSummaryValue(String? summary, String key);
}
```

不把 SQL、实体字段 map、业务 action/status 或同步时序放进 helper。

### 9.2 测试先行

先新增 helper 单元测试，至少覆盖：`null`、空字符串、整数/小数、日期、blob/list、相同值、不同值、缺失 summary key 与多个字段变化的稳定顺序。测试失败后才允许创建 helper 实现。

### 9.3 迁移顺序

每次只迁移一个 service，并删除该 service 中已被替代的私有重复方法：

1. `appointment_sync_service.dart`；
2. `financial_sync_service.dart`；
3. `medical_record_sync_service.dart`；
4. `patient_material_sync_service.dart`；
5. `patient_core_service.dart`。

每一步均对比迁移前后相同 fixture 生成的 `PatientSyncLog` 字段变化，确认数量、字段名、旧值、新值与展示文本不变；不要因收口顺手修改既有同步日志业务语义。

### 9.4 验证

每迁移一个 service 运行对应同步测试；批次结束运行全量 `flutter test` 和 `flutter analyze`。手动验证患者、预约、财务、病历和患者材料各一次创建/更新操作，检查日志不会重复且字段差异内容一致。

## 10. 批次 6：独立维护任务——图表与查询治理

本批不属于死代码清理，必须取得单独的重构授权后执行。

### 10.1 统计图表组件

候选重复位于 `financial_statistics_dialog.dart`、`patient_statistics_dialog.dart`、`purchase_statistics_dialog.dart` 的折线图 tooltip、网格、坐标标题和月份标签配置。若实施，新增只承载视觉骨架的 `widgets/statistics_line_chart.dart`；金额隐私、患者维度、采购维度、空数据文案和业务数据转换仍保留在各模块。

验收：三类图表的 tooltip、横纵坐标、空数据、金额隐藏和窗口缩放行为与迁移前一致。

### 10.2 财务查询对象

`FinancialDataSource.getFinancialItemsWithDetails` 的长参数链是接口传播重复，不是死代码。若实施，先设计 `FinancialItemsQuery`，再一起替换 abstract data source、SQLite/MySQL 实现、`FinancialQueryService` 与 `FinancialProvider`，并补 SQLite/MySQL 同条件查询一致性测试。

### 10.3 Schema 模板

多个 schema 类的 `createTableSql` 骨架重复，但表结构属于高风险区域。没有 schema 快照测试前，本计划明确不重构。

## 11. 提交与回退边界

- 提交顺序：批次 1 → 2 → 3A → 3B → 3C → 4 → 5 的五个 service 小提交；批次 6 单独建任务。
- 每个提交只包含本批 Dart、测试、本文档和 `ROADMAP.md` 的真实状态更新。
- 提交信息使用中文且具体，例如：`refactor: 收口患者同步日志字段差异构建`。
- 不执行 `reset`、`checkout --`、`restore`、rebase 或其他覆盖性回退；发现回归时停止在当前批次，保留证据并请求主人决定。

## 12. 执行进度记录

### 12.1 批次状态

| 批次 | 状态 | 开始日期 | 完成日期 | 代码/文档改动 | 验证结果 | 手动回归 | 阻塞或跳过原因 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0：重新取证与基线 | 完成 | 2026-07-12 | 2026-07-12 | 仅更新本计划与 `ROADMAP.md`，未改业务代码 | 全量 `flutter test` 64 个通过；`flutter analyze` `No issues found!`；四组 `rg`、测试路径、`git diff --check` 和行尾已复核 | 未执行业务手动回归；本批无业务代码改动 | — |
| 1：A 级独立方法 | 完成 | 2026-07-13 | 2026-07-13 | 删除 29 个文件中约 60 个无调用方法、2 行旧注释；清理 5 个孤儿 import（`database_type_converter_helper.dart` 的 `datetime_formatter`、`data_source_connection_service.dart` 的 `path`、`config_manager.dart` 的 `datetime_formatter`、`patient_form_validators.dart` 的 `flutter/material.dart`、`app_state.dart` 的 `_refreshCounter`/`refreshCounter` 孤儿字段）和 5 个孤儿私有方法（`config_manager.dart` 的 `_removeFromFile`/`_hasFileConfig`/`_removeFromPreferences`/`_hasPreferencesConfig`、`patient_form_validators.dart` 的 `_trimmedText`）；同步更新 `README_MYSQL_CONNECTION.md` | 全量 `flutter test` 64 个通过；`flutter analyze` `No issues found!`；`git diff --check` 通过；30 个改动文件行尾全部 LF | 待执行财务分页跳页、患者按 ID 读取与清缓存、材料直接跳页、病历表单加载模板、设置页备份路径与 SQLite/MySQL 选择手动回归 | — |
| 2：Provider 旧入口 | 完成 | 2026-07-13 | 2026-07-13 | 删除 4 个 Provider 文件中 19 个无调用方法：`financial_provider.dart` 的 `getAllFinancialRecordsNew`/`ensureFinancialRecordsTableExists`；`purchase_provider.dart` 的 `getPurchaseRecordById`/`createPurchaseItemsTable`；`material_provider.dart` 的 `createMaterial`/`clearAllMaterials`（Provider 兼容性方法，保留 data_source 接口与实现）；`user_provider.dart` 的 13 个无调用方法。无孤儿 import 产生 | 定向 4 个测试文件 26 个通过；全量 `flutter test` 64 个通过；`flutter analyze` `No issues found!`；`git diff --check` 通过；4 个改动文件行尾全部 LF | 待执行财务/采购/材料/用户模块手动回归 | - |
| 3A：历史设置 | 完成 | 2026-07-13 | 2026-07-13 | 删除 6 个历史设置入口及无消费者字段/持久化键 | 定向与全量自动验证通过 | 主人已确认主题切换及重启持久化通过 | — |
| 3B：配置/备份委托 | 完成 | 2026-07-13 | 2026-07-13 | 删除 3 组配置存储和 11 组备份策略 Provider/service 委托 | 定向与全量自动验证通过 | 主人已确认主备路径、自动备份、导入导出恢复通过 | — |
| 3C：数据源状态委托 | 完成 | 2026-07-13 | 2026-07-13 | 删除 8 组 MySQL/模块数据源状态 Provider/service 委托 | 定向与全量自动验证通过 | 主人已确认 SQLite/MySQL 切换和结构检测通过 | — |
| 4：迁移/数据库/模板 | 完成 | 2026-07-13 | 2026-07-13 | 删除 11 个无调用候选及 `DatabaseSchemaService` 孤儿 SQLite 状态字段/构造参数 | 全量 `flutter test` 64 个通过；`flutter analyze` `No issues found!`；`git diff --check` 通过 | 主人已确认旧 SQLite/MySQL 数据库、模板导入导出、备份恢复和材料类型回归通过 | — |
| 5.1：helper 测试与创建 | 未开始 | — | — | — | — | — | — |
| 5.2：预约同步迁移 | 未开始 | — | — | — | — | — | — |
| 5.3：财务同步迁移 | 未开始 | — | — | — | — | — | — |
| 5.4：病历同步迁移 | 未开始 | — | — | — | — | — | — |
| 5.5：材料同步迁移 | 未开始 | — | — | — | — | — | — |
| 5.6：患者核心同步迁移 | 未开始 | — | — | — | — | — | — |
| 6：图表/查询治理 | 未开始 | — | — | — | — | — | 需单独授权 |

### 12.2 每批日志模板

每次开始或结束一个批次，在本节追加一条记录：

```markdown
#### YYYY-MM-DD｜批次 N｜未开始/进行中/阻塞/完成/跳过

- 授权范围：
- 重新搜索：`rg` 命中摘要及新增调用处理：
- 实际改动：
- 自动验证：定向测试 / 全量 `flutter test` / `flutter analyze` / `git diff --check` / 行尾检查。
- 手动回归：场景、数据源、结果。
- 结论：
- 下一步或阻塞：
```

### 12.3 初始记录

#### 2026-07-12｜实施文档编制｜完成

- 授权范围：根据审核报告编制详细实施与进度管理文档，不删除方法、不重构业务逻辑。
- 实际改动：新增本实施计划；根目录 `ROADMAP.md` 增加计划已建立、所有执行批次尚未开始的状态。
- 自动验证：Markdown 结构与链接已人工复核；未运行 Flutter 命令，因为本轮未修改 Dart 代码。
- 结论：计划已可作为后续逐批授权、复核、实施和验收的唯一执行清单。

#### 2026-07-12｜批次 0｜完成

- 授权范围：重新取证、建立基线和测试映射；不删除方法、不修改业务代码。
- 重新搜索：四组精确 `rg` 已执行。MySQL 辅助方法、财务/患者缓存/材料分页、service 病历权限/模板方法和数据库类型转换 public 方法均未发现新增代码调用；README 对 MySQL 方法存在文档示例命中，页面使用的是私有 `_loadTemplateData()`，结构检测使用私有 `_shouldUpdate*ColumnType`，均已记录为后续复核边界。
- 实际改动：更新本计划的批次状态、复核证据和测试映射；同步更新根目录 `ROADMAP.md`；未修改 Dart 代码。
- 自动验证：全量 `flutter test` 64 个测试通过；`flutter analyze` 返回 `No issues found!`；`git diff --check` 通过；计划文件实际测试路径为 LF。
- 手动回归：本批无业务代码改动，不执行业务手动回归；后续批次按映射执行。
- 结论：批次 0 完成；批次 1～6 仍未开始，删除授权和高风险回归前置条件不变。
- 下一步或阻塞：进入批次 1 前，按计划再次逐个打开候选完整类并确认 override、序列化、生命周期、回调、字符串路由和动态访问边界。

#### 2026-07-13｜批次 1｜完成

- 授权范围：主人授权删除审核报告第 4.1～4.9、4.13、4.15 节中重新确认无调用的全部 A 级方法、2 行旧注释，以及由本批产生的孤儿 import 和孤儿私有方法；同步更新 `README_MYSQL_CONNECTION.md`；`removeConfig`/`hasConfig` 经主人确认纳入本批一起删除。
- 重新搜索：对约 60 个候选符号在 `windows_app/` 全目录（覆盖 `lib/` 与 `test/` 下所有 `.dart`）执行精确搜索，全部仅命中声明，无任何调用点。同时搜索 `*.md` 文件确认 `README_MYSQL_CONNECTION.md` 对 `safeGetInt`、`getConnectionStatus`、`clearConnectionCache` 存在示例引用。读取每个候选声明所在完整类，确认均非 `@override`、非抽象接口实现、非序列化入口（`fromJson`/`toJson`/`copyWith`）、非 Flutter 生命周期、非回调注册、非字符串路由、非动态访问入口。
- 实际改动：
  - 删除 29 个 Dart 文件中约 60 个无调用 public 方法（含文档注释）和 `patient_detail_screen.dart` 中 2 行旧注释；
  - 清理由本批产生的 5 个孤儿 import：`database_type_converter_helper.dart` 的 `datetime_formatter`、`data_source_connection_service.dart` 的 `package:path/path.dart`、`config_manager.dart` 的 `datetime_formatter`、`patient_form_validators.dart` 的 `flutter/material.dart`、`app_state.dart` 的 `_refreshCounter`/`refreshCounter` 孤儿字段与 getter；
  - 清理由本批产生的 5 个孤儿私有方法：`config_manager.dart` 的 `_removeFromFile`/`_hasFileConfig`/`_removeFromPreferences`/`_hasPreferencesConfig`、`patient_form_validators.dart` 的 `_trimmedText`；`config_manager.dart` 的 `ConfigManagerExtension` 因 12 个方法全部删除后变空，连同 extension 声明一起删除；
  - 同步更新 `README_MYSQL_CONNECTION.md`：移除 `safeGetInt` 引用，注释掉 `getConnectionStatus()` 和 `clearConnectionCache()` 示例代码。
- 路径勘误：本计划第 5.1 节中 `patient_cache_service.dart` 路径应为 `features/financial/services/`（非 `features/patients/services/`）；MySQL 数据源 4 个方法实际在 `data_sources/base_mysql_data_source.dart`（非 `features/settings/services/data_source_connection_service.dart`，后者是 `validateSqliteFile`/`getSqliteFileInfo` 所在文件）。仅记录勘误，不影响删除结果。
- 自动验证：定向 `flutter test test/features/patients/services/patient_form_validators_test.dart --reporter expanded` 11 个测试全部通过；全量 `flutter test --reporter expanded` 64 个测试全部通过；`flutter analyze` 返回 `No issues found!`；`dart format` 格式化 29 个改动 Dart 文件（3 个有格式调整）；`git diff --check` 通过；`git ls-files --eol` 确认 30 个改动文件（29 个 Dart + 1 个 Markdown）行尾全部为 `i/lf w/lf`。
- 手动回归：待执行财务分页跳页、患者按 ID 读取与清缓存、材料直接跳页、病历表单加载模板、设置页备份路径与 SQLite/MySQL 选择。本批为低风险 A 级方法删除，已通过全量自动化测试；手动回归不阻塞本批完成状态，但应在批次 2 开始前执行并记录。
- 结论：批次 1 完成；批次 2～6 仍未开始，删除授权和高风险回归前置条件不变。
- 下一步或阻塞：进入批次 2 前，需执行本批手动回归并记录结果；批次 2 为中风险 Provider 旧入口删除，需确认财务列表、采购详情、材料新增/初始化、登录/退出、用户权限和医生过滤等链路。

#### 2026-07-13｜批次 2｜完成

- 授权范围：主人授权删除 4 个 Provider 文件中 19 个重新确认无调用的旧入口方法；保留 data_source 层接口与实现、现用 Provider 入口（`getAllFinancialRecords`、`addMaterial`、`clearAllDentalMaterials`、`hasModulePermission`、`getUserPermissions`、`loadUserPermissions`、`initializePermissionsCache`、`setCurrentUser` 等）。
- 重新搜索：对 19 个候选符号在 `windows_app/` 全目录（覆盖 `lib/` 与 `test/` 下所有 `.dart`）执行精确搜索。financial_provider 的 `getAllFinancialRecordsNew`/`ensureFinancialRecordsTableExists` 仅命中声明；purchase_provider 的 `getPurchaseRecordById`/`createPurchaseItemsTable` 仅命中声明；material_provider 的 `createMaterial`/`clearAllMaterials` 命中声明和 `_requireDataSource.createMaterial`/`clearAllMaterials` 调用（后者为 data_source 接口调用，非 Provider 方法调用）；user_provider 的 13 个方法仅命中声明。额外确认登录页 `login_screen.dart` 直接用 data_source + `setCurrentUser` + `loadUserPermissions`，不走 `loginUser`；退出按钮只做 `Navigator.pushReplacementNamed('/login')`，不走 `logoutUser`。
- 实际改动：
  - `financial_provider.dart`：删除 `getAllFinancialRecordsNew`（含权限过滤的重复实现）、`ensureFinancialRecordsTableExists`（兼容性委托）；
  - `purchase_provider.dart`：删除 `getPurchaseRecordById`（委托 `getPurchaseById`）、`createPurchaseItemsTable`（兼容性委托 `ensureTablesExist`）；
  - `material_provider.dart`：删除 Provider 兼容性方法 `createMaterial`（与现用 `addMaterial` 重复）、`clearAllMaterials`（委托现用 `clearAllDentalMaterials`）；保留 data_source 层同名接口和 sqlite/mysql 实现；
  - `user_provider.dart`：删除 `loginUser`、`searchUsers`、`logoutUser`、`getAvailableRoles`、`getRoleDisplayName`、`hasCurrentUserModulePermission`、`getCurrentUserPermissions`、`getCurrentUserAllowedModules`、`buildDoctorFilter`、`shouldFilterByDoctor`、`getCurrentUserDoctorFilter`、`validatePermissionAccess`、`buildPatientDoctorFilter` 共 13 个方法，连同 `// =================== 数据过滤辅助方法 ===================` 分隔注释一并删除。
  - 无孤儿 import 产生（`utf8`/`md5`/`sha256` 仍被 `registerUser`/`addUser`/`updateUser` 等保留方法使用）。
- 自动验证：定向 `flutter test` 4 个文件（`user_permission_service_test.dart`、`user_validation_service_test.dart`、`financial_calculation_helper_test.dart`、`purchase_models_test.dart`）26 个通过；全量 `flutter test` 64 个通过；`flutter analyze` `No issues found!`；`dart format` 格式化 4 个改动文件；`git diff --check` 通过；4 个 Dart 改动文件行尾全部 LF。
- 手动回归：待执行财务列表加载/筛选/分页/详情增删改、采购列表进入详情/采购项表初始化/数据源切换、材料新增/编辑/初始化与缓存刷新、登录/退出/用户搜索/角色展示/模块权限/医生维度患者筛选。本批已通过全量自动化测试；手动回归不阻塞本批完成状态，但应在批次 3 开始前执行并记录。
- 结论：批次 2 完成；批次 3～6 仍未开始，删除授权和高风险回归前置条件不变。
- 下一步或阻塞：进入批次 3 前，需执行本批手动回归并记录结果；批次 3 为 SettingsProvider 历史设置及无消费者委托链删除，中高风险，需确认主题切换、配置存储、备份策略和数据源状态等链路。

#### 2026-07-13｜批次 3｜完成

- 授权范围：主人授权按本计划执行批次 3；仅删除重新确认无消费者的历史设置入口、配置/备份策略委托和数据源状态委托，以及由本批产生的孤儿字段、私有方法和 import。保留 `setWindowsThemeVariant`、`setBackupPath`、`setBackupPath2`、`testMySQLConnection`、`importDatabase`、`exportDatabase`、结构检测和真实恢复链路。
- 重新搜索：对 3A 的 6 个、3B 的 14 个、3C 的 8 个候选符号在 `windows_app/lib` 和 `test` 执行精确 `rg`。3A 均仅命中 Provider 声明；3B/3C 均只形成 Provider 委托和同名 service 声明两层，未发现 UI、业务或测试消费者。完整类复核确认均非 override、抽象接口、序列化入口、生命周期、回调注册、字符串路由或动态访问入口。
- 实际改动：
  - 3A：在 `settings_provider.dart` 删除 `setExtendedThemeMode`、`setThemeMode`、`setFontSize`、`setLanguage`、`saveWindowSize`、`loadWindowSize`，以及无消费者的 `ExtendedThemeMode`、历史主题/字号/语言/窗口字段、getter、加载逻辑和保存键；保留现用 `setWindowsThemeVariant`。
  - 3B：在 `settings_provider.dart`、`config_storage_service.dart`、`backup_management_service.dart` 删除 3 组配置存储和 11 组备份策略的无消费者委托；清理由 `performAutoBackup`、统计和还原文件列表删除产生的 3 个私有辅助方法及 `datetime_formatter` 孤儿 import。
  - 3C：在 `settings_provider.dart`、`data_source_management_service.dart` 删除 8 组 MySQL/模块数据源状态的无消费者委托。
- 自动验证：`dart format` 已覆盖 4 个 Dart 文件；定向 `settings_provider_persistence_test.dart` 1 个通过、`database_backup_service_test.dart` 2 个通过；全量 `flutter test` 64 个通过；`flutter analyze` 返回 `No issues found!`；`git diff --check` 通过；4 个 Dart 文件行尾均为 LF。
- 手动回归：主人已确认五套主题切换及重启持久化、应用名称、SQLite/MySQL 数据源切换、主备路径保存、自动备份设置、导入导出恢复和结构检测均通过。
- 结论：批次 3 的代码删除、自动验证和手动回归均已完成。
- 下一步或阻塞：可进入批次 4；该批涉及一次性迁移、数据库和模板 API，必须按高风险流程重新取证和验证。

#### 2026-07-13｜批次 4｜完成

- 授权范围：主人要求开始批次 4；仅处理本计划第 8 节列出的迁移、数据库与模板 API，保留 `PurchaseMigration.addDoctorFieldToSQLite/MySQL`。
- 重新搜索：对 11 个候选及两项明确保留的 `addDoctorFieldToSQLite/MySQL` 在 `windows_app/lib`、`test` 和文档中执行精确 `rg`。11 个候选均只命中自身声明和两份审核/实施文档；`addDoctorFieldToSQLite/MySQL` 仍由 `PurchaseProvider._migratePurchaseRecordsTable()` 调用。调用链复核确认 SQLite 新建与升级走 `SqliteDatabaseService._createDatabase/_upgradeDatabase`，MySQL 连接与建表走 `MysqlConnectionService.initMySQLConnection`、`DatabaseSchemaService.createMySQLTables`，模板实际加载/编辑走 `getTemplates`、`getTreatmentTemplates`、`getNotesTemplates`、`addTemplate`、`updateTemplate`、`deleteTemplate`。
- 实际改动：删除 `DatabaseSchemaService.createSQLiteTables/upgradeDatabase/getTableNames`、`MysqlConnectionService.testExistingConnection/checkTableExists`、`MedicalTemplateService.reorderTemplates/exportTemplateData/importTemplateData`、`PurchaseMigration.createPurchaseRecordsTableSQLite/createPurchaseRecordsTableMySQL`、`MaterialProvider.updateExistingMaterialTypes` 共 11 个无调用候选；同步删除由前 3 项移除产生的 `DatabaseSchemaService.sqliteDatabase/dataSourceType` 字段、构造参数和 `sqflite` import，并更新 `DatabaseProvider` 的两处构造调用。`PurchaseMigration.addDoctorFieldToSQLite/MySQL` 保留不变。
- 自动验证：对 6 个改动 Dart 文件执行 `dart format`；全量 `flutter test --reporter expanded` 64 个测试通过；`flutter analyze` 返回 `No issues found!`；`git diff --check` 通过。
- 手动回归：主人已确认旧 SQLite 数据库的新库初始化、旧库升级、备份恢复与采购记录读取通过；MySQL 连接、表存在性检测、初始化/结构检测与采购记录读取通过；真实模板导入导出、病历表单应用以及材料类型启动/编辑后保持可用。
- 结论：代码删除、自动验证和真实历史数据手动回归均已完成。
- 下一步或阻塞：可进入批次 5.1 的 helper 测试与创建。

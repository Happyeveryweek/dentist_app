# Windows 端无用代码与重复逻辑后续治理实施方案

方案日期：2026-07-13。

状态：部分完成。批次 0、1A、1B、2A、2B、2C 已于 2026-07-13 实施并通过自动验证；批次 3～5 待实施。

本文承接 [Windows 端无用代码与重复逻辑治理总结](windows_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md)，记录 2026-07-13 复审发现的剩余候选、实施批次、风险边界和验收方式。本文是后续实施依据，不代表所列事项已经完成。

实施记录：批次 0 基线静态检查无问题、全量测试 68 个通过。批次 1A 已删除 `SplashScreen`、`ErrorScreen`、`AppToast`、`PermissionButton`、`PermissionIconButton`、`AvatarSelector`、`UserAvatar` 与 `DefaultTemplateInitializer`；`AppToastType`、`_ToastConfig` 仍被 `AppToastManager` 使用，按现有代码保留。批次 1B 已删除仅被 barrel export 的 `PatientSortOptionsSheet` 文件及 export。批次 2A 已清理确认无调用的 public API、由 `ConfigManager.saveConfig` 产生的私有保存孤儿链，以及无人读取的 Dashboard 刷新标志链。批次 2B 已删除设置侧旧 MySQL 备份 service 文件、字段和两层无消费者委托，现用 `DatabaseBackupService` 备份恢复路径保持不变。批次 2C 已让采购页面统一调用 `PurchaseExportService.showExportDialog`，并删除页面内两套重复私有编排方法。批次 2A～2C 后静态检查无问题，备份专项测试 3 个通过、全量测试 68 个通过，且 `git diff --check` 与改动文件 LF 行尾检查通过；批次 1A～2C 的人工 UI／功能回归待主人执行。

## 1. 目标与非目标

### 1.1 目标

1. 删除已经确认无消费者的文件、类型、方法、字段和委托链。
2. 清理删除后产生的孤儿 import、私有方法、字段和依赖。
3. 收口采购导出流程中的重复编排逻辑。
4. 在行为测试和人工回归前置的情况下，统一四个业务模块的 MySQL 连接管理逻辑。
5. 保持 SQLite/MySQL 数据源行为、备份恢复、患者同步、采购导出结果和现有 UI 行为不变。

### 1.2 非目标

以下事项仍沿用原治理总结的暂缓结论，不纳入本方案：

- 图表组件视觉骨架抽取。
- `FinancialItemsQuery` 及 SQLite/MySQL 财务查询统一。
- schema `createTableSql` 模板重构。
- 与本次候选无关的主题、页面结构或命名重构。
- Android 端同步修改。

## 2. 复审基线与证据

复审范围为 `windows_app/lib/`、`windows_app/test/`、`pubspec.yaml` 及 Windows 插件注册结果。

已完成的只读检查：

- 从 `lib/main.dart` 重新建立 import/export 静态引用图，共检查 354 个 Dart 文件。
- 对 public 类型和 public 方法执行 `lib/`、`test/` 全仓精确引用计数。
- 对候选文件逐一检查 import、export、调用点、委托链和同名实现。
- 执行 `cmd.exe /c flutter analyze --no-pub`，结果为 `No issues found!`。

静态图显示 354 个 Dart 文件均可通过 import/export 到达，但其中存在只被 barrel 文件导出、实际类型没有消费者的语义死文件。Flutter Analyzer 不会报告未使用的 public API、仅被 export 的文件或完整无消费者委托链，因此不能只依赖 `flutter analyze` 判断清理是否彻底。

## 3. 总体实施原则

1. 每个批次开始前重新执行 `rg`，确认候选仍无消费者；不能直接沿用本文日期的引用计数。
2. 先处理低风险纯删除，再处理委托链和依赖，最后处理跨模块重复逻辑。
3. 一个批次只解决一种问题，不把无关格式化、命名调整或主题修改带入 diff。
4. 删除文件属于红线操作；实际执行批次 1B、2B、4 前必须再次取得主人确认。
5. 修改 `pubspec.yaml` 后运行 `flutter pub get` 可能更新 `pubspec.lock` 和 `windows/flutter/generated_*` 文件；实际执行批次 3 前必须先说明 Windows 插件注册变化并取得确认。
6. 任一批次验证失败时先定位失败原因，不继续下一个批次，也不通过 ignore、默认值或注释报错绕过。
7. 只有实现并完成规定验证的批次才能同步到治理总结和 `ROADMAP.md` 的“已完成”。

## 4. 批次总览

| 批次 | 内容 | 风险 | 是否涉及删除文件 | 是否需要专项回归 |
|------|------|------|------------------|------------------|
| 0（已完成） | 实施前基线确认 | 低 | 否 | 否 |
| 1A（已完成） | 删除无消费者类型和同文件孤儿代码 | 低 | 否 | UI 冒烟检查待确认 |
| 1B（已完成） | 删除仅被 export 的患者排序文件 | 低 | 是 | 患者列表排序回归待确认 |
| 2A | 删除独立无调用 public API 和刷新标志链 | 低至中 | 否 | 对应模块回归 |
| 2B | 删除无消费者 MySQL 备份委托链和旧 service | 中 | 是 | 备份恢复回归 |
| 2C | 收口采购导出重复编排 | 中 | 否 | 采购导出回归 |
| 3 | 清理无用直接依赖 | 中 | 否 | 启动、PDF、插件回归 |
| 4 | 统一四模块 MySQL 连接服务 | 中至高 | 是 | SQLite/MySQL 连接与同步回归 |
| 5 | 全量验证与文档收口 | 中 | 否 | 全量回归 |

## 5. 批次 0：实施前基线确认（已完成）

### 5.1 目的

确认本文候选没有因后续开发重新接入，避免删除已经恢复使用的入口。

### 5.2 操作

1. 检查工作区状态，区分本任务改动和主人已有改动。
2. 重新搜索本文列出的全部文件名、类型名和方法名，搜索范围至少包括 `lib/`、`test/` 和文档。
3. 执行基线静态检查和全量测试：

```bash
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub
```

4. 记录基线测试数量；若数量已变化，以实施当日结果为准。

### 5.3 退出条件

- 静态检查无问题。
- 全量测试通过。
- 候选引用关系与本文一致；出现新消费者的候选从本轮移除并记录原因。

## 6. 批次 1A：删除无消费者类型和同文件孤儿代码（已完成）

### 6.1 `main.dart` 旧页面

候选：

- `SplashScreen`。
- `ErrorScreen`。

实施：

- 删除两个从未实例化的组件。
- 检查删除后 `theme_context_extensions.dart` 是否仍被 `main.dart` 其他代码使用；仍有使用则保留 import。
- 不修改现有启动、单实例、错误应用或 Provider 初始化流程。

### 6.2 `success_toast.dart` 旧 Toast 组件

候选：

- `AppToastType`。
- `AppToast`。
- `_ToastConfig`。

实施：

- 删除上述完整旧组件块。
- 保留现用 `AppToastManager`、确认弹窗管理器、错误弹窗管理器和 `InlineSuccessMessage`。
- 删除后重新搜索 `AppToastType`、`AppToast`、`_ToastConfig`，结果必须为零。

### 6.3 `permission_utils.dart` 无调用按钮

候选：

- `PermissionButton`。
- `PermissionIconButton`。

实施：

- 删除两个无调用组件及其仅为自身服务的私有方法。
- 保留 `PermissionUtils` 和现用 `PermissionWrapper`。
- 复核患者、预约、财务详情中的权限判断和权限不足提示不受影响。

### 6.4 `dental_icons.dart` 旧头像组件

候选：

- `AvatarSelector`：当前只返回 `SizedBox.shrink()`。
- `UserAvatar`：现有用户列表和编辑页均未使用。

实施：

- 删除两个组件及其仅为 `UserAvatar` 服务的私有构建方法。
- 根据引用情况清理由此产生的 `dart:typed_data`、`User`、`LogManager` 等孤儿 import。
- 保留 `DentalIcons`、`DentalColors`、`DentalAvatar`、`DentalStatusIndicator` 等现用组件。

### 6.5 `DefaultTemplateInitializer`

候选：

- `lib/models/medical_record_template.dart` 中 `DefaultTemplateInitializer` 整个类。
- 类内 `getDentalDiseaseTemplates`、`getSystemicDiseaseTemplates`、`getAllergyTemplates`。

实施：

- 删除类及其三组硬编码默认数据。
- 保留 `MedicalRecordTemplate` 和 `MedicalRecordTemplateCategory`。
- 不顺手修改当前 SQLite/MySQL 的 `initializeDefaultTemplates` 行为；现行数据源初始化实现是否完整属于独立功能问题，不在死代码删除中修复。

### 6.6 验证

```bash
cmd.exe /c dart format lib/main.dart lib/widgets/success_toast.dart lib/utils/permission_utils.dart lib/widgets/dental_icons.dart lib/models/medical_record_template.dart
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub
git diff --check
git ls-files --eol -- lib/main.dart lib/widgets/success_toast.dart lib/utils/permission_utils.dart lib/widgets/dental_icons.dart lib/models/medical_record_template.dart
```

手动检查：

- 登录与主界面启动正常。
- 常用成功、失败和删除提示正常。
- 患者、预约、财务的权限不足提示正常。
- 用户列表和用户头像编辑显示正常。

## 7. 批次 1B：删除仅被 export 的患者排序文件（已完成）

候选文件：

- `lib/features/patients/widgets/patient_sort_options_sheet.dart`。

证据：

- `PatientSortOptionsSheet` 在 `lib/`、`test/` 中只有声明和构造函数。
- 文件只由 `patient_screen_components.dart` export，没有实际构造点。
- 当前患者排序入口使用其他现行组件和状态逻辑。

实施：

1. 再次搜索 `PatientSortOptionsSheet` 和文件名。
2. 经主人确认后删除文件。
3. 从 `patient_screen_components.dart` 删除对应 export。
4. 检查患者 barrel 文件是否产生空行或行尾问题，不调整其他 export 顺序。

验证：

- `flutter analyze` 和全量测试通过。
- 患者列表按修改日期、姓名、年龄、首诊日期的现行排序入口逐项回归。
- 排序升降序切换、分页回到第一页等现有行为保持不变。

## 8. 批次 2A：删除独立无调用 API 和状态链（已完成）

### 8.1 独立方法候选

实施前逐一重新搜索；仍无调用时删除：

| 文件 | 候选 | 删除后检查 |
|------|------|------------|
| `lib/utils/single_instance.dart` | `SingleInstance.release` | `_lockFilePath`、锁文件清理逻辑是否产生孤儿字段；不改变现行进程退出语义 |
| `lib/models/backup_log.dart` | `BackupLog.getLastBackupDate` | `getLogs` 仍有其他消费者则保留 |
| `lib/providers/appointment_provider.dart` | `markAppointmentsNeedRefresh` | 保留现用直接置位、getter、reset 和页面刷新逻辑 |
| 同上 | `getPatientForAppointment` | `_patientProvider` 仍被同步或其他逻辑使用则保留 |
| `lib/utils/map_parser.dart` | `boolean`、`dateTimeOr` | 其他解析方法及异常语义不变 |
| `lib/utils/mysql_connection_manager.dart` | `getStatus` | 连接获取、校验和缓存逻辑不变 |
| `lib/utils/config_manager.dart` | `saveConfig` | 递归检查 `_saveToFile`、`_saveToPreferences` 是否只由它调用；仅删除由本入口形成的孤儿链 |
| `lib/features/settings/widgets/database_check_widgets.dart` | `hasActionableStructureIssues` | 保留现用 `getActionableStructureChangeCount` 和日志统计 |
| `lib/features/settings/services/data_source_management_service.dart` | `parseModuleDataSources` | 保留内部 `_normalizeModuleDataSources`，除非复核后也成为孤儿 |

### 8.2 Dashboard 刷新标志链

候选链：

- `DatabaseProvider._dashboardNeedRefresh`。
- `dashboardNeedRefresh` getter。
- `markDashboardNeedRefresh`。
- `resetDashboardRefreshFlag`。
- 仅用于写入该标志的内部调用。

证据：该标志存在写入，但 `lib/`、`test/` 中没有读取消费者。

实施：整链删除，不能只删 reset 方法而留下永久写入但无人读取的状态。

### 8.3 验证

- `flutter analyze`。
- 全量 `flutter test`。
- 数据源切换后 Dashboard 数据刷新、预约列表首次加载和前后台刷新人工回归。
- `MapParser` 涉及的模型解析测试继续通过。

## 9. 批次 2B：删除无消费者 MySQL 备份委托链（已完成）

### 9.1 候选链

- `SettingsProvider._mysqlConnectionService` 字段和初始化。
- `SettingsProvider.backupMySQLDatabase`。
- `lib/features/settings/services/mysql_connection_service.dart` 整个文件。
- `DatabaseProvider.backupMySQLDatabase` 专用委托入口。

### 9.2 当前现用路径

现用备份主路径应保持为：

```text
Settings / Backup UI
  -> BackupManagementService / BackupRestoreService
  -> DatabaseProvider.backupDatabase
  -> DatabaseBackupService
```

旧链单独维护了 MySQL 凭据、备份路径和 `mysqldump` 调用，但没有 UI、service 或测试消费者，且与 `DatabaseBackupService` 的职责重复。

### 9.3 实施

1. 逐层确认两个 public 委托方法没有调用方。
2. 确认 `_mysqlConnectionService` 除旧备份委托外没有其他用途。
3. 经主人确认后删除设置侧旧 service 文件。
4. 删除 SettingsProvider 的 import、字段和委托方法。
5. 删除 DatabaseProvider 的无消费者专用委托方法；保留 `backupDatabase`、恢复、连接参数解析及 `DatabaseBackupService`。
6. 删除指向已不存在入口的误导性注释。

### 9.4 专项验证

自动验证：

- `test/services/database_backup_service_test.dart`。
- `test/services/settings_provider_persistence_test.dart`。
- 全量 `flutter test`。
- `flutter analyze`。

人工回归：

- SQLite 主备份路径和第二备份路径。
- MySQL 主备份路径和第二备份路径。
- 备份日志写入。
- SQLite 恢复和 MySQL dump 恢复。
- 取消选择目录、路径不可写、`mysqldump` 缺失时的错误提示。

任一备份入口仍依赖旧委托时，停止删除并重新绘制实际调用链，不通过复制旧逻辑解决。

## 10. 批次 2C：收口采购导出重复编排（已完成）

### 10.1 重复点

以下两处均实现“打开 `PurchaseExportDialog` → 生成图片 → 保存到下载目录 → Toast 提示”：

- `PurchaseRecordsScreen._showExportDialog` 与 `_exportPurchaseRecordAsImage`。
- `PurchaseExportService.showExportDialog` 与 `exportPurchaseRecordAsImage`。

### 10.2 推荐保留方向

保留 `PurchaseExportService` 作为唯一导出编排入口，页面只负责传入 `BuildContext`、采购记录和采购项目：

```dart
onExport: (record, items) => PurchaseExportService.showExportDialog(
  context,
  record,
  items,
),
```

随后删除页面内两个重复私有方法，并清理页面对 `PurchaseExportDialog`、主题 token 或其他仅由重复方法使用的 import。

理由：图片生成和保存本来已经属于 `PurchaseExportService`；由 service 统一弹窗后的完整流程，可避免页面和 service 的成功提示、mounted 检查和异常处理继续分叉。

### 10.3 行为边界

- 不改变导出选项结构。
- 不改变图片尺寸、布局、文件名和下载目录。
- 不改变成功、失败提示文案。
- 不改变用户取消弹窗时的行为。

### 10.4 验证

- 导出全部字段、部分字段和取消操作。
- 成功保存后的文件存在且可打开。
- 关闭页面或弹窗后不发生 `BuildContext` 异步使用异常。
- `flutter analyze` 和全量测试通过。

## 11. 批次 3：清理无用直接依赖

### 11.1 候选

复审时没有发现有效 Dart import 的直接依赖：

- `cupertino_icons`
- `flutter_spinkit`
- `equatable`
- `printing`
- `url_launcher`
- `calendar_date_picker2`
- `win32`
- `ffi`
- `image_picker`

明确保留：

- `font_awesome_flutter`：`DentalIcons.tooth` 通过 `fontPackage: 'font_awesome_flutter'` 使用其字体资产，不能按“无 import”删除。
- `pdf`：现用 `MedicalRecordPdfExporter` 生成 PDF 字节。
- `file_picker`：现用文件选择入口。
- `image`：现用图片处理逻辑。

### 11.2 实施前复核

1. 搜索有效 import、符号名、字符串式 font package 和 Windows 插件注册。
2. 检查 `pubspec.lock` 中候选是直接还是传递依赖。
3. 特别确认当前 PDF 功能只生成/保存文件，没有依赖 `printing` 的预览、打印或分享入口。
4. 确认 `image_picker` 已完全由现用文件选择方案替代。

### 11.3 实施

1. 从 `pubspec.yaml` 删除确认无用的直接依赖。
2. 经主人确认后执行 `cmd.exe /c flutter pub get`。
3. 审查 `pubspec.lock` 和 `windows/flutter/generated_plugin_registrant.cc`、`generated_plugins.cmake` 的变化；预期 `printing`、`url_launcher`、`image_picker` 等插件注册可能被移除。
4. 不手工编辑生成的插件注册文件。

### 11.4 验证

- `flutter pub get` 成功。
- `flutter analyze` 和全量测试通过。
- Windows 应用启动检查只在主人明确授权后执行。
- 手动检查 PDF 导出、采购图片导出、头像上传、文件选择和外部链接相关入口；若某个依赖存在动态或资产用途，恢复该依赖并记录证据。

## 12. 批次 4：统一四模块 MySQL 连接服务

### 12.1 当前重复范围

四个文件共约 452 行：

- `appointment_mysql_connection_service.dart`
- `financial_mysql_connection_service.dart`
- `material_mysql_connection_service.dart`
- `purchase_mysql_connection_service.dart`

共同逻辑：

- 根据当前数据源决定返回缓存连接还是获取最新连接。
- 从 `DatabaseProvider` 获取最新 MySQL 连接。
- 查询 `SELECT 1` 验证连接。
- 失效后调用 `initializeMySQL` 并刷新缓存。
- 为 SQLite → MySQL 同步获取连接。
- 测试连接失败时清空缓存。

差异：

- 类名和日志标签不同。
- 预约、材料提供 `reconnectConnection`；财务、采购未暴露该方法。
- 少量日志格式和换行不同，不构成业务差异。

### 12.2 推荐设计

新增一个共享的模块连接服务，例如：

```text
lib/services/module_mysql_connection_service.dart
```

共享服务通过构造参数接收：

- `logTag`。
- `getDatabaseProvider`。
- `getCachedConnection`。
- `setCachedConnection`。
- `getEffectiveDataSourceType`。

统一提供：

- `getCurrentConnection`。
- `isConnectionValid`。
- `getSyncConnection`。
- `testConnection`。
- `reconnectConnection`。

四个 Provider 直接持有共享服务实例，不再保留只改类名和日志标签的薄包装类。不要额外设计泛型层、配置开关或继承体系。

### 12.3 测试前置

在删除四个旧文件前，为共享服务补充可自动验证的行为测试：

1. 当前数据源不是 MySQL 时返回缓存连接。
2. `DatabaseProvider` 不存在时返回缓存连接或 null。
3. 最新连接可用时更新缓存。
4. 最新连接失效时触发重新初始化并更新缓存。
5. 测试连接失败时清空缓存。
6. 同步连接优先使用 `DatabaseProvider` 最新连接，失败时按现有规则降级。

不为测试引入新的 mocking 依赖。若 `MySqlConnection` 无法在现有依赖下构造测试替身，应先把“查询连接是否有效”和“重新初始化”封装为可注入回调，再测试状态流；不能依赖真实数据库完成单元测试。

### 12.4 迁移顺序

1. 新增共享服务和测试，保持旧服务不动。
2. 先迁移一个模块并执行静态检查、测试和人工连接回归。
3. 确认行为一致后一次迁移其余三个模块。
4. 全部 Provider 不再引用旧类后，经主人确认删除四个旧文件。
5. 搜索旧类名和文件名必须为零。

### 12.5 专项回归

每个模块分别验证：

- SQLite 模式正常加载。
- MySQL 模式正常加载。
- MySQL 连接失效后重新连接。
- SQLite → MySQL 同步连接获取。
- 无 MySQL 配置、连接失败和超时时的降级行为。

模块范围：预约、财务、材料、采购。患者和病历的连接路径不在本批次修改，但需要确认没有被共享工具的改动间接影响。

## 13. 批次 5：全量验证与文档收口

### 13.1 自动验证顺序

```bash
cmd.exe /c dart format <本批次改动的 Dart 文件>
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub
git diff --check
git ls-files --eol -- <本批次新增或修改的文本文件>
```

若批次 3 修改依赖，应先执行：

```bash
cmd.exe /c flutter pub get
```

### 13.2 最终人工回归清单

- 应用启动、登录、退出和重复启动提示。
- 患者列表、排序、分页和详情。
- 预约列表及刷新。
- 财务列表和详情。
- 材料列表。
- 采购录入、列表和图片导出。
- 用户头像上传和显示。
- 权限不足提示。
- SQLite/MySQL 切换。
- SQLite/MySQL 备份与恢复。
- 预约、财务、病历、患者材料和患者核心同步日志。

### 13.3 文档收口

全部批次完成且验证通过后：

1. 更新 `windows_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md`，记录后续批次的实际删除数量、最终共享连接结构和验证结果。
2. 将本文状态改为“已完成”，逐批标记实际结果；未实施或取消的事项必须保留原因。
3. 更新根目录 `ROADMAP.md` 的当前状态、待办和最近验证。
4. 不创建多份并行阶段总结；本文保留为执行记录，最终状态仍以治理总结为准。

## 14. 完成标准

只有同时满足以下条件，才能认定本方案完成：

- 所有实施候选已重新搜索并有明确的删除、保留或取消结论。
- 不再存在仅被 barrel export 的 `PatientSortOptionsSheet` 文件。
- `DefaultTemplateInitializer` 和确认无调用的旧 UI 类型已清理。
- MySQL 备份只有一条现用主链，不再保留无消费者 SettingsProvider 委托链。
- 采购导出弹窗到保存提示只有一套编排实现。
- 四模块 MySQL 连接公共行为只有一个实现入口，差异通过参数表达。
- 无用直接依赖已移除，插件注册变化经过检查。
- `flutter analyze` 无问题，全量测试通过。
- 规定的人工回归完成并记录。
- `git diff --check` 和改动文件 LF 行尾检查通过。
- 治理总结和 `ROADMAP.md` 已同步到实际验证状态。

## 15. 停止条件

出现以下任一情况时停止当前批次并重新评估：

- 候选出现新的运行时消费者或动态入口证据。
- 备份恢复路径无法证明与旧委托链无关。
- 依赖删除导致现有资产、插件或运行功能缺失。
- MySQL 连接收口需要改变超时、重试、缓存或同步时序。
- 同一问题连续修改三次仍未通过验证。
- 为完成清理必须扩大到财务查询、schema、数据库迁移或其他暂缓范围。

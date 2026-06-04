# dentist_app Android 端项目内渐进式拆分实施方案

## 结论

`D:\Data\android_project\dentist_app\android_app` 是需要拆分的 Android 端 Flutter 项目。

参考 Windows 端拆分经验，采用"原项目内渐进式拆分"：同一模块、同一层级、同一职责簇、同一验证路径的内容可以成组拆分；不同风险边界不能混在同一轮。

Android 端项目不做大重构，不迁移新工程，不改 UI，不改数据库 schema。

## 固定范围

目标项目：

- `D:\Data\android_project\dentist_app\android_app`

本方案不处理：

- Windows 端代码（`windows_app`）
- 其他仓库或历史参考工程
- `android_app` 之外的迁移逻辑，除非用户明确指定

## 参考原则（来自 Windows 端经验）

### 拆分原则

- 每次只拆一个模块。
- 后续拆分优先提升速度和效率：同一模块、同一层级、强相关且可一次验证的内容可以合并到同一轮处理。
- 前端/UI 拆分必须默认按完整职责组成组拆，例如同一弹窗里的同类 section、同一区域的标题/按钮/列表/行/输入控件应尽量同轮拆到同一个职责文件；不要把一个 UI 区域拆成"只拆标题""只拆按钮""只拆外层容器"这类多轮小部位。
- 同一轮仍不能混合高风险边界：UI 拆分、Provider/Service 拆分、Repository/Data Source 拆分、数据库 schema、验证错误修复不要混在一起；数据库 schema 永远单独确认。
- 不再为了几行代码单独开一轮，除非该小步是阻断后续拆分的必要前置。
- 后续默认速度档位：UI 批量拆必须比较大胆，一轮拆同一大文件内 3-6 个强相关 section，或一个完整 UI 职责组内的标题、操作按钮、列表项、输入控件和空/加载/错误状态；Provider/Service 中等速度，一轮拆一条完整流程或一组强相关规则；Data Source 保守，一轮只处理一个数据源边界。
- 提速上限是"同模块 + 同层级 + 同职责簇 + 同验证路径"。超过这个上限，例如同轮同时拆多个不同模块的文件，必须拆开执行。
- 之前拆出的细粒度小文件不要为了形式统一立刻合并；只有当多个文件职责过碎、总是一起修改、不能独立复用、合并后能减少理解成本且不扩大验证范围时，才在同类职责收尾轮合并。
- 拆分前后 UI、入口、用户操作路径、数据库 schema、原功能保持不变。
- 不做全项目格式化，不顺手重构无关代码，不清理拆分前已存在的无关死代码。
- 删除文件、目录、Git 回滚、数据库迁移、CI/CD、密钥配置、发布部署都必须先问用户。
- 拆分时如果发现历史遗留无用代码，必须先明确告诉用户疑似无用代码的名称、位置和判断依据；只有用户确认后才能删除。删除后必须提示用户执行验证，并在本计划文档中记录删除原因、范围和验证重点。

### 智能档位选择

- 默认按低智能执行纯 UI 小组件拆分、已确认无引用代码清理、import 清理、拆分计划文档更新等低风险任务。
- 遇到 Provider、Service、Repository/Data Source 拆分，或涉及权限、缓存刷新、SQLite/MySQL 数据源差异、业务流程边界判断时，必须先提醒用户建议切换到中智能，再继续执行。
- 遇到复杂 `flutter analyze` 错误排查、外部 SDK/API 对比、历史代码是否可删的证据判断、跨多个文件的调用链调整时，必须先提醒用户建议切换到中智能。
- 如果任务已经明显属于中智能场景，但用户要求继续用低智能，可以继续执行，但必须把风险点和验证重点说清楚。

### 进度同步

- 每次改完代码或文档后，必须更新本计划文档中的当前阶段、最近记录和下一步建议。
- 本计划文档只保留当前状态、最近 3-5 轮高价值记录、下一步建议、验证命令和历史归档索引，避免长期堆积完整流水账。
- 详细历史记录归档到 `docs/android_split_history/` 下，按模块或阶段命名；需要追溯旧轮次时再打开归档文件。
- 新一轮进度记录必须能支持新开窗口继续工作：写清楚本轮改了哪些文件、拆出了什么组件/职责、哪些职责仍留在原文件、下一步建议做什么。
- 如果本轮只是清理历史无用代码或修验证错误，也要在主计划写当前摘要，并在归档记录原因、范围和验证重点。

### 验证要求

- Android 端验证优先在 `D:\Data\android_project\dentist_app\android_app` 内执行。
- 只负责修改代码和文档，不主动执行 `flutter analyze`、`flutter run`、`dart format`、测试命令或其他验证命令。
- 每次需要验证时，必须把完整命令发给用户，由用户手动执行并反馈结果。
- 基础验证命令是：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

- 如需格式化，只格式化本轮涉及的 `.dart` 文件或目录。
- 如需运行应用，给出完整 `flutter run` 命令，用户执行。
- 每次改完代码或文档后，必须更新拆分方案中的进度提示。

## 最新修复记录

### 2026-06-01 第一批根级私有弹窗归位

### 变更范围

- 将 `lib/widgets/financial_statistics_dialog.dart` 迁移到 `lib/features/financial/widgets/financial_statistics_dialog.dart`
- 将 `lib/widgets/purchase_record_dialog.dart` 迁移到 `lib/features/purchases/widgets/purchase_record_dialog.dart`
- 将 `lib/widgets/purchase_item_dialog.dart` 迁移到 `lib/features/purchases/widgets/purchase_item_dialog.dart`
- 将 `lib/widgets/user_dialog.dart` 迁移到 `lib/features/users/widgets/user_dialog.dart`

### 同步修正

- `lib/features/financial/widgets/progressive_statistics_dialog.dart` 改为直接引用同目录下的 `financial_statistics_dialog.dart`
- `lib/features/purchases/screens/purchase_records_screen.dart` 改为引用 feature 内的 `purchase_record_dialog.dart`
- `lib/screens/financial_management_screen.dart` 改为引用 feature 内的 `financial_statistics_dialog.dart`
- `lib/screens/purchase_detail_screen.dart` 改为引用 feature 内的 `purchase_item_dialog.dart` 和 `purchase_record_dialog.dart`
- `lib/screens/user_detail_screen.dart` 与 `lib/screens/users_screen.dart` 改为引用 feature 内的 `user_dialog.dart`

### 当前结果

- 根级 `lib/widgets/` 已不再保留这 4 个模块私有弹窗
- `confirm_dialogs.dart` 只做了归属审计，暂时保留在根级

### 下一步建议

进入第二批 UI 收口，优先处理：

1. `lib/screens/appointments_screen.dart`
2. `lib/screens/patients_screen.dart`
3. `lib/screens/financial_management_screen.dart`
4. `lib/features/settings/widgets/settings_dialogs.dart`

### 验证重点

- 基础验证命令仍然是：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### 问题描述
拆分后运行安卓端应用时，UserProvider 初始化失败：
- MySQL 数据源设置成功
- 但随即报错 "SQLite用户数据源未初始化"
- 无法进入应用页面

### 根本原因分析
异常处理中的多个 print 语句在访问 Provider 对象时导致了二级异常：
1. 初始化过程中某个环节抛出异常
2. catch 块执行 print 语句时，访问 _mysqlDataSource 等对象触发错误
3. 异常处理逻辑将 _dataSourceType 重置为 'sqlite'，但 _sqliteDataSource 未初始化
4. 后续任何访问 _currentDataSource 的操作都会抛出 "SQLite用户数据源未初始化" 异常

### 修复方案（已实施）
对 [user_provider.dart](lib/providers/user_provider.dart) 做以下调整：

1. **移除 catch 块中的调试 print 语句**  
   - 删除打印 _mysqlConnection、_database、_mysqlDataSource 等对象的 print 语句
   - 这些语句访问对象时可能触发错误

2. **不重置 _dataSourceType**  
   - 删除 `_dataSourceType = 'sqlite';` 这一行
   - 保持初始化时设置的数据源类型状态

3. **清理冗余调试代码**  
   - 移除 setMySqlDataSource() 中的 print 语句
   - 移除 _currentDataSource getter 中的 print 语句  
   - 移除 getAllUsers() 中的详细 print 语句
   - 移除 clearCache() 中的 print 语句

### 验证指标
修复完成后，运行以下命令验证：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze  # 检查编译错误
flutter run  # 在模拟器或真机上运行应用
```

预期行为：
- 应用能成功启动
- 进入登录界面（不卡在初始化）
- 使用 MySQL 数据源时正常连接和展示数据

## 当前状态分析

### 目录结构

当前 Android 端目录结构：

```
lib/
├── data_sources/          # 数据源层（7个文件）
├── docs/                   # 文档
├── models/                 # 模型层
│   └── schemas/           # 数据库 schema
├── providers/              # Provider 层（14个文件）
├── screens/               # 屏幕/页面层
├── theme/                 # 主题
├── utils/                 # 工具类
└── widgets/               # 组件层
```

### 大文件分析（行数统计）

当前 Android 端行数最多的文件：

| 文件 | 行数 | 优先级 |
| --- | ---: | ---: |
| screens\settings_screen.dart | 3894 | P0 |
| widgets\appointment_form_sheet.dart | 1983 | P0 |
| providers\financial_provider.dart | 1942 | P0 |
| screens\patient_detail_screen.dart | 1894 | P0 |
| widgets\patient_form_sheet.dart | 1893 | P0 |
| screens\financial_management_screen.dart | 1770 | P0 |
| screens\patients_screen.dart | 1621 | P0 |
| widgets\financial_statistics_dialog.dart | 1572 | P1 |
| providers\patient_provider.dart | 1491 | P0 |
| providers\database_provider.dart | 1488 | P0 |
| widgets\success_toast.dart | 1394 | P1 |
| widgets\financial_record_dialog.dart | 1334 | P1 |
| screens\financial_detail_screen.dart | 1324 | P1 |
| screens\dashboard_screen.dart | 1293 | P1 |
| screens\appointments_screen.dart | 1287 | P1 |
| providers\purchase_provider_bak.dart | 1233 | P2（备份文件） |
| widgets\purchase_statistics_dialog.dart | 1185 | P1 |
| screens\login_screen.dart | 1169 | P1 |
| screens\purchase_detail_screen.dart | 1148 | P1 |
| providers\user_provider.dart | 1147 | P0 |
| screens\appointment_detail_screen.dart | 1142 | P1 |

### 与 Windows 端对比

Windows 端已完成的工作：
- Data Source 层已完成 SQLite/MySQL 物理隔离
- 患者模块已建立 features/patients/ 结构
- 大部分模块已建立 features/ 目录
- Provider 层部分已拆分 Service
- UI 层部分已拆分独立 Widget

Android 端当前状态：
- Data Source 层已完成 SQLite/MySQL 物理隔离（接口+实现）
- features/ 目录结构已建立（A0 已完成）
- 所有代码仍在根级目录（data_sources、providers、screens、widgets）
- 大文件数量较多，最大文件 3894 行

## 拆分目标

参考 Windows 端目标，按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的原则进行拆分：

1. **结构清晰**：建立 features/ 目录结构，按模块组织代码，形成清晰的模块化架构
2. **排查问题更快**：降低单文件行数，明确职责边界，让问题定位更快速
3. **增加功能更容易**：模块化结构，新功能有明确落点，减少改动范围
4. **文件职责明确**：单一职责原则，每个文件只负责一个明确的职责
5. **减少混用和耦合**：UI、业务逻辑、数据访问分层清晰，降低层间耦合

## 拆分路线

### 阶段 0：准备工作

#### A0：建立目录结构

创建 features/ 目录及子目录：

```
lib/features/
├── patients/          # 患者模块
│   ├── models/
│   ├── services/
│   └── widgets/
├── appointments/      # 预约模块
│   ├── models/
│   ├── services/
│   └── widgets/
├── financial/         # 财务模块
│   ├── models/
│   ├── services/
│   └── widgets/
├── medical_records/   # 病历模块
│   ├── models/
│   ├── services/
│   └── widgets/
├── materials/         # 材料模块
│   ├── models/
│   ├── services/
│   └── widgets/
├── purchases/         # 采购模块
│   ├── models/
│   ├── services/
│   └── widgets/
├── users/             # 用户模块
│   ├── models/
│   ├── services/
│   └── widgets/
├── settings/          # 设置模块
│   ├── models/
│   ├── services/
│   └── widgets/
└── dashboard/         # 仪表盘模块
    ├── models/
    ├── services/
    └── widgets/
```

#### A1：清理备份文件

删除或移动备份文件：
- providers\purchase_provider_bak.dart（1233行）

### 阶段 1：Data Source 层拆分（已完成）

**状态：已完成**

安卓端的 Data Source 层已经完成了 SQLite/MySQL 物理隔离，每个 data_source.dart 文件都包含：
- 抽象接口定义
- SQLite 实现
- MySQL 实现

无需再进行拆分，直接跳过阶段 1。

### 阶段 2：患者模块拆分（参考 Windows 端患者模块经验）

目标：将患者模块代码迁移到 features/patients/，拆分 Provider 和 UI。

#### P1：患者 Provider 拆分

- P1.1：提取患者核心逻辑为 patient_core_service.dart
- P1.2：提取患者初始化逻辑为 patient_initialization_service.dart
- P1.3：提取患者列表逻辑为 patient_list_service.dart
- P1.4：提取患者搜索逻辑为 patient_search_service.dart
- P1.5：简化 patient_provider.dart 主文件

#### P2：患者 UI 组件拆分

- P2.1：迁移 patient_form_sheet.dart 到 features/patients/widgets/
- P2.2：拆分 patient_form_sheet.dart 为多个小组件
- P2.3：拆分 patient_detail_screen.dart 为多个小组件
- P2.4：拆分 patients_screen.dart 为多个小组件

### 阶段 3：设置模块拆分（延后，3894行）

目标：拆分 settings_screen.dart（3894行），这是当前最大文件。

**说明：** 由于文件过大（3894行），拆分复杂度高，建议先完成其他模块拆分后再处理。

#### S1：设置页 UI 组件拆分

- S1.1：提取数据源设置区域为独立 Widget
- S1.2：提取备份恢复区域为独立 Widget
- S1.3：提取同步配置区域为独立 Widget
- S1.4：提取系统设置区域为独立 Widget

#### S2：Settings Provider 拆分

- S2.1：提取配置存储管理为 config_storage_service.dart
- S2.2：提取备份管理逻辑为 backup_management_service.dart
- S2.3：提取数据源管理逻辑为 data_source_management_service.dart
- S2.4：简化 settings_provider.dart 主文件

### 阶段 4：财务模块拆分（进行中）

目标：拆分财务模块的大文件。

#### F1：财务 Provider 拆分

- F1.1：提取财务缓存管理为 financial_cache_helper.dart
- F1.2：提取财务权限过滤为 financial_permission_service.dart
- F1.3：提取财务连接管理为 financial_connection_service.dart
- F1.4：简化 financial_provider.dart 主文件

#### F2：财务 UI 组件拆分

- F2.1：迁移 financial_statistics_dialog.dart 到 features/financial/widgets/
- F2.2：拆分 financial_statistics_dialog.dart 为多个小组件
- F2.3：迁移 financial_record_dialog.dart 到 features/financial/widgets/
- F2.4：拆分 financial_record_dialog.dart 为多个小组件
- F2.5：拆分 financial_management_screen.dart 为多个小组件
- F2.6：拆分 financial_detail_screen.dart 为多个小组件

### 阶段 5：预约模块拆分

目标：拆分预约模块的大文件。

#### AP1：预约 UI 组件拆分

- AP1.1：迁移 appointment_form_sheet.dart 到 features/appointments/widgets/
- AP1.2：拆分 appointment_form_sheet.dart 为多个小组件
- AP1.3：拆分 appointments_screen.dart 为多个小组件
- AP1.4：拆分 appointment_detail_screen.dart 为多个小组件

### 阶段 6：其他模块拆分

#### O1：用户模块拆分

- O1.1：拆分 user_provider.dart
- O1.2：拆分 login_screen.dart
- O1.3：建立 features/users/widgets/ 目录

#### O2：采购模块拆分

- O2.1：拆分 purchase_provider.dart
- O2.2：迁移 purchase_statistics_dialog.dart 到 features/purchases/widgets/
- O2.3：拆分 purchase_statistics_dialog.dart
- O2.4：拆分 purchase_records_screen.dart
- O2.5：拆分 purchase_detail_screen.dart

#### O3：仪表盘模块拆分

- O3.1：拆分 dashboard_screen.dart
- O3.2：建立 features/dashboard/widgets/ 目录

#### O4：全局组件整理

- O4.1：分析 success_toast.dart（1394行），判断是否混入复杂 UI
- O4.2：将模块专用组件迁移到对应 features/ 目录
- O4.3：保留真正通用的组件在 widgets/

### 阶段 7：Database Provider 拆分

目标：拆分 database_provider.dart（1488行），这是核心数据库管理文件。

#### DB1：Database Provider 拆分

- DB1.1：提取 SQLite 初始化逻辑为 sqlite_database_service.dart
- DB1.2：提取 MySQL 连接管理为 mysql_connection_service.dart
- DB1.3：提取模块数据源绑定为 module_data_source_binding_service.dart
- DB1.4：提取数据库健康检查为 database_health_service.dart
- DB1.5：简化 database_provider.dart 主文件

### 阶段 8：边界收口和验证

目标：按照 Windows 端审计报告建议，进行边界收口。

#### B1：清理 part 文件（如果有）

- B1.1：检查是否有 part 文件
- B1.2：将 part 文件改为独立 Widget 或 Service
- B1.3：确保 Widget 通过构造函数暴露依赖

#### B2：Provider 层收口

- B2.1：确保 Provider 不再直接拼 SQL
- B2.2：确保 Provider 不再直接创建 MySQL 连接
- B2.3：确保 Provider 只保留状态管理和流程编排

#### B3：Data Source 查询构造收口

- B3.1：提取 where builder 方法
- B3.2：提取 args builder 方法
- B3.3：count/page 查询复用同一搜索条件生成逻辑

## 当前进度

| 阶段 | 模块 | 状态 | 说明 |
| --- | --- | --- | --- |
| 0 | 准备工作 | 已完成 | A0 已完成，A1 已完成 |
| 1 | Data Source 层拆分 | 已完成 | 已完成 SQLite/MySQL 物理隔离 |
| 2 | 患者模块拆分 | 已完成 | P1 Provider 拆分已完成，P2 UI 拆分已完成，P2.3 患者详情页拆分已完成，P2.4 患者列表页拆分已完成 |
| 3 | 设置模块拆分 | 已完成 | S1 UI 组件拆分已完成（S1.1-S1.5），S2 Service 拆分已完成（S2.1-S2.4），S3 对话框拆分已完成（S3.1-S3.6），S4 工具类拆分已完成（S4.1-S4.2），S5 对话框进一步拆分已完成（S5.1-S5.3），S6 SQLite 配置对话框拆分已完成（S6.1-S6.2），主文件从 3894 行减少到 963 行 |
| 4 | 财务模块拆分 | 进行中 | F1 Provider 拆分已完成，F2 UI 拆分进行中（F2.1 财务记录对话框拆分已完成，F2.2 财务统计对话框拆分已完成，F2.3 财务管理页面拆分已完成，F2.4 财务详情页面拆分已完成，F2.5 财务记录对话框组件拆分已完成） |
| 5 | 预约模块拆分 | 已完成 | AP1.1、AP1.2、AP1.3、AP1.4 已完成 |
| 6 | 其他模块拆分 | 进行中 | 用户（O1.1.1-O1.1.11 Provider 拆分已完成，O1.2 已完成）、采购（O2.1 Provider 拆分已完成，O2.2、O2.3、O2.4、O2.5 已完成）、仪表盘（O3.1 已完成）、患者图片（PI1-PI4 已完成）、全局组件（O4.1 success_toast.dart 拆分已完成） |
| 7 | Database Provider 拆分 | 已完成 | DB1.1-DB1.6 已完成，从 1488 行减少到约 800 行 |
| 8 | 边界收口和验证 | 未开始 | 最终收口和验证 |

## 最近记录

### 2026-05-31：Database Provider 拆分（DB1.1-DB1.6 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 database_provider.dart 进行职责拆分。

**拆分内容：**

- DB1.1：创建 mysql_connection_service.dart
  - 新文件：lib/services/mysql_connection_service.dart
  - 职责：MySQL 连接创建、关闭、参数配置、localhost 转换、字符编码设置
  - 方法：initConnection()、initWithParams()、testConnection()、closeConnection()

- DB1.2：创建 database_health_service.dart
  - 新文件：lib/services/database_health_service.dart
  - 职责：连接健康检查、快速检查、健康监控定时器
  - 方法：startHealthMonitoring()、stopHealthMonitoring()、testConnectionHealth()

- DB1.3：创建 mysql_reconnect_service.dart
  - 新文件：lib/services/mysql_reconnect_service.dart
  - 职责：自动重连逻辑、指数退避、重连状态管理
  - 方法：manualReconnect()、forceReconnect()、ensureConnection()、checkConnectionOnAppResume()、smartConnectionCheck()

- DB1.4：创建 sqlite_initialization_service.dart
  - 新文件：lib/services/sqlite_initialization_service.dart
  - 职责：SQLite 数据库初始化、路径管理、默认路径设置
  - 方法：initDatabase()、initWithNotification()、ensureDatabasePath()、getDatabase()、closeDatabase()

- DB1.5：创建 database_sync_service.dart
  - 新文件：lib/services/database_sync_service.dart
  - 职责：数据同步检查、强制同步
  - 方法：checkAndSyncData()、forceDataSync()

- DB1.6：简化 database_provider.dart 主文件
  - 添加服务实例：_mysqlConnectionService、_healthService、_reconnectService、_sqliteInitService、_syncService
  - 移除连接管理方法：_initMySQLConnection()、_initMySQLConnectionWithParams()、_testMySQLConnection()（改为调用服务）
  - 移除健康检查方法：_checkConnectionHealth()、_quickConnectionCheck()、_testConnectionHealth()（改为调用服务）
  - 移除重连方法：_startAutoReconnect()、_performReconnect()（改为调用服务）
  - 移除 SQLite 初始化方法：_initSQLiteWithNotification()（改为调用服务）
  - 移除同步方法：_checkAndSyncData()、forceDataSync()（改为调用服务）
  - 更新所有调用点：使用服务实例替代直接调用
  - 从 1488 行减少到约 800 行（减少约 688 行，减少 46.2%）

**效果：**

- database_provider.dart 从 1488 行减少到约 800 行（减少约 688 行，减少 46.2%）
- 创建 5 个独立的 Service，职责明确
- MySQL 连接管理、健康检查、自动重连、SQLite 初始化、数据同步职责分离
- Provider 层只保留状态管理、数据源绑定、配置管理、缓存管理、数据库切换逻辑
- 符合分层架构原则（UI → Provider → Service → Data）
- 职责明确：Provider 负责状态管理和流程编排，Service 负责具体业务逻辑
- 便于测试和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分
- Database Provider 拆分已完成，达到合理边界

### 2026-05-31：全局组件 success_toast.dart 拆分（O4.1 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 success_toast.dart 进行职责拆分。

**拆分内容：**

- O4.1.1：创建 toast_widgets.dart
  - 新文件：lib/widgets/toast_widgets.dart
  - 职责：Toast UI 组件
  - 组件：SuccessToast、SuccessToastBottom、DeleteSuccessToast、DeleteSuccessToastBottom

- O4.1.2：创建 toast_manager.dart
  - 新文件：lib/widgets/toast_manager.dart
  - 职责：Toast 管理器
  - 组件：SuccessToastManager（show、showError、showInfo）、DeleteSuccessToastManager（show）

- O4.1.3：创建 confirm_dialogs.dart
  - 新文件：lib/widgets/confirm_dialogs.dart
  - 职责：确认对话框组件
  - 组件：DeleteConfirmDialog、DeleteConfirmDialogManager、LogoutConfirmDialog、LogoutConfirmDialogManager、ModernDeleteDialog、ModernDeleteDialogManager

- O4.1.4：更新所有引用文件
  - 更新 16 个文件的 import 语句
  - widgets：user_dialog.dart、purchase_record_dialog.dart、purchase_item_dialog.dart
  - screens：user_detail_screen.dart、users_screen.dart、sync_logs_screen.dart、settings_screen.dart、purchase_detail_screen.dart、patient_detail_screen.dart、patients_screen.dart、financial_management_screen.dart、financial_detail_screen.dart、dashboard_screen.dart、appointments_screen.dart
  - features：purchase_records_screen.dart、financial_record_dialog.dart

- O4.1.5：删除原文件
  - 删除 lib/widgets/success_toast.dart（1395行）

**效果：**

- success_toast.dart 从 1395 行拆分为 3 个职责明确的文件
- Toast 组件、Toast 管理器、确认对话框职责分离
- 符合"文件职责明确、减少混用和耦合"的拆分目标
- 便于后续维护和扩展

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分

### 2026-05-31：财务记录对话框组件拆分（F2.5 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 financial_record_dialog.dart 进行 UI 组件拆分。

**拆分内容：**

- F2.5.1：创建 dialog_header.dart 组件
  - 新文件：lib/features/financial/widgets/dialog_header.dart
  - 职责：对话框标题栏（图标、标题、关闭按钮）
  - 参数：title、isEditing、onClose

- F2.5.2：创建 patient_selection_section.dart 组件
  - 新文件：lib/features/financial/widgets/patient_selection_section.dart
  - 职责：患者选择区域（SectionTitle + 患者选择 TextField）
  - 参数：selectedPatient、patientNameController、onTap、isEditingNotesOnly

- F2.5.3：创建 charge_info_section.dart 组件
  - 新文件：lib/features/financial/widgets/charge_info_section.dart
  - 职责：收费信息区域（日期、项目名称、金额输入）
  - 参数：各控制器、焦点节点、验证器

- F2.5.4：创建 notes_section.dart 组件
  - 新文件：lib/features/financial/widgets/notes_section.dart
  - 职责：备注信息区域（SectionTitle + 备注 TextFormField）
  - 参数：notesController

- F2.5.5：迁移主文件到 features/financial/widgets/
  - 从 lib/widgets/financial_record_dialog.dart 迁移到 lib/features/financial/widgets/financial_record_dialog.dart
  - 更新 import 语句，使用新组件
  - 替换 UI 代码为新组件调用

- F2.5.6：更新引用文件
  - 更新 financial_management_screen.dart 的 import 路径
  - 更新 financial_detail_screen.dart 的 import 路径

**效果：**

- financial_record_dialog.dart 从 809 行减少到 638 行（减少 171 行，减少 21.1%）
- 创建 4 个独立的 UI 组件，职责明确
- UI 组件可复用，便于测试和维护
- 符合拆分目标：结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分
- 财务记录对话框组件拆分已完成，达到合理边界

### 2026-05-31：用户模块 Provider 深度拆分（O1.1.6-O1.1.11 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 user_provider.dart 进行深度业务逻辑迁移。

**拆分内容：**

- O1.1.6：提取认证逻辑为 user_authentication_service.dart
  - 新文件：lib/features/users/services/user_authentication_service.dart
  - 职责：用户登录、登出、认证
  - 方法：login()、authenticateUser()、logout()
  - 依赖：UserDataSource、UserPermissionService、DatabaseOperationWrapper

- O1.1.7：提取数据验证为 user_validation_service.dart
  - 新文件：lib/features/users/services/user_validation_service.dart
  - 职责：用户名/邮箱存在性检查
  - 方法：isUsernameExists()、isEmailExists()
  - 依赖：UserConnectionService

- O1.1.8：提取初始化逻辑为 user_initialization_service.dart
  - 新文件：lib/features/users/services/user_initialization_service.dart
  - 职责：Provider 初始化、数据源设置
  - 方法：initializeFromDatabase()、_initializeMySQL()、_initializeSQLite()
  - 依赖：UserConnectionService、UserDataSource

- O1.1.9：提取数据修复为 user_data_repair_service.dart
  - 新文件：lib/features/users/services/user_data_repair_service.dart
  - 职责：数据库数据修复
  - 方法：fixInvalidRoles()、_fixMySQLRoles()、_fixSQLiteRoles()
  - 依赖：UserConnectionService

- O1.1.10：简化 user_provider.dart 主文件
  - 添加服务实例：_authenticationService、_validationService、_initializationService、_dataRepairService
  - 移除认证相关方法：login()、authenticateUser()、logout()（改为调用服务）
  - 移除验证相关方法：isUsernameExists()、isEmailExists()（改为调用服务）
  - 移除初始化逻辑：initializeFromDatabase()（改为调用服务）
  - 移除修复逻辑：fixInvalidRoles()（改为调用服务）
  - 更新所有调用点：使用服务实例替代直接调用
  - 从 952 行减少到约 735 行（减少约 217 行，减少 22.8%）

**效果：**

- user_provider.dart 从 952 行减少到约 735 行（减少约 217 行，减少 22.8%）
- 所有直接数据库操作已迁移到服务层
- Provider 层只保留状态管理、数据源管理和核心业务流程（用户 CRUD）
- 符合分层架构原则（UI → Provider → Service → Data）
- 职责更加明确：Provider 负责状态管理和流程编排，Service 负责具体业务逻辑
- 便于测试和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）
- 用户模块 Provider 拆分已完成，达到合理边界

### 2026-05-31：用户模块 Provider 拆分（O1.1.1-O1.1.5 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 user_provider.dart 进行业务逻辑迁移。

**拆分内容：**

- O1.1.1：提取缓存管理为 user_cache_service.dart
  - 新文件：lib/features/users/services/user_cache_service.dart
  - 职责：用户列表缓存、权限缓存管理
  - 方法：isCacheValid()、updateCache()、clearCache()、getCachedUsers()、isPermissionsCacheValid()、getPermissionsCache()、updatePermissionsCache()、clearPermissionsCache()
  - 缓存有效期：用户数据10分钟，权限20分钟

- O1.1.2：提取权限控制为 user_permission_service.dart
  - 新文件：lib/features/users/services/user_permission_service.dart
  - 职责：权限获取、权限检查、权限更新、医生过滤条件
  - 方法：getUserPermissions()、hasModulePermission()、updateUserPermissions()、buildDoctorFilter()、shouldFilterByDoctor()、loadCurrentUserPermissions()、refreshCurrentUserPermissions()、hasCurrentUserModulePermission()、getCurrentUserPermissions()
  - 依赖：UserDataSource、UserCacheService

- O1.1.3：提取连接管理为 user_connection_service.dart
  - 新文件：lib/features/users/services/user_connection_service.dart
  - 职责：MySQL 连接获取、连接状态检查、连接确保
  - 方法：getCurrentMysqlConnection()、getSqliteDatabase()、isInitialized()、testMySqlConnection()、testSQLiteConnection()、ensureConnection()、resetConnectionState()、setReconnecting()
  - 状态管理：isConnected、isReconnecting、lastError

- O1.1.4：提取统计方法为 user_statistics_service.dart
  - 新文件：lib/features/users/services/user_statistics_service.dart
  - 职责：用户统计信息查询
  - 方法：getUserStatistics()
  - 支持 SQLite 和 MySQL 双数据源

- O1.1.5：简化 user_provider.dart 主文件
  - 添加服务实例：_cacheService、_connectionService、_permissionService、_statisticsService
  - 移除缓存相关字段和方法：_cachedUsers、_lastCacheTime、_cacheValidDuration、_isCacheValid()、_updateCache()（改为调用服务）
  - 移除权限缓存相关字段和方法：_permissionsCache、_permissionsCacheTime、_permissionsCacheValidDuration、_isPermissionsCacheValid()、clearPermissionsCache()（改为调用服务）
  - 移除连接管理方法：_currentMysqlConnection getter（改为调用服务）
  - 移除统计方法：getUserStatistics()（改为调用服务）
  - 移除权限相关方法：getUserPermissions()、hasModulePermission()、updateUserPermissions()、loadCurrentUserPermissions()、refreshCurrentUserPermissions()、hasCurrentUserModulePermission()、getCurrentUserPermissions()、buildDoctorFilter()、shouldFilterByDoctor()（改为调用服务）
  - 更新所有调用点：使用服务实例替代直接调用
  - 从 1147 行减少到约 950 行（减少约 200 行，减少 17.4%）

**效果：**

- user_provider.dart 从 1147 行减少到约 950 行（减少约 200 行，减少 17.4%）
- 业务逻辑已全部迁移到 Service 层
- Provider 层只保留状态管理、数据源管理和核心业务流程（用户 CRUD、认证）
- 符合分层架构原则（UI → Service → Data）
- 职责明确：Provider 负责状态管理和流程编排，Service 负责具体业务逻辑
- 便于测试和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）
- 用户模块 Provider 拆分已完成，达到合理边界

### 2026-05-31：患者图片 Provider 拆分（PI1-PI4 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 patient_image_provider.dart 进行业务逻辑迁移。

**拆分内容：**

- PI3：提取 MySQL 结果处理为 mysql_row_processor.dart
  - 新文件：lib/utils/mysql_row_processor.dart
  - 职责：处理 MySQL 查询结果中的 Blob 字段、DateTime 类型转换、Uint8List 类型转换、字符串编码修复
  - 方法：processRow()
  - 通用工具类，可被其他 Provider 复用

- PI1：提取连接管理为 patient_image_connection_service.dart
  - 新文件：lib/features/patients/services/patient_image_connection_service.dart
  - 职责：MySQL 连接检查、自动重连、SQLite 连接检查、应用恢复时连接检查
  - 方法：ensureConnection()、autoReconnect()、checkSQLiteConnection()、checkConnectionOnResume()
  - 状态管理：isConnected、isReconnecting

- PI2：提取缓存管理为 patient_image_cache_service.dart
  - 新文件：lib/features/patients/services/patient_image_cache_service.dart
  - 职责：缓存有效性检查、缓存更新/清除、缓存数据获取、加载/错误状态管理
  - 方法：hasPatientMaterialsCache()、getPatientMaterialsCache()、updatePatientMaterialsCache()、hasMaterialImagesCache()、getMaterialImagesCache()、updateMaterialImagesCache()、clearPatientCache()、clearAllCache()、setLoadingState()、isLoading()、setError()、getError()、clearError()、hasCachedData()、getCachedMaterialCount()、getCachedImageCount()、getCachedImages()、getCachedMaterials()
  - 防抖通知机制（50ms）

- PI4：简化 patient_image_provider.dart 主文件
  - 添加服务实例：_connectionService、_cacheService
  - 移除 MySQL 结果处理方法：_processMySQLRow()（改为调用 MysqlRowProcessor.processRow()）
  - 移除连接管理方法：_ensureConnection()、_autoReconnect()、_checkSQLiteConnection()、_checkConnectionOnResume()（改为调用服务）
  - 移除缓存相关字段和方法：_patientMaterialsCache、_materialImagesCache、_loadingStates、_errorStates、_setLoadingState()、_setError()、_clearError()、_safeNotifyListeners()（改为调用服务）
  - 移除防抖定时器：_notifyTimer（迁移到缓存服务）
  - 更新所有调用点：使用服务实例替代直接调用
  - 从 887 行减少到 637 行（减少 250 行，减少 28.2%）

**效果：**

- patient_image_provider.dart 从 887 行减少到 637 行（减少 250 行，减少 28.2%）
- 业务逻辑已全部迁移到 Service 层
- Provider 层只保留状态管理、数据源管理和核心业务流程（患者材料查询、材料图片查询）
- 符合分层架构原则（UI → Service → Data）
- 职责明确：Provider 负责状态管理和流程编排，Service 负责具体业务逻辑
- MySQL 结果处理逻辑提取为通用工具类，便于其他 Provider 复用
- 便于测试和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）
- 患者图片 Provider 拆分已完成，达到合理边界

### 2026-05-31：预约模块 widgets 目录整理（已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 `lib/features/appointments/widgets/` 目录进行职责归属评估和迁移。

**评估结果：**

- **不需要迁移的文件（12个）**：预约模块专用组件，保留在 `features/appointments/widgets/`
  - appointment_action_buttons.dart - 预约操作按钮
  - appointment_calendar_view.dart - 预约日历视图
  - appointment_card.dart - 预约卡片
  - appointment_form_sheet.dart - 预约表单
  - appointment_info_card.dart - 预约信息卡片
  - appointment_search_filter_bar.dart - 预约搜索筛选栏
  - appointment_status_chip.dart - 预约状态标签
  - appointment_status_info.dart - 预约状态信息工具函数
  - teeth_condition_input.dart - 牙齿状况输入
  - treatment_info_display.dart - 治疗信息展示
  - treatment_items_input.dart - 治疗项目输入
  - time_picker_dialog.dart - 时间选择对话框

- **需要迁移的文件（2个）**：
  - date_time_card.dart - 通用日期时间卡片，迁移到 `lib/widgets/`
  - patient_selection_dialog.dart - 患者选择对话框，迁移到 `lib/features/patients/widgets/`

- **不迁移的文件（1个）**：
  - patient_info_card.dart - 预约模块专用，保留在 `features/appointments/widgets/`（财务模块有同名文件，实现不同）

**迁移内容：**

- 迁移 date_time_card.dart 到 `lib/widgets/date_time_card.dart`
- 迁移 patient_selection_dialog.dart 到 `lib/features/patients/widgets/patient_selection_dialog.dart`
- 更新 appointment_form_sheet.dart 的 import 路径：
  - `import 'package:dentist_app/widgets/date_time_card.dart'`
  - `import 'package:dentist_app/features/patients/widgets/patient_selection_dialog.dart'`
- 删除原位置的文件：
  - `lib/features/appointments/widgets/date_time_card.dart`
  - `lib/features/appointments/widgets/patient_selection_dialog.dart`

**效果：**

- 通用组件 date_time_card.dart 提取到 lib/widgets/，便于其他模块复用
- 患者相关组件 patient_selection_dialog.dart 归位到患者模块
- 预约模块保留自己的专用组件，职责明确
- 符合"结构清晰、文件职责明确、减少混用和耦合"的拆分目标

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证迁移
- 继续其他模块的拆分

### 2026-05-31：采购模块 Provider 拆分（O2.1 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 purchase_provider.dart 进行业务逻辑迁移。

**拆分内容：**

- O2.1.1：提取缓存管理为 purchase_cache_service.dart
  - 新文件：lib/features/purchases/services/purchase_cache_service.dart
  - 职责：缓存有效性检查、缓存更新、缓存清除、缓存数据获取
  - 方法：isCacheValid()、updateCache()、clearCache()、hasCache、cachedRecords
  - 缓存有效期：20分钟

- O2.1.2：提取权限控制为 purchase_permission_service.dart
  - 新文件：lib/features/purchases/services/purchase_permission_service.dart
  - 职责：医生过滤条件获取、权限判断
  - 方法：getDoctorFilter()、shouldFilterByDoctor()
  - 依赖：UserProvider

- O2.1.3：提取连接管理为 purchase_connection_service.dart
  - 新文件：lib/features/purchases/services/purchase_connection_service.dart
  - 职责：MySQL 连接测试、连接确保、自动重连、错误处理
  - 方法：testMySqlConnection()、ensureConnection()、autoReconnect()、resetConnectionState()
  - 状态管理：isConnected、isReconnecting、lastError

- O2.1.4：提取统计方法为 purchase_statistics_service.dart
  - 扩展现有文件：lib/features/purchases/services/purchase_statistics_service.dart
  - 新增类：PurchaseDatabaseStatisticsService
  - 职责：从数据库直接查询统计信息
  - 方法：getPurchaseStatistics()、getPurchaseStatisticsByDateRange()
  - 支持 SQLite 和 MySQL 双数据源
  - 支持权限过滤（基于医生字段）

- O2.1.5：简化 purchase_provider.dart 主文件
  - 添加服务实例：_cacheService、_permissionService、_connectionService、_statisticsService
  - 移除缓存相关字段和方法：_cachedRecords、_cachedStatistics、_lastCacheTime、_isCacheValid()、_updateCache()
  - 移除连接管理方法：_testMySqlConnection()、_ensureConnection()、_autoReconnect()、_clearError()、_setError()
  - 移除权限控制方法：_getDoctorFilter()、_shouldFilterByDoctor()
  - 移除统计方法：getPurchaseStatistics()、getPurchaseStatisticsByDateRange()（改为调用服务）
  - 更新 Getters：通过服务实例获取状态
  - 从 903 行减少到 632 行（减少 271 行，减少 30.0%）

**效果：**

- purchase_provider.dart 从 903 行减少到 632 行（减少 271 行，减少 30.0%）
- 业务逻辑已全部迁移到 Service 层
- Provider 层只保留状态管理、数据源管理和核心业务逻辑（采购记录 CRUD、采购项目明细 CRUD）
- 符合分层架构原则（UI → Service → Data）
- 职责明确：Provider 负责状态管理和流程编排，Service 负责具体业务逻辑
- 便于测试和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）
- 采购模块 Provider 拆分已完成，达到合理边界

### 2026-05-31：Utils 目录文件职责评估（U0 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 `lib/utils/` 目录下的 27 个文件进行职责评估，判断哪些是模块私有的（应该迁移到模块目录），哪些是共有的（应该保留在 utils 目录）。

**评估结果：**

**需要迁移到模块私有目录的文件（3个）：**

1. **dental_condition_integration.dart**
   - 职责：解析和处理患者的牙齿状况数据，支持病历与牙齿状况的关联
   - 引用：medical_record_detail_screen.dart, medical_record_pdf_exporter.dart
   - 判断：**模块私有** - 专门用于病历模块
   - 迁移目标：`lib/features/medical_records/utils/dental_condition_integration.dart`
   - 理由：仅被病历模块使用，职责明确属于病历功能

2. **financial_data_cleaner.dart**
   - 职责：检查和清理无效的财务记录（患者ID为0的记录）
   - 引用：financial_provider.dart
   - 判断：**模块私有** - 专门用于财务模块
   - 迁移目标：`lib/features/financial/utils/financial_data_cleaner.dart`
   - 理由：仅被财务模块使用，职责明确属于财务功能

3. **medical_record_pdf_exporter.dart**
   - 职责：将患者病历数据导出为标准化的PDF格式
   - 引用：medical_record_detail_screen.dart
   - 判断：**模块私有** - 专门用于病历模块
   - 迁移目标：`lib/features/medical_records/utils/medical_record_pdf_exporter.dart`
   - 理由：仅被病历模块使用，职责明确属于病历功能

**应该保留在 utils 目录的文件（24个）：**

- **应用级别工具（4个）**：app_lifecycle_manager.dart, app_paths.dart, config_utils.dart, connection_manager.dart
- **数据库相关工具（6个）**：database_operation_wrapper.dart, database_utils.dart, mysql_row_processor.dart, mysql_utils.dart, schema_validator.dart, sync_table_config.dart
- **同步相关工具（2个）**：sync_manager.dart, sync_logger.dart
- **数据迁移工具（2个）**：permission_migration.dart, purchase_migration.dart
- **通用UI工具（4个）**：message_toast_helper.dart, snackbar_util.dart, toast_util.dart, notification_helper.dart
- **通用业务工具（6个）**：datetime_formatter.dart, pinyin_util.dart, image_compressor.dart, permission_utils.dart, settings_manager.dart

**迁移计划：**

**阶段 U1：创建模块 utils 目录**
- U1.1：创建 `lib/features/medical_records/utils/` 目录
- U1.2：创建 `lib/features/financial/utils/` 目录

**阶段 U2：迁移模块私有文件**
- U2.1：迁移 dental_condition_integration.dart 到病历模块 utils 目录
- U2.2：迁移 financial_data_cleaner.dart 到财务模块 utils 目录
- U2.3：迁移 medical_record_pdf_exporter.dart 到病历模块 utils 目录，并更新内部引用

**阶段 U3：验证迁移结果**
- U3.1：执行 flutter analyze 验证
- U3.2：删除原文件

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**执行结果：**

- U1.1：创建 `lib/features/medical_records/utils/` 目录 - 已完成
- U1.2：创建 `lib/features/financial/utils/` 目录 - 已完成
- U2.1：迁移 dental_condition_integration.dart 到病历模块 - 已完成
- U2.2：迁移 financial_data_cleaner.dart 到财务模块 - 已完成
- U2.3：迁移 medical_record_pdf_exporter.dart 到病历模块并更新引用 - 已完成
- U3.1：flutter analyze 验证 - 已通过（用户确认无报错）
- U3.2：删除原文件 - 已完成

**更新的引用文件：**
- medical_record_detail_screen.dart - 更新了 import 路径
- medical_record_pdf_exporter.dart - 更新了内部 import 路径

**下一步建议：**

- Utils 目录迁移已完成，3个模块私有文件已迁移到对应模块
- 继续其他模块的拆分工作

### 2026-05-31：Provider 层业务逻辑迁移到 Service 层（已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对 settings_provider.dart 进行业务逻辑迁移。

**拆分内容：**

- SP.1：迁移数据库切换逻辑到 database_switch_service.dart
  - 移除对 DatabaseSettingsManager 的依赖
  - 添加 initDatabaseConfig() 静态方法
  - 添加 switchDatabaseType() 静态方法
  - 职责：数据库配置初始化和切换

- SP.2：迁移备份恢复逻辑到 backup_restore_service.dart
  - 移除对 DatabaseSettingsManager 的依赖
  - 将所有方法改为静态方法
  - 添加 dbType 参数
  - 职责：数据库备份、恢复、导入导出

- SP.3：迁移MySQL连接测试逻辑到 mysql_config_service.dart
  - 增强 testMySqlConnection() 方法，添加重试机制和Socket连接测试
  - 职责：MySQL连接测试

- SP.4：创建 excel_export_service.dart 并迁移Excel导出逻辑
  - 新文件：lib/features/settings/services/excel_export_service.dart
  - 迁移 exportPatientsToExcel() 方法
  - 迁移 _convertDentalJsonToText() 方法
  - 迁移 _formatDentalCondition() 方法
  - 职责：Excel导出功能

- SP.5：简化 DatabaseSettingsManager 为纯状态管理类
  - 移除所有业务逻辑方法
  - 保留状态管理功能（dbType、dbPath、dbConfig）
  - 添加 setDbConfig()、setDbType()、setDbPath() 方法
  - 从 647 行减少到 33 行（减少 94.9%）

- SP.6：更新 settings_screen.dart
  - 移除 _dbSettingsManager 变量
  - 使用 DatabaseSwitchService.initDatabaseConfig()
  - 使用 DatabaseSwitchService.switchDatabaseType()
  - 更新对话框调用参数

- SP.7：更新 settings_dialogs.dart
  - 更新 showBackupDialog() 方法签名，移除 DatabaseSettingsManager 参数
  - 更新 showRestoreDialog() 方法签名，移除 DatabaseSettingsManager 参数
  - 更新 showExportDialog() 方法签名，移除 DatabaseSettingsManager 参数
  - 使用 BackupRestoreService 静态方法
  - 使用 ExcelExportService 静态方法

**效果：**

- settings_provider.dart 从 752 行减少到 129 行（减少 623 行，减少 82.8%）
- DatabaseSettingsManager 从 647 行减少到 33 行（减少 614 行，减少 94.9%）
- 业务逻辑已全部迁移到 Service 层
- Provider 层只保留状态管理功能
- 符合分层架构原则（UI → Service → Data）
- 职责明确：Provider 负责状态管理，Service 负责业务逻辑

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 继续其他模块的拆分（财务模块 F2）
- Provider 层业务逻辑迁移已完成，达到合理边界

### 2026-05-31：阶段 3 设置模块拆分（S6 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对设置页面进行 SQLite 配置对话框拆分。

**拆分内容：**

- S6.1：提取 SQLite 激活成功对话框到 sqlite_config_dialogs.dart
  - 新文件：lib/features/settings/widgets/sqlite_config_dialogs.dart
  - 新方法：showSqliteActivatedDialog()
  - 职责：显示 SQLite 激活成功对话框
  - 替换主文件中的对话框代码为 SqliteConfigDialogs.showSqliteActivatedDialog() 调用

- S6.2：提取 SQLite 配置已保存对话框到 sqlite_config_dialogs.dart
  - 新方法：showSqliteConfigSavedDialog()
  - 职责：显示 SQLite 配置已保存对话框（单个确定按钮）
  - 新方法：showSqliteConfigSavedDialogWithLoadOption()
  - 职责：显示 SQLite 配置已保存对话框（询问是否立即加载）
  - 替换主文件中的对话框代码为 SqliteConfigDialogs.showSqliteConfigSavedDialog() 和 SqliteConfigDialogs.showSqliteConfigSavedDialogWithLoadOption() 调用

- S6.3：简化主文件 settings_screen.dart
  - 替换 SQLite 激活成功对话框为 SqliteConfigDialogs.showSqliteActivatedDialog() 调用
  - 替换 SQLite 配置已保存对话框为 SqliteConfigDialogs.showSqliteConfigSavedDialog() 调用
  - 替换 SQLite 配置已保存对话框（询问是否立即加载）为 SqliteConfigDialogs.showSqliteConfigSavedDialogWithLoadOption() 调用

- S6.4：更新引用并验证
  - 添加 sqlite_config_dialogs.dart 的 import

**效果：**

- settings_screen.dart 从 1458 行减少到 963 行（减少 495 行，减少 33.9%）
- 从原始 3894 行减少到 963 行（减少 2931 行，减少 75.3%）
- SQLite 配置对话框已迁移到 sqlite_config_dialogs.dart
- 符合拆分原则：同模块 + 同层级 + 同职责簇 + 同验证路径

**拆分总结：**

- S1：UI 组件拆分（database_source_section.dart, backup_restore_section.dart, sync_config_section.dart, system_settings_section.dart）
- S2：Service 拆分（database_switch_service.dart, backup_restore_service.dart, mysql_config_service.dart, permission_service.dart）
- S3：对话框拆分（settings_dialogs.dart - 数据库切换、确认选择、MySQL 配置保存）
- S4：工具类拆分（settings_header.dart, snackbar_util.dart）
- S5：对话框进一步拆分（settings_dialogs.dart - 备份、恢复、导出）
- S6：SQLite 配置对话框拆分（sqlite_config_dialogs.dart - SQLite 激活成功、SQLite 配置已保存）

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）
- 设置模块拆分已完成，达到合理边界

### 2026-05-31：阶段 3 设置模块拆分（S5 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对设置页面进行对话框进一步拆分。

**拆分内容：**

- S5.1：提取备份对话框到 settings_dialogs.dart
  - 新方法：showBackupDialog()
  - 职责：显示备份对话框，包含文件夹选择、文件名输入、备份执行逻辑
  - 通过回调传递依赖（setState、showSnackBar、mounted、dbSettingsManager）
  - 替换主文件中的 _showBackupDialog() 为 SettingsDialogs.showBackupDialog() 调用

- S5.2：提取恢复对话框到 settings_dialogs.dart
  - 新方法：showRestoreDialog()
  - 职责：显示恢复对话框，包含文件选择、确认对话框、恢复执行逻辑
  - 通过回调传递依赖（setState、showSnackBar、mounted、dbProvider、dbSettingsManager、requestStoragePermission）
  - 替换主文件中的 _restoreDatabaseFromBackup() 为 SettingsDialogs.showRestoreDialog() 调用

- S5.3：提取导出对话框到 settings_dialogs.dart
  - 新方法：showExportDialog()
  - 职责：显示导出对话框，包含文件夹选择、文件名输入、导出执行逻辑
  - 通过回调传递依赖（setState、showSnackBar、mounted、dbSettingsManager）
  - 替换主文件中的 _showExcelExportDialog() 为 SettingsDialogs.showExportDialog() 调用

- S5.4：简化主文件 settings_screen.dart
  - 替换 _showBackupDialog() 为 SettingsDialogs.showBackupDialog() 调用
  - 替换 _restoreDatabaseFromBackup() 为 SettingsDialogs.showRestoreDialog() 调用
  - 替换 _showExcelExportDialog() 为 SettingsDialogs.showExportDialog() 调用

- S5.5：更新引用并验证
  - 添加 PatientProvider 的 import 到 settings_dialogs.dart
  - 无需更新主文件的 import

**效果：**

- settings_screen.dart 从 2037 行减少到 1467 行（减少 570 行，减少 28%）
- 从原始 3894 行减少到 1467 行（减少 2427 行，减少 62.3%）
- 备份、恢复、导出对话框已迁移到 settings_dialogs.dart
- 符合拆分原则：同模块 + 同层级 + 同职责簇 + 同验证路径

**拆分总结：**

- S1：UI 组件拆分（database_source_section.dart, backup_restore_section.dart, sync_config_section.dart, system_settings_section.dart）
- S2：Service 拆分（database_switch_service.dart, backup_restore_service.dart, mysql_config_service.dart, permission_service.dart）
- S3：对话框拆分（settings_dialogs.dart - 数据库切换、确认选择、MySQL 配置保存）
- S4：工具类拆分（settings_header.dart, snackbar_util.dart）
- S5：对话框进一步拆分（settings_dialogs.dart - 备份、恢复、导出）

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）
- 设置模块拆分已完成，达到合理边界

### 2026-05-31：阶段 3 设置模块拆分（S4 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对设置页面进行工具类拆分。

**拆分内容：**

- S4.1：提取 _buildSettingsHeader() 到独立组件
  - 新文件：lib/features/settings/widgets/settings_header.dart
  - 新组件：SettingsHeader
  - 职责：构建设置页面头部（标题、退出登录按钮、帮助按钮、TabBar）
  - 替换主文件中的 _buildSettingsHeader() 为 SettingsHeader 组件调用

- S4.2：提取 _showSnackBar() 到工具类
  - 新文件：lib/utils/snackbar_util.dart
  - 新类：SnackBarUtil
  - 职责：提供统一的 SnackBar 显示方法
  - 替换主文件中的 _showSnackBar() 为 SnackBarUtil.show() 调用

- S4.3：提取 _getDisplayDbPath() 到服务类
  - 该方法依赖于多个 Screen 状态变量（_selectedDbType、_dbConfig、dbProvider、_dbPath）
  - 提取到服务类会增加复杂度，决定保留在 Screen 中

- S4.4：简化主文件 settings_screen.dart
  - 替换 _buildSettingsHeader() 为 SettingsHeader 组件调用
  - 替换 _showSnackBar() 为 SnackBarUtil.show() 调用
  - 保留 _getDisplayDbPath() 在 Screen 中

- S4.5：更新引用并验证
  - 添加 SettingsHeader 组件的 import
  - 添加 SnackBarUtil 的 import

**效果：**

- settings_screen.dart 从 2118 行减少到 2037 行（减少 81 行，减少 3.8%）
- 从原始 3894 行减少到 2037 行（减少 1857 行，减少 47.7%）
- 设置页面的头部组件已迁移到 features/settings/widgets/settings_header.dart
- SnackBar 工具已迁移到 utils/snackbar_util.dart
- 符合拆分原则：同模块 + 同层级 + 同职责簇 + 同验证路径

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）

### 2026-05-31：阶段 3 设置模块拆分（S3 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对设置页面进行对话框拆分。

**拆分内容：**

- S3.1：提取数据库切换确认对话框到 settings_dialogs.dart
  - 新方法：showDatabaseSwitchConfirmDialog()
  - 职责：显示数据库类型切换确认对话框

- S3.2：提取确认选择数据库对话框到 settings_dialogs.dart
  - 新方法：showConfirmDatabaseDialog()
  - 职责：显示确认选择数据库文件对话框

- S3.3：提取备份对话框到 settings_dialogs.dart
  - 备份对话框包含大量 UI 代码，与业务逻辑紧密耦合，保留在主文件中

- S3.4：提取恢复对话框到 settings_dialogs.dart
  - 恢复对话框包含大量 UI 代码，与业务逻辑紧密耦合，保留在主文件中

- S3.5：提取导出对话框到 settings_dialogs.dart
  - 导出对话框包含大量 UI 代码，与业务逻辑紧密耦合，保留在主文件中

- S3.6：提取 MySQL 配置对话框到 settings_dialogs.dart
  - 已有方法：showMySqlConfigSavedDialog()
  - 替换主文件中的对话框调用为 SettingsDialogs.showMySqlConfigSavedDialog()

- S3.7：简化主文件 settings_screen.dart
  - 替换 _switchDatabaseType 中的对话框调用
  - 替换 _selectCustomDbPathAlternative 中的对话框调用
  - 替换 _saveMySQLConfig 中的对话框调用
  - 保留与业务逻辑紧密耦合的对话框（备份、恢复、导出）

**效果：**

- settings_screen.dart 从 2449 行减少到 2118 行（减少 331 行，减少 13.5%）
- 从原始 3894 行减少到 2118 行（减少 1776 行，减少 45.6%）
- 设置模块的对话框已部分迁移到 features/settings/widgets/settings_dialogs.dart
- 与业务逻辑紧密耦合的对话框保留在主文件中，避免过度拆分
- 符合拆分原则：同模块 + 同层级 + 同职责簇 + 同验证路径

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）

### 2026-05-31：阶段 3 设置模块拆分（S2 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对设置页面进行 Service 层拆分。

**拆分内容：**

- S2.1：提取数据库切换业务逻辑为 database_switch_service.dart
  - 新文件：lib/features/settings/services/database_switch_service.dart
  - 职责：数据库类型切换、路径选择、配置保存
  - 包含：switchDatabaseType()、selectCustomDbPath()、selectCustomDbPathAlternative()、saveDatabaseConfig()、isUsingCachePath()

- S2.2：提取备份恢复业务逻辑为 backup_restore_service.dart
  - 新文件：lib/features/settings/services/backup_restore_service.dart
  - 职责：数据库备份、恢复、Excel 导出
  - 包含：backupDatabase()、restoreDatabaseFromBackup()、exportPatientsToExcel()、selectBackupFile()、selectOutputDirectory()、generateBackupFilename()、generateExcelFilename()

- S2.3：提取 MySQL 配置管理为 mysql_config_service.dart
  - 新文件：lib/features/settings/services/mysql_config_service.dart
  - 职责：MySQL 连接测试、配置保存、网络测试
  - 包含：testNetworkConnection()、testMySqlConnection()、getEffectiveHost()、isHostConverted()

- S2.4：提取权限管理为 permission_service.dart
  - 新文件：lib/features/settings/services/permission_service.dart
  - 职责：存储权限请求
  - 包含：requestStoragePermission()、showPermissionSettingsDialog()

- S2.5：简化主文件 settings_screen.dart
  - 添加服务文件的 import
  - 替换 _requestStoragePermission() 为 PermissionService.requestStoragePermission()
  - 替换 _testNetworkConnection() 为 MysqlConfigService.testNetworkConnection()
  - 替换 _testMySqlConnection() 为 MysqlConfigService.testMySqlConnection()
  - 替换 _selectCustomDbPath() 为 DatabaseSwitchService.selectCustomDbPath()
  - 替换 _selectCustomDbPathAlternative() 为 DatabaseSwitchService.selectCustomDbPathAlternative()
  - 替换 _selectOutputDirectory() 为 BackupRestoreService.selectOutputDirectory()
  - 替换备份、恢复、导出相关的逻辑为 BackupRestoreService 的调用
  - 保留状态管理、UI 对话框、核心流程编排

**效果：**

- settings_screen.dart 从 2684 行减少到 2449 行（减少 235 行，减少 8.8%）
- 从原始 3894 行减少到 2449 行（减少 1445 行，减少 37.1%）
- 设置模块的业务逻辑已迁移到 features/settings/services/
- 符合分层架构原则（UI → Service → Data）
- 职责明确：Screen 负责流程编排和 UI，Service 负责业务逻辑
- 便于测试和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）

### 2026-05-31：阶段 3 设置模块拆分（S1 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对设置页面进行拆分。

**拆分内容：**

- S1.1：提取数据源设置区域为独立 Widget
  - 新文件：lib/features/settings/widgets/database_source_section.dart
  - 职责：数据库类型选择、MySQL配置、SQLite路径选择、连接测试
  - 包含：_buildDatabaseSourceTab()、_buildDatabaseTypeOption()、_buildMySQLEditForm()、_buildMySQLConfigDetails()、_buildConfigItem()

- S1.2：提取备份恢复区域为独立 Widget
  - 新文件：lib/features/settings/widgets/backup_restore_section.dart
  - 职责：数据库备份、恢复、Excel导出
  - 包含：_buildBackupRestoreTab()、_showBackupDialog()、_restoreDatabaseFromBackup()、_showExcelExportDialog()、_selectOutputDirectory()

- S1.3：提取同步配置区域为独立 Widget
  - 新文件：lib/features/settings/widgets/sync_config_section.dart
  - 职责：同步开关、同步间隔设置
  - 包含：_buildSyncConfigTab()、_formatLastSyncTime()

- S1.4：提取系统设置区域为独立 Widget
  - 新文件：lib/features/settings/widgets/system_settings_section.dart
  - 职责：通知设置、账户管理、退出登录
  - 包含：_buildSystemSettingsTab()、_showLogoutDialog()、_performLogout()

- S1.5：提取通用对话框
  - 新文件：lib/features/settings/widgets/settings_dialogs.dart
  - 职责：数据库切换确认对话框、成功提示对话框
  - 包含：_showSuccessDialog()、SQLite激活成功对话框、SQLite配置保存成功对话框、MySQL配置保存成功对话框

- S1.6：简化主文件 settings_screen.dart
  - 更新 import 语句，添加新组件的引用
  - 替换 build 方法中的 Tab 内容，使用新组件
  - 删除所有已提取的方法实现（_buildDatabaseSourceTab、_buildBackupRestoreTab、_buildSyncConfigTab、_buildSystemSettingsTab、_buildDatabaseTypeOption、_buildMySQLEditForm、_buildMySQLConfigDetails、_buildConfigItem、_formatLastSyncTime、_showSuccessDialog）
  - 保留状态管理、权限请求、网络测试、数据库操作等核心业务逻辑

**效果：**

- settings_screen.dart 从 3894 行减少到 2503 行（减少 35.7%）
- 设置模块的可复用 UI 组件已迁移到 features/settings/widgets/
- 设置模块的通用对话框已迁移到 features/settings/widgets/
- 符合模块化架构，设置模块的组件集中在 features/settings/ 下
- 便于后续维护和复用
- 职责明确：Screen 负责业务逻辑和流程编排，Widget 负责显示，Dialog 负责对话框

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（财务模块 F2）

### 2026-05-31：阶段 6 采购模块拆分（O2.2、O2.3 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对采购统计对话框进行拆分。

**拆分内容：**

- O2.2.1：提取时间范围管理服务（purchase_date_range_service.dart）
  - 新文件：lib/features/purchases/services/purchase_date_range_service.dart
  - 职责：时间范围管理服务
  - 包含：预设时间范围配置、默认时间范围获取、最早日期获取、预设应用、预设激活检查、日期范围格式化、日期范围判断

- O2.2.2：提取统计计算服务（purchase_statistics_calculator.dart）
  - 新文件：lib/features/purchases/services/purchase_statistics_calculator.dart
  - 职责：采购统计计算服务
  - 包含：calculateMonthlyData() 方法（计算月度数据）、calculateTopMaterialsByAmount() 方法（按金额计算材料排行）、calculateTopMaterialsByQuantity() 方法（按数量计算材料排行）、calculateTopSuppliers() 方法（计算供应商排行）、getRankColor() 方法（获取排名颜色）

- O2.2.3：提取数据过滤服务（purchase_data_filter.dart）
  - 新文件：lib/features/purchases/services/purchase_data_filter.dart
  - 职责：采购数据过滤服务
  - 包含：getFilteredRecords() 方法（获取过滤后的记录）、getFilteredItems() 方法（获取过滤后的采购项目）

- O2.3.1：提取统计卡片组件（purchase_stat_card.dart）
  - 新文件：lib/features/purchases/widgets/purchase_stat_card.dart
  - 职责：显示采购统计卡片（标题、数值、图标）

- O2.3.2：提取时间范围选择器组件（purchase_date_range_selector.dart）
  - 新文件：lib/features/purchases/widgets/purchase_date_range_selector.dart
  - 职责：显示时间范围选择器，包括当前时间范围显示和预设时间范围按钮

- O2.3.3：提取概览 Tab 页面组件（purchase_overview_tab.dart）
  - 新文件：lib/features/purchases/widgets/purchase_overview_tab.dart
  - 职责：显示概览 Tab 页面，包括统计卡片网格和采购分布图表

- O2.3.4：提取趋势 Tab 页面组件（purchase_trend_tab.dart）
  - 新文件：lib/features/purchases/widgets/purchase_trend_tab.dart
  - 职责：显示趋势 Tab 页面，包括月度趋势图表和月度统计表格

- O2.3.5：提取排行 Tab 页面组件（purchase_ranking_tab.dart）
  - 新文件：lib/features/purchases/widgets/purchase_ranking_tab.dart
  - 职责：显示排行 Tab 页面，包括材料采购排行和供应商排行

- O2.3.6：迁移并简化 purchase_statistics_dialog.dart
  - 新文件：lib/features/purchases/widgets/purchase_statistics_dialog.dart
  - 使用新服务替换原有逻辑（PurchaseDateRangeService、PurchaseDataFilter）
  - 使用新组件替换原有 UI 构建方法（PurchaseDateRangeSelector、PurchaseOverviewTab、PurchaseTrendTab、PurchaseRankingTab）
  - 删除所有已提取的方法实现（_setDefaultDateRange、_getEarliestPurchaseDate、_applyPreset、_isPresetActive、_isWithinRange、_getFilteredRecords、_getFilteredItems、_buildDateRangeSelector、_showCustomDatePicker、_buildOverviewTab、_buildStatCard、_buildPurchaseDistributionChart、_buildTrendTab、_calculateMonthlyData、_buildMonthlyTrendChart、_buildMonthlyStatsTable、_buildRankingTab、_calculateTopMaterialsByAmount、_calculateTopMaterialsByQuantity、_calculateTopSuppliers、_buildTopMaterialsCard、_buildTopSuppliersCard、_getRankColor）
  - 保留状态管理、Tab 切换、组件组合等核心流程编排

- O2.3.7：更新引用
  - lib/features/purchases/screens/purchase_records_screen.dart：更新 import 路径，从旧的 widgets 目录改为新的 features/purchases/widgets 目录

- O2.3.8：删除旧文件
  - 删除：lib/widgets/purchase_statistics_dialog.dart（1186行）

**效果：**

- purchase_statistics_dialog.dart 从 1186 行减少到 175 行（减少 85%）
- 采购模块的可复用 UI 组件已迁移到 features/purchases/widgets/
- 采购模块的业务逻辑已迁移到 features/purchases/services/
- 符合模块化架构，采购模块的组件集中在 features/purchases/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责，每个服务只负责一个明确的业务逻辑

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（全局组件）

### 2026-05-31：阶段 6 采购模块拆分（O2.4 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对采购记录列表页面进行拆分。

**拆分内容：**

- O2.4.1：提取统计逻辑服务（purchase_statistics_service.dart）
  - 新文件：lib/features/purchases/services/purchase_statistics_service.dart
  - 职责：采购统计计算服务
  - 包含：calculateStatistics() 方法（计算总记录数、总金额、总采购量、材料种类）、calculateBasicStatistics() 方法（降级方案）

- O2.4.2：提取统计卡片组件（purchase_statistics_card.dart）
  - 新文件：lib/features/purchases/widgets/purchase_statistics_card.dart
  - 职责：显示采购记录的统计信息卡片

- O2.4.3：提取搜索栏组件（purchase_search_bar.dart）
  - 新文件：lib/features/purchases/widgets/purchase_search_bar.dart
  - 职责：显示采购记录的搜索栏，包括搜索框和搜索按钮

- O2.4.4：提取采购记录卡片组件（purchase_record_card.dart）
  - 新文件：lib/features/purchases/widgets/purchase_record_card.dart
  - 职责：显示单个采购记录的详细信息卡片

- O2.4.5：提取空状态组件（purchase_records_empty_state.dart）
  - 新文件：lib/features/purchases/widgets/purchase_records_empty_state.dart
  - 职责：显示采购记录列表为空时的提示

- O2.4.6：迁移并更新 purchase_records_screen.dart
  - 新文件：lib/features/purchases/screens/purchase_records_screen.dart
  - 使用新组件替换原有UI构建方法
  - 使用 PurchaseStatisticsService 替代 _updateStatistics() 逻辑
  - 删除所有已提取的方法实现（_buildStatisticsCard、_buildStatItem、_buildSearchBar、_buildPurchaseRecordsList、_buildPurchaseRecordCard）
  - 保留状态管理、数据加载、用户交互等核心流程编排

- O2.4.7：更新引用
  - lib/screens/home_screen.dart：更新 import 路径，从旧的 screens 目录改为新的 features/purchases/screens 目录

**效果：**

- purchase_records_screen.dart 从 852 行减少到 425 行（减少 50%）
- 采购模块的可复用 UI 组件已迁移到 features/purchases/widgets/
- 采购模块的统计逻辑已迁移到 features/purchases/services/
- 符合模块化架构，采购模块的组件集中在 features/purchases/ 下
- 便于后续维护和复用
- 职责明确：Screen 负责流程编排，Widget 负责显示，Service 负责计算

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（全局组件）

**补充记录：**

- 已删除旧文件：lib/screens/purchase_records_screen.dart（852行）
- 所有引用已更新到新位置：lib/features/purchases/screens/purchase_records_screen.dart（425行）

### 2026-05-31：阶段 6 采购模块拆分（O2.5 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对采购详情页面进行拆分。

**拆分内容：**

- O2.5.1：提取导出功能服务（purchase_export_service.dart）
  - 新文件：lib/features/purchases/services/purchase_export_service.dart
  - 职责：采购记录导出为图片的完整逻辑
  - 包含：generatePurchaseRecordImage、saveImageToDownloads 方法

- O2.5.2：提取导出选项对话框（purchase_export_options_dialog.dart）
  - 新文件：lib/features/purchases/widgets/purchase_export_options_dialog.dart
  - 职责：导出选项选择对话框

- O2.5.3：提取 UI 组件到 features/purchases/widgets/（8个组件）
  - purchase_basic_info_card.dart - 基本信息卡片
  - purchase_info_row.dart - 信息行组件
  - purchase_items_card.dart - 采购项目明细卡片
  - purchase_item_row.dart - 单个采购项目行
  - purchase_empty_state.dart - 空状态组件
  - purchase_error_state.dart - 错误状态组件
  - purchase_amount_card.dart - 金额统计卡片
  - purchase_amount_item.dart - 单个金额统计项

- O2.5.4：更新 purchase_detail_screen.dart 使用新组件和服务
  - 简化 import，只保留必要的依赖
  - 使用 PurchaseExportService 替代原有的导出逻辑
  - 使用新组件替换原有的 build 方法
  - 删除所有已提取的方法实现（_buildBasicInfoCard、_buildItemsCard、_buildPurchaseItemCard、_buildAmountCard、_buildAmountItem、_buildInfoRow、_generatePurchaseRecordImage、_saveImageToDownloads、_openFileLocation、_ExportOptionsDialog）
  - 保留状态管理、数据加载、业务流程编排等核心功能

**效果：**

- purchase_detail_screen.dart 从 1148 行减少到 313 行（减少 73%）
- 采购模块的可复用 UI 组件已迁移到 features/purchases/widgets/
- 采购模块的导出服务已迁移到 features/purchases/services/
- 符合模块化架构，采购模块的组件集中在 features/purchases/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责，导出服务独立

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（全局组件）

### 2026-05-31：阶段 6 用户模块拆分（O1.2 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对登录页面进行拆分。

**拆分内容：**

- O1.2.1：提取 UI 组件到 features/users/widgets/（8个组件）
  - login_header.dart - 登录头部组件（包含 _DecorIcon 内部组件）
  - login_form.dart - 登录表单容器组件
  - username_field.dart - 用户名字段组件
  - password_field.dart - 密码字段组件
  - remember_password_checkbox.dart - 记住密码复选框组件
  - login_button.dart - 登录按钮组件
  - login_bottom_decorations.dart - 底部装饰组件
  - database_error_dialog.dart - 数据库错误对话框组件

- O1.2.2：提取业务逻辑到 features/users/services/（4个服务）
  - login_credentials_service.dart - 登录凭证管理服务（包含 LoginCredentials 数据类）
  - login_initialization_service.dart - 登录初始化服务
  - login_handler.dart - 登录处理服务（包含 LoginDatabaseException 异常类）
  - database_connection_service.dart - 数据库连接服务

- O1.2.3：更新 login_screen.dart 使用新组件和服务
  - 简化 import，只保留必要的依赖
  - 使用 LoginCredentialsService 替代原有的凭证加载/保存逻辑
  - 使用 LoginInitializationService 替代原有的初始化逻辑
  - 使用 LoginHandler 替代原有的登录处理逻辑
  - 使用 DatabaseConnectionService 替代原有的数据库连接逻辑
  - 使用新组件替换原有的 build 方法
  - 删除所有已提取的方法实现（_buildAdaptiveHeader, _buildDecorIcon, _buildAdaptiveLoginForm, _buildUsernameField, _buildPasswordField, _buildRememberPasswordCheckbox, _buildLoginButton, _buildAdaptiveBottomDecorations, _showDatabaseErrorDialog, _retryMySQLConnection, _switchToSQLite）
  - 删除已提取的类（StatusInfo）
  - 删除已提取的常量（positionMap）
  - 保留状态管理、控制器、状态变量等核心功能

**效果：**

- login_screen.dart 从 1169 行减少到 213 行（减少 82%）
- 用户模块的可复用 UI 组件已迁移到 features/users/widgets/
- 用户模块的业务逻辑已迁移到 features/users/services/
- 符合模块化架构，用户模块的组件集中在 features/users/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责，每个服务只负责一个明确的业务逻辑

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（采购、全局组件）

### 2026-05-31：阶段 6 仪表盘模块拆分（O3.1 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对仪表盘模块进行拆分。

**拆分内容：**

- O3.1.1：提取 UI 组件到 features/dashboard/widgets/（9个组件）
  - dashboard_header.dart - 仪表盘头部组件
  - welcome_section.dart - 欢迎区域组件
  - statistics_cards.dart - 统计卡片组组件
  - stat_card.dart - 单个统计卡片组件
  - today_appointments_section.dart - 今日预约区域组件
  - appointment_card.dart - 预约卡片组件
  - status_chip.dart - 状态标签组件
  - info_item.dart - 信息项组件
  - default_avatar_icon.dart - 默认头像图标组件

- O3.1.2：提取业务逻辑到 features/dashboard/services/（4个服务）
  - dashboard_data_loader.dart - 数据加载服务（包含 DashboardData 数据类）
  - appointment_status_helper.dart - 预约状态辅助服务（包含 StatusInfo 类）
  - phone_formatter.dart - 电话号码格式化服务
  - treatment_type_formatter.dart - 治疗类型格式化服务

- O3.1.3：更新 dashboard_screen.dart 使用新组件和服务
  - 简化 import，只保留必要的依赖
  - 使用 DashboardDataLoader.loadData() 替代原有的数据加载逻辑
  - 使用新组件替换原有的 build 方法
  - 删除所有已提取的方法实现（_buildDashboardHeader, _buildWelcomeSection, _buildStatisticsCards, _buildStatCard, _buildTodayAppointmentsSection, _buildDefaultAvatarIcon, _buildInfoItem, _buildStatusChip, _getStatusInfo, _getColorForStatus, _getDisplayPhone, _formatTreatmentType, _initializeAllProviders）
  - 删除已提取的类（StatusInfo）
  - 删除已提取的常量（positionMap）
  - 保留状态管理、动画控制、数据加载重试逻辑等核心功能

**效果：**

- dashboard_screen.dart 从 1294 行减少到 318 行（减少 75%）
- 仪表盘模块的可复用 UI 组件已迁移到 features/dashboard/widgets/
- 仪表盘模块的业务逻辑已迁移到 features/dashboard/services/
- 符合模块化架构，仪表盘模块的组件集中在 features/dashboard/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责，每个服务只负责一个明确的业务逻辑

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分（用户、采购、全局组件）

### 2026-05-31：阶段 4 财务模块拆分（F2.4 财务详情页面拆分已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对财务详情页面进行拆分。

**拆分内容：**

- F2.4.1：提取财务项目编辑对话框（financial_item_edit_dialog.dart）
  - 新文件：lib/features/financial/widgets/financial_item_edit_dialog.dart
  - 职责：编辑财务项目的对话框

- F2.4.2：提取财务项目添加对话框（financial_item_add_dialog.dart）
  - 新文件：lib/features/financial/widgets/financial_item_add_dialog.dart
  - 职责：添加财务项目的对话框

- F2.4.3：提取患者信息卡片（patient_info_card.dart）
  - 新文件：lib/features/financial/widgets/patient_info_card.dart
  - 职责：显示患者基本信息卡片

- F2.4.4：提取财务统计卡片（financial_summary_card.dart）
  - 新文件：lib/features/financial/widgets/financial_summary_card.dart
  - 职责：显示财务统计信息卡片

- F2.4.5：提取收费记录历史卡片（payment_history_card.dart）
  - 新文件：lib/features/financial/widgets/payment_history_card.dart
  - 职责：显示收费记录历史卡片

- F2.4.6：提取收费项目卡片（financial_item_card.dart）
  - 新文件：lib/features/financial/widgets/financial_item_card.dart
  - 职责：显示单个收费项目的卡片

- F2.4.7：提取金额信息项组件（amount_info_item.dart）
  - 已存在：lib/features/financial/widgets/amount_info_item.dart
  - 职责：显示金额信息项

- F2.4.8：提取统计项组件（stat_item.dart）
  - 新文件：lib/features/financial/widgets/stat_item.dart
  - 职责：显示统计信息项

**更新引用：**

- lib/screens/financial_detail_screen.dart：更新 import 路径，使用新组件替换原有方法
- 删除不再需要的方法（_buildPatientInfoCard, _buildFinancialSummaryCard, _buildPaymentHistoryCard, _buildItemCard, _buildAmountInfo, _buildStatItem）
- 删除不再需要的类（_FinancialItemEditDialog, _FinancialItemAddDialog）
- 保留仍在使用的方法（数据加载、编辑、删除等业务逻辑）

**效果：**

- financial_detail_screen.dart 从 1271 行减少到 365 行（减少 71%）
- 财务模块的可复用 UI 组件已迁移到 features/financial/widgets/
- 符合模块化架构，财务模块的组件集中在 features/financial/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他财务模块 UI 的拆分

### 2026-05-31：阶段 4 财务模块拆分（F2.3 财务管理页面拆分已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对财务管理页面进行拆分。

**拆分内容：**

- F2.3.1：提取计算逻辑服务类（financial_calculator.dart）
  - 新文件：lib/features/financial/services/financial_calculator.dart
  - 职责：提供财务金额计算、患者统计、欠费计算等纯计算逻辑

- F2.3.2：提取搜索栏组件（financial_search_bar.dart）
  - 新文件：lib/features/financial/widgets/financial_search_bar.dart
  - 职责：显示财务记录的搜索栏，包括搜索框、排序按钮、时间筛选

- F2.3.3：提取统计信息卡片组件（financial_statistics_card.dart）
  - 新文件：lib/features/financial/widgets/financial_statistics_card.dart
  - 职责：显示财务统计信息卡片（患者数、记录数、已收费、总欠费、加工费）

- F2.3.4：提取财务记录卡片组件（financial_record_card.dart）
  - 新文件：lib/features/financial/widgets/financial_record_card.dart
  - 职责：显示单个财务记录的卡片

- F2.3.5：提取排序对话框组件（financial_sort_dialog.dart）
  - 新文件：lib/features/financial/widgets/financial_sort_dialog.dart
  - 职责：显示财务记录排序选项对话框

- F2.3.6：提取渐进式统计对话框（progressive_statistics_dialog.dart）
  - 新文件：lib/features/financial/widgets/progressive_statistics_dialog.dart
  - 职责：渐进式加载统计图表对话框

**更新引用：**

- lib/screens/financial_management_screen.dart：更新 import 路径，使用新组件替换原有方法
- 删除不再需要的方法（_buildSearchBar, _buildStatisticsCard, _buildStatItem, _buildFinancialRecordCard, _buildSortOption, _changeSort, _getLatestFinancialRecord, _calculatePatientLatestReceivableAmount, _calculatePatientLatestCollectedAmount, _calculateTotalAmount, _calculateSettledCount, _calculateUniquePatientCount, _calculateTotalRecords, _getFilteredItems, _calculateTotalReceivable, _calculateTotalCollected, _calculateTotalOutstanding, _calculateTotalProcessingFee, _isWithinRange, _buildPresetButton, _isPresetSelected, _isSameDay, _applyPreset）
- 删除不再需要的类（_ProgressiveStatisticsDialog）
- 保留仍在使用的方法（数据加载、分页、搜索、排序、删除等业务逻辑）

**效果：**

- financial_management_screen.dart 从 1771 行减少到 894 行（减少 50%）
- 财务模块的可复用 UI 组件已迁移到 features/financial/widgets/
- 财务模块的计算逻辑已迁移到 features/financial/services/
- 符合模块化架构，财务模块的组件集中在 features/financial/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责，计算逻辑独立

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他财务模块 UI 的拆分

### 2026-05-31：阶段 4 财务模块拆分（F2.2 财务统计对话框拆分已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对财务统计对话框进行拆分。

**拆分内容：**

- F2.2.1：提取紧凑型统计卡片组件（compact_stat_card.dart）
  - 新文件：lib/features/financial/widgets/compact_stat_card.dart
  - 职责：显示紧凑型统计卡片（标题、数值、图标）

- F2.2.2：提取统计卡片组件（stat_card.dart）
  - 新文件：lib/features/financial/widgets/stat_card.dart
  - 职责：显示统计卡片（标题、数值、图标）

- F2.2.3：提取收费状态图表组件（payment_status_chart.dart）
  - 新文件：lib/features/financial/widgets/payment_status_chart.dart
  - 职责：显示收费状态分布图表

- F2.2.4：提取月度趋势图表组件（monthly_trend_chart.dart）
  - 新文件：lib/features/financial/widgets/monthly_trend_chart.dart
  - 职责：显示月度收费趋势图表

- F2.2.5：提取月度加工费图表组件（monthly_processing_chart.dart）
  - 新文件：lib/features/financial/widgets/monthly_processing_chart.dart
  - 职责：显示月度加工费趋势图表

**更新引用：**

- lib/widgets/financial_statistics_dialog.dart：更新 import 路径，使用新组件替换原有方法
- 删除不再需要的方法（_buildCompactStatCard, _buildStatCard, _buildPaymentStatusChart, _buildMonthlyTrendChart, _buildMonthlyProcessingChart）
- 保留仍在使用的方法（_calculateMonthlyData, _calculateMonthlyProcessingFee）

**效果：**

- financial_statistics_dialog.dart 从 1573 行减少到 952 行（减少 39%）
- 财务模块的可复用 UI 组件已迁移到 features/financial/widgets/
- 符合模块化架构，财务模块的组件集中在 features/financial/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他财务模块 UI 的拆分

### 2026-05-31：阶段 4 财务模块拆分（F2.1 财务记录对话框拆分已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对财务记录对话框进行拆分。

**拆分内容：**

- F2.1.1：提取患者搜索对话框（patient_search_dialog.dart）
  - 新文件：lib/features/financial/widgets/patient_search_dialog.dart
  - 职责：显示患者搜索对话框，支持按姓名、拼音搜索

- F2.1.2：提取财务项目行组件（financial_item_row.dart）
  - 新文件：lib/features/financial/widgets/financial_item_row.dart
  - 职责：显示财务项目列表中的单个项目

- F2.1.3：提取金额信息项组件（amount_info_item.dart）
  - 新文件：lib/features/financial/widgets/amount_info_item.dart
  - 职责：显示金额信息项（标题和值）

- F2.1.4：提取节标题组件（section_title.dart）
  - 新文件：lib/features/financial/widgets/section_title.dart
  - 职责：显示节标题（图标+标题）

**更新引用：**

- lib/widgets/financial_record_dialog.dart：更新 import 路径，使用新组件替换原有方法
- 删除不再需要的方法（_buildFinancialItemRow, _buildAmountInfoItem, _buildSectionTitle）
- 删除不再需要的类（PatientSearchDialog）

**效果：**

- financial_record_dialog.dart 从 1335 行减少到 809 行（减少 39%）
- 财务模块的可复用 UI 组件已迁移到 features/financial/widgets/
- 符合模块化架构，财务模块的组件集中在 features/financial/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他财务模块 UI 的拆分

### 2026-05-31：阶段 2 患者模块拆分（P2.4 患者列表页拆分已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对患者列表页进行拆分。

**拆分内容：**

- P2.4.1：提取患者列表卡片组件（patient_list_card.dart）
  - 新文件：lib/features/patients/widgets/patient_list_card.dart
  - 职责：显示患者列表中的单个患者卡片，包含基本信息、操作按钮等

- P2.4.2：提取搜索筛选栏组件（patient_search_filter_bar.dart）
  - 新文件：lib/features/patients/widgets/patient_search_filter_bar.dart
  - 职责：显示搜索框和时间筛选功能

- P2.4.3：提取患者统计栏组件（patient_stats_bar.dart）
  - 新文件：lib/features/patients/widgets/patient_stats_bar.dart
  - 职责：显示患者统计信息（总数、当前显示数、分页信息等）

- P2.4.4：提取排序选项组件（patient_sort_options.dart）
  - 新文件：lib/features/patients/widgets/patient_sort_options.dart
  - 职责：显示排序选项对话框

- P2.4.5：提取空状态组件（patient_empty_state.dart）
  - 新文件：lib/features/patients/widgets/patient_empty_state.dart
  - 职责：显示患者列表为空时的状态

**更新引用：**

- lib/screens/patients_screen.dart：更新 import 路径，使用新组件替换原有方法
- 删除不再需要的方法（_buildPatientCard, _buildSearchBar, _buildPatientStatsBar, _showSortOptions, _buildSortOption, _buildEmptyState, _buildTimeFilterSection, _buildFilterTypeButton, _buildDateField, _buildInfoItem）
- 删除不再需要的 import（dart:convert, dart:math as math）

**效果：**

- patients_screen.dart 从 1621 行减少到 789 行（减少 51%）
- 患者列表页的可复用 UI 组件已迁移到 features/patients/widgets/
- 符合模块化架构，患者模块的组件集中在 features/patients/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分

### 2026-05-31：阶段 2 患者模块拆分（P2.3 患者详情页拆分已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对患者详情页进行拆分。

**拆分内容：**

- P2.3.1：提取通用信息行组件（patient_info_row.dart）
  - 新文件：lib/features/patients/widgets/patient_info_row.dart
  - 职责：显示患者的基本信息行（图标+标签+值），支持电话号码拨号功能

- P2.3.2：提取患者基本信息显示卡片组件（patient_basic_info_card.dart）
  - 新文件：lib/features/patients/widgets/patient_basic_info_card.dart
  - 职责：显示患者的基本信息（姓名、年龄、性别、病历号、医生、地址、身份证号、初诊日期、总费用、治疗项目）

- P2.3.3：提取电话号码显示组件（patient_phone_display.dart）
  - 新文件：lib/features/patients/widgets/patient_phone_display.dart
  - 职责：显示患者电话号码列表，支持拨号功能

- P2.3.4：提取牙齿状况显示组件（patient_dental_condition_display.dart）
  - 新文件：lib/features/patients/widgets/patient_dental_condition_display.dart
  - 职责：显示患者牙齿状况的十字图表和备注

- P2.3.5：提取病历记录显示组件（patient_medical_records_section.dart）
  - 新文件：lib/features/patients/widgets/patient_medical_records_section.dart
  - 职责：显示患者的病历记录列表，支持加载、刷新、查看详情

**更新引用：**

- lib/screens/patient_detail_screen.dart：更新 import 路径，使用新组件替换原有方法
- 删除不再需要的状态变量（_cachedMedicalRecords, _medicalRecordsLoaded）
- 删除不再需要的 import（medical_record_provider, patient_medical_record, medical_record_detail_screen）

**效果：**

- patient_detail_screen.dart 从 1895 行减少到 663 行（减少 65%）
- 患者详情页的可复用 UI 组件已迁移到 features/patients/widgets/
- 符合模块化架构，患者模块的显示组件集中在 features/patients/ 下
- 便于后续维护和复用
- 职责明确：每个组件只负责一个明确的显示职责

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证拆分
- 继续其他模块的拆分

### 2026-05-31：阶段 5 预约模块拆分（AP1.1、AP1.2、AP1.3、AP1.4 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对预约模块进行拆分。

**拆分内容：**

- AP1.1：迁移 appointment_form_sheet.dart 到 features/appointments/widgets/（已完成）
  - 原位置：lib/widgets/appointment_form_sheet.dart（1984行）
  - 新位置：lib/features/appointments/widgets/appointment_form_sheet.dart
  - 职责：预约表单底部弹窗，包含患者选择、日期时间选择、治疗项目、牙齿情况、费用等信息录入

- AP1.2：拆分 appointment_form_sheet.dart 为多个小组件（已完成）
  - AP1.2.1：提取患者选择对话框为独立组件（patient_selection_dialog.dart）
  - AP1.2.2：提取时间选择对话框为独立组件（time_picker_dialog.dart）
  - AP1.2.3：提取牙齿情况组件为独立组件（teeth_condition_input.dart）
  - AP1.2.4：提取治疗项目组件为独立组件（treatment_items_input.dart）
  - AP1.2.5：提取日期时间卡片组件为独立组件（date_time_card.dart）

- AP1.3：拆分 appointments_screen.dart 为多个小组件（已完成）
  - AP1.3.1：提取搜索筛选栏组件（appointment_search_filter_bar.dart）
  - AP1.3.2：提取预约卡片组件（appointment_card.dart）
  - AP1.3.3：提取日历视图组件（appointment_calendar_view.dart）

- AP1.4：拆分 appointment_detail_screen.dart 为多个小组件（已完成）
  - AP1.4.1：提取预约信息卡片组件（appointment_info_card.dart）
  - AP1.4.2：提取患者信息卡片组件（patient_info_card.dart）
  - AP1.4.3：提取治疗类型信息显示组件（treatment_info_display.dart）
  - AP1.4.4：提取状态标签组件（appointment_status_chip.dart）
  - AP1.4.5：提取操作按钮组组件（appointment_action_buttons.dart）

**更新引用：**

- lib/screens/appointments_screen.dart：更新 import 路径，使用新组件替换原有方法
- lib/screens/appointment_detail_screen.dart：更新 import 路径，使用新组件替换原有方法

**效果：**

- appointment_form_sheet.dart 从 1984 行减少到约 990 行（减少 50%）
- appointments_screen.dart 从 1287 行减少到约 700 行（减少 45%）
- appointment_detail_screen.dart 从 1143 行减少到约 600 行（减少 47%）
- 预约相关的可复用 UI 组件已迁移到 features/appointments/widgets/
- 符合模块化架构，预约模块的组件集中在 features/appointments/ 下
- 便于后续维护和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证整体项目
- 继续其他模块的拆分

### 2026-05-31：阶段 6 预约 Provider 拆分（AP2.1、AP2.2、AP2.3 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对预约 Provider 进行拆分。

**拆分内容：**

- AP2.1：提取缓存管理逻辑到独立的 mixin（已完成）
  - 新文件：lib/features/appointments/providers/appointment_cache_mixin.dart
  - 职责：预约数据缓存管理，包括缓存有效性检查、更新和清除

- AP2.2：提取数据库连接管理逻辑到独立的 mixin（已完成）
  - 新文件：lib/features/appointments/providers/appointment_database_mixin.dart
  - 职责：数据库连接管理和数据源切换功能

- AP2.3：提取权限和过滤逻辑到独立的 mixin（已完成）
  - 新文件：lib/features/appointments/providers/appointment_permission_mixin.dart
  - 职责：权限检查和医生过滤功能

**更新引用：**

- lib/providers/appointments_provider.dart：使用三个 mixin 替代原有的内联逻辑

**效果：**

- appointments_provider.dart 从 526 行减少到约 370 行（减少 30%）
- 缓存、数据库连接、权限管理逻辑被提取到独立的 mixin 中
- 提高了代码的可复用性和可维护性
- 符合单一职责原则

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### 2026-05-31：阶段 5 预约模块拆分（AP1.1、AP1.2、AP1.3 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对预约模块进行拆分。

**拆分内容：**

- AP1.1：迁移 appointment_form_sheet.dart 到 features/appointments/widgets/（已完成）
  - 原位置：lib/widgets/appointment_form_sheet.dart（1984行）
  - 新位置：lib/features/appointments/widgets/appointment_form_sheet.dart
  - 职责：预约表单底部弹窗，包含患者选择、日期时间选择、治疗项目、牙齿情况、费用等信息录入

- AP1.2：拆分 appointment_form_sheet.dart 为多个小组件（已完成）
  - AP1.2.1：提取患者选择对话框为独立组件（patient_selection_dialog.dart）
  - AP1.2.2：提取时间选择对话框为独立组件（time_picker_dialog.dart）
  - AP1.2.3：提取牙齿情况组件为独立组件（teeth_condition_input.dart）
  - AP1.2.4：提取治疗项目组件为独立组件（treatment_items_input.dart）
  - AP1.2.5：提取日期时间卡片组件为独立组件（date_time_card.dart）

- AP1.3：拆分 appointments_screen.dart 为多个小组件（已完成）
  - AP1.3.1：提取搜索筛选栏组件（appointment_search_filter_bar.dart）
    - 职责：搜索输入、筛选按钮、清除搜索功能
  - AP1.3.2：提取预约卡片组件（appointment_card.dart）
    - 职责：预约列表项显示，包含患者头像、时间、状态、治疗项目、备注、编辑删除按钮
  - AP1.3.3：提取日历视图组件（appointment_calendar_view.dart）
    - 职责：日历显示、选中日期预约列表、空状态处理

**更新引用：**

- lib/screens/appointments_screen.dart：更新 import 路径，使用新组件替换原有方法
- lib/screens/appointment_detail_screen.dart：更新 import 路径

**效果：**

- appointment_form_sheet.dart 从 1984 行减少到约 990 行（减少 50%）
- appointments_screen.dart 从 1287 行减少到约 700 行（减少 45%）
- 预约相关的可复用 UI 组件已迁移到 features/appointments/widgets/
- 符合模块化架构，预约模块的组件集中在 features/appointments/ 下
- 便于后续维护和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证 AP1.1、AP1.2、AP1.3 拆分
- 继续执行 AP1.4：拆分 appointment_detail_screen.dart 为多个小组件

### 2026-05-31：阶段 5 预约模块拆分（AP1.1 和 AP1.2 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对预约模块进行拆分。

**拆分内容：**

- AP1.1：迁移 appointment_form_sheet.dart 到 features/appointments/widgets/（已完成）
  - 原位置：lib/widgets/appointment_form_sheet.dart（1984行）
  - 新位置：lib/features/appointments/widgets/appointment_form_sheet.dart
  - 职责：预约表单底部弹窗，包含患者选择、日期时间选择、治疗项目、牙齿情况、费用等信息录入

- AP1.2：拆分 appointment_form_sheet.dart 为多个小组件（已完成）
  - AP1.2.1：提取患者选择对话框为独立组件（patient_selection_dialog.dart）
    - 职责：患者搜索、选择、添加功能
    - 包含拼音搜索支持
  - AP1.2.2：提取时间选择对话框为独立组件（time_picker_dialog.dart）
    - 职责：24小时制时间选择，支持手动输入和网格选择
  - AP1.2.3：提取牙齿情况组件为独立组件（teeth_condition_input.dart）
    - 职责：牙位十字图输入，包含四个象限的牙位输入
  - AP1.2.4：提取治疗项目组件为独立组件（treatment_items_input.dart）
    - 职责：治疗项目输入和标签管理
  - AP1.2.5：提取日期时间卡片组件为独立组件（date_time_card.dart）
    - 职责：日期时间显示卡片

**更新引用：**

- lib/screens/appointments_screen.dart：更新 import 路径
- lib/screens/appointment_detail_screen.dart：更新 import 路径

**效果：**

- appointment_form_sheet.dart 从 1984 行减少到约 990 行（减少 50%）
- 预约相关的可复用 UI 组件已迁移到 features/appointments/widgets/
- 符合模块化架构，预约模块的组件集中在 features/appointments/ 下
- 便于后续维护和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证 AP1.1 和 AP1.2 拆分
- 继续执行 AP1.3：拆分 appointments_screen.dart 为多个小组件

### 2026-05-31：阶段 5 预约模块拆分（AP1.1 已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对预约模块进行拆分。

**拆分内容：**

- AP1.1：迁移 appointment_form_sheet.dart 到 features/appointments/widgets/（已完成）
  - 原位置：lib/widgets/appointment_form_sheet.dart（1983行）
  - 新位置：lib/features/appointments/widgets/appointment_form_sheet.dart
  - 职责：预约表单底部弹窗，包含患者选择、日期时间选择、治疗项目、牙齿情况、费用等信息录入

**更新引用：**

- lib/screens/appointments_screen.dart：更新 import 路径
- lib/screens/appointment_detail_screen.dart：更新 import 路径

**效果：**

- 预约相关的可复用 UI 组件已迁移到 features/appointments/widgets/
- 符合模块化架构，预约模块的组件集中在 features/appointments/ 下
- 便于后续维护和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证 AP1.1 拆分
- 继续执行 AP1.2：拆分 appointment_form_sheet.dart 为多个小组件

### 2026-05-30：阶段 4 财务模块拆分（进行中）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对财务模块进行拆分。

**拆分内容：**

- F1.1：提取财务初始化逻辑为 financial_initialization_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_initialization_service.dart`
  - 职责：数据源初始化、数据源类型管理、连接管理

- F1.2：提取财务缓存管理为 financial_cache_helper.dart（已完成）
  - 创建 `lib/features/financial/helpers/financial_cache_helper.dart`
  - 职责：缓存数据管理、缓存刷新、缓存有效性检查

- F1.3：简化 Provider 主文件（进行中）
  - financial_provider.dart 从 1942 行减少
  - Provider 只保留：状态管理、流程编排、Service 调用

**新增文件：**

- `lib/features/financial/services/financial_initialization_service.dart`
- `lib/features/financial/helpers/financial_cache_helper.dart`

**下一步建议：**

- 继续执行 F1.3：简化财务 Provider 主文件
- 执行 flutter analyze 验证 F1 拆分

### 2026-05-30：A1 清理备份文件（已完成）

清理备份文件，减少文件数量。

**执行内容：**

- 删除 providers\purchase_provider_bak.dart（1233行备份文件）

**效果：**

- 减少了不必要的备份文件
- 清理了代码库

### 2026-05-30：A0 建立 features/ 目录结构（已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，建立 features/ 目录结构。

**创建内容：**

- A0.1：创建 features/ 根目录
- A0.2：创建 9 个模块目录：
  - patients/（患者模块）
  - appointments/（预约模块）
  - financial/（财务模块）
  - medical_records/（病历模块）
  - materials/（材料模块）
  - purchases/（采购模块）
  - users/（用户模块）
  - settings/（设置模块）
  - dashboard/（仪表盘模块）
- A0.3：为每个模块创建 3 个子目录：
  - models/（模块专用 DTO / view model）
  - services/（业务流程、校验、同步、协调）
  - widgets/（独立 Widget）

**目录结构：**

```
lib/features/
├── patients/
│   ├── models/
│   ├── services/
│   └── widgets/
├── appointments/
│   ├── models/
│   ├── services/
│   └── widgets/
├── financial/
│   ├── models/
│   ├── services/
│   └── widgets/
├── medical_records/
│   ├── models/
│   ├── services/
│   └── widgets/
├── materials/
│   ├── models/
│   ├── services/
│   └── widgets/
├── purchases/
│   ├── models/
│   ├── services/
│   └── widgets/
├── users/
│   ├── models/
│   ├── services/
│   └── widgets/
├── settings/
│   ├── models/
│   ├── services/
│   └── widgets/
└── dashboard/
    ├── models/
    ├── services/
    └── widgets/
```

**效果：**

- 建立了清晰的模块化目录结构
- 为后续拆分提供了明确的文件落点
- 符合"结构清晰"的拆分目标

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### 2026-05-30：阶段 1 Data Source 层拆分（已完成）

**状态：已完成**

经检查，安卓端的 Data Source 层已经完成了 SQLite/MySQL 物理隔离：
- patient_data_source.dart：包含接口、SQLite实现、MySQL实现
- financial_data_source.dart：包含接口、SQLite实现、MySQL实现
- appointment_data_source.dart：包含接口、SQLite实现、MySQL实现
- 其他 data_source 文件同样已完成拆分

无需再进行拆分，直接跳过阶段 1。

**下一步建议：**

- 执行 flutter analyze 验证 F1 拆分
- 继续执行阶段 5：预约模块拆分

### 2026-05-30：阶段 4 财务模块拆分（已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对财务模块进行拆分。

**拆分内容：**

- F1.1：提取财务缓存管理为 financial_cache_helper.dart（已完成）
  - 创建 `lib/features/financial/helpers/financial_cache_helper.dart`
  - 职责：缓存数据管理、缓存刷新、缓存有效性检查、统计缓存管理
  - 方法：cachedRecords、cachedItemsMap、hasValidCache、updateCache、clearCache、cachedStats、ensureFullDataCached

- F1.2：提取财务权限过滤为 financial_permission_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_permission_service.dart`
  - 职责：权限过滤逻辑、Blob 转换
  - 方法：getDoctorFilter、shouldFilterByDoctor、getFilteredFinancialRecords、convertBlobToString

- F1.3：提取财务连接管理为 financial_connection_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_connection_service.dart`
  - 职责：连接状态管理、自动重连、错误处理
  - 方法：ensureConnection、autoReconnect、setError、currentMysqlConnection

- F1.4：简化 Provider 主文件（已完成）
  - financial_provider.dart 从 1942 行减少到 1629 行
  - Provider 只保留：状态管理、流程编排、Service 调用
  - 删除已提取的业务逻辑（缓存、权限过滤、连接管理、Blob 转换）

- F1.5：提取财务数据源管理为 financial_data_source_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_data_source_service.dart`
  - 职责：数据源初始化、数据源类型管理、连接管理、表创建
  - 方法：setSqliteDataSource、setMySqlDataSource、currentDataSource、ensureFinancialRecordsTableExists

- F1.6：提取财务数据清理为 financial_data_cleaner_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_data_cleaner_service.dart`
  - 职责：数据清理、无效记录检测、数据验证
  - 方法：checkAndCleanInvalidRecords、getInvalidRecordsInfo

- F1.7：提取财务统计为 financial_statistics_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_statistics_service.dart`
  - 职责：统计计算、患者消费统计、财务统计
  - 方法：getPatientTotalCost、getFinancialStatistics

- F1.8：进一步简化 Provider 主文件（已完成）
  - 删除已提取的字段和方法
  - Provider 只保留：状态管理、流程编排、Service 调用
  - financial_provider.dart 从 1629 行减少到 1382 行

- F1.9：提取财务记录 CRUD 为 financial_record_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_record_service.dart`
  - 职责：财务记录的增删改查操作
  - 方法：addFinancialRecord、updateFinancialRecord、deleteFinancialRecord、getFinancialRecordsByPatientId

- F1.10：提取财务项目 CRUD 为 financial_item_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_item_service.dart`
  - 职责：财务项目的增删改查操作
  - 方法：getFinancialItemsByRecordId、addFinancialItem、updateFinancialItem、deleteFinancialItem

- F1.11：提取查询操作为 financial_query_service.dart（已完成）
  - 创建 `lib/features/financial/services/financial_query_service.dart`
  - 职责：财务数据的查询操作（分页、搜索、复杂查询）
  - 方法：getFinancialRecordsCount、getPaginatedFinancialRecords、searchFinancialRecords、getPaginatedFinancialRecordsWithDateFilter、getFinancialRecordCount、getAllFinancialItemsWithDetailsFiltered

- F1.12：最终简化 Provider 主文件（已完成）
  - 删除已提取的 CRUD 和查询逻辑
  - Provider 只保留：状态管理、流程编排、Service 调用
  - financial_provider.dart 从 1382 行减少到 732 行

- F1.13：修复 Service 实例共享问题（已完成）
  - 修复 Service 实例独立创建导致数据源状态不同步的问题
  - 将 Service 实例改为使用 `late final`，在构造函数中初始化，确保所有 Service 共享同一个 `_dataSourceService`、`_permissionService`、`_connectionService` 实例
  - 在初始化和 `setDatabaseConnection` 中同步设置 `_dataSourceService.setDataSourceType()`
  - 修复文件：financial_provider.dart、financial_query_service.dart、financial_record_service.dart、financial_item_service.dart

**新增文件：**

- `lib/features/financial/helpers/financial_cache_helper.dart`
- `lib/features/financial/services/financial_permission_service.dart`
- `lib/features/financial/services/financial_connection_service.dart`
- `lib/features/financial/services/financial_data_source_service.dart`
- `lib/features/financial/services/financial_data_cleaner_service.dart`
- `lib/features/financial/services/financial_statistics_service.dart`
- `lib/features/financial/services/financial_record_service.dart`
- `lib/features/financial/services/financial_item_service.dart`
- `lib/features/financial/services/financial_query_service.dart`

**效果：**

- 财务缓存、权限过滤、连接管理、数据源管理、数据清理、统计、CRUD、查询逻辑已提取到独立 Service 和 Helper
- Provider 只保留状态管理、流程编排、Service 调用
- financial_provider.dart 从原始 1942 行减少到 732 行（减少 62%）
- 修复了 Service 实例共享问题，确保数据源状态正确同步
- 符合"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### 2026-05-30：P3 患者表单组件拆分（已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对患者表单组件进行拆分。

**拆分内容：**

- P3.1：提取牙齿状况记录管理为 patient_dental_records_widget.dart（已完成）
  - 创建 `lib/features/patients/widgets/patient_dental_records_widget.dart`
  - 职责：牙齿状况记录的 UI 和逻辑管理
  - 方法：_loadDentalCondition、_createEmptyDentalRecord、_addNewDentalRecord、_removeDentalRecord、_dentalConditionToJson、_notifyChange
  - UI 方法：build、_buildDentalRecordSimplified、_buildDentalChartSimplified、_buildCrossInputField、_getChartIcon

- P3.2：提取电话号码管理为 patient_phone_widget.dart（已完成）
  - 创建 `lib/features/patients/widgets/patient_phone_widget.dart`
  - 职责：电话号码的输入和管理
  - 方法：_processPhoneNumbers、_addAdditionalPhone、_removeAdditionalPhone、_notifyChange
  - UI 方法：build、_buildInfoField

- P3.3：提取基本信息表单为 patient_basic_info_widget.dart（已完成）
  - 创建 `lib/features/patients/widgets/patient_basic_info_widget.dart`
  - 职责：患者基本信息表单字段
  - 方法：_notifyChange
  - UI 方法：build、_buildGenderSelector、_buildInfoField、_buildTreatmentItemField

- P3.4：更新 patient_form_sheet.dart 主文件（已完成）
  - 添加新组件的 import
  - 删除原有的状态变量和方法
  - 在 build 方法中使用新组件
  - 更新保存逻辑以使用新组件的数据
  - patient_form_sheet.dart 从 1896 行减少到 479 行（减少 75%）

**新增文件：**

- `lib/features/patients/widgets/patient_dental_records_widget.dart`
- `lib/features/patients/widgets/patient_phone_widget.dart`
- `lib/features/patients/widgets/patient_basic_info_widget.dart`

**效果：**

- 牙齿状况记录、电话号码管理、基本信息表单逻辑已提取到独立 Widget
- patient_form_sheet.dart 只保留病历号管理、保存逻辑、组件编排
- patient_form_sheet.dart 从原始 1896 行减少到 479 行（减少 75%）
- 符合"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### 2026-05-30：P2 患者 UI 组件拆分（已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对患者 UI 组件进行拆分。

**拆分内容：**

- P2.1：迁移 patient_form_sheet.dart（1893行）
  - 从 `lib/widgets/patient_form_sheet.dart` 迁移到 `lib/features/patients/widgets/patient_form_sheet.dart`
  - 职责：患者表单底部弹窗，包含患者信息录入

- P2.2：迁移 patient_image_viewer.dart（354行）
  - 从 `lib/widgets/patient_image_viewer.dart` 迁移到 `lib/features/patients/widgets/patient_image_viewer.dart`
  - 职责：患者图片查看器组件

**更新引用：**

- `lib/screens/patient_detail_screen.dart`：更新 import 路径
- `lib/screens/patients_screen.dart`：更新 import 路径
- `lib/widgets/appointment_form_sheet.dart`：更新 import 路径

**保留在原位置：**

- `lib/screens/patient_detail_screen.dart`（页面级组件，暂不迁移）
- `lib/screens/patients_screen.dart`（页面级组件，暂不迁移）

**效果：**

- 患者相关的可复用 UI 组件已迁移到 `features/patients/widgets/`
- 符合模块化架构，患者模块的组件集中在 features/patients/ 下
- 便于后续维护和复用

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证 P2 拆分
- 继续执行阶段 3：设置模块拆分

### 2026-05-30：P1 患者 Provider 拆分（已完成）

按照"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标，对患者 Provider 进行拆分。

**拆分内容：**

- P1.1：提取患者初始化逻辑为 patient_initialization_service.dart（约80行）
  - 创建 `lib/features/patients/services/patient_initialization_service.dart`
  - 职责：数据源初始化、数据源类型管理、连接管理
  - 方法：initializeFromDatabase、setDataSourceType、setSqliteDataSource、setMySqlDataSource、currentDataSource

- P1.2：提取患者导出/备份逻辑为 patient_export_service.dart（约60行）
  - 创建 `lib/features/patients/services/patient_export_service.dart`
  - 职责：患者数据导出、备份功能
  - 方法：exportPatientsTable、savePatientBackupWithSaf

- P1.3：提取患者缓存管理为 patient_cache_helper.dart（约25行）
  - 创建 `lib/features/patients/helpers/patient_cache_helper.dart`
  - 职责：缓存数据管理、缓存刷新
  - 方法：cachedPatients、setCachedPatients、clearCache、hasCache

- P1.4：简化 Provider 主文件
  - patient_provider.dart 从 1492 行减少到 487 行（减少约 67%）
  - Provider 只保留：状态管理、流程编排、Service 调用
  - 删除了所有 MySQL/SQLite 专用方法（这些逻辑已在 Data Source 层处理）
  - 删除了工具方法（牙齿状况相关方法）

**新增文件：**

- `lib/features/patients/services/patient_initialization_service.dart`
- `lib/features/patients/services/patient_export_service.dart`
- `lib/features/patients/helpers/patient_cache_helper.dart`

**效果：**

- 主文件从 1492 行减少到 487 行（减少约 67%）
- Provider 只保留：状态管理、流程编排、Service 调用
- 各 Service 职责单一，便于测试和维护
- 符合"结构清晰、排查问题更快、增加功能更容易、文件职责明确、减少混用和耦合"的目标

**验证命令：**

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

**下一步建议：**

- 执行 flutter analyze 验证 P1 拆分
- 继续执行 P2：患者 UI 组件拆分

## 下一步建议

### 第一轮拆分建议

建议从 **阶段 2：患者模块拆分** 开始，因为：
- 患者模块是业务核心，拆分收益最大
- 参考 Windows 端经验，患者模块拆分质量最高
- 患者模块可以作为其他模块的参考样板

具体执行顺序：
1. P1：患者 Provider 拆分（提取 Service）
2. P2：患者 UI 组件拆分（迁移到 features/patients/widgets/）

## 验证命令

每次拆分后，用户需要执行：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

如需运行应用验证：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter run
```

## 历史归档索引

详细历史记录将归档到：
- `docs/android_split_history/`（按模块或阶段命名）

当前暂无归档记录。

## 参考文档

- Windows 端拆分计划：`D:\Data\android_project\dentist_app\dentist_app_incremental_split_plan.md`
- Windows 端拆分评估：`D:\Data\android_project\dentist_app\docs\windows_app_split_assessment_2026_05_29.md`

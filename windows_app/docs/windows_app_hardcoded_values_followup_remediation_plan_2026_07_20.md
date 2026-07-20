# Windows 端硬编码治理补充整改方案

方案日期：2026-07-20。

状态：进行中。本方案补充收口总方案批次 6～9 复查后确认的残留问题，范围仅包含 HC-08、HC-09、HC-11、HC-12；不重复处理已无静态残留证据的 HC-01～HC-07、HC-10。

关联总方案：`docs/windows_app_hardcoded_values_remediation_plan_2026_07_20.md`。

## 1. 复查结论

此前批次 6～8 已建立 `defaultAppName`、`DataSourceType`、`DataSourceMode`、`AppModule`、`MySqlConnectionPolicy` 和 `AppointmentStatus` 等统一入口，但业务代码尚未完整接入，因此不能视为代码全部完成。

| 编号 | 残留问题 | 主要证据 | 当前判断 |
|------|----------|----------|----------|
| HC-08 | 窗口标题、单实例提示、设置重置说明和关于页副标题仍写死默认应用名称 | `main.dart`、`settings_screen.dart`、`app_info_screen.dart` | 明确需要整改 |
| HC-09 | Provider、设置、备份／恢复及数据源初始化链路仍以字符串进行状态决策 | `database_provider.dart`、各业务 Provider、设置服务和初始化器 | 只整改决策入口，不机械替换全部字符串 |
| HC-11 | MySQL 默认端口仍在数据库 Provider、备份服务和设置服务重复定义 | `database_provider.dart`、`database_backup_service.dart`、`data_source_config_service.dart` | 明确需要整改 |
| HC-12 | 新预约仍可能写入中文状态，详情页和患者详情仍维护平行映射 | `patient_form_dialog.dart`、`appointment_details_screen.dart`、`patient_detail_appointment_widgets.dart` | 明确需要整改 |

## 2. 实施边界

### 2.1 本次必须处理

1. 所有应用名称决策点复用 `defaultAppName` 或当前 `SettingsProvider.appName`。
2. 数据源类型、数据源模式和模块 ID 在业务决策层使用现有类型定义。
3. SharedPreferences、JSON、Map、数据库字段和回调兼容接口在边界处显式转换为稳定字符串。
4. MySQL 默认端口和各类连接超时只从 `MySqlConnectionPolicy` 读取。
5. 新写入预约状态统一保存英文稳定值；读取继续兼容既有中英文状态。
6. 状态显示名、选项列表和颜色语义统一从 `AppointmentStatus` 派生。

### 2.2 明确保留

1. SQL、SharedPreferences、JSON 和数据库内的稳定协议值，如 `sqlite`、`mysql`、`scheduled`。
2. 表名、列名、Map 字段名和第三方 API 要求的字符串。
3. UI 中用于向用户解释 SQLite、MySQL 的普通文案。
4. `medical_records` 作为导航／权限模块 ID；模块数据源继续使用历史配置键 `medical`，且病历继续跟随患者数据源。本次不迁移配置键。
5. 登录预填、记住密码、MySQL 失败回退 SQLite、既有预约状态数据和数据库 schema 均不迁移。
6. 日志、导出和页面展示所需的日期格式不纳入 HC-10 扩大整改。

## 3. 任务 A：补齐应用名称唯一真源

### 3.1 改动范围

1. `main.dart`：
   - Provider 初始化前的窗口标题使用 `defaultAppName`。
   - 单实例提示无法读取当前 Provider，使用同一默认常量拼接提示文案。
   - `MaterialApp.title` 继续使用 `SettingsProvider.appName`。
2. `settings_screen.dart`：重置说明中的应用名称复用 `defaultAppName`，不得重复写字面量。
3. `app_info_screen.dart`：关于页副标题以当前 `settingsProvider.appName` 生成。
4. 保持采购图片导出和日志导出通过参数显式接收当前应用名称。

### 3.2 测试与退出条件

- 默认名称字面量只允许出现在 `config/app_defaults.dart`。
- 设置自定义名称后，主页、登录页、关于页、采购导出和日志导出均使用自定义名称。
- Provider 初始化前的窗口标题和单实例提示使用统一默认名称。
- 重置设置后恢复 `defaultAppName`。

## 4. 任务 B：收口数据源和模块状态决策

### 4.1 分层规则

```text
SharedPreferences / JSON / Map / 旧接口
                    ↓ 安全解析
DataSourceType / DataSourceMode / AppModule
                    ↓ 业务判断
Provider / 初始化器 / 备份恢复 / 设置编排
                    ↓ 显式序列化
SharedPreferences / JSON / Map / 数据库
```

业务层不得通过未知字符串继续运行。解析策略如下：

- 用户已保存的未知数据源类型或模式：记录明确错误，并按现有安全策略回退 SQLite／global。
- 运行时 API 收到未知数据源：失败关闭或抛出明确异常，不静默当作 MySQL 或 SQLite。
- 未知模块 ID：不授予权限，不创建隐式模块配置。

### 4.2 优先改动入口

按风险从低到高分三步处理，避免一次性机械替换：

1. 配置和设置入口：
   - `ConfigStorageService`
   - `DataSourceManagementService`
   - `DataSourceConfigService`
   - 设置页数据源选择、备份数据源选择和模块数据源选择
2. 数据库与通用服务：
   - `DatabaseProvider`
   - `DatabaseBackupService`
   - `ModuleMysqlConnectionService`
   - 数据库结构检测、备份和恢复服务
3. 业务 Provider 和初始化器：
   - 患者、预约、财务、材料、采购、用户和病历 Provider
   - 对应数据源初始化器及同步服务

公共方法若当前被大量字符串调用，可暂时保留字符串兼容入口，但入口内必须立即安全解析，并将内部实现迁移到类型化私有方法；不新增第二套长期并行 API。

### 4.3 模块标识规则

- 首页导航、角色模块权限、权限面板和连接警告统一读取 `AppModule`。
- 模块数据源配置通过 `AppModule.dataSourceConfigKey` 获取键。
- `medical_records` 与 `medical` 的映射只允许在 `AppModule` 内定义一次。
- Dashboard 和设置模块没有独立数据源，不应写入模块数据源配置。

### 4.4 测试与退出条件

- `sqlite`、`mysql`、`global`、`modular` 可完成历史配置反序列化和稳定值序列化。
- 未知值不会静默选择错误数据源或提升权限。
- 全局／模块化模式下各模块选择结果与整改前一致。
- MySQL 连接失败仍按现有行为临时降级 SQLite，不改写用户模块配置。
- 首页导航、权限集合、连接警告和模块数据源使用同一模块定义。
- 允许协议边界保留字符串，但业务状态判断不再散落新的字面量。

## 5. 任务 C：补齐 MySQL 默认端口和连接策略

### 5.1 改动范围

以下入口统一读取 `MySqlConnectionPolicy.defaultPort`：

- `DatabaseProvider` 的字段默认值、Map 解析回退和备份参数。
- `DatabaseBackupService` 的可选端口回退。
- `DataSourceConfigService` 和配置存储服务的端口回退。
- 数据源页面输入框初始值及提示值；提示文本可由常量转成字符串。

以下超时保持不同业务语义，不合并为一个通用超时：

- 建连超时 `connectionTimeout`。
- 连接验证超时 `validationTimeout`。
- 用户主动测试连接超时 `userTestTimeout`。
- 健康检查间隔 `healthCheckInterval`。
- 模块化初始化保险超时 `modularInitializationTimeout`。

### 5.2 测试与退出条件

- 除 `app_defaults.dart` 和数据库 schema／协议说明外，业务代码不再直接使用 `3306` 作为默认或回退值。
- 空端口和非法端口均回退 `MySqlConnectionPolicy.defaultPort`。
- 不同连接动作使用各自命名的超时策略。
- 备份、恢复、全局连接和模块化连接继续使用相同端口配置。

## 6. 任务 D：统一预约状态

### 6.1 数据兼容策略

稳定存储值保持：

| 稳定值 | 中文显示名 |
|--------|------------|
| `scheduled` | 已预约 |
| `completed` | 已完成 |
| `cancelled` | 已取消 |
| `missed` | 未到诊 |

- 新增和更新预约只写稳定英文值。
- `Appointment.fromMap` 继续兼容历史中英文值，并在内存中规范为稳定英文值。
- 本次不扫描、不修改历史 SQLite 或 MySQL 数据。
- 未知状态保留原始展示文本，但不能映射为任一可操作状态。

### 6.2 改动范围

1. `patient_form_dialog.dart`：新预约使用 `AppointmentStatus.scheduled.storageValue`。
2. `appointment_details_screen.dart`：按钮列表从 `AppointmentStatus.values` 生成，提交稳定值，显示中文名。
3. `appointment_card.dart`：继续由统一枚举生成选项，删除残余平行判断。
4. Dashboard、患者详情和牙科图标状态颜色统一接收解析后的 `AppointmentStatus`，颜色本身继续来自主题 token。
5. schema 中 `scheduled` 默认值属于协议固定值，可以保留；如需复用常量，必须确保 schema 仍是编译期可安全生成的稳定 SQL。

### 6.3 测试与退出条件

- 四种英文值和四种历史中文值均能解析为同一状态。
- 新建、编辑和详情页切换状态后持久化值均为英文。
- 列表、Dashboard、患者详情和预约详情显示名及颜色语义一致。
- 未知状态不崩溃、不被误判为已预约或已完成。
- 不执行数据库迁移。

## 7. 实施顺序

| 子批次 | 内容 | 风险 | 完成标志 |
|--------|------|------|----------|
| F1 | HC-08 应用名称 | 低 | 默认字面量唯一，相关专项测试通过 |
| F2 | HC-11 端口与超时 | 低 | 默认端口和超时无重复决策入口 |
| F3 | HC-12 预约状态 | 中 | 新写入统一英文，所有状态 UI 复用定义 |
| F4 | HC-09 数据源与模块 | 高 | 状态决策类型化，序列化兼容测试通过 |
| F5 | 全量验证与文档收口 | 中 | 静态检查、专项、全量测试通过，文档记录真实状态 |

F4 涉及跨模块状态流，实施时应按“配置入口 → 通用服务 → 业务 Provider／初始化器”分段验证；任何一步出现行为差异，先定位该段，不继续扩大修改范围。

## 8. 自动验证

每个子批次执行：

```bash
cmd.exe /c dart format <本批改动的 Dart 文件>
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub <本批专项测试>
git diff --check
git ls-files --eol -- <本批修改和新增的文本文件>
```

F5 执行：

```bash
cmd.exe /c flutter test --no-pub
```

不得通过删除 `build/test_cache`、注释错误或添加忽略标记绕过失败。

## 9. 人工回归

1. 自定义应用名称后检查登录页、主页、关于页、窗口标题、采购导出和日志导出；重置后恢复默认名称。
2. 全局 SQLite、全局 MySQL、模块化混合配置分别启动并核对患者、预约、财务、材料、采购、用户和病历数据源。
3. 模块化 MySQL 不可用时确认只进行运行时降级，不覆盖保存配置。
4. 使用默认端口和自定义端口分别测试连接、备份和恢复。
5. 新建预约、编辑预约、详情页切换四种状态，核对 SQLite／MySQL 存储值及四处界面显示。
6. 打开包含历史中文状态和未知状态的既有数据，确认兼容展示且未知状态不获得错误操作语义。

## 10. 文档收口规则

1. F1～F4 只有代码和对应专项测试通过后才能标记“代码与自动验证完成”。
2. F5 全量测试通过后，将总方案批次 6～8 更新为“待人工回归”；人工回归完成前不得标记“已完成”。
3. 每完成一个子批次，同步更新本方案实施记录、总方案进度表和根目录 `ROADMAP.md`。
4. 若复查发现新的静态命中，先判断是业务决策值还是协议／展示字面量，不以命中数量作为整改依据。

## 11. 实施记录

- 2026-07-20：复查确认 HC-08、HC-09、HC-11、HC-12 仍有残留，创建补充整改方案；本次只更新文档，不修改业务代码、不运行 Flutter 验证。
- 2026-07-20：完成 F1～F4 代码与自动验证。窗口标题、单实例提示、设置重置说明和关于页复用默认／当前应用名称；MySQL 默认端口改由 `MySqlConnectionPolicy.defaultPort` 提供；预约新建、编辑与详情操作统一写入英文稳定值，历史中文值继续兼容，未知值不获得预约状态操作语义；数据源配置、模块配置和 `DatabaseProvider` 入口显式解析类型，未知模块或数据源拒绝继续决策。新增预约模型兼容测试；`flutter analyze --no-pub` 与定义专项 5 项测试通过。全量测试已启动并执行至既有测试集，未运行应用；待人工回归。
- 2026-07-20：复核并补齐应用名称、端口提示、预约图标映射和连接验证超时；`flutter analyze --no-pub`、定义专项 5 项与全量 `flutter test --no-pub`（102 项）通过。复核同时确认 HC-09 仍有 76 个业务层数据源／模式字符串决策，F4 不能标记完成；人工回归仍未执行。
- 2026-07-20：完成 F4。Provider、同步服务、数据库结构检查与备份恢复服务的 76 个数据源／模式字符串业务决策，均改为通过 `DataSourceValueParsing` 显式解析后按 `DataSourceType`／`DataSourceMode` 语义判断；SharedPreferences、JSON、Map 和 SQL 的稳定协议字符串继续保留在边界。对相关目录的直接字符串决策扫描无命中，`flutter analyze --no-pub` 与定义专项 5 项通过；全量测试已启动，人工回归仍未执行。

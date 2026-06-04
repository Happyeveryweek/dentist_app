# dentist_app Android 端优化拆分方案

## 结论

`D:\Data\android_project\dentist_app\android_app` 已经完成第一阶段“把代码拆出来、放进 features 目录”的工作，但当前状态仍然是**半模块化**：

- `features/` 目录已经建立，部分 UI / Service 已迁入模块内。
- 根级 `providers/`、`data_sources/`、`widgets/` 仍然承担大量模块私有职责。
- `features/*` 内部仍然大量反向依赖根级 `providers/` 和 `data_sources/`，模块边界没有真正收口。
- 旧拆分文档已经明显落后于真实代码状态，继续按旧文档推进会误导后续拆分。

后续优化重点不再是“继续建目录”，而是：

1. 收口模块私有 UI 落点
2. 收口 Provider 职责
3. 收口 Data Source 依赖边界
4. 清理根级全局层中的模块私有残留
5. 用可重复执行的批次推进，而不是继续做一次性大重构

本方案只处理 Android 端拆分优化，不改数据库 schema，不改业务流程，不改 UI 交互结果，不做全项目格式化。

## 当前执行进度

### 第一批执行结果

- A1 新建优化方案文档，已完成。
- A2 更新旧总计划现状，已完成。
- B1 财务统计弹窗已归位到 `lib/features/financial/widgets/financial_statistics_dialog.dart`。
- B2 采购弹窗已归位到 `lib/features/purchases/widgets/purchase_record_dialog.dart` 和 `lib/features/purchases/widgets/purchase_item_dialog.dart`。
- B3 用户弹窗已归位到 `lib/features/users/widgets/user_dialog.dart`。
- B4 `confirm_dialogs.dart` 已完成归属审计，暂时保留在根级 `lib/widgets/`，本轮不迁移。

### 第二批执行结果

- C1 `appointments_screen.dart` 已拆出 `lib/features/appointments/widgets/appointments_screen_body.dart`
- 预约页面的头部、搜索筛选、日历/列表切换和空状态已下沉到新 widget
- `appointments_screen.dart` 现在主要保留数据加载、过滤逻辑、弹窗和删除确认
- C2 `patients_screen.dart` 已拆出 `lib/features/patients/widgets/patients_screen_body.dart`
- 患者页面的头部、搜索筛选、统计栏、列表/空态和加载更多展示已下沉到新 widget
- `patients_screen.dart` 现在主要保留分页、时间筛选、排序、弹窗和删除确认

### 第三批执行结果

- C3 `financial_management_screen.dart` 已拆出 `lib/features/financial/widgets/financial_management_screen_body.dart`
- 财务页面的统计卡片、搜索栏、错误/空态、列表和加载更多展示已下沉到新 widget
- `financial_management_screen.dart` 现在主要保留数据加载、搜索、排序、统计弹窗、删除和刷新编排

### 第四批执行结果

- C4 `settings_dialogs.dart` 已拆成入口壳，具体实现下沉到 `settings_common_dialogs.dart`、`settings_backup_restore_dialogs.dart`，并复用 `sqlite_config_dialogs.dart`
- 设置页的通用确认、SQLite/MySQL 配置提示、备份/恢复/导出三个对话框职责已分离
- `settings_screen.dart` 的调用点保持不变，仍然通过 `SettingsDialogs` 访问
- 已修正入口壳对 `settings_backup_restore_dialogs.dart` 的引用，避免分析阶段找不到 URI

### 第五批执行结果

- D1 `user_provider.dart` 已将用户列表缓存与权限缓存委托给 `UserCacheService`，权限读取/更新/加载/刷新委托给 `UserPermissionService`
- `user_provider.dart` 现在主要保留用户状态、登录编排、数据源初始化和对外方法入口
- 用户权限缓存、当前用户权限加载、当前用户权限刷新、当前用户权限查询等职责已从 Provider 内部收口到 feature services

### 第六批执行结果

- D2 `database_provider.dart` 已将数据库启动编排抽到 `DatabaseBootstrapService`
- 数据库配置加载、SQLite/MySQL 启动选择、自动切换到 SQLite、初始化结果汇总已从 Provider 主体中抽离
- `database_provider.dart` 现在主要保留数据库状态、连接协调、对外入口和少量兼容方法

### 第七批执行结果

- D3 `purchase_provider.dart` 已将初始化编排抽到 `PurchaseInitializationService`
- 采购 Provider 的数据库接入、数据源选择、缓存/权限/连接/统计服务装配已从主文件中抽离
- `purchase_provider.dart` 现在主要保留采购数据 CRUD、统计入口、缓存入口和状态编排

### 第八批执行结果

- D3 `patient_image_provider.dart` 已将初始化编排抽到 `PatientImageInitializationService`
- 患者图片 Provider 的数据库接入、数据源识别和初始化结果汇总已从主文件中抽离
- `patient_image_provider.dart` 现在主要保留图片/材料读取、缓存管理、连接检查和恢复处理

### 第九批执行结果

- D3 `financial_provider.dart` 已将初始化编排抽到 `FinancialInitializationService`
- 财务 Provider 的数据库接入、数据源识别和连接同步已从主文件中抽离
- `financial_provider.dart` 现在主要保留财务记录 CRUD、统计入口、缓存入口、查询编排和状态协调

### 第十批执行结果

- D3 `material_provider.dart` 已将初始化编排抽到 `MaterialInitializationService`
- 材料 Provider 的数据库接入、数据源识别和连接同步已从主文件中抽离
- `material_provider.dart` 现在主要保留材料 CRUD、编码生成、统计入口、缓存和状态协调

### 第十一批执行结果

- D3 `medical_record_provider.dart` 已将初始化编排抽到 `MedicalRecordInitializationService`
- 病历 Provider 的数据库接入、数据源识别和连接同步已从主文件中抽离
- `medical_record_provider.dart` 现在主要保留病历记录、项目、模板的查询与缓存编排

### 第十二批执行结果

- D3 `patient_provider.dart` 已将删除患者编排抽到 `PatientDeletionService`
- 患者 Provider 的关联预约清理、患者删除和缓存清理已从主文件中抽离
- `patient_provider.dart` 现在主要保留患者列表查询、增改、导出和缓存编排

### 第十三批执行结果

- D3 `appointments_provider.dart` 已将初始化编排抽到 `AppointmentInitializationService`
- 预约 Provider 的数据库接入、数据源识别和连接同步已从主文件中抽离
- `appointments_provider.dart` 现在主要保留预约查询、增改、删除、缓存和权限过滤编排

### 第十四批执行结果

- `DatabaseSettingsManager` 已从 `settings_provider.dart` 拆出到 `features/settings/services/database_settings_manager.dart`
- `settings_provider.dart` 现在只保留应用偏好状态和 `SettingsManager` 的读写编排
- 设置页的数据库配置状态与应用偏好状态已分离

### 第十五批执行结果

- D3 `user_provider.dart` 已将数据库初始化编排抽到 `UserInitializationService`
- 用户登录、认证、登出、统计和角色修复已委托给现有的 `UserAuthenticationService`、`UserStatisticsService`、`UserDataRepairService`
- `user_provider.dart` 现在主要保留用户 CRUD、权限入口、缓存和状态协调

### 第十六批执行结果

- D3 `user_validation_service.dart` 已接管用户名和邮箱是否存在的校验
- `user_provider.dart` 现在不再自己拼接用户名/邮箱存在性查询
- 用户校验职责已从 Provider 中单独收口到 `UserValidationService`

### 第十七批执行结果

- D3 `user_permission_service.dart` 已接管用户权限判断和医生过滤条件
- `user_provider.dart` 不再自己维护 `hasModulePermission`、`buildDoctorFilter`、`shouldFilterByDoctor` 的权限逻辑
- 用户权限职责已从 Provider 中进一步收口到 `UserPermissionService`

### 第十八批执行结果

- D3 `user_connection_service.dart` 已接管用户连接状态、连接检查和连接重置
- `user_provider.dart` 不再自己维护 `isConnected`、`isReconnecting`、`lastError` 这组连接状态字段
- 用户连接职责已从 Provider 中进一步收口到 `UserConnectionService`

### 第十九批执行结果

- `login_initialization_service.dart` 已拆分出独立的 `login_database_switch_service.dart`
- `login_initialization_service.dart` 现在只保留等待数据库和用户初始化完成的逻辑
- 登录页的数据库切换提示职责已独立收口到 `LoginDatabaseSwitchService`

### 第二十批执行结果

- `login_handler.dart` 已保持为登录入口编排层，不再继续拆分为更细的 service
- 登录提交流程、凭证保存、错误分流和页面跳转已经处在当前合理边界
- 本轮未新增迁移，避免把登录入口拆成过碎的小工具链

### 第二十一批执行结果

- `login_credentials_service.dart` 已完成审计，当前仅包含登录凭证读写和 `LoginCredentials` 数据类
- 该文件已经是纯工具层，没有继续下拆的有效边界
- 下一步建议切到 `database_connection_service.dart`，继续收口登录链路里仍带有数据库切换职责的部分

### 第二十二批执行结果

- `database_connection_service.dart` 已拆出 `MySQLConnectionRetryService` 和 `SQLiteDatabaseSwitchService`
- `database_connection_service.dart` 现在只保留兼容门面，向两个更窄的服务转发调用
- 数据库重试和 SQLite 切换职责已分离，登录链路里的数据库操作边界更清晰
- 下一步建议切到 `user_authentication_service.dart`，继续收口登录认证链路中仍然偏重的业务逻辑

### 第二十三批执行结果

- `user_authentication_service.dart` 已剥离登录与登出会话动作
- 登录与登出现已收口到独立的 `UserSessionService`
- `user_authentication_service.dart` 现在主要只保留认证执行、权限预加载和认证后通知
- 下一步建议切到 `user_permission_service.dart`，继续收口用户权限边界

### 第二十四批执行结果

- `user_permission_service.dart` 已进一步收口，当前只保留权限读写、模块权限判断、医生过滤规则
- 当前用户的权限加载、刷新、查询和模块权限判断已拆到 `UserCurrentPermissionService`
- `user_permission_service.dart` 不再承载当前用户包装逻辑，职责边界更清晰
- 下一步建议切到 `user_data_repair_service.dart`，继续收口用户服务里剩余的修复/重建类职责

### 第二十五批执行结果

- `user_data_repair_service.dart` 已拆出 `UserMySqlRoleRepairService` 和 `UserSqliteRoleRepairService`
- `user_data_repair_service.dart` 现在只保留数据库类型分发和刷新用户列表的收口逻辑
- MySQL 和 SQLite 的角色修复职责已彻底分离，后续若继续优化可直接针对单独实现类
- 下一步建议切到 `user_statistics_service.dart`，继续收口用户服务中剩余的统计类职责

### 第二十六批执行结果

- 已修正 `user_current_permission_service.dart` 的刷新路径
- 当前用户权限刷新现在通过 `UserPermissionService.clearPermissionsCache()` 清缓存后重新预热
- `UserPermissionService` 新增了权限缓存清理入口，保持权限读写与缓存控制同域
- 下一步建议切到 `user_statistics_service.dart`，继续收口用户服务中剩余的统计类职责

### 第二十七批执行结果

- `user_statistics_service.dart` 已完成审计，当前仅包含按数据源分支的用户统计查询
- 该文件已经是统计链路的最小合理边界，不再继续拆分为更细服务
- 下一步建议切到 `login_database_switch_service.dart` 或 `user_connection_service.dart`，优先处理登录链路里仍偏薄但可收口的辅助职责

### 第二十八批执行结果

- `user_connection_service.dart` 已拆出 `UserConnectionStateService` 和 `UserConnectionHealthService`
- `user_connection_service.dart` 现在主要保留兼容门面，向状态服务和连接检查服务转发调用
- `UserCacheService` 已拆成 `UserListCacheService` 和 `UserPermissionCacheService`
- 用户列表缓存与权限缓存职责已分离，缓存层边界更清晰
- 下一步建议切到 `user_validation_service.dart`，继续收口用户名/邮箱存在性校验边界

### 第二十九批执行结果

- `user_validation_service.dart` 已把 SQLite/MySQL 的存在性查询公共逻辑抽到 `UserExistenceQueryService`
- `user_validation_service.dart` 现在只保留用户名/邮箱校验入口
- 用户存在性查询的表名、字段名、数据源分支已统一收口
- 下一步建议切到 `user_initialization_service.dart`，继续审计用户初始化编排是否还有可收口的内部边界

### 第三十批执行结果

- 已修正 `user_validation_service.dart` 的 `Database` 类型导入
- `user_validation_service.dart` 现在可以继续保留 `Database?` 兼容构造参数
- 本轮仅修复编译断点，不扩大职责边界
- 下一步建议仍切到 `user_initialization_service.dart`

### 第三十一批执行结果

- `user_initialization_service.dart` 已完成审计，当前仅负责数据库提供者接入、数据源识别和 SQLite 回退
- 该文件已经是用户初始化链路的最小编排边界，不再继续拆分
- 下一步建议切到 `login_database_switch_service.dart`，继续审计登录链路中仍偏薄但可独立收口的辅助服务

### 第三十二批执行结果

- `login_database_switch_service.dart` 已完成审计，当前仅负责监听数据库切换并弹出提示
- 该文件已经是登录页数据库切换链路的最小边界，不再继续拆分
- 下一步建议切到 `user_existence_query_service.dart`，继续审计用户名/邮箱存在性查询链路中是否还有可收口的公共逻辑

### 第三十三批执行结果

- `user_existence_query_service.dart` 已完成审计，当前仅负责用户名/邮箱存在性查询的公共分发
- 该文件已经是用户存在性查询链路的最小公共边界，不再继续拆分
- 下一步建议切到 `user_current_permission_service.dart`，继续审计当前用户权限包装链路中是否还有可收口的辅助职责

### 第三十四批执行结果

- `user_current_permission_service.dart` 已完成审计，当前仅负责当前用户权限的加载、刷新、查询和模块权限判断包装
- 该文件已经是当前用户权限包装链路的最小边界，不再继续拆分
- 下一步建议切到 `user_provider.dart`，继续收口仍然较重的用户 Provider 主体

### 第三十五批执行结果

- `user_provider.dart` 已继续抽出 `UserCrudService`
- 用户列表获取、按 ID 查询、创建、更新、删除逻辑已从 Provider 主体中移出
- `user_provider.dart` 现在主要保留初始化、登录、权限、统计和少量状态编排
- 下一步建议继续审计 `user_provider.dart` 剩余逻辑，优先看登录与权限编排之外是否还有可独立收口的辅助职责

### 第三十六批执行结果

- `database_provider.dart` 已清理冗余的 MySQL 查询辅助实现
- `MySqlDataSource` 内重复的 `_formatDateForMySQL`、`_getSafeValue` 已移除
- 旧的 `_queryMySQLData`、`_processDateField`、`_formatDateForMySQL` 实现已注释封存，避免继续参与编译
- `database_provider.dart` 现在继续保留数据库状态、连接协调、对外入口和少量兼容方法，下一轮可继续收口剩余编排职责

### 第三十七批执行结果

- `database_provider.dart` 进一步清理了未使用的内部方法与导入
- `_startConnectionHealthMonitoring`、`_stopConnectionHealthMonitoring`、`_checkAndSyncData`、`_createMySQLTables` 已移除
- 顶部未使用的 schema / 导出 / 工具包导入已收口，`database_provider.dart` 现在只保留实际使用的数据库编排依赖
- 下一轮继续围绕 `database_provider.dart` 剩余的状态协调和数据源封装边界推进

### 第三十八批执行结果

- `database_provider.dart` 已移除冗余的 `_activeDataSource`、`MySqlDataSource`、`SqliteDataSource` 和相关缓存字段
- SQLite 侧只保留真实使用的 `sqliteDatabase` 入口，初始化与关闭继续由专用服务负责
- `database_provider.dart` 现在只保留数据库状态、重连、同步、初始化编排、关闭与对外查询入口
- 该文件已收口到当前可接受边界，下一步建议切到数据访问层的 `user_data_source.dart`

### 第三十九批执行结果

- `user_data_source.dart` 已收口为纯接口文件
- `SqliteUserDataSource` 和 `MySqlUserDataSource` 已拆出到独立文件
- `user_provider.dart` 已改为从新文件引入具体数据源实现
- 数据访问层的数据源实现已开始按 SQLite / MySQL 分文件收口，下一步建议继续处理 `patient_data_source.dart`

### 第四十批执行结果

- `mysql_user_data_source.dart` 已修正 `affectedRows` 的空值判断
- MySQL 数据源的创建、更新和删除结果判断现在统一使用安全的空值兜底
- 这轮仅修复编译层报错，不扩大数据访问边界
- 下一步继续推进 `patient_data_source.dart`

### 第四十一批执行结果

- `patient_data_source.dart` 已修正 `insertId` 和 `affectedRows` 的空值判断
- 患者数据源的 MySQL 创建、更新、删除结果判断现在统一使用安全兜底
- 这轮先消除编译断点，下一步继续推进患者数据源的收口整理

### 第四十二批执行结果

- `patient_data_source.dart` 已收口为纯接口文件
- `SqlitePatientDataSource` 和 `MySqlPatientDataSource` 已拆出到独立文件
- `patient_provider.dart` 已切换到新文件引入患者数据源具体实现
- 患者数据源实现已完成分文件收口，下一步建议继续处理 `medical_record_data_source.dart`

### 第四十三批执行结果

- `medical_record_data_source.dart` 已继续收口为接口文件
- `SqliteMedicalRecordDataSource` 和 `MySqlMedicalRecordDataSource` 已拆出到独立文件
- `medical_record_provider.dart` 已切换到新文件引入病历数据源具体实现
- 病历数据源实现已完成分文件收口，下一步建议继续处理 `purchase_data_source.dart`

### 第四十四批执行结果

- 已在 `medical_record_provider.dart` 和 `patient_provider.dart` 中隐藏旧数据源实现名，消除接口文件与新实现文件的撞名
- 这轮仅修正导入冲突，不扩大业务边界
- 下一步继续推进 `purchase_data_source.dart`

### 第四十五批执行结果

- `purchase_data_source.dart` 已继续收口为接口文件
- `SqlitePurchaseDataSource` 和 `MySqlPurchaseDataSource` 已拆出到独立文件
- `purchase_provider.dart` 已切换到新文件引入采购数据源具体实现
- 采购数据源实现已完成分文件收口，下一步建议进入 `database_models.dart` 审计

### 下一步建议

优先进入共享模型与辅助层收口，按收益顺序先做：

1. `F2 其他共享模型/辅助文件`

### 文档维护规则

- 以后不再更新 `android_app_incremental_split_plan.md`
- 后续只维护本文件 `android_app_optimization_split_plan_2026_06_01.md`
- 每次执行完只在本文件末尾补充执行进度表，并同步更新“下一次推荐执行什么”

## 当前状态评估

### 1. 已有成果

- 已建立 `lib/features/appointments`、`financial`、`patients`、`purchases`、`settings`、`users`、`dashboard`、`materials`、`medical_records`。
- 多个模块已经有独立 `services/`、`widgets/`、`helpers/`。
- 大部分历史 `part` 风格拆分没有继续残留，这是正确方向。
- 一些核心大文件已经明显缩小，例如：
  - `lib/screens/settings_screen.dart`
  - `lib/features/appointments/widgets/appointment_form_sheet.dart`
  - `lib/providers/financial_provider.dart`
  - `lib/providers/patient_provider.dart`

### 2. 当前主要问题

#### P0：边界未收口

典型问题不是“没拆文件”，而是**拆出来的文件仍然穿透全局层**。

示例：

- `lib/features/appointments/widgets/appointment_form_sheet.dart` 仍直接依赖：
  - `providers/database_provider.dart`
  - `providers/appointments_provider.dart`
  - `providers/patient_provider.dart`
- `lib/features/settings/widgets/settings_dialogs.dart` 仍直接依赖：
  - `providers/database_provider.dart`
  - `providers/patient_provider.dart`
  - `providers/app_state.dart`
- `lib/features/users/services/database_connection_service.dart` 仍直接依赖：
  - `providers/database_provider.dart`
  - `providers/user_provider.dart`
  - `providers/settings_provider.dart`

这意味着目录是模块化的，但依赖关系仍然是全局耦合的。

#### P0：根级仍残留模块私有文件

当前根级 `lib/widgets/` 中明显仍有模块私有文件：

- `financial_statistics_dialog.dart`
- `purchase_item_dialog.dart`
- `purchase_record_dialog.dart`
- `user_dialog.dart`
- `confirm_dialogs.dart`

这些文件继续留在根级，会导致后续维护时无法快速判断“这是全局组件还是某个业务模块私有组件”。

#### P0：根级 Provider 仍偏重

当前仍较重的 Provider 包括：

- `lib/providers/user_provider.dart`：975 行
- `lib/providers/database_provider.dart`：703 行
- `lib/providers/patient_image_provider.dart`：610 行
- `lib/providers/financial_provider.dart`：591 行
- `lib/providers/purchase_provider.dart`：588 行

这说明 Android 端已经完成“第一轮抽离”，但还没完成“第二轮收口”。

#### P1：大文件仍集中在对话框和详情页

当前较重文件包括：

- `lib/features/settings/widgets/settings_dialogs.dart`：1200 行
- `lib/widgets/financial_statistics_dialog.dart`：908 行
- `lib/models/database_models.dart`：907 行
- `lib/screens/medical_record_detail_screen.dart`：865 行
- `lib/screens/settings_screen.dart`：844 行
- `lib/screens/financial_management_screen.dart`：833 行
- `lib/screens/appointments_screen.dart`：816 行
- `lib/features/appointments/widgets/appointment_form_sheet.dart`：799 行
- `lib/screens/patients_screen.dart`：784 行
- `lib/features/patients/widgets/patient_dental_records_widget.dart`：750 行

这些文件不适合继续无规则下沉，必须按“同模块、同层级、同职责簇”分批处理。

#### P1：计划文档已过时

现有文档 `android_app/docs/android_app_incremental_split_plan.md` 中仍保留大量早期状态描述，例如：

- 大文件排行明显过时
- “所有代码仍在根级目录”与当前实际代码不符
- 拆分阶段描述与代码真实状态不一致

如果不先补一份新的优化方案，后续拆分很容易重复劳动。

## 优化拆分目标

本轮优化目标不是“把所有文件都挪进 features”，而是达到下面 5 个结果：

### G1：模块私有文件位置可预测

看到文件名后，能快速判断它属于：

- 全局通用层
- 某个模块私有层

### G2：Provider 只保留状态与编排

Provider 允许保留：

- 状态字段
- `notifyListeners`
- 生命周期初始化
- 调用多个 service 的流程编排

Provider 不应继续承担：

- 长段查询条件拼装
- 大块数据清洗
- 复杂权限判断
- 对话框输入规则处理
- 跨模块连接细节

### G3：Data Source 不再成为“全局业务杂物箱”

保留现有 data source 文件位置不强迁移，但其职责必须收口为：

- 面向一个模块的数据访问
- 统一查询入口
- 统一过滤条件构建
- SQLite/MySQL 差异封装

### G4：根级 widgets 只保留真正通用组件

根级 `lib/widgets/` 只保留跨模块复用组件，例如：

- `app_card.dart`
- `modern_date_picker.dart`
- `stateful_text_field.dart`
- `toast_manager.dart`
- `message_toast.dart`

### G5：后续每一轮都能稳定复用本方案

每一轮拆分都必须满足：

- 只拆一个模块
- 只动一个风险层级
- 有明确完成定义
- 有明确验证命令

## 目标结构约定

后续执行时，按下面约定判断文件应该放哪里。

### 1. 保留在根级的目录

- `lib/screens/`
  - 保留页面入口
  - 允许引用 feature 内 widgets / services
  - 不再堆模块私有大段 UI 实现
- `lib/providers/`
  - 暂不整体迁移目录
  - 但 Provider 职责要持续收口
- `lib/data_sources/`
  - 暂不整体迁移目录
  - 但按模块逐个收口查询与差异逻辑
- `lib/widgets/`
  - 只保留真正跨模块通用组件
- `lib/models/`
  - 保留通用 model、数据库 schema、跨模块模型

### 2. 放入模块目录的内容

应放入 `lib/features/<module>/widgets/`：

- 某模块的表单弹窗
- 某模块的统计弹窗
- 某模块的详情卡片
- 某模块的筛选栏
- 某模块的列表项
- 某模块的空状态 / 错误状态

应放入 `lib/features/<module>/services/`：

- 查询条件组装
- 导出逻辑
- 初始化流程
- 权限过滤
- 缓存管理
- 连接协调
- 数据清洗

应放入 `lib/features/<module>/helpers/`：

- 轻量格式转换
- 小型工具函数
- 与单个模块强绑定、但不值得上升到 service 的逻辑

## 拆分执行总原则

### 原则 1：不做目录洁癖式迁移

只因为“看起来更整齐”而移动文件，没有意义。  
必须满足至少一条再拆：

- 文件明显属于某个模块私有职责
- 迁移后能减少根级依赖
- 迁移后能减少 import 混乱
- 迁移后能为下一轮 Provider / Data Source 收口创造前置条件

### 原则 2：先 UI 归位，再逻辑收口

Android 端当前更适合先处理：

1. 根级模块私有 Widget 迁移
2. 屏幕内大段 UI 组件拆分
3. Provider 职责收口
4. Data Source 查询收口

不要一上来就动：

- 数据源大规模重构
- 全量 Provider 迁移目录
- 所有 screen 迁移到 feature 下

### 原则 3：不把“页面入口”和“页面实现”混为一谈

允许 `screens/` 继续保留页面入口文件。  
但页面内部的大块区域应持续抽到 feature widgets。

### 原则 4：每轮拆分都必须有停止点

每轮必须能在一个自然边界停下，典型停止点：

- 一个对话框完整拆完
- 一个 screen 的列表区 + 筛选区完整拆完
- 一个 Provider 的一类逻辑完整抽完
- 一个 Data Source 的一条查询链完整收口

## 详细执行方案

下面是按优先级排列的可执行方案。默认按 `P0 -> P1 -> P2` 执行。

---

## 阶段 A：文档与基线收口

### A1：新增优化方案文档

目标：

- 建立新的执行基线
- 不再继续依赖旧流水账文档作为当前现状判断

执行内容：

- 保留旧文档作为历史记录
- 新增优化方案文档
- 后续每轮拆分都同步更新旧总计划的“最近记录”，但具体执行顺序以本方案为准

完成标准：

- 新文档存在
- 当前问题、优先级、执行顺序明确

风险：

- 无代码风险

验证：

- 无需代码验证

### A2：校正文档中的真实现状

目标：

- 让后续拆分不再基于过期数据

执行内容：

- 更新 `android_app_incremental_split_plan.md` 中：
  - 当前大文件排行
  - 已完成模块拆分事实
  - 当前“半模块化”判断
  - 下一步建议

完成标准：

- 文档描述与当前代码状态一致

风险：

- 无代码风险

验证：

- 无需代码验证

---

## 阶段 B：根级 widgets 归位

这是当前收益最高、风险最低的一阶段，应优先完成。

### B1：财务模块私有弹窗归位

目标文件：

- `lib/widgets/financial_statistics_dialog.dart`

目标位置：

- `lib/features/financial/widgets/financial_statistics_dialog.dart`

执行内容：

- 迁移文件
- 更新所有引用路径
- 检查是否与 `progressive_statistics_dialog.dart` 的职责重复或交叉
- 若两个统计弹窗定位不同，保留两个文件；若有重复区域，只做记录，不在本轮合并

完成标准：

- 根级 `widgets/` 不再承载财务统计弹窗
- 财务管理页引用只指向 feature 内文件

风险：

- 低风险，主要是 import 路径和同名引用错误

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### B2：采购模块私有弹窗归位

目标文件：

- `lib/widgets/purchase_record_dialog.dart`
- `lib/widgets/purchase_item_dialog.dart`

目标位置：

- `lib/features/purchases/widgets/purchase_record_dialog.dart`
- `lib/features/purchases/widgets/purchase_item_dialog.dart`

执行内容：

- 迁移两个文件
- 统一处理它们之间的相互引用
- 更新 `purchase_records_screen.dart`、`purchase_detail_screen.dart` 等所有引用

完成标准：

- 根级 `widgets/` 不再保留采购模块私有对话框

风险：

- 低风险，需注意两个 dialog 互相 import 的相对路径

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### B3：用户模块私有弹窗归位

目标文件：

- `lib/widgets/user_dialog.dart`

目标位置：

- `lib/features/users/widgets/user_dialog.dart`

执行内容：

- 迁移文件
- 更新 `users_screen.dart`、`user_detail_screen.dart` 的 import

完成标准：

- 用户模块表单对话框落到 users feature 内

风险：

- 低风险

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### B4：确认 `confirm_dialogs.dart` 的归属

目标文件：

- `lib/widgets/confirm_dialogs.dart`

执行方式：

- 不直接迁移，先审计

判断标准：

- 如果 80% 以上是跨模块通用确认框，保留在根级
- 如果已经演变成模块混杂集合，后续拆成：
  - `widgets/common_confirm_dialogs.dart`
  - 各模块私有 confirm dialog

完成标准：

- 对其归属做出明确判断
- 不在未确认前贸然迁移

风险：

- 误迁移会扩大引用面

验证：

- 如果仅审计，无需代码验证
- 如果发生拆分，执行 `flutter analyze`

---

## 阶段 C：screen 内 UI 职责继续下沉

这一阶段只动 UI，不动 Provider / Data Source。

### C1：appointments_screen.dart 收口

目标文件：

- `lib/screens/appointments_screen.dart`

现状：

- 816 行
- 已依赖 feature 内多个 widgets
- 仍可能残留筛选、列表、操作区编排之外的大段 UI

建议拆分顺序：

1. 预约顶部筛选区
2. 列表卡片区
3. 日历视图区切换
4. 空状态 / 加载态 / 错误态

完成标准：

- screen 只保留：
  - 页面状态
  - Provider 调用
  - 页面级事件编排
  - 各区域 widget 装配

风险：

- 中低风险

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### C2：patients_screen.dart 收口

目标文件：

- `lib/screens/patients_screen.dart`

现状：

- 784 行
- 已依赖 feature 内多种 widgets
- 继续收口的重点应是页面内剩余筛选 / 排序 / 批量操作编排

建议拆分顺序：

1. 顶部统计与搜索区
2. 列表区
3. 排序 / 筛选弹层
4. 空状态 / 错误态

完成标准：

- screen 主文件降到可维护范围
- 页面只保留入口编排

风险：

- 中低风险

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### C3：financial_management_screen.dart 收口

目标文件：

- `lib/screens/financial_management_screen.dart`

现状：

- 833 行
- 已有财务 widgets，但 screen 仍较重

建议拆分顺序：

1. 顶部统计区
2. 搜索和筛选区
3. 列表区 / 表格区
4. 批量动作或分页区

完成标准：

- 与财务模块内 widgets 的职责分工稳定

风险：

- 中风险，财务页面联动较多

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

### C4：settings_screen.dart 收口

目标文件：

- `lib/screens/settings_screen.dart`
- `lib/features/settings/widgets/settings_dialogs.dart`
- `lib/features/settings/widgets/database_source_section.dart`
- `lib/features/settings/widgets/sqlite_config_dialogs.dart`

现状：

- `settings_screen.dart` 已降到 844 行
- 但 `settings_dialogs.dart` 又长到 1200 行

执行策略：

- 本轮不继续把 screen 往更多文件硬切
- 重点处理 `settings_dialogs.dart` 内的职责分组

建议拆分为：

1. 数据源切换类对话框
2. 备份恢复类对话框
3. 导出/同步类对话框
4. 重置/确认类对话框

完成标准：

- `settings_dialogs.dart` 不再承担多个大类对话框混合职责

风险：

- 中风险，设置页牵涉数据源和全局配置

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

---

## 阶段 D：Provider 边界收口

这一阶段开始进入中风险区域。按项目约定，执行前应提醒切换中智能。

### D1：user_provider.dart 收口

目标文件：

- `lib/providers/user_provider.dart`

现状：

- 975 行
- 仍是当前最重 Provider

建议拆分顺序：

1. 登录态初始化与恢复
2. 权限相关逻辑
3. 数据源切换 / 连接协调
4. 用户 CRUD 编排之外的辅助逻辑

优先抽出：

- `features/users/services/user_session_service.dart`
- `features/users/services/user_permission_orchestrator.dart`
- `features/users/services/user_data_source_coordinator.dart`

完成标准：

- Provider 只保留用户状态、登录态、事件触发与编排

风险：

- 中风险，容易影响登录和初始化

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
flutter run
```

重点验证：

- 应用启动
- 登录
- 权限读取
- 用户列表/详情

### D2：database_provider.dart 收口

目标文件：

- `lib/providers/database_provider.dart`

现状：

- 703 行
- 文件不算超大，但位置非常关键

处理原则：

- 只做职责收口，不做目录大迁移
- 目标是让它成为“数据库状态与连接编排中心”，而不是业务逻辑承载点

建议抽离内容：

1. 配置装载
2. 健康检查
3. 自动重连协调
4. 向各模块同步数据源状态的桥接逻辑

完成标准：

- database_provider 不承担模块业务判断

风险：

- 高于一般 Provider

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
flutter run
```

重点验证：

- SQLite 启动
- MySQL 启动
- 数据源切换
- 页面首次加载

### D3：purchase_provider.dart / financial_provider.dart / patient_image_provider.dart 收口

执行顺序建议：

1. `purchase_provider.dart`
2. `patient_image_provider.dart`
3. `financial_provider.dart`

理由：

- 财务模块已经拆过一轮，继续拆收益还在，但优先级低于用户和数据库初始化链
- 采购和图片流程更容易形成清晰边界

完成标准：

- Provider 文件继续变薄
- 逻辑迁移后不新增跨模块依赖

风险：

- 中风险

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

---

## 阶段 E：Data Source 查询收口

这一阶段不建议早做，也不建议并行做多个模块。

### E1：user_data_source.dart 收口

目标文件：

- `lib/data_sources/user_data_source.dart`

现状：

- 696 行
- 用户模块初始化、认证、权限读取容易在这里继续堆积

执行重点：

- 统一认证相关查询入口
- 统一权限查询入口
- 统一 SQLite/MySQL 差异处理
- 消除重复 where / args 拼装

完成标准：

- user_data_source 中的查询按职责分组清晰
- 上层 service 不再反复拼接同类条件

风险：

- 中风险

验证命令：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
flutter run
```

### E2：patient_data_source.dart 收口

目标文件：

- `lib/data_sources/patient_data_source.dart`

执行重点：

- 搜索条件构建
- 分页与 count 条件复用
- 患者筛选条件统一

完成标准：

- 分页查询、统计查询、搜索查询共用同一条件生成逻辑

### E3：medical_record_data_source.dart 收口

目标文件：

- `lib/data_sources/medical_record_data_source.dart`

执行重点：

- 详情查询、列表查询、导出查询分组
- SQLite/MySQL 差异逻辑集中

### E4：purchase_data_source.dart 收口

目标文件：

- `lib/data_sources/purchase_data_source.dart`

执行重点：

- 统计、明细、分页查询分离
- 避免一处改字段影响多个查询

---

## 阶段 F：根级公共层审计

### F1：`database_models.dart` 审计

目标文件：

- `lib/models/database_models.dart`

现状：

- 907 行

处理原则：

- 本轮只审计，不强拆
- 先区分：
  - 真正跨模块通用模型
  - 单模块专用 DTO / VO / view data

后续处理：

- 单模块专用 model 再逐步迁到各自 `features/<module>/models/`

### F2：`database_utils.dart` / `sync_manager.dart` 审计

目标文件：

- `lib/utils/database_utils.dart`
- `lib/utils/sync_manager.dart`

处理原则：

- 判断是否混入业务逻辑
- 如果已经承载模块业务，拆出对应 service

### F3：全局 widgets 白名单化

保留在根级的候选文件：

- `app_card.dart`
- `modern_date_picker.dart`
- `modern_date_range_picker.dart`
- `stateful_text_field.dart`
- `toast_manager.dart`
- `toast_widgets.dart`
- `message_toast.dart`
- `connection_status_widget.dart`

需要逐步迁出或审计的文件：

- `confirm_dialogs.dart`

---

## 推荐执行顺序

按收益/风险比排序，推荐这样推进：

### 第一批：低风险、高收益

1. A1 新建优化方案文档
2. A2 更新旧总计划现状
3. B1 财务统计弹窗归位
4. B2 采购弹窗归位
5. B3 用户弹窗归位
6. B4 `confirm_dialogs.dart` 归属审计

### 第二批：继续做 UI 收口

1. C1 `appointments_screen.dart`
2. C2 `patients_screen.dart`
3. C3 `financial_management_screen.dart`
4. C4 `settings_dialogs.dart`

### 第三批：进入中风险逻辑收口

1. D1 `user_provider.dart`
2. D2 `database_provider.dart`
3. D3 `purchase_provider.dart`
4. D3 `patient_image_provider.dart`
5. D3 `financial_provider.dart`

### 第四批：数据访问层收口

1. E1 `user_data_source.dart`
2. E2 `patient_data_source.dart`
3. E3 `medical_record_data_source.dart`
4. E4 `purchase_data_source.dart`

## 每轮执行模板

后续实际执行时，每轮建议按下面模板推进。

### 模板

1. 选定一个模块和一个风险层级  
   例：采购模块 + 根级 Widget 归位

2. 列出本轮文件  
   例：
- `lib/widgets/purchase_record_dialog.dart`
- `lib/widgets/purchase_item_dialog.dart`
- `lib/features/purchases/screens/purchase_records_screen.dart`

当前判断：

- `app_card.dart`、`modern_date_picker.dart`、`modern_date_range_picker.dart`、`stateful_text_field.dart`、`toast_manager.dart`、`toast_widgets.dart`、`message_toast.dart`、`connection_status_widget.dart` 属于跨模块通用组件，保留根级合理
- `confirm_dialogs.dart` 已完成归属审计，属于跨模块共享确认框集合，继续保留根级
- `loading_dialog.dart`、`date_time_card.dart`、`reusable_date_range_picker.dart` 更像历史残留，后续优先审计归属

3. 明确本轮不做什么  
   例：
   - 不动 Provider
   - 不动 Data Source
   - 不做无关格式化

4. 拆分后执行验证  

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

5. 如果是初始化、登录、数据源切换相关改动，再补跑：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter run
```

6. 回写文档  
   至少更新：
   - 旧总计划中的最近记录
   - 本方案中的进度摘要（如后续需要）

## 完成定义

当满足下面条件时，可以认为 Android 端从“半模块化”进入“可维护模块化”：

### DOD-1

根级 `widgets/` 不再保留明显模块私有对话框。

### DOD-2

根级 `providers/` 中仅剩少量核心协调 Provider，且职责明确。

### DOD-3

`features/*` 内新增文件不再继续大面积反向依赖根级全局层。

### DOD-4

页面入口保留在 `screens/`，但页面内大段 UI 已拆入 feature widgets。

### DOD-5

主要 Data Source 的查询条件构造已经统一，不再到处复制 where / args 逻辑。

## 当前建议的下一步

如果按执行效率排序，下一步最合适的是：

1. 暂停继续拆分，进入验证与维护观察

原因很直接：

- 现有根级 `widgets/` 已经基本完成白名单化
- `DateTimeCard` 仍被 `appointment_form_sheet.dart` 直接使用，继续迁移收益偏低
- 剩余项大多是跨模块通用组件或低收益历史残留

## 验证命令

基础验证：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

涉及启动、登录、数据源切换、初始化链时追加：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter run
```

## 备注

- 本方案是 Android 端当前真实代码状态下的优化拆分方案，不是重新从零规划。
- 后续如果发现某个文件已经明显属于高风险链路，应先提醒切换到中智能再继续。
- 删除文件、目录、数据库 schema 变更、Git 回滚、发布部署仍然必须先经用户确认。

## 执行进度表

| 批次 | 日期 | 已执行内容 | 当前结果 | 下一次推荐执行 |
| --- | --- | --- | --- | --- |
| 第一批 | 2026-06-01 | A1、A2、B1、B2、B3、B4 | 4 个根级模块私有弹窗已归位到 feature 目录；`confirm_dialogs.dart` 已审计并保留根级 | `C1 appointments_screen.dart` |
| 第二批 | 2026-06-01 | C1 `appointments_screen.dart` | 预约页面头部、搜索筛选、日历/列表切换、空状态已下沉到 `appointments_screen_body.dart` | `C2 patients_screen.dart` |
| 第三批 | 2026-06-01 | C2 `patients_screen.dart` | 患者页面头部、搜索筛选、统计栏、列表/空态、加载更多已下沉到 `patients_screen_body.dart` | `C3 financial_management_screen.dart` |
| 第四批 | 2026-06-02 | C4 `settings_dialogs.dart` | 设置页通用确认、SQLite/MySQL 配置提示、备份/恢复/导出对话框已拆到 `settings_common_dialogs.dart`、`settings_backup_restore_dialogs.dart`，并复用 `sqlite_config_dialogs.dart` | `D1 user_provider.dart` |
| 第五批 | 2026-06-02 | D1 `user_provider.dart` | 用户列表缓存与权限缓存已委托给 `UserCacheService`，权限读取/更新/加载/刷新已委托给 `UserPermissionService` | `D2 database_provider.dart` |
| 第六批 | 2026-06-02 | D2 `database_provider.dart` | 数据库启动编排已抽到 `DatabaseBootstrapService`，Provider 仅保留状态协调和对外入口 | `D3 purchase_provider.dart` |
| 第七批 | 2026-06-02 | D3 `purchase_provider.dart` | 采购初始化编排已抽到 `PurchaseInitializationService`，Provider 仅保留 CRUD、统计入口和状态编排 | `D3 patient_image_provider.dart` |
| 第八批 | 2026-06-02 | D3 `patient_image_provider.dart` | 患者图片初始化编排已抽到 `PatientImageInitializationService`，Provider 仅保留图片/材料读取、缓存管理和连接处理 | `D3 financial_provider.dart` |
| 第九批 | 2026-06-02 | D3 `financial_provider.dart` | 财务初始化编排已抽到 `FinancialInitializationService`，Provider 仅保留财务记录 CRUD、统计入口、缓存入口和查询编排 | `D3 material_provider.dart` |
| 第十批 | 2026-06-02 | D3 `material_provider.dart` | 材料初始化编排已抽到 `MaterialInitializationService`，Provider 仅保留材料 CRUD、编码生成、统计入口、缓存和状态协调 | `D3 medical_record_provider.dart` |
| 第十一批 | 2026-06-02 | D3 `medical_record_provider.dart` | 病历初始化编排已抽到 `MedicalRecordInitializationService`，Provider 仅保留病历记录、项目、模板的查询与缓存编排 | `D3 patient_provider.dart` |
| 第十二批 | 2026-06-02 | D3 `patient_provider.dart` | 患者删除编排已抽到 `PatientDeletionService`，Provider 仅保留患者列表查询、增改、导出和缓存编排 | `D3 appointments_provider.dart` |
| 第十三批 | 2026-06-02 | D3 `appointments_provider.dart` | 预约初始化编排已抽到 `AppointmentInitializationService`，Provider 仅保留预约查询、增改、删除、缓存和权限过滤编排 | `D3 settings_provider.dart` |
| 第十四批 | 2026-06-02 | `settings_provider.dart` | `DatabaseSettingsManager` 已拆到 `features/settings/services/database_settings_manager.dart`，`settings_provider.dart` 仅保留应用偏好状态和 `SettingsManager` 编排 | `D3 user_provider.dart` |
| 第十五批 | 2026-06-02 | D3 `user_provider.dart` | 数据库初始化已抽到 `UserInitializationService`，登录/认证/登出/统计/角色修复已委托给现有 service，`user_provider.dart` 仅保留用户 CRUD、权限入口、缓存和状态协调 | `D3 user_validation_service.dart` |
| 第十六批 | 2026-06-02 | D3 `user_validation_service.dart` | 用户名和邮箱是否存在校验已接管到 `UserValidationService`，`user_provider.dart` 不再自己拼接存在性查询 | `D3 user_permission_service.dart` |
| 第十七批 | 2026-06-02 | D3 `user_permission_service.dart` | 用户权限判断和医生过滤条件已接管到 `UserPermissionService`，`user_provider.dart` 不再自己维护相关权限逻辑 | `D3 user_connection_service.dart` |
| 第十八批 | 2026-06-02 | D3 `user_connection_service.dart` | 用户连接状态、连接检查和连接重置已接管到 `UserConnectionService`，`user_provider.dart` 不再自己维护连接状态字段 | `D3 login_initialization_service.dart` |
| 第十九批 | 2026-06-02 | `login_initialization_service.dart` | 已拆分出独立的 `login_database_switch_service.dart`，`login_initialization_service.dart` 仅保留等待初始化完成的逻辑 | `D3 login_handler.dart` |
| 第二十批 | 2026-06-02 | `login_handler.dart` | 已确认保持为登录入口编排层，当前边界合理，未继续拆分 | `D3 login_credentials_service.dart` |
| 第二十一批 | 2026-06-02 | `login_credentials_service.dart` | 已审计为纯凭证读写工具，当前没有继续拆分的有效边界 | `D3 database_connection_service.dart` |
| 第二十二批 | 2026-06-02 | `database_connection_service.dart` | 已拆成 `MySQLConnectionRetryService` 和 `SQLiteDatabaseSwitchService`，门面仅保留兼容转发 | `D3 user_authentication_service.dart` |
| 第二十三批 | 2026-06-02 | `user_authentication_service.dart` | 已剥离登录/登出会话动作，认证与权限预加载边界更清晰 | `D3 user_permission_service.dart` |
| 第二十四批 | 2026-06-02 | `user_permission_service.dart` | 已进一步收口，当前用户包装逻辑拆到 `UserCurrentPermissionService` | `D3 user_data_repair_service.dart` |
| 第二十五批 | 2026-06-02 | `user_data_repair_service.dart` | 已拆出 `UserMySqlRoleRepairService` 和 `UserSqliteRoleRepairService`，主服务仅保留分发和刷新 | `D3 user_statistics_service.dart` |
| 第二十六批 | 2026-06-02 | `user_current_permission_service.dart` 刷新路径修复 | 当前用户权限刷新改为清缓存后重新预热，补上权限刷新闭环 | `D3 user_statistics_service.dart` |
| 第二十七批 | 2026-06-02 | `user_statistics_service.dart` | 已审计为最小统计边界，保留现状不再拆分 | `D3 user_connection_service.dart` |
| 第二十八批 | 2026-06-02 | `user_connection_service.dart`、`UserCacheService` | `user_connection_service.dart` 已拆成状态/健康两层，`UserCacheService` 已拆成用户列表缓存和权限缓存 | `D3 user_validation_service.dart` |
| 第二十九批 | 2026-06-02 | `user_validation_service.dart` | 已把存在性查询公共逻辑抽到 `UserExistenceQueryService`，校验服务只保留入口 | `D3 user_initialization_service.dart` |
| 第三十批 | 2026-06-02 | `user_validation_service.dart` 导入修复 | 已补回 `Database` 类型导入，保留兼容构造参数 | `D3 user_initialization_service.dart` |
| 第三十一批 | 2026-06-02 | `user_initialization_service.dart` | 已审计为最小初始化编排边界，保留现状不再拆分 | `D3 login_database_switch_service.dart` |
| 第三十二批 | 2026-06-02 | `login_database_switch_service.dart` | 已审计为最小监听边界，保留现状不再拆分 | `D3 user_existence_query_service.dart` |
| 第三十三批 | 2026-06-02 | `user_existence_query_service.dart` | 已审计为最小公共查询边界，保留现状不再拆分 | `D3 user_current_permission_service.dart` |
| 第三十四批 | 2026-06-02 | `user_current_permission_service.dart` | 已审计为最小当前用户权限包装边界，保留现状不再拆分 | `D1 user_provider.dart` |
| 第三十五批 | 2026-06-02 | `user_provider.dart` CRUD 收口 | 已抽出 `UserCrudService`，用户增删改查从 Provider 主体移出 | `D1 user_provider.dart` |
| 第三十六批 | 2026-06-02 | `database_provider.dart` 冗余清理 | 已清理重复的 MySQL 查询辅助实现，并将旧查询块注释封存 | `D2 database_provider.dart` |
| 第三十七批 | 2026-06-02 | `database_provider.dart` 内部死代码清理 | 已移除未使用的内部方法和导入，`database_provider.dart` 只保留实际使用的编排依赖 | `D2 database_provider.dart` |
| 第三十八批 | 2026-06-02 | `database_provider.dart` 终收口 | 已移除 `_activeDataSource`、`MySqlDataSource`、`SqliteDataSource` 等冗余层，文件收口到数据库编排入口 | `E1 user_data_source.dart` |
| 第三十九批 | 2026-06-02 | `user_data_source.dart` 拆分 | `user_data_source.dart` 已收口为接口文件，SQLite/MySQL 具体实现已下沉到独立文件 | `E2 patient_data_source.dart` |
| 第四十批 | 2026-06-02 | `mysql_user_data_source.dart` 报错修复 | 已修正 `affectedRows` 的空值判断，消除 MySQL 数据源编译错误 | `E2 patient_data_source.dart` |
| 第四十一批 | 2026-06-02 | `patient_data_source.dart` 报错修复 | 已修正 `insertId` 和 `affectedRows` 的空值判断，消除患者数据源编译错误 | `E2 patient_data_source.dart` |
| 第四十二批 | 2026-06-02 | `patient_data_source.dart` 拆分 | `patient_data_source.dart` 已收口为接口文件，患者 SQLite/MySQL 具体实现已分文件落地 | `E3 medical_record_data_source.dart` |
| 第四十三批 | 2026-06-02 | `medical_record_data_source.dart` 拆分 | `medical_record_data_source.dart` 已收口为接口文件，病历 SQLite/MySQL 具体实现已分文件落地 | `E4 purchase_data_source.dart` |
| 第四十四批 | 2026-06-02 | `medical_record_provider.dart` / `patient_provider.dart` 导入修复 | 已隐藏旧数据源实现名，消除接口与新实现的撞名冲突 | `E4 purchase_data_source.dart` |
| 第四十五批 | 2026-06-02 | `purchase_data_source.dart` 拆分 | `purchase_data_source.dart` 已收口为接口文件，采购 SQLite/MySQL 具体实现已分文件落地 | `F1 database_models.dart` |
| 第四十六批 | 2026-06-02 | `medical_record_data_source.dart` / `purchase_data_source.dart` 接口化加固 | 旧实现已包进注释块，避免与新实现撞名导致分析冲突 | `F1 database_models.dart` |
| 第四十七批 | 2026-06-02 | `purchase_initialization_service.dart` 导入修复 | 已改为只引用新拆出的采购数据源实现文件，消除初始化服务里的旧类名冲突 | `F1 database_models.dart` |
| 第四十八批 | 2026-06-02 | `database_models.dart` 审计 | 该文件是全局共享的模型与数据库壳，当前不建议继续硬拆 | `F2 其他共享模型/辅助文件` |
| 第四十九批 | 2026-06-02 | `database_utils.dart` / `sync_manager.dart` 审计 | 两个全局工具都是完整的跨层编排器，当前不建议继续拆分 | `F3 全局 widgets 白名单化` |
| 第五十批 | 2026-06-02 | `widgets/` 白名单审计 | 已确认一组跨模块通用组件保留根级，历史残留候选已标记待审计 | `F3 confirm_dialogs.dart` |
| 第五十一批 | 2026-06-02 | `material_dialog.dart` / `dental_chart_card.dart` / `dental_icons.dart` 删除确认 | 已由用户手动删除，且未发现外部引用 | `F3 confirm_dialogs.dart` |
| 第五十二批 | 2026-06-02 | `confirm_dialogs.dart` 归属审计 | 已确认其为跨模块共享确认框集合，继续保留根级 | `暂停继续拆分` |
| 第五十三批 | 2026-06-02 | 新增开发指南 | 新增 `docs/android_app_development_guide.md`，统一后续 Android 端目录、命名与职责约束 | `暂停继续拆分` |

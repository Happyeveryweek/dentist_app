# Windows 端后续拆分与优化计划

日期：2026-06-01

范围：`D:\Data\android_project\dentist_app\windows_app`

## 结论

Windows 端已经从“大文件 + 物理拆分”阶段进入“边界收口”阶段。

后续主线不再是继续机械拆文件，也不再以清理 `part` 为核心，而是按下面 4 条主线推进：

1. 先修真实功能风险：配置持久化与数据源配置闭环。
2. 再收 Provider 连接/同步/数据源选择边界。
3. 再处理几个仍然过重的业务组件和页面入口。
4. 最后做 Data Source 查询构造收口，降低 SQLite/MySQL 回归风险。

## 当前进度表

| 项目 | 状态 | 已完成内容 | 下一步 |
| --- | --- | --- | --- |
| P0 `SettingsProvider` 模块数据源配置闭环 | 已完成 | 已收紧 `settings_provider.dart` 的模块配置加载回填；`data_source_management_service.dart` 统一了模块数据源归一化和 MySQL 设置应用逻辑；`data_source_screen.dart` 的回填、同步和保存辅助路径也已收口 | 进入下一项 |
| P1 `FinancialProvider` 连接入口收口 | 已完成 | 连接获取、校验、重连、同步入口已收口到独立服务 | 暂不继续修改，按计划平移到下一个模块 |
| P1 `PurchaseProvider` 连接入口收口 | 已完成 | 连接获取、校验、重连、同步入口已收口到独立服务 | 暂不继续修改，按计划平移到下一个模块 |
| P1 `MaterialProvider` 连接入口收口 | 已完成 | 新增 `MaterialMysqlConnectionService`；`MaterialProvider` 的连接获取、测试、重连已委托出去 | 进入 P2，按计划处理 `database_provider.dart` |
| P1 `AppointmentProvider` 连接入口收口 | 已完成 | 新增 `AppointmentMysqlConnectionService`；`AppointmentProvider` 的连接获取、测试、重连已委托出去 | 进入 P2，按计划处理 `database_provider.dart` |
| P1 `UserProvider` 连接入口清理 | 已完成 | 清理了 `UserProvider` 内直接 MySQL 辅助方法；连接责任留在 `UserDataSourceInitializer` / `UserSyncService` | 进入 P2，优先处理 `database_provider.dart` |
| P2 `DatabaseProvider` 协调职责收口 | 已完成 | 已收紧 MySQL 设置归一化与连接参数复用，并补了连接状态同步，减少初始化/切换/备份中的重复协调逻辑 | 进入 P3 |
| P2 `MaterialInputWidget` 状态重建收口 | 已完成 | 已把数据库加载、合并初始化、普通初始化收成统一的内部重建入口，并收紧 `didUpdateWidget` / 更新通知路径；旧的合并包装方法已删除 | 进入下一个大文件 |
| P2 `FinancialManagementScreen` 页面数据流收口 | 已完成 | 已统一患者数据源解析、患者装饰、聚合映射和代表记录构造，并删除旧的内部过滤/分页冗余路径 | 进入 `patient_detail_screen.dart` |
| P2 `PatientDetailScreen` 页面刷新与操作收口 | 已完成 | 已把患者/预约/收费/病历的重复重新加载链路收成统一 helper，并减少各操作分支里的重复状态切换 | 进入 `materials_screen.dart` |
| P2 `MaterialsScreen` 页面筛选初始化收口 | 已完成 | 已统一筛选分页入口，并把初始化按钮接到真实初始化流程，同时清理了重复的分页状态构造 | 进入下一个大文件 |
| P3 `PatientDataSource` 患者查询构造收口 | 已完成 | `sqlite_patient_data_source.dart` 和 `mysql_patient_data_source.dart` 的患者检索、分页、ID 搜索和存在性检查已收口到统一条件构造器，并修正了 `OR` / `AND doctor` 的组合优先级 | 进入 P3 financial，先处理 `sqlite_financial_data_source.dart` |
| P3 `FinancialDataSource` 财务查询构造收口（SQLite） | 已完成 | `sqlite_financial_data_source.dart` 的财务记录、患者聚合、收费项统计/分页/详情查询已收口到统一条件构造器 | 下一步处理 `mysql_financial_data_source.dart` |
| P3 `PurchaseDataSource` 采购查询构造收口（SQLite） | 已完成 | `sqlite_purchase_data_source.dart` 的采购记录、搜索、日期范围、统计/分页查询已收口到统一条件构造器 | 下一步处理 `mysql_purchase_data_source.dart` |

## 当前现状判断

### 已有进展

- `part` 路线基本退出主舞台，当前代码已不再以 `part/part of` 作为主要拆分形态。
- `features/` 已经承接了患者、财务、病历、设置、用户等模块的大量组件与服务。
- `users_screen.dart` 这类 5 月底还明显过重的页面，已经拆薄到可接受范围。
- 患者模块仍然是当前最接近目标结构的参考模块。

### 仍然存在的核心问题

1. `SettingsProvider` 的模块数据源配置保存/恢复闭环不完整，模块化配置的可靠性不足。
2. `DatabaseProvider` 仍然是下一层需要处理的协调点。
3. 少数大型业务组件虽然已经迁入 `features/`，但仍是“UI + 状态 + 数据加载 + 图片/文件处理”混合体。
4. 主计划和 2026-05-29 审计文档里的部分结论已经过时，后续执行必须以当前代码实际结构为准。

## 后续目标

### 目标 1：先让配置和边界可靠

成功标准：

- 模块数据源配置可以正确保存、重启后正确恢复。
- `SettingsProvider` 不再保留“暂时跳过”的半成品路径。
- 数据源模式切换时，相关 Provider 的行为一致且可预测。

### 目标 2：把 Provider 压回状态外观层

成功标准：

- Provider 不再各自实现一套 MySQL 连接获取、校验、重连和同步连接逻辑。
- Provider 中数据库相关字段和 helper 数量明显下降。
- 新增模块能力时，优先落到 `features/<module>/services` 或统一协调器，而不是继续塞回 Provider。

### 目标 3：把最大耦合点拆成可维护单元

成功标准：

- 重点大文件从“一个文件里混四五层职责”变成“入口编排 + 若干独立职责文件”。
- 独立 Widget 只收参数和回调，不主动去 Provider 拉数据。
- 页面入口主要负责布局、状态绑定和对话框触发。

### 目标 4：降低 Data Source 回归风险

成功标准：

- 高风险查询不再在 count/page/list 多处重复拼条件。
- SQLite/MySQL 查询语义保持一致，后续修改不会只修一边漏另一边。

## 优先级路线

### P0：先修功能闭环

优先处理：

1. `windows_app/lib/providers/settings_provider.dart`
2. `windows_app/lib/features/settings/services/data_source_management_service.dart`
3. `windows_app/lib/screens/data_source_screen.dart`

任务：

- 补齐 `moduleDataSources` 的保存和恢复。
- 清理“暂时跳过”的配置读取逻辑。
- 复核数据源设置页与 Provider 同步链路是否仍有重复状态。

风险说明：

- 这是低范围、高价值修复。
- 不涉及 schema，不涉及 UI 重做，但直接影响模块化数据源方案是否真实可用。

### P1：统一 Provider 的连接与同步入口

优先处理模块：

1. `financial_provider.dart`
2. `purchase_provider.dart`
3. `material_provider.dart`
4. `appointment_provider.dart`
5. `user_provider.dart`

建议收口方向：

- 增加统一的连接解析/同步连接服务，例如：
  - `module_data_source_resolver.dart`
  - `mysql_runtime_connection_service.dart`
  - `sync_connection_resolver.dart`
- Provider 只保留：
  - 状态字段
  - 初始化入口
  - service 调用编排
  - `notifyListeners()`

当前已推进到：

1. `financial_provider.dart`：已完成
2. `purchase_provider.dart`：已完成
3. `material_provider.dart`：已完成
4. `appointment_provider.dart`：已完成
5. `user_provider.dart`：已完成直接辅助入口清理

不要再做的事：

- 不再在每个 Provider 中重复实现 `_currentMysqlConnection`。
- 不再让每个 Provider 自己决定何时 `initializeMySQL()`、何时降级、何时取同步连接。

### P2：处理最大的真实耦合文件

第一批目标：

1. `windows_app/lib/providers/database_provider.dart`
2. `windows_app/lib/features/patients/widgets/material_input_widget.dart`
3. `windows_app/lib/screens/financial_management_screen.dart`
4. `windows_app/lib/screens/patient_detail_screen.dart`
5. `windows_app/lib/screens/materials_screen.dart`

拆分原则：

- `DatabaseProvider` 先按协调职责继续下沉，不做对外 API 大改。
- `MaterialInputWidget` 先拆“数据加载”和“UI 行编辑/图片处理”边界，不一次性重写整套材料流程。
- 其他 screen 继续按完整职责簇拆，不按零碎按钮/标题拆。

### P3：Data Source 查询构造收口

优先模块：

1. patients
2. financial
3. purchases

建议动作：

- 在各自的 SQLite/MySQL Data Source 内提取共享查询片段生成方法。
- 让 count/list/page 共用同一组 where/args 生成逻辑。
- 对拼音搜索、首字母搜索、手机号搜索这类高风险查询优先处理。

## 推荐执行批次

### 批次 A：配置闭环批

1. 修 `SettingsProvider` 模块数据源配置保存/恢复。
2. 检查数据源设置页回填与加载逻辑。
3. 用户手动执行 `flutter analyze`。

预期收益：

- 先把“功能正确性”补齐。
- 后续 Provider 收口才有稳定基础。

### 批次 B：Provider 连接收口批

1. `material_provider.dart` 和 `appointment_provider.dart` 已完成验证，直接进入 P2。
2. 先处理 `database_provider.dart`。
3. 继续处理 `material_input_widget.dart`，再回到其他大页面入口。

预期收益：

- 后续连接、同步、降级问题只需要修一处。

### 批次 C：大组件收口批

1. 拆 `material_input_widget.dart`
2. 收口 `database_provider.dart`
3. 继续压薄 `financial_management_screen.dart`

预期收益：

- 直接消掉当前最难维护的几个点。

### 批次 D：查询风险降低批

1. 患者搜索查询收口
2. 财务分页/筛选查询收口
3. 采购分页/筛选查询收口

预期收益：

- 降低“改一次 SQL，漏一处实现”的回归概率。

## 不建议的路线

- 不建议再以“行数下降”为主要目标。
- 不建议为了形式统一，把已经拆出的文件再大规模回并。
- 不建议先碰 Android 端或根目录旧 Flutter 工程。
- 不建议在一轮里同时混 UI 拆分、Provider 收口、Data Source 收口。

## 后续验收标准

后续每一轮拆分或优化，至少满足下面一条：

1. 修掉一个真实功能风险闭环。
2. 去掉一组重复连接/同步逻辑。
3. 让一个大文件减少一层职责，而不是只减少行数。
4. 让一类高风险查询共用同一套构造逻辑。

## 建议的下一轮起点

当前这一轮已收尾，后续如果继续，就直接从新的大文件或新模块开始。

原因：

- `SettingsProvider`、`data_source_management_service.dart` 和 `data_source_screen.dart` 的闭环已经收完。
- `database_provider.dart` 已通过 analyze 验证。
- `material_input_widget.dart` 已通过 analyze 验证。
- `financial_management_screen.dart` 已通过 analyze 验证。
- `patient_detail_screen.dart` 已通过 analyze 验证。
- `materials_screen.dart` 已通过 analyze 验证。
- `PatientDataSource` 的患者查询构造已经收口完成，`sqlite_financial_data_source.dart`、`mysql_financial_data_source.dart`、`sqlite_purchase_data_source.dart`、`mysql_purchase_data_source.dart` 也已经收口完成，下一步回到配置闭环验证。
- `user_provider.dart` 的直接 MySQL 辅助入口已经清理，P1 连接边界基本收口完成。
- 下一层更值得处理的是 `DatabaseProvider` 这类协调点，而不是继续追着单个 Provider 加壳。

## 验证命令

```powershell
cd D:\Data\android_project\dentist_app\windows_app
flutter analyze
```

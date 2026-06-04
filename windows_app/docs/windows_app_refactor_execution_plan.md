# windows_app 渐进式拆分施工方案

## 0. 方案目标

本方案用于指导任意 AI 编码模型继续拆分 `D:\Data\android_project\dentist_app\windows_app`。

执行目标只有三个：

1. 降低患者模块、财务模块、预约模块、病历模块等大文件维护成本。
2. 让 UI、Provider、Service、Data Source 的职责边界清楚。
3. 保持现有功能、UI、入口、数据库 schema、用户操作路径不变。

本方案不是重写项目，不是迁移新架构，不是重做 UI。

## 1. 固定范围

只允许处理：

- `D:\Data\android_project\dentist_app\windows_app`
- `D:\Data\android_project\dentist_app\dentist_app_incremental_split_plan.md`
- `D:\Data\android_project\dentist_app\docs\split_history\`
- 本文件：`D:\Data\android_project\dentist_app\docs\windows_app_refactor_execution_plan.md`

默认不允许处理：

- 根目录旧 Flutter/安卓端代码：`D:\Data\android_project\dentist_app\lib`
- `D:\Data\android_project\dentist_app\android`
- `D:\Data\android_project\dentist_app\windows`
- `D:\Data\android_project\dentist_app\windows_app11`
- 任何数据库文件
- `.env`、密钥、CI/CD、发布配置

`windows_app11` 只作为只读参考源，不允许修改。

## 2. 当前状态判断

当前项目已经被外部工具做过一轮大范围拆分。

已经存在的主要拆分成果：

- 患者模块 UI 组件目录：
  - `windows_app\lib\features\patients\widgets\`
- 患者模块 Service 目录：
  - `windows_app\lib\features\patients\services\`
- 患者材料 DTO：
  - `windows_app\lib\models\patient_material_with_images.dart`
- 全模块 Data Source 物理拆分：
  - `windows_app\lib\data_sources\sqlite_*_data_source.dart`
  - `windows_app\lib\data_sources\mysql_*_data_source.dart`

当前已经修复过的问题：

- `PatientMaterialWithImages` 已从 Service 迁到 model。
- `PatientProvider` 已恢复财务页需要的 `effectiveDataSourceType` 兼容参数。
- 患者模块启动初始化竞态已补过显式初始化。
- 患者 Service 捕获旧 SQLite 连接的问题已改为动态 getter。
- 患者 SQLite -> MySQL 同步连接已恢复专用连接入口。

当前不能假设的问题：

- 不能假设所有页面运行时都正常。
- 不能假设所有删除文件都合理。
- 不能假设 Data Source 拆分行为和原代码完全等价。
- 不能假设患者模块已经拆分完成。

## 3. 当前结构问题

### 3.1 PatientProvider 仍承担过多职责

文件：

- `windows_app\lib\providers\patient_provider.dart`

当前问题：

- 负责数据源初始化。
- 负责 SQLite/MySQL 当前连接选择。
- 负责同步连接获取。
- 负责组装多个 Service。
- 负责兼容旧 UI API。
- 同时还维护患者刷新状态、缓存状态。

目标状态：

- `PatientProvider` 只保留：
  - 页面状态
  - 缓存状态
  - 刷新标记
  - 调用 Service
  - 向旧 UI 暴露兼容 API

暂不强制处理：

- 初始化逻辑可以先留在 `PatientProvider`，等患者模块运行稳定后再单独拆。

### 3.2 Service 里仍有过多数据访问细节

文件：

- `patient_core_service.dart`
- `patient_material_service.dart`
- `patient_search_service.dart`
- `patient_list_service.dart`

当前问题：

- Service 内仍包含 SQL。
- Service 内仍判断 SQLite/MySQL。
- Service 依赖 Provider 内部状态 getter。
- 部分逻辑只是从 Provider 搬到了 Service，没有真正下沉到 Data Source。

目标状态：

- Service 负责业务规则和流程组合。
- SQL、SQLite/MySQL 差异、连接细节进入 Data Source 或后续 Repository。

短期允许：

- 先保留 Service 内 SQL，只做运行稳定和 UI 文件收口。

不允许：

- 继续把新的 SQL 写进 screen/widget。
- 继续让 widget 直接判断 SQLite/MySQL。

### 3.3 患者 UI 仍有大文件

当前较大的文件：

- `windows_app\lib\screens\patient_detail_screen.dart`
- `windows_app\lib\screens\patient_form_dialog.dart`
- `windows_app\lib\screens\patients_screen.dart`
- `windows_app\lib\features\patients\widgets\patient_medical_record_detail_dialog.dart`
- `windows_app\lib\features\patients\widgets\patient_detail_financial_widgets.dart`
- `windows_app\lib\features\patients\widgets\patient_form_dental_section.dart`

目标状态：

- `patient_detail_screen.dart` 只负责：
  - 加载患者详情页所需数据
  - 调用 Provider
  - 打开对话框
  - 组合已拆出的详情页组件
- `patient_form_dialog.dart` 只负责：
  - 表单生命周期
  - 字段控制器
  - 保存流程
  - 组合表单 section
- widgets 不直接访问数据库。

### 3.4 Data Source 拆分还只是物理拆分

当前状态：

- 全局目录 `windows_app\lib\data_sources` 下已有 SQLite/MySQL 实现文件。

问题：

- 模块归属不够清晰。
- Data Source 文件仍在全局目录。
- 短期可以接受，因为继续移动目录会扩大 import 风险。

目标状态：

- 先保持当前目录不动。
- 等患者、财务、预约、病历 Provider 稳定后，再评估是否迁到各模块 `data` 目录。

## 4. 绝对禁止事项

任意模型执行时必须遵守：

- 不改数据库 schema。
- 不做数据迁移。
- 不删除文件，除非用户明确确认。
- 不做全项目格式化。
- 不修改 `.env`、密钥、token、CI/CD。
- 不发布、不部署。
- 不把 `windows_app11` 内容整文件覆盖到 `windows_app`。
- 不同时改 UI、Provider、Service、Data Source。
- 不为了解决报错注释掉功能代码。
- 不新增未要求的功能。
- 不改视觉样式，除非当前任务明确要求 UI 调整。

## 5. 每轮通用执行流程

每一轮都必须按以下顺序执行。

### 5.1 读上下文

必须先读：

1. `AGENTS.md`
2. `dentist_app_incremental_split_plan.md`
3. 本文件
4. 本轮涉及的源文件
5. 如需对照，读取 `windows_app11` 对应文件

### 5.2 定义本轮边界

每轮开工前必须明确写出：

- 本轮目标文件
- 本轮只处理哪一类问题
- 本轮不处理哪些相邻问题
- 成功标准

示例：

```text
本轮只拆 patient_form_dialog.dart 的牙齿状况表单 section。
不处理 Provider。
不处理 Data Source。
不处理财务、预约、病历。
成功标准：UI 行为不变，analyze 无 error，表单保存路径不变。
```

### 5.3 修改代码

规则：

- 只修改本轮声明的文件。
- 为新增文件命名使用英文 snake_case。
- 优先移动原逻辑，不重写原逻辑。
- 新组件参数必须显式传入，不让组件自己读数据库。
- 如果拆出 helper，helper 文件必须只服务当前职责组。

### 5.4 更新文档

每轮代码或文档改动后必须更新：

- `dentist_app_incremental_split_plan.md`

如果是较大一轮，还要追加或新建归档：

- `docs\split_history\*.md`

主计划只写当前摘要，不写流水账。

### 5.5 验证

Codex 不主动执行 Flutter 验证命令。

每轮结束必须给用户完整命令：

```powershell
cd D:\Data\android_project\dentist_app\windows_app
flutter analyze | Select-String "error -"
```

涉及运行时初始化、页面数据加载、Provider/Data Source 时，还要让用户执行：

```powershell
cd D:\Data\android_project\dentist_app\windows_app
flutter run -d windows
```

### 5.6 停止条件

出现以下情况必须停止继续拆分，只修错误：

- `flutter analyze` 出现 error。
- 登录后仪表盘数据异常。
- 患者列表为空但数据库有数据。
- 财务页分页有总数但列表为空。
- SQLite/MySQL 模块配置不生效。
- 用户反馈任何核心路径运行异常。

## 6. 后续施工总顺序

后续必须按以下顺序执行，不允许跳跃。

### P0：稳定性确认

目标：

- 确认当前代码恢复到可运行状态。

必须验证：

- 登录成功。
- 仪表盘患者总数正常。
- 患者管理列表有数据。
- 财务管理按患者显示有数据。
- 材料管理能加载。
- 采购管理能加载。
- 用户管理能加载。

用户执行：

```powershell
cd D:\Data\android_project\dentist_app\windows_app
flutter analyze | Select-String "error -"
flutter run -d windows
```

通过标准：

- analyze 无 error。
- 上述页面不出现空数据异常。
- 日志中患者模块初始化完成：

```text
PatientProvider.initializeFromDatabase: 完成，数据源类型: sqlite
```

如果 P0 未通过：

- 不进入任何拆分。
- 只修运行时错误。

### P1：确认历史删除文件

当前疑似删除文件：

- `windows_app\lib\screens\purchase_detail_screen.dart`
- `windows_app\lib\utils\thumbnail_manager.dart`
- `windows_app\lib\models\schemas\example_usage.dart`

执行方式：

1. 查当前项目是否还有引用。
2. 对照 `windows_app11` 判断文件职责。
3. 写出每个文件：
   - 是否仍有引用
   - 是否有入口
   - 删除是否影响功能
   - 建议保留还是确认删除
4. 等用户确认。

禁止：

- 未经用户确认直接删除。
- 未经用户确认恢复覆盖。

通过标准：

- 三个文件都有明确结论。
- 如需恢复，使用备份源最小恢复，不改其它文件。
- 如确认删除，更新主计划和归档。

### P2：患者 UI 收尾

目标：

- 继续收敛患者模块大 UI 文件。

优先顺序：

1. `patient_form_dialog.dart`
2. `patient_detail_screen.dart`
3. `patients_screen.dart`
4. `patient_medical_record_detail_dialog.dart`

每轮只拆一个职责组。

#### P2.1 patient_form_dialog 表单保存前校验区

目标文件：

- `windows_app\lib\screens\patient_form_dialog.dart`

允许新增：

- `windows_app\lib\features\patients\widgets\patient_form_save_validation.dart`

只允许移动：

- 保存前校验对话框 UI
- 重复病历号提示 UI
- 重复患者名提示 UI

不允许移动：

- 数据库检查逻辑
- `PatientProvider` 调用
- 保存患者逻辑

成功标准：

- 新增患者流程不变。
- 编辑患者流程不变。
- 重复病历号提示不变。
- analyze 无 error。

#### P2.2 patient_form_dialog 控制器和 DTO 整理

目标：

- 只整理表单内部状态对象，不改 UI。

允许新增：

- `windows_app\lib\features\patients\models\patient_form_state.dart`

不允许：

- 改保存逻辑。
- 改字段含义。
- 改数据库字段。

触发条件：

- 只有 P2.1 通过后才能做。

#### P2.3 patient_detail_screen 详情页数据加载拆分

目标文件：

- `patient_detail_screen.dart`

允许新增：

- `windows_app\lib\features\patients/services/patient_detail_loader_service.dart`

只允许迁移：

- 患者详情页需要的加载组合逻辑
- 预约、财务、病历、材料数据加载编排

不允许：

- 改 Provider 接口。
- 改 Data Source。
- 改 UI 结构。

成功标准：

- 打开患者详情页正常。
- 基本信息、预约、财务、病历、材料 Tab 数据正常。

#### P2.4 patient_detail_screen 弹窗打开流程收口

目标：

- 把详情页里打开病历详情、预约详情、财务详情等弹窗的重复流程拆成本地 helper。

允许新增：

- `windows_app\lib\features\patients\widgets\patient_detail_dialog_actions.dart`

不允许：

- 把数据库读取放进 widget。
- 改弹窗 UI。

#### P2.5 patients_screen 列表页状态收口

目标文件：

- `patients_screen.dart`

允许新增：

- `windows_app\lib\features\patients/services/patient_list_state_service.dart`，如果已有则复用。

只允许移动：

- 分页状态计算
- 排序状态计算
- 搜索条件组装

不允许：

- 改患者查询结果。
- 改 Provider 接口。

### P3：患者 Service/Data Source 边界收口

前置条件：

- P0 通过。
- P2 至少完成 `patient_form_dialog.dart` 和 `patient_detail_screen.dart` 的主要收口。
- analyze 无 error。

目标：

- 把 Service 中的 SQL 下沉到 Data Source。

禁止：

- 同时改 UI。
- 同时改其它模块。

#### P3.1 PatientListService SQL 下沉

目标文件：

- `patient_list_service.dart`
- `patient_data_source.dart`
- `sqlite_patient_data_source.dart`
- `mysql_patient_data_source.dart`

目标：

- `PatientListService.getPatientsByIds`
- `PatientListService.getPatientsByDoctor`

应变成：

- Service 调 `PatientDataSource`。
- SQLite/MySQL 查询分别在 Data Source 实现。

成功标准：

- 财务页按患者显示仍能批量查患者。
- 患者管理按医生过滤行为不变。

#### P3.2 PatientSearchService SQL 下沉

目标：

- 搜索患者 ID。
- 综合搜索患者。
- 拼音搜索。

要求：

- Data Source 接口明确搜索方法。
- SQLite/MySQL 实现各自处理差异。
- Service 只负责选择调用和权限参数。

成功标准：

- 患者管理搜索正常。
- 财务页按患者名搜索正常。

#### P3.3 PatientMaterialService SQL 下沉

目标：

- 患者材料 CRUD。
- 材料图片 CRUD。
- 缩略图加载。

要求：

- `PatientMaterialService` 不直接拼 SQL。
- `PatientDataSource` 或后续专门 Material Data Source 负责查询。

注意：

- 这一轮风险较高，必须单独执行。
- 必须重点验证材料图片、缩略图、编辑、删除。

### P4：财务模块收口

前置条件：

- P0 通过。
- 患者模块批量查询患者稳定。

目标文件：

- `financial_provider.dart`
- `financial_management_screen.dart`
- `financial_data_source.dart`
- `sqlite_financial_data_source.dart`
- `mysql_financial_data_source.dart`

先做 UI，后做 Provider/Data Source。

#### P4.1 财务页 UI 状态组件整理

只允许处理：

- 搜索栏
- 筛选栏
- 分页栏
- 空状态
- 加载状态

不允许：

- 改财务查询。
- 改患者关联。

#### P4.2 财务 Provider 查询编排整理

目标：

- `FinancialProvider` 保留状态和流程。
- 统计、按患者聚合、按记录查询进入 Service。

不允许：

- 改 SQL。
- 改 Data Source。

#### P4.3 财务 Data Source 边界整理

目标：

- 财务 SQL 全部进入 SQLite/MySQL Data Source。
- Provider/Service 不直接拼 SQL。

验证重点：

- 财务列表。
- 按患者显示。
- 按记录显示。
- 搜索患者名。
- 分页总数。

### P5：预约模块 Provider 瘦身

前置条件：

- P0 通过。
- 患者模块稳定。

目标文件：

- `appointment_provider.dart`

允许新增：

- `features/appointments/services/appointment_service.dart`

第一轮只迁移：

- 状态文本转换
- 预约过滤条件组装
- 预约排序规则

不允许：

- 改预约 Data Source。
- 改患者关联。

第二轮再处理：

- 新增/编辑预约流程。
- 预约状态变更流程。

验证重点：

- 预约列表。
- 新增预约。
- 编辑预约。
- 状态变更。
- 患者详情页预约 Tab。

### P6：病历模块 Provider 瘦身

前置条件：

- P0 通过。
- 患者详情页病历 Tab 正常。

目标文件：

- `medical_record_provider.dart`

第一轮只迁移：

- 模板加载判断。
- 病历列表排序。
- 病历摘要格式化。

第二轮再迁移：

- 病历新增/编辑流程。
- PDF 导出流程。

禁止：

- 同轮改 PDF 导出和 Data Source。

验证重点：

- 病历列表。
- 新增病历。
- 编辑病历。
- 病历详情弹窗。
- PDF 导出。

### P7：Data Source 目录归属评估

前置条件：

- 患者、财务、预约、病历运行稳定。
- 连续两轮无 analyze error。

目标：

- 判断是否把全局 `data_sources` 文件迁到各 feature 的 `data` 目录。

默认建议：

- 暂不迁移。

只有满足以下条件才允许迁移：

- import 边界已经清晰。
- Provider/Service 不再直接依赖具体 SQLite/MySQL 类。
- 每个模块 Data Source 只被本模块引用。

如果迁移：

- 每轮只迁一个模块。
- 不改 SQL。
- 不改接口行为。

## 7. 文件职责标准

### 7.1 Screen

允许：

- 页面生命周期。
- 调用 Provider。
- 打开弹窗。
- 组合 widget。
- 处理按钮事件。

不允许：

- SQL。
- SQLite/MySQL 判断。
- 图片压缩细节。
- 大段业务校验。

### 7.2 Widget

允许：

- 展示 UI。
- 接收参数。
- 回调用户操作。
- 局部动画或 hover 状态。

不允许：

- 直接访问数据库。
- 直接读取 `DatabaseProvider`。
- 直接拼 SQL。
- 直接判断 SQLite/MySQL。

例外：

- 弹窗组件可以使用 `BuildContext` 打开子弹窗。
- 但不能在 widget 中新增数据库访问。

### 7.3 Provider

允许：

- 保存页面状态。
- loading/error 状态。
- 缓存。
- 调 Service。
- notifyListeners。

不允许：

- 大段 SQL。
- 大段业务规则。
- 图片二进制处理。
- 大段导入导出逻辑。

### 7.4 Service

允许：

- 业务流程。
- 参数校验。
- 默认值生成。
- 多个 Data Source 调用组合。
- 统计口径。

不允许：

- Flutter Widget。
- BuildContext。
- showDialog。
- ScaffoldMessenger。
- Navigator。

短期过渡允许：

- 旧 SQL 暂时留在患者 Service，但只能减少，不能新增。

### 7.5 Data Source

允许：

- SQL。
- SQLite/MySQL 差异。
- Row/Map 转换。
- 查询条件转换。

不允许：

- UI 文案。
- 弹窗。
- 页面状态。
- notifyListeners。

## 8. 命名规则

文件命名：

- 英文 snake_case。

类命名：

- UpperCamelCase。

患者模块 UI：

- `patient_<area>_<role>.dart`

示例：

- `patient_detail_dialog_actions.dart`
- `patient_form_save_validation.dart`
- `patient_detail_loader_service.dart`

Service：

- `<module>_<responsibility>_service.dart`

Data Source：

- `sqlite_<module>_data_source.dart`
- `mysql_<module>_data_source.dart`
- `<module>_data_source.dart`

## 9. 每轮交付格式

每个模型完成一轮后，最终回复必须包含：

1. 修改了哪些文件。
2. 每个文件承担什么职责。
3. 没有处理哪些相邻问题。
4. 需要用户执行的验证命令。
5. 运行时验证重点。
6. 是否更新了主计划和归档。

示例：

```text
本轮只拆 patient_form_dialog 的保存前校验 UI。
修改文件：
- ...
未处理：
- Provider 初始化
- Data Source
验证命令：
...
运行重点：
- 新增患者
- 编辑患者
```

## 10. 当前最优下一步

当前不应该继续拆预约/病历 Provider。

下一步固定为：

1. 用户确认 P0 稳定性。
2. 审核三个删除文件。
3. 从 `patient_form_dialog.dart` 的保存前校验 UI 开始做 P2.1。

不得跳过 P0。

## 11. P0 稳定性检查清单

用户运行：

```powershell
cd D:\Data\android_project\dentist_app\windows_app
flutter analyze | Select-String "error -"
flutter run -d windows
```

用户手动检查：

- 登录成功。
- 仪表盘患者总数不是异常 0。
- 患者管理列表有数据。
- 财务管理按患者显示有数据。
- 预约管理能打开。
- 材料管理能打开。
- 采购管理能打开。
- 病历管理能打开。
- 用户管理能打开。

关键日志：

```text
PatientProvider.initializeFromDatabase: 完成，数据源类型: sqlite
FinancialProvider初始化完成，数据源类型: mysql
PurchaseProvider初始化完成，数据源类型: mysql
MaterialProvider: MySQL数据源初始化完成
```

如果任何一项失败：

- 停止拆分。
- 只修失败项。

## 12. 删除文件审核清单

对每个疑似删除文件执行以下步骤：

1. 搜索引用。
2. 对照 `windows_app11` 读取原文件职责。
3. 判断是否有替代实现。
4. 判断是否有页面入口。
5. 给出建议：恢复、保留删除、等待确认。

要审核的文件：

- `windows_app\lib\screens\purchase_detail_screen.dart`
- `windows_app\lib\utils\thumbnail_manager.dart`
- `windows_app\lib\models\schemas\example_usage.dart`

结论模板：

```text
文件：
引用：
原职责：
当前替代：
风险：
建议：
需要用户确认：
```

## 13. 质量门槛

一轮拆分合格必须同时满足：

- analyze 无 error。
- 本轮目标路径人工验证通过。
- 没有新增无关功能。
- 没有删除未经确认文件。
- 没有改数据库 schema。
- 没有把 SQL 新增到 UI。
- 没有让 widget 直接依赖 DatabaseProvider。
- 主计划已更新。

不合格时：

- 不继续下一轮。
- 先修到合格。

## 14. 当前成果评价

当前成果不是废弃状态，可以继续在其上施工。

可保留：

- 患者 widgets 目录。
- 患者 services 目录。
- `PatientMaterialWithImages` model。
- 当前 Data Source 物理拆分文件。

需要收口：

- `PatientProvider` 初始化和 facade 职责。
- Service 里的 SQL。
- 大型患者 UI 文件。
- 删除文件的确认。

不建议回滚：

- 不建议整体回滚外部工具拆分成果。
- 当前更合理的路径是在现有成果上按本方案收口。

## 15. 刚性施工路线图

从本节开始是后续拆分的唯一执行路线。任意模型继续工作时，必须从最靠前且未完成的任务开始，不允许自己选择顺序。

执行顺序固定为：

1. R0：稳定性与删除文件审核。
2. R1：患者模块 UI 收尾。
3. R2：财务模块 UI 拆分。
4. R3：材料模块 UI 拆分。
5. R4：采购模块 UI 拆分。
6. R5：预约模块 UI 拆分。
7. R6：病历模块 UI 拆分。
8. R7：用户模块 UI 拆分。
9. R8：设置和数据源页面 UI 拆分。
10. R9：Provider 瘦身。
11. R10：Service/Data Source 边界收口。

强制规则：

- R1 到 R8 只做 UI 拆分，不改 Provider 逻辑，不改 Service 逻辑，不改 Data Source。
- R9 只做 Provider 瘦身，不改 UI，不改 Data Source。
- R10 只做 Service/Data Source 边界，不改 UI。
- 任意一轮出现 analyze error 或运行时核心页面异常，立刻停止路线图，只修错误。
- 每个编号任务完成后必须更新主计划；较大任务必须更新归档。

## 16. R0 稳定性与删除文件审核

### R0.1 当前代码稳定性确认

本轮不改代码。

用户执行：

```powershell
cd D:\Data\android_project\dentist_app\windows_app
flutter analyze | Select-String "error -"
flutter run -d windows
```

必须人工确认：

- 登录成功。
- 仪表盘总患者数不是异常 0。
- 患者管理列表有数据。
- 财务管理列表有数据。
- 预约管理能打开并显示已有数据或正常空态。
- 材料管理能打开。
- 采购管理能打开。
- 病历管理能打开。
- 用户管理能打开。

通过后才能进入 R0.2。

### R0.2 删除文件审核

本轮只读代码，不删除文件。

必须审核：

- `windows_app\lib\screens\purchase_detail_screen.dart`
- `windows_app\lib\utils\thumbnail_manager.dart`
- `windows_app\lib\models\schemas\example_usage.dart`

每个文件按固定步骤执行：

1. 在 `windows_app\lib` 搜索文件名、类名、主要函数名。
2. 在 `windows_app11` 读取同路径原文件。
3. 判断当前是否有替代实现。
4. 判断是否有页面入口或运行时调用。
5. 给出结论：建议恢复、建议保留删除、无法判断。

禁止：

- 不得直接删除。
- 不得直接从 `windows_app11` 覆盖恢复。

交付模板：

```text
文件：
当前是否存在：
当前引用：
备份源职责：
当前替代实现：
风险：
建议：
是否需要用户确认：
```

## 17. R1 患者模块 UI 收尾

患者模块已有一批 UI 文件，但没有彻底完成。R1 只处理患者 UI，不处理患者 Provider 和 Data Source。

### R1.1 `patient_form_dialog.dart` 保存前校验 UI

目标文件：

- 读取：`windows_app\lib\screens\patient_form_dialog.dart`
- 允许新增：`windows_app\lib\features\patients\widgets\patient_form_save_validation.dart`
- 允许修改：`patient_form_dialog.dart`

只迁移：

- 保存前确认对话框 UI。
- 重复病历号提示 UI。
- 重复姓名提示 UI。
- 必填项错误提示 UI。

不得迁移：

- 保存患者的业务流程。
- `PatientProvider` 调用。
- 数据库重复检查。
- 表单字段控制器。

施工步骤：

1. 在 `patient_form_dialog.dart` 搜索 `showDialog`、`duplicate`、`medicalRecordNumber`、`confirm`、`validate`。
2. 找到只负责展示提示的 Widget 或 builder。
3. 新建 `PatientFormSaveValidation` 或同等职责类。
4. 把原 UI 代码原样移动到新文件。
5. 所有动态数据通过构造参数传入。
6. 回调命名只允许使用 `onConfirm`、`onCancel`、`onEdit`。
7. 在原文件中保留业务判断，只把展示部分替换成新组件调用。

验收：

- 新增患者时保存前提示不变。
- 编辑患者时保存前提示不变。
- 重复病历号提示不变。
- 重复姓名提示不变。

### R1.2 `patient_form_dialog.dart` 图片和材料输入区域

前置条件：R1.1 通过。

目标文件：

- 读取：`patient_form_dialog.dart`
- 读取：`windows_app\lib\widgets\material_input_widget.dart`
- 读取：`windows_app\lib\widgets\patient_materials_manager.dart`
- 允许新增：`windows_app\lib\features\patients\widgets\patient_form_material_section.dart`

只迁移：

- 表单内患者材料输入区域的 UI 组合。
- 图片上传按钮区域。
- 材料列表入口区域。

不得迁移：

- 图片压缩逻辑。
- 材料保存逻辑。
- `PatientMaterialWithImages` 的 model 定义。
- `PatientProvider` 方法。

施工步骤：

1. 找到 `patient_form_dialog.dart` 中使用 `MaterialInputWidget`、`PatientMaterialsManager`、`PatientMaterialWithImages` 的 UI 区域。
2. 新建 `PatientFormMaterialSection`。
3. 构造参数必须显式包含：当前材料列表、材料变更回调、图片变更回调、是否编辑模式。
4. 原文件只保留状态和保存流程。
5. 禁止让新组件读取 Provider。

验收：

- 新增患者时可添加材料。
- 编辑患者时原材料显示正常。
- 图片缩略图显示正常。

### R1.3 `patient_form_dialog.dart` 底部操作区

前置条件：R1.2 通过。

允许新增：

- `windows_app\lib\features\patients\widgets\patient_form_footer_actions.dart`

只迁移：

- 保存按钮。
- 取消按钮。
- loading 状态按钮。
- 删除按钮，如果当前弹窗有删除入口。

不得迁移：

- 保存方法。
- 删除方法。
- 表单校验方法。

验收：

- 保存、取消、loading、删除按钮行为不变。

### R1.4 `patient_detail_screen.dart` 数据区 UI 组合

目标文件：

- `windows_app\lib\screens\patient_detail_screen.dart`
- 已有患者详情 widgets 目录。

允许新增：

- `windows_app\lib\features\patients\widgets\patient_detail_content.dart`

只迁移：

- 详情页主体 `TabBarView` 或各 Tab 的组合区域。
- loading、error、empty 的页面级 UI。

不得迁移：

- 数据加载方法。
- Provider 调用。
- 弹窗打开流程。

验收：

- 患者详情页各 Tab 展示不变。

### R1.5 `patient_detail_screen.dart` 弹窗动作区

允许新增：

- `windows_app\lib\features\patients\widgets\patient_detail_dialog_actions.dart`

只迁移：

- 打开病历详情弹窗的按钮或回调包装。
- 打开财务详情弹窗的按钮或回调包装。
- 打开预约详情弹窗的按钮或回调包装。

不得迁移：

- 弹窗内部 UI。
- 数据加载。
- Provider 方法。

验收：

- 从患者详情页打开病历、财务、预约相关弹窗正常。

### R1.6 `patients_screen.dart` 顶层布局收尾

目标文件：

- `windows_app\lib\screens\patients_screen.dart`
- 已有 `features\patients\widgets\patient_screen_*` 文件。

只迁移：

- 页面顶部标题区。
- 搜索和筛选区组合。
- 列表和分页组合。
- 空状态组合。

不得迁移：

- 搜索条件生成。
- 分页数据查询。
- Provider 调用。

验收：

- 患者列表、搜索、排序、分页行为不变。

## 18. R2 财务模块 UI 拆分

财务模块当前最大文件是 `windows_app\lib\screens\financial_management_screen.dart`，必须先拆 UI，再处理 Provider。

目标目录：

- 新建目录：`windows_app\lib\features\financial\widgets\`

禁止：

- 不改 `financial_provider.dart`。
- 不改 `financial_data_source.dart`、`sqlite_financial_data_source.dart`、`mysql_financial_data_source.dart`。
- 不改财务 SQL。
- 不改患者查询兼容参数。

### R2.1 财务页面框架拆分

目标文件：

- `financial_management_screen.dart`

允许新增：

- `features\financial\widgets\financial_screen_scaffold.dart`
- `features\financial\widgets\financial_header_actions.dart`

只迁移：

- 页面标题。
- 顶部右侧切换按钮。
- 新增财务按钮。
- 导出或统计入口按钮。

不得迁移：

- 查询逻辑。
- 当前 tab 状态。
- Provider 调用。

验收：

- 财务管理页面顶部视觉和按钮行为不变。

### R2.2 财务搜索与筛选栏

允许新增：

- `features\financial\widgets\financial_search_filter_bar.dart`
- `features\financial\widgets\financial_date_filter_button.dart`

只迁移：

- 搜索框 UI。
- 排序按钮 UI。
- 时间筛选 UI。
- 筛选 chip 或菜单 UI。

不得迁移：

- 实际搜索方法。
- 日期范围计算。
- Provider 查询。

参数必须包含：

- `searchController`
- `selectedDateRange`
- `onSearchChanged`
- `onDateRangeChanged`
- `onClearFilters`

验收：

- 搜索、清空、时间筛选按钮行为不变。

### R2.3 财务按患者显示列表

允许新增：

- `features\financial\widgets\financial_patient_group_list.dart`
- `features\financial\widgets\financial_patient_group_item.dart`

只迁移：

- 按患者显示模式的列表 UI。
- 每个患者聚合项 UI。
- 展开/收起 UI。
- 患者汇总金额展示 UI。

不得迁移：

- `getPatientAggregatesPage`。
- 患者 ID 批量查询。
- 财务分页查询。

验收：

- 按患者显示列表不再出现“总数有但列表空”的回归。
- 展开患者记录行为不变。

### R2.4 财务按记录显示列表

允许新增：

- `features\financial\widgets\financial_record_list.dart`
- `features\financial\widgets\financial_record_item.dart`

只迁移：

- 单条财务记录卡片或表格行。
- 金额、状态、日期、患者姓名展示。
- 操作按钮 UI。

不得迁移：

- 编辑、删除、收款逻辑。
- Provider 调用。

验收：

- 按记录显示模式行为不变。

### R2.5 财务分页、空态、加载态

允许新增：

- `features\financial\widgets\financial_pagination.dart`
- `features\financial\widgets\financial_empty_state.dart`
- `features\financial\widgets\financial_loading_state.dart`

只迁移：

- 分页 UI。
- 空状态 UI。
- 加载中 UI。
- 错误提示 UI。

不得迁移：

- 页码计算。
- 分页查询。

验收：

- 页码、总数、上一页、下一页行为不变。

### R2.6 财务表单弹窗 UI 拆分

目标文件：

- `windows_app\lib\screens\financial_form_dialog.dart`

允许新增目录：

- `windows_app\lib\features\financial\widgets\form\`

固定拆分顺序：

1. `financial_form_basic_section.dart`：患者选择、日期、类型、状态。
2. `financial_form_amount_section.dart`：金额、折扣、已付、欠款展示。
3. `financial_form_items_section.dart`：项目明细列表、添加项目、删除项目。
4. `financial_form_footer_actions.dart`：保存、取消、loading。

每轮只新增一个 section 文件。

不得迁移：

- 保存逻辑。
- 金额计算逻辑，除非只是展示公式结果。
- Provider 调用。

验收：

- 新增财务记录正常。
- 编辑财务记录正常。
- 项目明细增删正常。
- 金额显示不变。

### R2.7 财务详情页和统计弹窗

目标文件：

- `financial_detail_screen.dart`
- `financial_statistics_dialog.dart`

允许新增：

- `features\financial\widgets\financial_detail_content.dart`
- `features\financial\widgets\financial_statistics_content.dart`

只迁移：

- 详情展示 UI。
- 统计展示 UI。

不得迁移：

- 统计数据计算。
- 删除、编辑、收款逻辑。

## 19. R3 材料模块 UI 拆分

目标文件：

- `windows_app\lib\screens\materials_screen.dart`
- `windows_app\lib\widgets\material_input_widget.dart`
- `windows_app\lib\widgets\material_detail_manager.dart`
- `windows_app\lib\widgets\single_material_editor.dart`
- `windows_app\lib\widgets\patient_materials_manager.dart`

目标目录：

- `windows_app\lib\features\materials\widgets\`

禁止：

- 不改 `material_provider.dart`。
- 不改材料 Data Source。
- 不改图片压缩和存储逻辑。
- 不改 `PatientMaterialWithImages`。

### R3.1 材料管理页面框架

允许新增：

- `features\materials\widgets\materials_screen_scaffold.dart`
- `features\materials\widgets\materials_header_actions.dart`

只迁移：

- 页面标题。
- 新增材料按钮。
- 搜索入口。
- 导入导出入口，如果页面已有。

### R3.2 材料列表和材料卡片

允许新增：

- `features\materials\widgets\material_list_view.dart`
- `features\materials\widgets\material_list_item.dart`

只迁移：

- 材料列表 UI。
- 单个材料展示 UI。
- 库存颜色提示 UI。
- 操作按钮 UI。

不得迁移：

- 库存计算。
- 新增、编辑、删除方法。

### R3.3 材料详情管理器拆分

目标文件：

- `material_detail_manager.dart`

允许新增：

- `features\materials\widgets\material_detail_header.dart`
- `features\materials\widgets\material_detail_image_grid.dart`
- `features\materials\widgets\material_detail_usage_list.dart`

每轮只拆一个文件。

不得迁移：

- 图片实际保存。
- 图片删除逻辑。
- 数据库调用。

### R3.4 材料输入控件拆分

目标文件：

- `material_input_widget.dart`

固定拆分顺序：

1. `material_input_search_bar.dart`
2. `material_input_selected_list.dart`
3. `material_input_image_area.dart`
4. `material_input_footer_actions.dart`

不得迁移：

- 患者材料保存逻辑。
- 图片压缩逻辑。

验收：

- 患者表单内材料输入正常。
- 材料图片正常显示。

## 20. R4 采购模块 UI 拆分

目标文件：

- `windows_app\lib\screens\purchase_records_screen.dart`
- `windows_app\lib\screens\purchase_statistics_dialog.dart`
- `windows_app\lib\widgets\purchase_export_dialog.dart`

目标目录：

- `windows_app\lib\features\purchase\widgets\`

禁止：

- 不改 `purchase_provider.dart`。
- 不改采购 Data Source。
- 不改 MySQL/SQLite 配置。

### R4.1 采购页面框架和筛选栏

允许新增：

- `features\purchase\widgets\purchase_screen_scaffold.dart`
- `features\purchase\widgets\purchase_search_filter_bar.dart`

只迁移：

- 页面标题。
- 搜索框。
- 时间筛选。
- 供应商筛选。
- 新增采购按钮。

### R4.2 采购记录列表

允许新增：

- `features\purchase\widgets\purchase_record_list.dart`
- `features\purchase\widgets\purchase_record_item.dart`

只迁移：

- 采购记录列表 UI。
- 采购记录行或卡片 UI。
- 金额、供应商、日期、状态展示。

不得迁移：

- 采购查询。
- 编辑、删除、付款逻辑。

### R4.3 采购记录明细区域

允许新增：

- `features\purchase\widgets\purchase_record_detail_panel.dart`
- `features\purchase\widgets\purchase_item_list.dart`

只迁移：

- 明细展示 UI。
- 采购项目列表 UI。

### R4.4 采购统计和导出弹窗

允许新增：

- `features\purchase\widgets\purchase_statistics_content.dart`
- `features\purchase\widgets\purchase_export_content.dart`

只迁移：

- 统计展示 UI。
- 导出选项 UI。

不得迁移：

- 统计计算。
- 导出文件生成。

## 21. R5 预约模块 UI 拆分

目标文件：

- `windows_app\lib\screens\appointments_screen.dart`
- `windows_app\lib\screens\appointment_form_dialog.dart`
- `windows_app\lib\screens\appointment_details_screen.dart`

目标目录：

- `windows_app\lib\features\appointments\widgets\`

禁止：

- 不改 `appointment_provider.dart`。
- 不改预约 Data Source。
- 不改患者 Provider 调用。

### R5.1 预约列表页框架

允许新增：

- `features\appointments\widgets\appointments_screen_scaffold.dart`
- `features\appointments\widgets\appointment_calendar_header.dart`

只迁移：

- 页面标题。
- 日期切换 UI。
- 新增预约按钮。
- 视图模式切换按钮。

### R5.2 预约列表和预约卡片

允许新增：

- `features\appointments\widgets\appointment_list_view.dart`
- `features\appointments\widgets\appointment_list_item.dart`
- `features\appointments\widgets\appointment_empty_state.dart`

只迁移：

- 预约列表 UI。
- 单个预约展示 UI。
- 状态颜色 UI。
- 空状态 UI。

不得迁移：

- 预约查询。
- 状态更新。
- Provider 调用。

### R5.3 预约表单弹窗

目标文件：

- `appointment_form_dialog.dart`

允许新增：

- `features\appointments\widgets\appointment_form_patient_section.dart`
- `features\appointments\widgets\appointment_form_time_section.dart`
- `features\appointments\widgets\appointment_form_detail_section.dart`
- `features\appointments\widgets\appointment_form_footer_actions.dart`

每轮只拆一个 section。

不得迁移：

- 保存预约。
- 患者搜索。
- 时间冲突检查。

### R5.4 预约详情页

目标文件：

- `appointment_details_screen.dart`

允许新增：

- `features\appointments\widgets\appointment_detail_content.dart`
- `features\appointments\widgets\appointment_detail_actions.dart`

只迁移：

- 详情展示 UI。
- 操作按钮 UI。

不得迁移：

- 状态流转。
- 编辑、取消、完成逻辑。

## 22. R6 病历模块 UI 拆分

目标文件：

- `windows_app\lib\screens\medical_management_screen.dart`
- `windows_app\lib\screens\medical_record_form_dialog.dart`
- `windows_app\lib\screens\medical_template_management_screen.dart`
- `windows_app\lib\widgets\medical_template_edit_dialog.dart`
- `windows_app\lib\features\patients\widgets\patient_medical_record_detail_dialog.dart`

目标目录：

- `windows_app\lib\features\medical_records\widgets\`

禁止：

- 不改 `medical_record_provider.dart`。
- 不改 PDF 导出。
- 不改病历模板初始化。
- 不改数据库 schema。

### R6.1 病历管理列表页

允许新增：

- `features\medical_records\widgets\medical_screen_scaffold.dart`
- `features\medical_records\widgets\medical_record_search_filter_bar.dart`
- `features\medical_records\widgets\medical_record_list.dart`
- `features\medical_records\widgets\medical_record_list_item.dart`

每轮只拆一个职责组：

1. 页面标题和操作按钮。
2. 搜索筛选栏。
3. 列表容器。
4. 单条病历卡片。

不得迁移：

- 病历查询。
- 模板加载。
- Provider 调用。

### R6.2 病历表单弹窗

目标文件：

- `medical_record_form_dialog.dart`

允许新增：

- `features\medical_records\widgets\medical_record_form_patient_section.dart`
- `features\medical_records\widgets\medical_record_form_diagnosis_section.dart`
- `features\medical_records\widgets\medical_record_form_treatment_section.dart`
- `features\medical_records\widgets\medical_record_form_notes_section.dart`
- `features\medical_records\widgets\medical_record_form_footer_actions.dart`

每轮只拆一个 section。

不得迁移：

- 保存病历。
- 模板应用逻辑。
- PDF 导出。

### R6.3 病历详情弹窗

目标文件：

- `patient_medical_record_detail_dialog.dart`

允许新增：

- `features\medical_records\widgets\medical_record_detail_header.dart`
- `features\medical_records\widgets\medical_record_detail_body.dart`
- `features\medical_records\widgets\medical_record_detail_actions.dart`

不得迁移：

- PDF 导出。
- 编辑、删除逻辑。

### R6.4 模板管理 UI

目标文件：

- `medical_template_management_screen.dart`
- `medical_template_edit_dialog.dart`

允许新增：

- `features\medical_records\widgets\medical_template_list.dart`
- `features\medical_records\widgets\medical_template_list_item.dart`
- `features\medical_records\widgets\medical_template_form_section.dart`

不得迁移：

- 模板保存。
- 模板初始化。

## 23. R7 用户模块 UI 拆分

目标文件：

- `windows_app\lib\screens\users_screen.dart`

目标目录：

- `windows_app\lib\features\users\widgets\`

禁止：

- 不改 `user_provider.dart`。
- 不改登录逻辑。
- 不改权限规则。

固定拆分顺序：

1. `users_screen_scaffold.dart`：页面标题、顶部按钮。
2. `user_search_filter_bar.dart`：搜索、角色筛选。
3. `user_list_view.dart`：用户列表容器。
4. `user_list_item.dart`：单个用户卡片或行。
5. `user_form_dialog_content.dart`：新增/编辑用户弹窗内容。

不得迁移：

- 用户保存。
- 密码处理。
- 权限判断。

验收：

- 用户列表正常。
- 新增用户正常。
- 编辑用户正常。
- 权限显示不变。

## 24. R8 设置和数据源页面 UI 拆分

这一阶段风险高于普通 UI，因为设置项会影响运行时行为。只允许拆展示，不改配置读写。

### R8.1 设置页 UI 拆分

目标文件：

- `windows_app\lib\screens\settings_screen.dart`

目标目录：

- `windows_app\lib\features\settings\widgets\`

固定拆分顺序：

1. `settings_screen_scaffold.dart`：页面框架和标题。
2. `settings_data_source_section.dart`：数据源设置展示和入口。
3. `settings_backup_section.dart`：备份设置 UI。
4. `settings_appearance_section.dart`：外观设置 UI。
5. `settings_system_section.dart`：系统信息、日志、路径展示 UI。

禁止：

- 不改 `settings_provider.dart`。
- 不改配置存储。
- 不改数据库路径保存。
- 不改备份执行逻辑。

### R8.2 数据源页面 UI 拆分

目标文件：

- `windows_app\lib\screens\data_source_screen.dart`

目标目录：

- `windows_app\lib\features\data_source\widgets\`

固定拆分顺序：

1. `data_source_mode_section.dart`：全局/模块化模式选择 UI。
2. `data_source_sqlite_section.dart`：SQLite 路径显示和选择 UI。
3. `data_source_mysql_section.dart`：MySQL 连接配置 UI。
4. `data_source_module_mapping_section.dart`：模块到数据源映射 UI。
5. `data_source_connection_status.dart`：连接状态 UI。

禁止：

- 不改连接测试逻辑。
- 不改配置保存逻辑。
- 不改模块配置字段名。
- 不改 MySQL 密码处理。

验收：

- 设置页能打开。
- 数据源配置能显示。
- 不出现配置丢失。
- 不出现数据源自动切换异常。

## 25. R9 Provider 瘦身路线

R9 只有在 R1-R8 UI 拆分完成或明确暂停后才能开始。R9 不改 UI，不改 Data Source。

Provider 处理顺序固定为：

1. `financial_provider.dart`
2. `purchase_provider.dart`
3. `medical_record_provider.dart`
4. `appointment_provider.dart`
5. `material_provider.dart`
6. `user_provider.dart`
7. `settings_provider.dart`
8. `database_provider.dart`

`patient_provider.dart` 当前已较小，暂不作为 R9 第一目标。

### R9 每个 Provider 的固定施工步骤

每个 Provider 都按同样步骤做：

1. 只读 Provider，列出方法分组：初始化、查询、增删改、统计、导入导出、UI 状态。
2. 先拆纯函数或无副作用逻辑。
3. 再拆查询编排。
4. 最后拆增删改流程。
5. 每轮只拆一个方法组。

允许新增目录：

- `windows_app\lib\features\<module>\services\`

Service 命名固定：

- `<module>_query_service.dart`
- `<module>_mutation_service.dart`
- `<module>_statistics_service.dart`
- `<module>_initialization_service.dart`

禁止：

- 不一次性拆完整 Provider。
- 不改 Provider 对外方法名，除非所有调用方同轮同步且 analyze 无 error。
- 不让 Service 依赖 BuildContext。
- 不让 Service 弹窗。
- 不把 UI 状态迁到 Service。

### R9.1 `financial_provider.dart`

第一轮只拆：

- 金额统计。
- 状态统计。
- 按时间范围统计。

允许新增：

- `features\financial\services\financial_statistics_service.dart`

第二轮再拆：

- 财务查询编排。

允许新增：

- `features\financial\services\financial_query_service.dart`

第三轮再拆：

- 新增、编辑、删除、收款流程。

允许新增：

- `features\financial\services\financial_mutation_service.dart`

### R9.2 `purchase_provider.dart`

第一轮只拆：

- 采购统计。
- 供应商统计。
- 时间范围统计。

第二轮拆：

- 采购查询编排。

第三轮拆：

- 新增、编辑、删除、付款流程。

### R9.3 `medical_record_provider.dart`

第一轮只拆：

- 模板存在性判断。
- 病历排序。
- 病历摘要格式化。

第二轮拆：

- 病历查询编排。

第三轮拆：

- 新增、编辑、删除病历。

第四轮单独处理：

- PDF 导出编排。

### R9.4 `appointment_provider.dart`

第一轮只拆：

- 状态文案。
- 状态颜色或状态映射。
- 排序和过滤条件组装。

第二轮拆：

- 预约查询编排。

第三轮拆：

- 新增、编辑、取消、完成流程。

### R9.5 `material_provider.dart`

第一轮只拆：

- 库存状态判断。
- 材料统计。

第二轮拆：

- 材料查询编排。

第三轮拆：

- 新增、编辑、删除材料。

### R9.6 `user_provider.dart`

第一轮只拆：

- 角色和权限显示规则。
- 用户筛选排序。

第二轮拆：

- 用户查询编排。

第三轮拆：

- 新增、编辑、删除、密码修改流程。

禁止：

- 不改权限规则含义。
- 不改登录验证。

### R9.7 `settings_provider.dart`

第一轮只拆：

- 配置读取默认值映射。

第二轮拆：

- 配置保存编排。

第三轮拆：

- 备份和恢复相关编排。

禁止：

- 不改配置 key。
- 不改存储路径。

### R9.8 `database_provider.dart`

最后处理。

第一轮只拆：

- 数据源类型判断辅助函数。

第二轮拆：

- SQLite 初始化编排。

第三轮拆：

- MySQL 初始化编排。

第四轮拆：

- 模块化数据源切换编排。

禁止：

- 不改 schema。
- 不改数据库迁移。
- 不改配置字段名。
- 不改连接密码处理。

## 26. R10 Service/Data Source 边界收口

R10 只有在 UI 和 Provider 大部分稳定后才能开始。R10 的目标是让 SQL 回到 Data Source。

处理顺序固定：

1. 患者。
2. 财务。
3. 采购。
4. 材料。
5. 预约。
6. 病历。
7. 用户。

每个模块固定步骤：

1. 搜索该模块 Service 中的 SQL 关键字：`rawQuery`、`query(`、`insert(`、`update(`、`delete(`、`SELECT`、`JOIN`。
2. 选一个查询职责。
3. 在抽象 Data Source 增加方法签名。
4. 在 SQLite 实现相同方法。
5. 在 MySQL 实现相同方法。
6. Service 改为调用 Data Source。
7. Provider 不感知变化。

禁止：

- 不同模块 SQL 不同轮处理。
- 不把 SQLite SQL 复制给 MySQL 后不检查字段差异。
- 不改表结构。
- 不改返回 model 类型。

验收：

- SQLite 模式正常。
- MySQL 模块正常。
- 模块化配置正常。

## 27. 单轮操作模板

任何模型开始一轮任务时，必须先在回复或工作记录中写出以下内容：

```text
本轮编号：
本轮目标：
允许修改文件：
允许新增文件：
明确不处理：
成功标准：
验证命令：
```

示例：

```text
本轮编号：R2.3
本轮目标：拆分财务按患者显示列表 UI
允许修改文件：
- windows_app\lib\screens\financial_management_screen.dart
允许新增文件：
- windows_app\lib\features\financial\widgets\financial_patient_group_list.dart
- windows_app\lib\features\financial\widgets\financial_patient_group_item.dart
明确不处理：
- financial_provider.dart
- financial_data_source.dart
- getPatientAggregatesPage 查询逻辑
成功标准：
- 按患者列表显示、展开、分页行为不变
验证命令：
- flutter analyze | Select-String "error -"
```

如果一个模型无法写清楚这些内容，不能动代码。

## 28. UI 拆分机械步骤

每个 UI 拆分任务必须按以下机械步骤做，不能自由发挥。

1. 在目标 screen/dialog 文件中定位一个完整 UI 职责块。
2. 确认该块没有直接 SQL、没有直接数据库连接、没有独立业务流程。
3. 新建 widget 文件。
4. 把原 UI 代码原样移动到新 widget。
5. 把原来闭包里用到的变量全部变成构造参数。
6. 把原来闭包里调用的方法全部变成回调参数。
7. 回调参数使用 `VoidCallback`、`ValueChanged<T>` 或明确类型函数。
8. 新 widget 不读 Provider，除非原 UI 块本来就是独立 Consumer；即使是 Consumer，也优先把数据从父级传入。
9. 原文件只保留状态、Provider 调用、事件流程和新 widget 组合。
10. 清理本轮新增的无用 import。
11. 不格式化全项目。
12. 更新主计划。

如果某个 UI 块和业务逻辑混在一起，处理方式固定：

- 只抽出最内层纯展示 widget。
- 保留业务判断在原文件。
- 不为了抽 UI 改业务流程。

## 29. Provider 拆分机械步骤

每个 Provider 拆分任务必须按以下机械步骤做。

1. 不改 UI 调用方。
2. 保持 Provider 对外 public 方法名不变。
3. 新建 Service。
4. 把 Provider 内部私有纯函数先移动到 Service。
5. Provider 构造或初始化 Service。
6. Provider public 方法调用 Service。
7. loading、error、notifyListeners 留在 Provider。
8. 如果 Service 需要 Data Source，通过构造参数注入，不在 Service 内读全局 Provider。
9. 如果 Service 需要当前用户、权限、数据源类型，通过参数传入。
10. 更新主计划。

禁止：

- Provider public API 改名。
- 一轮迁移多个互相无关方法组。
- Service 持有 BuildContext。
- Service 直接弹 UI。

## 30. Data Source 拆分机械步骤

每个 Data Source 拆分任务必须按以下机械步骤做。

1. 先确认 Provider/Service 层已有稳定调用。
2. 在抽象 Data Source 增加一个方法。
3. SQLite 实现该方法。
4. MySQL 实现该方法。
5. Service 调用抽象 Data Source 方法。
6. 不让 Service 判断 SQL 方言。
7. 不改 model 字段。
8. 不改数据库 schema。
9. 不改已有配置 key。
10. 更新主计划。

如果 SQLite 和 MySQL 字段不同：

- 必须对照两个现有实现文件。
- 保持原查询字段映射不变。
- 不猜字段名。

## 31. 模块 UI 完成标准

一个模块 UI 拆分完成，必须满足：

- screen/dialog 主文件主要只剩页面状态、生命周期、Provider 调用、事件编排、widget 组合。
- 单个 screen/dialog 文件优先低于 900 行；确实复杂的表单允许暂时低于 1200 行。
- 单个 widget 文件优先低于 500 行；复杂表格或表单 section 允许暂时低于 800 行。
- widget 不直接拼 SQL。
- widget 不直接读数据库。
- widget 不新增 Provider 依赖。
- 原用户操作路径不变。

未达到这些标准时，不能声称该模块 UI 拆分完成。

## 32. 当前各模块拆分状态表

| 模块 | UI 状态 | Provider 状态 | Data Source 状态 | 下一步 |
| --- | --- | --- | --- | --- |
| 患者 | 部分完成，仍需 R1 收尾 | 已明显瘦身但仍承担 facade 和初始化 | 已物理拆分，Service 中仍有 SQL | 执行 R1 |
| 财务 | 未完成，主 screen 和 form dialog 很大 | 未拆，仍很大 | 已物理拆分 | 执行 R2 |
| 材料 | 未完成，screen 和多个 widget 很大 | 未拆 | 已物理拆分 | 执行 R3 |
| 采购 | 未完成，screen 很大 | 未拆 | 已物理拆分 | 执行 R4 |
| 预约 | 未完成，screen/form/detail 仍在 screens | 未拆 | 已物理拆分 | 执行 R5 |
| 病历 | 未完成，管理页、表单、模板、详情弹窗都需拆 | 未拆且较大 | 已物理拆分 | 执行 R6 |
| 用户 | 未完成，users_screen 较大 | 未拆 | 已物理拆分 | 执行 R7 |
| 设置/数据源 | 未完成，文件极大，风险高 | settings/database provider 很大 | 不适用或已存在 | 执行 R8 |

## 33. 自由发挥拦截规则

出现以下行为，视为偏离方案，必须停止：

- 跳过 R0 直接拆新模块。
- 在 R1-R8 阶段修改 Provider 业务逻辑。
- 在 UI 拆分时改 SQL。
- 在 Provider 拆分时改 UI。
- 在 Data Source 收口时改页面。
- 一轮同时处理财务和采购。
- 一轮同时处理 screen 和 provider。
- 为了消除 error 删除功能代码。
- 把 `windows_app11` 文件整文件覆盖到当前项目。
- 未经确认删除文件。
- 引入新状态管理框架。
- 新增 repository 架构并大范围替换调用。
- 修改数据库 schema。

如果必须违反其中一条，必须先向用户说明原因并等待确认。

# Android App 开发文档指南

## 目的

这份指南用于约束 `D:\Data\android_project\dentist_app\android_app` 后续开发，目标只有四个：

1. 结构清晰
2. 排查问题更快
3. 增加功能更容易
4. 文件职责明确，减少混用和耦合

它不是设计说明，也不是拆分流水账。它的作用是给后续新增功能、修 bug、拆分文件、调整目录时提供统一落点。

## 适用范围

- 适用于 `android_app` 下所有 Flutter 代码
- 适用于新增文件、迁移文件、重命名文件、拆分文件、补充文档
- 适用于后续由 Codex 或人工共同维护的开发过程

## 最高原则

1. 先按职责放文件，再考虑代码复用。
2. 先让边界清楚，再追求通用性。
3. 一个文件只做一类事情。
4. 不为了“看起来整齐”而重构无关代码。
5. 不为了短期方便把 UI、业务、数据访问混在一起。

## 目录约定

### 1. `lib/features/<module>/`

模块代码优先放这里。当前项目已经有这些模块：

- `patients`
- `appointments`
- `financial`
- `medical_records`
- `materials`
- `purchases`
- `users`
- `settings`
- `dashboard`

每个模块下优先按下面三类组织：

- `models/`：模块专用数据结构、DTO、ViewModel
- `services/`：业务流程、初始化、校验、缓存、同步、编排
- `widgets/`：模块专用 UI 组件、弹窗、表单片段、页面局部块

如果模块后续真的需要再细分，可以再补：

- `helpers/`：纯辅助逻辑，不能承载业务编排
- `screens/`：模块内部页面壳子，前提是这个页面已经明显属于该模块
- `providers/`：只有在模块内真的需要单独收口状态管理时才放

### 2. `lib/screens/`

这里只放页面入口壳，职责是：

- 组装页面
- 连接 provider / service
- 挂载模块级 widget
- 保留路由入口与页面级生命周期

不放这些内容：

- 大块表单 UI
- 大段弹窗实现
- 复杂业务逻辑
- SQL 拼接
- 大量缓存/连接/权限判断

### 3. `lib/providers/`

这里只放全局状态协调和跨模块编排。原则是：

- Provider 只做状态管理和流程协调
- Provider 不直接承担复杂业务逻辑
- Provider 不直接拼 SQL
- Provider 不直接创建或管理过多数据源细节

如果某个 Provider 已经明显变成“业务大杂烩”，优先把职责下沉到 `features/<module>/services/`。

### 4. `lib/data_sources/`

这里只放数据访问边界相关代码。原则是：

- 接口文件和实现文件要分清
- SQLite / MySQL 差异逻辑尽量收口在数据源层
- 查询条件构造要集中，不要到处重复写 `where` / `args`

数据源层不做 UI，不做页面编排，不做跨层状态协调。

### 5. `lib/widgets/`

这里只保留真正跨模块通用的组件。

可保留的典型类型：

- 通用确认框
- 通用日期选择器
- 通用提示组件
- 通用卡片、输入框、状态提示

应该迁出的典型类型：

- 明确属于某个模块的弹窗
- 只服务某个页面的局部 UI
- 带有明显业务语义的组件

### 6. `lib/utils/`

这里只放纯工具类。

判断标准很简单：

- 不能依赖页面状态
- 不能依赖业务流程
- 不能内嵌模块判断
- 输入输出尽量明确

如果工具开始依赖业务上下文，就应该下沉到对应模块的 `services/`。

### 7. `lib/models/`

这里只放跨模块共享模型和全局 schema。

如果模型只服务一个模块，优先放到：

- `lib/features/<module>/models/`

## 命名规则

### 文件命名

- 全部使用 `snake_case.dart`
- 文件名必须直接反映职责
- 不使用模糊词：`common`、`helper`、`manager`、`util`、`tool` 只有在职责足够明确时才允许

优先命名方式：

- `patient_initialization_service.dart`
- `financial_statistics_service.dart`
- `settings_backup_restore_dialogs.dart`
- `appointment_search_filter_bar.dart`

不推荐命名方式：

- `new_widget.dart`
- `temp_service.dart`
- `common_utils.dart`
- `misc.dart`

### 类命名

- Widget 用 `XXXWidget`、`XXXDialog`、`XXXCard`、`XXXSection`
- Service 用 `XXXService`
- Provider 用 `XXXProvider`
- Helper 用 `XXXHelper`
- Model 用明确业务名，不用泛化名字

### 方法命名

- 方法名必须能看出动作和对象
- 避免 `doThing`、`handleData`、`process` 这种泛名
- 查询、缓存、校验、刷新、同步、初始化要分开命名

## 职责边界

### UI 层

UI 层只负责展示、交互、事件上抛。

UI 可以做的事：

- 渲染列表、表单、弹窗
- 响应点击、输入、选择
- 把用户动作交给 provider / service

UI 不应该做的事：

- 拼 SQL
- 判断数据库类型
- 自己维护复杂缓存
- 自己做权限流程
- 自己处理同步与重连

### Provider 层

Provider 负责：

- 页面状态
- 数据加载编排
- 用户交互后的流程转发
- 调用 service，汇总结果

Provider 不负责：

- 大段业务规则
- 重复查询条件拼接
- 复杂数据转换
- 跨模块逻辑

### Service 层

Service 负责：

- 初始化
- 校验
- 连接协调
- 缓存管理
- 查询编排
- 业务流程拆分

Service 的目标是让 Provider 变薄，而不是再造一个更胖的工具类。

### Data Source 层

Data Source 负责：

- 数据读写
- SQLite / MySQL 具体差异
- 查询实现

不负责 UI，不负责 provider 状态，不负责页面流程。

## 新功能放哪里

新增功能时，先按这个顺序判断落点：

1. 这个功能属于哪个模块
2. 它是 UI、业务、数据、还是纯工具
3. 它是否只服务一个页面
4. 它是否可以独立测试和复用

落点规则：

- 页面入口放 `lib/screens/`
- 模块 UI 放 `lib/features/<module>/widgets/`
- 模块业务放 `lib/features/<module>/services/`
- 模块模型放 `lib/features/<module>/models/`
- 通用工具放 `lib/utils/`
- 全局共享 UI 放 `lib/widgets/`
- 数据访问放 `lib/data_sources/`

## 拆分规则

拆文件时按这个优先级处理：

1. 先拆职责最清楚、影响范围最小的部分
2. 同一文件内同一职责簇可以一次拆完
3. 不同风险边界不要混拆
4. 不要为了“每个文件都很小”而继续切碎

推荐拆分节奏：

- UI：一次拆完整职责组
- Provider / Service：一次拆一条完整流程
- Data Source：一次拆一个数据边界

## 重命名规则

需要重命名文件时，按这个顺序处理：

1. 先确认职责是否真的变了
2. 再确认是否能用更准确的名字表达职责
3. 再检查所有引用是否能一起改完

禁止：

- 只改文件名，不改引用
- 只为了“更好看”重命名
- 频繁改名造成上下文丢失

## 放在根级的内容必须有理由

根级目录只保留以下两类内容：

1. 全局入口
2. 真的跨模块共享

如果一个文件属于某个模块，就不要长期留在根级。

## 排查问题的顺序

以后排查问题，按这个顺序：

1. 先看具体模块
2. 再看对应 service / provider
3. 再看 data source
4. 最后才看全局工具和根级共享组件

不要一开始就怀疑所有层，先缩小到最小责任边界。

## 新增代码前的检查清单

写新文件前先确认：

- 这个文件属于哪个模块
- 这个文件只做几类事情
- 这个名字是否直接反映职责
- 是否会和现有文件职责重叠
- 是否会把 UI、业务、数据混在一起

## 修改代码前的检查清单

改现有代码前先确认：

- 能不能只改最小范围
- 是否会影响页面入口
- 是否会影响 provider 状态
- 是否会影响数据源切换
- 是否会引入新的耦合

## 代码评审标准

如果一个文件出现下面任意一项，说明需要重新整理：

- 超过一个明显职责
- 名字看不出用途
- UI 和业务混在一起
- Provider 直接拼接查询或处理大量数据转换
- service 变成万能工具类
- widgets 里塞进模块私有业务

## 验证要求

每次改完后，至少提醒执行：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter analyze
```

如果改动涉及启动、登录、数据库切换、权限、初始化链，再补充：

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter run
```

## 维护规则

- 新增功能先按本指南落点
- 迁移旧代码时优先收口职责，再考虑美化目录
- 如果发现当前规则不够用，先补这份指南，再改代码
- 不要在没有文档约束的情况下继续扩大混用

## 结论

这份指南的核心不是“把目录切得更细”，而是让每个文件都能回答三个问题：

1. 我属于哪个模块
2. 我负责什么
3. 我不负责什么

只要后续所有新增和拆分都遵守这三条，代码就不会继续乱放、乱命名，也更容易排查和扩展。

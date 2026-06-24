# Android App 静态检查治理计划

## 结论

`D:\Data\android_project\dentist_app\android_app` 当前需要补一轮静态检查治理，但这轮工作**不能按“大重构”方式推进**。

本计划只做三件事：

1. 降低真实风险
2. 提高 `flutter analyze` 的可读性
3. 在**不影响现有架构和逻辑**的前提下，为后续小步治理建立执行顺序

本计划**不是**架构改造方案，不推动模块重组，不推动 Provider 重写，不推动数据库访问层替换，不改页面交互结果，不改数据库 schema，不改现有功能行为。

## 适用范围

- 仅适用于 `android_app`
- 仅适用于静态检查治理、低风险代码清理、文档补充
- 适用于后续由 Codex 或人工分批执行

不包含以下内容：

- 不改数据库表结构
- 不改 MySQL / SQLite 现有运行逻辑
- 不改页面路由和业务流程
- 不做跨模块重命名和大规模迁移
- 不因为“顺手”做全项目格式化

## 当前现状

本次检查基于 `cmd.exe /c flutter analyze`。

当前结果：

- 总问题数：`1991`
- `warning`：`303`
- `info`：`1688`

问题分布最集中的几类：

- `avoid_print`：`1200`
- `deprecated_member_use`：`217`
- `unused_import`：`126`
- `prefer_const_constructors`：`87`
- `use_build_context_synchronously`：`74`
- `dead_null_aware_expression`：`43`
- `unused_element`：`36`
- `unused_field`：`32`
- `unnecessary_non_null_assertion`：`19`
- `unnecessary_null_comparison`：`16`
- `depend_on_referenced_packages`：`14`

这说明当前问题不是单点 bug，而是：

1. 低价值噪声过多，掩盖了高信号问题
2. 一部分空安全与异步上下文问题已经开始影响正确性
3. 工程卫生没有跟上 Flutter / Dart 版本变化

## 约束原则

本计划执行时必须遵守以下约束：

1. 不影响现有业务逻辑。
2. 不改变页面交互结果。
3. 不调整现有目录结构和模块归属。
4. 不主动做架构重构。
5. 不把“清理 lint”扩展成“顺便优化代码风格”。
6. 每一批修改都必须可回归验证。

判断标准只有一个：

如果某项修改会让现有行为、初始化时序、权限控制、数据库切换、同步流程发生不确定变化，这项修改就不属于本计划，应停止并单独立项。

## 风险分级

### P0：必须优先处理

这些问题不是“代码风格”，而是会影响安全性、正确性或后续维护判断。

包括：

- 明文保存敏感信息
- 固定默认密码或隐式弱口令回退
- `use_build_context_synchronously`
- `dead_null_aware_expression`
- `unnecessary_null_comparison`
- `unnecessary_non_null_assertion`
- `invalid_null_aware_operator`
- `depend_on_referenced_packages`
- `unreachable_switch_default`

### P1：应成批处理

这些问题虽然不一定马上造成线上故障，但继续堆积会让分析结果不可读。

包括：

- `unused_import`
- `unused_element`
- `unused_field`
- `unused_local_variable`
- `deprecated_member_use`

### P2：可以后置处理

这些问题主要影响工程整洁度，不应抢占前两类问题的处理优先级。

包括：

- `avoid_print`
- `prefer_const_constructors`
- `prefer_const_declarations`
- `prefer_const_literals_to_create_immutables`
- `use_key_in_widget_constructors`
- `sort_child_properties_last`

## 当前最值得关注的风险点

### 1. 登录凭证存储风险

当前代码存在以下风险：

- 登录密码保存在 `SharedPreferences`
- 异常路径会回退到固定默认账号密码

这类问题的处理目标不是“重写登录系统”，而是：

1. 去掉默认账号密码兜底
2. 默认只记住用户名，不明文记住密码
3. 如果业务上必须保留“记住密码”，再单独评估安全存储方案

注意：

- 本计划不要求直接引入新的鉴权架构
- 本计划不要求把登录流程改成服务端认证
- 本计划只要求先消除明显不合理实现

### 2. 异步后继续使用 `BuildContext`

这类问题数量不少，分布在 `dashboard`、`settings`、`financial`、`patients`、`purchase`、`users` 等页面和弹窗里。

风险是：

- 页面已销毁后继续弹窗或调用 `Navigator`
- 状态变化后仍使用旧上下文
- 复现成本高，静态检查却已经提前给出信号

这类修复应遵循：

1. 只补 `mounted` / `context.mounted` 守卫
2. 只调整调用位置，不改原有业务判断
3. 不顺带改 UI 结构

### 3. 空安全判断失真

当前存在大量：

- 空值判断永远为真/假
- `!` 对非空值无效
- `?.` 对非空值无效

这说明部分代码是在旧空安全语义下迁移过来的，或者后续演化时没有同步清理。

这类问题如果不处理，会带来两个坏处：

1. 代码阅读者会被误导，以为这里真的存在可空分支
2. 真实空值 bug 会被淹没在“看起来像判空”的假逻辑里

### 4. 依赖声明不完整

当前有 `path`、`cross_file` 等被使用但未在 `pubspec.yaml` 中显式声明的问题。

这类问题短期内可能还能跑，是因为传递依赖碰巧存在，但它不稳定：

1. 换机器可能失败
2. 升级依赖可能失败
3. 静态分析始终会报噪声

这类修复不改变业务逻辑，优先级应高。

### 5. 过量 `print`

`avoid_print` 占了 `1200` 条，是当前噪声的最大来源。

这里要明确：

- `print` 太多确实不合理
- 但它不是本轮第一优先级

本计划不建议现在全量替换为复杂日志框架。更稳妥的方式是：

1. 先处理 P0 / P1
2. 再统一引入一层极薄的日志封装
3. 分批替换高频热点文件中的 `print`

## 执行策略

整体策略是：**先让 analyzer 重新具备判断价值，再考虑进一步收敛。**

### 第一阶段：建立可执行基线

目标：

- 固化当前结果
- 明确不动边界
- 为后续每批治理设定验证标准

本阶段动作：

1. 保存当前 `flutter analyze` 结果
2. 记录各问题类型数量
3. 建立本计划文档
4. 明确“只做小步修复，不做架构改造”

验收标准：

- 文档可作为后续执行依据
- 后续每一批都能对照本计划推进

### 第二阶段：只清理高信号问题

目标：

- 优先消除真正影响正确性和稳定性的告警

处理范围：

- `use_build_context_synchronously`
- `dead_null_aware_expression`
- `unnecessary_null_comparison`
- `unnecessary_non_null_assertion`
- `invalid_null_aware_operator`
- `depend_on_referenced_packages`
- `unreachable_switch_default`
- 登录凭证明文存储与固定默认密码问题

处理原则：

1. 一次只处理一小类
2. 优先从风险集中区域开始
3. 每批改完都跑 `flutter analyze`
4. 如果某类修复触及行为不确定区，立即暂停，不继续扩散

验收标准：

- `warning` 明显下降
- 关键高信号问题数量下降到可控水平
- 没有引入新的行为变更

### 第三阶段：清理中等噪声

目标：

- 让 analyzer 输出重新可读

处理范围：

- `unused_import`
- `unused_element`
- `unused_field`
- `unused_local_variable`
- `deprecated_member_use`

处理原则：

1. 优先批量删未使用 import
2. 再清理无引用私有成员
3. 最后处理 `withOpacity` 等兼容性替换

说明：

- `deprecated_member_use` 虽然大多不影响当前逻辑，但属于版本兼容债
- 这一步不改变 UI 设计，只替换等价 API

验收标准：

- Analyzer 输出长度明显缩短
- 低价值噪声下降
- 页面表现无变化

### 第四阶段：收敛日志噪声

目标：

- 降低 `avoid_print` 对分析结果的污染

建议做法：

1. 先补一层最小日志工具
2. 只替换高频核心文件
3. 不要求一次清空全部 `print`

不建议做法：

- 不要一口气在全项目替换 1200 处
- 不要顺便接入复杂日志平台
- 不要为了日志规范改动大量业务代码

验收标准：

- 核心链路文件中的 `print` 显著下降
- 后续问题排查入口更集中

## 推荐批次安排

### 批次 A：高信号告警与安全问题

建议内容：

1. 修复登录凭证明文保存和默认密码回退
2. 补齐缺失依赖声明
3. 修复 `invalid_null_aware_operator`
4. 修复 `unreachable_switch_default`
5. 修复明显的空安全伪判断

验收：

- `flutter analyze` 可通过对比确认问题数下降
- 登录与设置相关基本流程可人工回归

### 批次 B：异步上下文治理

建议内容：

1. 集中处理 `dashboard`
2. 处理 `settings`
3. 处理 `financial`
4. 处理 `patients`、`purchases`、`users`

验收：

- `use_build_context_synchronously` 大幅下降或清零
- 弹窗、跳转、保存后的反馈不变

### 批次 C：未使用代码清理

建议内容：

1. 删 `unused_import`
2. 删 `unused_element`
3. 删 `unused_field`
4. 删 `unused_local_variable`

验收：

- 这批修改应主要体现为无行为差异的小改动
- Analyzer 噪声明显减少

### 批次 D：兼容性与日志收敛

建议内容：

1. 逐步替换 `withOpacity`
2. 逐步引入最小日志封装
3. 分模块替换 `print`

验收：

- 不影响现有 UI 视觉结果
- 不影响现有初始化流程

## 每批执行时的操作规范

每一批都按下面步骤执行：

1. 先限定本批处理范围
2. 先跑一次 `flutter analyze`
3. 只改本批对应类型的问题
4. 改完再次运行 `flutter analyze`
5. 记录问题数量变化
6. 必要时补充局部人工回归说明

禁止行为：

- 顺手做模块迁移
- 顺手重命名一批文件
- 顺手统一格式化全项目
- 顺手改页面视觉样式
- 顺手改数据库流程

## 建议验证方式

本计划后续执行时，最少验证包括：

### 静态验证

- `cmd.exe /c flutter analyze`

### 关键人工回归

- 登录页加载与登录提交
- 首页进入与基础导航
- 设置页打开、保存、返回
- 依赖数据库的主要页面能正常进入
- 涉及弹窗的页面在异步操作后不报上下文错误

说明：

- 如果某批次只改文档或只改 import，可不做完整功能回归
- 如果某批次涉及登录、设置、弹窗、导航，必须补最少人工验证说明

## 不建议现在做的事

以下内容当前不建议混入本计划：

1. 把客户端直连 MySQL 改成 API 化
2. 重写 `DatabaseProvider`
3. 重写 `ConnectionManager`
4. 大规模迁移 `providers/`、`services/`、`utils/`
5. 把所有 `print` 一次性替换掉
6. 追求 `flutter analyze` 一次性归零

原因很简单：

- 这些动作都可能影响现有架构和逻辑
- 它们已经超出“静态检查治理”的边界
- 应该单独立项、单独验证、单独评估风险

## 成功标准

本计划成功，不以“所有 lint 清零”为标准，而以下面四条为标准：

1. `flutter analyze` 不再被海量低价值噪声淹没
2. 高信号问题被优先清掉
3. 现有业务逻辑、路由、数据库行为未被改坏
4. 后续开发能看懂 analyzer 输出，并继续按批次推进

## 最终建议

最合理的推进方式不是大改，而是：

1. 先做批次 A
2. 再做批次 B
3. 然后做批次 C
4. 最后视精力决定是否做批次 D

如果后续执行中连续三轮修改仍然无法明显下降关键问题数量，就不该继续硬清 lint，而应停下来重新评估：

- 当前问题是否触及真实架构边界
- 是否需要拆成更小批次
- 是否需要单独立项处理某个高风险模块

这份计划的核心不是“把输出变干净”，而是：在不影响现有架构和逻辑的前提下，把真正该修的先修掉，把不该现在动的明确挡住。

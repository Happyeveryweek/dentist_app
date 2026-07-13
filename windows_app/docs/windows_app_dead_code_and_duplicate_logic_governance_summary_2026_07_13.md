# Windows 端无用代码与重复逻辑治理总结

完成日期：2026-07-13。

本文是 Windows 端两轮无用代码与重复逻辑治理的最终状态源，替代此前的四份阶段性审核与实施文档。

## 1. 范围与结论

治理覆盖 `windows_app/lib/` 的文件级不可达代码、方法级无调用 API，以及五套患者同步服务中的重复日志构建逻辑。

- 文件级治理：从 `lib/main.dart` 建立静态引用图，确认并删除 39 个不可达 Dart 文件，约 8484 行。范围包括预约旧组件、财务旧弹窗与统计、采购旧统计、患者材料旧编辑器、旧 schema/MySQL 工具及未接入组件。
- 方法级治理：重新搜索并删除约 60 个 A 级独立无调用方法、19 个 Provider 旧入口、SettingsProvider 及其 service 的无消费者委托链、11 个一次性迁移/数据库/模板 API，以及删除产生的孤儿 import、字段和私有方法。
- 重复逻辑治理：新增 `PatientSyncLogHelper`，迁移预约、财务、病历、患者材料、患者核心五套同步服务，删除 21 个私有重复 helper。

已确认继续保留的现用链路包括 SQLite 升级、MySQL 建表与结构检测、数据库备份恢复、材料类型初始化、现用 Provider 入口、患者同步 SQL/实体映射/同步时序。

## 2. 验证证据

每个删除候选在实施当日均重新进行 `rg` 搜索，并确认不是抽象接口、override、生命周期、序列化、回调、路由或动态访问入口。

- 文件级及方法级清理后均通过 `flutter analyze`、`git diff --check` 和改动文件 LF 行尾检查。
- 方法级批次 1～4 的全量 `flutter test` 为 64 个通过；批次 5 新增 4 个 `PatientSyncLogHelper` 行为测试后，全量 `flutter test` 为 68 个通过。
- 设置主题/持久化、备份恢复、SQLite/MySQL 切换和结构检测、历史数据库、模板导入导出、材料类型等高风险回归已确认通过。
- 主人已确认患者、预约、财务、病历、患者材料五类同步日志回归完成；收口未改变 SQL、实体字段映射、同步 action/status 或同步时序。

## 3. 暂缓的独立优化

原计划的图表组件与财务查询对象治理不属于无用代码清理，当前决定暂缓，不纳入本次完成范围：

- 三类统计图表可抽取视觉骨架，但收益主要是减少少量配置重复，不能改善当前功能或性能。
- `FinancialItemsQuery` 会跨越抽象 data source、SQLite/MySQL、查询 service、Provider 与财务页面；现有两种数据源对 `searchQuery` 的处理存在差异，重构会带来行为决策，需在确有新增筛选需求或查询不一致问题时另立任务并先补双数据源一致性测试。
- schema `createTableSql` 模板重构风险高，未建立 schema 快照测试前不实施。

## 4. 后续维护边界

1. 新增或删除 public API 前，先搜索 `lib/`、`test/` 和文档引用，避免再次形成无消费者兼容层。
2. 患者同步日志的字段差异、值标准化、展示值和摘要提取统一使用 `PatientSyncLogHelper`；业务 SQL、实体映射和同步时序继续留在各自 service。
3. 若将来实施财务查询对象，必须一次替换接口与 SQLite/MySQL 两套实现，并以同条件查询一致性测试作为前置条件。
4. 现有验证顺序保持为：定向 `dart format`（仅 Dart 改动文件）→ `flutter analyze` → 必要时 `flutter test` → `git diff --check` → 行尾检查。

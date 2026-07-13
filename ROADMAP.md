# ROADMAP

## 当前状态

### Windows 端

- 无用代码与重复逻辑治理已完成：删除 39 个不可达 Dart 文件、方法级无调用 API 与无消费者委托链；五套患者同步服务已通过 `PatientSyncLogHelper` 收口。最终状态见 [治理总结](windows_app/docs/windows_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 图表组件抽取、财务查询对象和 schema 模板重构均已暂缓：当前收益不足以覆盖跨模块行为风险，不是遗留缺陷。
- 主题治理、SQLite/MySQL 数据源与备份恢复、患者 SQLite → MySQL 同步规则均已完成；业务变更以对应模块代码和测试为准。

### Android 端

- 无用代码与重复实现治理已完成批次 0～5；批次 6～7 已暂缓，结论见 [治理总结](android_app/docs/android_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 登录“记住密码”、新建预约治疗项目窄屏布局、采购录入弹窗键盘适配均已完成代码与针对性静态检查，待人工回归确认。

## 待办与阻塞

- Windows 端：无用代码治理无阻塞项；若后续出现财务筛选扩展或 SQLite/MySQL 查询结果不一致，再单独评估财务查询对象重构。
- Android 端：无死代码清理待办。若未来出现 MySQL 图片、文本或日期转换不一致，再按治理总结建立专项测试与迁移方案。
- 阻塞：无。

## 最近验证

- 2026-07-13：Windows 方法级治理批次 5 完成。新增 4 个 `PatientSyncLogHelper` 测试；全量 `flutter test` 68 个通过，`flutter analyze` 为 `No issues found!`，`git diff --check` 与 LF 行尾检查通过；五类同步日志手动回归已确认。
- 2026-07-13：Windows 方法级治理批次 1～4 完成。全量 `flutter test` 64 个通过，`flutter analyze` 为 `No issues found!`；设置、备份恢复、数据源切换、数据库/模板/材料类型高风险回归已确认。
- 2026-07-13：Android 无用代码治理批次 3A 完成。删除旧财务清理文件及 30 个无调用方法；`flutter analyze` 为 `No issues found!`，`git diff --check` 与 LF 行尾检查通过。
- 2026-07-13：Android 无用代码治理批次 4 完成。删除 2 个一次性迁移文件和 8 个无消费者备份／数据库旧入口；Windows Flutter `flutter analyze` 为 `No issues found!`；SQLite／MySQL 的备份恢复、旧库升级和连接回归已确认通过。
- 2026-07-13：Android 无用代码治理批次 5 完成。删除采购页空焦点／生命周期监听链；Windows Flutter `flutter analyze` 为 `No issues found!`，`git diff --check` 通过；采购页首次、下拉、增删改和前后台刷新回归已确认。

## 维护规则

- 只有已实现并验证的事项进入“完成”；未确认信息放入“待办与阻塞”。
- 详细执行过程不再重复保存在本文件；使用模块内最终总结文档和 Git 历史追溯。

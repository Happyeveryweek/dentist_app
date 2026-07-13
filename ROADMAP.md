# ROADMAP

## 当前状态

### Windows 端

- 无用代码与重复逻辑治理已完成：删除 39 个不可达 Dart 文件、方法级无调用 API 与无消费者委托链；五套患者同步服务已通过 `PatientSyncLogHelper` 收口。最终状态见 [治理总结](windows_app/docs/windows_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 2026-07-13 复审后续治理已完成批次 0、1A、1B：清理 8 个无消费者旧 UI 类型／类和 1 个仅被 barrel export 的患者排序文件；`AppToastType`、`_ToastConfig` 因仍被 `AppToastManager` 使用而保留。其余 MySQL 备份委托链、采购导出和连接逻辑治理仍按 [后续治理实施方案](windows_app/docs/windows_app_dead_code_and_duplicate_logic_followup_implementation_plan_2026_07_13.md) 待执行，批次 1A、1B 的 UI 人工回归待确认。
- 图表组件抽取、财务查询对象和 schema 模板重构均已暂缓：当前收益不足以覆盖跨模块行为风险，不是遗留缺陷。
- 主题治理、SQLite/MySQL 数据源与备份恢复、患者 SQLite → MySQL 同步规则均已完成；业务变更以对应模块代码和测试为准。

### Android 端

- 无用代码与重复实现治理已完成批次 0～5；批次 6～7 已暂缓，结论见 [治理总结](android_app/docs/android_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 登录“记住密码”、新建预约治疗项目窄屏布局、采购录入弹窗键盘适配均已完成代码与针对性静态检查，待人工回归确认。
- 采购单仅含一个项目时，MySQL 将未变化的汇总更新误报为失败的问题已修复；待 Android 真机连接 MySQL 回归确认。

## 待办与阻塞

- Windows 端：后续无用代码与重复逻辑治理待执行批次 2A～5；删除文件、清理依赖生成文件和跨模块 MySQL 连接重构均需实施前确认。批次 1A、1B 的启动、提示、权限、用户头像和患者排序人工回归待确认。若后续出现财务筛选扩展或 SQLite/MySQL 查询结果不一致，再单独评估财务查询对象重构。
- Android 端：无死代码清理待办。若未来出现 MySQL 图片、文本或日期转换不一致，再按治理总结建立专项测试与迁移方案。
- 阻塞：无。

## 最近验证

- 2026-07-13：Windows 后续治理批次 0、1A、1B 完成。删除 8 个无消费者旧 UI 类型／类及 1 个仅被 barrel export 的患者排序文件；`AppToastType`、`_ToastConfig` 因仍服务于 `AppToastManager` 保留。基线及修改后 `flutter analyze --no-pub` 均为 `No issues found!`，全量 `flutter test --no-pub` 均为 68 个通过；`git diff --check` 与改动文本文件 LF 行尾检查通过。人工 UI 回归待确认。
- 2026-07-13：Windows 无用代码与重复逻辑复审及后续实施方案完成；复审覆盖 354 个 Dart 文件、public 类型／方法引用和直接依赖，`flutter analyze --no-pub` 为 `No issues found!`。本次仅新增方案文档，代码治理尚未实施。
- 2026-07-13：Android 采购汇总无变化更新误报修复完成；`flutter analyze` 为 `No issues found!`。该问题依赖 MySQL 对无变化 UPDATE 的返回语义，待真机连接 MySQL 回归确认。
- 2026-07-13：Windows 方法级治理批次 5 完成。新增 4 个 `PatientSyncLogHelper` 测试；全量 `flutter test` 68 个通过，`flutter analyze` 为 `No issues found!`，`git diff --check` 与 LF 行尾检查通过；五类同步日志手动回归已确认。
- 2026-07-13：Windows 方法级治理批次 1～4 完成。全量 `flutter test` 64 个通过，`flutter analyze` 为 `No issues found!`；设置、备份恢复、数据源切换、数据库/模板/材料类型高风险回归已确认。
- 2026-07-13：Android 无用代码治理批次 3A 完成。删除旧财务清理文件及 30 个无调用方法；`flutter analyze` 为 `No issues found!`，`git diff --check` 与 LF 行尾检查通过。
- 2026-07-13：Android 无用代码治理批次 4 完成。删除 2 个一次性迁移文件和 8 个无消费者备份／数据库旧入口；Windows Flutter `flutter analyze` 为 `No issues found!`；SQLite／MySQL 的备份恢复、旧库升级和连接回归已确认通过。
- 2026-07-13：Android 无用代码治理批次 5 完成。删除采购页空焦点／生命周期监听链；Windows Flutter `flutter analyze` 为 `No issues found!`，`git diff --check` 通过；采购页首次、下拉、增删改和前后台刷新回归已确认。

## 维护规则

- 只有已实现并验证的事项进入“完成”；未确认信息放入“待办与阻塞”。
- 详细执行过程不再重复保存在本文件；使用模块内最终总结文档和 Git 历史追溯。

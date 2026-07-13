# Android 端无用代码与重复逻辑后续治理实施方案

方案日期：2026-07-13。

状态：实施中。批次 1A、1B、2A～2C 已完成；批次 3 待实施。

本文承接 [Android 端无用代码与重复实现治理总结](android_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md)，记录 2026-07-13 再次复审发现的遗漏项、实施批次、风险边界、进度和验收方式。本文的总进度表和批次实施结果代表当前完成状态；未标记为已完成的内容仍不代表已经删除，也不替代实施当日的引用复核。

## 1. 结论

上轮治理完成后仍存在以下剩余项：

1. `user_data_source.dart`、`purchase_data_source.dart` 中保留了大段旧数据源实现，其中既有注释代码，也有被现用导入明确隐藏的活代码实现。
2. 仍有无消费者 UI 类型、公共方法、getter 和主题常量；Flutter Analyzer 不会报告这些 public API。
3. 存在一个无引用图片、两个高概率过期的一次性脚本，以及三个可复核移除的直接依赖。
4. 财务新增／编辑弹窗、牙齿状况展示和多个统计图表仍有现用重复逻辑，但它们不是死代码，且当前项目没有自动化测试，不应混入纯删除批次。
5. 272 个 Dart 文件均可从应用入口建立静态可达关系；本轮没有确认可直接删除的完整 Dart 文件。

因此，根目录 `ROADMAP.md` 中 Android 端后续治理状态应以本文为准：批次 2A～2C 已完成；批次 3 仍待实施。

## 2. 目标与非目标

### 2.1 目标

1. 删除已经确认没有消费者的注释旧实现、活代码旧实现、类型、方法、getter 和常量。
2. 清理由删除产生的孤儿 import、依赖和配置项。
3. 在主人明确确认删除文件后，清理无引用资源和一次性工具脚本。
4. 保持 SQLite/MySQL 用户、患者、采购、备份恢复、同步和现有 UI 行为不变。
5. 将现用重复逻辑单独列为专项候选，只有测试和验收条件满足后再实施。

### 2.2 非目标

本方案不包含以下工作：

- 不修改 Windows 端代码。
- 不改变数据库 schema，不执行数据迁移。
- 不统一 MySQL `ResultRow` 的日期、Blob、UTF-8 或图片转换语义。
- 不重构 MySQL 连接生命周期、缓存回退或断线重连架构。
- 不因删除死代码顺手调整主题、页面布局、命名或业务流程。
- 不在缺少测试的情况下直接抽取财务表单、牙位图或统计图表公共组件。

## 3. 复审基线与证据

复审范围：

- `android_app/lib/`。
- `android_app/test/`；复审时该目录没有 Dart 测试文件。
- `android_app/assets/`。
- `android_app/tools/`。
- `android_app/pubspec.yaml`、`pubspec.lock` 和 Android 原生资源引用。

已完成的只读检查：

- 共检查 272 个 Dart 文件。
- 从 `lib/main.dart` 和测试入口建立 import/export/part 静态引用图，没有发现不可达 Dart 文件或除入口外零入站引用的 Dart 文件。
- 对 public 类型、方法、getter 和静态常量执行去除注释后的全仓精确词法引用计数。
- 检查 `hide`、`show`、同名实现、整块注释代码和资源路径。
- 对跨文件重复代码执行连续代码块比对，并人工排除构造器、State 类和框架回调等误报。
- 执行 `cmd.exe /c flutter analyze --no-pub`，结果为 `No issues found!`，耗时 13.2 秒。
- 执行 `git diff --check`，当前工作区没有空白错误。

基线注意事项：

- 复审时 `lib/providers/purchase_provider.dart` 已有主人未提交的 10 行改动；本文按当前工作区取证，没有修改或覆盖该文件。
- Flutter Analyzer 不会报告未使用的 public API、被注释的旧实现、无引用资源或冗余直接依赖，因此静态检查通过不代表本方案候选不存在。
- Dart/Flutter 不依赖运行时反射调用这些 public 方法；本文所列“仅声明一次”的候选在应用仓库中没有静态消费者。

## 4. 总体实施原则

1. 每个批次开始前重新执行本文列出的 `rg` 命令；出现新消费者时，立即从该批次移除对应候选。
2. 先删除纯注释和无消费者类型，再处理数据源旧实现，最后处理连接、同步等较高风险 public API。
3. 一个批次只处理表格中明确列出的内容，不格式化无关文件。
4. 删除文件、图片或脚本属于红线操作；实施批次 3B 前必须取得主人确认。
5. 修改 `pubspec.yaml` 后使用 `flutter pub get` 更新锁文件；不手工编辑 `pubspec.lock`。
6. 数据源、连接、同步和备份相关修改必须完成对应 SQLite/MySQL 人工回归；`flutter analyze` 不能替代真实数据验证。
7. 任一批次自动验证失败时停止后续批次，先定位根因，不使用 `ignore`、默认值或注释报错绕过。
8. 只有实现并完成规定验证的事项才能在本文进度表、治理总结和 `ROADMAP.md` 中标记为已完成。
9. 批次 4 是现用逻辑重构专项，未满足测试前置条件时保持暂缓，不以减少代码行数为由实施。

## 5. 总进度表

状态定义：`已完成` 表示代码或文档已经实现并完成规定验证；`待人工回归` 表示代码实施和自动验证已完成，但规定的人工回归尚未确认；`待实施` 表示已有明确方案但尚未修改；`待确认` 表示实施前需要主人授权；`暂缓` 表示前置条件尚不满足。

| 批次 | 内容 | 风险 | 文件删除 | 当前状态 | 完成日期 | 验证记录 |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | 复审、引用图和基线静态检查 | 低 | 否 | 已完成 | 2026-07-13 | 272 个 Dart 文件已检查；`flutter analyze --no-pub` 通过 |
| 1A | 删除用户／采购数据源注释旧实现 | 低 | 否 | 已完成 | 2026-07-13 | 删除 876 行注释旧实现；格式化、静态检查、diff 和 LF 行尾检查通过 |
| 1B | 删除采购接口文件内无消费者 MySQL 旧实现 | 中 | 否 | 已完成 | 2026-07-13 | 删除 356 行旧 MySQL 实现并清理冗余 import／`hide`；静态检查、diff 和 LF 行尾检查通过；无 Dart 测试文件 |
| 2A | 删除无消费者 UI 类型、备份函数和孤儿 import | 低 | 否 | 已完成 | 2026-07-13 | 候选及孤儿 import 已清理；格式化、静态检查、diff 和 LF 行尾检查通过；主人确认按现有验证完成 |
| 2B | 删除无读取 getter、模型辅助方法和主题常量 | 低至中 | 否 | 已完成 | 2026-07-13 | getter／字段读写链已复核清理；格式化、静态检查、diff 和 LF 行尾检查通过；主人确认按现有验证完成 |
| 2C | 删除连接、同步、初始化服务中的无调用 public API | 中至高 | 否 | 已完成 | 2026-07-13 | 候选、回调及递归孤儿链已清理；格式化、静态检查、diff 和 LF 行尾检查通过；主人确认按现有验证完成 |
| 3A | 清理冗余直接依赖并更新锁文件 | 中 | 否 | 待实施 | — | — |
| 3B | 删除无引用图片和一次性工具脚本 | 低 | 是 | 待确认 | — | — |
| 4A | 财务新增／编辑表单重复逻辑专项 | 中至高 | 否 | 暂缓 | — | 缺少表单测试 |
| 4B | 牙齿状况展示重复逻辑专项 | 高 | 否 | 暂缓 | — | 缺少牙位数据对照测试 |
| 4C | 图表骨架与日期区间逻辑专项 | 中 | 否 | 暂缓 | — | 收益不足，等待相关页面改版或测试补齐 |
| 5 | 全量验证、人工回归和文档收口 | 中 | 否 | 待实施 | — | — |

## 6. 批次 0：复审与基线确认（已完成）

### 6.1 已完成事项

1. 读取根目录和 Android 子项目 `AGENTS.md`、原治理总结及 `ROADMAP.md`。
2. 盘点 Dart、资源、工具和依赖文件。
3. 建立文件级静态引用图。
4. 对 public 符号进行引用计数，并对低次数候选逐一打开调用上下文。
5. 检查工作区已有改动，确认本轮只读审核没有覆盖主人修改。
6. 完成基线 `flutter analyze --no-pub`。

### 6.2 后续实施前必须重跑

在 `android_app/` 目录执行：

```bash
git status --short
cmd.exe /c flutter analyze --no-pub
```

若实施时已经存在测试，再同时执行：

```bash
cmd.exe /c flutter test --no-pub
```

## 7. 批次 1A：删除数据源注释旧实现

### 7.1 候选范围

| 文件 | 行范围（复审时） | 内容 | 现用替代 |
| --- | --- | --- | --- |
| `lib/data_sources/user_data_source.dart` | 22～741 | 整块注释掉的 SQLite/MySQL 用户数据源旧实现 | `sqlite_user_data_source.dart`、`mysql_user_data_source.dart` |
| `lib/data_sources/purchase_data_source.dart` | 33～188 | 整块注释掉的 SQLite 采购数据源旧实现 | `sqlite_purchase_data_source.dart` |

### 7.2 实施步骤

1. 重新确认注释块边界，防止误删抽象接口。
2. 保留 `UserDataSource`、`PurchaseDataSource` 的抽象方法定义。
3. 删除两个完整块注释及仅用于说明旧实现的空行、失效注释。
4. 不调整接口方法顺序、返回值或参数。
5. 删除后检查两个文件的 import；只删除因旧注释代码产生且当前活代码不需要的 import。

### 7.3 删除前复核

```bash
rg -n '^\s*/\*|^\s*\*/' lib/data_sources/user_data_source.dart lib/data_sources/purchase_data_source.dart
rg -n 'class (SqliteUserDataSource|MySqlUserDataSource|SqlitePurchaseDataSource)' lib/data_sources
```

### 7.4 验证

```bash
cmd.exe /c dart format lib/data_sources/user_data_source.dart lib/data_sources/purchase_data_source.dart
cmd.exe /c flutter analyze --no-pub
git diff --check
git ls-files --eol -- lib/data_sources/user_data_source.dart lib/data_sources/purchase_data_source.dart
```

该批次只删除注释，不改变运行时行为，不单独要求业务人工回归。

### 7.5 实施结果

2026-07-13 已完成。重新复核注释边界及同名实现后，删除用户数据源 720 行、采购数据源 156 行注释旧实现，仅保留两个抽象接口。定向格式化无额外改动，`flutter analyze --no-pub`、`git diff --check` 和 LF 行尾检查通过。

## 8. 批次 1B：删除采购接口文件内无消费者 MySQL 旧实现

### 8.1 候选与证据

候选：`lib/data_sources/purchase_data_source.dart` 第 191～546 行的 `MySqlPurchaseDataSource`。

证据链：

1. `PurchaseProvider` 导入 `purchase_data_source.dart` 时显式使用 `hide MySqlPurchaseDataSource`。
2. Provider 实际实例化 `lib/data_sources/mysql_purchase_data_source.dart` 中的同名实现。
3. `PurchaseInitializationService` 也直接导入独立的 SQLite/MySQL 实现文件。
4. 其他数据源只从接口文件获取 `PurchaseDataSource` 抽象类型，没有实例化接口文件内的旧 MySQL 类。
5. 两套 MySQL 实现包含大量相同 SQL 和行转换逻辑，继续并存会造成误改旧实现的风险。

### 8.2 实施步骤

1. 精确列出 `purchase_data_source.dart` 的所有 import 方：

```bash
rg -n "purchase_data_source\.dart|\bMySqlPurchaseDataSource\b" lib test
```

2. 确认所有构造点都解析到独立文件中的 `MySqlPurchaseDataSource`。
3. 删除接口文件内整套旧 MySQL 类，只保留 `PurchaseDataSource` 抽象接口。
4. 从 `PurchaseProvider` 导入中删除已经不需要的 `hide MySqlPurchaseDataSource`。
5. 清理接口文件中仅为旧实现服务的 `mysql1`、`dart:convert`、`dart:typed_data`、`DateTimeFormatter`、`AppLogger` 等 import。
6. 不修改独立 MySQL 实现中的 SQL、行转换、事务或汇总更新逻辑。

### 8.3 自动验证

```bash
cmd.exe /c dart format lib/data_sources/purchase_data_source.dart lib/providers/purchase_provider.dart
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub
git diff --check
git ls-files --eol -- lib/data_sources/purchase_data_source.dart lib/providers/purchase_provider.dart
```

如果实施时仍没有测试目录，记录“无自动化测试”，不得写成测试通过。

### 8.4 人工回归

SQLite 和 MySQL 分别执行：

- 打开采购列表并加载记录。
- 新增含一个项目和多个项目的采购单。
- 编辑采购单及项目数量、单价、总额。
- 删除采购项目和采购单。
- 搜索、日期筛选、医生筛选和统计汇总。
- MySQL 下验证“汇总值未变化”的更新仍按成功处理。

### 8.5 实施结果

2026-07-13 已完成代码实施和自动验证。所有构造点均确认使用独立文件中的现用 `MySqlPurchaseDataSource`；接口文件内 356 行旧实现及其专用 import 已删除，`PurchaseProvider` 的冗余 `hide MySqlPurchaseDataSource` 已移除，独立实现的 SQL、转换和事务逻辑未修改。

定向格式化无额外改动，`flutter analyze --no-pub`、`git diff --check` 和 LF 行尾检查通过。`test/` 下没有 Dart 测试文件，因此未执行 `flutter test`，不记为测试通过。SQLite／MySQL 采购人工回归未执行；主人已确认本批次按现有验证结果标记完成。

## 9. 批次 2A：删除无消费者 UI 类型和备份函数

### 9.1 候选

| 文件 | 候选 | 证据与保留边界 |
| --- | --- | --- |
| `lib/theme/app_theme.dart` | `AppCard` | 业务页面使用 `lib/widgets/app_card.dart`，多处导入主题时显式 `hide AppCard` |
| 同上 | `PrimaryButton` | 全仓只有类声明和构造函数 |
| 同上 | `SecondaryButton` | 全仓只有类声明和构造函数 |
| `lib/utils/permission_utils.dart` | `PermissionButton` | 全仓只有类声明和构造函数；保留现用 `PermissionWrapper` 和权限工具 |
| `lib/widgets/app_card.dart` | `saveBackupWithSaf` | 只有声明，没有调用；保留现用 `AppCard` |

### 9.2 实施步骤

1. 重新搜索五个候选名称，并结合文件路径区分两个同名 `AppCard`。
2. 删除主题文件中的三个组件，不删除主题 token。
3. 删除 `PermissionButton`，保留其他权限组件和权限提示逻辑。
4. 删除 `saveBackupWithSaf`。
5. 检查 `app_card.dart` 中 `flutter_file_dialog`、`intl` import；若只为已删除函数服务则一并删除。
6. 删除页面中不再必要的 `hide AppCard`，但只修改确实因此产生冗余的导入组合，不调整页面 UI。

### 9.3 验证

```bash
cmd.exe /c dart format lib/theme/app_theme.dart lib/utils/permission_utils.dart lib/widgets/app_card.dart
cmd.exe /c flutter analyze --no-pub
git diff --check
```

人工冒烟：用户详情、患者详情、预约详情、病历详情、采购详情和财务卡片正常显示；权限不足提示和权限包装组件正常。

### 9.4 实施结果

2026-07-13 已完成代码实施和自动验证。删除主题文件内无消费者的 `AppCard`、`PrimaryButton`、`SecondaryButton`，删除 `PermissionButton` 和 `saveBackupWithSaf`，同步清理后者的两个专用 import 以及 6 处冗余 `hide AppCard`。现用 `widgets/app_card.dart` 中的 `AppCard`、`PermissionWrapper` 和权限提示逻辑均保留。

定向格式化完成，`flutter analyze --no-pub`、`git diff --check` 和 LF 行尾检查通过。项目没有 Dart 测试文件；UI 与权限人工冒烟未执行，主人确认按现有验证将本批次标记为已完成。

## 10. 批次 2B：删除无读取模型辅助、getter 和主题常量

### 10.1 模型与工具候选

实施前逐一精确搜索，仍只有声明时删除：

| 文件 | 候选 |
| --- | --- |
| `lib/models/database_models.dart` | `originalPhone` getter |
| `lib/models/medical_record_template.dart` | `fullDisplayName`、`isMainType`、`isSubType` getter；`getCategoryName`、`getCategoryEnglishName`、`isValidCategory` |
| `lib/models/user.dart` | `permissionMap` getter |
| `lib/utils/map_parser.dart` | `doubleOptional` |
| `lib/features/medical_records/utils/dental_condition_integration.dart` | `getAvailableDates` |
| `lib/theme/app_theme.dart` | `smallPadding`、`largePadding`、`headingStyle` |

### 10.2 Provider、状态和日志 getter 候选

| 文件 | 候选 |
| --- | --- |
| `lib/providers/app_state.dart` | `refreshCounter` |
| `lib/providers/database_provider.dart` | `dashboardNeedsRefresh`、`hasConnectionIssues`、`connectionStatusText`、`connectionStatusIcon`、`connectionPool`、`configDbType`、`currentDbTypeDescription` |
| `lib/providers/financial_provider.dart` | `financialsNeedRefresh` |
| `lib/providers/material_provider.dart` | `materialsNeedRefresh` |
| `lib/providers/user_provider.dart` | `usersNeedRefresh` |
| `lib/services/mysql_reconnect_service.dart` | `reconnectAttempts` |
| `lib/utils/connection_manager.dart` | `isNetworkMonitoringAvailable` |
| `lib/utils/sync_logger.dart` | `formattedTime`、`statusText`、`statusColor` |
| `lib/utils/sync_table_config.dart` | `syncTableCount` |
| `lib/features/appointments/providers/appointment_cache_mixin.dart` | `appointmentsNeedRefresh`、`cachedAppointmentsCount` |

### 10.3 实施边界

1. getter 无消费者不等于其底层字段无用途；先删 getter，再检查字段读写关系。
2. 只有字段也完全成为孤儿时才删除字段及专用写入方法。
3. `dashboardNeedsRefresh`、`financialsNeedRefresh`、`materialsNeedRefresh`、`usersNeedRefresh`、`appointmentsNeedRefresh` 涉及刷新状态；必须绘制“字段—写入—读取”链，避免留下只写不读状态。
4. 不改变模型 `toMap`、`fromMap`、JSON 键名或数据库列。
5. 不删除 `MapParser.doubleValue` 等仍有消费者的相邻方法。

### 10.4 验证

- 格式化本批次实际修改的 Dart 文件。
- `flutter analyze --no-pub` 通过。
- 有测试时运行全量测试。
- 人工回归 Dashboard、预约、患者、用户、材料和财务列表首次加载及增删改后的刷新。
- 验证同步日志页面状态文字、时间和颜色仍由现用路径正常生成。

### 10.5 实施结果

2026-07-13 已完成代码实施和自动验证。删除本节列出的无读取模型辅助方法、getter 和主题常量；按“字段—写入—读取”链同步清理只写不读的刷新字段、连接池／配置字段及启动结果字段，保留原有 `notifyListeners()` 通知、缓存失效、重连计数内部逻辑、模型序列化和数据库字段语义。

定向格式化完成，`flutter analyze --no-pub`、`git diff --check` 和 LF 行尾检查通过。项目没有 Dart 测试文件；Dashboard、预约、患者、用户、材料、财务与同步日志人工回归未执行，主人确认按现有验证将本批次标记为已完成。

## 11. 批次 2C：删除连接、同步和初始化服务中的无调用 API

该批次涉及数据库和连接语义，风险高于普通 public 方法删除。建议按 2C-1～2C-4 分小提交执行，每个小批次都重新静态检查。

### 11.1 候选清单

| 子批次 | 文件 | 候选 | 风险关注点 |
| --- | --- | --- | --- |
| 2C-1 | `lib/providers/mysql_connection_pool.dart` | `checkHealth`、`getDetailedStats` | 连接池监控和诊断入口 |
| 2C-1 | `lib/utils/connection_manager.dart` | `checkConnection` | 手动连接检查入口 |
| 2C-2 | `lib/services/database_sync_service.dart` | `checkAndSyncData` | 定时／启动同步入口 |
| 2C-2 | `lib/services/mysql_reconnect_service.dart` | `setOnReconnectFailed`、`resetReconnectState` | 重连失败提示和状态复位 |
| 2C-3 | `lib/services/mysql_connection_service.dart` | `initWithParams`、`resetConnection` | 登录、切库和连接初始化 |
| 2C-3 | `lib/services/sqlite_initialization_service.dart` | `ensureDatabasePath` | SQLite 路径创建和配置保存 |
| 2C-4 | `lib/utils/database_operation_wrapper.dart` | `wrapQuery`、`wrapInsert`、`wrapUpdate`、`wrapDelete` | 数据库操作重试包装 |

### 11.2 删除前复核

```bash
rg -n "\b(checkHealth|getDetailedStats|checkConnection|checkAndSyncData|setOnReconnectFailed|resetReconnectState|initWithParams|resetConnection|ensureDatabasePath|wrapQuery|wrapInsert|wrapUpdate|wrapDelete)\b" lib test
```

复核要求：

1. 逐个名称确认唯一命中是声明，而不是接口实现、框架回调、函数 tear-off 或动态注册。
2. 检查构造函数中是否将候选作为回调保存。
3. 检查文档和原生层是否通过 MethodChannel 字符串调用；当前复审未发现，但实施当日仍需确认。
4. 删除方法后递归检查其私有调用链、字段和 import；只删除由该入口产生的孤儿。

### 11.3 专项人工回归

SQLite：

- 首次启动和数据库路径初始化。
- 登录、退出、切换 SQLite 数据库。
- 患者、预约、财务、材料、用户和采购基本查询。
- 备份与恢复。

MySQL：

- 正确配置连接、错误配置提示、断网后恢复。
- 登录和数据库切换。
- 连接池获取、释放和关闭。
- 同步开关、手动同步和同步日志。
- CRUD 操作出现连接异常时的重试和错误提示。

任一入口依赖候选方法时，停止该候选，不通过复制逻辑或添加兼容包装继续删除。

### 11.4 实施结果

2026-07-13 已完成 2C-1～2C-4 的代码实施和自动验证。全仓及原生层复核确认候选没有调用、tear-off、动态注册或 MethodChannel 字符串入口；删除本节列出的 13 个无调用 API，并递归清理仅由它们消费的 `getPoolStats`、`SyncManager.checkAndSync`、失败回调字段和只写不读的活动连接计数。现用连接池获取／释放／关闭、`forceDataSync`、连接健康监控、自动重连、SQLite 初始化和通用 `wrapOperation` 均保留。

定向格式化完成，`flutter analyze --no-pub`、`git diff --check` 和 LF 行尾检查通过。项目没有 Dart 测试文件；SQLite／MySQL 专项人工回归未执行，主人确认按现有验证将本批次标记为已完成。

## 12. 批次 3A：清理冗余直接依赖

### 12.1 候选

| 依赖 | 当前证据 | 处理建议 |
| --- | --- | --- |
| `flutter_phoenix` | 无 package import，无 `Phoenix` 调用 | 从 `pubspec.yaml` 删除 |
| `sqflite_common_ffi` | 无 package import，无 `sqfliteFfiInit` 或 `databaseFactoryFfi`；Android 端不使用 Windows FFI | 从 `pubspec.yaml` 删除 |
| `cross_file` | 无直接 import；`XFile` 由 `file_selector` 重导出 | 删除直接依赖，允许其作为传递依赖保留在锁文件 |

保留：

- `cupertino_icons`：项目大量使用 `CupertinoIcons`，其字体资源不能按“无显式 import”直接删除。
- `flutter_file_dialog`：病历 PDF 和患者导出仍在使用。
- `file_selector`：数据库选择和恢复仍在使用。

### 12.2 实施步骤

1. 重新搜索依赖名和代表性 API。
2. 仅删除 `pubspec.yaml` 中确认无直接用途的三项依赖。
3. 在 Android 子项目执行 `cmd.exe /c flutter pub get` 更新 `pubspec.lock` 和插件元数据。
4. 审查生成差异，确认没有意外升级其他依赖。
5. 若 `pub get` 导致无关大范围锁文件升级，停止并定位环境或约束原因。

### 12.3 验证

```bash
cmd.exe /c flutter pub get
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub
git diff --check
```

人工回归：启动应用、选择数据库文件、备份恢复、病历 PDF 导出、患者导出、所有使用 Cupertino 图标的预约和患者信息卡片。

## 13. 批次 3B：删除无引用资源和一次性工具脚本

该批次涉及删除文件，实施前必须取得主人确认。

### 13.1 候选文件

| 文件 | 证据 | 风险 |
| --- | --- | --- |
| `assets/images/login.jpg` | `lib/`、`test/`、`pubspec.yaml`、Android 原生配置均无路径引用；现用图片为 `login_clinical_console.png` | 低，需启动页和登录页确认 |
| `tools/fix_string_null_assertions.py` | 无文档或脚本引用；硬编码当前电脑绝对路径；属于一次性批量替换脚本 | 低，但需确认是否作为历史工具保留 |
| `tools/fix_ui_patterns.py` | 无文档或脚本引用；硬编码当前电脑绝对路径；属于一次性批量替换脚本 | 低，但需确认是否作为历史工具保留 |

### 13.2 实施步骤

1. 说明将删除的三个文件、路径和风险，取得主人明确确认。
2. 再次搜索完整路径、文件名和图片 basename。
3. 删除文件。
4. `pubspec.yaml` 当前按目录声明 `assets/images/`，无需因删除单张图片调整 assets 配置。
5. 不删除 `tools/` 目录；未来仍可放置有明确用途和相对路径的维护脚本。

### 13.3 验证

- `flutter analyze --no-pub` 通过。
- 应用登录页和 Dashboard 欢迎区图片正常。
- `git diff --check` 通过。
- 使用 `git status --short` 确认只删除获批文件。

## 14. 批次 4：现用重复逻辑专项（暂缓）

### 14.1 4A：财务新增／编辑表单

重复位置：

- `lib/features/financial/widgets/financial_item_add_dialog.dart`。
- `lib/features/financial/widgets/financial_item_edit_dialog.dart`。

复审发现两文件存在多段 15～30 行完全相同代码，覆盖控制器初始化、金额输入、项目选择、表单布局和校验。

推荐方向：抽取不持有提交行为的共享表单主体或字段 section，由新增／编辑弹窗分别管理初始值、保存调用和成功提示。

实施前置：

1. 为新增和编辑分别建立 widget 测试或等价回归测试。
2. 覆盖空名称、无效金额、项目类型切换、保存成功、保存失败和弹窗关闭。
3. 先记录当前焦点、键盘和窄屏滚动行为。

当前结论：暂缓，不作为死代码批次执行。

### 14.2 4B：牙齿状况展示

重复位置：

- `lib/features/patients/widgets/patient_dental_condition_display.dart`。
- `lib/screens/medical_record_detail_screen.dart`。

两处存在多段 18～32 行完全相同的牙位图、象限和备注展示代码。

推荐方向：先定义统一输入模型，明确历史牙位数据、当前病历数据、空值、日期和备注语义，再抽取纯展示组件。

实施前置测试至少覆盖：

- 四象限都有数据。
- 单个象限为空。
- 历史多日期数据。
- 旧格式 Map 键缺失或值为 null。
- 病历详情与患者详情展示结果一致。

当前结论：高风险暂缓，不能仅凭代码相同直接抽取。

### 14.3 4C：图表和日期范围

候选包括：

- `monthly_processing_chart.dart` 与 `monthly_trend_chart.dart` 的图表骨架。
- 财务统计弹窗与采购统计页面的日期范围计算和空状态。
- 财务／采购多个统计卡片的标题、容器和加载结构。

当前收益主要是视觉和结构一致性，未发现现行业务缺陷。等待统计页改版或相关测试补齐后另立方案，不纳入本轮清理。

## 15. 批次 5：全量验证与文档收口

### 15.1 自动验证

在 `android_app/` 目录执行：

```bash
cmd.exe /c flutter analyze --no-pub
cmd.exe /c flutter test --no-pub
git diff --check
git status --short
```

对所有本轮修改的文本文件执行：

```bash
git ls-files --eol -- <modified-files>
```

结果中不得出现 `w/crlf` 或 `w/mixed`。

### 15.2 人工回归矩阵

| 模块 | SQLite | MySQL | 关键检查 |
| --- | --- | --- | --- |
| 启动与登录 | 必测 | 必测 | 首次启动、记住密码、退出、错误连接提示 |
| 数据库切换 | 必测 | 必测 | 切换成功、取消、失败恢复 |
| 用户 | 必测 | 必测 | 登录、列表、增删改、权限 |
| 患者 | 必测 | 必测 | 列表、搜索、分页、图片、详情 |
| 预约 | 必测 | 必测 | 列表、日历、增删改、刷新 |
| 采购 | 必测 | 必测 | 单项目、多项目、统计、导出、无变化更新 |
| 财务与材料 | 必测 | 必测 | 查询、增删改、统计和刷新 |
| 病历 | 必测 | 必测 | 模板、牙位数据、PDF 导出 |
| 备份恢复 | 必测 | 必测 | 备份、恢复、取消、错误提示 |
| 同步与重连 | 不适用或按现行行为 | 必测 | 手动同步、断网、恢复、日志 |

### 15.3 文档收口

全部已实施批次通过验证后：

1. 更新本文总进度表、完成日期和验证记录。
2. 更新原治理总结，说明复审发现和最终处理结果；不要继续保留“无死代码待办”的旧结论。
3. 更新根目录 `ROADMAP.md` 的 Android 当前状态、待办和最近验证。
4. 未实施或未验证的批次继续标记为“待实施”“待确认”或“暂缓”，不得写入“已完成”。

## 16. 建议提交边界

建议按以下边界提交，避免风险混杂：

1. `refactor: 清理安卓用户和采购数据源旧实现`
2. `refactor: 清理安卓无消费者组件与公共接口`
3. `refactor: 清理安卓连接同步无调用入口`
4. `chore: 清理安卓冗余依赖与过期资源`
5. `docs: 更新安卓无用代码治理实施进度`

提交前必须确认每个提交只包含对应批次文件，不得带入主人已有的 `purchase_provider.dart` 或 Windows 端未提交改动，除非该文件确实属于已确认执行的批次。

## 17. 完成标准

本方案只有同时满足以下条件才能标记为完成：

1. 批次 1～3 的所有实际实施项均完成引用复核和自动验证。
2. 文件删除均已获得主人明确确认。
3. SQLite/MySQL 专项人工回归均有明确结果；未执行不能写“通过”。
4. 没有因删除产生孤儿 import、字段、私有方法、依赖或配置。
5. `flutter analyze --no-pub` 无问题；存在测试时全量测试通过。
6. `git diff --check` 和改动文本文件 LF 行尾检查通过。
7. 原治理总结、本文进度表和根目录 `ROADMAP.md` 状态一致。
8. 批次 4 未满足前置条件时保持暂缓，不影响批次 1～3 的清理完成判定。

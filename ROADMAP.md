# ROADMAP

## 当前状态

### Windows 端

- Windows 端第二轮代码审核整改正在实施：进度 1、2 已完成代码与自动验证。密码写入、默认管理员和登录认证均统一为 PBKDF2-HMAC-SHA256；历史 SHA-256、MD5 与明文仅保留兼容验证，并会在成功登录后升级。固定密码不再可绕过任意账户认证，完整范围见 [审核整改执行方案](windows_app/docs/windows_app_code_audit_remediation_plan_2026_07_19.md) 。
- Windows 端高风险复审整改方案已建立：覆盖患者权限、采购／预约失败关闭、MySQL 删除与恢复原子性和登出会话清理；持久化同步任务已从方案删除，详见 [高风险整改方案](windows_app/docs/windows_app_high_risk_remediation_plan_2026_07_19.md) 。
- Windows 端高风险复审整改批次 0～2 已完成：患者 SQLite／MySQL 全量、分页、搜索和按 ID 读取统一失败关闭；采购与预约缺少身份、权限 Provider 或医生字段时均拒绝访问，用户切换会失效相关缓存。主人确认按自动验证完成，详见 [高风险整改方案](windows_app/docs/windows_app_high_risk_remediation_plan_2026_07_19.md) 。
- Windows 端审核整改进度 4 已完成：财务患者聚合、收费明细、计数与分页已统一按医生权限过滤；缺少用户身份或医生字段时失败关闭并返回空结果。主人确认按自动验证完成。
- Windows 端审核整改进度 5 已完成：采购搜索改为 350ms 防抖并只采纳最新请求，采购页与材料页异步结束后均保护页面生命周期；主人确认按自动验证完成。
- Windows 端第二轮代码审核整改进度 1～7 已全部完成：认证安全、财务权限、采购异步生命周期、冗余 API 与重复通知均已整改并通过自动验证；主人确认按现有验证完成。
- 无用代码与重复逻辑治理已完成：删除 39 个不可达 Dart 文件、方法级无调用 API 与无消费者委托链；五套患者同步服务已通过 `PatientSyncLogHelper` 收口。最终状态见 [治理总结](windows_app/docs/windows_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 2026-07-13 复审后续治理批次 0～5 的代码实施和自动验证已完成：清理无消费者代码与 9 项无用直接依赖，采购图片导出统一由 `PurchaseExportService` 编排，四模块 MySQL 连接统一由 `ModuleMysqlConnectionService` 管理。最终状态见 [后续治理实施方案](windows_app/docs/windows_app_dead_code_and_duplicate_logic_followup_implementation_plan_2026_07_13.md) ；人工 UI／功能回归待确认。
- 图表组件抽取、财务查询对象和 schema 模板重构均已暂缓：当前收益不足以覆盖跨模块行为风险，不是遗留缺陷。
- 主题治理、SQLite/MySQL 数据源与备份恢复、患者 SQLite → MySQL 同步规则均已完成；业务变更以对应模块代码和测试为准。

### Android 端

- Android 端现用代码审核已完成，确认权限边界、默认弱密码、用户编辑清空密码、密码算法分裂、采购复合写入、患者删除、配置降级、同步范围、MySQL 直连与系统性硬编码等问题；审核报告和分批整改方案已建立，当前仅完成只读基线，业务整改尚未开始。详见 [审核报告](android_app/docs/android_app_code_audit_report_2026_07_19.md) 和 [整改方案](android_app/docs/android_app_code_audit_remediation_plan_2026_07_19.md) 。
- 采购列表项目数已修复：列表按采购明细条数显示项目数，不再误用总采购数量；自动测试与静态检查通过，待真机确认。
- Android 构建链已迁移至 AGP 9.2／Gradle 9.4.1 和 Built-in Kotlin，`flutter_file_dialog`、`shared_preferences_android` 已升级至兼容实现；debug APK 构建不再输出 Gradle、AGP、Kotlin 或 KGP 兼容性警告。
- 无用代码与重复实现治理已完成批次 0～5；批次 6～7 已暂缓，结论见 [治理总结](android_app/docs/android_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 2026-07-13 后续治理已完成：清理数据源注释旧实现、无消费者 UI／模型／服务 API、冗余直接依赖、无引用登录图片和两份一次性脚本；最终范围、验证和现用重复逻辑处置见 [治理总结](android_app/docs/android_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 登录“记住密码”、新建预约治疗项目窄屏布局、采购录入弹窗键盘适配均已完成代码与针对性静态检查，待人工回归确认。
- 采购汇总无变化时 MySQL 将更新误报为失败的问题已修复：数据源在 `affectedRows = 0` 时验证记录存在性，覆盖单项目、浮点误差和同秒更新时间；待 Android 真机连接 MySQL 回归确认。
- Android MySQL 前后台连接恢复已优化：后台暂停健康检查，前台统一串行重建并验证连接，业务重连与健康检查不会并发关闭／查询同一 socket；待 Android 真机前后台切换回归确认。
- Android 采购图表与详情加载已优化：图表弹窗立即打开并渐进加载采购明细，详情页复用按采购记录缓存的明细数据；采购记录或项目变更时会使缓存失效，待人工回归确认。
- Android 财务详情页异步加载已修复：打开时立即展示详情框架，返回页面后不再对已销毁 State 调用 `setState`；待真机确认。
- Android 财务详情收费记录已补充按记录缓存：重复打开优先复用缓存，收费项目或财务记录变更时失效；待人工回归确认。
- Android 预约与患者详情重复加载已优化：预约详情复用患者缓存和权限查询，患者详情复用患者、图片、财务、病历缓存；待人工回归确认。
- Android 返回手势系统警告已处理：关闭未适配的预测性返回平台回调，保留现有 Flutter 返回行为；待真机确认日志不再重复输出。

## 待办与阻塞

- Windows 端：第二轮审核整改进度 1～7 已完成，主人确认按现有验证收口。高风险整改方案批次 0～2 已完成，批次 3、5 代码完成并待 MySQL 删除／恢复和登出／切换用户人工回归；批次 4（持久化同步任务）已按主人决定从方案删除；批次 6 被既有 `build/test_cache` 编译缓存冲突阻塞。主人明确保留本地“记住用户名密码”，因此密码仍会明文保存于应用偏好文件。此前治理批次 0～5 的启动、提示、权限、用户头像、患者排序、预约刷新、数据源切换、备份恢复、PDF／采购图片导出、文件选择及四模块 SQLite/MySQL 连接与同步人工回归仍待确认。
- Android 端：现用代码审核整改批次 1～6、8 待实施；批次 7（MySQL 架构、网络与原生权限）已从方案删除，应用按受控局域网使用，保留直连 MySQL、现有网络／原生权限和本地“记住密码”方案。默认账号规则已确认，新数据库删除 `staff / 123456` 创建逻辑，只保留经统一密码服务哈希保存的 `admin / 123456`。应先处理权限、密码服务和用户编辑误改密码，再处理采购事务、患者删除与配置同步。数据可见范围和患者删除策略仍需按整改方案在实施前确认。此前后续治理已完成，UI、SQLite、MySQL 及登录／Dashboard 图片人工回归未执行但主人已确认按自动验证完成。财务表单和牙齿状况展示重复逻辑仅随相关需求实施；图表及日期范围不纳入计划，除非统计页改版、需统一产品规则或出现实际缺陷。
- 阻塞：无。

## 最近验证

- 2026-07-19：Windows 端高风险整改批次 3、5 完成代码实施：MySQL 患者删除链路改为事务提交／回滚，不再切换 `FOREIGN_KEY_CHECKS`；MySQL 转储恢复首错即停，并在 `finally` 恢复外键检查；登出跳转前清除用户、权限和业务缓存。`flutter analyze --no-pub` 为 `No issues found!`，`flutter test --no-pub` 在既有 `build/test_cache` 文件冲突的编译阶段失败，未运行测试；`git diff --check` 与 LF 行尾检查通过。批次 3、5 待人工回归，批次 6 阻塞。
- 2026-07-19：Windows 端高风险整改批次 0～2 完成。新增患者 SQLite 权限回归测试，覆盖管理员、医生和无访问身份；患者 SQLite／MySQL 数据源全量读取统一应用医生条件，无用户／无医生身份失败关闭；采购与预约缺少权限上下文时不再放行，身份切换清除缓存。专项 6 项、全量 `flutter test --no-pub` 89 项通过，`flutter analyze --no-pub` 为 `No issues found!`；MySQL 实连与 UI 权限人工回归未执行。
- 2026-07-19：根据受控局域网使用决定，从 Android 整改方案直接删除批次 7（MySQL 架构、网络与原生权限），批次 8 编号保持不变；保留直连 MySQL、现有原生配置和本地“记住密码”方案。本次仅更新文档，未修改代码。
- 2026-07-19：Windows 端高风险复审整改方案创建完成，覆盖患者权限泄漏、权限失败关闭、MySQL 删除／恢复原子性、持久化同步和登出会话清理；本次仅新增方案文档并更新进度，未修改业务代码或执行新的 Flutter 验证。
- 2026-07-19：Android 默认账号整改规则已确认并同步到审核报告与整改方案：删除新数据库的 `staff / 123456` 创建逻辑，只保留 `admin / 123456`；默认 admin 后续必须通过统一密码服务哈希保存，不能作为任意账户的通用密码。本次仅更新文档，业务代码尚未修改。
- 2026-07-19：Android 端现用代码只读审核完成。审核覆盖 272 个 Dart 文件以及 Manifest、网络安全、认证、权限、患者、采购、同步和配置主链路，新增详细审核报告与含进度表的整改方案；`cmd.exe /c flutter analyze` 为 `No issues found!`。本次未修改业务代码，未执行 SQLite／MySQL 写入或真机回归。
- 2026-07-19：Windows 端审核整改进度 7 已完成最终自动验证。`flutter analyze --no-pub` 为 `No issues found!`，全量 `flutter test --no-pub` 75 项通过，`git diff --check` 与本批次改动文件 LF 行尾检查通过；主人确认阶段 7 按现有验证完成，第二轮审核整改方案已收口。
- 2026-07-19：Windows 端审核整改进度 6 完成代码与自动验证。患者详情服务改用现有按记录 ID 查询，移除财务重复委托及无消费者的财务／预约旧分页、计数、统计 API 链；采购记录新增、删除各消除一次重复刷新通知。`flutter analyze --no-pub` 为 `No issues found!`，全量 `flutter test --no-pub` 通过；SQLite/MySQL 人工回归未执行。
- 2026-07-19：Windows 端审核整改进度 5 完成。采购搜索采用 350ms 防抖和请求世代校验，旧请求、异常或已销毁页面均不能更新状态；材料页异步成功与异常路径补齐 `mounted` 检查。`flutter analyze --no-pub` 为 `No issues found!`；现有测试结构未提供可注入的页面异步数据源，未新增脱离实际生命周期的伪测试；主人确认按自动验证完成。
- 2026-07-19：Windows 端审核整改进度 4 完成代码与自动验证。患者聚合、收费项计数和分页明细的医生条件已贯通 QueryService、Provider、接口与 SQLite/MySQL 数据源；用户身份或医生字段缺失时失败关闭。新增 SQLite 权限回归测试覆盖医生甲、管理员和无访问主体，`flutter test --no-pub test/data_sources/sqlite_financial_data_source_permission_test.dart` 3 项通过，`flutter analyze --no-pub` 为 `No issues found!`；SQLite/MySQL 人工回归未执行。
- 2026-07-19：Windows 端审核整改进度 1、2 及本地凭证保留决定完成。登录页改经统一认证服务验证，移除 SQLite/MySQL 内嵌建表、MD5 及固定密码放行；默认管理员创建使用 `PasswordService`，历史密码成功登录后升级。`flutter test --no-pub test/features/users/services/user_validation_service_test.dart test/features/users/services/user_authentication_service_test.dart` 14 项通过，`flutter analyze --no-pub` 为 `No issues found!`；SQLite／MySQL 新安装、旧密码升级和本地凭证重启回填由主人确认按自动验证完成。
- 2026-07-19：Windows 端审核整改进度 1 已开始。新增 `PasswordService`，新写入密码统一为 PBKDF2-HMAC-SHA256，历史 SHA-256、MD5 和明文密码均有受限兼容验证；`UserProvider` 的新增、编辑、注册、重置密码四个入口已收口。`flutter test --no-pub test/features/users/services/user_validation_service_test.dart` 11 项通过，`flutter analyze --no-pub` 为 `No issues found!`；登录认证入口、默认管理员和升级写回尚未实施，未进行人工回归。
- 2026-07-19：Windows 端第二轮代码审核和整改执行方案完成，本次只新增方案文档并更新进度，未修改业务代码。审核确认认证绕过、密码格式分叉、明文凭证、财务权限分页不完整、采购搜索竞态和剩余冗余候选；`flutter analyze --no-pub` 为 `No issues found!`，全量 `flutter test --no-pub` 75 项通过，但现有测试尚未覆盖上述问题。
- 2026-07-14：Android 采购列表项目数修复完成。采购统计在获取明细时按记录 ID 回填明细条数，列表卡片显示该值，总采购量仍按明细数量求和；新增“总数量 82、项目数 2”回归测试。`flutter test --no-pub test/features/purchases/purchase_cache_service_test.dart test/features/purchases/purchase_statistics_service_test.dart` 3 项通过，`flutter analyze --no-pub` 为 `No issues found!`；待真机确认采购列表加载后的项目数。
- 2026-07-13：Android 返回手势警告修复完成。Manifest 将 `android:enableOnBackInvokedCallback` 设为 `false`，避免预测性返回取消路径反复输出 `WindowOnBackDispatcher sendCancelIfRunning`；Flutter `PopScope`／`Navigator` 返回逻辑不受影响，但不再显示预测返回动画。`flutter analyze --no-pub` 为 `No issues found!`；待真机验证系统返回、详情返回和对话框取消。
- 2026-07-13：Android 预约与患者详情缓存优化完成。患者 Provider 增加按 ID 缓存；预约详情首次命中缓存时不再等待患者查询，三个权限控件复用同一 Future；患者详情不再每次清除图片缓存，财务记录按患者缓存，病历记录按患者缓存 5 分钟且手动刷新会失效该患者缓存。财务与采购缓存测试共 4 个通过，`flutter analyze --no-pub` 为 `No issues found!`；待真机验证重复打开预约／患者详情、患者图片与病历刷新、患者财务金额和预约编辑后的数据刷新。
- 2026-07-13：Android 财务详情收费记录缓存完成。`FinancialProvider` 优先返回按财务记录 ID 缓存的明细，数据库查询结果自动回填；新增、编辑收费项目时精准失效对应缓存，删除时清除财务缓存，记录变更沿用全量缓存清除。新增 2 个财务缓存测试；财务与采购缓存测试共 4 个通过，`flutter analyze --no-pub` 为 `No issues found!`；待真机验证重复进入财务详情不重复加载，以及收费项目增删改后的详情刷新。
- 2026-07-13：Android 财务详情页加载与返回异常修复完成。详情页加载时保留页面内容并在收费明细区显示进度，`_loadData()` 在异步查询结束及异常处理前均检查 `mounted`，避免用户加载中返回触发 `setState() called after dispose()`。`flutter analyze --no-pub` 为 `No issues found!`；待真机验证加载中返回、下拉刷新和收费项目增删改后的详情刷新。
- 2026-07-13：Android 采购图表与详情加载优化完成。统计图表不再等待全部明细返回才弹出，改为打开后随明细完成进度刷新；采购明细按记录 ID 缓存 20 分钟，详情首次进入不再重复读取主记录，采购记录／项目变更会先清除缓存再重新计算汇总。新增 2 个缓存回归测试，`flutter test --no-pub test/features/purchases/purchase_cache_service_test.dart` 全部通过，`flutter analyze --no-pub` 为 `No issues found!`；待真机回归图表加载进度、详情重复进入与采购增删改后的金额／明细刷新。
- 2026-07-13：Android MySQL 前后台连接恢复优化完成。后台停止健康监控并移除重复的快速检查，成功轮询不再输出日志；恢复前台时统一重建并验证新连接，重连前等待运行中的健康查询结束，患者图片 Provider 不再重复监听生命周期。`flutter analyze --no-pub` 为 `No issues found!`；项目无 Dart 测试文件，待真机验证后台切回前台后 MySQL 查询、图片读取及断线重连。
- 2026-07-13：Android 登录页底部“技术支持：牙科诊所管理系统”白色文案和横线装饰已移除，避免遮挡底部图片内容；`flutter analyze --no-pub` 为 `No issues found!`。
- 2026-07-13：Android 构建警告治理完成。Gradle Wrapper 从 8.11.1 升至 9.4.1、AGP 从 8.9.1 升至 9.2.0，应用模块移除 KGP 并使用 Built-in Kotlin；`flutter_file_dialog` 升至 3.3.1、`shared_preferences` 升至 2.5.5，锁定的 `shared_preferences_android` 升至 2.4.26。`flutter analyze` 为 `No issues found!`，`flutter build apk --debug` 成功生成 APK，原 Gradle、AGP、Kotlin 和 KGP 兼容性警告未再出现；其余 55 项“存在更高版本但不兼容当前约束”的依赖统计未批量升级。
- 2026-07-13：Android 后续治理批次 3A、3B 已完成。移除 `flutter_phoenix`、`sqflite_common_ffi`、`cross_file` 三项冗余直接依赖，锁文件仅同步移除不再需要的 `flutter_phoenix`、`sqflite_common_ffi`、`sqlite3`，并保留 `cross_file` 的传递依赖；删除无引用的 `assets/images/login.jpg` 和两份硬编码绝对路径的一次性工具脚本。`flutter pub get`、`flutter analyze --no-pub`、`git diff --check` 与改动文本文件 LF 行尾检查通过；项目无 Dart 测试文件，启动、文件选择、备份恢复、PDF／患者导出、Cupertino 图标及登录／Dashboard 图片人工回归未执行。
- 2026-07-13：Android 后续治理批次 2A～2C 已完成。删除无消费者 UI 类型、备份函数、模型辅助、getter、刷新字段，以及连接、同步和初始化服务中的无调用 API 与递归孤儿链；现用通知、缓存失效、连接池、强制同步、健康监控、重连、SQLite 初始化和通用数据库重试逻辑均保留。`flutter analyze --no-pub` 为 `No issues found!`，`git diff --check` 与改动文本文件 LF 行尾检查通过；项目无 Dart 测试文件，UI、SQLite 和 MySQL 人工回归未执行，主人确认按自动验证完成。
- 2026-07-13：Android 后续治理批次 1A、1B 完成。删除用户／采购数据源 876 行注释旧实现和采购接口文件内 356 行无消费者 MySQL 旧实现，清理专用 import 及采购 Provider 冗余 `hide`。修改前后 `flutter analyze --no-pub` 均为 `No issues found!`；`git diff --check` 与改动文本文件 LF 行尾检查通过。项目无 Dart 测试文件；SQLite／MySQL 采购人工回归未执行，主人确认按现有验证结果完成。
- 2026-07-13：Windows 后续治理批次 3～5 的代码实施和自动验证完成。移除 9 项无用直接依赖；新增 `ModuleMysqlConnectionService` 和 7 个行为测试，迁移四个 Provider 并删除四个共 452 行的重复连接 service。`flutter analyze --no-pub` 为 `No issues found!`，全量 `flutter test --no-pub` 75 个通过；`git diff --check` 与改动文本文件 LF 行尾检查通过。人工回归待确认。
- 2026-07-13：Android 无用代码与重复逻辑再次复审完成并形成后续实施方案。复审覆盖 272 个 Dart 文件以及资源、工具和直接依赖，未发现完全不可达 Dart 文件；发现数据源旧实现、无调用 public API、无引用图片和冗余依赖等后续候选。`flutter analyze --no-pub` 为 `No issues found!`；本次仅新增方案文档并更新进度，未修改业务代码。
- 2026-07-13：Windows 后续治理批次 2A、2B、2C 完成。清理独立无调用 API 与 Dashboard 刷新标志链，删除设置侧旧 MySQL 备份 service 文件及无消费者委托，并将采购图片导出收口到 `PurchaseExportService`。`flutter analyze --no-pub` 为 `No issues found!`，备份专项测试 3 个通过，全量 `flutter test --no-pub` 68 个通过；`git diff --check` 与改动文本文件 LF 行尾检查通过。人工回归待确认。
- 2026-07-13：Windows 后续治理批次 0、1A、1B 完成。删除 8 个无消费者旧 UI 类型／类及 1 个仅被 barrel export 的患者排序文件；`AppToastType`、`_ToastConfig` 因仍服务于 `AppToastManager` 保留。基线及修改后 `flutter analyze --no-pub` 均为 `No issues found!`，全量 `flutter test --no-pub` 均为 68 个通过；`git diff --check` 与改动文本文件 LF 行尾检查通过。人工 UI 回归待确认。
- 2026-07-13：Windows 无用代码与重复逻辑复审及后续实施方案完成；复审覆盖 354 个 Dart 文件、public 类型／方法引用和直接依赖，`flutter analyze --no-pub` 为 `No issues found!`。本次仅新增方案文档，代码治理尚未实施。
- 2026-07-13：Android 采购汇总无变化更新误报修复完成；`flutter analyze --no-pub` 为 `No issues found!`。MySQL 数据源在 `affectedRows = 0` 时验证采购记录仍存在，避免单项目、多项目浮点误差或同秒更新时间产生的无变化 UPDATE 被误判为失败；待真机连接 MySQL 回归确认。
- 2026-07-13：Windows 方法级治理批次 5 完成。新增 4 个 `PatientSyncLogHelper` 测试；全量 `flutter test` 68 个通过，`flutter analyze` 为 `No issues found!`，`git diff --check` 与 LF 行尾检查通过；五类同步日志手动回归已确认。
- 2026-07-13：Windows 方法级治理批次 1～4 完成。全量 `flutter test` 64 个通过，`flutter analyze` 为 `No issues found!`；设置、备份恢复、数据源切换、数据库/模板/材料类型高风险回归已确认。
- 2026-07-13：Android 无用代码治理批次 3A 完成。删除旧财务清理文件及 30 个无调用方法；`flutter analyze` 为 `No issues found!`，`git diff --check` 与 LF 行尾检查通过。
- 2026-07-13：Android 无用代码治理批次 4 完成。删除 2 个一次性迁移文件和 8 个无消费者备份／数据库旧入口；Windows Flutter `flutter analyze` 为 `No issues found!`；SQLite／MySQL 的备份恢复、旧库升级和连接回归已确认通过。
- 2026-07-13：Android 无用代码治理批次 5 完成。删除采购页空焦点／生命周期监听链；Windows Flutter `flutter analyze` 为 `No issues found!`，`git diff --check` 通过；采购页首次、下拉、增删改和前后台刷新回归已确认。

## 维护规则

- 只有已实现并验证的事项进入“完成”；未确认信息放入“待办与阻塞”。
- 详细执行过程不再重复保存在本文件；使用模块内最终总结文档和 Git 历史追溯。

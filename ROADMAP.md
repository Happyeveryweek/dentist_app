# ROADMAP

## 当前状态

### Windows 端

- 第二轮代码审核整改、无用代码与重复逻辑治理均已完成；详细结果见 [审核整改方案](windows_app/docs/windows_app_code_audit_remediation_plan_2026_07_19.md) 和 [治理总结](windows_app/docs/windows_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 高风险整改批次 0～2 已完成；批次 3、5 已完成代码，待 MySQL 删除／恢复及登出／切换用户人工回归。批次 6 受既有 `build/test_cache` 编译缓存冲突阻塞，详见 [高风险整改方案](windows_app/docs/windows_app_high_risk_remediation_plan_2026_07_19.md) 。
- 患者默认医生硬编码整改任务 4、6 已完成：新库不再带固定医生默认值，新增患者仅使用当前用户已配置的医生姓名；静态检查和全量测试已通过。既有 SQLite 数据库不做 schema 迁移，不修改其中任何内容；任务 5 待 SQLite／MySQL／登录人工回归，详见 [实施方案](windows_app/docs/windows_app_patient_default_doctor_remediation_plan_2026_07_20.md) 。
- Windows 端硬编码治理补充方案 F1～F4 已完成自动验证：76 个 Provider、初始化器、同步、备份恢复和设置服务的数据源／模式业务决策已改为类型解析后的语义判断；批次 6～9 待人工回归，详见 [补充整改方案](windows_app/docs/windows_app_hardcoded_values_followup_remediation_plan_2026_07_20.md) 。

### Android 端

- 代码审核整改批次 1～7 已完成；批次 7 由主人确认按自动验证收口。新建患者按当前用户的医生姓名设置默认医生，不再写入固定医生。
- 无用代码与重复实现治理已完成；暂缓项及历史依据见 [治理总结](android_app/docs/android_app_dead_code_and_duplicate_logic_governance_summary_2026_07_13.md) 。
- 构建链已迁移至 AGP 9.2、Gradle 9.4.1 与 Built-in Kotlin。
- MySQL 不可用时的登录回退已修复：启动回退、自动同步和登录兜底统一使用配置中的 SQLite 文件，登录前会等待用户认证服务完成 SQLite 绑定；待真机断网回归。

## 待办与阻塞

- Windows：硬编码治理补充方案自动验证已完成，待执行全局／模块化数据源、MySQL 连接失败回退、备份恢复和预约状态人工回归；批次 1、3～5 仍待既定人工回归。既有 SQLite 默认约束清理按主人要求暂缓。另需完成高风险整改批次 3、5 的 MySQL／会话人工回归，并解决批次 6 的 `build/test_cache` 编译缓存冲突。
- Android：待真机或 MySQL 回归的项目包括采购项目数、登录与预约窄屏、采购输入键盘适配、MySQL 前后台恢复、采购／财务／患者详情缓存及返回手势。
- 已确认边界：Android 保持受控局域网直连 MySQL，保留本地“记住密码”和 MySQL 连接失败时回退 SQLite 的行为；患者删除维持现有全部关联数据删除语义。

## 最近验证

- 2026-07-21：Windows 端统一可点击元素鼠标悬停小手光标行为。根因定位为 Flutter 3.44.6 将所有 Material 可点击组件默认光标改为 `WidgetStateMouseCursor.adaptiveClickable`，桌面端解析为箭头（非小手）。修复：①新增公共组件 `widgets/clickable.dart`，迁移 9 处缺失光标的 `GestureDetector` 及 `financial_hoverable_cards` 内层纯光标组合；②在 `app_theme.dart` 主题层为 `ElevatedButton/TextButton/OutlinedButton/IconButton/FilledButton/Checkbox` 及 `PopupMenu` 统一设置 `mouseCursor: WidgetStateMouseCursor.clickable`；③给 43 处裸 `InkWell` 与 1 处 `Switch` 补 `mouseCursor: SystemMouseCursors.click`；④给 11 处 `DropdownButton/DropdownButtonFormField` 补 `mouseCursor` 与 `dropdownMenuItemMouseCursor`，并给 2 处自定义 child 的 `PopupMenuButton`（materials_screen、material_dropdown_container）在 child 内层包 `MouseRegion(cursor: click)`（因 SDK 触发 InkWell 离目标最近、外层 MouseRegion 无效）；⑤给 6 处日期范围选择器（appointment_filter_bar、financial_search_bar、financial_statistics_dialog、purchase_statistics_dialog、patient_statistics_dialog、modern_date_picker 日历单元格）的 `InkWell` 直接补 `mouseCursor: click`，修正之前误判“外层 `MouseRegion(cursor:click)` 已覆盖”实则被 InkWell 默认箭头覆盖的问题（患者管理时间选择因之前直接加了参数而正常）。`flutter analyze` 无问题，未运行应用，待人工鼠标悬停回归（登录按钮、记住密码框、退出登录、分页、对话框按钮、日期选择器、各类下拉框等）。
- 2026-07-20：Windows 登录页体验优化：应用启动后立即展示登录页，数据库与 Provider 初始化在首帧后后台进行，初始化期间登录按钮禁用并显示“系统初始化中...”状态，避免 build 阶段 notifyListeners 与白屏转圈；`flutter analyze` 无问题，未运行应用，待人工启动回归。
- 2026-07-20：Windows 模块化数据源启动时的 MySQL 失败回退已修复：受影响模块仅在运行时切换至 SQLite，并等待所有 Provider 以该配置初始化完成后再展示登录页，避免查询未初始化数据源；`flutter analyze --no-pub` 无问题。全量测试已启动但未获得完整结束结果，未运行应用，待断开 MySQL 的人工启动回归。
- 2026-07-20：Windows 患者管理日期范围筛选已移至搜索栏右侧，样式与财务管理一致；可选择范围或在控件内清除。`flutter analyze --no-pub` 无问题，未运行应用。
- 2026-07-20：Windows 日期范围选择弹窗移除了错误的 `1:` 日期前缀；患者管理的既有日期范围筛选入口明确标注为“日期范围筛选”。`flutter analyze --no-pub` 无问题，未运行应用。
- 2026-07-20：Android MySQL 不可用自动回退 SQLite 登录修复，新增配置路径回归测试，路径、密码与会话专项 6 项通过，`flutter analyze --no-pub` 无问题；未运行应用，待真机断网后使用本地已同步账号登录回归。
- 2026-07-20：Windows 硬编码治理补充方案 F1～F4，`flutter analyze --no-pub` 无问题，定义专项 5 项测试通过；全量测试已启动但未获得完整结束结果，未运行应用，待人工回归。
- 2026-07-20：Windows 硬编码治理补充复核：`flutter analyze --no-pub` 无问题，定义专项 5 项与全量 102 项测试通过；HC-09 仍有 76 个业务层字符串决策，F4 未完成，未运行应用。
- 2026-07-20：再次复查 Windows 硬编码治理批次 6～8，确认 HC-08、HC-09、HC-11、HC-12 仍有残留，创建补充整改方案并修正总方案状态；本次只更新文档，未修改业务代码、未运行 Flutter 验证。
- 2026-07-20：Windows 硬编码治理批次 2～5：`flutter analyze --no-pub` 无问题；角色定义与患者列表专项 10 项测试通过。批次 1、3～5 的人工回归尚未执行，具体状态见 [总实施方案](windows_app/docs/windows_app_hardcoded_values_remediation_plan_2026_07_20.md) 。
- 2026-07-20：Windows 硬编码治理批次 6～9：`flutter analyze --no-pub` 无问题；新增定义专项 4 项与全量 `flutter test --no-pub` 通过。未运行应用，批次 1、3～8 的人工回归尚未执行，具体状态见 [总实施方案](windows_app/docs/windows_app_hardcoded_values_remediation_plan_2026_07_20.md) 。
- 2026-07-20：Windows 端硬编码治理总方案创建完成。只读复核个人路径、敏感日志、角色权限、全量查询、主题颜色、应用名称、数据源／模块标识、数据库时间、MySQL 默认值和预约状态；本次仅新增方案并同步进度，未修改业务代码或运行新的 Flutter 验证。
- 2026-07-20：Windows 患者默认医生硬编码整改任务 4～6，专项 16 项与全量 `flutter test --no-pub` 94 项通过，`flutter analyze --no-pub` 无问题。既有 SQLite 数据库不做 schema 迁移，不修改其中任何内容；待 SQLite／MySQL／登录人工回归。
- 2026-07-20：Windows 患者默认医生硬编码整改方案创建完成。只读核对新建数据库 schema、新增／编辑患者表单、Provider、CoreService、SQLite/MySQL 写入与结构检测链路；本次仅新增方案并同步进度，未修改业务代码、数据库 schema 或登录行为，未运行 Flutter 验证。
- 2026-07-20：Android 审核整改批次 7，专项 2 项与全量 `flutter test --no-pub` 19 项通过，`flutter analyze --no-pub` 无问题。
- 2026-07-20：Windows 与 Android 工程规范和 lint 基线收紧完成；两端 `flutter analyze --no-pub` 均通过。
- 2026-07-19：Windows 高风险整改批次 0～2，专项 6 项与全量 `flutter test --no-pub` 89 项通过，`flutter analyze --no-pub` 无问题。

## 维护规则

- 只记录当前状态、待办／阻塞和最近关键验证；详细过程保留在模块方案、总结文档和 Git 历史中。
- 只有已实现并验证的事项标为完成；未确认信息必须进入“待办与阻塞”。

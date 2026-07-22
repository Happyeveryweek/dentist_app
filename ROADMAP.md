# ROADMAP

## 当前状态

### Windows 端

- 模块列表与图表统计缓存优化已完成自动验证：患者、采购、财务统计及财务患者／收费记录分页、患者分页／高级搜索、采购分页／搜索、普通医生预约均按数据源、权限及查询条件使用 20 分钟缓存，统计弹窗主动刷新会绕过缓存；财务收费记录移除侧边栏切换触发的逐行异步转圈，采购统计不再在弹窗内逐条加载明细；患者病历与病历模板改为按患者／分类独立计算缓存有效期；用户列表首次进入复用有效缓存。待人工回归图表统计打开／刷新、财务页面切换、筛选分页及各模块数据变更后的刷新行为。
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

- Windows：待人工回归患者／采购／财务图表统计的重复打开与主动刷新、财务管理按收费记录显示时的模块切换、筛选分页，以及患者／采购／预约／病历／用户缓存的数据变更刷新行为。硬编码治理补充方案自动验证已完成，待执行全局／模块化数据源、MySQL 连接失败回退、备份恢复和预约状态人工回归；批次 1、3～5 仍待既定人工回归。既有 SQLite 默认约束清理按主人要求暂缓。另需完成高风险整改批次 3、5 的 MySQL／会话人工回归，并解决批次 6 的 `build/test_cache` 编译缓存冲突。
- Android：待真机或 MySQL 回归的项目包括采购项目数、登录与预约窄屏、采购输入键盘适配、MySQL 前后台恢复、采购／财务／患者详情缓存及返回手势。
- 已确认边界：Android 保持受控局域网直连 MySQL，保留本地“记住密码”和 MySQL 连接失败时回退 SQLite 的行为；患者删除维持现有全部关联数据删除语义。

## 最近验证

- 2026-07-22：Windows 端鼠标悬浮视觉完成统一。五套主题统一以主色 `8%` 透明度作为普通悬浮背景、`14%` 作为选中背景，并由主题层向 Material 控件提供统一 Hover／Focus 状态；患者、预约等业务列表、仪表盘统计卡片、设置主题卡片和紧凑下拉菜单不再混用自定义颜色或把悬浮态显示成选中态，危险、警告、成功操作仍保留原有语义色。新增五套主题层级、公共卡片悬浮及下拉菜单选中态回归测试；专项 7 项与全量 123 项测试通过，`flutter analyze --no-pub` 无问题。未运行应用，待人工回归侧边栏、下拉菜单、各模块列表、仪表盘和设置主题选择的实际悬浮效果。
- 2026-07-22：Windows 端下拉菜单样式完成全局整改。共用紧凑下拉支持自定义菜单宽度、36px 标准行高、44px 富内容行高、受控最大高度、选中态及禁用态；患者性别与预约内容、预约卡片状态、财务收费方式与排序、病历类别与父类型、用户角色、自动备份间隔均已迁移。业务代码已无遗留 `DropdownButton`／`DropdownButtonFormField`，材料模块既有 32～40px 紧凑菜单保持不变。患者性别、菜单尺寸、空值显示、收费图标居中及预约表单专项 7 项通过；全量 119 项测试通过，`flutter analyze --no-pub` 无问题。未运行应用，待人工回归各模块弹层视觉和选择行为。
- 2026-07-22：Windows 弹窗内下拉菜单完成桌面端紧凑化。新增共用紧凑下拉组件，将财务记录添加页的收费方式、预约添加／编辑页的预约状态和已有治疗项目统一为跟随输入框宽度、36px 选项行高及受控最大高度的弹层，保留收费方式图标和原有表单视觉；已有治疗项目未选择时不再显示与字段标签重叠的“暂无”。新增空值显示、弹层宽度、行高及选择行为回归测试；全量 118 项测试通过，`flutter analyze --no-pub` 无问题。未运行应用，待人工确认三处弹层最终视觉。
- 2026-07-22：Windows 财务记录添加／编辑收费项时的收费方式图标垂直居中修复。编辑态选中项改用独立的固定尺寸居中图标，不再复用下拉菜单的“图标＋文字”行；财务记录编辑弹窗和患者详情内联编辑入口同步处理。新增选中图标中心位置回归测试；全量 116 项测试通过，`flutter analyze --no-pub` 无问题。未运行应用，待人工确认现金、微信、支付宝图标显示位置。
- 2026-07-22：Windows 患者／采购／财务图表统计统一缓存完成。采购统计记录与明细按数据源、医生权限、搜索条件及记录 ID 集合缓存，弹窗改为数据准备完成后直接渲染并新增强制刷新入口，不再在 `initState` 中逐记录查询和显示整页转圈；财务全量统计明细及关联患者按数据源、用户权限和筛选条件缓存，既有刷新按钮改为 `forceRefresh` 回源。新增采购、财务统计缓存命中及强制刷新回归测试；全量 115 项测试通过，`flutter analyze --no-pub` 无问题。未运行应用，待人工回归。
- 2026-07-22：Windows 端模块列表缓存优化完成。财务管理移除无效的全局页面状态订阅和收费记录逐行 `FutureBuilder`，患者信息改为分页批量加载后同步读取；财务患者／收费记录分页、患者分页／高级搜索、采购分页／搜索、普通医生预约接入按查询条件隔离的 20 分钟缓存；患者病历与病历模板改为按患者／分类独立计时；用户列表首次进入不再强制回源。新增缓存键隔离、过期、清理、财务患者同步读取及病历独立计时测试；专项 25 项与全量 113 项测试通过，`flutter analyze --no-pub` 无问题。未运行应用，待人工回归。
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

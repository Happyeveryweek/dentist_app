# ROADMAP

## 当前阶段
- `windows_app` 备份/恢复链路高风险修复已完成并验证：MySQL 部分失败不再误报成功，还原前备份改为真实执行，SQLite 文件恢复前会先关闭连接并在恢复后重建；采购导出服务已收口为单一核心实现。已在 `windows_app/` 运行 `flutter analyze`，结果 `No issues found!`。
- `android_app` 采购详情页导出与材料库初始化修复已完成代码修改，待在 `android_app/` 运行 `flutter analyze` 验证。
- `windows_app` 预约管理菜单重复点击闪屏修复已完成代码修改，待在 `windows_app/` 运行 `flutter analyze` 验证。
- `windows_app` 预约/财务弹窗对比度修正已完成代码修改，待在 `windows_app/` 运行 `flutter analyze` 验证。
- `windows_app` 侧边栏/用户管理/病历管理闪烁修复已完成代码修改，待在 `windows_app/` 运行 `flutter analyze` 验证。

## 进行中
- `android_app` 登录页“记住密码”已恢复为安全存储方案，并补成“勾选后实时保存草稿、取消勾选立即清空”；预约新增页“治疗项目”输入区已改为窄屏自适应布局并消除下拉溢出。当前已通过针对性静态检查，待登录页和新建预约页手动回归确认。
- `android_app` 采购“添加采购项目”弹窗已改为键盘弹起时高度自适应、表单内容可滚动、底部按钮固定，已消除底部 `RenderFlex overflow` 风险。当前已通过针对性静态检查，待采购录入弹窗手动回归确认。

## 已完成
- `windows_app` 预约详情页头部摘要卡片背景已进一步压浅：不再使用偏深背景，也不再直接复用偏可见的浅渐变 token，改为接近白色的定制轻渐变，并同步压轻阴影和边框，只保留一点点层次避免头部发沉；已在 `windows_app/` 运行 `flutter analyze`，结果 `No issues found!`。
- `windows_app` 牙齿状况线条显示已完成修复并验证：添加/编辑患者、添加/编辑预约、查看患者、查看预约中的牙位十字线均已改为更深更粗显示；备注横线仅保留在患者添加/编辑和患者查看页，不扩展到预约查看页，提升浅色主题下的可读性；已在 `windows_app/` 运行 `flutter analyze`，结果 `No issues found!`。
- `windows_app` 患者详情页同步状态按钮与公共患者选择弹窗已完成修复并验证：同步按钮在“检查中/不可用”状态下禁用，避免在非 SQLite 主库场景误导用户触发失败提示；公共患者选择弹窗已补回电话和病历号显示，降低财务/预约场景同名患者误选风险。已在 `windows_app/` 运行 `flutter analyze`，结果 `No issues found!`。
- `windows_app` 患者 SQLite → MySQL 同步规则已修正为以 SQLite `id` 为主键来源：MySQL 命中同 `id` 时直接更新，未命中时插入同 `id`；患者详情页进入财务数据源补齐患者也使用同一 id-upsert 规则。已新增本地 `patient_sync_logs.json` 结构化日志和设置页“患者同步日志”查看入口，日志已按患者基本信息/患者材料/材料图片/预约记录/财务记录/财务明细/病历记录分类展示同步新建、同步更新、同步删除，并记录字段从旧值到新值的变更明细；财务详情页新增 MySQL 患者缺失/SQLite 与 MySQL 信息不一致的明确拦截提示；仓库新增 `.gitattributes` 固定文本文件 LF 行尾；全量 `flutter analyze` `No issues found!`。
- 根目录已新增 [crlf_to_lf_execution_2026_07_07.md](D:/Data/android_project/dentist_app/docs/crlf_to_lf_execution_2026_07_07.md)，用于后续按批次将仓库文本文件从 CRLF 统一修复为 LF，文档包含可直接执行的 PowerShell 命令、分批提交顺序和验证步骤。
- `windows_app` 五套主题已按 `windows_app/docs/dental_management_themes.md` 9.7 严格实施协议接入：`AppThemeTokens` 五套 factory、`WindowsThemeVariant` 主题枚举与解析、设置持久化、`AppTheme.resolve(...)` 统一入口和设置页主题选择 UI 已落地；全量 `flutter analyze` `No issues found!`，业务页面无新增主题分支。
- `windows_app` 主题治理与医学识别色治理已完成归档，统一以 [windows_app_theme_governance_final_summary_2026_07_05.md](D:/Data/android_project/dentist_app/windows_app/docs/windows_app_theme_governance_final_summary_2026_07_05.md) 为最终状态源，不再依赖已删除的阶段性文档。
- `windows_app` 空安全与 Flutter Analyze 治理已完成：`!` 已清零到仅注释示例保留，日志输出已统一收敛到 `LogManager`，`flutter analyze` 0 issue；归档文档为 `windows_app/docs/windows_app_null_safety_and_analysis_governance_summary.md`。
- `android_app` 空安全与静态检查治理已完成：`!` / `late` 在 Provider、Service、DataSource、UI 层已清零，`MapParser` 已建立并完成主要模型改造；归档文档为 `android_app/docs/android_app_null_safety_governance_summary.md`。
- 根目录与子项目 `AGENTS.md` 已完成共享边界、Flutter 命令约定、格式化/验证流程和 UI 复用规则同步，当前以仓库内现有 `AGENTS.md` 为准。

## 阻塞
- 无

## 最近验证
- 2026-07-07：`windows_app` 预约详情页头部摘要卡片背景已进一步压浅，并运行 `flutter analyze`，`No issues found!`；本轮仅调整预约详情页顶部摘要卡片的背景渐变、阴影和边框层次，不改动状态徽标、时间文案和业务逻辑。
- 2026-07-07：`windows_app` 牙齿状况线条显示已统一加深加粗，并运行 `flutter analyze`，`No issues found!`；本轮覆盖添加/编辑患者、添加/编辑预约、查看患者、查看预约中的牙位十字线，以及患者表单/患者查看中的备注横线显示，不改动牙齿状况数据结构和业务逻辑。
- 2026-07-07：`windows_app` 重复打开应用的单实例拦截提示已改为明确页面提示，不再灰屏后立即退出；当前会显示“应用已经打开”说明、5 秒倒计时和手动退出按钮，并运行 `flutter analyze`，`No issues found!`。
- 2026-07-07：`windows_app` 编辑财务记录专用弹窗 `financial_record_edit_dialog.dart` 已补回右上角关闭按钮，并运行 `flutter analyze`，`No issues found!`；本轮修复的是财务管理列表“编辑财务记录”链路，不涉及新增财务记录弹窗主体逻辑。
- 2026-07-07：`windows_app` 财务管理添加/编辑财务记录弹窗已补回右上角关闭按钮，并运行 `flutter analyze`，`No issues found!`；本轮仅修复标题栏关闭入口缺失，不改动财务表单业务逻辑。
- 2026-07-07：`windows_app` 公共患者选择弹窗列顺序已调整为“病历号 / 姓名电话 / 最近就诊”，并运行 `flutter analyze`，`No issues found!`；本轮仅调整患者辨识信息的展示顺序，降低同名患者选择时的扫描成本。
- 2026-07-07：`windows_app` 患者详情页同步状态按钮与公共患者选择弹窗修复后运行 `flutter analyze`，`No issues found!`；本轮覆盖同步按钮禁用边界、同步状态文案，以及患者选择弹窗电话/病历号辨识信息恢复。
- 2026-07-07：`windows_app` 患者 SQLite → MySQL 同步修复后运行全量 `flutter analyze`，`No issues found!`；`git diff --check` 通过；本轮覆盖患者同步 id-upsert、患者详情页财务数据源补齐 id-upsert、患者同步 JSON 日志、设置页查看入口、患者材料/材料图片/预约/财务/病历等患者相关同步日志、字段变更明细、财务详情页 MySQL 患者缺失/信息不一致提示和 LF 行尾规则。
- 2026-07-07：根目录已补充 `docs/crlf_to_lf_execution_2026_07_07.md`，定义 CRLF→LF 的可执行分批修复方案；本次文档补齐未单独运行 Flutter 命令。
- 2026-07-06：`windows_app` 备份/恢复与采购导出治理后运行全量 `flutter analyze`，`No issues found!`；本轮修复覆盖 MySQL 恢复成功判定、真实预恢复备份、SQLite 恢复前断开连接/恢复后重建、还原文件句柄关闭、SQLite 路径错误兜底移除，以及采购导出服务重复实现收口。
- 2026-07-06：根目录 `AGENTS.md` 已补充 Dart 定向格式化规则与默认验证顺序：先格式化改动文件，再运行 `flutter analyze`，命中测试条件时再运行 `flutter test`；本次仅更新协作文档，未运行 Flutter 命令。
- 2026-07-05：`windows_app` 五套主题接入后运行全量 `flutter analyze`，`No issues found!`；并完成搜索复核，主题枚举仅存在于主题入口与设置相关文件，业务页面 `DentalColors` / `AppTheme.primaryColor` / `AppTheme.secondaryColor` / `AppTheme.primaryGradient` 为 0 命中。
- 2026-07-05：`windows_app` 主题治理阶段文档已归档合并为 `windows_app/docs/windows_app_theme_governance_final_summary_2026_07_05.md`，旧的 9 份阶段性文档已删除；本次仅整理文档，未运行 Flutter 命令。
- 2026-07-04：`windows_app` 阶段 5 范围运行针对性 `flutter analyze`，`No issues found!`；图表、统计弹窗、牙位相关组件的旧 `DentalColors`、`AppTheme.primaryGradient` / `AppTheme.primaryColor` 和普通硬编码边框已清零。
- 2026-07-04：`windows_app` 阶段 6 完成后运行全量 `flutter analyze`，0 error、0 warning，仅剩预先存在的 `prefer_const` info；运行链路中仅保留 `AppTheme.standardTheme()`、`AppTheme.smallBorderRadius` 和 `AppTheme.dangerGradient`。
- 2026-07-01：`android_app` 对采购初始化与采购统计相关文件运行针对性 `flutter analyze`，0 issue。

# ROADMAP

## 当前阶段
- 项目协作规范维护

## 已完成
- `windows_app` 修复患者详情页财务记录串患者问题：当患者模块与财务模块使用不同数据源时，不再直接复用裸 `patient.id` 关联收费记录；患者详情页收费记录标签改为按财务模块数据源解析对应患者，空记录时保留原有空态和“添加收费记录”入口，新增收费时会先把患者解析/同步到财务数据源后再写入收费记录，避免把收费写到同 ID 的其他患者名下。
- `windows_app` 修复预约新增/编辑弹窗患者选择串患者问题：预约弹窗患者列表改为按预约模块当前数据源读取，预选患者和已有预约患者也会在预约数据源内重新解析，避免跨数据源时把患者模块对象直接写入预约记录后显示成其他人。
- `windows_app` 修复采购新增弹窗材料选择串数据源问题：采购材料选择改为按采购模块当前数据源读取材料，避免采购用 MySQL 时仍错误复用其他模块材料数据源。
- `windows_app` 修复患者详情页预约记录跨数据源关联问题：预约记录标签改为按预约模块数据源解析对应患者后再查询预约，预约数据源内部回查患者、医生过滤和患者搜索也统一按预约模块数据源执行，避免详情页预约记录串患者。
- `windows_app` 修复 MySQL 患者材料图片显示异常：MySQL 通用行转换不再把 BLOB 图片字段错误解码成字符串，患者材料图片/缩略图在 MySQL 数据源下恢复按二进制正常显示。
- `windows_app` 修复预约 `treatment_type` 显示回归：MySQL 通用行转换恢复为“图片字段保留二进制、普通文本字段按 UTF-8 解码”，避免预约牙位/治疗项目 JSON 被渲染成字节数组；预约弹窗“选择已有项目”同时恢复兼容旧版 `treatmentTypes` 与新版 `treatments` 去重显示。
- `windows_app` 修复采购记录读取回归：对照 `lib_bak` 确认采购模块业务链路未变，问题收口到 MySQL 底层类型转换后的读取兼容；采购记录/采购明细/采购金额汇总补齐 `String/BigInt/int/double` 安全解析，避免 MySQL 返回类型波动导致采购列表被 provider 吃错后显示为空。
- `android_app` 空安全与静态检查治理完成：批次 1~5 已结束，明文密码存储已移除，`!`/`late` 在 Provider/Service/DataSource/UI 层已清零，`MapParser` 已建立并改造 12 个模型文件；原治理计划文档已归档为 `android_app/docs/android_app_null_safety_governance_summary.md`。
- `windows_app` 空安全与 Flutter Analyze 治理完成：`!` 从 628 处降至 0（仅注释示例保留 2 处），`print`/`debugPrint` 收敛到 `LogManager`，`flutter analyze` 0 issue，Release 已打包测试；原治理文档已归档为 `windows_app/docs/windows_app_null_safety_and_analysis_governance_summary.md`。
- 根目录 `AGENTS.md` 补充 Android/Windows 端共享边界、编码规范和验证要求。
- 新增 `android_app/AGENTS.md`，记录 Android 端范围、常用命令和平台专属约定。
- 新增 `windows_app/AGENTS.md`，记录 Windows 端范围、WSL 下使用 `cmd.exe /c` 执行 Flutter 命令和平台专属约定。
- 根目录 `AGENTS.md` 补充 WSL 下统一使用 `cmd.exe /c` 的 Flutter 命令、Bug 修复两阶段规则和新增/修复测试要求。
- 根目录 `AGENTS.md` 更新 Flutter 命令约定：Windows shell 直接使用 `flutter ...`，仅在 WSL 下使用 `cmd.exe /c flutter ...`。
- 根目录 `AGENTS.md` 精简沙箱执行边界，仅保留与当前仓库直接相关的 Flutter/Android 工具链说明；通用沙箱规则转移到用户全局 AGENTS 维护。
- 精简 `android_app/AGENTS.md` 与 `windows_app/AGENTS.md`，避免重复维护共享命令。

## 进行中
- `android_app` 登录页“记住密码”已恢复为安全存储方案，并补成“勾选后实时保存草稿、取消勾选立即清空”，避免只有登录成功才落盘；预约新增页“治疗项目”输入区已改为窄屏自适应布局并消除下拉溢出；当前已通过针对性静态检查，待登录页和新建预约页手动回归确认。
- `android_app` 采购“添加采购项目”弹窗已改为键盘弹起时高度自适应、表单内容可滚动、底部按钮固定，已消除底部 `RenderFlex overflow` 风险；当前已通过针对性静态检查，待采购录入弹窗手动回归确认。

## 待办
- 无

## 阻塞
- 无

## 最近验证
- 2026-06-26：`android_app` 运行 `flutter analyze lib/screens/login_screen.dart lib/features/users/services/login_credentials_service.dart lib/features/users/services/login_handler.dart`，0 issue。
- 2026-06-26：`android_app` 运行 `flutter analyze lib/features/purchases/widgets/purchase_item_dialog.dart lib/features/purchases/widgets/purchase_record_dialog.dart lib/features/purchases/screens/purchase_records_screen.dart`，0 issue。
- 2026-06-26：`android_app` 运行 `flutter analyze lib/features/users/services/login_credentials_service.dart lib/features/users/services/login_handler.dart lib/screens/login_screen.dart lib/features/appointments/widgets/treatment_items_input.dart lib/features/appointments/widgets/appointment_form_sheet.dart`，0 issue。
- 2026-06-26：`windows_app` 运行 `flutter analyze lib/providers/patient_provider.dart lib/features/patients/services/patient_detail_loader_service.dart lib/screens/patient_detail_screen.dart`，0 issue。
- 2026-06-26：`windows_app` 运行 `flutter analyze lib/features/financial/widgets/financial_form_dialog.dart lib/features/financial/services/patient_cache_service.dart lib/providers/patient_provider.dart lib/features/patients/services/patient_detail_loader_service.dart lib/screens/patient_detail_screen.dart`，0 issue。
- 2026-06-26：`windows_app` 运行 `flutter analyze lib/features/appointments/widgets/appointment_form_dialog.dart lib/providers/patient_provider.dart lib/providers/appointment_provider.dart`，0 issue。
- 2026-06-26：`windows_app` 运行 `flutter analyze lib/data_sources/base_mysql_data_source.dart lib/providers/material_provider.dart lib/features/purchases/widgets/material_selection_dialog.dart lib/providers/patient_provider.dart lib/data_sources/mysql_appointment_data_source.dart lib/data_sources/sqlite_appointment_data_source.dart lib/features/patients/services/patient_detail_loader_service.dart lib/screens/patient_detail_screen.dart`，0 issue。
- 2026-06-26：`windows_app` 运行 `flutter analyze lib/data_sources/base_mysql_data_source.dart lib/features/appointments/widgets/appointment_form_dialog.dart`，0 issue。
- 2026-06-26：`windows_app` 运行 `flutter analyze lib/data_sources/base_mysql_data_source.dart lib/data_sources/mysql_purchase_data_source.dart lib/models/purchase_record.dart lib/models/purchase_item.dart lib/screens/appointment_details_screen.dart lib/features/appointments/widgets/appointment_form_dialog.dart`，0 issue。
- 2026-06-26：更新 Flutter 命令约定并复测 Windows unelevated sandbox；`Get-Location`、`Get-ChildItem`、`Invoke-WebRequest` 成功，`rg` 因访问 `WindowsApps` 内置 `rg.exe` 被拒绝，`flutter --version` 未在日志中完成返回。
- 2026-06-26：精简仓库内沙箱规则，仅保留当前仓库的 Flutter/Android 工具链说明；通用沙箱执行策略改由用户全局 AGENTS 维护。


# ROADMAP

## 当前阶段
- `android_app` 采购详情页导出与材料库初始化修复已完成代码修改，待在 `android_app/` 运行 `flutter analyze` 验证。
- `windows_app` 预约管理菜单重复点击闪屏修复已完成代码修改，待在 `windows_app/` 运行 `flutter analyze` 验证。
- `windows_app` 预约/财务弹窗对比度修正已完成代码修改，待在 `windows_app/` 运行 `flutter analyze` 验证。
- `windows_app` 侧边栏/用户管理/病历管理闪烁修复已完成代码修改，待在 `windows_app/` 运行 `flutter analyze` 验证。

## 进行中
- `android_app` 登录页“记住密码”已恢复为安全存储方案，并补成“勾选后实时保存草稿、取消勾选立即清空”；预约新增页“治疗项目”输入区已改为窄屏自适应布局并消除下拉溢出。当前已通过针对性静态检查，待登录页和新建预约页手动回归确认。
- `android_app` 采购“添加采购项目”弹窗已改为键盘弹起时高度自适应、表单内容可滚动、底部按钮固定，已消除底部 `RenderFlex overflow` 风险。当前已通过针对性静态检查，待采购录入弹窗手动回归确认。

## 已完成
- `windows_app` 五套主题已按 `windows_app/docs/dental_management_themes.md` 9.7 严格实施协议接入：`AppThemeTokens` 五套 factory、`WindowsThemeVariant` 主题枚举与解析、设置持久化、`AppTheme.resolve(...)` 统一入口和设置页主题选择 UI 已落地；全量 `flutter analyze` `No issues found!`，业务页面无新增主题分支。
- `windows_app` 主题治理与医学识别色治理已完成归档，统一以 [windows_app_theme_governance_final_summary_2026_07_05.md](D:/Data/android_project/dentist_app/windows_app/docs/windows_app_theme_governance_final_summary_2026_07_05.md) 为最终状态源，不再依赖已删除的阶段性文档。
- `windows_app` 空安全与 Flutter Analyze 治理已完成：`!` 已清零到仅注释示例保留，日志输出已统一收敛到 `LogManager`，`flutter analyze` 0 issue；归档文档为 `windows_app/docs/windows_app_null_safety_and_analysis_governance_summary.md`。
- `android_app` 空安全与静态检查治理已完成：`!` / `late` 在 Provider、Service、DataSource、UI 层已清零，`MapParser` 已建立并完成主要模型改造；归档文档为 `android_app/docs/android_app_null_safety_governance_summary.md`。
- 根目录与子项目 `AGENTS.md` 已完成共享边界、Flutter 命令约定、验证要求和 UI 复用规则同步，当前以仓库内现有 `AGENTS.md` 为准。

## 阻塞
- 无

## 最近验证
- 2026-07-05：`windows_app` 五套主题接入后运行全量 `flutter analyze`，`No issues found!`；并完成搜索复核，主题枚举仅存在于主题入口与设置相关文件，业务页面 `DentalColors` / `AppTheme.primaryColor` / `AppTheme.secondaryColor` / `AppTheme.primaryGradient` 为 0 命中。
- 2026-07-05：`windows_app` 主题治理阶段文档已归档合并为 `windows_app/docs/windows_app_theme_governance_final_summary_2026_07_05.md`，旧的 9 份阶段性文档已删除；本次仅整理文档，未运行 Flutter 命令。
- 2026-07-04：`windows_app` 阶段 5 范围运行针对性 `flutter analyze`，`No issues found!`；图表、统计弹窗、牙位相关组件的旧 `DentalColors`、`AppTheme.primaryGradient` / `AppTheme.primaryColor` 和普通硬编码边框已清零。
- 2026-07-04：`windows_app` 阶段 6 完成后运行全量 `flutter analyze`，0 error、0 warning，仅剩预先存在的 `prefer_const` info；运行链路中仅保留 `AppTheme.standardTheme()`、`AppTheme.smallBorderRadius` 和 `AppTheme.dangerGradient`。
- 2026-07-01：`android_app` 对采购初始化与采购统计相关文件运行针对性 `flutter analyze`，0 issue。

# AGENTS.md

## 项目范围

- 本目录是 Windows 端 Flutter 项目。
- 用户未明确说明目标平台时，默认修改本目录。
- 不同步修改 Android 端，除非用户明确要求跨平台处理。

## 开发约定

- 默认只改 `lib/`、`test/`、`assets/` 和必要文档。
- 修改 `windows/`、`installer/`、安装脚本、系统路径、发布配置前先说明影响并等待确认。
- 数据库、Map、JSON、文件路径等外部输入必须显式校验，不新增非必要 `!`。
- 新 UI 不允许直接用 `Colors.white`、`Colors.grey.shade50`、`Colors.grey.shade100`、`Color(0x...)` 充当页面背景、卡片背景、边框、普通按钮或 hover/selected/disabled 主题色。
- 新 UI 不允许直接使用 `DentalColors.primaryGradient`、页面内 `LinearGradient(...)` 或 `BoxShadow(color: Colors.black.withValues(...))` 表达普通主题视觉；优先使用 `Theme.of(context)` 或 `context.tokens`。
- 公共组件必须在组件内部读取主题，不应要求调用方传固定品牌色；状态色优先使用统一主题令牌。
- 本轮主题治理只保留标准主题入口；未来新增主题只能扩展 token 和主题构建入口，不能在业务页面继续加主题分支。
- 验证命令按根目录 `AGENTS.md` 执行，并在本目录下运行。
- 运行 Windows 应用只在用户明确要求时执行：`cmd.exe /c flutter run -d windows`。
- 构建 Windows 应用只在用户明确要求时执行：`cmd.exe /c flutter build windows`。

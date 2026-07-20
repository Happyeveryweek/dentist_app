# AGENTS.md

## 项目范围

- 本目录是 Windows 端 Flutter 项目。
- 用户未明确说明目标平台时，默认修改本目录。
- 不同步修改 Android 端，除非用户明确要求跨平台处理。

## 开发约定

- 默认只改 `lib/`、`test/`、`assets/` 和必要文档。
- 修改 `windows/`、`installer/`、安装脚本、系统路径、发布配置前先说明影响并等待确认。
- 新 UI 的主题视觉必须来自 `Theme.of(context)`、`context.tokens` 或统一语义常量；医学识别色等业务颜色集中定义后使用，不在业务页面自行建立主题体系。
- 公共组件在内部读取主题，不要求调用方传入固定品牌色；新主题只扩展 token 和主题构建入口。
- 运行 Windows 应用只在用户明确要求时执行：`cmd.exe /c flutter run -d windows`。
- 构建 Windows 应用只在用户明确要求时执行：`cmd.exe /c flutter build windows`。

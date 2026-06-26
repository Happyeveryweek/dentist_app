# AGENTS.md

## 项目范围

- 本目录是 Windows 端 Flutter 项目。
- 用户未明确说明目标平台时，默认修改本目录。
- 不同步修改 Android 端，除非用户明确要求跨平台处理。

## 开发约定

- 默认只改 `lib/`、`test/`、`assets/` 和必要文档。
- 修改 `windows/`、`installer/`、安装脚本、系统路径、发布配置前先说明影响并等待确认。
- 数据库、Map、JSON、文件路径等外部输入必须显式校验，不新增非必要 `!`。
- 验证命令按根目录 `AGENTS.md` 执行，并在本目录下运行。
- 运行 Windows 应用只在用户明确要求时执行：`cmd.exe /c flutter run -d windows`。
- 构建 Windows 应用只在用户明确要求时执行：`cmd.exe /c flutter build windows`。

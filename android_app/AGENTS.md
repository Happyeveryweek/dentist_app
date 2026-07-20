# AGENTS.md

## 项目范围

- 本目录是 Android 端 Flutter 项目。
- 只有用户明确说明处理 Android 端时，才修改本目录。
- 不把 Windows 端实现直接复制到 Android 端；需要先确认平台差异。

## 开发约定

- 默认只改 `lib/`、`test/` 和必要的 `pubspec.yaml`。
- 修改 `android/` 原生配置、签名、权限、Gradle 配置前先说明影响并等待确认。
- Provider 状态和 UI 异步加载必须显式处理 null 与组件生命周期。
- APK 构建只在用户明确要求时执行：`cmd.exe /c flutter build apk`。

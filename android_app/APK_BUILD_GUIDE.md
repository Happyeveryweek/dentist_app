# Android APK 打包说明

本文适用于 `D:\Data\android_project\dentist_app\android_app` 这个 Flutter 项目。

## 为什么 IDE 里的“构建 APK”没反应

你现在把 Android 工程放进了仓库根目录下的 `android_app` 子目录里。
如果 IDE 打开的不是这个目录本身，而是上一级的仓库根目录 `D:\Data\android_project\dentist_app`，Flutter 的构建入口有时会失效，表现就是：

- 菜单里点了“Build APK”没反应
- IDE 没有正常启动 Flutter 构建任务
- 控制台也没有明显输出

处理方式很直接：

1. 用 `D:\Data\android_project\dentist_app\android_app` 作为 Flutter 项目根目录打开
2. 不要用仓库根目录去触发 Android 构建
3. 直接用脚本或命令行打包

## 推荐打包方式

优先使用项目根目录里的脚本：

```text
D:\Data\android_project\dentist_app\android_app\build_apk.bat
```

双击它即可开始打包。

## 手动命令

如果你想直接在命令行里构建，可以用下面这些命令。

### 调试包

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter build apk --debug
```

### 正式包

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter build apk --release
```

### 按 ABI 拆分正式包

```powershell
cd D:\Data\android_project\dentist_app\android_app
flutter build apk --release --split-per-abi
```

## 打包结果在哪

成功后，APK 一般会生成在这里：

```text
D:\Data\android_project\dentist_app\android_app\build\app\outputs\flutter-apk\
```

常见文件：

- `app-debug.apk`
- `app-release.apk`
- `app-arm64-v8a-release.apk`
- `app-armeabi-v7a-release.apk`
- `app-x86_64-release.apk`

## 如果脚本还是没跑起来

按这个顺序处理：

1. 确认 IDE 打开的就是 `android_app`
2. 先执行 `flutter pub get`
3. 再执行 `flutter build apk --release`
4. 如果还是失败，先看控制台报错，再决定要不要清理缓存

## 说明

- `windows_app` 是另一个独立工程，不用于 Android APK 构建
- 这份文档只针对 Android 工程
- 如果以后项目结构再调整，先更新这里，再改构建方式

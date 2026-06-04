# Windows 打包命令说明

这个文档只说明 `windows_app` 的 Windows 端如何从源码打包到安装包。

## 1. 进入项目目录

在 Windows 命令行或 PowerShell 中执行：

```powershell
cd /d D:\Data\android_project\dentist_app\windows_app
```

## 2. 安装依赖

如果依赖有变动，先执行：

```powershell
flutter pub get
```

## 3. 构建 Windows Release

生成 Windows 发布版 exe：

```powershell
flutter build windows --release
```

生成结果默认在：

```text
build\windows\x64\runner\Release\
```

主要文件是：

```text
build\windows\x64\runner\Release\dentist_app_windows.exe
```

## 4. 用 Inno Setup 打安装包

项目里已经有安装脚本：

```text
installer_script.iss
```

如果你安装了 Inno Setup，可以直接编译这个脚本。

常见命令 1，Inno Setup 已加入 PATH：

```powershell
ISCC.exe installer_script.iss
```

常见命令 2，直接写完整路径：

```powershell
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_script.iss
```

安装包输出目录由脚本里的 `OutputDir=installer` 控制，生成结果一般在：

```text
installer\牙科诊所管理系统_安装程序.exe
```

## 5. 一次性打包命令

如果你想一次跑完，可以按这个顺序执行：

```powershell
cd /d D:\Data\android_project\dentist_app\windows_app
flutter pub get
flutter build windows --release
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_script.iss
```

## 6. 可保存为 Windows 批处理文件

下面这段可以保存为 `build_windows_release.bat`，然后双击运行：

```bat
@echo off
cd /d D:\Data\android_project\dentist_app\windows_app
flutter pub get
flutter build windows --release
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer_script.iss
pause
```

如果你的 Inno Setup 安装路径不同，只需要把上面那行 `ISCC.exe` 的路径改成你机器上的实际路径。

## 7. 说明

- 代码拆分不会改变这个安装脚本的基本用法
- 只要 `build\windows\x64\runner\Release` 里的 exe 是最新的，`installer_script.iss` 就可以继续直接用
- 如果以后 exe 文件名改了，才需要同步修改 `MyAppExeName`

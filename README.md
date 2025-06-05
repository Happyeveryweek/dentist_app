# 牙医诊所管理系统

## 项目概述
牙医诊所管理系统是一款专为牙医诊所设计的管理软件，旨在帮助牙医诊所管理患者信息、预约安排、治疗记录等各项业务。

## 主要功能
- 患者管理：记录患者基本信息、病史、就诊记录等
- 预约管理：安排、查看、修改患者预约
- 患者数据导出：支持导出Excel格式的患者数据
- 跨平台支持：Android和Windows客户端

## 技术栈
- Flutter框架
- SQLite本地数据库
- MySQL远程数据库支持
- Excel数据导出

## Android打包指南
确保已安装Flutter环境后执行以下命令：

```bash
# 构建APK
flutter build apk --release

# 构建分离式APK (支持不同架构)
flutter build apk --split-per-abi --release

# 构建Android App Bundle (推荐发布到Google Play)
flutter build appbundle --release
```

## Windows打包指南
确保已安装Flutter Windows开发环境后，执行以下命令：

```bash
# 启用Windows桌面支持
flutter config --enable-windows-desktop

# 构建Windows可执行文件
flutter build windows --release
```

生成的Windows应用将位于`build\windows\runner\Release`目录下。

## 开发指南

### 环境设置
1. 安装Flutter SDK (2.10.0或更高版本)
2. 克隆项目代码库
3. 运行`flutter pub get`获取依赖
4. 运行`flutter run`启动项目

### 数据库配置
- 本地模式：默认使用SQLite，无需额外配置
- 远程模式：在设置页面配置MySQL连接信息

## 项目文件结构
```
lib/
  ├── main.dart            # 应用程序入口点
  ├── models/              # 数据模型
  │   └── database_models.dart
  ├── providers/           # 状态管理
  │   ├── database_provider.dart
  │   └── settings_provider.dart
  ├── screens/             # 界面
  │   ├── appointments_screen.dart
  │   ├── dashboard_screen.dart
  │   ├── patients_screen.dart
  │   └── settings_screen.dart
  ├── utils/               # 工具函数
  │   └── database_utils.dart
  └── widgets/             # 可复用组件
      ├── appointment_form_sheet.dart
      └── patient_form_sheet.dart
```

## 贡献指南
1. Fork 仓库
2. 创建功能分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 开启一个 Pull Request

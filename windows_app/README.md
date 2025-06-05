# 牙医诊所管理系统 - Windows版本

这是一个用于牙医诊所的患者和预约管理系统的Windows版本，采用Flutter开发，遵循Apple设计风格，提供现代化的用户界面和高效的管理功能。

## 功能特点

- **仪表板**：概览诊所运营状况，显示今日预约和关键统计数据
- **患者管理**：完整的患者信息管理，包括个人资料、治疗历史和费用记录
- **预约管理**：灵活的预约安排系统，支持创建、编辑和状态跟踪
- **跟进记录**：记录患者治疗后的跟进情况，确保治疗效果
- **系统设置**：个性化应用设置，包括主题、字体大小和备份选项
- **数据同步**：与Android版本应用数据同步，确保多平台数据一致性

## 系统要求

- **操作系统**：Windows 10 或更高版本
- **磁盘空间**：至少500MB可用空间
- **内存**：4GB RAM（推荐8GB或更高）

## 开发环境设置

1. 安装Flutter SDK（2.17.0或更高版本）
2. 安装Visual Studio（带有"使用C++的桌面开发"工作负载）
3. 克隆此仓库：
```
git clone https://github.com/yourusername/dentist_app_windows.git
cd dentist_app_windows
```

4. 获取依赖项：
```
flutter pub get
```

5. 运行应用程序：
```
flutter run -d windows
```

## 构建应用程序

生成发布版本：
```
flutter build windows --release
```

生成的可执行文件位于：`build\windows\x64\runner\Release\dentist_app_windows.exe`

## 项目结构

```
lib/
├── main.dart                # 应用程序入口点
├── providers/               # 状态管理
│   ├── app_state.dart       # 应用状态管理
│   ├── database_provider.dart # 数据库操作
│   └── settings_provider.dart # 用户设置
├── models/                  # 数据模型
│   ├── patient.dart         # 患者模型
│   ├── appointment.dart     # 预约模型
│   └── follow_up.dart       # 跟进记录模型
├── screens/                 # 界面
│   ├── dashboard_screen.dart # 仪表板
│   ├── patients_screen.dart  # 患者管理
│   ├── appointments_screen.dart # 预约管理
│   └── settings_screen.dart # 系统设置
└── theme/                   # 主题和样式
    └── app_theme.dart       # 应用主题定义
```

## 配置

应用程序设置存储在用户的本地应用数据目录中。数据库文件同样存储在此处，可以通过设置界面进行备份和恢复。

## 许可证

此项目采用MIT许可证 - 详情请参阅LICENSE文件

## 联系方式

如有问题或建议，请联系：your.email@example.com 
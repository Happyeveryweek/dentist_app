# Android App 空安全与静态检查治理完成总结

> 生成日期：2026-06-26  
> 项目范围：`android_app`  
> 依据文档：`android_app_null_assertion_elimination_plan.md`、`android_app_static_analysis_cleanup_plan_2026_06_24.md`

---

## 一、项目目标

1. 根本性消除 `android_app` 中的 `!` 空断言与 `late` 半初始化模式，降低运行时崩溃风险。
2. 建立 `MapParser` 安全解析基础设施，替代模型层的裸 `as` 强制转换。
3. 修复明文密码、固定默认账号等安全红线问题。
4. 完成第一轮静态检查治理，降低 `flutter analyze` 噪声，让高信号问题可被识别。
5. 保持 `flutter analyze --fatal-infos` 0 issue。

---

## 二、治理成果

### 2.1 第一轮静态检查治理（依据 `android_app_static_analysis_cleanup_plan_2026_06_24.md`）

- 将 `avoid_print` 收敛到 `AppLogger`。
- 补齐 `use_build_context_synchronously` 的 `mounted` 守卫。
- 清理 `unused_import` / `unused_element` / `unused_field`。
- 处理 `deprecated_member_use`。
- 使 `flutter analyze` 达到 0 issue，为后续空安全治理建立可执行基线。

### 2.2 空断言与安全红线治理（依据 `android_app_null_assertion_elimination_plan.md`）

| 批次 | 目标 | 范围 | 完成状态 | 关键结果 |
|------|------|------|----------|----------|
| 1 | 安全红线修复 | `models/database_models.dart`、`features/users/services/login_credentials_service.dart` | 部分完成 | 已移除明文密码存储；“记住密码”仅保存用户名与勾选状态；硬编码默认账号 `admin/123456` 与 `staff/123456` 保留，待后续评估 |
| 2 | 建立 `MapParser` 并改造模型 | `lib/utils/map_parser.dart`、`lib/models/*.dart`（12 个模型文件） | 已完成 | 模型 `fromMap` 全面改用 `MapParser` 安全解析，裸 `as` 转换清零 |
| 3 | Provider 层 `!` / `late` 清零 | `lib/providers/*.dart` 及相关 mixin | 已完成 | Provider getter 不再返回 `!`，无 `late` |
| 4 | Service/DataSource 层 `!` 清零 | `lib/services/*.dart`、`lib/data_sources/*.dart`、`lib/features/*/services/*.dart` | 已完成 | 数据库连接/配置 `!` 清零，`insertId!`、`affectedRows!` 等已处理 |
| 5 | UI 层显式加载/错误状态 | `lib/screens/*.dart`、`lib/features/*/widgets/*.dart`、`lib/widgets/*.dart` | 已完成 | UI 层 `!` 与 `late` 清零 |
| 6 | 启用严格 lint 与 CI 门禁 | `analysis_options.yaml`、CI 脚本 | **已取消** | 经确认，该步骤不再执行 |

---

## 三、关键改动模式

### 3.1 模型解析安全化

```dart
// 改造前
username: map['username']?.toString() ?? '',

// 改造后
username: MapParser(map, context: 'User').string('username', defaultValue: ''),
```

### 3.2 Provider/Service 层消除 `late` + `!`

```dart
// 改造前
late final FinancialRecordService _recordService = FinancialRecordService();
_service!.method();

// 改造后
FinancialRecordService? _recordServiceInstance;
FinancialRecordService get _recordService =>
    _recordServiceInstance ??= FinancialRecordService();
```

### 3.3 UI 层显式状态

```dart
// 改造前
Text(patient!.name)

// 改造后
final p = patient;
if (p == null) return const Center(child: CircularProgressIndicator());
return Text(p.name);
```

### 3.4 明文密码存储移除

- 删除 `login_credentials_service.dart` 中的 `_savedPasswordKey` 与保存逻辑。
- 增加清理历史遗留 `saved_password` 的兼容代码。
- 登录页“记住密码”仅记住用户名与复选框状态，不再明文保存密码。

---

## 四、验证结果

- `flutter analyze --fatal-infos`：**0 issue**（每批次完成后均验证通过）。
- 代码中不再新增非必要的 `!` 空断言。
- 所有已治理目录下的 `late` 关键字已清零。

---

## 五、仍存风险与后续建议

1. **默认账号风险**：`models/database_models.dart` 中的 `admin/123456` 与 `staff/123456` 默认账号仍被保留。建议后续通过“首次启动强制修改密码”或“Release 包不创建默认账号”等方式处理。
2. **持续门禁**：虽然未启用严格 lint/CI 门禁，但建议在后续开发中保持：
   - 不新增非必要 `!`；
   - 外部输入（Map/JSON/数据库/文件）优先使用 `MapParser` 或显式判空；
   - 每次提交前运行 `flutter analyze`。
3. **日志规范**：`avoid_print` 已收敛到 `AppLogger`，后续新增代码应继续使用 `AppLogger`，避免重新引入 `print`。

---

## 六、文档变更

- 已归档并删除原治理计划文件：
  - `android_app_null_assertion_elimination_plan.md`
  - `android_app_static_analysis_cleanup_plan_2026_06_24.md`
- 本总结文件为最终归档版本。

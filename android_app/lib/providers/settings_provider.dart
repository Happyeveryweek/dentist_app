import 'package:flutter/material.dart';
import '../utils/settings_manager.dart';

/// 设置提供者 - 用于在应用程序中共享设置状态
class SettingsProvider extends ChangeNotifier {
  SettingsManager? _settingsManager;

  SettingsManager get _requireSettingsManager {
    final manager = _settingsManager;
    if (manager == null) {
      throw StateError('SettingsProvider 尚未初始化，请先调用 init()');
    }
    return manager;
  }

  // 通知设置
  bool _appointmentReminder = true;

  // 系统设置
  ThemeMode _themeMode = ThemeMode.light;

  // 获取器
  bool get appointmentReminder => _appointmentReminder;
  ThemeMode get themeMode => _themeMode;

  // 初始化设置
  Future<void> init() async {
    // 获取单例
    final manager = await SettingsManager.getInstance();
    _settingsManager = manager;

    // 加载所有设置
    _appointmentReminder = manager.getAppointmentReminder();
    _themeMode = manager.getThemeMode();

    // 通知监听器
    notifyListeners();
  }

  // 更新预约提醒设置
  Future<void> updateAppointmentReminder(bool value) async {
    if (await _requireSettingsManager.setAppointmentReminder(value)) {
      _appointmentReminder = value;
      notifyListeners();
    }
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置管理器 - 用于处理用户偏好设置的存储和获取
class SettingsManager {
  // 共享偏好设置键
  static const String _keyAppointmentReminder = 'appointment_reminder';
  static const String _keyThemeMode = 'theme_mode';

  // 单例模式
  static SettingsManager? _instance;
  static SharedPreferences? _prefs;

  // 获取单例
  static Future<SettingsManager> getInstance() async {
    if (_instance == null) {
      _instance = SettingsManager._();
      await _instance!._init();
    }
    return _instance!;
  }

  // 私有构造函数
  SettingsManager._();

  // 初始化SharedPreferences
  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 获取预约提醒设置
  bool getAppointmentReminder() {
    return _prefs?.getBool(_keyAppointmentReminder) ?? true;
  }

  // 设置预约提醒
  Future<bool> setAppointmentReminder(bool value) async {
    return await _prefs?.setBool(_keyAppointmentReminder, value) ?? false;
  }

  // 获取主题模式
  ThemeMode getThemeMode() {
    final String? themeModeString = _prefs?.getString(_keyThemeMode);
    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light; // 默认使用浅色主题
    }
  }
}

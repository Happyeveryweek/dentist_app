import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 设置管理器 - 用于处理用户偏好设置的存储和获取
class SettingsManager {
  // 共享偏好设置键
  static const String _keyAppointmentReminder = 'appointment_reminder';
  static const String _keySystemNotification = 'system_notification';
  static const String _keyLanguage = 'language';
  static const String _keyTimeFormat = 'time_format';
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyFontSize = 'font_size';

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

  // 获取系统通知设置
  bool getSystemNotification() {
    return _prefs?.getBool(_keySystemNotification) ?? true;
  }

  // 设置系统通知
  Future<bool> setSystemNotification(bool value) async {
    return await _prefs?.setBool(_keySystemNotification, value) ?? false;
  }

  // 获取语言设置
  String getLanguage() {
    return _prefs?.getString(_keyLanguage) ?? '中文';
  }

  // 设置语言
  Future<bool> setLanguage(String value) async {
    return await _prefs?.setString(_keyLanguage, value) ?? false;
  }

  // 获取时间格式设置
  String getTimeFormat() {
    return _prefs?.getString(_keyTimeFormat) ?? '24小时制';
  }

  // 设置时间格式
  Future<bool> setTimeFormat(String value) async {
    return await _prefs?.setString(_keyTimeFormat, value) ?? false;
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

  // 设置主题模式
  Future<bool> setThemeMode(ThemeMode value) async {
    String themeModeString;
    switch (value) {
      case ThemeMode.light:
        themeModeString = 'light';
        break;
      case ThemeMode.dark:
        themeModeString = 'dark';
        break;
      case ThemeMode.system:
      default:
        themeModeString = 'system';
        break;
    }
    return await _prefs?.setString(_keyThemeMode, themeModeString) ?? false;
  }

  // 获取字体大小设置
  String getFontSize() {
    return _prefs?.getString(_keyFontSize) ?? '中';
  }

  // 设置字体大小
  Future<bool> setFontSize(String value) async {
    return await _prefs?.setString(_keyFontSize, value) ?? false;
  }
}

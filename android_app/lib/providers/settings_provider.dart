import 'package:flutter/material.dart';
import '../utils/settings_manager.dart';

/// 设置提供者 - 用于在应用程序中共享设置状态
class SettingsProvider extends ChangeNotifier {
  late SettingsManager _settingsManager;

  // 通知设置
  bool _appointmentReminder = true;
  bool _systemNotification = true;

  // 语言与区域设置
  String _language = '中文';
  String _timeFormat = '24小时制';

  // 系统设置
  ThemeMode _themeMode = ThemeMode.light;
  String _fontSize = '中';

  // 获取器
  bool get appointmentReminder => _appointmentReminder;
  bool get systemNotification => _systemNotification;
  String get language => _language;
  String get timeFormat => _timeFormat;
  ThemeMode get themeMode => _themeMode;
  String get fontSize => _fontSize;

  // 初始化设置
  Future<void> init() async {
    // 获取单例
    _settingsManager = await SettingsManager.getInstance();

    // 加载所有设置
    _appointmentReminder = _settingsManager.getAppointmentReminder();
    _systemNotification = _settingsManager.getSystemNotification();
    _language = _settingsManager.getLanguage();
    _timeFormat = _settingsManager.getTimeFormat();
    _themeMode = _settingsManager.getThemeMode();
    _fontSize = _settingsManager.getFontSize();

    // 通知监听器
    notifyListeners();
  }

  // 更新预约提醒设置
  Future<void> updateAppointmentReminder(bool value) async {
    if (await _settingsManager.setAppointmentReminder(value)) {
      _appointmentReminder = value;
      notifyListeners();
    }
  }

  // 更新系统通知设置
  Future<void> updateSystemNotification(bool value) async {
    if (await _settingsManager.setSystemNotification(value)) {
      _systemNotification = value;
      notifyListeners();
    }
  }

  // 更新语言设置
  Future<void> updateLanguage(String value) async {
    if (await _settingsManager.setLanguage(value)) {
      _language = value;
      notifyListeners();
    }
  }

  // 更新时间格式设置
  Future<void> updateTimeFormat(String value) async {
    if (await _settingsManager.setTimeFormat(value)) {
      _timeFormat = value;
      notifyListeners();
    }
  }

  // 更新主题模式
  Future<void> updateThemeMode(ThemeMode value) async {
    if (await _settingsManager.setThemeMode(value)) {
      _themeMode = value;
      notifyListeners();
    }
  }

  // 更新字体大小
  Future<void> updateFontSize(String value) async {
    if (await _settingsManager.setFontSize(value)) {
      _fontSize = value;
      notifyListeners();
    }
  }
}

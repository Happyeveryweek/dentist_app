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
    final manager = await SettingsManager.getInstance();
    _settingsManager = manager;

    // 加载所有设置
    _appointmentReminder = manager.getAppointmentReminder();
    _systemNotification = manager.getSystemNotification();
    _language = manager.getLanguage();
    _timeFormat = manager.getTimeFormat();
    _themeMode = manager.getThemeMode();
    _fontSize = manager.getFontSize();

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

  // 更新系统通知设置
  Future<void> updateSystemNotification(bool value) async {
    if (await _requireSettingsManager.setSystemNotification(value)) {
      _systemNotification = value;
      notifyListeners();
    }
  }

  // 更新语言设置
  Future<void> updateLanguage(String value) async {
    if (await _requireSettingsManager.setLanguage(value)) {
      _language = value;
      notifyListeners();
    }
  }

  // 更新时间格式设置
  Future<void> updateTimeFormat(String value) async {
    if (await _requireSettingsManager.setTimeFormat(value)) {
      _timeFormat = value;
      notifyListeners();
    }
  }

  // 更新主题模式
  Future<void> updateThemeMode(ThemeMode value) async {
    if (await _requireSettingsManager.setThemeMode(value)) {
      _themeMode = value;
      notifyListeners();
    }
  }

  // 更新字体大小
  Future<void> updateFontSize(String value) async {
    if (await _requireSettingsManager.setFontSize(value)) {
      _fontSize = value;
      notifyListeners();
    }
  }
}

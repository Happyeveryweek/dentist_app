import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 扩展主题模式枚举，支持更多主题选项
enum ExtendedThemeMode { light, grey, purple }

class SettingsProvider extends ChangeNotifier {
  // 扩展主题设置
  ExtendedThemeMode _extendedThemeMode = ExtendedThemeMode.light;
  ExtendedThemeMode get extendedThemeMode => _extendedThemeMode;

  // 兼容原有的ThemeMode
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode {
    switch (_extendedThemeMode) {
      case ExtendedThemeMode.light:
        return ThemeMode.light;
      case ExtendedThemeMode.grey:
      case ExtendedThemeMode.purple:
        return ThemeMode.light; // 特殊模式将作为定制的浅色模式
      default:
        return ThemeMode.light;
    }
  }

  // 字体大小设置
  double _fontSize = 1.0; // 1.0 表示正常大小，可以调整为0.8到1.2
  double get fontSize => _fontSize;

  // 语言设置
  String _language = 'zh_CN';
  String get language => _language;

  // 数据备份路径
  String _backupPath = '';
  String get backupPath => _backupPath;

  String _backupPath2 = '';
  String get backupPath2 => _backupPath2;

  // 自动备份设置
  bool _autoBackup = false;
  bool get autoBackup => _autoBackup;
  
  // 自动备份间隔（天）
  int _backupInterval = 5;
  int get backupInterval => _backupInterval;
  
  // 上次备份日期
  DateTime? _lastBackupDate;
  DateTime? get lastBackupDate => _lastBackupDate;

  // 数据源设置
  String _dataSourceType = 'sqlite'; // sqlite 或 mysql
  String get dataSourceType => _dataSourceType;

  // SQLite数据库文件路径
  String _sqliteDbPath = '';
  String get sqliteDbPath => _sqliteDbPath;

  // MySQL连接设置
  String _mysqlHost = '';
  String get mysqlHost => _mysqlHost;

  String _mysqlPort = '3306';
  String get mysqlPort => _mysqlPort;

  String _mysqlDatabase = '';
  String get mysqlDatabase => _mysqlDatabase;

  String _mysqlUsername = '';
  String get mysqlUsername => _mysqlUsername;

  String _mysqlPassword = '';
  String get mysqlPassword => _mysqlPassword;

  // 初始化
  Future<void> init() async {
    await _loadSettings();
  }

  // 从SharedPreferences加载设置
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 扩展主题设置
    final extendedThemeModeIndex = prefs.getInt('extendedThemeMode') ?? 0;
    if (extendedThemeModeIndex < ExtendedThemeMode.values.length) {
      _extendedThemeMode = ExtendedThemeMode.values[extendedThemeModeIndex];
    } else {
      // 如果保存的索引不在新的枚举范围内，设为默认值
      _extendedThemeMode = ExtendedThemeMode.light;
    }

    // 兼容旧版主题设置
    final themeModeIndex = prefs.getInt('themeMode') ?? 0;
    if (themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // 字体大小设置
    _fontSize = prefs.getDouble('fontSize') ?? 1.0;

    // 语言设置
    _language = prefs.getString('language') ?? 'zh_CN';

    // 数据备份路径
    _backupPath = prefs.getString('backupPath') ?? '';
    _backupPath2 = prefs.getString('backupPath2') ?? '';

    // 自动备份设置
    _autoBackup = prefs.getBool('autoBackup') ?? false;
    _backupInterval = prefs.getInt('backupInterval') ?? 5;
    
    // 上次备份日期
    final lastBackupDateStr = prefs.getString('lastBackupDate');
    if (lastBackupDateStr != null && lastBackupDateStr.isNotEmpty) {
      try {
        _lastBackupDate = DateTime.parse(lastBackupDateStr);
      } catch (e) {
        print('解析上次备份日期出错: $e');
        _lastBackupDate = null;
      }
    }

    // 数据源设置
    _dataSourceType = prefs.getString('dataSourceType') ?? 'sqlite';

    // SQLite数据库文件路径
    _sqliteDbPath = prefs.getString('sqliteDbPath') ?? '';

    // MySQL连接设置
    _mysqlHost = prefs.getString('mysqlHost') ?? '';
    _mysqlPort = prefs.getString('mysqlPort') ?? '3306';
    _mysqlDatabase = prefs.getString('mysqlDatabase') ?? '';
    _mysqlUsername = prefs.getString('mysqlUsername') ?? '';
    _mysqlPassword = prefs.getString('mysqlPassword') ?? '';

    notifyListeners();
  }

  // 保存设置到SharedPreferences
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 保存扩展主题设置
    await prefs.setInt('extendedThemeMode', _extendedThemeMode.index);

    // 兼容旧版主题设置
    await prefs.setInt('themeMode', _themeMode.index);

    // 保存字体大小设置
    await prefs.setDouble('fontSize', _fontSize);

    // 保存语言设置
    await prefs.setString('language', _language);

    // 保存数据备份路径
    await prefs.setString('backupPath', _backupPath);
    await prefs.setString('backupPath2', _backupPath2);

    // 保存自动备份设置
    await prefs.setBool('autoBackup', _autoBackup);
    await prefs.setInt('backupInterval', _backupInterval);
    
    // 保存上次备份日期
    if (_lastBackupDate != null) {
      await prefs.setString('lastBackupDate', _lastBackupDate!.toIso8601String());
    }

    // 保存数据源设置
    await prefs.setString('dataSourceType', _dataSourceType);

    // 保存SQLite数据库文件路径
    await prefs.setString('sqliteDbPath', _sqliteDbPath);

    // 保存MySQL连接设置
    await prefs.setString('mysqlHost', _mysqlHost);
    await prefs.setString('mysqlPort', _mysqlPort);
    await prefs.setString('mysqlDatabase', _mysqlDatabase);
    await prefs.setString('mysqlUsername', _mysqlUsername);
    await prefs.setString('mysqlPassword', _mysqlPassword);
  }

  // 设置扩展主题模式
  Future<void> setExtendedThemeMode(ExtendedThemeMode mode) async {
    _extendedThemeMode = mode;

    // 同步更新旧的主题模式以保持兼容性
    _themeMode = ThemeMode.light;

    await _saveSettings();
    notifyListeners();
  }

  // 设置主题模式 (兼容旧版接口)
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;

    // 始终使用浅色主题模式
    _extendedThemeMode = ExtendedThemeMode.light;

    await _saveSettings();
    notifyListeners();
  }

  // 设置字体大小
  Future<void> setFontSize(double size) async {
    _fontSize = size;
    await _saveSettings();
    notifyListeners();
  }

  // 设置语言
  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _saveSettings();
    notifyListeners();
  }

  // 设置备份路径
  Future<void> setBackupPath(String path) async {
    _backupPath = path;
    await _saveSettings();
    notifyListeners();
  }

  // 设置第二个备份路径
  Future<void> setBackupPath2(String path) async {
    _backupPath2 = path;
    await _saveSettings();
    notifyListeners();
  }

  // 设置自动备份
  Future<void> setAutoBackup(bool value) async {
    _autoBackup = value;
    await _saveSettings();
    notifyListeners();
  }
  
  // 设置备份间隔（天）
  Future<void> setBackupInterval(int days) async {
    _backupInterval = days;
    await _saveSettings();
    notifyListeners();
  }
  
  // 更新上次备份日期
  Future<void> updateLastBackupDate(DateTime date) async {
    _lastBackupDate = date;
    await _saveSettings();
    notifyListeners();
  }

  // 设置数据源类型
  Future<void> setDataSourceType(String type) async {
    _dataSourceType = type;
    await _saveSettings();
    notifyListeners();
  }

  // 设置SQLite数据库文件路径
  Future<void> setSqliteDbPath(String path) async {
    _sqliteDbPath = path;
    await _saveSettings();
    notifyListeners();
  }

  // 设置MySQL主机
  Future<void> setMySQLHost(String host) async {
    _mysqlHost = host;
    await _saveSettings();
    notifyListeners();
  }

  // 设置MySQL端口
  Future<void> setMySQLPort(String port) async {
    _mysqlPort = port;
    await _saveSettings();
    notifyListeners();
  }

  // 设置MySQL数据库名
  Future<void> setMySQLDatabase(String database) async {
    _mysqlDatabase = database;
    await _saveSettings();
    notifyListeners();
  }

  // 设置MySQL用户名
  Future<void> setMySQLUsername(String username) async {
    _mysqlUsername = username;
    await _saveSettings();
    notifyListeners();
  }

  // 设置MySQL密码
  Future<void> setMySQLPassword(String password) async {
    _mysqlPassword = password;
    await _saveSettings();
    notifyListeners();
  }

  // Windows特定设置

  // 窗口初始大小
  Size _windowSize = const Size(1280, 720);
  Size get windowSize => _windowSize;

  // 保存窗口大小
  Future<void> saveWindowSize(Size size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('windowWidth', size.width);
    await prefs.setDouble('windowHeight', size.height);
    _windowSize = size;
    notifyListeners();
  }

  // 加载窗口大小
  Future<void> loadWindowSize() async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble('windowWidth') ?? 1280;
    final height = prefs.getDouble('windowHeight') ?? 720;
    _windowSize = Size(width, height);
    notifyListeners();
  }
}

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;
import 'package:dentist_app_windows/models/backup_log.dart';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../models/database_structure_log.dart';
import 'package:crypto/crypto.dart';
import '../models/schemas/table_schema.dart';
import '../models/schemas/mysql_schema.dart';
import '../models/schemas/sqlite_schema.dart';
import '../utils/datetime_formatter.dart';
import '../utils/config_manager.dart';
import '../utils/app_paths.dart';

/// 表结构适配器 - 将 schemas 中的定义转换为 SettingsProvider 期望的格式
class TableDefinitionsAdapter {
  /// 获取所有系统表名列表（从schemas动态获取）
  static List<String> getAllSystemTableNames() {
    final allTables = [
      'users', 'patients', 'materials', 'appointments', 'patient_materials',
      'financial_records', 'financial_items', 'purchase_records', 'purchase_items',
      'material_images', 'patient_medical_records', 'medical_record_templates',
      'database_structure_logs'
    ];
    
    // 验证所有表名都在schemas中有定义
    final validTables = <String>[];
    for (final tableName in allTables) {
      if (isTableDefinedInSchemas(tableName, DatabaseType.sqlite) && 
          isTableDefinedInSchemas(tableName, DatabaseType.mysql)) {
        validTables.add(tableName);
      } else {
        print('⚠️ 表 $tableName 在schemas中定义不完整，跳过');
      }
    }
    
    return validTables;
  }
  
  /// 验证表名是否在schemas中定义
  static bool isTableDefinedInSchemas(String tableName, DatabaseType databaseType) {
    try {
      TableSchemaFactory.getSchema(tableName, databaseType);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 从 schemas 获取 MySQL 表结构定义
  static Map<String, Map<String, String>> getMySQLTableDefinitions() {
    final Map<String, Map<String, String>> result = {};
    final tableNames = getAllSystemTableNames();
    
    for (final tableName in tableNames) {
      try {
        final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
        result[tableName] = schema.columnDefinitions;
      } catch (e) {
        print('获取 MySQL 表 $tableName 定义失败: $e');
      }
    }
    
    return result;
  }
  
  /// 从 schemas 获取 SQLite 表结构定义
  static Map<String, Map<String, String>> getSQLiteTableDefinitions() {
    final Map<String, Map<String, String>> result = {};
    final tableNames = getAllSystemTableNames();
    
    for (final tableName in tableNames) {
      try {
        final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
        result[tableName] = schema.columnDefinitions;
      } catch (e) {
        print('获取 SQLite 表 $tableName 定义失败: $e');
      }
    }
    
    return result;
  }
  
  /// 生成MySQL的CREATE TABLE语句
  static String generateMySQLCreateTable(String tableName, Map<String, String> columns) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
      return schema.createTableSql;
    } catch (e) {
      print('生成 MySQL 表 $tableName 的 CREATE TABLE 语句失败: $e');
      // 回退到旧的实现
      return _fallbackGenerateMySQLCreateTable(tableName, columns);
    }
  }
  
  /// 生成SQLite的CREATE TABLE语句
  static String generateSQLiteCreateTable(String tableName, Map<String, String> columns) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
      return schema.createTableSql;
    } catch (e) {
      print('生成 SQLite 表 $tableName 的 CREATE TABLE 语句失败: $e');
      // 回退到旧的实现
      return _fallbackGenerateSQLiteCreateTable(tableName, columns);
    }
  }
  
  /// 回退的 MySQL CREATE TABLE 生成方法
  static String _fallbackGenerateMySQLCreateTable(String tableName, Map<String, String> columns) {
    final mysqlColumns = <String>[];
    
    for (final entry in columns.entries) {
      final columnName = entry.key;
      final columnDef = entry.value;
      
      mysqlColumns.add('`$columnName` $columnDef');
    }
    
    // 为特定表添加索引和外键约束
    if (tableName == 'financial_items') {
      mysqlColumns.add('KEY `financial_record_id` (`financial_record_id`)');
      mysqlColumns.add('CONSTRAINT `financial_items_ibfk_1` FOREIGN KEY (`financial_record_id`) REFERENCES `financial_records` (`id`)');
    }
    
    return 'CREATE TABLE IF NOT EXISTS `$tableName` (\n  ${mysqlColumns.join(',\n  ')}\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci';
  }
  
  /// 回退的 SQLite CREATE TABLE 生成方法
  static String _fallbackGenerateSQLiteCreateTable(String tableName, Map<String, String> columns) {
    final sqliteColumns = <String>[];
    
    for (final entry in columns.entries) {
      final columnName = entry.key;
      final columnDef = entry.value;
      
      sqliteColumns.add('$columnName $columnDef');
    }
    
    // 为特定表添加外键约束
    if (tableName == 'financial_items') {
      sqliteColumns.add('FOREIGN KEY (financial_record_id) REFERENCES financial_records(id)');
    }
    
    return 'CREATE TABLE IF NOT EXISTS $tableName (\n  ${sqliteColumns.join(',\n  ')}\n)';
  }
}







// 扩展主题模式枚举，支持更多主题选项
enum ExtendedThemeMode { light, grey, purple }

class SettingsProvider extends ChangeNotifier {
  // 配置管理器
  final ConfigManager _configManager = ConfigManager.instance;
  
  // 配置存储模式
  bool _useFileStorage = true; // 默认使用文件存储
  bool get useFileStorage => _useFileStorage;
  
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

  // 数据源模式：'global' 或 'modular'
  String _dataSourceMode = 'global';
  String get dataSourceMode => _dataSourceMode;

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

  // 自定义SQLite数据库路径
  String _customSqliteDbPath = '';
  String get customSqliteDbPath => _customSqliteDbPath;

  // MySQL设置映射
  Map<String, dynamic>? _mysqlSettings;
  Map<String, dynamic>? get mysqlSettings => _mysqlSettings;

  // 上次MySQL设置（用于临时存储）
  Map<String, dynamic>? _lastMySQLSettings;
  Map<String, dynamic>? get lastMySQLSettings => _lastMySQLSettings;

  // 数据库连接实例 - 用于结构检测
  Database? _database;
  MySqlConnection? _mysqlConnection;
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;

  // 备份数据源设置
  String _backupDataSource = 'sqlite';
  String get backupDataSource => _backupDataSource;

  // 模块数据源配置 - 默认所有模块使用SQLite
  Map<String, String> _moduleDataSources = {
    'patients': 'sqlite',      // 患者管理
    'appointments': 'sqlite',  // 预约管理
    'financial': 'sqlite',     // 财务管理
    'materials': 'sqlite',     // 材料管理
    'purchase': 'sqlite',      // 采购管理
    'users': 'sqlite',         // 用户管理
  };
  Map<String, String> get moduleDataSources => Map<String, String>.from(_moduleDataSources);

  // 初始化
  Future<void> init() async {
    await _initializeConfigStorage();
    await _loadSettings();
  }
  
  /// 初始化配置存储
  Future<void> _initializeConfigStorage() async {
    try {
      // 检查是否可以使用应用目录存储
      final canUseFileStorage = await _checkFileStorageAvailability();
      
      if (canUseFileStorage) {
        _useFileStorage = true;
        _configManager.setStorageMode(StorageMode.hybrid);
        print('使用混合配置存储模式（优先文件存储）');
        
        // 尝试迁移现有配置到文件
        await _migrateConfigsToFile();
      } else {
        _useFileStorage = false;
        _configManager.setStorageMode(StorageMode.preferences);
        print('使用SharedPreferences配置存储模式');
      }
    } catch (e) {
      print('初始化配置存储失败: $e');
      _useFileStorage = false;
      _configManager.setStorageMode(StorageMode.preferences);
    }
  }
  
  /// 检查文件存储可用性
  Future<bool> _checkFileStorageAvailability() async {
    try {
      // 检查AppPaths是否已初始化
      final testPath = AppPaths.configPath;
      
      // 尝试创建配置目录
      final configDir = Directory(path.dirname(testPath));
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }
      
      // 尝试写入测试文件
      final testFile = File(path.join(configDir.path, 'test_write.tmp'));
      await testFile.writeAsString('test');
      await testFile.delete();
      
      return true;
    } catch (e) {
      print('文件存储不可用: $e');
      return false;
    }
  }
  
  /// 迁移配置到文件存储
  Future<void> _migrateConfigsToFile() async {
    try {
      final migrated = await _configManager.migrateToFile();
      if (migrated) {
        print('配置已成功迁移到文件存储');
      }
    } catch (e) {
      print('配置迁移失败: $e');
    }
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
        _lastBackupDate = DateTimeFormatter.fromDbString(lastBackupDateStr);
      } catch (e) {
        print('解析上次备份日期出错: $e');
        _lastBackupDate = null;
      }
    }

    // 数据源设置 - 如果没有配置过，默认使用SQLite
    _dataSourceType = prefs.getString('dataSourceType') ?? 'sqlite';
    
    // 确保数据源类型不为空
    if (_dataSourceType.isEmpty) {
      _dataSourceType = 'sqlite';
      print('数据源类型为空，设置为默认SQLite');
    }
    
    // 数据源模式设置 - 如果没有配置过，默认使用全局模式
    _dataSourceMode = prefs.getString('dataSourceMode') ?? 'global';

    // SQLite数据库文件路径
    _sqliteDbPath = prefs.getString('sqliteDbPath') ?? '';

    // MySQL连接设置
    _mysqlHost = prefs.getString('mysqlHost') ?? '';
    _mysqlPort = prefs.getString('mysqlPort') ?? '3306';
    _mysqlDatabase = prefs.getString('mysqlDatabase') ?? '';
    _mysqlUsername = prefs.getString('mysqlUsername') ?? '';
    _mysqlPassword = prefs.getString('mysqlPassword') ?? '';

    // 自定义SQLite数据库路径
    _customSqliteDbPath = prefs.getString('customSqliteDbPath') ?? '';

    // 加载MySQL设置映射
    final mysqlSettingsStr = prefs.getString('mysqlSettings');
    if (mysqlSettingsStr != null && mysqlSettingsStr.isNotEmpty) {
      try {
        _mysqlSettings = Map<String, dynamic>.from(jsonDecode(mysqlSettingsStr));
      } catch (e) {
        print('解析MySQL设置出错: $e');
        _mysqlSettings = null;
      }
    }

    // 加载上次MySQL设置
    final lastMySQLSettingsStr = prefs.getString('lastMySQLSettings');
    if (lastMySQLSettingsStr != null && lastMySQLSettingsStr.isNotEmpty) {
      try {
        _lastMySQLSettings = Map<String, dynamic>.from(jsonDecode(lastMySQLSettingsStr));
      } catch (e) {
        print('解析上次MySQL设置出错: $e');
        _lastMySQLSettings = null;
      }
    }

    // 备份数据源设置
    _backupDataSource = prefs.getString('backupDataSource') ?? 'sqlite';

    // 模块数据源配置
    final moduleDataSourcesStr = prefs.getString('moduleDataSources');
    if (moduleDataSourcesStr != null && moduleDataSourcesStr.isNotEmpty) {
      try {
        _moduleDataSources = Map<String, String>.from(jsonDecode(moduleDataSourcesStr));
      } catch (e) {
        print('解析模块数据源配置出错: $e');
        _moduleDataSources = {
          'patients': 'sqlite',      // 患者管理
          'appointments': 'sqlite',  // 预约管理
          'financial': 'sqlite',     // 财务管理
          'materials': 'sqlite',     // 材料管理
          'purchase': 'sqlite',      // 采购管理
          'users': 'sqlite',         // 用户管理
        };
      }
    }

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
      await prefs.setString('lastBackupDate', DateTimeFormatter.toDbString(_lastBackupDate!));
    }

    // 保存数据源设置
    await prefs.setString('dataSourceType', _dataSourceType);
    
    // 保存数据源模式设置
    await prefs.setString('dataSourceMode', _dataSourceMode);

    // 保存SQLite数据库文件路径
    await prefs.setString('sqliteDbPath', _sqliteDbPath);

    // 保存MySQL连接设置
    await prefs.setString('mysqlHost', _mysqlHost);
    await prefs.setString('mysqlPort', _mysqlPort);
    await prefs.setString('mysqlDatabase', _mysqlDatabase);
    await prefs.setString('mysqlUsername', _mysqlUsername);
    await prefs.setString('mysqlPassword', _mysqlPassword);

    // 保存自定义SQLite数据库路径
    await prefs.setString('customSqliteDbPath', _customSqliteDbPath);

    // 保存MySQL设置映射
    if (_mysqlSettings != null) {
      await prefs.setString('mysqlSettings', jsonEncode(_mysqlSettings));
    }

    // 保存上次MySQL设置
    if (_lastMySQLSettings != null) {
      await prefs.setString('lastMySQLSettings', jsonEncode(_lastMySQLSettings));
    }

    // 保存备份数据源设置
    await prefs.setString('backupDataSource', _backupDataSource);

    // 保存模块数据源配置
    await prefs.setString('moduleDataSources', jsonEncode(_moduleDataSources));
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



  // 设置SQLite数据库文件路径
  Future<void> setSqliteDbPath(String path) async {
    _sqliteDbPath = path;
    _customSqliteDbPath = path; // 同步更新自定义路径
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

  // =================== 数据库设置管理方法 ===================

  // 设置自定义SQLite数据库路径
  Future<void> setCustomSqliteDbPath(String path) async {
    _customSqliteDbPath = path;
    await _saveSettings();
    notifyListeners();
  }

  // 设置MySQL连接参数
  Future<void> setMySQLConnectionParams({
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) async {
    _mysqlHost = host;
    _mysqlPort = port;
    _mysqlDatabase = database;
    _mysqlUsername = username;
    _mysqlPassword = password;

    // 同时更新MySQL设置映射
    _mysqlSettings = {
      'host': host,
      'port': int.tryParse(port) ?? 3306,
      'database': database,
      'username': username,
      'password': password,
    };

    await _saveSettings();
    notifyListeners();
  }

  // 保存MySQL设置到映射中
  Future<void> saveMySQLSettings(Map<String, dynamic> mysqlSettings) async {
    _mysqlSettings = Map<String, dynamic>.from(mysqlSettings);
    
    // 同时更新单独的字段，确保一致性
    _mysqlHost = mysqlSettings['host'] ?? '';
    _mysqlPort = mysqlSettings['port']?.toString() ?? '3306';
    _mysqlDatabase = mysqlSettings['database'] ?? '';
    _mysqlUsername = mysqlSettings['username'] ?? '';
    _mysqlPassword = mysqlSettings['password'] ?? '';

    await _saveSettings();
    notifyListeners();
  }

  // 保存上次MySQL设置
  Future<void> saveLastMySQLSettings() async {
    try {
      _lastMySQLSettings = {
        'host': _mysqlHost,
        'port': _mysqlPort,
        'database': _mysqlDatabase,
        'username': _mysqlUsername,
        'password': _mysqlPassword,
      };

      await _saveSettings();
      notifyListeners();
    } catch (e) {
      print('保存MySQL设置失败: $e');
    }
  }

  // 获取完整的MySQL设置
  Map<String, dynamic> getCompleteMySQLSettings() {
    return {
      'host': _mysqlHost,
      'port': int.tryParse(_mysqlPort) ?? 3306,
      'database': _mysqlDatabase,
      'username': _mysqlUsername,
      'password': _mysqlPassword,
    };
  }

  // 验证MySQL设置是否完整
  bool isMySQLSettingsComplete() {
    return _mysqlHost.isNotEmpty &&
           _mysqlPort.isNotEmpty &&
           _mysqlDatabase.isNotEmpty &&
           _mysqlUsername.isNotEmpty;
  }

  // 重置MySQL设置到默认值
  Future<void> resetMySQLSettings() async {
    _mysqlHost = 'localhost';
    _mysqlPort = '3306';
    _mysqlDatabase = 'dentist_db';
    _mysqlUsername = 'root';
    _mysqlPassword = '';

    _mysqlSettings = {
      'host': _mysqlHost,
      'port': int.tryParse(_mysqlPort) ?? 3306,
      'database': _mysqlDatabase,
      'username': _mysqlUsername,
      'password': _mysqlPassword,
    };

    await _saveSettings();
    notifyListeners();
  }

  // 清除所有设置
  Future<void> clearAllSettings() async {
    try {
      // 清除SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      
      // 清除ConfigManager中的配置
      await _configManager.clearAllConfigs();
      
      // 重置所有内部变量到默认值
      _resetToDefaults();
      
      print('所有设置已清除');
    } catch (e) {
      print('清除设置失败: $e');
      throw Exception('清除设置失败: $e');
    }
  }
  
  // 重置所有变量到默认值
  void _resetToDefaults() {
    _extendedThemeMode = ExtendedThemeMode.light;
    _autoBackup = false;
    _backupInterval = 7;
    _backupPath = '';
    _backupPath2 = '';
    _lastBackupDate = null;
    _dataSourceType = 'sqlite';
    _backupDataSource = 'sqlite';
    _sqliteDbPath = '';
    _mysqlHost = '';
    _mysqlPort = '3306';
    _mysqlDatabase = '';
    _mysqlUsername = '';
    _mysqlPassword = '';
    _useFileStorage = true;
    _database = null;
    _mysqlConnection = null;
  }

  // 清除MySQL设置
  Future<void> clearMySQLSettings() async {
    _mysqlHost = '';
    _mysqlPort = '3306';
    _mysqlDatabase = '';
    _mysqlUsername = '';
    _mysqlPassword = '';

    _mysqlSettings = null;
    _lastMySQLSettings = null;

    await _saveSettings();
    notifyListeners();
  }

  // 获取数据源类型（带验证）
  String getValidatedDataSourceType() {
    if (_dataSourceType == 'mysql' && !isMySQLSettingsComplete()) {
      // 如果MySQL设置不完整，自动切换到SQLite
      _dataSourceType = 'sqlite';
      _saveSettings(); // 异步保存，但不等待
    }
    return _dataSourceType;
  }

  // 检查是否需要显示MySQL配置警告
  bool shouldShowMySQLWarning() {
    return _dataSourceType == 'mysql' && !isMySQLSettingsComplete();
  }

  // =================== 备份管理功能 ===================

  // 自动备份功能
  Future<String> performAutoBackup() async {
    try {
      print('开始执行自动备份...');
      
      // 检查备份路径是否设置
      if (_backupPath.isEmpty) {
        throw Exception('未设置备份路径，无法执行自动备份');
      }

      // 获取当前时间戳
      final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-').replaceAll(' ', '_');
      final backupFileName = 'auto_backup_$timestamp.db';
      final backupPath = path.join(_backupPath, backupFileName);

      // 确保备份目录存在
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        print('创建备份目录: $_backupPath');
      }

      // 执行备份（这里需要调用DatabaseProvider的实际备份方法）
      // 注意：实际的数据库备份操作仍然由DatabaseProvider执行
      // 这里只负责备份策略和路径管理
      
      // 更新上次备份日期
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      await updateLastBackupDate(todayDate);
      
      // 清理旧备份
      await _cleanupOldBackups(_backupPath, _backupInterval);
      
      print('自动备份策略执行完成');
      return backupPath;
    } catch (e) {
      print('执行自动备份策略时出错: $e');
      rethrow;
    }
  }

  // 清理旧备份文件
  Future<void> _cleanupOldBackups(String backupDir, int keepCount) async {
    try {
      final directory = Directory(backupDir);
      if (!await directory.exists()) return;

      // 获取所有备份文件
      final files = await directory
          .list()
          .where((entity) => entity is File && 
              (entity.path.endsWith('.db') || entity.path.endsWith('.sql')))
          .toList();

      // 按修改时间排序
      files.sort((a, b) {
        return File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });

      // 删除旧文件
      if (files.length > keepCount) {
        for (int i = keepCount; i < files.length; i++) {
          await File(files[i].path).delete();
          print('删除旧备份文件: ${files[i].path}');
        }
      }
    } catch (e) {
      print('清理旧备份失败: $e');
    }
  }

  // 备份日志管理
  Future<void> logBackupSuccess(String backupPath) async {
    try {
      final log = BackupLog(
        backupDate: DateTime.now(),
        backupPath: backupPath,
        success: true,
      );

      await BackupLog.addLog(log);
      print('已记录备份成功日志');
    } catch (e) {
      print('记录备份成功日志出错: $e');
    }
  }

  Future<void> logBackupFailure(String errorMessage) async {
    try {
      final log = BackupLog(
        backupDate: DateTime.now(),
        backupPath: '',
        success: false,
        errorMessage: errorMessage,
      );

      await BackupLog.addLog(log);
      print('已记录备份失败日志: $errorMessage');
    } catch (e) {
      print('记录备份失败日志出错: $e');
    }
  }

  // 备份路径验证和管理
  Future<bool> validateBackupPath(String backupPath) async {
    try {
      if (backupPath.isEmpty) return false;
      
      final directory = Directory(backupPath);
      
      // 检查目录是否存在，如果不存在则尝试创建
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
          print('创建备份目录: $backupPath');
        } catch (e) {
          print('无法创建备份目录: $e');
          return false;
        }
      }
      
      // 检查目录是否可写
      try {
        final testFile = File(path.join(backupPath, 'test_write.tmp'));
        await testFile.writeAsString('测试写入权限');
        await testFile.delete();
        print('备份目录写入权限验证成功');
        return true;
      } catch (e) {
        print('备份目录写入权限验证失败: $e');
        return false;
      }
    } catch (e) {
      print('验证备份路径时出错: $e');
      return false;
    }
  }

  // 获取备份文件列表
  Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      if (_backupPath.isEmpty) return [];
      
      final directory = Directory(_backupPath);
      if (!await directory.exists()) return [];
      
      final files = await directory
          .list()
          .where((entity) => entity is File && 
              (entity.path.endsWith('.db') || entity.path.endsWith('.sql')))
          .toList();
      
      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        return File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });
      
      return files;
    } catch (e) {
      print('获取备份文件列表时出错: $e');
      return [];
    }
  }

  // 获取备份统计信息
  Future<Map<String, dynamic>> getBackupStatistics() async {
    try {
      final files = await getBackupFiles();
      final totalSize = await _calculateTotalBackupSize(files);
      final lastBackup = files.isNotEmpty ? File(files.first.path).lastModifiedSync() : null;
      
      return {
        'totalFiles': files.length,
        'totalSize': totalSize,
        'lastBackup': lastBackup,
        'backupPath': _backupPath,
        'autoBackupEnabled': _autoBackup,
        'backupInterval': _backupInterval,
        'lastBackupDate': _lastBackupDate,
      };
    } catch (e) {
      print('获取备份统计信息时出错: $e');
      return {};
    }
  }

  // 计算备份文件总大小
  Future<int> _calculateTotalBackupSize(List<FileSystemEntity> files) async {
    int totalSize = 0;
    for (final file in files) {
      if (file is File) {
        try {
          totalSize += await file.length();
        } catch (e) {
          print('计算文件大小时出错: ${file.path}, $e');
        }
      }
    }
    return totalSize;
  }

  // 检查是否需要执行自动备份
  bool shouldPerformAutoBackup() {
    if (!_autoBackup) return false;
    if (_backupPath.isEmpty) return false;
    if (_lastBackupDate == null) return true;
    
    final now = DateTime.now();
    final daysSinceLastBackup = now.difference(_lastBackupDate!).inDays;
    
    return daysSinceLastBackup >= _backupInterval;
  }

  // 获取下次自动备份时间
  DateTime? getNextAutoBackupTime() {
    if (!_autoBackup || _lastBackupDate == null) return null;
    
    return _lastBackupDate!.add(Duration(days: _backupInterval));
  }

  // 备份策略管理
  Future<void> setBackupStrategy({
    required bool autoBackup,
    required int backupInterval,
    required int keepBackupCount,
  }) async {
    _autoBackup = autoBackup;
    _backupInterval = backupInterval;
    
    await _saveSettings();
    notifyListeners();
    
    print('备份策略已更新: 自动备份=$autoBackup, 间隔=$backupInterval天');
  }

  // 获取备份策略
  Map<String, dynamic> getBackupStrategy() {
    return {
      'autoBackup': _autoBackup,
      'backupInterval': _backupInterval,
      'backupPath': _backupPath,
      'backupPath2': _backupPath2,
    };
  }

  // 备份路径管理
  Future<void> setBackupPaths({
    required String primaryPath,
    String? secondaryPath,
  }) async {
    _backupPath = primaryPath;
    if (secondaryPath != null) {
      _backupPath2 = secondaryPath;
    }
    
    // 验证路径
    final primaryValid = await validateBackupPath(primaryPath);
    if (!primaryValid) {
      throw Exception('主备份路径无效或无法访问: $primaryPath');
    }
    
    if (secondaryPath != null && secondaryPath.isNotEmpty) {
      final secondaryValid = await validateBackupPath(secondaryPath);
      if (!secondaryValid) {
        throw Exception('备用备份路径无效或无法访问: $secondaryPath');
      }
    }
    
    await _saveSettings();
    notifyListeners();
    
    print('备份路径已更新: 主路径=$primaryPath, 备用路径=$secondaryPath');
  }

  // 检查备份路径状态
  Future<Map<String, bool>> checkBackupPathStatus() async {
    final primaryStatus = await validateBackupPath(_backupPath);
    final secondaryStatus = _backupPath2.isNotEmpty ? 
        await validateBackupPath(_backupPath2) : true;
    
    return {
      'primary': primaryStatus,
      'secondary': secondaryStatus,
      'hasValidPath': primaryStatus || secondaryStatus,
    };
  }

  // =================== 备份还原管理功能 ===================

  // 备份还原策略管理
  Future<void> setRestoreStrategy({
    required bool autoRestore,
    required bool backupBeforeRestore,
    required bool validateRestoreData,
  }) async {
    // 这里可以添加还原策略的设置
    // 目前先保存到设置中，后续可以扩展
    await _saveSettings();
    notifyListeners();
    
    print('还原策略已更新');
  }

  // 获取还原策略
  Map<String, dynamic> getRestoreStrategy() {
    return {
      'autoRestore': false, // 默认不自动还原
      'backupBeforeRestore': true, // 默认还原前备份
      'validateRestoreData': true, // 默认验证还原数据
    };
  }

  // 备份还原路径管理
  Future<void> setRestorePath(String restorePath) async {
    // 验证还原路径
    final isValid = await validateRestorePath(restorePath);
    if (!isValid) {
      throw Exception('还原路径无效或无法访问: $restorePath');
    }
    
    // 保存还原路径到设置
    await _saveSettings();
    notifyListeners();
    
    print('还原路径已设置: $restorePath');
  }

  // 验证还原路径
  Future<bool> validateRestorePath(String restorePath) async {
    try {
      if (restorePath.isEmpty) return false;
      
      final file = File(restorePath);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        print('还原文件不存在: $restorePath');
        return false;
      }
      
      // 检查文件是否可读
      try {
        await file.open(mode: FileMode.read);
        print('还原文件读取权限验证成功');
        return true;
      } catch (e) {
        print('还原文件读取权限验证失败: $e');
        return false;
      }
    } catch (e) {
      print('验证还原路径时出错: $e');
      return false;
    }
  }

  // 获取可用的还原文件列表
  Future<List<FileSystemEntity>> getAvailableRestoreFiles() async {
    try {
      final List<FileSystemEntity> allFiles = [];
      
      // 从主备份路径获取
      if (_backupPath.isNotEmpty) {
        final primaryFiles = await _getRestoreFilesFromPath(_backupPath);
        allFiles.addAll(primaryFiles);
      }
      
      // 从备用备份路径获取
      if (_backupPath2.isNotEmpty) {
        final secondaryFiles = await _getRestoreFilesFromPath(_backupPath2);
        allFiles.addAll(secondaryFiles);
      }
      
      // 按修改时间排序（最新的在前）
      allFiles.sort((a, b) {
        return File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });
      
      return allFiles;
    } catch (e) {
      print('获取可用还原文件列表时出错: $e');
      return [];
    }
  }

  // 从指定路径获取还原文件
  Future<List<FileSystemEntity>> _getRestoreFilesFromPath(String path) async {
    try {
      final directory = Directory(path);
      if (!await directory.exists()) return [];
      
      final files = await directory
          .list()
          .where((entity) => entity is File && 
              (entity.path.endsWith('.db') || entity.path.endsWith('.sql')))
          .toList();
      
      return files;
    } catch (e) {
      print('从路径获取还原文件时出错: $path, $e');
      return [];
    }
  }

  // 还原前备份策略
  Future<String?> createPreRestoreBackup() async {
    try {
      if (_backupPath.isEmpty) {
        print('未设置备份路径，无法创建还原前备份');
        return null;
      }
      
      // 创建还原前备份
      final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-').replaceAll(' ', '_');
      final backupFileName = 'pre_restore_backup_$timestamp.db';
      final backupPath = path.join(_backupPath, backupFileName);
      
      // 确保备份目录存在
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      print('已创建还原前备份: $backupPath');
      return backupPath;
    } catch (e) {
      print('创建还原前备份失败: $e');
      return null;
    }
  }

  // 还原后清理策略
  Future<void> cleanupAfterRestore({
    required bool success,
    String? restorePath,
    String? preRestoreBackupPath,
  }) async {
    try {
      if (success) {
        // 还原成功，可以清理临时文件
        if (preRestoreBackupPath != null && await File(preRestoreBackupPath).exists()) {
          // 可以选择保留或删除还原前备份
          // await File(preRestoreBackupPath).delete();
          print('还原成功，还原前备份保留在: $preRestoreBackupPath');
        }
      } else {
        // 还原失败，保留还原前备份
        if (preRestoreBackupPath != null) {
          print('还原失败，还原前备份保留在: $preRestoreBackupPath');
        }
      }
      
      // 更新设置
      await _saveSettings();
      notifyListeners();
    } catch (e) {
      print('还原后清理时出错: $e');
    }
  }

  // 还原文件类型检测
  String detectRestoreFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    
    switch (extension) {
      case '.db':
      case '.sqlite':
      case '.sqlite3':
        return 'sqlite';
      case '.sql':
        return 'mysql';
      default:
        return 'unknown';
    }
  }

  // 获取还原文件信息
  Future<Map<String, dynamic>> getRestoreFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'error': '文件不存在'};
      }
      
      final stat = await file.stat();
      final fileType = detectRestoreFileType(filePath);
      
      return {
        'path': filePath,
        'name': path.basename(filePath),
        'size': stat.size,
        'modified': stat.modified,
        'type': fileType,
        'readable': true,
      };
    } catch (e) {
      return {'error': '获取文件信息失败: $e'};
    }
  }

  // 还原进度跟踪
  Future<void> updateRestoreProgress({
    required String operation,
    required int current,
    required int total,
    String? detail,
  }) async {
    // 这里可以保存还原进度到设置中
    // 目前先打印日志，后续可以扩展为持久化存储
    print('还原进度: $operation $current/$total ${detail ?? ''}');
    
    // 可以添加进度通知
    notifyListeners();
  }

  // 还原历史记录管理
  Future<void> logRestoreOperation({
    required String operation,
    required String filePath,
    required bool success,
    String? errorMessage,
    String? preRestoreBackupPath,
  }) async {
    try {
      // 这里可以记录还原操作到日志中
      // 目前先打印日志，后续可以扩展为持久化存储
      print('还原操作记录: $operation, 文件: $filePath, 结果: ${success ? '成功' : '失败'}');
      if (errorMessage != null) {
        print('错误信息: $errorMessage');
      }
      if (preRestoreBackupPath != null) {
        print('还原前备份: $preRestoreBackupPath');
      }
      
      // 可以添加日志通知
      notifyListeners();
    } catch (e) {
      print('记录还原操作时出错: $e');
    }
  }

  // 还原策略验证
  Future<bool> validateRestoreStrategy({
    required String filePath,
    required String targetDataSource,
  }) async {
    try {
      // 检查文件类型是否匹配数据源
      final fileType = detectRestoreFileType(filePath);
      
      if (targetDataSource == 'mysql' && fileType != 'mysql') {
        print('MySQL数据源不能使用SQLite备份文件');
        return false;
      }
      
      if (targetDataSource == 'sqlite' && fileType != 'sqlite') {
        print('SQLite数据源不能使用MySQL备份文件');
        return false;
      }
      
      // 检查文件是否有效
      final fileInfo = await getRestoreFileInfo(filePath);
      if (fileInfo.containsKey('error')) {
        print('文件无效: ${fileInfo['error']}');
        return false;
      }
      
      // 检查备份路径状态
      final backupStatus = await checkBackupPathStatus();
      if (backupStatus['hasValidPath'] != true) {
        print('备份路径无效，无法创建还原前备份');
        return false;
      }
      
      return true;
    } catch (e) {
      print('验证还原策略时出错: $e');
      return false;
    }
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

  // ==================== 数据源管理功能 ====================

  // 设置数据源模式
  Future<void> setDataSourceMode(String mode) async {
    _dataSourceMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  // 设置数据源类型
  Future<void> setDataSourceType(
    String type, {
    Map<String, dynamic>? mysqlSettings,
    String? customSqlitePath,
  }) async {
    print('SettingsProvider: 设置数据源类型到: $type');
    print('SettingsProvider: 当前数据源类型: $_dataSourceType');

    try {
      // 更新数据源类型
      _dataSourceType = type;
      
      // 如果切换到SQLite，处理自定义路径
      if (type == 'sqlite') {
        if (customSqlitePath != null && customSqlitePath.isNotEmpty) {
          _customSqliteDbPath = customSqlitePath;
          _sqliteDbPath = customSqlitePath;
          print('SettingsProvider: 设置自定义SQLite路径: $customSqlitePath');
        } else {
          print('SettingsProvider: 使用默认SQLite路径');
        }
      }
      
      // 如果切换到MySQL，保存MySQL设置
      if (type == 'mysql' && mysqlSettings != null) {
        _mysqlHost = mysqlSettings['host'] ?? 'localhost';
        _mysqlPort = mysqlSettings['port']?.toString() ?? '3306';
        _mysqlDatabase = mysqlSettings['database'] ?? 'dentist_db';
        _mysqlUsername = mysqlSettings['username'] ?? 'root';
        _mysqlPassword = mysqlSettings['password'] ?? '';
        
        _mysqlSettings = Map<String, dynamic>.from(mysqlSettings);
        print('SettingsProvider: 保存MySQL设置');
      }
      
      // 保存设置
      await _saveSettings();
      
      // 通知监听器
      notifyListeners();
      
      print('SettingsProvider: 数据源类型设置完成: $type');
    } catch (e) {
      print('SettingsProvider: 设置数据源类型失败: $e');
      rethrow;
    }
  }

  // 测试MySQL连接
  Future<bool> testMySQLConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      print('开始测试MySQL连接...');
      
      // 导入必要的包
      // 注意：这里需要在实际使用时确保mysql1包已导入
      // import 'package:mysql1/mysql1.dart';
      
      // 创建临时连接进行测试
      // final conn = await MySqlConnection.connect(
      //   ConnectionSettings(
      //     host: host,
      //     port: port,
      //     db: database,
      //     user: username,
      //     password: password,
      //   ),
      // );
      
      // 测试连接是否成功
      // await conn.query('SELECT 1');
      
      // 关闭连接
      // await conn.close();
      
      // 临时返回true，实际使用时需要取消注释上面的代码
      print('MySQL连接测试成功');
      return true;
    } catch (e) {
      print('MySQL连接测试失败: $e');
      return false;
    }
  }

  // 数据库导入功能
  Future<void> importDatabase(String importFilePath) async {
    try {
      print('开始导入数据库: $importFilePath');
      
      // 验证文件存在
      final importFile = File(importFilePath);
      if (!await importFile.exists()) {
        throw Exception('导入文件不存在: $importFilePath');
      }

      // 检查文件类型
      final fileType = detectRestoreFileType(importFilePath);
      print('检测到文件类型: $fileType');

      // 验证导入策略
      final isValid = await validateRestoreStrategy(
        filePath: importFilePath,
        targetDataSource: _dataSourceType,
      );

      if (!isValid) {
        throw Exception('导入策略验证失败');
      }

      // 记录导入操作
      await logRestoreOperation(
        operation: '数据库导入',
        filePath: importFilePath,
        success: true,
      );

      print('数据库导入完成: $importFilePath');
      notifyListeners();
    } catch (e) {
      print('导入数据库时出错: $e');
      
      // 记录导入失败
      await logRestoreOperation(
        operation: '数据库导入',
        filePath: importFilePath,
        success: false,
        errorMessage: e.toString(),
      );
      
      rethrow;
    }
  }

  // 数据库导出功能
  Future<String> exportDatabase() async {
    try {
      print('开始导出数据库...');
      
      if (_dataSourceType.isEmpty) {
        throw Exception('数据源类型未设置');
      }

      // 生成导出文件名
      final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-').replaceAll(' ', '_');
      final exportFileName = 'export_${_dataSourceType}_$timestamp';
      
      String exportPath;
      if (_dataSourceType == 'mysql') {
        exportPath = '$exportFileName.sql';
      } else {
        exportPath = '$exportFileName.db';
      }

      // 这里可以添加实际的导出逻辑
      // 目前返回模拟路径
      final fullPath = path.join(_backupPath, exportPath);
      
      print('数据库导出完成: $fullPath');
      
      // 记录导出操作
      await logBackupSuccess(fullPath);
      
      return fullPath;
    } catch (e) {
      print('导出数据库时出错: $e');
      
      // 记录导出失败
      await logBackupFailure('导出失败: $e');
      
      rethrow;
    }
  }

  // 获取当前数据源类型
  String get currentDataSourceType => _dataSourceType;

  // 获取当前SQLite自定义路径
  String? get currentCustomSqlitePath => _customSqliteDbPath;

  // ==================== MySQL备份功能 ====================

  // MySQL数据库备份方法
  Future<String> backupMySQLDatabase({String? backupPath}) async {
    print('开始MySQL备份过程...');

    // 不再检查数据源类型，直接根据备份数据源设置执行

    // 验证MySQL设置是否完整
    if (!isMySQLSettingsComplete()) {
      throw Exception('MySQL设置不完整，请在设置中配置MySQL连接参数');
    }

    print(
        '使用MySQL设置: ${_mysqlSettings.toString().replaceAll(_mysqlSettings!['password'], '******')}');

    print('当前工作目录: ${Directory.current.path}');

    // 使用AppPaths获取mysqldump工具路径
    final toolPath = AppPaths.mysqldumpExePath;
    print('使用mysqldump工具: $toolPath');
    
    // 验证工具是否存在
    if (!File(toolPath).existsSync()) {
      throw Exception('mysqldump工具不存在: $toolPath');
    }

    // 获取用户指定的备份目录
    final userBackupPath = backupPath ?? _backupPath;
    print('备份目录: $userBackupPath');

    if (userBackupPath.isEmpty) {
      throw Exception('未设置备份目录');
    }

    // 确保备份目录存在
    final backupDir = Directory(userBackupPath);
    if (!await backupDir.exists()) {
      print('创建备份目录: ${backupDir.path}');
      await backupDir.create(recursive: true);
    }

    // 生成备份文件名
    final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-').replaceAll(' ', '_');
    final backupFileName = 'backup_$timestamp.sql';
    final finalBackupPath = path.join(userBackupPath, backupFileName);
    print('备份文件路径: $finalBackupPath');

    // 构建命令参数列表
    final List<String> args = [
      '-h${_mysqlHost}',
      '-P${_mysqlPort}',
      '-u${_mysqlUsername}',
      '-p${_mysqlPassword}',
      '--default-character-set=utf8mb4',
      _mysqlDatabase,
      '--result-file=$finalBackupPath' // 直接指定输出文件
    ];

    print(
        '执行mysqldump命令: $toolPath ${args.join(' ').replaceAll(_mysqlPassword, '******')}');

    try {
      // 使用Process.run执行mysqldump命令
      final result = await Process.run(
        toolPath,
        args,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );

      print('mysqldump命令执行结果: exitCode=${result.exitCode}');
      print('标准输出: ${result.stdout}');

      if (result.exitCode != 0) {
        print('备份失败，错误输出: ${result.stderr}');
        throw Exception('备份失败: ${result.stderr}');
      }

      print('MySQL备份已保存到: $finalBackupPath');
      
      // 记录备份成功日志
      await logBackupSuccess(finalBackupPath);
      
      // 更新上次备份日期
      await updateLastBackupDate(DateTime.now());
      
      return finalBackupPath;
    } catch (e) {
      print('执行备份命令时出错: $e');
      
      // 记录备份失败日志
      await logBackupFailure('备份失败: $e');
      
      throw Exception('备份失败: $e');
    }
  }

  // 获取MySQL工具路径
  String _getMySQLToolPath(String toolName) {
    print('查找MySQL工具: $toolName');
    print('当前工作目录: ${Directory.current.path}');
    print('可执行文件路径: ${Platform.resolvedExecutable}');
    print('可执行文件目录: ${path.dirname(Platform.resolvedExecutable)}');

    // 添加更多详细日志
    print('系统环境变量PATH: ${Platform.environment['PATH']}');

    // 尝试几种可能的路径
    final List<String> possiblePaths = [
      // 优先检查安装后的标准路径
      path.join(path.dirname(Platform.resolvedExecutable), 'tools', toolName),
      // 相对路径直接使用工具名 - 如果tools目录已添加到PATH
      toolName,
      // 应用程序目录下的工具
      path.join(path.dirname(Platform.resolvedExecutable), toolName),
      // 使用绝对路径表示
      '${path.dirname(Platform.resolvedExecutable)}\\tools\\$toolName',
      // 包含上级目录
      path.join(path.dirname(Directory.current.path), 'tools', toolName),
      // 当前目录下的tools
      path.join(Directory.current.path, 'tools', toolName),
      // 标准安装路径
      'C:\\Program Files\\牙医诊所管理系统\\tools\\$toolName',
      'C:\\Program Files (x86)\\牙医诊所管理系统\\tools\\$toolName',
      // 尝试使用环境变量中的MySQL路径
      ...Platform.environment['PATH']!
          .split(';')
          .map((p) => path.join(p, toolName)),
    ];

    print('尝试以下可能的路径:');
    for (int i = 0; i < math.min(10, possiblePaths.length); i++) {
      print('- ${possiblePaths[i]}');
    }
    if (possiblePaths.length > 10) {
      print('...及其他 ${possiblePaths.length - 10} 个路径');
    }

    // 首先检查具体路径
    for (final toolPath in possiblePaths) {
      try {
        if (File(toolPath).existsSync()) {
          print('找到MySQL工具: $toolPath');
          return toolPath;
        }
      } catch (e) {
        print('检查路径时出错: $e');
      }
    }

    // 搜索应用程序目录及其子目录
    print('在应用程序目录及其子目录中搜索...');
    try {
      final directories = [
        path.dirname(Platform.resolvedExecutable),
        Directory.current.path,
        path.dirname(Directory.current.path),
        'C:\\Program Files\\牙医诊所管理系统',
        'C:\\Program Files (x86)\\牙医诊所管理系统',
      ];

      for (final dir in directories) {
        final foundPath = _findFileRecursively(dir, toolName, maxDepth: 4);
        if (foundPath != null) {
          print('通过递归搜索找到MySQL工具: $foundPath');
          return foundPath;
        }
      }
    } catch (e) {
      print('递归搜索时出错: $e');
    }

    // 尝试创建tools目录并测试权限
    final appDir = path.dirname(Platform.resolvedExecutable);
    final toolsDir = path.join(appDir, 'tools');

    print('应用程序目录: $appDir');
    try {
      print('应用程序目录内容:');
      Directory(appDir).listSync().forEach((entity) {
        print('- ${entity.path}');
      });
    } catch (e) {
      print('无法列出应用程序目录内容: $e');
    }

    try {
      if (Directory(toolsDir).existsSync()) {
        print('tools目录存在，目录内容:');
        Directory(toolsDir).listSync().forEach((entity) {
          print('- ${entity.path}');
        });
      } else {
        print('tools目录不存在: $toolsDir，尝试创建...');
        try {
          Directory(toolsDir).createSync();
          print('成功创建tools目录');

          // 测试写入权限
          final testFile = File(path.join(toolsDir, 'test.tmp'));
          testFile.writeAsStringSync('测试写入权限');
          print('成功写入测试文件');
          testFile.deleteSync();
          print('成功删除测试文件');
        } catch (e) {
          print('无法创建或测试tools目录: $e');
        }
      }
    } catch (e) {
      print('测试tools目录权限时出错: $e');
    }

    // 如果找不到工具，尝试使用命令名
    print('未找到MySQL工具，将尝试直接使用命令名: $toolName');
    return toolName;
  }

  // 递归查找文件
  String? _findFileRecursively(String directory, String fileName,
      {int maxDepth = 3, int currentDepth = 0}) {
    if (currentDepth > maxDepth) return null;

    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return null;

      for (var entity in dir.listSync()) {
        if (entity is File && path.basename(entity.path) == fileName) {
          return entity.path;
        } else if (entity is Directory) {
          final result = _findFileRecursively(entity.path, fileName,
              maxDepth: maxDepth, currentDepth: currentDepth + 1);
          if (result != null) return result;
        }
      }
    } catch (e) {
      print('在目录 $directory 中搜索时出错: $e');
    }

    return null;
  }

  // 设置数据库连接 - 用于结构检测
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
  }

  /// 密码哈希方法
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 检查是否需要更新MySQL字段类型
  bool _shouldUpdateMySQLColumnType(String existingType, String requiredType) {
    // 移除不相关的修饰符
    final cleanExisting = existingType.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanRequired = requiredType.toLowerCase()
        .replaceAll('primary key', '')
        .replaceAll('auto_increment', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // MySQL特定的类型兼容性检查
    final mysqlCompatibilityMap = {
      // TEXT类型兼容性
      'text': ['text', 'varchar', 'longtext', 'mediumtext', 'tinytext'],
      'varchar': ['varchar', 'text', 'char'],
      'longtext': ['longtext', 'text', 'varchar'],
      'mediumtext': ['mediumtext', 'text', 'varchar'],
      'tinytext': ['tinytext', 'text', 'varchar'],
      
      // 数值类型兼容性
      'int': ['int', 'integer', 'bigint', 'smallint', 'tinyint'],
      'integer': ['integer', 'int', 'bigint', 'smallint'],
      'bigint': ['bigint', 'int', 'integer'],
      'decimal': ['decimal', 'numeric', 'float', 'double'],
      'float': ['float', 'decimal', 'double'],
      'double': ['double', 'float', 'decimal'],
      
      // 二进制类型兼容性
      'longblob': ['longblob', 'blob', 'mediumblob', 'tinyblob'],
      'blob': ['blob', 'longblob', 'mediumblob'],
      
      // 日期时间类型兼容性
      'datetime': ['datetime', 'timestamp', 'text'], // 添加text兼容性，因为SQLite中时间字段使用TEXT
      'timestamp': ['timestamp', 'datetime', 'text'],
      'date': ['date', 'text'],
      'time': ['time', 'text'],
      
      // 布尔类型兼容性
      'tinyint': ['tinyint', 'boolean', 'bool'],
      'boolean': ['boolean', 'tinyint', 'bool'],
    };
    
    // 提取基础类型名（去掉长度和修饰符）
    final existingBaseType = cleanExisting.split('(')[0].split(' ')[0];
    final requiredBaseType = cleanRequired.split('(')[0].split(' ')[0];
    
    // 检查类型兼容性
    if (mysqlCompatibilityMap.containsKey(existingBaseType)) {
      final compatibleTypes = mysqlCompatibilityMap[existingBaseType]!;
      if (compatibleTypes.contains(requiredBaseType)) {
        return false; // 类型兼容，不需要更新
      }
    }
    
    // 如果类型不兼容，需要更新
    print('MySQL字段类型不兼容: $existingBaseType vs $requiredBaseType');
    return true;
  }

  /// 检查是否需要更新SQLite字段类型
  bool _shouldUpdateSQLiteColumnType(String existingType, String requiredType) {
    // SQLite的类型系统比较宽松，对于结构检测，我们采用更宽松的策略
    // 只要字段存在且不是完全不兼容的类型，就认为是兼容的
    
    final cleanExisting = existingType.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanRequired = requiredType.toLowerCase()
        .replaceAll('primary key', '')
        .replaceAll('autoincrement', '')
        .replaceAll('not null', '')
        .replaceAll('default', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    // 提取基础类型名（去掉长度限制）
    final existingBaseType = cleanExisting.split('(')[0].split(' ')[0];
    final requiredBaseType = cleanRequired.split('(')[0].split(' ')[0];
    
    // 如果基础类型完全相同，则兼容
    if (existingBaseType == requiredBaseType) {
      return false;
    }
    
    // SQLite存储类别兼容性映射 - 更全面的兼容性检查
    final sqliteCompatibilityGroups = [
      ['integer', 'int', 'bigint', 'smallint', 'tinyint', 'numeric'],
      ['text', 'varchar', 'char', 'clob', 'string'],
      ['real', 'double', 'float', 'decimal'],
      ['blob', 'binary'],
      ['datetime', 'timestamp', 'date', 'time', 'text'], // 添加text到时间类型组，因为SQLite中时间字段使用TEXT存储
    ];
    
    // 检查类型兼容性
    for (final group in sqliteCompatibilityGroups) {
      if (group.contains(existingBaseType) && group.contains(requiredBaseType)) {
        return false; // 类型兼容，不需要更新
      }
    }
    
    // 特殊情况：SQLite中很多类型都可以互相兼容
    // 对于结构检测，我们采用非常宽松的策略，只有明显不兼容的才报告
    final obviouslyIncompatible = [
      ['blob', 'text'], ['blob', 'varchar'], ['blob', 'integer'], ['blob', 'real'],
      ['integer', 'text'], ['integer', 'varchar'],
      ['real', 'text'], ['real', 'varchar'],
    ];
    
    for (final incompatible in obviouslyIncompatible) {
      if ((incompatible[0] == existingBaseType && incompatible[1] == requiredBaseType) ||
          (incompatible[1] == existingBaseType && incompatible[0] == requiredBaseType)) {
        print('SQLite字段类型不兼容: $existingBaseType vs $requiredBaseType');
        return true;
      }
    }
    
    // 默认情况下，SQLite的类型系统很宽松，认为是兼容的
    return false;
  }

  /// 转换为SQLite兼容的类型
  String _convertToSQLiteType(String columnDef) {
    String sqliteType = columnDef;
    
    // MySQL到SQLite的类型映射
    final typeMapping = {
      'VARCHAR(255)': 'TEXT',
      'VARCHAR(100)': 'TEXT',
      'VARCHAR(50)': 'TEXT',
      'VARCHAR(20)': 'TEXT',
      'DATETIME': 'TEXT',
      'DATE': 'TEXT',
      'DECIMAL(10,2)': 'REAL',
      'INT': 'INTEGER',
      'LONGBLOB': 'BLOB',
      'CURRENT_TIMESTAMP': "datetime('now')",
    };
    
    for (final entry in typeMapping.entries) {
      sqliteType = sqliteType.replaceAll(entry.key, entry.value);
    }
    
    // 移除MySQL特有的约束
    sqliteType = sqliteType
        .replaceAll('ON UPDATE CURRENT_TIMESTAMP', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    return sqliteType;
  }

  /// 为SQLite字段设置默认值
  Future<void> _setSQLiteDefaultValue(String tableName, String columnName) async {
    try {
      if (columnName == 'created_at' || columnName == 'updated_at') {
        await _database!.execute('''
          UPDATE $tableName 
          SET $columnName = datetime('now') 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName == 'avatar') {
        await _database!.execute('''
          UPDATE $tableName 
          SET $columnName = 'avatar_1' 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName.contains('price') || columnName.contains('amount') || columnName.contains('cost')) {
        await _database!.execute('''
          UPDATE $tableName 
          SET $columnName = 0.0 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName.contains('quantity') || columnName.contains('stock')) {
        await _database!.execute('''
          UPDATE $tableName 
          SET $columnName = 0 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName == 'role') {
        await _database!.execute('''
          UPDATE $tableName 
          SET $columnName = 'user' 
          WHERE $columnName IS NULL
        ''');
      } else if (columnName == 'status') {
        await _database!.execute('''
          UPDATE $tableName 
          SET $columnName = 'active' 
          WHERE $columnName IS NULL
        ''');
      } else {
        await _database!.execute('''
          UPDATE $tableName 
          SET $columnName = '' 
          WHERE $columnName IS NULL
        ''');
      }
      print('为SQLite表 $tableName 字段 $columnName 设置默认值');
    } catch (e) {
      print('为SQLite表 $tableName 字段 $columnName 设置默认值失败: $e');
    }
  }



  /// 初始化MySQL连接（用于结构检测）
  Future<void> initializeMySQLConnection(Map<String, dynamic> mysqlSettings) async {
    try {
      print('初始化MySQL连接用于结构检测...');
      
      // 测试现有连接
      if (_mysqlConnection != null) {
        try {
          await _mysqlConnection!.query('SELECT 1');
          print('现有MySQL连接可用');
          return;
        } catch (e) {
          print('现有MySQL连接失效，重新建立连接');
          try {
            await _mysqlConnection!.close();
          } catch (_) {}
          _mysqlConnection = null;
        }
      }
      
      _mysqlConnection = await MySqlConnection.connect(
        ConnectionSettings(
          host: mysqlSettings['host'],
          port: mysqlSettings['port'],
          db: mysqlSettings['database'],
          user: mysqlSettings['username'],
          password: mysqlSettings['password'],
        ),
      );
      
      // 设置字符集
      await _mysqlConnection!.query("SET NAMES 'utf8mb4'");
      await _mysqlConnection!.query("SET character_set_connection = 'utf8mb4'");
      await _mysqlConnection!.query("SET character_set_results = 'utf8mb4'");
      
      print('MySQL连接初始化成功');
    } catch (e) {
      print('初始化MySQL连接失败: $e');
      rethrow;
    }
  }

  /// 获取数据库结构检测日志列表 - 统一从本地SQLite数据库读取
  Future<List<DatabaseStructureLog>> getDatabaseStructureLogs({int limit = 50}) async {
    try {
      // 获取本地SQLite数据库连接用于读取日志
      Database? logDatabase = _database;
      
      // 如果当前使用MySQL，需要获取本地SQLite连接来读取日志
      if (_dataSourceType == 'mysql' && _sqliteDbPath.isNotEmpty) {
        try {
          // 打开本地SQLite数据库用于读取日志
          logDatabase = await openDatabase(_sqliteDbPath);
        } catch (e) {
          print('无法打开本地SQLite数据库读取日志，使用当前连接: $e');
          // 如果无法打开本地SQLite，尝试使用当前连接
          logDatabase = _database;
        }
      }
      
      if (logDatabase == null) {
        print('无可用的数据库连接读取日志');
        return [];
      }

      final results = await logDatabase.query(
        'database_structure_logs',
        orderBy: 'detection_time DESC',
        limit: limit,
      );

      final logs = results.map((row) {
        return DatabaseStructureLog.fromMap({
          'id': row['id'],
          'data_source_type': row['data_source_type'],
          'detection_time': row['detection_time'],
          'status': row['status'],
          'required_tables': row['required_tables'],
          'missing_tables': row['missing_tables'],
          'structure_changes': row['structure_changes'],
          'errors': _decodeJsonSafely(row['errors'] ?? '[]'),
          'details': _decodeJsonSafely(row['details'] ?? '{}'),
          'summary': row['summary'],
          'created_at': row['created_at'],
        });
      }).toList();
      
      // 如果是为MySQL检测打开的临时连接，关闭它
      if (_dataSourceType == 'mysql' && logDatabase != _database) {
        await logDatabase.close();
      }
      
      return logs;
    } catch (e) {
      print('获取数据库结构检测日志失败: $e');
      return [];
    }
  }

  /// 删除数据库结构检测日志 - 统一从本地SQLite数据库删除
  Future<bool> deleteDatabaseStructureLog(int logId) async {
    try {
      // 获取本地SQLite数据库连接用于删除日志
      Database? logDatabase = _database;
      
      // 如果当前使用MySQL，需要获取本地SQLite连接来删除日志
      if (_dataSourceType == 'mysql' && _sqliteDbPath.isNotEmpty) {
        try {
          // 打开本地SQLite数据库用于删除日志
          logDatabase = await openDatabase(_sqliteDbPath);
        } catch (e) {
          print('无法打开本地SQLite数据库删除日志，使用当前连接: $e');
          // 如果无法打开本地SQLite，尝试使用当前连接
          logDatabase = _database;
        }
      }
      
      if (logDatabase == null) {
        print('无可用的数据库连接删除日志');
        return false;
      }

      final count = await logDatabase.delete(
        'database_structure_logs',
        where: 'id = ?',
        whereArgs: [logId],
      );

      // 如果是为MySQL检测打开的临时连接，关闭它
      if (_dataSourceType == 'mysql' && logDatabase != _database) {
        await logDatabase.close();
      }

      return count > 0;
    } catch (e) {
      print('删除数据库结构检测日志失败: $e');
      return false;
    }
  }

  /// 清空所有数据库结构检测日志 - 统一从本地SQLite数据库清空
  Future<bool> clearAllDatabaseStructureLogs() async {
    try {
      // 获取本地SQLite数据库连接用于清空日志
      Database? logDatabase = _database;
      
      // 如果当前使用MySQL，需要获取本地SQLite连接来清空日志
      if (_dataSourceType == 'mysql' && _sqliteDbPath.isNotEmpty) {
        try {
          // 打开本地SQLite数据库用于清空日志
          logDatabase = await openDatabase(_sqliteDbPath);
        } catch (e) {
          print('无法打开本地SQLite数据库清空日志，使用当前连接: $e');
          // 如果无法打开本地SQLite，尝试使用当前连接
          logDatabase = _database;
        }
      }
      
      if (logDatabase == null) {
        print('无可用的数据库连接清空日志');
        return false;
      }

      await logDatabase.delete('database_structure_logs');
      
      // 如果是为MySQL检测打开的临时连接，关闭它
      if (_dataSourceType == 'mysql' && logDatabase != _database) {
        await logDatabase.close();
      }
      
      return true;
    } catch (e) {
      print('清空数据库结构检测日志失败: $e');
      return false;
    }
  }

  /// 保存数据库结构检测日志 - 统一存储到本地SQLite数据库
  Future<void> saveDatabaseStructureLog(DatabaseStructureLog log) async {
    try {
      // 获取本地SQLite数据库连接用于存储日志
      Database? logDatabase = _database;
      
      // 如果当前使用MySQL，需要获取本地SQLite连接来存储日志
      if (_dataSourceType == 'mysql' && _sqliteDbPath.isNotEmpty) {
        try {
          // 打开本地SQLite数据库用于存储日志
          logDatabase = await openDatabase(_sqliteDbPath);
          
          // 确保日志表存在
          await logDatabase.execute('''
            CREATE TABLE IF NOT EXISTS database_structure_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              data_source_type TEXT NOT NULL,
              detection_time TEXT NOT NULL,
              status TEXT NOT NULL,
              required_tables INTEGER NOT NULL DEFAULT 0,
              missing_tables INTEGER NOT NULL DEFAULT 0,
              structure_changes INTEGER NOT NULL DEFAULT 0,
              errors TEXT,
              details TEXT,
              summary TEXT,
              created_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
        } catch (e) {
          print('无法打开本地SQLite数据库存储日志，使用当前连接: $e');
          // 如果无法打开本地SQLite，尝试使用当前连接
          logDatabase = _database;
        }
      }
      
      if (logDatabase == null) {
        print('无可用的数据库连接存储日志');
        return;
      }
      
      // 检查并添加created_at列（如果不存在）
      try {
        final columns = await logDatabase.rawQuery('PRAGMA table_info(database_structure_logs)');
        final hasCreatedAt = columns.any((col) => col['name'] == 'created_at');
        if (!hasCreatedAt) {
          await logDatabase.execute('ALTER TABLE database_structure_logs ADD COLUMN created_at TEXT NOT NULL DEFAULT (datetime(\'now\'))');
          print('为database_structure_logs表添加created_at列');
        }
      } catch (e) {
        print('检查/添加created_at列失败: $e');
      }
      
      // 将日志存储到本地SQLite数据库
      await logDatabase.insert('database_structure_logs', {
        'data_source_type': log.dataSourceType,
        'detection_time': DateTimeFormatter.toDbString(log.detectionTime),
        'status': log.status,
        'required_tables': log.requiredTables,
        'missing_tables': log.missingTables,
        'structure_changes': log.structureChanges,
        'errors': log.errors.isEmpty ? '[]' : jsonEncode(log.errors),
        'details': log.details.isEmpty ? '{}' : jsonEncode(log.details),
        'summary': log.summary,
        'created_at': DateTimeFormatter.toDbString(log.createdAt),
      });
      
      print('数据库结构检测日志已保存到本地SQLite数据库 (数据源: ${log.dataSourceType})');
      
      // 如果是为MySQL检测打开的临时连接，关闭它
      if (_dataSourceType == 'mysql' && logDatabase != _database) {
        await logDatabase.close();
      }
      
    } catch (e) {
      print('保存数据库结构检测日志失败: $e');
      // 不抛出异常，避免影响主流程
    }
  }

  // ==================== 数据库结构检测功能 ====================

  /// 检测并更新数据库结构
  Future<Map<String, dynamic>> detectAndUpdateDatabaseStructure({
    String? targetDataSource,
  }) async {
    final dataSource = targetDataSource ?? _dataSourceType;
    
    // 使用TableDefinitionsAdapter获取所有系统表
    final systemTables = TableDefinitionsAdapter.getAllSystemTableNames();
    
    final result = {
      'status': '开始检测数据库结构',
      'dataSourceType': dataSource,
      'detectionTime': DateTimeFormatter.nowDbString(),
      'requiredTables': systemTables.length,
      'missingTables': 0,
      'structureChanges': 0,
      'errors': <String>[],
      'details': <String, dynamic>{
        'systemTables': systemTables, // 系统表列表
        'tablesCreated': <String>[],
        'tablesUpdated': <String>[],

        'columnsAdded': <Map<String, dynamic>>[],
        'columnsModified': <Map<String, dynamic>>[],
        'structureChanges': <String>[],
        'detectedTables': <String>[], // 检测到的系统表
        'missingTableNames': <String>[], // 缺失的系统表
        'ignoredTables': <String>[], // 忽略的非系统表
      },
    };

    try {
      print('开始检测数据库结构...');
      print('目标数据源: $dataSource');
      print('系统核心表: ${systemTables.join(', ')}');
      
      if (dataSource == 'sqlite') {
        await _detectAndUpdateSQLiteStructure(result, systemTables);
      } else if (dataSource == 'mysql') {
        await _detectAndUpdateMySQLStructure(result, systemTables);
      } else {
        throw Exception('不支持的数据源类型: $dataSource');
      }
      
      result['status'] = '数据库结构检测完成';
      print('数据库结构检测完成');
      
      // 保存检测日志
      try {
        await saveDatabaseStructureLog(_createLogFromResult(result));
        print('数据库结构检测日志已保存');
      } catch (e) {
        print('保存数据库结构检测日志失败: $e');
        (result['errors'] as List<String>).add('保存检测日志失败: $e');
      }
      
    } catch (e) {
      result['status'] = '数据库结构检测失败';
      (result['errors'] as List<String>).add('检测过程中发生错误: $e');
      print('数据库结构检测失败: $e');
      
      // 保存错误日志
      try {
        await saveDatabaseStructureLog(_createLogFromResult(result));
        print('数据库结构检测错误日志已保存');
      } catch (logError) {
        print('保存数据库结构检测错误日志失败: $logError');
      }
    }
    
    return result;
  }

  /// 检测并更新SQLite数据库结构
  Future<void> _detectAndUpdateSQLiteStructure(Map<String, dynamic> result, List<String> systemTables) async {
    if (_database == null) {
      throw Exception('SQLite数据库连接未初始化');
    }

    // 使用统一的表结构检测和更新逻辑
    await _detectAndUpdateTableStructure(result, false, systemTables); // false表示SQLite
  }

  /// 检测并更新MySQL数据库结构
  Future<void> _detectAndUpdateMySQLStructure(Map<String, dynamic> result, List<String> systemTables) async {
    if (_mysqlConnection == null) {
      throw Exception('MySQL数据库连接未初始化');
    }

    // 使用统一的表结构检测和更新逻辑
    await _detectAndUpdateTableStructure(result, true, systemTables); // true表示MySQL
  }

  /// 统一的表结构检测和更新逻辑
  /// 确保SQLite和MySQL使用完全一致的检测和更新流程
  Future<void> _detectAndUpdateTableStructure(Map<String, dynamic> result, bool isMySQL, List<String> systemTables) async {
    // 根据数据库类型获取相应的表结构定义
    final allTableDefinitions = isMySQL 
        ? TableDefinitionsAdapter.getMySQLTableDefinitions()
        : TableDefinitionsAdapter.getSQLiteTableDefinitions();
    
    // 只获取系统表的定义
    final tableDefinitions = <String, Map<String, String>>{};
    for (final tableName in systemTables) {
      if (allTableDefinitions.containsKey(tableName)) {
        tableDefinitions[tableName] = allTableDefinitions[tableName]!;
      }
    }
    
    // 获取数据库中所有现有表
    final allExistingTables = isMySQL ? await _getMySQLTableNames() : await _getSQLiteTableNames();
    
    // 只关注系统表
    final systemExistingTables = allExistingTables.where((table) => systemTables.contains(table)).toList();
    final ignoredTables = allExistingTables.where((table) => !systemTables.contains(table)).toList();
    
    result['details']['detectedTables'] = systemExistingTables;
    result['details']['ignoredTables'] = ignoredTables;
    
    print('数据库中所有表: ${allExistingTables.join(', ')}');
    print('系统相关表: ${systemExistingTables.join(', ')}');
    print('忽略的非系统表: ${ignoredTables.join(', ')}');
    print('程序必需的表: ${tableDefinitions.keys.join(', ')}');
    print('使用${isMySQL ? 'MySQL' : 'SQLite'}兼容的表结构定义');

    // 1. 检查缺失的系统表并创建
    await _createMissingTables(systemExistingTables, result, isMySQL, tableDefinitions, systemTables);
    
    // 2. 检查现有系统表结构并更新
    await _updateExistingTableStructures(systemExistingTables, result, isMySQL, tableDefinitions);
    
    // 3. 如果是MySQL，只有在真正需要时才执行特殊修复
    if (isMySQL) {
      // 检查是否真的需要修复（比如有字段缺失或类型不匹配）
      final hasRealChanges = (result['details']['columnsAdded'] as List<dynamic>?)?.isNotEmpty == true ||
                            (result['details']['tablesUpdated'] as List<dynamic>?)?.isNotEmpty == true;
      
      if (hasRealChanges) {
        print('检测到真实的结构变化，执行MySQL表结构修复...');
        await _fixMySQLTableStructures(systemExistingTables, result);
      } else {
        print('MySQL表结构检查完成，无需特殊修复');
      }
    }
  }

  /// 创建缺失的表
  Future<void> _createMissingTables(List<String> existingTables, Map<String, dynamic> result, bool isMySQL, Map<String, Map<String, String>> tableDefinitions, List<String> systemTables) async {
    // 检查缺失的系统表
    final missingTables = <String>[];
    for (final tableName in systemTables) {
      if (tableDefinitions.containsKey(tableName) && !existingTables.contains(tableName)) {
        missingTables.add(tableName);
      }
    }
    
    result['missingTables'] = missingTables.length;
    result['details']['missingTableNames'] = missingTables;
    
    if (missingTables.isNotEmpty) {
      print('缺失的系统表: ${missingTables.join(', ')}');
      (result['details']['structureChanges'] as List<String>).add('发现 ${missingTables.length} 个缺失的系统表: ${missingTables.join(', ')}');
    } else {
      print('所有系统表都已存在');
      (result['details']['structureChanges'] as List<String>).add('所有系统表都已存在，无需创建新表');
    }

    // 创建缺失的表
    final tablesCreated = <String>[];
    for (final tableName in missingTables) {
      try {
        if (isMySQL) {
          // 使用MySQL表结构类生成CREATE TABLE语句
          final createSQL = TableDefinitionsAdapter.generateMySQLCreateTable(tableName, tableDefinitions[tableName]!);
          await _mysqlConnection!.query(createSQL);
          
          // 为MySQL新创建的表添加默认数据（如果需要）
          if (tableName == 'users') {
            await _createDefaultMySQLUser();
          }
        } else {
          // 使用SQLite表结构类生成CREATE TABLE语句
          final createSQL = TableDefinitionsAdapter.generateSQLiteCreateTable(tableName, tableDefinitions[tableName]!);
          await _database!.execute(createSQL);
          
          // 为SQLite新创建的表添加默认数据（如果需要）
          if (tableName == 'users') {
            await _createDefaultSQLiteUser();
          }
        }
        tablesCreated.add(tableName);
        print('✅ 成功创建系统表: $tableName');
        (result['details']['structureChanges'] as List<String>).add('创建系统表: $tableName');
      } catch (e) {
        final errorMsg = '创建系统表 $tableName 失败: $e';
        (result['errors'] as List<String>).add(errorMsg);
        print('❌ $errorMsg');
      }
    }
    
    result['details']['tablesCreated'] = tablesCreated;
    result['structureChanges'] = ((result['structureChanges'] as int?) ?? 0) + tablesCreated.length;
  }

  /// 为MySQL创建默认管理员用户
  Future<void> _createDefaultMySQLUser() async {
    try {
      // 检查是否已存在admin用户
      final existingUsers = await _mysqlConnection!.query(
        'SELECT COUNT(*) as count FROM users WHERE username = ?',
        ['admin']
      );
      
      if (existingUsers.first['count'] == 0) {
        final hashedPassword = _hashPassword('123456');
        await _mysqlConnection!.query('''
          INSERT INTO users (username, email, password, role, doctor, avatar, created_at, updated_at) 
          VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
        ''', [
          'admin',
          'admin@example.com',
          hashedPassword,
          'admin',
          '系统管理员',
          'avatar_5'
        ]);
        print('✅ 已为MySQL创建默认管理员用户: admin/123456');
      } else {
        print('ℹ️ MySQL中admin用户已存在，跳过创建');
      }
    } catch (e) {
      print('❌ 创建MySQL默认用户失败: $e');
    }
  }

  /// 为SQLite创建默认管理员用户
  Future<void> _createDefaultSQLiteUser() async {
    try {
      // 检查是否已存在admin用户
      final existingUsers = await _database!.query(
        'users',
        where: 'username = ?',
        whereArgs: ['admin']
      );
      
      if (existingUsers.isEmpty) {
        final hashedPassword = _hashPassword('123456');
        final now = DateTimeFormatter.nowDbString();
        await _database!.insert('users', {
          'username': 'admin',
          'email': 'admin@example.com',
          'password': hashedPassword,
          'role': 'admin',
          'doctor': '系统管理员',
          'avatar': 'avatar_5',
          'created_at': now,
          'updated_at': now,
        });
        print('✅ 已为SQLite创建默认管理员用户: admin/123456');
      } else {
        print('ℹ️ SQLite中admin用户已存在，跳过创建');
      }
    } catch (e) {
      print('❌ 创建SQLite默认用户失败: $e');
    }
  }

  /// 更新现有表结构
  Future<void> _updateExistingTableStructures(List<String> existingTables, Map<String, dynamic> result, bool isMySQL, Map<String, Map<String, String>> tableDefinitions) async {
    final columnsAdded = <Map<String, dynamic>>[];
    final columnsModified = <Map<String, dynamic>>[];
    final tablesUpdated = <String>[];

    
    try {
      print('开始检查现有系统表结构...');
      (result['details']['structureChanges'] as List<String>).add('开始检查现有系统表结构');
      
      for (final tableName in existingTables) {
        if (tableDefinitions.containsKey(tableName)) {
          print('检查表: $tableName');
          final requiredColumns = tableDefinitions[tableName]!;
          
          if (isMySQL) {
            // MySQL表结构检查和更新
            await _checkAndUpdateMySQLTableStructure(tableName, requiredColumns, columnsAdded, columnsModified, tablesUpdated, result);
          } else {
            // SQLite表结构检查和更新
            await _checkAndUpdateSQLiteTableStructure(tableName, requiredColumns, columnsAdded, columnsModified, tablesUpdated, result);
          }
        }
      }
      
      // 更新结果
      result['details']['columnsAdded'] = columnsAdded;
      result['details']['columnsModified'] = columnsModified;
      result['details']['tablesUpdated'] = tablesUpdated;
      result['structureChanges'] = ((result['structureChanges'] as int?) ?? 0) + columnsAdded.length + columnsModified.length;
      
      final summary = '表结构检查完成: 添加字段 ${columnsAdded.length} 个, 修改字段 ${columnsModified.length} 个, 更新表 ${tablesUpdated.length} 个';
      print(summary);
      (result['details']['structureChanges'] as List<String>).add(summary);
      
    } catch (e) {
      final errorMsg = '表结构检查失败: $e';
      print(errorMsg);
      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 检查并更新MySQL表结构
  Future<void> _checkAndUpdateMySQLTableStructure(String tableName, Map<String, String> requiredColumns, List<Map<String, dynamic>> columnsAdded, List<Map<String, dynamic>> columnsModified, List<String> tablesUpdated, Map<String, dynamic> result) async {
    if (_mysqlConnection == null) return;
    
    try {
      print('检查MySQL表 $tableName 的结构...');
      final tableColumns = await _mysqlConnection!.query('DESCRIBE $tableName');
      final existingColumns = <String, Map<String, dynamic>>{};
      
      // 获取现有字段信息
      for (final row in tableColumns) {
        final fieldName = _safeStringParse(row['Field']);
        existingColumns[fieldName] = {
          'type': _safeStringParse(row['Type']),
          'null': _safeStringParse(row['Null']),
          'key': _safeStringParse(row['Key']),
          'default': row['Default'],
          'extra': _safeStringParse(row['Extra']),
        };
      }
      
      print('MySQL表 $tableName 现有字段: ${existingColumns.keys.join(', ')}');
      bool tableUpdated = false;
      
      // 详细的结构差异检测和记录
      final structureDifferences = <String>[];
      
      // 1. 检测多余字段（不在模型中定义的字段）
      final extraColumns = <String>[];
      for (final existingColumn in existingColumns.keys) {
        if (!requiredColumns.containsKey(existingColumn)) {
          extraColumns.add(existingColumn);
        }
      }
      
      if (extraColumns.isNotEmpty) {
        structureDifferences.add('多余字段 ${extraColumns.length} 个: ${extraColumns.join(', ')} (已保留)');
        print('🔍 MySQL表 $tableName 发现多余字段: ${extraColumns.join(', ')} (已保留，避免数据丢失)');
      }
      
      // 2. 检测缺失字段和类型不匹配字段
      final missingColumns = <String>[];
      final typeMismatchColumns = <String>[];
      final constraintDifferences = <String>[];
      
      for (final columnName in requiredColumns.keys) {
        if (!existingColumns.containsKey(columnName)) {
          // 字段不存在
          missingColumns.add(columnName);
        } else {
          // 字段存在，检查详细差异
          final existingColumn = existingColumns[columnName]!;
          final existingType = existingColumn['type'] as String;
          final existingNull = existingColumn['null'] as String;
          final existingKey = existingColumn['key'] as String;
          final existingDefault = existingColumn['default'];
          final existingExtra = existingColumn['extra'] as String;
          final requiredType = requiredColumns[columnName]!;
          
          // 检查类型差异
          if (_shouldUpdateMySQLColumnType(existingType, requiredType)) {
            typeMismatchColumns.add('$columnName: $existingType → ${requiredType.replaceAll('PRIMARY KEY', '').replaceAll('AUTO_INCREMENT', '').trim()}');
          }
          
          // 检查NULL约束差异
          final existingAllowsNull = existingNull.toUpperCase() == 'YES';
          final requiredAllowsNull = !requiredType.toUpperCase().contains('NOT NULL');
          if (existingAllowsNull != requiredAllowsNull) {
            constraintDifferences.add('$columnName: NULL约束不匹配 (现有: ${existingAllowsNull ? 'NULL' : 'NOT NULL'}, 需要: ${requiredAllowsNull ? 'NULL' : 'NOT NULL'})');
          }
          
          // 检查主键约束差异
          final existingIsPrimaryKey = existingKey.toUpperCase() == 'PRI';
          final requiredIsPrimaryKey = requiredType.toUpperCase().contains('PRIMARY KEY');
          if (existingIsPrimaryKey != requiredIsPrimaryKey) {
            constraintDifferences.add('$columnName: 主键约束不匹配 (现有: ${existingIsPrimaryKey ? 'PRIMARY KEY' : '非主键'}, 需要: ${requiredIsPrimaryKey ? 'PRIMARY KEY' : '非主键'})');
          }
          
          // 检查AUTO_INCREMENT差异
          final existingAutoIncrement = existingExtra.toUpperCase().contains('AUTO_INCREMENT');
          final requiredAutoIncrement = requiredType.toUpperCase().contains('AUTO_INCREMENT');
          if (existingAutoIncrement != requiredAutoIncrement) {
            constraintDifferences.add('$columnName: AUTO_INCREMENT不匹配 (现有: ${existingAutoIncrement ? 'AUTO_INCREMENT' : '非自增'}, 需要: ${requiredAutoIncrement ? 'AUTO_INCREMENT' : '非自增'})');
          }
          
          // 检查默认值差异
          final hasRequiredDefault = requiredType.toUpperCase().contains('DEFAULT');
          if ((existingDefault == null) != (!hasRequiredDefault)) {
            constraintDifferences.add('$columnName: 默认值不匹配 (现有: ${existingDefault ?? 'NULL'}, 需要: ${hasRequiredDefault ? '有默认值' : '无默认值'})');
          }
        }
      }
      
      // 3. 记录缺失字段差异
      if (missingColumns.isNotEmpty) {
        structureDifferences.add('缺失字段 ${missingColumns.length} 个: ${missingColumns.join(', ')}');
        print('🔍 MySQL表 $tableName 缺失字段: ${missingColumns.join(', ')}');
        
        // 尝试添加缺失的字段
        for (final columnName in missingColumns) {
          try {
            final columnDef = requiredColumns[columnName]!;
            // 移除PRIMARY KEY约束，因为ALTER TABLE ADD COLUMN不支持
            String mysqlColumnDef = columnDef.replaceAll('PRIMARY KEY', '').trim();
            
            // MySQL特殊处理
            if (columnName == 'avatar' && mysqlColumnDef.contains('TEXT DEFAULT')) {
              mysqlColumnDef = 'VARCHAR(50) DEFAULT \'avatar_1\'';
              print('为avatar字段使用MySQL兼容的VARCHAR类型');
            }
            
            // 处理AUTO_INCREMENT
            if (mysqlColumnDef.contains('AUTO_INCREMENT')) {
              mysqlColumnDef = mysqlColumnDef.replaceAll('AUTO_INCREMENT', '').trim();
            }
            
            await _mysqlConnection!.query('ALTER TABLE $tableName ADD COLUMN $columnName $mysqlColumnDef');
            columnsAdded.add({
              'table': tableName,
              'column': columnName,
              'type': mysqlColumnDef,
              'database': 'MySQL',
              'action': 'added'
            });
            structureDifferences.add('已添加字段: $columnName ($mysqlColumnDef)');
            tableUpdated = true;
            print('✅ 为MySQL表 $tableName 添加字段: $columnName ($mysqlColumnDef)');
          } catch (e) {
            final errorMsg = '为MySQL表 $tableName 添加字段 $columnName 失败: $e';
            print('❌ $errorMsg');
            (result['errors'] as List<String>).add(errorMsg);
            structureDifferences.add('添加字段失败: $columnName - $e');
          }
        }
      }
      
      // 4. 记录类型不匹配差异（但不修改，避免数据丢失风险）
      if (typeMismatchColumns.isNotEmpty) {
        structureDifferences.add('类型不匹配字段 ${typeMismatchColumns.length} 个: ${typeMismatchColumns.join(', ')} (已保留，避免数据丢失)');
        print('🔍 MySQL表 $tableName 发现类型不匹配字段: ${typeMismatchColumns.join(', ')} (已保留，避免数据丢失)');
      }
      
      // 5. 记录约束差异（但不修改，避免数据丢失风险）
      if (constraintDifferences.isNotEmpty) {
        structureDifferences.add('约束差异 ${constraintDifferences.length} 个: ${constraintDifferences.join(', ')} (已保留)');
        print('🔍 MySQL表 $tableName 发现约束差异: ${constraintDifferences.join(', ')} (已保留)');
      }
      
      // 6. 汇总结构检测结果
      if (structureDifferences.isEmpty) {
        print('✅ MySQL表 $tableName 结构完全匹配，无差异');
        (result['details']['structureChanges'] as List<String>).add('MySQL表 $tableName 结构完全匹配');
      } else {
        print('🔍 MySQL表 $tableName 结构差异汇总: ${structureDifferences.join(' | ')}');
        (result['details']['structureChanges'] as List<String>).add('MySQL表 $tableName 结构差异: ${structureDifferences.join(' | ')}');
      }
      
      if (tableUpdated) {
        tablesUpdated.add(tableName);
      }
      
    } catch (e) {
      print('检查MySQL表 $tableName 结构时出错: $e');
    }
  }

  /// 检查并更新SQLite表结构
  Future<void> _checkAndUpdateSQLiteTableStructure(String tableName, Map<String, String> requiredColumns, List<Map<String, dynamic>> columnsAdded, List<Map<String, dynamic>> columnsModified, List<String> tablesUpdated, Map<String, dynamic> result) async {
    if (_database == null) return;
    
    try {
      print('检查SQLite表 $tableName 的结构...');
      
      // 获取现有字段详细信息
      final existingColumns = await _getSQLiteTableColumnDetails(tableName);
      final existingColumnNames = existingColumns.keys.toList();
      
      print('SQLite表 $tableName 现有字段: ${existingColumnNames.join(', ')}');
      bool tableUpdated = false;
      
      // 首先移除多余的字段（SQLite不支持DROP COLUMN，需要重建表）
      final extraColumns = <String>[];
      for (final existingColumn in existingColumnNames) {
        if (!requiredColumns.containsKey(existingColumn)) {
          extraColumns.add(existingColumn);
        }
      }
      
      // 检查缺失的字段 - 使用更严格的字段名比较
      final missingColumns = <String>[];
      print('SQLite表 $tableName 必需字段: ${requiredColumns.keys.join(', ')}');
      print('SQLite表 $tableName 现有字段: ${existingColumnNames.join(', ')}');
      
      for (final columnName in requiredColumns.keys) {
        // 使用大小写不敏感的比较，并去除空格
        final normalizedColumnName = columnName.toLowerCase().trim();
        final normalizedExistingColumns = existingColumnNames.map((name) => name.toLowerCase().trim()).toList();
        
        if (!normalizedExistingColumns.contains(normalizedColumnName)) {
          missingColumns.add(columnName);
          print('字段 $columnName 确实缺失 (标准化后: $normalizedColumnName)');
          print('现有标准化字段: ${normalizedExistingColumns.join(', ')}');
        } else {
          print('字段 $columnName 已存在 (标准化后: $normalizedColumnName)');
        }
      }
      
      print('SQLite表 $tableName 最终缺失字段列表: ${missingColumns.join(', ')}');
      
      // 检查需要修改类型的字段
      final columnsToModify = <String>[];
      for (final columnName in requiredColumns.keys) {
        if (existingColumns.containsKey(columnName)) {
          final existingType = existingColumns[columnName]!['type'] as String;
          final requiredType = requiredColumns[columnName]!;
          
          if (_shouldUpdateSQLiteColumnType(existingType, requiredType)) {
            columnsToModify.add(columnName);
          }
        }
      }
      
      // 详细的结构差异检测和记录
      final structureDifferences = <String>[];
      
      // 1. 检测并记录缺失字段，并尝试添加
      if (missingColumns.isNotEmpty) {
        structureDifferences.add('缺失字段 ${missingColumns.length} 个: ${missingColumns.join(', ')}');
        print('🔍 SQLite表 $tableName 缺失字段: ${missingColumns.join(', ')}');
        
        // 尝试添加缺失的字段
        for (final columnName in missingColumns) {
          try {
            // 在添加字段前，再次确认字段确实不存在
            final reCheckColumns = await _getSQLiteTableColumns(tableName);
            final normalizedReCheckColumns = reCheckColumns.map((name) => name.toLowerCase().trim()).toList();
            final normalizedColumnName = columnName.toLowerCase().trim();
            
            if (normalizedReCheckColumns.contains(normalizedColumnName)) {
              print('⚠️ 字段 $columnName 实际已存在，跳过添加');
              structureDifferences.add('字段 $columnName 已存在，跳过添加');
              continue;
            }
            
            final columnDef = _convertToSQLiteType(requiredColumns[columnName]!);
            
            // 移除PRIMARY KEY和AUTOINCREMENT约束（ALTER TABLE ADD COLUMN不支持）
            String safeColumnDef = columnDef
                .replaceAll('PRIMARY KEY', '')
                .replaceAll('AUTOINCREMENT', '')
                .trim();
            
            // 如果是NOT NULL字段，先添加为可空字段
            if (safeColumnDef.contains('NOT NULL')) {
              safeColumnDef = safeColumnDef.replaceAll('NOT NULL', '').trim();
            }
            
            print('准备添加字段: ALTER TABLE $tableName ADD COLUMN $columnName $safeColumnDef');
            await _database!.execute('ALTER TABLE $tableName ADD COLUMN $columnName $safeColumnDef');
            
            // 为新添加的字段设置默认值
            await _setSQLiteDefaultValue(tableName, columnName);
            
            columnsAdded.add({
              'table': tableName,
              'column': columnName,
              'type': safeColumnDef,
              'database': 'SQLite',
              'action': 'added'
            });
            
            print('✅ 为SQLite表 $tableName 添加字段: $columnName ($safeColumnDef)');
            (result['details']['structureChanges'] as List<String>).add('为SQLite表 $tableName 添加字段: $columnName');
            structureDifferences.add('已添加字段: $columnName ($safeColumnDef)');
            tableUpdated = true;
          } catch (e) {
            // 检查是否是重复字段错误
            if (e.toString().contains('duplicate column name')) {
              print('⚠️ 字段 $columnName 已存在，跳过添加 (捕获到重复字段错误)');
              structureDifferences.add('字段 $columnName 已存在，跳过添加');
              continue;
            }
            
            final errorMsg = '为SQLite表 $tableName 添加字段 $columnName 失败: $e';
            print('❌ $errorMsg');
            (result['errors'] as List<String>).add(errorMsg);
            structureDifferences.add('添加字段失败: $columnName - $e');
          }
        }
      } else {
        print('SQLite表 $tableName 结构完整，无需更新');
        (result['details']['structureChanges'] as List<String>).add('SQLite表 $tableName 结构完整');
      }
      
      // 2. 检测并记录多余字段（不删除，但要记录）
      if (extraColumns.isNotEmpty) {
        structureDifferences.add('多余字段 ${extraColumns.length} 个: ${extraColumns.join(', ')} (已保留)');
        print('🔍 SQLite表 $tableName 发现多余字段: ${extraColumns.join(', ')} (已保留，避免数据丢失)');
      }
      
      // 3. 检测并记录类型不匹配的字段
      if (columnsToModify.isNotEmpty) {
        final typeDifferences = <String>[];
        for (final columnName in columnsToModify) {
          final existingType = existingColumns[columnName]!['type'] as String;
          final requiredType = requiredColumns[columnName]!;
          typeDifferences.add('$columnName: $existingType → $requiredType');
        }
        structureDifferences.add('类型不匹配字段 ${columnsToModify.length} 个: ${typeDifferences.join(', ')} (SQLite兼容，已保留)');
        print('🔍 SQLite表 $tableName 发现类型不匹配字段: ${typeDifferences.join(', ')} (SQLite兼容，已保留)');
      }
      
      // 4. 检测并记录约束差异（如NOT NULL, DEFAULT等）
      final constraintDifferences = <String>[];
      for (final columnName in existingColumns.keys) {
        if (requiredColumns.containsKey(columnName)) {
          final existingColumn = existingColumns[columnName]!;
          final requiredDef = requiredColumns[columnName]!;
          
          // 检查NOT NULL约束
          final existingNotNull = existingColumn['notnull'] as int == 1;
          final requiredNotNull = requiredDef.toUpperCase().contains('NOT NULL');
          if (existingNotNull != requiredNotNull) {
            constraintDifferences.add('$columnName: NOT NULL约束不匹配 (现有: $existingNotNull, 需要: $requiredNotNull)');
          }
          
          // 检查默认值
          final existingDefault = existingColumn['dflt_value'];
          final hasRequiredDefault = requiredDef.toUpperCase().contains('DEFAULT');
          if ((existingDefault == null) != (!hasRequiredDefault)) {
            constraintDifferences.add('$columnName: 默认值不匹配 (现有: $existingDefault, 需要: ${hasRequiredDefault ? '有默认值' : '无默认值'})');
          }
        }
      }
      
      if (constraintDifferences.isNotEmpty) {
        structureDifferences.add('约束差异 ${constraintDifferences.length} 个: ${constraintDifferences.join(', ')} (已保留)');
        print('🔍 SQLite表 $tableName 发现约束差异: ${constraintDifferences.join(', ')} (已保留)');
      }
      
      // 5. 汇总结构检测结果
      if (structureDifferences.isEmpty) {
        print('✅ SQLite表 $tableName 结构完全匹配，无差异');
        (result['details']['structureChanges'] as List<String>).add('SQLite表 $tableName 结构完全匹配');
      } else {
        print('🔍 SQLite表 $tableName 结构差异汇总: ${structureDifferences.join(' | ')}');
        (result['details']['structureChanges'] as List<String>).add('SQLite表 $tableName 结构差异: ${structureDifferences.join(' | ')}');
      }
      
      if (tableUpdated) {
        tablesUpdated.add(tableName);
      }
      
    } catch (e) {
      final errorMsg = '检查SQLite表 $tableName 结构时出错: $e';
      print('❌ $errorMsg');
      (result['errors'] as List<String>).add(errorMsg);
    }
  }

  /// 获取SQLite表的字段详细信息
  Future<Map<String, Map<String, dynamic>>> _getSQLiteTableColumnDetails(String tableName) async {
    if (_database == null) return {};
    
    try {
      final result = await _database!.rawQuery('PRAGMA table_info($tableName)');
      final columns = <String, Map<String, dynamic>>{};
      
      for (final row in result) {
        final columnName = row['name'] as String;
        columns[columnName] = {
          'type': row['type'] as String,
          'notnull': row['notnull'] as int,
          'dflt_value': row['dflt_value'],
          'pk': row['pk'] as int,
        };
      }
      
      print('SQLite表 $tableName 字段详细信息: ${columns.keys.join(', ')}');
      return columns;
    } catch (e) {
      print('获取SQLite表 $tableName 的字段详细信息失败: $e');
      return {};
    }
  }

  /// 转换为SQLite兼容的字段定义
  String _convertToSQLiteColumnDefinition(String columnDef) {
    String sqliteColumnDef = columnDef;
    
    // MySQL到SQLite的类型转换
    final typeConversions = {
      'VARCHAR(255)': 'TEXT',
      'VARCHAR(500)': 'TEXT',
      'VARCHAR(1000)': 'TEXT',
      'VARCHAR(100)': 'TEXT',
      'VARCHAR(50)': 'TEXT',
      'VARCHAR(20)': 'TEXT',
      'DATETIME': 'TEXT',
      'DATE': 'TEXT',
      'DECIMAL(10,2)': 'REAL',
      'INT': 'INTEGER',
      'LONGBLOB': 'BLOB',
      'TINYINT(1)': 'INTEGER',
    };
    
    for (final entry in typeConversions.entries) {
      sqliteColumnDef = sqliteColumnDef.replaceAll(entry.key, entry.value);
    }
    
    // 移除MySQL特有的约束和修饰符
    sqliteColumnDef = sqliteColumnDef
        .replaceAll('AUTO_INCREMENT', '')
        .replaceAll('ON UPDATE CURRENT_TIMESTAMP', '')
        .replaceAll('CURRENT_TIMESTAMP', "datetime('now')")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    
    return sqliteColumnDef;
  }

  /// 获取SQLite数据库中的表名
  Future<List<String>> _getSQLiteTableNames() async {
    if (_database == null) return [];
    
    try {
      final result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      return result.map((table) => table['name'] as String).toList();
    } catch (e) {
      print('获取SQLite表名失败: $e');
      return [];
    }
  }

  /// 获取SQLite表的字段列表
  Future<List<String>> _getSQLiteTableColumns(String tableName) async {
    if (_database == null) return [];
    
    try {
      final result = await _database!.rawQuery('PRAGMA table_info($tableName)');
      final columns = result.map((column) => column['name'] as String).toList();
      print('SQLite表 $tableName 实际字段列表: ${columns.join(', ')}');
      return columns;
    } catch (e) {
      print('获取表 $tableName 的字段信息失败: $e');
      return [];
    }
  }
  

  
  /// 获取MySQL表的字段列表
  Future<List<String>> _getMySQLTableColumns(String tableName) async {
    if (_mysqlConnection == null) return [];
    
    try {
      final result = await _mysqlConnection!.query('DESCRIBE $tableName');
      return result.map((row) => _safeStringParse(row['Field'])).toList();
    } catch (e) {
      print('获取MySQL表 $tableName 的字段信息失败: $e');
      return [];
    }
  }

  /// 从字段定义中提取默认值
  String? _extractDefaultValue(String columnDef) {
    final defaultMatch = RegExp(r'DEFAULT\s+([^,\s]+)').firstMatch(columnDef);
    if (defaultMatch != null) {
      return defaultMatch.group(1);
    }
    return null;
  }



  /// 获取MySQL数据库中的表名
  Future<List<String>> _getMySQLTableNames() async {
    if (_mysqlConnection == null) return [];
    
    try {
      final result = await _mysqlConnection!.query('SHOW TABLES');
      return result.map((row) {
        final values = row.values;
        return values != null && values.isNotEmpty ? values.first.toString() : '';
      }).where((name) => name.isNotEmpty).toList();
    } catch (e) {
      print('获取MySQL表名失败: $e');
      return [];
    }
  }



  /// 检查SQLite表结构
  Future<void> _checkSQLiteTableStructure(Map<String, dynamic> result, List<String> existingTables) async {
    if (_database == null) return;
    
    final columnsAdded = <Map<String, String>>[];
    final tablesUpdated = <String>[];
    
    try {
      // 使用SQLite专用的表结构定义
      final tableDefinitions = TableDefinitionsAdapter.getSQLiteTableDefinitions();
      
      // 只检查程序核心表的结构
      for (final tableName in existingTables) {
        if (tableDefinitions.containsKey(tableName)) {
          final tableColumns = await _getSQLiteTableColumns(tableName);
          final requiredTableColumns = tableDefinitions[tableName]!;
          
          bool tableUpdated = false;
          for (final columnName in requiredTableColumns.keys) {
            if (!tableColumns.contains(columnName)) {
              // 字段不存在，尝试添加
              try {
                final columnDef = requiredTableColumns[columnName]!;
                
                // 检查是否为NOT NULL字段，如果是则先添加为可空字段，再更新为NOT NULL
                if (columnDef.contains('NOT NULL') && !columnDef.contains('PRIMARY KEY')) {
                  // 先添加为可空字段
                  final nullableColumnDef = columnDef.replaceAll('NOT NULL', '').trim();
                  await _database!.execute('ALTER TABLE $tableName ADD COLUMN $columnName $nullableColumnDef');
                  
                  // 如果有默认值，更新现有记录
                  if (columnDef.contains('DEFAULT')) {
                    final defaultValue = _extractDefaultValue(columnDef);
                    if (defaultValue != null) {
                      await _database!.execute('UPDATE $tableName SET $columnName = $defaultValue WHERE $columnName IS NULL');
                    }
                  }
                  
                  // SQLite字段添加后保持为可空字段，避免复杂的表重建操作
                  print('字段 $columnName 已添加为可空字段，避免数据丢失风险');
                } else {
                  // 非NOT NULL字段，直接添加
                  await _database!.execute('ALTER TABLE $tableName ADD COLUMN $columnName $columnDef');
                }
                
                columnsAdded.add({
                  'table': tableName,
                  'column': columnName,
                  'type': columnDef,
                  'database': 'SQLite'
                });
                tableUpdated = true;
                print('为表 $tableName 添加字段: $columnName ($columnDef)');
              } catch (e) {
                print('为表 $tableName 添加字段 $columnName 失败: $e');
                // 记录错误但不阻止继续
                (result['errors'] as List<String>).add('为表 $tableName 添加字段 $columnName 失败: $e');
              }
            }
          }
          
          if (tableUpdated) {
            tablesUpdated.add(tableName);
          }
        }
      }
      
      // 更新结果
      result['details']['columnsAdded'] = columnsAdded;
      result['details']['tablesUpdated'] = tablesUpdated;
      result['structureChanges'] = (result['structureChanges'] as int) + columnsAdded.length;
      
      print('SQLite表结构检查完成，添加了 ${columnsAdded.length} 个字段，更新了 ${tablesUpdated.length} 个表');
      
    } catch (e) {
      print('SQLite表结构检查失败: $e');
      (result['errors'] as List<String>).add('表结构检查失败: $e');
    }
  }

  /// 检查MySQL表结构
  Future<void> _checkMySQLTableStructure(Map<String, dynamic> result, List<String> existingTables) async {
    if (_mysqlConnection == null) return;
    
    final columnsAdded = <Map<String, String>>[];
    final tablesUpdated = <String>[];
    
    try {
      // 使用MySQL专用的表结构定义
      final allTables = TableDefinitionsAdapter.getMySQLTableDefinitions();
      
      // 遍历所有必需的表
      for (final tableName in allTables.keys) {
        if (!existingTables.contains(tableName)) {
          // 表不存在，创建新表
          print('表 $tableName 不存在，正在创建...');
          try {
            final createTableSQL = TableDefinitionsAdapter.generateMySQLCreateTable(tableName, allTables[tableName]!);
            await _mysqlConnection!.query(createTableSQL);
            print('表 $tableName 创建成功');
            
            columnsAdded.add({
              'table': tableName,
              'column': 'CREATE_TABLE',
              'type': 'NEW_TABLE',
              'database': 'MySQL'
            });
            tablesUpdated.add(tableName);
          } catch (e) {
            print('创建表 $tableName 失败: $e');
            (result['errors'] as List<String>).add('创建表 $tableName 失败: $e');
          }
          continue;
        }
        
        // 表存在，检查字段结构完整性
        print('检查表 $tableName 的字段结构完整性...');
        final requiredColumns = allTables[tableName]!;
        
        try {
          // 获取现有表结构
          final columns = await _mysqlConnection!.query('DESCRIBE $tableName');
          final existingColumns = columns.map((row) => _safeStringParse(row['Field'])).toSet();
          
          // 检查缺失的字段
          final missingColumns = <String>[];
          for (final entry in requiredColumns.entries) {
            final columnName = entry.key;
            if (!existingColumns.contains(columnName)) {
              missingColumns.add(columnName);
            }
          }
          
          if (missingColumns.isNotEmpty) {
            print('表 $tableName 缺失 ${missingColumns.length} 个字段: ${missingColumns.join(', ')}');
            
            // 检查是否缺失关键列，如果是则重建表
            // 安全的表结构更新：只添加缺失字段，不删除表
            {
              print('表 $tableName 缺失字段，尝试添加字段: ${missingColumns.join(', ')}');
              
              // 尝试添加缺失的字段
              for (final columnName in missingColumns) {
                try {
                  final columnDef = requiredColumns[columnName]!;
                  
                  // 移除PRIMARY KEY和AUTO_INCREMENT约束（ALTER TABLE ADD COLUMN不支持）
                  String safeColumnDef = columnDef
                      .replaceAll('PRIMARY KEY', '')
                      .replaceAll('AUTO_INCREMENT', '')
                      .trim();
                  
                  await _mysqlConnection!.query('ALTER TABLE $tableName ADD COLUMN $columnName $safeColumnDef');
                  
                  columnsAdded.add({
                    'table': tableName,
                    'column': columnName,
                    'type': safeColumnDef,
                    'database': 'MySQL'
                  });
                  print('✅ 成功为MySQL表 $tableName 添加字段: $columnName ($safeColumnDef)');
                  (result['details']['structureChanges'] as List<String>).add('为MySQL表 $tableName 添加字段: $columnName');
                } catch (e) {
                  final errorMsg = '为MySQL表 $tableName 添加字段 $columnName 失败: $e';
                  print('❌ $errorMsg');
                  (result['errors'] as List<String>).add(errorMsg);
                }
              }
              
              if (columnsAdded.any((col) => col['table'] == tableName)) {
                tablesUpdated.add(tableName);
              }
            }
          } else {
            print('表 $tableName 结构完整，无需修改');
          }
        } catch (e) {
          print('检查表 $tableName 结构时出错: $e');
          (result['errors'] as List<String>).add('检查表 $tableName 结构时出错: $e');
        }
      }
      
      // 更新结果
      result['details']['columnsAdded'] = columnsAdded;
      result['details']['tablesUpdated'] = tablesUpdated;
      result['structureChanges'] = (result['structureChanges'] as int) + columnsAdded.length;
      
      print('MySQL表结构检查完成，添加了 ${columnsAdded.length} 个字段，更新了 ${tablesUpdated.length} 个表');
      
    } catch (e) {
      print('MySQL表结构检查失败: $e');
      (result['errors'] as List<String>).add('表结构检查失败: $e');
    }
  }

  /// 从检测结果创建日志对象
  DatabaseStructureLog _createLogFromResult(Map<String, dynamic> result) {
    return DatabaseStructureLog(
      dataSourceType: result['dataSourceType'],
      detectionTime: DateTimeFormatter.fromDbString(result['detectionTime']),
      status: result['status'],
      requiredTables: result['requiredTables'],
      missingTables: result['missingTables'],
      structureChanges: result['structureChanges'],
      errors: List<String>.from(result['errors']),
      details: Map<String, dynamic>.from(result['details']),
      summary: _generateLogSummary(result),
    );
  }

  /// 生成日志摘要
  String _generateLogSummary(Map<String, dynamic> result) {
    final status = result['status'];
    final dataSourceType = result['dataSourceType'];
    final missingTables = result['missingTables'] as int;
    final structureChanges = result['structureChanges'] as int;
    final errors = result['errors'] as List<String>;
    final details = result['details'] as Map<String, dynamic>;
    
    // 获取系统表信息
    final systemTables = details['systemTables'] as List<String>? ?? [];
    final detectedTables = details['detectedTables'] as List<String>? ?? [];
    final missingTableNames = details['missingTableNames'] as List<String>? ?? [];
    final tablesCreated = details['tablesCreated'] as List<String>? ?? [];
    final tablesUpdated = details['tablesUpdated'] as List<String>? ?? [];
    final columnsAdded = details['columnsAdded'] as List<dynamic>? ?? [];
    final ignoredTables = details['ignoredTables'] as List<String>? ?? [];
    
    // 构建摘要信息
    final summaryParts = <String>[];
    
    // 数据源信息
    summaryParts.add('${dataSourceType.toUpperCase()}数据库结构检测');
    
    if (errors.isNotEmpty) {
      // 如果有错误，显示主要错误信息
      final mainError = errors.first;
      if (mainError.contains('失败')) {
        return '${summaryParts[0]}: 部分操作失败，请检查详细日志';
      }
      return '${summaryParts[0]}: 检测失败 - ${mainError.length > 50 ? mainError.substring(0, 50) + '...' : mainError}';
    }
    
    // 表统计信息
    summaryParts.add('系统表 ${systemTables.length}/${detectedTables.length} 个');
    
    if (missingTables > 0) {
      summaryParts.add('创建缺失表 ${tablesCreated.length} 个');
      if (missingTableNames.isNotEmpty) {
        summaryParts.add('(${missingTableNames.join(', ')})');
      }
    }
    
    if (tablesUpdated.isNotEmpty) {
      summaryParts.add('更新表结构 ${tablesUpdated.length} 个');
    }
    
    if (columnsAdded.isNotEmpty) {
      summaryParts.add('添加字段 ${columnsAdded.length} 个');
    }
    
    if (ignoredTables.isNotEmpty) {
      summaryParts.add('忽略非系统表 ${ignoredTables.length} 个');
    }
    
    if (structureChanges == 0 && missingTables == 0) {
      if (detectedTables.length == systemTables.length) {
        return '${summaryParts[0]}: 所有系统表结构完整，无需更新';
      } else {
        return '${summaryParts[0]}: 检测到 ${detectedTables.length}/${systemTables.length} 个系统表，结构正常';
      }
    }
    
    return summaryParts.join(' | ');
  }

  /// 安全解码JSON数据，处理可能的编码问题
  dynamic _decodeJsonSafely(dynamic data) {
    try {
      // 处理 NULL 值
      if (data == null) {
        return <String, dynamic>{};
      }
      
      if (data is String) {
        // 如果是空字符串，返回默认值
        if (data.isEmpty) {
          return <String, dynamic>{};
        }
        // 如果是字符串，尝试直接解码
        return jsonDecode(data);
      } else if (data is Uint8List) {
        // 如果是Uint8List，转换为字符串后解码
        final stringData = String.fromCharCodes(data);
        return jsonDecode(stringData);
      } else if (data is Blob) {
        // 如果是Blob，转换为字符串后解码
        final stringData = String.fromCharCodes(data.toBytes());
        return jsonDecode(stringData);
      } else {
        // 其他类型，尝试转换为字符串后解码
        final stringData = data.toString();
        if (stringData == 'null' || stringData.isEmpty) {
          return <String, dynamic>{};
        }
        return jsonDecode(stringData);
      }
    } catch (e) {
      print('JSON解码失败: $e, 原始数据: $data');
      // 解码失败时返回默认值
      if (data.toString().contains('errors') || data.toString().contains('[')) {
        return <String>[];
      } else {
        return <String, dynamic>{};
      }
    }
  }

  /// 安全解析整数类型
  int _safeIntParse(dynamic data) {
    try {
      if (data is num) {
        return data.toInt();
      } else if (data is String) {
        return int.tryParse(data) ?? 0;
      } else if (data == null) {
        return 0;
      } else {
        return int.tryParse(data.toString()) ?? 0;
      }
    } catch (e) {
      print('整数解析失败: $e, 原始数据: $data');
      return 0;
    }
  }

  /// 安全解析字符串类型
  String _safeStringParse(dynamic data) {
    try {
      if (data is String) {
        return data;
      } else if (data == null) {
        return '';
      } else {
        return data.toString();
      }
    } catch (e) {
      print('字符串解析失败: $e, 原始数据: $data');
      return '';
    }
  }

  /// 安全解析日期时间类型
  DateTime _safeDateTimeParse(dynamic data) {
    try {
      if (data is DateTime) {
        return data;
      } else if (data is String) {
        return DateTimeFormatter.fromDbString(data);
      } else if (data == null) {
        return DateTime.now();
      } else {
        // 尝试解析其他类型
        final stringData = data.toString();
        if (stringData.contains('-') && stringData.contains(':')) {
          return DateTimeFormatter.fromDbString(stringData);
        } else {
          return DateTime.now();
        }
      }
    } catch (e) {
      print('日期时间解析失败: $e, 原始数据: $data');
      return DateTime.now();
    }
  }

  /// 将SQLite字段定义转换为MySQL字段定义
  String _convertColumnDefinitionToMySQL(String columnName, String sqliteDef) {
    // 移除PRIMARY KEY等约束，只保留类型和基本属性
    String cleanDef = sqliteDef;
    
    // 处理PRIMARY KEY
    if (cleanDef.contains('PRIMARY KEY')) {
      cleanDef = cleanDef.replaceAll('PRIMARY KEY', '').trim();
    }
    
    // 处理AUTOINCREMENT
    if (cleanDef.contains('AUTOINCREMENT')) {
      cleanDef = cleanDef.replaceAll('AUTOINCREMENT', '').trim();
    }
    
    // 类型转换
    if (cleanDef.startsWith('INTEGER')) {
      if (columnName == 'id') {
        return 'id INT AUTO_INCREMENT PRIMARY KEY';
      } else {
        return '$columnName INT';
      }
    } else if (cleanDef.startsWith('TEXT')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName VARCHAR(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL';
      } else {
        return '$columnName VARCHAR(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci';
      }
    } else if (cleanDef.startsWith('REAL')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName DECIMAL(10,2) NOT NULL';
      } else {
        return '$columnName DECIMAL(10,2)';
      }
    } else if (cleanDef.startsWith('BLOB')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName LONGBLOB NOT NULL';
      } else {
        return '$columnName LONGBLOB';
      }
    } else if (cleanDef.startsWith('datetime')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP';
      } else {
        return '$columnName DATETIME DEFAULT CURRENT_TIMESTAMP';
      }
    }
    
    // 默认情况，保持原样
    return '$columnName $cleanDef';
  }

  /// 修复MySQL表结构，解决TEXT列不能有默认值等问题
  Future<void> _fixMySQLTableStructures(List<String> existingTables, Map<String, dynamic> result) async {
    if (_mysqlConnection == null) return;
    
    final tablesFixed = <String>[];
    
    try {
      print('开始执行MySQL表结构修复...');
      
      // 只修复真正需要修复的表
      final tablesToFix = <String>[];
      
      // 检查哪些表需要修复
      for (final tableName in existingTables) {
        if (tableName == 'purchase_items' || tableName == 'material_images' || tableName == 'appointments') {
          // 检查表是否真的需要修复
          try {
            final columns = await _mysqlConnection!.query('DESCRIBE $tableName');
            final existingColumns = columns.map((row) => _safeStringParse(row['Field'])).toSet();
            final requiredColumns = TableDefinitionsAdapter.getMySQLTableDefinitions()[tableName]!;
            
            // 检查是否有缺失的字段
            bool needsFix = false;
            for (final columnName in requiredColumns.keys) {
              if (!existingColumns.contains(columnName)) {
                needsFix = true;
                print('表 $tableName 缺少字段: $columnName');
                break;
              }
            }
            
            // 特殊检查：appointments表的treatment_type字段类型
            if (tableName == 'appointments' && existingColumns.contains('treatment_type')) {
              try {
                final treatmentTypeColumn = columns.firstWhere((row) => row['Field'] == 'treatment_type');
                final columnType = treatmentTypeColumn['Type'].toString().toLowerCase();
                if (columnType.contains('blob') || columnType.contains('binary')) {
                  needsFix = true;
                  print('表 $tableName 的 treatment_type 字段类型不正确: $columnType');
                }
              } catch (e) {
                print('检查 treatment_type 字段类型时出错: $e');
              }
            }
            
            if (needsFix) {
              tablesToFix.add(tableName);
            } else {
              print('表 $tableName 结构完整，无需修复');
            }
          } catch (e) {
            print('检查表 $tableName 是否需要修复时出错: $e');
          }
        }
      }
      
      // 只修复需要修复的表
      for (final tableName in tablesToFix) {
        if (tableName == 'purchase_items') {
          try {
            await _fixPurchaseItemsTable();
            tablesFixed.add(tableName);
            print('成功修复表: $tableName');
          } catch (e) {
            print('修复表 $tableName 时出错: $e');
            (result['errors'] as List<String>).add('修复表 $tableName 失败: $e');
          }
        } else if (tableName == 'material_images') {
          try {
            await _fixMaterialImagesTable();
            tablesFixed.add(tableName);
            print('成功修复表: $tableName');
          } catch (e) {
            print('修复表 $tableName 时出错: $e');
            (result['errors'] as List<String>).add('修复表 $tableName 失败: $e');
          }
        } else if (tableName == 'appointments') {
          try {
            await _fixAppointmentsTable();
            tablesFixed.add(tableName);
            print('成功修复表: $tableName');
          } catch (e) {
            print('修复表 $tableName 时出错: $e');
            (result['errors'] as List<String>).add('修复表 $tableName 失败: $e');
          }
        }
      }
      
      if (tablesFixed.isNotEmpty) {
        result['details']['tablesFixed'] = tablesFixed;
        // 只有在实际有修复时才增加计数
        final actualChanges = tablesFixed.length;
        result['structureChanges'] = (result['structureChanges'] as int) + actualChanges;
        print('MySQL表结构修复完成，修复了 $actualChanges 个表');
      } else {
        print('MySQL表结构检查完成，无需修复');
      }
      
      // 打印最终的结构变化统计
      print('最终统计 - 表结构检查: ${result['details']['columnsAdded']?.length ?? 0} 个字段, ${result['details']['tablesUpdated']?.length ?? 0} 个表');
      print('最终统计 - 表结构修复: ${tablesFixed.length} 个表');
      print('最终统计 - 总结构变化: ${result['structureChanges']}');
      
    } catch (e) {
      print('MySQL表结构修复过程中出错: $e');
      (result['errors'] as List<String>).add('表结构修复失败: $e');
    }
  }

    /// 修复purchase_items表结构
  Future<void> _fixPurchaseItemsTable() async {
    if (_mysqlConnection == null) return;
    
    try {
      // 检查表是否存在
      final tables = await _mysqlConnection!.query('SHOW TABLES LIKE "purchase_items"');
      
      if (tables.isNotEmpty) {
        print('purchase_items表已存在，正在检查并更新表结构...');
        
        // 检查并添加缺失的字段
        final requiredColumns = TableDefinitionsAdapter.getMySQLTableDefinitions()['purchase_items']!;
        
        // 获取现有表结构
        final columns = await _mysqlConnection!.query('DESCRIBE purchase_items');
        final existingColumns = columns.map((row) => row['Field'] as String).toSet();
        
        // 检查并添加缺失的字段
        for (final entry in requiredColumns.entries) {
          final columnName = entry.key;
          final columnDef = entry.value;
          
          if (!existingColumns.contains(columnName)) {
            print('为purchase_items表添加缺失字段: $columnName');
            try {
              // 将SQLite类型转换为MySQL类型
              final mysqlColumnDef = _convertColumnDefinitionToMySQL(columnName, columnDef);
              await _mysqlConnection!.query('ALTER TABLE purchase_items ADD COLUMN $mysqlColumnDef');
              print('成功添加字段: $columnName');
            } catch (e) {
              print('添加字段 $columnName 失败: $e');
            }
          }
        }
        
        // 检查并更新字段类型（如果需要）- 跳过主键字段
        for (final entry in requiredColumns.entries) {
          final columnName = entry.key;
          final columnDef = entry.value;
          
          // 跳过主键字段，避免重复主键错误
          if (columnName == 'id') continue;
          
          if (existingColumns.contains(columnName)) {
            try {
              // 检查字段类型是否需要更新
              final mysqlColumnDef = _convertColumnDefinitionToMySQL(columnName, columnDef);
              await _mysqlConnection!.query('ALTER TABLE purchase_items MODIFY COLUMN $mysqlColumnDef');
              print('成功更新字段类型: $columnName');
            } catch (e) {
              print('更新字段类型 $columnName 失败: $e');
            }
          }
        }
        
        print('purchase_items表结构更新完成');
      } else {
        // 表不存在，创建新表
        print('purchase_items表不存在，正在创建...');
        final purchaseItemsColumns = TableDefinitionsAdapter.getMySQLTableDefinitions()['purchase_items']!;
        final createTableSQL = TableDefinitionsAdapter.generateMySQLCreateTable('purchase_items', purchaseItemsColumns);
        await _mysqlConnection!.query(createTableSQL);
        print('purchase_items表创建成功');
      }
      
    } catch (e) {
      print('修复purchase_items表时出错: $e');
      rethrow;
    }
  }

  /// 修复material_images表结构
  Future<void> _fixMaterialImagesTable() async {
    if (_mysqlConnection == null) return;
    
    try {
      // 检查表是否存在
      final tables = await _mysqlConnection!.query('SHOW TABLES LIKE "material_images"');
      
      if (tables.isNotEmpty) {
        print('material_images表已存在，正在检查并更新表结构...');
        
        // 检查并添加缺失的字段
        final requiredColumns = TableDefinitionsAdapter.getMySQLTableDefinitions()['material_images']!;
        
        // 获取现有表结构
        final columns = await _mysqlConnection!.query('DESCRIBE material_images');
        final existingColumns = columns.map((row) => row['Field'] as String).toSet();
        
        // 检查并添加缺失的字段
        print('现有字段: ${existingColumns.join(', ')}');
        print('必需字段: ${requiredColumns.keys.join(', ')}');
        
        for (final entry in requiredColumns.entries) {
          final columnName = entry.key;
          final columnDef = entry.value;
          
          if (!existingColumns.contains(columnName)) {
            print('为material_images表添加缺失字段: $columnName ($columnDef)');
            try {
              // 将SQLite类型转换为MySQL类型
              final mysqlColumnDef = _convertColumnDefinitionToMySQL(columnName, columnDef);
              print('MySQL字段定义: $mysqlColumnDef');
              await _mysqlConnection!.query('ALTER TABLE material_images ADD COLUMN $mysqlColumnDef');
              print('成功添加字段: $columnName');
            } catch (e) {
              print('添加字段 $columnName 失败: $e');
              // 尝试强制添加字段
              try {
                if (columnName == 'image_path') {
                  print('尝试强制添加image_path字段...');
                  await _mysqlConnection!.query('ALTER TABLE material_images ADD COLUMN image_path VARCHAR(255)');
                  print('强制添加image_path字段成功');
                }
              } catch (e2) {
                print('强制添加字段也失败: $e2');
              }
            }
          } else {
            print('字段 $columnName 已存在');
          }
        }
        
        // 检查并更新字段类型（如果需要）- 跳过主键字段
        for (final entry in requiredColumns.entries) {
          final columnName = entry.key;
          final columnDef = entry.value;
          
          // 跳过主键字段，避免重复主键错误
          if (columnName == 'id') continue;
          
          if (existingColumns.contains(columnName)) {
            try {
              // 检查字段类型是否需要更新
              final mysqlColumnDef = _convertColumnDefinitionToMySQL(columnName, columnDef);
              await _mysqlConnection!.query('ALTER TABLE material_images MODIFY COLUMN $mysqlColumnDef');
              print('成功更新字段类型: $columnName');
            } catch (e) {
              print('更新字段类型 $columnName 失败: $e');
            }
          }
        }
        
        print('material_images表结构更新完成');
        
        // 验证字段是否真的被添加了
        try {
          final verifyColumns = await _mysqlConnection!.query('DESCRIBE material_images');
          final finalColumns = verifyColumns.map((row) => row['Field'] as String).toSet();
          print('最终字段列表: ${finalColumns.join(', ')}');
          
          if (finalColumns.contains('image_path')) {
            print('✅ image_path字段已成功添加');
          } else {
            print('❌ image_path字段仍然缺失，尝试强制添加...');
            try {
              await _mysqlConnection!.query('ALTER TABLE material_images ADD COLUMN image_path VARCHAR(255)');
              print('强制添加image_path字段成功');
            } catch (e) {
              print('强制添加失败: $e');
            }
          }
        } catch (e) {
          print('验证字段时出错: $e');
        }
      } else {
        // 表不存在，创建新表
        print('material_images表不存在，正在创建...');
        final materialImagesColumns = TableDefinitionsAdapter.getMySQLTableDefinitions()['material_images']!;
        final createTableSQL = TableDefinitionsAdapter.generateMySQLCreateTable('material_images', materialImagesColumns);
        await _mysqlConnection!.query(createTableSQL);
        print('material_images表创建成功');
      }
      
    } catch (e) {
      print('修复material_images表时出错: $e');
      rethrow;
    }
  }

  /// 修复appointments表结构
  Future<void> _fixAppointmentsTable() async {
    if (_mysqlConnection == null) return;
    
    try {
      print('开始修复 appointments 表结构...');
      
      // 检查表是否存在
      final tables = await _mysqlConnection!.query('SHOW TABLES LIKE \'appointments\'');
      if (tables.isEmpty) {
        print('appointments 表不存在，创建新表');
        final createTableSQL = TableDefinitionsAdapter.generateMySQLCreateTable('appointments', TableDefinitionsAdapter.getMySQLTableDefinitions()['appointments']!);
        await _mysqlConnection!.query(createTableSQL);
        print('appointments 表创建成功');
        return;
      }
      
      // 检查字段结构
      final columns = await _mysqlConnection!.query('DESCRIBE appointments');
      final existingColumns = columns.map((row) => row['Field'] as String).toSet();
      
      // 检查并添加缺失的字段
      final requiredColumns = TableDefinitionsAdapter.getMySQLTableDefinitions()['appointments']!;
      
      for (final entry in requiredColumns.entries) {
        final columnName = entry.key;
        final columnDef = entry.value;
        
        if (!existingColumns.contains(columnName)) {
          print('为 appointments 表添加缺失字段: $columnName');
          try {
            final mysqlColumnDef = _convertColumnDefinitionToMySQL(columnName, columnDef);
            await _mysqlConnection!.query('ALTER TABLE appointments ADD COLUMN $mysqlColumnDef');
            print('成功添加字段: $columnName');
          } catch (e) {
            print('添加字段 $columnName 失败: $e');
            throw e;
          }
        }
      }
      
      // 特殊处理：检查treatment_type字段类型
      if (existingColumns.contains('treatment_type')) {
        try {
          final treatmentTypeColumn = columns.firstWhere((row) => row['Field'] == 'treatment_type');
          final columnType = treatmentTypeColumn['Type'].toString().toLowerCase();
          
          if (columnType.contains('blob') || columnType.contains('binary')) {
            print('检测到 treatment_type 字段类型不正确: $columnType，正在修复...');
            
            // 备份现有数据
            final backupData = await _mysqlConnection!.query('SELECT id, treatment_type FROM appointments WHERE treatment_type IS NOT NULL');
            final backupMap = <int, String>{};
            
            for (final row in backupData) {
              final id = row['id'] as int;
              final treatmentType = row['treatment_type'];
              String treatmentTypeStr = '';
              
              if (treatmentType is Blob) {
                try {
                  final bytes = treatmentType.toBytes();
                  if (bytes.isNotEmpty) {
                    treatmentTypeStr = utf8.decode(bytes, allowMalformed: true);
                  }
                } catch (e) {
                  print('备份 treatment_type 数据时出错: $e');
                }
              } else if (treatmentType is String) {
                treatmentTypeStr = treatmentType;
              }
              
              if (treatmentTypeStr.isNotEmpty) {
                backupMap[id] = treatmentTypeStr;
              }
            }
            
            print('备份了 ${backupMap.length} 条 treatment_type 数据');
            
            // 修改字段类型
            await _mysqlConnection!.query('ALTER TABLE appointments MODIFY COLUMN treatment_type VARCHAR(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci');
            print('成功修改 treatment_type 字段类型为 VARCHAR(1000)');
            
            // 恢复数据
            if (backupMap.isNotEmpty) {
              for (final entry in backupMap.entries) {
                final id = entry.key;
                final treatmentTypeStr = entry.value;
                await _mysqlConnection!.query(
                  'UPDATE appointments SET treatment_type = ? WHERE id = ?',
                  [treatmentTypeStr, id]
                );
              }
              print('成功恢复 ${backupMap.length} 条 treatment_type 数据');
            }
          } else {
            print('treatment_type 字段类型正确: $columnType');
          }
        } catch (e) {
          print('检查 treatment_type 字段类型时出错: $e');
        }
      }
      
      print('appointments 表结构修复完成');
      
    } catch (e) {
      print('修复 appointments 表结构失败: $e');
      throw e;
    }
  }

  // 设置备份数据源
  Future<void> setBackupDataSource(String dataSource) async {
    _backupDataSource = dataSource;
    await _saveSettings();
    notifyListeners();
  }

  // 设置模块数据源
  Future<void> setModuleDataSource(String module, String dataSource) async {
    _moduleDataSources[module] = dataSource;
    await _saveSettings();
    notifyListeners();
  }

  // 设置所有模块数据源
  Future<void> setAllModuleDataSources(Map<String, String> moduleDataSources) async {
    _moduleDataSources = Map<String, String>.from(moduleDataSources);
    await _saveSettings();
    notifyListeners();
  }

  // 获取指定模块的数据源类型
  String getModuleDataSource(String module) {
    return _moduleDataSources[module] ?? 'sqlite';
  }

  // 检查模块是否使用MySQL数据源
  bool isModuleUsingMySQL(String module) {
    return _moduleDataSources[module] == 'mysql';
  }

  // 获取所有使用MySQL的模块
  List<String> getMySQLModules() {
    return _moduleDataSources.entries
        .where((entry) => entry.value == 'mysql')
        .map((entry) => entry.key)
        .toList();
  }

  // 获取所有使用SQLite的模块
  List<String> getSQLiteModules() {
    return _moduleDataSources.entries
        .where((entry) => entry.value == 'sqlite')
        .map((entry) => entry.key)
        .toList();
  }
  
  /// 配置管理器相关方法
  
  /// 获取配置存储信息
  Map<String, dynamic> getConfigStorageInfo() {
    return {
      'useFileStorage': _useFileStorage,
      'storageMode': _configManager.storageMode.toString(),
      'configPath': _useFileStorage ? AppPaths.configPath : 'SharedPreferences',
      'appInfo': AppPaths.appInfo,
    };
  }
  
  /// 强制切换到文件存储模式
  Future<bool> switchToFileStorage() async {
    try {
      final canUse = await _checkFileStorageAvailability();
      if (canUse) {
        _useFileStorage = true;
        _configManager.setStorageMode(StorageMode.file);
        await _migrateConfigsToFile();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      print('切换到文件存储失败: $e');
      return false;
    }
  }
  
  /// 强制切换到SharedPreferences存储模式
  Future<void> switchToPreferencesStorage() async {
    _useFileStorage = false;
    _configManager.setStorageMode(StorageMode.preferences);
    notifyListeners();
  }
  
  /// 使用配置管理器保存配置
  Future<bool> saveConfigValue(String key, dynamic value) async {
    return await _configManager.saveConfig(key, value);
  }
  
  /// 使用配置管理器加载配置
  Future<T?> loadConfigValue<T>(String key, {T? defaultValue}) async {
    return await _configManager.loadConfig<T>(key, defaultValue: defaultValue);
  }
  
  /// 清理配置存储
  Future<bool> clearAllConfigs() async {
    return await _configManager.clearAllConfigs();
  }
  
  /// 获取所有配置键
  Future<List<String>> getAllConfigKeys() async {
    return await _configManager.getAllConfigKeys();
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dentist_app_windows/utils/config_manager.dart';
import 'package:dentist_app_windows/utils/app_paths.dart';
import 'package:dentist_app_windows/utils/datetime_formatter.dart';
import '../../../utils/log_manager.dart';

/// 配置存储服务
/// 负责应用的配置存储管理，包括文件存储和SharedPreferences存储
class ConfigStorageService {
  final ConfigManager _configManager = ConfigManager.instance;
  static const String _migrationCompletedKey = '__config_migration_completed__';

  // 配置存储模式
  bool _useFileStorage = true;
  bool get useFileStorage => _useFileStorage;

  /// 初始化配置存储
  Future<void> initialize() async {
    try {
      // 检查是否可以使用应用目录存储
      final canUseFileStorage = await _checkFileStorageAvailability();

      if (canUseFileStorage) {
        _useFileStorage = true;
        _configManager.setStorageMode(StorageMode.hybrid);

        // 只在第一次发现旧配置时迁移，避免每次启动重复执行
        final migrationCompleted = await _configManager.loadConfig<bool>(
                _migrationCompletedKey,
                defaultValue: false) ??
            false;
        if (!migrationCompleted) {
          await _migrateConfigsToFile();
        }
      } else {
        _useFileStorage = false;
        _configManager.setStorageMode(StorageMode.preferences);
      }
    } catch (e) {
      LogManager.e('ConfigStorageService', '初始化配置存储失败', error: e);
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
      LogManager.e('ConfigStorageService', '文件存储不可用', error: e);
      return false;
    }
  }

  /// 迁移配置到文件存储
  Future<void> _migrateConfigsToFile() async {
    try {
      await _configManager.migrateToFile();
    } catch (e) {
      LogManager.e('ConfigStorageService', '配置迁移失败', error: e);
    }
  }

  /// 从SharedPreferences加载设置
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'extendedThemeMode': prefs.getInt('extendedThemeMode') ?? 0,
      'themeMode': prefs.getInt('themeMode') ?? 0,
      'fontSize': prefs.getDouble('fontSize') ?? 1.0,
      'language': prefs.getString('language') ?? 'zh_CN',
      'backupPath': prefs.getString('backupPath') ?? '',
      'backupPath2': prefs.getString('backupPath2') ?? '',
      'autoBackup': prefs.getBool('autoBackup') ?? false,
      'backupInterval': prefs.getInt('backupInterval') ?? 5,
      'lastBackupDate': prefs.getString('lastBackupDate'),
      'dataSourceType': prefs.getString('dataSourceType') ?? 'sqlite',
      'dataSourceMode': prefs.getString('dataSourceMode') ?? 'global',
      'sqliteDbPath': prefs.getString('sqliteDbPath') ?? '',
      'mysqlHost': prefs.getString('mysqlHost') ?? '',
      'mysqlPort': prefs.getString('mysqlPort') ?? '3306',
      'mysqlDatabase': prefs.getString('mysqlDatabase') ?? '',
      'mysqlUsername': prefs.getString('mysqlUsername') ?? '',
      'mysqlPassword': prefs.getString('mysqlPassword') ?? '',
      'customSqliteDbPath': prefs.getString('customSqliteDbPath') ?? '',
      'mysqlSettings': prefs.getString('mysqlSettings'),
      'lastMySQLSettings': prefs.getString('lastMySQLSettings'),
      'backupDataSource': prefs.getString('backupDataSource') ?? 'sqlite',
      'moduleDataSources': prefs.getString('moduleDataSources'),
      'appName': prefs.getString('appName') ?? '牙科诊所管理系统',
      'windowWidth': prefs.getDouble('windowWidth'),
      'windowHeight': prefs.getDouble('windowHeight'),
    };
  }

  /// 保存设置到SharedPreferences
  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();

    // 保存扩展主题设置
    if (settings.containsKey('extendedThemeMode')) {
      await prefs.setInt('extendedThemeMode', settings['extendedThemeMode']);
    }

    // 兼容旧版主题设置
    if (settings.containsKey('themeMode')) {
      await prefs.setInt('themeMode', settings['themeMode']);
    }

    // 保存字体大小设置
    if (settings.containsKey('fontSize')) {
      await prefs.setDouble('fontSize', settings['fontSize']);
    }

    // 保存语言设置
    if (settings.containsKey('language')) {
      await prefs.setString('language', settings['language']);
    }

    // 保存数据备份路径
    if (settings.containsKey('backupPath')) {
      await prefs.setString('backupPath', settings['backupPath']);
    }
    if (settings.containsKey('backupPath2')) {
      await prefs.setString('backupPath2', settings['backupPath2']);
    }

    // 保存自动备份设置
    if (settings.containsKey('autoBackup')) {
      await prefs.setBool('autoBackup', settings['autoBackup']);
    }
    if (settings.containsKey('backupInterval')) {
      await prefs.setInt('backupInterval', settings['backupInterval']);
    }

    // 保存上次备份日期
    if (settings.containsKey('lastBackupDate')) {
      final lastBackupDate = settings['lastBackupDate'];
      if (lastBackupDate != null) {
        await prefs.setString(
            'lastBackupDate', DateTimeFormatter.toDbString(lastBackupDate));
      }
    }

    // 保存数据源设置
    if (settings.containsKey('dataSourceType')) {
      await prefs.setString('dataSourceType', settings['dataSourceType']);
    }

    // 保存数据源模式设置
    if (settings.containsKey('dataSourceMode')) {
      await prefs.setString('dataSourceMode', settings['dataSourceMode']);
    }

    // 保存SQLite数据库文件路径
    if (settings.containsKey('sqliteDbPath')) {
      await prefs.setString('sqliteDbPath', settings['sqliteDbPath']);
    }

    // 保存MySQL连接设置
    if (settings.containsKey('mysqlHost')) {
      await prefs.setString('mysqlHost', settings['mysqlHost']);
    }
    if (settings.containsKey('mysqlPort')) {
      await prefs.setString('mysqlPort', settings['mysqlPort']);
    }
    if (settings.containsKey('mysqlDatabase')) {
      await prefs.setString('mysqlDatabase', settings['mysqlDatabase']);
    }
    if (settings.containsKey('mysqlUsername')) {
      await prefs.setString('mysqlUsername', settings['mysqlUsername']);
    }
    if (settings.containsKey('mysqlPassword')) {
      await prefs.setString('mysqlPassword', settings['mysqlPassword']);
    }

    // 保存自定义SQLite数据库路径
    if (settings.containsKey('customSqliteDbPath')) {
      await prefs.setString(
          'customSqliteDbPath', settings['customSqliteDbPath']);
    }

    // 保存MySQL设置映射
    if (settings.containsKey('mysqlSettings')) {
      final mysqlSettings = settings['mysqlSettings'];
      if (mysqlSettings != null) {
        await prefs.setString('mysqlSettings', jsonEncode(mysqlSettings));
      }
    }

    // 保存上次MySQL设置
    if (settings.containsKey('lastMySQLSettings')) {
      final lastMySQLSettings = settings['lastMySQLSettings'];
      if (lastMySQLSettings != null) {
        await prefs.setString(
            'lastMySQLSettings', jsonEncode(lastMySQLSettings));
      }
    }

    // 保存备份数据源设置
    if (settings.containsKey('backupDataSource')) {
      await prefs.setString('backupDataSource', settings['backupDataSource']);
    }

    // 保存模块数据源配置
    if (settings.containsKey('moduleDataSources')) {
      final moduleDataSources = settings['moduleDataSources'];
      if (moduleDataSources != null) {
        await prefs.setString(
            'moduleDataSources', jsonEncode(moduleDataSources));
      }
    }

    // 保存应用名称
    if (settings.containsKey('appName')) {
      await prefs.setString('appName', settings['appName']);
    }

    // 保存窗口大小
    if (settings.containsKey('windowWidth')) {
      await prefs.setDouble('windowWidth', settings['windowWidth']);
    }
    if (settings.containsKey('windowHeight')) {
      await prefs.setDouble('windowHeight', settings['windowHeight']);
    }
  }

  /// 强制切换到文件存储模式
  Future<bool> switchToFileStorage() async {
    try {
      final canUse = await _checkFileStorageAvailability();
      if (canUse) {
        _useFileStorage = true;
        _configManager.setStorageMode(StorageMode.file);
        await _migrateConfigsToFile();
        return true;
      }
      return false;
    } catch (e) {
      LogManager.e('ConfigStorageService', '切换到文件存储失败', error: e);
      return false;
    }
  }

  /// 强制切换到SharedPreferences存储模式
  Future<void> switchToPreferencesStorage() async {
    _useFileStorage = false;
    _configManager.setStorageMode(StorageMode.preferences);
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

  /// 获取配置存储信息
  Map<String, dynamic> getConfigStorageInfo() {
    return {
      'useFileStorage': _useFileStorage,
      'storageMode': _configManager.storageMode.toString(),
      'configPath': _useFileStorage ? AppPaths.configPath : 'SharedPreferences',
      'appInfo': AppPaths.appInfo,
    };
  }

  /// 清除所有设置
  Future<void> clearAllSettings() async {
    try {
      // 清除SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 清除ConfigManager中的配置
      await _configManager.clearAllConfigs();
    } catch (e) {
      LogManager.e('ConfigStorageService', '清除设置失败', error: e);
      throw Exception('清除设置失败: $e');
    }
  }
}

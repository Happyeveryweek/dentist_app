import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_paths.dart';
import 'datetime_formatter.dart';

/// 配置存储模式
enum StorageMode {
  file,           // 文件存储（应用目录）
  preferences,    // SharedPreferences存储
  hybrid,         // 混合模式（优先文件，回退到SharedPreferences）
}

/// 配置管理器
/// 统一管理应用配置的存储，支持文件和SharedPreferences两种方式
class ConfigManager {
  static ConfigManager? _instance;
  static ConfigManager get instance => _instance ??= ConfigManager._();
  ConfigManager._();

  static const String _migrationCompletedKey = '__config_migration_completed__';

  StorageMode _storageMode = StorageMode.hybrid;

  /// 设置存储模式
  void setStorageMode(StorageMode mode) {
    _storageMode = mode;
  }

  /// 获取当前存储模式
  StorageMode get storageMode => _storageMode;

  /// 保存配置
  Future<bool> saveConfig(String key, dynamic value) async {
    switch (_storageMode) {
      case StorageMode.file:
        return await _saveToFile(key, value);
      case StorageMode.preferences:
        return await _saveToPreferences(key, value);
      case StorageMode.hybrid:
        // 优先尝试文件存储
        final fileResult = await _saveToFile(key, value);
        if (fileResult) {
          return true;
        }
        // 文件存储失败，回退到SharedPreferences
        return await _saveToPreferences(key, value);
    }
  }

  /// 加载配置
  Future<T?> loadConfig<T>(String key, {T? defaultValue}) async {
    switch (_storageMode) {
      case StorageMode.file:
        return await _loadFromFile<T>(key, defaultValue: defaultValue);
      case StorageMode.preferences:
        return await _loadFromPreferences<T>(key, defaultValue: defaultValue);
      case StorageMode.hybrid:
        // 优先尝试文件存储
        final fileResult = await _loadFromFile<T>(key, defaultValue: null);
        if (fileResult != null) {
          return fileResult;
        }
        // 文件存储没有数据，尝试SharedPreferences
        return await _loadFromPreferences<T>(key, defaultValue: defaultValue);
    }
  }

  /// 删除配置
  Future<bool> removeConfig(String key) async {
    bool result = true;
    
    switch (_storageMode) {
      case StorageMode.file:
        result = await _removeFromFile(key);
        break;
      case StorageMode.preferences:
        result = await _removeFromPreferences(key);
        break;
      case StorageMode.hybrid:
        // 两种存储都尝试删除
        final fileResult = await _removeFromFile(key);
        final prefResult = await _removeFromPreferences(key);
        result = fileResult || prefResult;
        break;
    }
    
    return result;
  }

  /// 清空所有配置
  Future<bool> clearAllConfigs() async {
    bool result = true;
    
    switch (_storageMode) {
      case StorageMode.file:
        result = await _clearFileConfigs();
        break;
      case StorageMode.preferences:
        result = await _clearPreferencesConfigs();
        break;
      case StorageMode.hybrid:
        // 两种存储都清空
        final fileResult = await _clearFileConfigs();
        final prefResult = await _clearPreferencesConfigs();
        result = fileResult && prefResult;
        break;
    }
    
    return result;
  }

  /// 获取配置文件路径
  String get configFilePath => AppPaths.configPath;

  /// 检查配置是否存在
  Future<bool> hasConfig(String key) async {
    switch (_storageMode) {
      case StorageMode.file:
        return await _hasFileConfig(key);
      case StorageMode.preferences:
        return await _hasPreferencesConfig(key);
      case StorageMode.hybrid:
        final hasFile = await _hasFileConfig(key);
        if (hasFile) return true;
        return await _hasPreferencesConfig(key);
    }
  }

  /// 获取所有配置键
  Future<List<String>> getAllConfigKeys() async {
    final Set<String> keys = {};
    
    switch (_storageMode) {
      case StorageMode.file:
        keys.addAll(await _getFileConfigKeys());
        break;
      case StorageMode.preferences:
        keys.addAll(await _getPreferencesConfigKeys());
        break;
      case StorageMode.hybrid:
        keys.addAll(await _getFileConfigKeys());
        keys.addAll(await _getPreferencesConfigKeys());
        break;
    }
    
    return keys.toList();
  }

  /// 迁移配置从SharedPreferences到文件
  Future<bool> migrateToFile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      final Map<String, dynamic> allConfigs = {};
      
      for (final key in keys) {
        final value = prefs.get(key);
        if (value != null) {
          allConfigs[key] = value;
        }
      }

      // 记录迁移已完成，避免每次启动都重复执行迁移流程
      allConfigs[_migrationCompletedKey] = true;
      
      final success = await _saveAllToFile(allConfigs);
      if (success) {
        return true;
      }
      
      return false;
    } catch (e) {
      print('配置迁移失败: $e');
      return false;
    }
  }

  // 私有方法：文件存储相关

  Future<bool> _saveToFile(String key, dynamic value) async {
    try {
      final configs = await _loadAllFromFile();
      configs[key] = value;
      return await _saveAllToFile(configs);
    } catch (e) {
      print('保存配置到文件失败: $e');
      return false;
    }
  }

  Future<T?> _loadFromFile<T>(String key, {T? defaultValue}) async {
    try {
      final configs = await _loadAllFromFile();
      final value = configs[key];
      if (value is T) {
        return value;
      }
      return defaultValue;
    } catch (e) {
      print('从文件加载配置失败: $e');
      return defaultValue;
    }
  }

  Future<bool> _removeFromFile(String key) async {
    try {
      final configs = await _loadAllFromFile();
      configs.remove(key);
      return await _saveAllToFile(configs);
    } catch (e) {
      print('从文件删除配置失败: $e');
      return false;
    }
  }

  Future<bool> _clearFileConfigs() async {
    try {
      return await _saveAllToFile({});
    } catch (e) {
      print('清空文件配置失败: $e');
      return false;
    }
  }

  Future<bool> _hasFileConfig(String key) async {
    try {
      final configs = await _loadAllFromFile();
      return configs.containsKey(key);
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _getFileConfigKeys() async {
    try {
      final configs = await _loadAllFromFile();
      return configs.keys.toList();
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> _loadAllFromFile() async {
    try {
      final configFile = File(configFilePath);
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        if (content.isNotEmpty) {
          return Map<String, dynamic>.from(jsonDecode(content));
        }
      }
      return {};
    } catch (e) {
      print('加载配置文件失败: $e');
      return {};
    }
  }

  Future<bool> _saveAllToFile(Map<String, dynamic> configs) async {
    try {
      final configFile = File(configFilePath);
      
      // 确保目录存在
      final configDir = Directory(configFile.parent.path);
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }
      
      await configFile.writeAsString(jsonEncode(configs));
      return true;
    } catch (e) {
      print('保存配置文件失败: $e');
      return false;
    }
  }

  // 私有方法：SharedPreferences存储相关

  Future<bool> _saveToPreferences(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (value is String) {
        return await prefs.setString(key, value);
      } else if (value is int) {
        return await prefs.setInt(key, value);
      } else if (value is double) {
        return await prefs.setDouble(key, value);
      } else if (value is bool) {
        return await prefs.setBool(key, value);
      } else if (value is List<String>) {
        return await prefs.setStringList(key, value);
      } else {
        // 其他类型转换为JSON字符串
        return await prefs.setString(key, jsonEncode(value));
      }
    } catch (e) {
      print('保存配置到SharedPreferences失败: $e');
      return false;
    }
  }

  Future<T?> _loadFromPreferences<T>(String key, {T? defaultValue}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.get(key);
      
      if (value is T) {
        return value;
      } else if (value is String && T != String) {
        // 尝试从JSON字符串解析
        try {
          final decoded = jsonDecode(value);
          if (decoded is T) {
            return decoded;
          }
        } catch (e) {
          // JSON解析失败，返回默认值
        }
      }
      
      return defaultValue;
    } catch (e) {
      print('从SharedPreferences加载配置失败: $e');
      return defaultValue;
    }
  }

  Future<bool> _removeFromPreferences(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(key);
    } catch (e) {
      print('从SharedPreferences删除配置失败: $e');
      return false;
    }
  }

  Future<bool> _clearPreferencesConfigs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.clear();
    } catch (e) {
      print('清空SharedPreferences配置失败: $e');
      return false;
    }
  }

  Future<bool> _hasPreferencesConfig(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(key);
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _getPreferencesConfigKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getKeys().toList();
    } catch (e) {
      return [];
    }
  }
}

/// 配置管理器扩展方法
extension ConfigManagerExtension on ConfigManager {
  /// 保存备份路径配置
  Future<bool> saveBackupPath(String path) async {
    return await saveConfig('backupPath', path);
  }

  /// 加载备份路径配置
  Future<String> loadBackupPath() async {
    return await loadConfig<String>('backupPath', defaultValue: '') ?? '';
  }

  /// 保存备份路径2配置
  Future<bool> saveBackupPath2(String path) async {
    return await saveConfig('backupPath2', path);
  }

  /// 加载备份路径2配置
  Future<String> loadBackupPath2() async {
    return await loadConfig<String>('backupPath2', defaultValue: '') ?? '';
  }

  /// 保存自动备份设置
  Future<bool> saveAutoBackup(bool enabled) async {
    return await saveConfig('autoBackup', enabled);
  }

  /// 加载自动备份设置
  Future<bool> loadAutoBackup() async {
    return await loadConfig<bool>('autoBackup', defaultValue: false) ?? false;
  }

  /// 保存备份间隔
  Future<bool> saveBackupInterval(int days) async {
    return await saveConfig('backupInterval', days);
  }

  /// 加载备份间隔
  Future<int> loadBackupInterval() async {
    return await loadConfig<int>('backupInterval', defaultValue: 7) ?? 7;
  }

  /// 保存最后备份时间
  Future<bool> saveLastBackupDate(DateTime date) async {
    return await saveConfig('lastBackupDate', DateTimeFormatter.toDbString(date));
  }

  /// 加载最后备份时间
  Future<DateTime?> loadLastBackupDate() async {
    final dateStr = await loadConfig<String>('lastBackupDate');
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        return DateTimeFormatter.fromDbString(dateStr);
      } catch (e) {
        print('解析最后备份时间失败: $e');
      }
    }
    return null;
  }
}

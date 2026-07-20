import 'dart:convert';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../utils/app_paths.dart';
import '../utils/atomic_file_writer.dart';
import '../utils/datetime_formatter.dart';
import '../utils/app_logger.dart';
import '../utils/sync_table_config.dart';

/// 同步配置模型
class SyncConfig {
  bool syncEnabled; // 是否启用同步
  int syncIntervalDays; // 同步间隔天数
  String lastSyncTime; // 上次同步时间
  List<String> syncTables; // 需要同步的表

  SyncConfig({
    this.syncEnabled = false,
    this.syncIntervalDays = 7,
    this.lastSyncTime = '',
    List<String>? syncTables,
  }) : syncTables =
           syncTables ?? List<String>.from(SyncTableConfig.syncTableNames);

  // 从JSON创建配置
  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    final rawTables = json['sync_tables'];
    if (rawTables != null && rawTables is! List) {
      throw const FormatException('sync_tables 必须是数组');
    }
    final List<String>? tables =
        rawTables?.map<String>((value) {
          if (value is! String) {
            throw const FormatException('sync_tables 只能包含表名字符串');
          }
          return value;
        }).toList();
    if (tables != null) {
      SyncTableConfig.validate(tables);
    }
    return SyncConfig(
      syncEnabled: json['sync_enabled'] as bool? ?? false,
      syncIntervalDays: json['sync_interval_days'] as int? ?? 7,
      lastSyncTime: json['last_sync_time'] as String? ?? '',
      syncTables: tables,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'sync_enabled': syncEnabled,
      'sync_interval_days': syncIntervalDays,
      'last_sync_time': lastSyncTime,
      'sync_tables': syncTables,
    };
  }

  // 保存同步配置
  static Future<void> saveSyncConfig(
    SyncConfig config, {
    String? filePath,
  }) async {
    try {
      SyncTableConfig.validate(config.syncTables);
      // 使用应用数据目录
      final configPath = filePath ?? await AppPaths.syncConfigPath;
      final configFile = File(configPath);

      // 确保目录存在
      final configDir = Directory(path.dirname(configPath));
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      await AtomicFileWriter.write(configFile, jsonEncode(config.toJson()));
      AppLogger.info('同步配置已保存到: $configPath');
    } catch (e) {
      AppLogger.info('保存同步配置失败: $e');
      rethrow;
    }
  }

  // 加载同步配置
  static Future<SyncConfig> loadSyncConfig({String? filePath}) async {
    final configPath = filePath ?? await AppPaths.syncConfigPath;
    final configFile = File(configPath);

    if (await configFile.exists()) {
      try {
        AppLogger.info('从应用目录加载同步配置: $configPath');
        return await _readConfigFile(configFile);
      } catch (primaryError) {
        AppLogger.info('同步配置读取失败，尝试最近备份: $primaryError');
        final backupFile = File(
          '${configFile.path}${AtomicFileWriter.backupSuffix}',
        );
        if (await backupFile.exists()) {
          return await _readConfigFile(backupFile);
        }
        rethrow;
      }
    }

    return SyncConfig(); // 返回默认配置
  }

  static Future<SyncConfig> _readConfigFile(File configFile) async {
    final decoded = jsonDecode(await configFile.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('同步配置JSON结构无效');
    }
    return SyncConfig.fromJson(decoded);
  }

  /// 检查是否需要同步
  bool shouldSync() {
    if (!syncEnabled) return false;

    if (lastSyncTime.isEmpty) return true;

    try {
      final lastSync = DateTimeFormatter.fromDbString(lastSyncTime);
      final now = DateTime.now();
      final daysSinceLastSync = now.difference(lastSync).inDays;

      return daysSinceLastSync >= syncIntervalDays;
    } catch (e) {
      AppLogger.info('解析上次同步时间失败: $e');
      return true;
    }
  }

  /// 更新上次同步时间
  Future<void> updateLastSyncTime() async {
    lastSyncTime = DateTimeFormatter.nowDbString();
    await saveSyncConfig(this);
  }
}

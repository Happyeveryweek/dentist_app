import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import '../utils/app_paths.dart';
import '../utils/datetime_formatter.dart';
import '../utils/app_logger.dart';

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
           syncTables ??
           [
             'patients',
             'purchase_items',
             'purchase_records',
             'patient_materials',
             'financial_records',
             'financial_items',
             'patient_medical_records',
             'medical_record_templates',
           ];

  // 从JSON创建配置
  factory SyncConfig.fromJson(Map<String, dynamic> json) {
    return SyncConfig(
      syncEnabled: json['sync_enabled'] ?? false,
      syncIntervalDays: json['sync_interval_days'] ?? 7,
      lastSyncTime: json['last_sync_time'] ?? '',
      syncTables:
          json['sync_tables'] != null
              ? List<String>.from(json['sync_tables'])
              : null,
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
  static Future<void> saveSyncConfig(SyncConfig config) async {
    try {
      // 使用应用数据目录
      final configPath = await AppPaths.syncConfigPath;
      final configFile = File(configPath);

      // 确保目录存在
      final configDir = Directory(path.dirname(configPath));
      if (!await configDir.exists()) {
        await configDir.create(recursive: true);
      }

      await configFile.writeAsString(jsonEncode(config.toJson()));
      AppLogger.info('同步配置已保存到: $configPath');
    } catch (e) {
      AppLogger.info('保存同步配置失败，尝试使用文档目录: $e');
      try {
        // 回退到文档目录
        final appDir = await getApplicationDocumentsDirectory();
        final configFile = File(path.join(appDir.path, 'sync_config.json'));
        await configFile.writeAsString(jsonEncode(config.toJson()));
      } catch (fallbackError) {
        AppLogger.info('保存同步配置完全失败: $fallbackError');
      }
    }
  }

  // 加载同步配置
  static Future<SyncConfig> loadSyncConfig() async {
    try {
      // 使用应用数据目录
      final configPath = await AppPaths.syncConfigPath;
      final configFile = File(configPath);

      if (await configFile.exists()) {
        final jsonString = await configFile.readAsString();
        AppLogger.info('从应用目录加载同步配置: $configPath');
        return SyncConfig.fromJson(jsonDecode(jsonString));
      }
    } catch (e) {
      AppLogger.info('从应用目录加载同步配置失败，尝试文档目录: $e');
      try {
        // 回退到文档目录
        final appDir = await getApplicationDocumentsDirectory();
        final configFile = File(path.join(appDir.path, 'sync_config.json'));

        if (await configFile.exists()) {
          final jsonString = await configFile.readAsString();
          AppLogger.info('从文档目录加载同步配置');
          return SyncConfig.fromJson(jsonDecode(jsonString));
        }
      } catch (fallbackError) {
        AppLogger.info('加载同步配置完全失败: $fallbackError');
      }
    }

    return SyncConfig(); // 返回默认配置
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

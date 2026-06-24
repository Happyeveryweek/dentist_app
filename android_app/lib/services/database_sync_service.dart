import '../models/sync_config.dart';
import '../utils/datetime_formatter.dart';
import '../utils/sync_manager.dart' as sync_manager;
import '../utils/app_logger.dart';

/// 数据库同步服务
/// 职责：数据同步检查、强制同步
class DatabaseSyncService {
  String _dbType = '';

  /// 设置数据库类型
  void setDatabaseType(String dbType) {
    _dbType = dbType;
  }

  /// 检查并执行数据同步
  Future<void> checkAndSyncData() async {
    try {
      final syncConfig = await SyncConfig.loadSyncConfig();
      if (!syncConfig.syncEnabled) {
        AppLogger.info('数据同步已禁用');
        return;
      }

      final lastSyncStr = syncConfig.lastSyncTime;
      final syncIntervalDays = syncConfig.syncIntervalDays;
      final now = DateTime.now();

      if (lastSyncStr.isEmpty) {
        AppLogger.info('从未进行过数据同步，需要执行首次同步');
      } else {
        try {
          final lastSync = DateTimeFormatter.fromDbString(lastSyncStr);
          if (now.difference(lastSync).inDays >= syncIntervalDays) {
            AppLogger.info('需要执行数据同步，上次同步时间: $lastSync');
          } else {
            AppLogger.info('距离上次同步不足$syncIntervalDays天，跳过同步');
            return;
          }
        } catch (e) {
          AppLogger.info('解析上次同步时间失败，执行同步: $e');
        }
      }

      await sync_manager.SyncManager.checkAndSync();
    } catch (e) {
      AppLogger.info('检查数据同步时出错: $e');
    }
  }

  /// 强制数据同步（供外部调用）
  Future<bool> forceDataSync() async {
    try {
      AppLogger.info('DatabaseSyncService: 开始执行强制数据同步...');
      AppLogger.info('DatabaseSyncService: 当前数据源类型: $_dbType');

      if (_dbType != 'mysql') {
        AppLogger.info('DatabaseSyncService: 当前不是MySQL模式，无法进行数据同步');
        return false;
      }

      AppLogger.info('DatabaseSyncService: 调用SyncManager.forceSync()...');
      final result = await sync_manager.SyncManager.forceSync();
      AppLogger.info('DatabaseSyncService: 同步结果: $result');
      return result;
    } catch (e) {
      AppLogger.info('DatabaseSyncService: 强制数据同步失败: $e');
      return false;
    }
  }
}

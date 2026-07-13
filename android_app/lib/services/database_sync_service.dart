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

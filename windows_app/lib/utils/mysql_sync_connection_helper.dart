import 'package:mysql1/mysql1.dart';
import '../providers/database_provider.dart';
import '../utils/log_manager.dart';

/// MySQL同步连接辅助类
///
/// 专门用于SQLite→MySQL数据同步场景的MySQL连接获取
///
/// 使用场景：
/// - 当模块配置为使用SQLite作为主数据源时
/// - 需要将SQLite中的数据同步到MySQL数据库
/// - 此时不能使用模块的_currentMysqlConnection（因为它在SQLite模式下不会获取连接）
///
/// 核心功能：
/// - 无论当前模块使用什么数据源（SQLite/MySQL），都能获取到MySQL连接
/// - 自动从DatabaseProvider获取最新的MySQL连接
/// - 支持连接缓存和自动更新
///
/// 使用示例：
/// ```dart
/// class MyProvider {
///   DatabaseProvider? _databaseProvider;
///   MySqlConnection? _mysqlConnection;
///
///   // 获取用于同步的MySQL连接
///   MySqlConnection? get _syncMysqlConnection {
///     return MySqlSyncConnectionHelper.getSyncConnection(
///       databaseProvider: _databaseProvider,
///       cachedConnection: _mysqlConnection,
///       onConnectionUpdate: (newConnection) {
///         _mysqlConnection = newConnection;
///       },
///     );
///   }
///
///   Future<void> _syncToMySQL() async {
///     final conn = _syncMysqlConnection;
///     if (conn == null) {
///       LogManager.w('MysqlSyncConnectionHelper', 'MySQL连接不可用，跳过同步');
///       return;
///     }
///     // 执行同步操作...
///   }
/// }
/// ```
class MySqlSyncConnectionHelper {
  /// 获取用于同步的MySQL连接
  ///
  /// 参数说明：
  /// - [databaseProvider]: DatabaseProvider实例，用于获取最新的MySQL连接
  /// - [cachedConnection]: 缓存的MySQL连接（可选）
  /// - [onConnectionUpdate]: 连接更新回调（可选），当获取到新连接时调用
  ///
  /// 返回值：
  /// - 返回可用的MySQL连接，如果无法获取则返回null
  ///
  /// 工作流程：
  /// 1. 优先从DatabaseProvider获取最新连接（确保连接有效）
  /// 2. 如果获取成功，通过回调更新缓存
  /// 3. 如果获取失败，降级使用缓存的连接
  /// 4. 如果都不可用，返回null
  static MySqlConnection? getSyncConnection({
    required DatabaseProvider? databaseProvider,
    MySqlConnection? cachedConnection,
    void Function(MySqlConnection)? onConnectionUpdate,
  }) {
    // 尝试从DatabaseProvider获取最新连接
    if (databaseProvider != null) {
      try {
        final latestConnection = databaseProvider.mysqlConnection;
        if (latestConnection != null) {
          // 更新缓存（如果提供了回调）
          onConnectionUpdate?.call(latestConnection);
          return latestConnection;
        }
      } catch (e) {
        LogManager.e('MysqlSyncConnectionHelper',
            'MySqlSyncConnectionHelper: 从DatabaseProvider获取MySQL连接失败',
            error: e);
      }
    }

    // 降级：返回缓存的连接
    if (cachedConnection != null) {
      LogManager.w('MysqlSyncConnectionHelper',
          'MySqlSyncConnectionHelper: 使用缓存的MySQL连接');
      return cachedConnection;
    }

    // 无可用连接
    LogManager.w(
        'MysqlSyncConnectionHelper', 'MySqlSyncConnectionHelper: 无可用的MySQL连接');
    return null;
  }
}

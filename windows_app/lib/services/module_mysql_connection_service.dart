import 'dart:async';

import 'package:mysql1/mysql1.dart';

import '../providers/database_provider.dart';
import '../utils/log_manager.dart';
import '../utils/mysql_sync_connection_helper.dart';

typedef MySqlConnectionProbe = Future<void> Function(
  MySqlConnection connection,
  Duration timeout,
  String timeoutMessage,
);

/// 业务模块共用的 MySQL 连接服务。
class ModuleMysqlConnectionService {
  ModuleMysqlConnectionService({
    required this.logTag,
    required DatabaseProvider? Function() getDatabaseProvider,
    required MySqlConnection? Function() getCachedConnection,
    required void Function(MySqlConnection?) setCachedConnection,
    required String Function() getEffectiveDataSourceType,
    MySqlConnectionProbe? probeConnection,
  })  : _getDatabaseProvider = getDatabaseProvider,
        _getCachedConnection = getCachedConnection,
        _setCachedConnection = setCachedConnection,
        _getEffectiveDataSourceType = getEffectiveDataSourceType,
        _probeConnection = probeConnection ?? _defaultProbeConnection;

  final String logTag;
  final DatabaseProvider? Function() _getDatabaseProvider;
  final MySqlConnection? Function() _getCachedConnection;
  final void Function(MySqlConnection?) _setCachedConnection;
  final String Function() _getEffectiveDataSourceType;
  final MySqlConnectionProbe _probeConnection;

  Future<MySqlConnection?> getCurrentConnection() async {
    final databaseProvider = _getDatabaseProvider();
    if (_getEffectiveDataSourceType() != 'mysql' || databaseProvider == null) {
      LogManager.d(logTag, '当前数据源不是MySQL，返回缓存连接');
      return _getCachedConnection();
    }

    try {
      final latestConnection = databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        if (await isConnectionValid(latestConnection)) {
          _setCachedConnection(latestConnection);
          return latestConnection;
        }

        LogManager.w(logTag, 'MySQL连接已失效，尝试重新获取...');
        await databaseProvider.initializeMySQL();
        final newConnection = databaseProvider.mysqlConnection;
        if (newConnection != null) {
          LogManager.i(logTag, 'MySQL连接重新获取成功');
          _setCachedConnection(newConnection);
          return newConnection;
        }
        LogManager.e(logTag, 'MySQL连接重新获取失败');
      }
    } catch (e) {
      LogManager.e(logTag, '获取最新MySQL连接失败', error: e);
    }

    return _getCachedConnection();
  }

  Future<bool> isConnectionValid(MySqlConnection connection) async {
    try {
      await _probeConnection(
        connection,
        const Duration(seconds: 3),
        '连接验证超时',
      );
      return true;
    } catch (e) {
      LogManager.e(logTag, 'MySQL连接验证失败', error: e);
      return false;
    }
  }

  MySqlConnection? getSyncConnection() {
    return MySqlSyncConnectionHelper.getSyncConnection(
      databaseProvider: _getDatabaseProvider(),
      cachedConnection: _getCachedConnection(),
      onConnectionUpdate: _setCachedConnection,
    );
  }

  Future<bool> testCurrentConnection() async {
    final connection = await getCurrentConnection();
    if (connection == null) {
      return false;
    }

    try {
      await _probeConnection(
        connection,
        const Duration(seconds: 10),
        '连接测试超时',
      );
      return true;
    } catch (e) {
      LogManager.e(logTag, 'MySQL连接测试失败', error: e);
      _setCachedConnection(null);
      return false;
    }
  }

  Future<void> reconnectConnection() async {
    final databaseProvider = _getDatabaseProvider();
    if (databaseProvider == null) {
      return;
    }

    await databaseProvider.initializeMySQL();
    _setCachedConnection(databaseProvider.mysqlConnection);
  }

  static Future<void> _defaultProbeConnection(
    MySqlConnection connection,
    Duration timeout,
    String timeoutMessage,
  ) async {
    await connection.query('SELECT 1').timeout(
          timeout,
          onTimeout: () => throw TimeoutException(timeoutMessage, timeout),
        );
  }
}

import 'dart:async';

import 'package:mysql1/mysql1.dart';

import '../../../providers/database_provider.dart';
import '../../../utils/mysql_sync_connection_helper.dart';

/// 预约模块 MySQL 连接服务
///
/// 统一处理：
/// - 从 DatabaseProvider 获取最新 MySQL 连接
/// - 连接有效性校验
/// - SQLite -> MySQL 同步连接获取
class AppointmentMysqlConnectionService {
  AppointmentMysqlConnectionService({
    required DatabaseProvider? Function() getDatabaseProvider,
    required MySqlConnection? Function() getCachedConnection,
    required void Function(MySqlConnection?) setCachedConnection,
    required String Function() getEffectiveDataSourceType,
  })  : _getDatabaseProvider = getDatabaseProvider,
        _getCachedConnection = getCachedConnection,
        _setCachedConnection = setCachedConnection,
        _getEffectiveDataSourceType = getEffectiveDataSourceType;

  final DatabaseProvider? Function() _getDatabaseProvider;
  final MySqlConnection? Function() _getCachedConnection;
  final void Function(MySqlConnection?) _setCachedConnection;
  final String Function() _getEffectiveDataSourceType;

  Future<MySqlConnection?> getCurrentConnection() async {
    final databaseProvider = _getDatabaseProvider();
    if (_getEffectiveDataSourceType() != 'mysql' || databaseProvider == null) {
      return _getCachedConnection();
    }

    try {
      final latestConnection = databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        final isValid = await validateConnection(latestConnection);
        if (isValid) {
          _setCachedConnection(latestConnection);
          return latestConnection;
        }

        print('⚠️ MySQL连接已失效，尝试重新获取...');
        await databaseProvider.initializeMySQL();
        final newConnection = databaseProvider.mysqlConnection;
        if (newConnection != null) {
          _setCachedConnection(newConnection);
          return newConnection;
        }
      }
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
    }

    return _getCachedConnection();
  }

  Future<bool> validateConnection(MySqlConnection connection) async {
    try {
      await connection.query('SELECT 1').timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('连接验证超时');
        },
      );
      return true;
    } catch (e) {
      print('MySQL连接验证失败: $e');
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
    final conn = await getCurrentConnection();
    if (conn == null) {
      return false;
    }

    try {
      await conn.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', Duration(seconds: 10));
        },
      );
      return true;
    } catch (e) {
      print('MySQL连接测试失败: $e');
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
}

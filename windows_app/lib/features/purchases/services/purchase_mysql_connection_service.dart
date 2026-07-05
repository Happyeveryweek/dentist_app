import 'dart:async';

import 'package:mysql1/mysql1.dart';

import '../../../providers/database_provider.dart';
import '../../../utils/mysql_sync_connection_helper.dart';
import '../../../utils/log_manager.dart';

/// 采购模块 MySQL 连接服务
class PurchaseMysqlConnectionService {
  PurchaseMysqlConnectionService({
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
      LogManager.d('PurchaseMysqlConnectionService', '当前数据源不是MySQL，返回缓存连接');
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

        LogManager.w('PurchaseMysqlConnectionService', 'MySQL连接已失效，尝试重新获取...');
        await databaseProvider.initializeMySQL();
        final newConnection = databaseProvider.mysqlConnection;
        if (newConnection != null) {
          LogManager.i('PurchaseMysqlConnectionService', 'MySQL连接重新获取成功');
          _setCachedConnection(newConnection);
          return newConnection;
        } else {
          LogManager.e('PurchaseMysqlConnectionService', 'MySQL连接重新获取失败');
        }
      }
    } catch (e) {
      LogManager.e('PurchaseMysqlConnectionService', '获取最新MySQL连接失败', error: e);
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
      LogManager.e('PurchaseMysqlConnectionService', 'MySQL连接验证失败', error: e);
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
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      return true;
    } catch (e) {
      LogManager.e('PurchaseMysqlConnectionService', 'MySQL连接测试失败', error: e);
      _setCachedConnection(null);
      return false;
    }
  }
}

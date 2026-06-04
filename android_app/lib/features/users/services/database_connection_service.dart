import 'package:flutter/material.dart';
import 'mysql_connection_retry_service.dart';
import 'sqlite_database_switch_service.dart';

/// 数据库连接服务
class DatabaseConnectionService {
  /// 重试MySQL连接
  static Future<void> retryMySQLConnection(BuildContext context) async {
    return MySQLConnectionRetryService.retry(context);
  }

  /// 切换到SQLite数据库
  static Future<void> switchToSQLite(BuildContext context) async {
    return SQLiteDatabaseSwitchService.switchToSQLite(context);
  }
}

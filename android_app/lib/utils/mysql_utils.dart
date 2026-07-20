import 'package:mysql1/mysql1.dart';
import 'package:dentist_app/models/database_config.dart';
import 'dart:async';
import './app_logger.dart';

/// MySQL连接工具类
class MySqlUtils {
  /// 测试MySQL连接
  static Future<bool> testConnection(DatabaseConfig config) async {
    try {
      final settings = ConnectionSettings(
        host: config.mysql.host,
        port:
            int.tryParse(config.mysql.port) ??
            int.parse(DatabaseDefaults.mysqlPort),
        user: config.mysql.username,
        password: config.mysql.password,
        db: config.mysql.database,
        timeout: const Duration(seconds: 5),
      );

      final conn = await MySqlConnection.connect(settings);
      await conn.close();
      return true;
    } catch (e) {
      AppLogger.info('MySQL连接测试失败: $e');
      return false;
    }
  }

  /// 获取MySQL连接
  static Future<MySqlConnection?> getConnection(DatabaseConfig config) async {
    try {
      final settings = ConnectionSettings(
        host: config.mysql.host,
        port:
            int.tryParse(config.mysql.port) ??
            int.parse(DatabaseDefaults.mysqlPort),
        user: config.mysql.username,
        password: config.mysql.password,
        db: config.mysql.database,
        timeout: const Duration(seconds: 10),
      );

      final conn = await MySqlConnection.connect(settings);
      try {
        await conn.query("SET NAMES 'utf8mb4'");
        await conn.query("SET character_set_connection = 'utf8mb4'");
        await conn.query("SET character_set_results = 'utf8mb4'");
      } catch (e) {
        AppLogger.info('设置MySQL会话字符集失败: $e');
      }

      return conn;
    } catch (e) {
      AppLogger.info('MySQL连接失败: $e');
      return null;
    }
  }
}

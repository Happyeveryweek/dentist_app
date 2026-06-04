import 'dart:io';
import 'package:mysql1/mysql1.dart';
import 'datetime_formatter.dart';
import 'package:dentist_app/models/database_config.dart';
import 'dart:async';

/// MySQL连接工具类
class MySqlUtils {
  /// 测试MySQL连接
  static Future<bool> testConnection(DatabaseConfig config) async {
    try {
      final settings = ConnectionSettings(
        host: config.mysql.host,
        port: int.tryParse(config.mysql.port) ?? 3306,
        user: config.mysql.username,
        password: config.mysql.password,
        db: config.mysql.database,
        timeout: const Duration(seconds: 5),
      );

      final conn = await MySqlConnection.connect(settings);
      await conn.close();
      return true;
    } catch (e) {
      print('MySQL连接测试失败: $e');
      return false;
    }
  }

  /// 获取MySQL连接
  static Future<MySqlConnection?> getConnection(DatabaseConfig config) async {
    try {
      final settings = ConnectionSettings(
        host: config.mysql.host,
        port: int.tryParse(config.mysql.port) ?? 3306,
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
        print('设置MySQL会话字符集失败: $e');
      }

      return conn;
    } catch (e) {
      print('MySQL连接失败: $e');
      return null;
    }
  }

  /// 检查MySQL表是否存在
  static Future<bool> checkTablesExist(MySqlConnection conn, List<String> tableNames) async {
    try {
      for (final tableName in tableNames) {
        final result = await conn.query(
          'SHOW TABLES LIKE ?',
          [tableName],
        );
        if (result.isEmpty) {
          print('表 $tableName 不存在');
          return false;
        }
      }
      return true;
    } catch (e) {
      print('检查表存在性失败: $e');
      return false;
    }
  }

  /// 获取表记录数量
  static Future<int> getTableCount(MySqlConnection conn, String tableName) async {
    try {
      final result = await conn.query('SELECT COUNT(*) as count FROM $tableName');
      return result.first['count'] as int;
    } catch (e) {
      print('获取表记录数量失败: $e');
      return 0;
    }
  }

  /// 获取表的最后更新时间
  static Future<DateTime?> getLastUpdateTime(MySqlConnection conn, String tableName) async {
    try {
      final result = await conn.query(
        'SELECT MAX(updated_at) as last_update FROM $tableName',
      );
      
      if (result.isNotEmpty && result.first['last_update'] != null) {
        final lastUpdate = result.first['last_update'];
        if (lastUpdate is DateTime) {
          return lastUpdate;
        } else if (lastUpdate is String) {
          return DateTimeFormatter.fromDbString(lastUpdate);
        }
      }
      return null;
    } catch (e) {
      print('获取最后更新时间失败: $e');
      return null;
    }
  }
}
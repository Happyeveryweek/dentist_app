import 'dart:convert';

import 'package:mysql1/mysql1.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// MySQL 连接工具类
/// 从 SharedPreferences 读取 MySQL 配置并建立连接，消除各 Provider 中的重复代码
class MySqlConnectionHelper {
  MySqlConnectionHelper._();

  /// 从 SharedPreferences 读取 MySQL 配置并尝试建立新连接
  ///
  /// 返回 null 表示配置缺失或连接失败
  static Future<MySqlConnection?> establishConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mysqlJson = prefs.getString('mysqlSettings');
      Map<String, dynamic>? settings;

      if (mysqlJson != null && mysqlJson.isNotEmpty) {
        try {
          settings = Map<String, dynamic>.from(jsonDecode(mysqlJson));
          print('从 SharedPreferences mysqlSettings 读取 MySQL 配置');
        } catch (e) {
          print('解析 SharedPreferences 中 mysqlSettings 失败: $e');
          settings = null;
        }
      }

      // 如果没有整体 json 配置，回退到单项配置键（兼容旧版保存方式）
      if (settings == null) {
        final host = prefs.getString('mysqlHost') ?? '';
        if (host.isNotEmpty) {
          settings = {
            'host': host,
            'port': prefs.getString('mysqlPort') ?? '3306',
            'database': prefs.getString('mysqlDatabase') ?? '',
            'username': prefs.getString('mysqlUsername') ?? '',
            'password': prefs.getString('mysqlPassword') ?? '',
          };
          print('从 SharedPreferences 单独键读取 MySQL 配置');
        }
      }

      if (settings != null) {
        try {
          final host = settings['host'];
          final port = int.tryParse(settings['port']?.toString() ?? '3306') ?? 3306;
          final database = settings['database'];
          final username = settings['username'];
          final password = settings['password'];

          final conn = await MySqlConnection.connect(ConnectionSettings(
            host: host,
            port: port,
            db: database,
            user: username,
            password: password,
          ));

          // 强制使用 utf8mb4 字符集以避免中文/特殊字符乱码
          try {
            await conn.query("SET NAMES 'utf8mb4'");
            await conn.query("SET character_set_connection = 'utf8mb4'");
            await conn.query("SET character_set_results = 'utf8mb4'");
          } catch (e) {
            print('设置MySQL会话字符集失败: $e');
          }

          return conn;
        } catch (e) {
          print('尝试初始化MySQL连接失败: $e');
          return null;
        }
      }
    } catch (e) {
      print('读取SharedPreferences以获取MySQL设置失败: $e');
    }
    return null;
  }
}

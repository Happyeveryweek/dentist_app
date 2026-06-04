import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../models/database_config.dart';
import '../services/database_health_service.dart';
import '../services/database_sync_service.dart';
import '../services/mysql_connection_service.dart';
import '../services/sqlite_initialization_service.dart';

/// 数据库启动编排结果
class DatabaseBootstrapResult {
  final DatabaseConfig dbConfig;
  final String dbType;
  final String dbPath;
  final bool initialized;
  final bool databaseChanged;
  final bool shouldNavigateToDashboard;
  final bool isAutoSwitchedToSQLite;
  final String previousDbType;

  const DatabaseBootstrapResult({
    required this.dbConfig,
    required this.dbType,
    required this.dbPath,
    required this.initialized,
    required this.databaseChanged,
    required this.shouldNavigateToDashboard,
    required this.isAutoSwitchedToSQLite,
    required this.previousDbType,
  });
}

/// 数据库启动编排服务
/// 职责：加载配置、初始化 SQLite/MySQL、处理自动切换、同步基础状态
class DatabaseBootstrapService {
  Future<DatabaseBootstrapResult> bootstrap({
    required MySQLConnectionService mysqlConnectionService,
    required DatabaseHealthService healthService,
    required SQLiteInitializationService sqliteInitService,
    required DatabaseSyncService syncService,
  }) async {
    print('开始初始化数据库...');
    print('当前工作目录: ${Directory.current.path}');

    print('开始加载数据库配置...');
    final dbConfig = await DatabaseConfig.loadConfig();

    var dbType = dbConfig.dbType;
    var dbPath = '';
    var initialized = false;
    var databaseChanged = false;
    var shouldNavigateToDashboard = false;
    var isAutoSwitchedToSQLite = false;
    var previousDbType = 'sqlite';

    print('数据库类型: $dbType');
    print('数据库配置: $dbConfig');

    // 初始化 SQLite 作为备份通道
    sqliteInitService.setDatabaseConfig(dbConfig);
    mysqlConnectionService.setDatabaseConfig(dbConfig);
    healthService.setConnection(mysqlConnectionService.connection);

    if (dbType == 'sqlite') {
      print('初始化SQLite数据库...');
      await sqliteInitService.initDatabase();
      dbPath = sqliteInitService.dbPath;
      print('SQLite数据库路径: $dbPath');
    } else if (dbType == 'mysql') {
      final canConnect = await mysqlConnectionService.testConnection(dbConfig);
      var shouldSwitchToSQLite = false;

      if (canConnect) {
        try {
          await mysqlConnectionService.initConnection(isStartup: true);
          healthService.setConnection(mysqlConnectionService.connection);
          healthService.setConnectionStatus(true);
          healthService.startHealthMonitoring();
          print('MySQL数据库初始化成功');
        } catch (e) {
          shouldSwitchToSQLite = true;
        }
      } else {
        shouldSwitchToSQLite = true;
      }

      if (shouldSwitchToSQLite) {
        print('MySQL连接失败，自动切换到SQLite数据库');
        isAutoSwitchedToSQLite = true;
        previousDbType = 'mysql';
        dbType = 'sqlite';

        await sqliteInitService.initWithNotification();
        dbPath = sqliteInitService.dbPath;
        databaseChanged = true;
        shouldNavigateToDashboard = true;
      } else {
        dbPath = '${dbConfig.mysql.host}:${dbConfig.mysql.port}/${dbConfig.mysql.database}';
      }
    }

    try {
      print('开始测试数据库连接...');
      if (dbType == 'sqlite') {
        final db = await sqliteInitService.getDatabase();
        await db!.rawQuery('SELECT 1');
        print('数据库连接测试成功');
      } else if (dbType == 'mysql') {
        final results = await mysqlConnectionService.connection!.query('SELECT 1');
        if (results.isNotEmpty) {
          print('数据库连接测试成功');
        } else {
          throw Exception('数据库连接测试失败: 查询返回空结果');
        }
      }
    } catch (e) {
      print('数据库连接测试失败: $e');
      print('错误堆栈: ${StackTrace.current}');
      throw Exception('数据库连接测试失败: $e');
    }

    initialized = true;
    syncService.setDatabaseType(dbType);
    print('数据库初始化完成，initialized = $initialized');

    return DatabaseBootstrapResult(
      dbConfig: dbConfig,
      dbType: dbType,
      dbPath: dbPath,
      initialized: initialized,
      databaseChanged: databaseChanged,
      shouldNavigateToDashboard: shouldNavigateToDashboard,
      isAutoSwitchedToSQLite: isAutoSwitchedToSQLite,
      previousDbType: previousDbType,
    );
  }
}

import 'dart:io';


import '../models/database_config.dart';
import '../services/database_health_service.dart';
import '../services/database_sync_service.dart';
import '../services/mysql_connection_service.dart';
import '../services/sqlite_initialization_service.dart';
import '../utils/app_logger.dart';

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
    AppLogger.info('开始初始化数据库...');
    AppLogger.info('当前工作目录: ${Directory.current.path}');

    AppLogger.info('开始加载数据库配置...');
    final dbConfig = await DatabaseConfig.loadConfig();

    var dbType = dbConfig.dbType;
    var dbPath = '';
    var initialized = false;
    var databaseChanged = false;
    var shouldNavigateToDashboard = false;
    var isAutoSwitchedToSQLite = false;
    var previousDbType = 'sqlite';

    AppLogger.info('数据库类型: $dbType');
    AppLogger.info('数据库配置: $dbConfig');

    // 初始化 SQLite 作为备份通道
    sqliteInitService.setDatabaseConfig(dbConfig);
    mysqlConnectionService.setDatabaseConfig(dbConfig);
    healthService.setConnection(mysqlConnectionService.connection);

    if (dbType == 'sqlite') {
      AppLogger.info('初始化SQLite数据库...');
      await sqliteInitService.initDatabase();
      dbPath = sqliteInitService.dbPath;
      AppLogger.info('SQLite数据库路径: $dbPath');
    } else if (dbType == 'mysql') {
      final canConnect = await mysqlConnectionService.testConnection(dbConfig);
      var shouldSwitchToSQLite = false;

      if (canConnect) {
        try {
          await mysqlConnectionService.initConnection(isStartup: true);
          healthService.setConnection(mysqlConnectionService.connection);
          healthService.setConnectionStatus(true);
          healthService.startHealthMonitoring();
          AppLogger.info('MySQL数据库初始化成功');
        } catch (e) {
          shouldSwitchToSQLite = true;
        }
      } else {
        shouldSwitchToSQLite = true;
      }

      if (shouldSwitchToSQLite) {
        AppLogger.info('MySQL连接失败，自动切换到SQLite数据库');
        isAutoSwitchedToSQLite = true;
        previousDbType = 'mysql';
        dbType = 'sqlite';

        await sqliteInitService.initWithNotification();
        dbPath = sqliteInitService.dbPath;
        databaseChanged = true;
        shouldNavigateToDashboard = true;
      } else {
        dbPath =
            '${dbConfig.mysql.host}:${dbConfig.mysql.port}/${dbConfig.mysql.database}';
      }
    }

    try {
      AppLogger.info('开始测试数据库连接...');
      if (dbType == 'sqlite') {
        final db = await sqliteInitService.getDatabase();
        if (db == null) {
          throw Exception('SQLite数据库未初始化');
        }
        await db.rawQuery('SELECT 1');
        AppLogger.info('数据库连接测试成功');
      } else if (dbType == 'mysql') {
        final connection = mysqlConnectionService.connection;
        if (connection == null) {
          throw Exception('MySQL连接未建立');
        }
        final results = await connection.query(
          'SELECT 1',
        );
        if (results.isNotEmpty) {
          AppLogger.info('数据库连接测试成功');
        } else {
          throw Exception('数据库连接测试失败: 查询返回空结果');
        }
      }
    } catch (e) {
      AppLogger.info('数据库连接测试失败: $e');
      AppLogger.info('错误堆栈: ${StackTrace.current}');
      throw Exception('数据库连接测试失败: $e');
    }

    initialized = true;
    syncService.setDatabaseType(dbType);
    AppLogger.info('数据库初始化完成，initialized = $initialized');

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

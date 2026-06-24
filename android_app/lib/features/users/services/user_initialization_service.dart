import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../../../utils/app_logger.dart';

/// 用户 Provider 初始化结果
class UserInitializationResult {
  final Database? database;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;
  final bool initialized;

  UserInitializationResult({
    required this.database,
    required this.mysqlConnection,
    required this.dataSourceType,
    required this.initialized,
  });
}

/// 用户初始化编排服务
/// 职责：把数据库提供者接入、数据源识别和连接同步从 Provider 中抽离出来
class UserInitializationService {
  Future<UserInitializationResult> initializeFromDatabase({
    required dynamic dbProvider,
  }) async {
    String dbType = 'sqlite';
    if (dbProvider.dbType != null) {
      dbType = dbProvider.dbType;
    } else if (dbProvider.dataSourceType != null) {
      dbType = dbProvider.dataSourceType;
    }

    if (dbType == 'mysql') {
      final mysqlConnection = dbProvider.mysqlConnection;
      if (mysqlConnection != null) {
        AppLogger.info('✅ UserProvider MySQL数据源设置成功');
        return UserInitializationResult(
          database: null,
          mysqlConnection: mysqlConnection,
          dataSourceType: 'mysql',
          initialized: true,
        );
      }

      AppLogger.info('警告：MySQL连接为null，尝试SQLite');
      final sqliteDatabase = await _loadSqliteDatabase(dbProvider);
      if (sqliteDatabase != null) {
        AppLogger.info('UserProvider 回退到SQLite数据源设置成功');
        return UserInitializationResult(
          database: sqliteDatabase,
          mysqlConnection: null,
          dataSourceType: 'sqlite',
          initialized: true,
        );
      }

      AppLogger.info('警告：SQLite数据库实例为null，延迟初始化...');
      throw Exception('所有数据库获取方式都失败');
    }

    final sqliteDatabase = await _loadSqliteDatabase(dbProvider);
    if (sqliteDatabase != null) {
      AppLogger.info('✅ UserProvider SQLite数据源设置成功');
      return UserInitializationResult(
        database: sqliteDatabase,
        mysqlConnection: null,
        dataSourceType: 'sqlite',
        initialized: true,
      );
    }

    AppLogger.info('警告：所有数据库获取方式都失败');
    throw Exception('所有数据库获取方式都失败');
  }

  Future<Database?> _loadSqliteDatabase(dynamic dbProvider) async {
    try {
      return await dbProvider.sqliteDatabase;
    } catch (e) {
      AppLogger.info('获取SQLite数据库失败: $e');
      if (dbProvider.database != null) {
        return dbProvider.database;
      }
      return null;
    }
  }
}

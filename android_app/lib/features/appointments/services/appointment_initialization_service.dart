import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

/// 预约 Provider 初始化结果
class AppointmentInitializationResult {
  final Database? database;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;
  final bool initialized;

  AppointmentInitializationResult({
    required this.database,
    required this.mysqlConnection,
    required this.dataSourceType,
    required this.initialized,
  });
}

/// 预约初始化编排服务
/// 职责：把数据库提供者接入、数据源识别和连接同步从 Provider 中抽离出来
class AppointmentInitializationService {
  Future<AppointmentInitializationResult> initializeFromDatabase({
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
        print('✅ AppointmentsProvider MySQL数据源设置成功');
        return AppointmentInitializationResult(
          database: null,
          mysqlConnection: mysqlConnection,
          dataSourceType: 'mysql',
          initialized: true,
        );
      }

      print('警告：MySQL连接为null，尝试SQLite');
      final database = await _loadSqliteDatabase(dbProvider);
      if (database != null) {
        print('AppointmentsProvider 回退到SQLite数据源设置成功');
        return AppointmentInitializationResult(
          database: database,
          mysqlConnection: null,
          dataSourceType: 'sqlite',
          initialized: true,
        );
      }

      throw Exception('所有数据库获取方式都失败');
    }

    final database = await _loadSqliteDatabase(dbProvider);
    if (database != null) {
      print('✅ AppointmentsProvider SQLite数据源设置成功');
      return AppointmentInitializationResult(
        database: database,
        mysqlConnection: null,
        dataSourceType: 'sqlite',
        initialized: true,
      );
    }

    throw Exception('所有数据库获取方式都失败');
  }

  Future<Database?> _loadSqliteDatabase(dynamic dbProvider) async {
    try {
      final database = await dbProvider.sqliteDatabase;
      return database;
    } catch (e) {
      print('获取SQLite数据库失败: $e');
      if (dbProvider.database != null) {
        return dbProvider.database;
      }
      return null;
    }
  }
}

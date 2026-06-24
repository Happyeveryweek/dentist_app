import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

import 'financial_connection_service.dart';
import 'financial_data_source_service.dart';
import '../../../utils/app_logger.dart';

/// 财务 Provider 初始化结果
class FinancialInitializationResult {
  final Database? database;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;
  final bool initialized;

  FinancialInitializationResult({
    required this.database,
    required this.mysqlConnection,
    required this.dataSourceType,
    required this.initialized,
  });
}

/// 财务初始化编排服务
/// 职责：把数据库提供者接入、数据源识别和连接同步从 Provider 中抽离出来
class FinancialInitializationService {
  Future<FinancialInitializationResult> initializeFromDatabase({
    required dynamic dbProvider,
    required FinancialDataSourceService dataSourceService,
    required FinancialConnectionService connectionService,
  }) async {
    connectionService.setDatabaseProvider(dbProvider);

    String dbType = 'sqlite';
    if (dbProvider.dbType != null) {
      dbType = dbProvider.dbType;
    } else if (dbProvider.dataSourceType != null) {
      dbType = dbProvider.dataSourceType;
    }

    AppLogger.info('检测到数据源类型: $dbType');

    if (dbType == 'mysql') {
      AppLogger.info('使用MySQL连接...');
      final mysqlConnection = dbProvider.mysqlConnection;
      if (mysqlConnection == null) {
        throw Exception('MySQL连接为null，无法创建数据源');
      }

      dataSourceService.setDataSourceType('mysql');
      connectionService.setDataSourceType('mysql');
      connectionService.setMysqlConnection(mysqlConnection);
      dataSourceService.setMySqlDataSource(mysqlConnection);
      AppLogger.info('✅ MySQL财务数据源创建成功');

      return FinancialInitializationResult(
        database: null,
        mysqlConnection: mysqlConnection,
        dataSourceType: 'mysql',
        initialized: true,
      );
    }

    AppLogger.info('使用SQLite连接...');
    Database? database;
    try {
      database = await dbProvider.sqliteDatabase;
      AppLogger.info('获取到的SQLite数据库实例: $database');
    } catch (e) {
      AppLogger.info('获取SQLite数据库失败: $e');
      if (dbProvider.database != null) {
        database = dbProvider.database;
        AppLogger.info('通过备用方式获取SQLite数据库: $database');
      }
    }

    if (database == null) {
      throw Exception('SQLite数据库为null，无法创建数据源');
    }

    dataSourceService.setDataSourceType('sqlite');
    connectionService.setDataSourceType('sqlite');
    dataSourceService.setSqliteDataSource(database);
    AppLogger.info('✅ SQLite财务数据源创建成功');

    return FinancialInitializationResult(
      database: database,
      mysqlConnection: null,
      dataSourceType: 'sqlite',
      initialized: true,
    );
  }
}

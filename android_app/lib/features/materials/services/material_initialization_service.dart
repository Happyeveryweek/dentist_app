import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

/// 材料 Provider 初始化结果
class MaterialInitializationResult {
  final Database? database;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;
  final bool initialized;

  MaterialInitializationResult({
    required this.database,
    required this.mysqlConnection,
    required this.dataSourceType,
    required this.initialized,
  });
}

/// 材料初始化编排服务
/// 职责：把数据库提供者接入、数据源识别和连接同步从 Provider 中抽离出来
class MaterialInitializationService {
  Future<MaterialInitializationResult> initializeFromDatabase({
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
      if (mysqlConnection == null) {
        throw Exception('MySQL连接为null，无法创建材料数据源');
      }

      print('✅ MaterialProvider MySQL 数据源设置成功');
      return MaterialInitializationResult(
        database: null,
        mysqlConnection: mysqlConnection,
        dataSourceType: 'mysql',
        initialized: true,
      );
    }

    Database? database;
    try {
      database = await dbProvider.sqliteDatabase;
      print('MaterialProvider SQLite 数据源设置成功: ${database != null ? "成功" : "失败"}');
    } catch (e) {
      print('获取SQLite数据库失败: $e');
      if (dbProvider.database != null) {
        database = dbProvider.database;
        print('通过备用方式获取SQLite数据库: ${database != null ? "成功" : "失败"}');
      }
    }

    if (database == null) {
      throw Exception('SQLite数据库为null，无法创建材料数据源');
    }

    return MaterialInitializationResult(
      database: database,
      mysqlConnection: null,
      dataSourceType: 'sqlite',
      initialized: true,
    );
  }
}

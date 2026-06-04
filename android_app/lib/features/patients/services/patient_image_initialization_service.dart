import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

/// 患者图片初始化结果
class PatientImageInitializationResult {
  final String dataSourceType;
  final Database? sqliteDatabase;
  final MySqlConnection? mysqlConnection;
  final bool initialized;

  const PatientImageInitializationResult({
    required this.dataSourceType,
    required this.sqliteDatabase,
    required this.mysqlConnection,
    required this.initialized,
  });
}

/// 患者图片初始化服务
/// 职责：识别数据源类型、获取 SQLite/MySQL 连接、返回初始化结果
class PatientImageInitializationService {
  Future<PatientImageInitializationResult> initialize(dynamic dbProvider) async {
    print('PatientImageInitializationService开始初始化...');

    String dbType = 'sqlite';
    if (dbProvider.dbType != null) {
      dbType = dbProvider.dbType;
    } else if (dbProvider.dataSourceType != null) {
      dbType = dbProvider.dataSourceType;
    }

    print('检测到数据源类型: $dbType');

    if (dbType == 'mysql') {
      final mysqlConnection = dbProvider.mysqlConnection;
      if (mysqlConnection != null) {
        print('PatientImageInitializationService MySQL数据源设置成功');
        return PatientImageInitializationResult(
          dataSourceType: 'mysql',
          sqliteDatabase: null,
          mysqlConnection: mysqlConnection,
          initialized: true,
        );
      }

      print('警告：MySQL连接为null，尝试SQLite');
      final database = await dbProvider.sqliteDatabase;
      if (database != null) {
        print('PatientImageInitializationService 回退到SQLite数据源设置成功');
        return PatientImageInitializationResult(
          dataSourceType: 'sqlite',
          sqliteDatabase: database,
          mysqlConnection: null,
          initialized: true,
        );
      }

      print('警告：SQLite数据库实例为null，延迟初始化...');
      return const PatientImageInitializationResult(
        dataSourceType: 'sqlite',
        sqliteDatabase: null,
        mysqlConnection: null,
        initialized: false,
      );
    }

    try {
      final database = await dbProvider.sqliteDatabase;
      if (database != null) {
        print('PatientImageInitializationService SQLite数据源设置成功');
        return PatientImageInitializationResult(
          dataSourceType: 'sqlite',
          sqliteDatabase: database,
          mysqlConnection: null,
          initialized: true,
        );
      }

      print('警告：SQLite数据库实例为null，延迟初始化...');
      if (dbProvider.database != null) {
        print('通过备用方式获取SQLite数据库: 成功');
        return PatientImageInitializationResult(
          dataSourceType: 'sqlite',
          sqliteDatabase: dbProvider.database,
          mysqlConnection: null,
          initialized: true,
        );
      }

      print('警告：所有数据库获取方式都失败');
      return const PatientImageInitializationResult(
        dataSourceType: 'sqlite',
        sqliteDatabase: null,
        mysqlConnection: null,
        initialized: false,
      );
    } catch (e) {
      print('获取SQLite数据库失败: $e');
      if (dbProvider.database != null) {
        print('通过备用方式获取SQLite数据库: 成功');
        return PatientImageInitializationResult(
          dataSourceType: 'sqlite',
          sqliteDatabase: dbProvider.database,
          mysqlConnection: null,
          initialized: true,
        );
      }

      print('警告：所有数据库获取方式都失败');
      return const PatientImageInitializationResult(
        dataSourceType: 'sqlite',
        sqliteDatabase: null,
        mysqlConnection: null,
        initialized: false,
      );
    }
  }
}

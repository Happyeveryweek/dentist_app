import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

/// 病历 Provider 初始化结果
class MedicalRecordInitializationResult {
  final Database? database;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;
  final bool initialized;

  MedicalRecordInitializationResult({
    required this.database,
    required this.mysqlConnection,
    required this.dataSourceType,
    required this.initialized,
  });
}

/// 病历初始化编排服务
/// 职责：把数据库提供者接入、数据源识别和连接同步从 Provider 中抽离出来
class MedicalRecordInitializationService {
  Future<MedicalRecordInitializationResult> initializeFromDatabase({
    required dynamic dbProvider,
  }) async {
    String dataSourceType = 'sqlite';
    if (dbProvider.dbType != null) {
      dataSourceType = dbProvider.dbType;
    } else if (dbProvider.dataSourceType != null) {
      dataSourceType = dbProvider.dataSourceType;
    }

    if (dataSourceType == 'mysql') {
      final mysqlConnection = dbProvider.mysqlConnection;
      if (mysqlConnection == null) {
        throw Exception('MySQL连接为null，无法创建数据源');
      }

      print('✅ MedicalRecordProvider MySQL数据源设置成功');
      return MedicalRecordInitializationResult(
        database: null,
        mysqlConnection: mysqlConnection,
        dataSourceType: 'mysql',
        initialized: true,
      );
    }

    Database? database;
    try {
      database = await dbProvider.sqliteDatabase;
      print('✅ MedicalRecordProvider SQLite数据源设置成功');
    } catch (e) {
      print('获取SQLite数据库失败: $e');
      if (dbProvider.database != null) {
        database = dbProvider.database;
        print('通过备用方式获取SQLite数据库: ${database != null ? "成功" : "失败"}');
      }
    }

    if (database == null) {
      throw Exception('SQLite数据库为null，无法创建数据源');
    }

    return MedicalRecordInitializationResult(
      database: database,
      mysqlConnection: null,
      dataSourceType: 'sqlite',
      initialized: true,
    );
  }
}

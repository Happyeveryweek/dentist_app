import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../models/schemas/table_schema.dart';

/// 数据库表结构服务
/// 职责：表结构创建、升级、表名获取
class DatabaseSchemaService {
  final Database? sqliteDatabase;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;

  DatabaseSchemaService({
    this.sqliteDatabase,
    this.mysqlConnection,
    required this.dataSourceType,
  });

  /// 创建 SQLite 数据库表
  Future<void> createSQLiteTables(Database db, int version) async {
    print('使用新的分离式架构创建 SQLite 数据库表...');
    
    try {
      final tableNames = [
        'patients',
        'appointments',
        'financial_records',
        'financial_items',
        'materials',
        'material_images',
        'patient_materials',
        'purchase_records',
        'purchase_items',
        'users',
        'database_structure_logs',
        'patient_medical_records',
        'medical_record_templates',
      ];

      for (final tableName in tableNames) {
        try {
          final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
          
          // 创建表
          await db.execute(schema.createTableSql);
          print('成功创建表: $tableName');
          
          // 创建索引（如果有的话）
          for (final indexSql in schema.indexDefinitions) {
            if (!indexSql.contains('PRIMARY KEY')) {
              await db.execute(indexSql);
              print('成功创建索引: $tableName - ${indexSql.substring(0, 50)}...');
            }
          }
        } catch (e) {
          print('创建表 $tableName 时出错: $e');
        }
      }
      
      print('SQLite 数据库表创建完成');
    } catch (e) {
      print('使用新架构创建数据库表时出错: $e');
      rethrow;
    }
  }

  /// 创建 MySQL 数据库表
  Future<void> createMySQLTables() async {
    if (mysqlConnection == null) {
      print('MySQL 连接未建立，无法创建表');
      return;
    }
    
    print('使用新的分离式架构创建 MySQL 数据库表...');
    
    try {
      final tableNames = [
        'patients',
        'appointments',
        'financial_records',
        'financial_items',
        'materials',
        'material_images',
        'patient_materials',
        'purchase_records',
        'purchase_items',
        'users',
        'database_structure_logs',
        'patient_medical_records',
        'medical_record_templates',
      ];

      for (final tableName in tableNames) {
        try {
          final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
          
          // 创建表
          await mysqlConnection!.query(schema.createTableSql);
          print('成功创建 MySQL 表: $tableName');
          
          // 创建索引（如果有的话）
          for (final indexSql in schema.indexDefinitions) {
            if (!indexSql.contains('PRIMARY KEY')) {
              try {
                // 提取索引名称
                final indexNameMatch = RegExp(r'CREATE (?:UNIQUE )?INDEX (\w+)').firstMatch(indexSql);
                final indexName = indexNameMatch?.group(1) ?? 'unknown';
                
                // 检查索引是否已存在
                final checkResult = await mysqlConnection!.query(
                  "SELECT COUNT(*) as count FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?",
                  [tableName, indexName]
                );
                
                final indexExists = checkResult.first['count'] > 0;
                
                if (!indexExists) {
                  await mysqlConnection!.query(indexSql);
                  final displayText = indexSql.length > 50 ? '${indexSql.substring(0, 50)}...' : indexSql;
                  print('成功创建 MySQL 索引: $tableName - $displayText');
                } else {
                  final displayText = indexSql.length > 50 ? '${indexSql.substring(0, 50)}...' : indexSql;
                  print('MySQL 索引已存在，跳过创建: $tableName - $displayText');
                }
              } catch (e) {
                final displayText = indexSql.length > 50 ? '${indexSql.substring(0, 50)}...' : indexSql;
                print('创建 MySQL 索引失败: $tableName - $displayText 错误: $e');
              }
            }
          }
        } catch (e) {
          print('创建 MySQL 表 $tableName 时出错: $e');
        }
      }
      
      print('MySQL 数据库表创建完成');
    } catch (e) {
      print('使用新架构创建 MySQL 数据库表时出错: $e');
      rethrow;
    }
  }

  /// 数据库升级
  Future<void> upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('数据库升级: 从 v$oldVersion 到 v$newVersion');

    if (oldVersion < newVersion) {
      print('执行数据库升级操作...');

      // 随访表已移除

      // 财务和材料采购表由相应的 Provider 负责创建
      if (oldVersion < 2) {
        print('财务和材料采购表由 FinancialProvider 和 MaterialProvider 负责创建...');
      }
      
      // 版本3：材料表升级由 MaterialProvider 负责
      if (oldVersion < 3) {
        print('版本3材料表升级由 MaterialProvider 负责...');
      }
    }
  }

  /// 获取数据库表名
  Future<List<String>> getTableNames() async {
    if (dataSourceType == 'sqlite') {
      if (sqliteDatabase == null) {
        return [];
      }
      
      final result = await sqliteDatabase!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      return result.map((table) => table['name'] as String).toList();
    } else {
      if (mysqlConnection == null) {
        return [];
      }
      
      // MySQL 获取表名
      final result = await mysqlConnection!.query('SHOW TABLES');
      List<String> tableNames = [];
      for (var row in result) {
        if (row.fields.isNotEmpty &&
            row.values != null &&
            row.values!.isNotEmpty) {
          var value = row.values!.first;
          tableNames.add(value?.toString() ?? '');
        }
      }
      return tableNames;
    }
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../models/schemas/table_schema.dart';
import '../utils/log_manager.dart';

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
          final schema =
              TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);

          // 创建表
          await db.execute(schema.createTableSql);

          // 创建索引（如果有的话）
          for (final indexSql in schema.indexDefinitions) {
            if (!indexSql.contains('PRIMARY KEY')) {
              await db.execute(indexSql);
              LogManager.i('DatabaseSchemaService',
                  '成功创建索引: $tableName - ${indexSql.substring(0, 50)}...');
            }
          }
        } catch (e) {
          LogManager.e('DatabaseSchemaService', '创建表 $tableName 时出错', error: e);
        }
      }
    } catch (e) {
      LogManager.e('DatabaseSchemaService', '使用新架构创建数据库表时出错', error: e);
      rethrow;
    }
  }

  /// 创建 MySQL 数据库表
  Future<void> createMySQLTables() async {
    final connection = mysqlConnection;
    if (connection == null) {
      LogManager.w('DatabaseSchemaService', 'MySQL 连接未建立，无法创建表');
      return;
    }

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
          final schema =
              TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);

          // 创建表
          await connection.query(schema.createTableSql);
          LogManager.i('DatabaseSchemaService', '成功创建 MySQL 表: $tableName');

          // 创建索引（如果有的话）
          for (final indexSql in schema.indexDefinitions) {
            if (!indexSql.contains('PRIMARY KEY')) {
              try {
                // 提取索引名称
                final indexNameMatch = RegExp(r'CREATE (?:UNIQUE )?INDEX (\w+)')
                    .firstMatch(indexSql);
                final indexName = indexNameMatch?.group(1) ?? 'unknown';

                // 检查索引是否已存在
                final checkResult = await connection.query(
                    "SELECT COUNT(*) as count FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?",
                    [tableName, indexName]);

                final indexExists = checkResult.first['count'] > 0;

                if (!indexExists) {
                  await connection.query(indexSql);
                  final displayText = indexSql.length > 50
                      ? '${indexSql.substring(0, 50)}...'
                      : indexSql;
                  LogManager.i('DatabaseSchemaService',
                      '成功创建 MySQL 索引: $tableName - $displayText');
                } else {
                  final displayText = indexSql.length > 50
                      ? '${indexSql.substring(0, 50)}...'
                      : indexSql;
                  LogManager.w('DatabaseSchemaService',
                      'MySQL 索引已存在，跳过创建: $tableName - $displayText');
                }
              } catch (e) {
                final displayText = indexSql.length > 50
                    ? '${indexSql.substring(0, 50)}...'
                    : indexSql;
                LogManager.e('DatabaseSchemaService',
                    '创建 MySQL 索引失败: $tableName - $displayText 错误',
                    error: e);
              }
            }
          }
        } catch (e) {
          LogManager.e('DatabaseSchemaService', '创建 MySQL 表 $tableName 时出错',
              error: e);
        }
      }
    } catch (e) {
      LogManager.e('DatabaseSchemaService', '使用新架构创建 MySQL 数据库表时出错', error: e);
      rethrow;
    }
  }

  /// 数据库升级
  Future<void> upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    LogManager.w(
        'DatabaseSchemaService', '数据库升级: 从 v$oldVersion 到 v$newVersion');

    if (oldVersion < newVersion) {
      // 随访表已移除

      // 财务和材料采购表由相应的 Provider 负责创建
      if (oldVersion < 2) {
        LogManager.w('DatabaseSchemaService',
            '财务和材料采购表由 FinancialProvider 和 MaterialProvider 负责创建...');
      }

      // 版本3：材料表升级由 MaterialProvider 负责
      if (oldVersion < 3) {
        LogManager.w(
            'DatabaseSchemaService', '版本3材料表升级由 MaterialProvider 负责...');
      }
    }
  }

  /// 获取数据库表名
  Future<List<String>> getTableNames() async {
    if (dataSourceType == 'sqlite') {
      final db = sqliteDatabase;
      if (db == null) {
        return [];
      }

      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      return result.map((table) => table['name'] as String).toList();
    } else {
      final connection = mysqlConnection;
      if (connection == null) {
        return [];
      }

      // MySQL 获取表名
      final result = await connection.query('SHOW TABLES');
      List<String> tableNames = [];
      for (var row in result) {
        final values = row.values;
        if (row.fields.isNotEmpty &&
            values != null &&
            values.isNotEmpty) {
          var value = values.first;
          tableNames.add(value?.toString() ?? '');
        }
      }
      return tableNames;
    }
  }
}

import 'package:mysql1/mysql1.dart';
import '../models/schemas/table_schema.dart';
import '../utils/log_manager.dart';

/// 数据库表结构服务
/// 职责：表结构创建、升级、表名获取
class DatabaseSchemaService {
  final MySqlConnection? mysqlConnection;

  DatabaseSchemaService({
    this.mysqlConnection,
  });

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
}

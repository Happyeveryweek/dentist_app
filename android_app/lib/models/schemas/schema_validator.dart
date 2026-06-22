import 'table_schema.dart';
import 'mysql_schema.dart';
import 'sqlite_schema.dart';

/// 数据库表结构验证器
class SchemaValidator {
  /// 验证MySQL和SQLite表结构的一致性
  static Map<String, List<String>> validateSchemas() {
    final Map<String, List<String>> validationResults = {};
    
    // 获取所有表名
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
    ];

    for (final tableName in tableNames) {
      final mysqlSchema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
      final sqliteSchema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
      
      final issues = _compareSchemas(mysqlSchema, sqliteSchema);
      if (issues.isNotEmpty) {
        validationResults[tableName] = issues;
      }
    }

    return validationResults;
  }

  /// 比较两个表结构的差异
  static List<String> _compareSchemas(TableSchema mysqlSchema, TableSchema sqliteSchema) {
    final List<String> issues = [];
    
    // 验证表名一致性
    if (mysqlSchema.tableName != sqliteSchema.tableName) {
      issues.add('表名不一致: MySQL=${mysqlSchema.tableName}, SQLite=${sqliteSchema.tableName}');
    }

    // 验证索引数量一致性
    if (mysqlSchema.indexDefinitions.length != sqliteSchema.indexDefinitions.length) {
      issues.add('索引数量不一致: MySQL=${mysqlSchema.indexDefinitions.length}, SQLite=${sqliteSchema.indexDefinitions.length}');
    }

    return issues;
  }

  /// 生成表结构报告
  static String generateSchemaReport() {
    final validationResults = validateSchemas();
    final StringBuffer report = StringBuffer();
    
    report.writeln('=== 数据库表结构验证报告 ===');
    report.writeln('生成时间: ${DateTime.now()}');
    report.writeln('');
    
    if (validationResults.isEmpty) {
      report.writeln('✅ 所有表结构验证通过！');
    } else {
      report.writeln('❌ 发现以下表结构问题:');
      report.writeln('');
      
      validationResults.forEach((tableName, issues) {
        report.writeln('📋 表: $tableName');
        for (final issue in issues) {
          report.writeln('   ⚠️  $issue');
        }
        report.writeln('');
      });
    }
    
    return report.toString();
  }

  /// 获取MySQL表结构SQL
  static String getMySQLCreateTableSQL(String tableName) {
    final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
    return schema.createTableSql;
  }

  /// 获取SQLite表结构SQL
  static String getSQLiteCreateTableSQL(String tableName) {
    final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
    return schema.createTableSql;
  }

  /// 获取表的所有索引SQL
  static List<String> getTableIndexes(String tableName, DatabaseType databaseType) {
    final schema = TableSchemaFactory.getSchema(tableName, databaseType);
    return schema.indexDefinitions;
  }

  /// 检查表是否存在
  static bool tableExists(String tableName) {
    try {
      TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取所有支持的表名
  static List<String> getAllTableNames() {
    return [
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
    ];
  }
}

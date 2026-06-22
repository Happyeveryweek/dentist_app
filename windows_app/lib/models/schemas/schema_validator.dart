import 'table_schema.dart';
import 'mysql_schema.dart';
import 'sqlite_schema.dart';

/// Windows端表结构验证器
class SchemaValidator {
  /// 验证MySQL和SQLite表结构的一致性
  static Map<String, dynamic> validateSchemas() {
    final results = <String, dynamic>{};
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
    ];

    for (final tableName in tableNames) {
      try {
        final mysqlSchema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
        final sqliteSchema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
        
        results[tableName] = _compareSchemas(mysqlSchema, sqliteSchema);
      } catch (e) {
        results[tableName] = {
          'error': e.toString(),
          'status': 'error',
        };
      }
    }

    return results;
  }

  /// 比较两个表结构
  static Map<String, dynamic> _compareSchemas(
    TableSchema mysqlSchema,
    TableSchema sqliteSchema,
  ) {
    final mysqlColumns = mysqlSchema.columnDefinitions;
    final sqliteColumns = sqliteSchema.columnDefinitions;
    
    final differences = <String, dynamic>{};
    final mysqlOnly = <String>[];
    final sqliteOnly = <String>[];
    final typeMismatches = <String, Map<String, String>>{};

    // 检查MySQL独有的字段
    for (final column in mysqlColumns.keys) {
      if (!sqliteColumns.containsKey(column)) {
        mysqlOnly.add(column);
      }
    }

    // 检查SQLite独有的字段
    for (final column in sqliteColumns.keys) {
      if (!mysqlColumns.containsKey(column)) {
        sqliteOnly.add(column);
      }
    }

    // 检查类型不匹配的字段
    for (final column in mysqlColumns.keys) {
      if (sqliteColumns.containsKey(column)) {
        final mysqlType = mysqlColumns[column]!;
        final sqliteType = sqliteColumns[column]!;
        
        if (!_isTypeCompatible(mysqlType, sqliteType)) {
          typeMismatches[column] = {
            'mysql': mysqlType,
            'sqlite': sqliteType,
          };
        }
      }
    }

    differences['mysql_only_columns'] = mysqlOnly;
    differences['sqlite_only_columns'] = sqliteOnly;
    differences['type_mismatches'] = typeMismatches;
    differences['mysql_column_count'] = mysqlColumns.length;
    differences['sqlite_column_count'] = sqliteColumns.length;
    differences['status'] = mysqlOnly.isEmpty && sqliteOnly.isEmpty && typeMismatches.isEmpty 
        ? 'consistent' 
        : 'inconsistent';

    return differences;
  }

  /// 检查类型兼容性
  static bool _isTypeCompatible(String mysqlType, String sqliteType) {
    // 简化的类型兼容性检查
    final mysqlLower = mysqlType.toLowerCase();
    final sqliteLower = sqliteType.toLowerCase();

    // 整数类型兼容性
    if (mysqlLower.contains('int') && sqliteLower.contains('integer')) {
      return true;
    }

    // 字符串类型兼容性
    if ((mysqlLower.contains('varchar') || mysqlLower.contains('text') || mysqlLower.contains('char')) &&
        (sqliteLower.contains('text') || sqliteLower.contains('varchar'))) {
      return true;
    }

    // 浮点数类型兼容性
    if ((mysqlLower.contains('float') || mysqlLower.contains('double') || mysqlLower.contains('decimal')) &&
        sqliteLower.contains('real')) {
      return true;
    }

    // 日期时间类型兼容性
    if ((mysqlLower.contains('datetime') || mysqlLower.contains('date') || mysqlLower.contains('time')) &&
        (sqliteLower.contains('text') || sqliteLower.contains('datetime'))) {
      return true;
    }

    // BLOB类型兼容性
    if (mysqlLower.contains('blob') && sqliteLower.contains('blob')) {
      return true;
    }

    return false;
  }

  /// 生成表结构报告
  static String generateSchemaReport() {
    final validationResults = validateSchemas();
    final buffer = StringBuffer();
    
    buffer.writeln('=== Windows端数据库表结构验证报告 ===\n');
    
    for (final entry in validationResults.entries) {
      final tableName = entry.key;
      final result = entry.value;
      
      buffer.writeln('表名: $tableName');
      
      if (result['error'] != null) {
        buffer.writeln('  状态: 错误 - ${result['error']}');
      } else {
        buffer.writeln('  状态: ${result['status']}');
        buffer.writeln('  MySQL字段数: ${result['mysql_column_count']}');
        buffer.writeln('  SQLite字段数: ${result['sqlite_column_count']}');
        
        if (result['mysql_only_columns'].isNotEmpty) {
          buffer.writeln('  MySQL独有字段: ${result['mysql_only_columns'].join(', ')}');
        }
        
        if (result['sqlite_only_columns'].isNotEmpty) {
          buffer.writeln('  SQLite独有字段: ${result['sqlite_only_columns'].join(', ')}');
        }
        
        if (result['type_mismatches'].isNotEmpty) {
          buffer.writeln('  类型不匹配:');
          for (final mismatch in result['type_mismatches'].entries) {
            buffer.writeln('    ${mismatch.key}: MySQL(${mismatch.value['mysql']}) vs SQLite(${mismatch.value['sqlite']})');
          }
        }
      }
      
      buffer.writeln();
    }
    
    return buffer.toString();
  }

  /// 获取MySQL建表SQL
  static String getMySQLCreateTableSQL(String tableName) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
      return schema.createTableSql;
    } catch (e) {
      return '错误: $e';
    }
  }

  /// 获取SQLite建表SQL
  static String getSQLiteCreateTableSQL(String tableName) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
      return schema.createTableSql;
    } catch (e) {
      return '错误: $e';
    }
  }

  /// 获取表的所有索引
  static List<String> getTableIndexes(String tableName, DatabaseType databaseType) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, databaseType);
      return schema.indexDefinitions;
    } catch (e) {
      return ['错误: $e'];
    }
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

  /// 获取所有表名
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
      'database_structure_logs',
    ];
  }
}

import 'table_schema.dart';
import 'mysql_schema.dart';
import 'sqlite_schema.dart';

/// Windows端数据库初始化工具
class DatabaseInitializer {
  /// 根据数据源类型初始化数据库表结构
  static List<String> initializeTables(DatabaseType databaseType) {
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

    final createTableStatements = <String>[];
    final createIndexStatements = <String>[];

    for (final tableName in tableNames) {
      try {
        final schema = TableSchemaFactory.getSchema(tableName, databaseType);
        
        // 添加建表语句
        createTableStatements.add(schema.createTableSql);
        
        // 添加索引创建语句（如果有的话）
        for (final indexSql in schema.indexDefinitions) {
          if (!indexSql.contains('PRIMARY KEY')) {
            createIndexStatements.add(indexSql);
          }
        }
      } catch (e) {
        print('初始化表 $tableName 时出错: $e');
      }
    }

    // 合并所有SQL语句
    final allStatements = <String>[];
    allStatements.addAll(createTableStatements);
    allStatements.addAll(createIndexStatements);

    return allStatements;
  }

  /// 获取MySQL数据库初始化SQL
  static List<String> getMySQLInitializationSQL() {
    return initializeTables(DatabaseType.mysql);
  }

  /// 获取SQLite数据库初始化SQL
  static List<String> getSQLiteInitializationSQL() {
    return initializeTables(DatabaseType.sqlite);
  }

  /// 获取特定表的建表SQL
  static String getTableCreationSQL(String tableName, DatabaseType databaseType) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, databaseType);
      return schema.createTableSql;
    } catch (e) {
      return '错误: 无法获取表 $tableName 的建表SQL - $e';
    }
  }

  /// 获取特定表的所有索引SQL
  static List<String> getTableIndexSQL(String tableName, DatabaseType databaseType) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, databaseType);
      return schema.indexDefinitions
          .where((index) => !index.contains('PRIMARY KEY'))
          .map((index) => 'CREATE INDEX IF NOT EXISTS idx_${tableName}_${index.split('(')[1].split(')')[0]} ON $tableName ($index)')
          .toList();
    } catch (e) {
      return ['错误: 无法获取表 $tableName 的索引SQL - $e'];
    }
  }

  /// 获取数据库类型描述
  static String getDatabaseTypeDescription(DatabaseType databaseType) {
    switch (databaseType) {
      case DatabaseType.mysql:
        return 'MySQL';
      case DatabaseType.sqlite:
        return 'SQLite';
      default:
        return '未知';
    }
  }

  /// 验证表结构完整性
  static Map<String, dynamic> validateTableStructure(DatabaseType databaseType) {
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
        final schema = TableSchemaFactory.getSchema(tableName, databaseType);
        
        results[tableName] = {
          'status': 'valid',
          'column_count': schema.columnDefinitions.length,
          'index_count': schema.indexDefinitions.length,
          'foreign_key_count': schema.foreignKeyConstraints.length,
          'has_primary_key': schema.indexDefinitions.any((index) => index.contains('PRIMARY KEY')),
        };
      } catch (e) {
        results[tableName] = {
          'status': 'error',
          'error': e.toString(),
        };
      }
    }

    return results;
  }

  /// 生成数据库初始化报告
  static String generateInitializationReport(DatabaseType databaseType) {
    final validationResults = validateTableStructure(databaseType);
    final buffer = StringBuffer();
    
    buffer.writeln('=== Windows端 ${getDatabaseTypeDescription(databaseType)} 数据库初始化报告 ===\n');
    
    int validTables = 0;
    int errorTables = 0;
    
    for (final entry in validationResults.entries) {
      final tableName = entry.key;
      final result = entry.value;
      
      buffer.writeln('表名: $tableName');
      
      if (result['status'] == 'valid') {
        validTables++;
        buffer.writeln('  状态: 有效');
        buffer.writeln('  字段数: ${result['column_count']}');
        buffer.writeln('  索引数: ${result['index_count']}');
        buffer.writeln('  外键数: ${result['foreign_key_count']}');
        buffer.writeln('  主键: ${result['has_primary_key'] ? '是' : '否'}');
      } else {
        errorTables++;
        buffer.writeln('  状态: 错误 - ${result['error']}');
      }
      
      buffer.writeln();
    }
    
    buffer.writeln('=== 总结 ===');
    buffer.writeln('有效表数: $validTables');
    buffer.writeln('错误表数: $errorTables');
    buffer.writeln('总计: ${validationResults.length}');
    
    return buffer.toString();
  }

  /// 获取所有支持的数据库类型
  static List<DatabaseType> getSupportedDatabaseTypes() {
    return DatabaseType.values;
  }

  /// 检查数据库类型是否支持
  static bool isDatabaseTypeSupported(DatabaseType databaseType) {
    return getSupportedDatabaseTypes().contains(databaseType);
  }
}

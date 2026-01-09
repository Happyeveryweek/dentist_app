import 'table_schema.dart';
import 'mysql_schema.dart';
import 'sqlite_schema.dart';
import 'schema_validator.dart';
import 'database_initializer.dart';

/// Windows端分离式架构使用示例
class ExampleUsage {
  /// 演示如何使用表结构工厂
  static void demonstrateTableSchemaFactory() {
    print('=== 表结构工厂使用示例 ===\n');

    // 获取MySQL患者表结构
    try {
      final mysqlPatientsSchema = TableSchemaFactory.getSchema('patients', DatabaseType.mysql);
      print('MySQL患者表结构:');
      print('表名: ${mysqlPatientsSchema.tableName}');
      print('字段数: ${mysqlPatientsSchema.columnDefinitions.length}');
      print('索引数: ${mysqlPatientsSchema.indexDefinitions.length}');
      print('外键数: ${mysqlPatientsSchema.foreignKeyConstraints.length}');
      print();
    } catch (e) {
      print('获取MySQL患者表结构失败: $e');
    }

    // 获取SQLite患者表结构
    try {
      final sqlitePatientsSchema = TableSchemaFactory.getSchema('patients', DatabaseType.sqlite);
      print('SQLite患者表结构:');
      print('表名: ${sqlitePatientsSchema.tableName}');
      print('字段数: ${sqlitePatientsSchema.columnDefinitions.length}');
      print('索引数: ${sqlitePatientsSchema.indexDefinitions.length}');
      print('外键数: ${sqlitePatientsSchema.foreignKeyConstraints.length}');
      print();
    } catch (e) {
      print('获取SQLite患者表结构失败: $e');
    }
  }

  /// 演示如何生成建表SQL
  static void demonstrateCreateTableSQL() {
    print('=== 建表SQL生成示例 ===\n');

    // 生成MySQL预约表SQL
    try {
      final mysqlAppointmentsSchema = TableSchemaFactory.getSchema('appointments', DatabaseType.mysql);
      print('MySQL预约表建表SQL:');
      print(mysqlAppointmentsSchema.createTableSql);
      print();
    } catch (e) {
      print('生成MySQL预约表SQL失败: $e');
    }

    // 生成SQLite预约表SQL
    try {
      final sqliteAppointmentsSchema = TableSchemaFactory.getSchema('appointments', DatabaseType.sqlite);
      print('SQLite预约表建表SQL:');
      print(sqliteAppointmentsSchema.createTableSql);
      print();
    } catch (e) {
      print('生成SQLite预约表SQL失败: $e');
    }
  }

  /// 演示如何使用表结构验证器
  static void demonstrateSchemaValidator() {
    print('=== 表结构验证示例 ===\n');

    // 验证所有表结构
    final validationResults = SchemaValidator.validateSchemas();
    
    for (final entry in validationResults.entries) {
      final tableName = entry.key;
      final result = entry.value;
      
      print('表: $tableName');
      if (result['error'] != null) {
        print('  错误: ${result['error']}');
      } else {
        print('  状态: ${result['status']}');
        print('  MySQL字段数: ${result['mysql_column_count']}');
        print('  SQLite字段数: ${result['sqlite_column_count']}');
        
        if (result['mysql_only_columns'].isNotEmpty) {
          print('  MySQL独有字段: ${result['mysql_only_columns'].join(', ')}');
        }
        
        if (result['sqlite_only_columns'].isNotEmpty) {
          print('  SQLite独有字段: ${result['sqlite_only_columns'].join(', ')}');
        }
      }
      print();
    }
  }

  /// 演示如何使用数据库初始化工具
  static void demonstrateDatabaseInitializer() {
    print('=== 数据库初始化示例 ===\n');

    // 获取MySQL初始化SQL
    try {
      final mysqlSQL = DatabaseInitializer.getMySQLInitializationSQL();
      print('MySQL初始化SQL数量: ${mysqlSQL.length}');
      print('前3个SQL语句:');
      for (int i = 0; i < 3 && i < mysqlSQL.length; i++) {
        print('${i + 1}. ${mysqlSQL[i].substring(0, 50)}...');
      }
      print();
    } catch (e) {
      print('获取MySQL初始化SQL失败: $e');
    }

    // 获取SQLite初始化SQL
    try {
      final sqliteSQL = DatabaseInitializer.getSQLiteInitializationSQL();
      print('SQLite初始化SQL数量: ${sqliteSQL.length}');
      print('前3个SQL语句:');
      for (int i = 0; i < 3 && i < sqliteSQL.length; i++) {
        print('${i + 1}. ${sqliteSQL[i].substring(0, 50)}...');
      }
      print();
    } catch (e) {
      print('获取SQLite初始化SQL失败: $e');
    }
  }

  /// 演示如何获取特定表的详细信息
  static void demonstrateTableDetails() {
    print('=== 表详细信息示例 ===\n');

    final tableNames = ['patients', 'appointments', 'financial_records'];
    
    for (final tableName in tableNames) {
      print('表: $tableName');
      
      // MySQL表信息
      try {
        final mysqlSchema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
        print('  MySQL:');
        print('    字段: ${mysqlSchema.columnDefinitions.keys.join(', ')}');
        print('    索引: ${mysqlSchema.indexDefinitions.join(', ')}');
      } catch (e) {
        print('    错误: $e');
      }
      
      // SQLite表信息
      try {
        final sqliteSchema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
        print('  SQLite:');
        print('    字段: ${sqliteSchema.columnDefinitions.keys.join(', ')}');
        print('    索引: ${sqliteSchema.indexDefinitions.join(', ')}');
      } catch (e) {
        print('    错误: $e');
      }
      
      print();
    }
  }

  /// 运行所有示例
  static void runAllExamples() {
    print('开始运行Windows端分离式架构示例...\n');
    
    demonstrateTableSchemaFactory();
    demonstrateCreateTableSQL();
    demonstrateSchemaValidator();
    demonstrateDatabaseInitializer();
    demonstrateTableDetails();
    
    print('所有示例运行完成！');
  }
}

/// 主函数，用于测试
void main() {
  ExampleUsage.runAllExamples();
}

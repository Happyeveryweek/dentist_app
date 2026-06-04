import '../../../models/schemas/table_schema.dart';
import '../../../models/schemas/mysql_schema.dart';
import '../../../models/schemas/sqlite_schema.dart';

/// 表结构适配器 - 将 schemas 中的定义转换为 SettingsProvider 期望的格式
class TableDefinitionsAdapter {
  /// 获取所有系统表名列表（从schemas动态获取）
  static List<String> getAllSystemTableNames() {
    final allTables = [
      'users', 'patients', 'materials', 'appointments', 'patient_materials',
      'financial_records', 'financial_items', 'purchase_records', 'purchase_items',
      'material_images', 'patient_medical_records', 'medical_record_templates',
      'database_structure_logs'
    ];
    
    // 验证所有表名都在schemas中有定义
    final validTables = <String>[];
    for (final tableName in allTables) {
      if (isTableDefinedInSchemas(tableName, DatabaseType.sqlite) && 
          isTableDefinedInSchemas(tableName, DatabaseType.mysql)) {
        validTables.add(tableName);
      } else {
        print('⚠️ 表 $tableName 在schemas中定义不完整，跳过');
      }
    }
    
    return validTables;
  }
  
  /// 验证表名是否在schemas中定义
  static bool isTableDefinedInSchemas(String tableName, DatabaseType databaseType) {
    try {
      TableSchemaFactory.getSchema(tableName, databaseType);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 从 schemas 获取 MySQL 表结构定义
  static Map<String, Map<String, String>> getMySQLTableDefinitions() {
    final Map<String, Map<String, String>> result = {};
    final tableNames = getAllSystemTableNames();
    
    for (final tableName in tableNames) {
      try {
        final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
        result[tableName] = schema.columnDefinitions;
      } catch (e) {
        print('获取 MySQL 表 $tableName 定义失败: $e');
      }
    }
    
    return result;
  }
  
  /// 从 schemas 获取 SQLite 表结构定义
  static Map<String, Map<String, String>> getSQLiteTableDefinitions() {
    final Map<String, Map<String, String>> result = {};
    final tableNames = getAllSystemTableNames();
    
    for (final tableName in tableNames) {
      try {
        final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
        result[tableName] = schema.columnDefinitions;
      } catch (e) {
        print('获取 SQLite 表 $tableName 定义失败: $e');
      }
    }
    
    return result;
  }
  
  /// 生成MySQL的CREATE TABLE语句
  static String generateMySQLCreateTable(String tableName, Map<String, String> columns) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
      return schema.createTableSql;
    } catch (e) {
      print('生成 MySQL 表 $tableName 的 CREATE TABLE 语句失败: $e');
      // 回退到旧的实现
      return _fallbackGenerateMySQLCreateTable(tableName, columns);
    }
  }
  
  /// 生成SQLite的CREATE TABLE语句
  static String generateSQLiteCreateTable(String tableName, Map<String, String> columns) {
    try {
      final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
      return schema.createTableSql;
    } catch (e) {
      print('生成 SQLite 表 $tableName 的 CREATE TABLE 语句失败: $e');
      // 回退到旧的实现
      return _fallbackGenerateSQLiteCreateTable(tableName, columns);
    }
  }
  
  /// 回退的 MySQL CREATE TABLE 生成方法
  static String _fallbackGenerateMySQLCreateTable(String tableName, Map<String, String> columns) {
    final mysqlColumns = <String>[];
    
    for (final entry in columns.entries) {
      final columnName = entry.key;
      final columnDef = entry.value;
      
      mysqlColumns.add('`$columnName` $columnDef');
    }
    
    // 为特定表添加索引和外键约束
    if (tableName == 'financial_items') {
      mysqlColumns.add('KEY `financial_record_id` (`financial_record_id`)');
      mysqlColumns.add('CONSTRAINT `financial_items_ibfk_1` FOREIGN KEY (`financial_record_id`) REFERENCES `financial_records` (`id`)');
    }
    
    return 'CREATE TABLE IF NOT EXISTS `$tableName` (\n  ${mysqlColumns.join(',\n  ')}\n) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci';
  }
  
  /// 回退的 SQLite CREATE TABLE 生成方法
  static String _fallbackGenerateSQLiteCreateTable(String tableName, Map<String, String> columns) {
    final sqliteColumns = <String>[];
    
    for (final entry in columns.entries) {
      final columnName = entry.key;
      final columnDef = entry.value;
      
      sqliteColumns.add('$columnName $columnDef');
    }
    
    // 为特定表添加外键约束
    if (tableName == 'financial_items') {
      sqliteColumns.add('FOREIGN KEY (financial_record_id) REFERENCES financial_records(id)');
    }
    
    return 'CREATE TABLE IF NOT EXISTS $tableName (\n  ${sqliteColumns.join(',\n  ')}\n)';
  }
}

import 'package:sqflite/sqflite.dart';
import 'package:dentist_app/models/schemas/table_schema.dart';
import 'package:dentist_app/utils/sync_table_config.dart';
import 'dart:convert';

/// 表结构验证和更新工具
class SchemaValidator {
  /// 检查并更新SQLite数据库表结构
  static Future<SchemaValidationResult> validateAndUpdateSchema(Database db) async {
    final result = SchemaValidationResult();
    
    try {
      print('SchemaValidator: 开始检查数据库表结构...');
      
      // 获取所有需要检查的表
      final requiredTables = SyncTableConfig.getSyncTables();
      
      for (final tableName in requiredTables.keys) {
        print('SchemaValidator: 检查表 $tableName...');
        
        final tableResult = await _validateTable(db, tableName, requiredTables[tableName]!);
        result.addTableResult(tableName, tableResult);
        
        if (tableResult.needsUpdate) {
          print('SchemaValidator: 表 $tableName 需要更新');
          await _updateTableSchema(db, tableName, tableResult);
          result.updatedTables.add(tableName);
        }
      }
      
      result.success = true;
      print('SchemaValidator: 表结构检查完成');
      
    } catch (e) {
      print('SchemaValidator: 表结构检查失败: $e');
      result.success = false;
      result.error = e.toString();
    }
    
    return result;
  }
  

  
  /// 验证单个表结构
  static Future<TableValidationResult> _validateTable(
    Database db, 
    String tableName, 
    TableSchema expectedSchema
  ) async {
    final result = TableValidationResult();
    
    try {
      // 检查表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName]
      );
      
      if (tables.isEmpty) {
        // 表不存在，需要创建
        result.exists = false;
        result.needsUpdate = true;
        result.action = 'CREATE_TABLE';
        result.details = '表不存在，需要创建';
        return result;
      }
      
      result.exists = true;
      
      // 获取当前表结构
      final currentColumns = await db.rawQuery("PRAGMA table_info($tableName)");
      final currentColumnMap = <String, Map<String, dynamic>>{};
      
      for (final column in currentColumns) {
        currentColumnMap[column['name'] as String] = {
          'type': column['type'] as String,
          'notnull': column['notnull'] as int,
          'dflt_value': column['dflt_value'],
          'pk': column['pk'] as int,
        };
      }
      
      // 比较期望的列结构
      final expectedColumns = expectedSchema.columnDefinitions;
      final missingColumns = <String>[];
      final differentColumns = <String>[];
      
      for (final expectedColumn in expectedColumns.keys) {
        if (!currentColumnMap.containsKey(expectedColumn)) {
          missingColumns.add(expectedColumn);
        } else {
          // 检查列类型是否匹配（简化检查）
          final currentType = currentColumnMap[expectedColumn]!['type'] as String;
          final expectedType = expectedColumns[expectedColumn]!;
          
          if (!_isColumnTypeCompatible(currentType, expectedType)) {
            differentColumns.add(expectedColumn);
          }
        }
      }
      
      // 检查是否有多余的列
      final extraColumns = <String>[];
      for (final currentColumn in currentColumnMap.keys) {
        if (!expectedColumns.containsKey(currentColumn)) {
          extraColumns.add(currentColumn);
        }
      }
      
      result.missingColumns = missingColumns;
      result.differentColumns = differentColumns;
      result.extraColumns = extraColumns;
      
      if (missingColumns.isNotEmpty || differentColumns.isNotEmpty) {
        result.needsUpdate = true;
        result.action = 'ALTER_TABLE';
        
        final details = <String>[];
        if (missingColumns.isNotEmpty) {
          details.add('缺少列: ${missingColumns.join(", ")}');
        }
        if (differentColumns.isNotEmpty) {
          details.add('类型不匹配: ${differentColumns.join(", ")}');
        }
        if (extraColumns.isNotEmpty) {
          details.add('多余列: ${extraColumns.join(", ")}');
        }
        result.details = details.join('; ');
      } else {
        result.details = '表结构正确';
      }
      
    } catch (e) {
      result.error = e.toString();
      print('SchemaValidator: 验证表 $tableName 失败: $e');
    }
    
    return result;
  }
  
  /// 更新表结构
  static Future<void> _updateTableSchema(
    Database db, 
    String tableName, 
    TableValidationResult validation
  ) async {
    try {
      if (validation.action == 'CREATE_TABLE') {
        // 创建新表
        final schema = SyncTableConfig.getSyncTables()[tableName]!;
        await db.execute(schema.createTableSql);
        print('SchemaValidator: 已创建表 $tableName');
        
      } else if (validation.action == 'ALTER_TABLE') {
        // 修改现有表
        await _alterTable(db, tableName, validation);
      }
      
    } catch (e) {
      print('SchemaValidator: 更新表 $tableName 失败: $e');
      rethrow;
    }
  }
  
  /// 修改表结构
  static Future<void> _alterTable(
    Database db, 
    String tableName, 
    TableValidationResult validation
  ) async {
    final schema = SyncTableConfig.getSyncTables()[tableName]!;
    final expectedColumns = schema.columnDefinitions;
    
    // 对于SQLite，如果需要修改列类型或删除列，需要重建表
    if (validation.differentColumns.isNotEmpty || validation.extraColumns.isNotEmpty) {
      await _recreateTable(db, tableName, schema);
    } else {
      // 只是添加缺少的列
      for (final missingColumn in validation.missingColumns) {
        final columnDef = expectedColumns[missingColumn]!;
        try {
          await db.execute('ALTER TABLE $tableName ADD COLUMN $missingColumn $columnDef');
          print('SchemaValidator: 已添加列 $tableName.$missingColumn');
        } catch (e) {
          print('SchemaValidator: 添加列 $tableName.$missingColumn 失败: $e');
          // 如果添加列失败，可能需要重建表
          await _recreateTable(db, tableName, schema);
          break;
        }
      }
    }
  }
  
  /// 重建表（直接删除旧表，创建新表，数据将从MySQL重新同步）
  static Future<void> _recreateTable(Database db, String tableName, TableSchema schema) async {
    try {
      // 1. 删除原表
      await db.execute('DROP TABLE IF EXISTS $tableName');
      print('SchemaValidator: 已删除旧表 $tableName');
      
      // 2. 创建新表
      await db.execute(schema.createTableSql);
      print('SchemaValidator: 已创建新表 $tableName（数据将从MySQL重新同步）');
      
    } catch (e) {
      print('SchemaValidator: 重建表 $tableName 失败: $e');
      rethrow;
    }
  }
  
  /// 检查列类型是否兼容
  static bool _isColumnTypeCompatible(String currentType, String expectedType) {
    // 简化的类型兼容性检查
    final current = currentType.toUpperCase();
    final expected = expectedType.toUpperCase();
    
    // 完全匹配
    if (current == expected) return true;
    
    // 常见的兼容类型
    final compatibleTypes = {
      'INTEGER': ['INT', 'BIGINT', 'SMALLINT'],
      'TEXT': ['VARCHAR', 'CHAR', 'STRING'],
      'REAL': ['FLOAT', 'DOUBLE', 'DECIMAL'],
      'BLOB': ['BINARY', 'VARBINARY'],
    };
    
    for (final baseType in compatibleTypes.keys) {
      if (current.contains(baseType) || expected.contains(baseType)) {
        final compatible = compatibleTypes[baseType]!;
        for (final compatType in compatible) {
          if ((current.contains(compatType) && expected.contains(baseType)) ||
              (expected.contains(compatType) && current.contains(baseType))) {
            return true;
          }
        }
      }
    }
    
    return false;
  }
}

/// 表结构验证结果
class SchemaValidationResult {
  bool success = false;
  String? error;
  Map<String, TableValidationResult> tableResults = {};
  Set<String> updatedTables = {};
  
  void addTableResult(String tableName, TableValidationResult result) {
    tableResults[tableName] = result;
  }
  
  /// 获取总结信息
  String getSummary() {
    if (!success) {
      return '表结构检查失败: ${error ?? "未知错误"}';
    }
    
    final totalTables = tableResults.length;
    final updatedCount = updatedTables.length;
    
    if (updatedCount == 0) {
      return '所有 $totalTables 个表结构都是最新的';
    } else {
      return '检查了 $totalTables 个表，更新了 $updatedCount 个表: ${updatedTables.join(", ")}';
    }
  }
  
  /// 获取详细信息
  Map<String, dynamic> getDetails() {
    final details = <String, dynamic>{};
    
    for (final entry in tableResults.entries) {
      final tableName = entry.key;
      final result = entry.value;
      
      details[tableName] = {
        'exists': result.exists,
        'needsUpdate': result.needsUpdate,
        'action': result.action,
        'details': result.details,
        'missingColumns': result.missingColumns,
        'differentColumns': result.differentColumns,
        'extraColumns': result.extraColumns,
        'error': result.error,
      };
    }
    
    return details;
  }
}

/// 单个表验证结果
class TableValidationResult {
  bool exists = false;
  bool needsUpdate = false;
  String action = '';
  String details = '';
  List<String> missingColumns = [];
  List<String> differentColumns = [];
  List<String> extraColumns = [];
  String? error;
}
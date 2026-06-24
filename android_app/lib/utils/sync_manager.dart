import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/models/sync_config.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/utils/mysql_utils.dart';
import 'package:dentist_app/utils/sync_logger.dart';
import 'package:dentist_app/utils/schema_validator.dart';
import 'package:dentist_app/utils/sync_table_config.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import './app_logger.dart';

/// MySQL到SQLite数据同步管理器
class SyncManager {
  /// 执行数据同步
  /// [forceSync] 如果为true，跳过同步间隔检测（用于手动同步）
  static Future<bool> performSync({bool forceSync = false}) async {
    try {
      AppLogger.info('SyncManager: 开始执行MySQL到SQLite数据同步...');

      final dbConfig = await DatabaseConfig.loadConfig();
      final syncConfig = await SyncConfig.loadSyncConfig();

      AppLogger.info(
        'SyncManager: 同步配置 - 启用: ${syncConfig.syncEnabled}, 间隔: ${syncConfig.syncIntervalDays}天, 上次同步: ${syncConfig.lastSyncTime}',
      );
      AppLogger.info(
        'SyncManager: 数据库配置 - 类型: ${dbConfig.dbType}, MySQL主机: ${dbConfig.mysql.host}',
      );

      // 检查MySQL连接
      AppLogger.info('SyncManager: 测试MySQL连接...');
      final canConnect = await MySqlUtils.testConnection(dbConfig);
      if (!canConnect) {
        AppLogger.info('SyncManager: MySQL连接失败，无法执行同步');
        await SyncLogger.logSync(
          success: false,
          message: 'MySQL连接失败，无法执行同步',
          tableCounts: {},
          tableDetails: {},
          error: '无法连接到MySQL数据库',
        );
        return false;
      }
      AppLogger.info('SyncManager: MySQL连接测试成功');

      // 检查是否需要同步（只有非强制同步时才检查间隔）
      if (!forceSync) {
        AppLogger.info('SyncManager: 检查是否需要同步...');
        if (!syncConfig.shouldSync()) {
          AppLogger.info('SyncManager: 未达到同步间隔，跳过同步');
          return true;
        }
      }
      AppLogger.info('SyncManager: 需要执行同步，开始同步过程...');

      final mysqlConn = await MySqlUtils.getConnection(dbConfig);
      if (mysqlConn == null) {
        await SyncLogger.logSync(
          success: false,
          message: '获取MySQL连接失败',
          tableCounts: {},
          tableDetails: {},
          error: '无法建立MySQL连接',
        );
        return false;
      }

      final sqliteDb = await DatabaseHelper().database;

      // 1. 首先检查并更新表结构
      AppLogger.info('SyncManager: 检查并更新SQLite表结构...');
      final schemaResult = await SchemaValidator.validateAndUpdateSchema(
        sqliteDb,
      );

      if (!schemaResult.success) {
        await SyncLogger.logSync(
          success: false,
          message: '表结构检查失败',
          tableCounts: {},
          tableDetails: {},
          error: schemaResult.error ?? '未知错误',
          schemaChanges: schemaResult.getSummary(),
        );
        return false;
      }

      AppLogger.info('SyncManager: 表结构检查完成: ${schemaResult.getSummary()}');

      // 开始事务
      await sqliteDb.transaction((txn) async {
        final tableCounts = <String, int>{};
        final tableDetails = <String, String>{};

        try {
          for (final tableName in SyncTableConfig.syncTableNames) {
            AppLogger.info('同步表: $tableName');
            final result = await _syncTableInternal(mysqlConn, txn, tableName);
            tableCounts[tableName] = result.count;
            tableDetails[tableName] = result.detail;
            AppLogger.info('表 $tableName 同步完成: ${result.detail}');
          }

          // 更新同步时间
          await syncConfig.updateLastSyncTime();

          // 记录成功日志
          await SyncLogger.logSync(
            success: true,
            message: 'MySQL到SQLite数据同步成功',
            tableCounts: tableCounts,
            tableDetails: tableDetails,
            schemaChanges: schemaResult.getSummary(),
          );
        } catch (e) {
          // 记录失败日志
          await SyncLogger.logSync(
            success: false,
            message: '数据同步过程中发生错误',
            tableCounts: tableCounts,
            tableDetails: tableDetails,
            error: e.toString(),
            schemaChanges: schemaResult.getSummary(),
          );
          rethrow;
        }
      });

      await mysqlConn.close();
      AppLogger.info('SyncManager: 数据同步完成，返回成功');
      return true;
    } catch (e) {
      AppLogger.info('SyncManager: 数据同步失败: $e');
      AppLogger.info('SyncManager: 错误堆栈: ${StackTrace.current}');
      return false;
    }
  }

  static Future<_SyncTableResult> _syncTableInternal(
    MySqlConnection mysqlConn,
    Transaction txn,
    String tableName,
  ) async {
    try {
      final tableExists = await _mysqlTableExists(mysqlConn, tableName);
      if (!tableExists) {
        const detail = 'MySQL源表不存在，已跳过';
        AppLogger.info('同步表 $tableName 跳过: $detail');
        return const _SyncTableResult(count: 0, detail: 'MySQL源表不存在，已跳过');
      }

      // 清空SQLite表
      await txn.delete(tableName);

      // 获取MySQL数据
      final mysqlResult = await mysqlConn.query('SELECT * FROM $tableName');

      if (mysqlResult.isEmpty) {
        AppLogger.info('表 $tableName 没有数据');
        return const _SyncTableResult(count: 0, detail: '同步了 0 条记录');
      }

      // 获取SQLite表结构以确认字段顺序
      final sqliteColumns = await txn.rawQuery("PRAGMA table_info($tableName)");
      final expectedColumns =
          sqliteColumns.map((col) => col['name'] as String).toList();
      AppLogger.info('SQLite表 $tableName 期望的字段顺序: $expectedColumns');

      // 插入数据到SQLite
      int count = 0;
      for (final row in mysqlResult) {
        final map = _convertRowToMap(row, tableName, expectedColumns);
        await txn.insert(tableName, map);
        count++;
      }

      return _SyncTableResult(count: count, detail: '同步了 $count 条记录');
    } catch (e) {
      AppLogger.info('同步表 $tableName 失败: $e');
      rethrow;
    }
  }

  static Future<bool> _mysqlTableExists(
    MySqlConnection mysqlConn,
    String tableName,
  ) async {
    final escapedTableName = tableName.replaceAll("'", "''");
    final result = await mysqlConn.query(
      "SHOW TABLES LIKE '$escapedTableName'",
    );
    return result.isNotEmpty;
  }

  /// 将MySQL行转换为Map
  static Map<String, dynamic> _convertRowToMap(
    ResultRow row,
    String tableName,
    List<String> expectedColumns,
  ) {
    final map = <String, dynamic>{};

    // 创建一个按字段名映射的Map
    final mysqlFields = Map<String, dynamic>.from(row.fields);

    // 按SQLite期望的字段顺序构建Map
    for (final sqliteColumn in expectedColumns) {
      // 查找对应的MySQL字段（考虑大小写和命名约定）
      final mysqlColumn = _findMatchingColumn(mysqlFields.keys, sqliteColumn);

      if (mysqlColumn.isNotEmpty && mysqlFields.containsKey(mysqlColumn)) {
        final value = mysqlFields[mysqlColumn];
        map[sqliteColumn] = _convertFieldValue(sqliteColumn, value);
      } else {
        // 如果找不到对应字段，使用默认值
        map[sqliteColumn] = _getDefaultValue(sqliteColumn);
      }
    }

    return map;
  }

  /// 转换字段值
  static dynamic _convertFieldValue(String columnName, dynamic value) {
    if (value == null) {
      return _getDefaultValue(columnName);
    }

    // 处理BLOB类型数据（图片等二进制数据）
    if (columnName == 'image_data' || columnName == 'thumbnail_data') {
      if (value is Blob) {
        return value.toBytes();
      } else if (value is List<int>) {
        return value;
      } else if (value is Uint8List) {
        return value;
      } else if (value is String && value.isNotEmpty) {
        try {
          return base64.decode(value);
        } catch (e) {
          return Uint8List(0);
        }
      }
      return Uint8List(0);
    }

    // 处理JSON字段（如module_permissions）
    if (columnName == 'module_permissions') {
      if (value is String) {
        return value;
      } else if (value is Map || value is List) {
        return jsonEncode(value);
      }
      return '';
    }

    // 处理文本字段
    if (_isTextColumn(columnName)) {
      if (value is Blob) {
        try {
          final bytes = value.toBytes();
          return bytes.isNotEmpty
              ? utf8.decode(bytes, allowMalformed: true)
              : '';
        } catch (e) {
          return value.toString();
        }
      } else if (value is Uint8List) {
        try {
          return value.isNotEmpty
              ? utf8.decode(value, allowMalformed: true)
              : '';
        } catch (e) {
          return value.toString();
        }
      }
      return value.toString();
    }

    // 处理整数字段
    if (_isIntegerColumn(columnName)) {
      if (value is int) {
        return value;
      } else if (value is num) {
        return value.toInt();
      } else if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    // 处理浮点数字段
    if (_isFloatColumn(columnName)) {
      if (value is num) {
        return value.toDouble();
      } else if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    // 处理布尔值字段
    if (_isBooleanColumn(columnName)) {
      if (value is bool) {
        return value ? 1 : 0;
      } else if (value is int) {
        return value;
      } else if (value is String) {
        return (value.toLowerCase() == 'true' || value == '1') ? 1 : 0;
      }
      return 0;
    }

    // 处理日期时间字段
    if (_isDateTimeColumn(columnName)) {
      if (value is DateTime) {
        return DateTimeFormatter.toDbString(value);
      } else if (value is String) {
        return value;
      }
      return DateTimeFormatter.nowDbString();
    }

    // 默认处理
    if (value is bool) {
      return value ? 1 : 0;
    } else if (value is num) {
      return value is int ? value : value.toDouble();
    }

    return value.toString();
  }

  /// 获取字段默认值
  static dynamic _getDefaultValue(String columnName) {
    if (columnName == 'image_data' || columnName == 'thumbnail_data') {
      return Uint8List(0);
    } else if (_isIntegerColumn(columnName) || _isBooleanColumn(columnName)) {
      return 0;
    } else if (_isFloatColumn(columnName)) {
      return 0.0;
    } else if (_isDateTimeColumn(columnName)) {
      return DateTimeFormatter.nowDbString();
    }
    return '';
  }

  /// 判断是否为文本列
  static bool _isTextColumn(String columnName) {
    const textColumns = {
      'supplier',
      'notes',
      'doctor',
      'material_name',
      'description',
      'name',
      'username',
      'email',
      'password',
      'role',
      'avatar',
      'phone',
      'identification_number',
      'address',
      'address_pinyin',
      'dental_condition',
      'treatment_items',
      'medical_history',
      'status',
      'treatment_type',
      'item_name',
      'payment_method',
      'material_code',
      'material_type',
      'specification',
      'unit',
      'original_name',
      'image_path',
      'image_type',
      'module_permissions',
    };
    return textColumns.contains(columnName);
  }

  /// 判断是否为整数列
  static bool _isIntegerColumn(String columnName) {
    const intColumns = {
      'id',
      'patient_id',
      'material_id',
      'financial_record_id',
      'purchase_record_id',
      'medical_record_number',
      'age',
      'total_quantity',
      'quantity',
      'file_size',
      'thumbnail_size',
      'stock_quantity',
      'min_stock',
      'has_thumbnail',
    };
    return intColumns.contains(columnName);
  }

  /// 判断是否为浮点数列
  static bool _isFloatColumn(String columnName) {
    const floatColumns = {
      'total_cost',
      'cost',
      'item_price',
      'total_price',
      'processing_fee',
      'default_price',
      'unit_price',
      'total_amount',
    };
    return floatColumns.contains(columnName);
  }

  /// 判断是否为布尔列
  static bool _isBooleanColumn(String columnName) {
    const boolColumns = {'has_thumbnail'};
    return boolColumns.contains(columnName);
  }

  /// 判断是否为日期时间列
  static bool _isDateTimeColumn(String columnName) {
    return columnName.contains('date') ||
        columnName.contains('_at') ||
        columnName.contains('time');
  }

  /// 查找匹配的MySQL列名
  static String _findMatchingColumn(
    Iterable<String> mysqlColumns,
    String sqliteColumn,
  ) {
    // 直接匹配
    if (mysqlColumns.contains(sqliteColumn)) {
      return sqliteColumn;
    }

    // 大小写不敏感匹配
    for (final mysqlColumn in mysqlColumns) {
      if (mysqlColumn.toLowerCase() == sqliteColumn.toLowerCase()) {
        return mysqlColumn;
      }
    }

    // 驼峰到下划线匹配
    final camelCase = sqliteColumn.replaceAllMapped(RegExp(r'_([a-z])'), (
      match,
    ) {
      final group = match.group(1);
      return group != null ? group.toUpperCase() : '';
    });
    if (mysqlColumns.contains(camelCase)) {
      return camelCase;
    }

    // 下划线到驼峰匹配
    final snakeCase = camelCase.replaceAllMapped(RegExp(r'[A-Z]'), (match) {
      return '_${match.group(0)!.toLowerCase()}';
    });
    if (mysqlColumns.contains(snakeCase)) {
      return snakeCase;
    }

    // 如果都没找到，返回空字符串表示未找到
    return '';
  }

  /// 检查并执行同步（带连接检测）
  static Future<bool> checkAndSync() async {
    try {
      final dbConfig = await DatabaseConfig.loadConfig();
      final syncConfig = await SyncConfig.loadSyncConfig();

      // 如果未启用同步，直接返回
      if (!syncConfig.syncEnabled) {
        AppLogger.info('同步未启用');
        return true;
      }

      // 测试MySQL连接
      final canConnect = await MySqlUtils.testConnection(dbConfig);
      if (!canConnect) {
        AppLogger.info('MySQL连接失败，跳过同步');
        return false;
      }

      // 执行同步（自动同步，需要检查间隔）
      return await performSync(forceSync: false);
    } catch (e) {
      AppLogger.info('检查并执行同步失败: $e');
      return false;
    }
  }

  /// 强制同步（忽略间隔检查）
  static Future<bool> forceSync() async {
    try {
      final dbConfig = await DatabaseConfig.loadConfig();

      // 测试MySQL连接
      final canConnect = await MySqlUtils.testConnection(dbConfig);
      if (!canConnect) {
        await SyncLogger.logSync(
          success: false,
          message: '强制同步失败：MySQL连接失败',
          tableCounts: {},
          tableDetails: {},
          error: '无法连接到MySQL数据库',
        );
        return false;
      }

      // 强制同步，跳过间隔检查
      return await performSync(forceSync: true);
    } catch (e) {
      AppLogger.info('强制同步失败: $e');
      return false;
    }
  }
}

class _SyncTableResult {
  final int count;
  final String detail;

  const _SyncTableResult({required this.count, required this.detail});
}

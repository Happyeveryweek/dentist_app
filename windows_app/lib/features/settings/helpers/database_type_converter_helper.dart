import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql1/mysql1.dart';
import 'package:crypto/crypto.dart';
import '../../../utils/datetime_formatter.dart';
import '../../../utils/log_manager.dart';

/// 数据库类型转换辅助类
class DatabaseTypeConverterHelper {
  /// 密码哈希
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 判断是否需要更新 MySQL 字段类型
  static bool shouldUpdateMySQLColumnType(
      String existingType, String requiredType) {
    // 移除不相关的修饰符
    final cleanExisting =
        existingType.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanRequired = requiredType
        .toLowerCase()
        .replaceAll('primary key', '')
        .replaceAll('auto_increment', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // MySQL特定的类型兼容性检查
    final mysqlCompatibilityMap = {
      // TEXT类型兼容性
      'text': ['text', 'varchar', 'longtext', 'mediumtext', 'tinytext'],
      'varchar': ['varchar', 'text', 'char'],
      'longtext': ['longtext', 'text', 'varchar'],
      'mediumtext': ['mediumtext', 'text', 'varchar'],
      'tinytext': ['tinytext', 'text', 'varchar'],

      // 数值类型兼容性
      'int': ['int', 'integer', 'bigint', 'smallint', 'tinyint'],
      'integer': ['integer', 'int', 'bigint', 'smallint'],
      'bigint': ['bigint', 'int', 'integer'],
      'decimal': ['decimal', 'numeric', 'float', 'double'],
      'float': ['float', 'decimal', 'double'],
      'double': ['double', 'float', 'decimal'],

      // 二进制类型兼容性
      'longblob': ['longblob', 'blob', 'mediumblob', 'tinyblob'],
      'blob': ['blob', 'longblob', 'mediumblob'],

      // 日期时间类型兼容性
      'datetime': [
        'datetime',
        'timestamp',
        'text'
      ], // 添加text兼容性，因为SQLite中时间字段使用TEXT
      'timestamp': ['timestamp', 'datetime', 'text'],
      'date': ['date', 'text'],
      'time': ['time', 'text'],

      // 布尔类型兼容性
      'tinyint': ['tinyint', 'boolean', 'bool'],
      'boolean': ['boolean', 'tinyint', 'bool'],
    };

    // 提取基础类型名（去掉长度和修饰符）
    final existingBaseType = cleanExisting.split('(')[0].split(' ')[0];
    final requiredBaseType = cleanRequired.split('(')[0].split(' ')[0];

    // 检查类型兼容性
    final compatibleTypes = mysqlCompatibilityMap[existingBaseType];
    if (compatibleTypes != null &&
        compatibleTypes.contains(requiredBaseType)) {
      return false; // 类型兼容，不需要更新
    }

    // 如果类型不兼容，需要更新
    LogManager.e('DatabaseTypeConverterHelper',
        'MySQL字段类型不兼容: $existingBaseType vs $requiredBaseType');
    return true;
  }

  /// 判断是否需要更新 SQLite 字段类型
  static bool shouldUpdateSQLiteColumnType(
      String existingType, String requiredType) {
    // SQLite的类型系统比较宽松，对于结构检测，我们采用更宽松的策略
    // 只要字段存在且不是完全不兼容的类型，就认为是兼容的

    final cleanExisting =
        existingType.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final cleanRequired = requiredType
        .toLowerCase()
        .replaceAll('primary key', '')
        .replaceAll('autoincrement', '')
        .replaceAll('not null', '')
        .replaceAll('default', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 提取基础类型名（去掉长度限制）
    final existingBaseType = cleanExisting.split('(')[0].split(' ')[0];
    final requiredBaseType = cleanRequired.split('(')[0].split(' ')[0];

    // 如果基础类型完全相同，则兼容
    if (existingBaseType == requiredBaseType) {
      return false;
    }

    // SQLite存储类别兼容性映射 - 更全面的兼容性检查
    final sqliteCompatibilityGroups = [
      ['integer', 'int', 'bigint', 'smallint', 'tinyint', 'numeric'],
      ['text', 'varchar', 'char', 'clob', 'string'],
      ['real', 'double', 'float', 'decimal'],
      ['blob', 'binary'],
      [
        'datetime',
        'timestamp',
        'date',
        'time',
        'text'
      ], // 添加text到时间类型组，因为SQLite中时间字段使用TEXT存储
    ];

    // 检查类型兼容性
    for (final group in sqliteCompatibilityGroups) {
      if (group.contains(existingBaseType) &&
          group.contains(requiredBaseType)) {
        return false; // 类型兼容，不需要更新
      }
    }

    // 特殊情况：SQLite中很多类型都可以互相兼容
    // 对于结构检测，我们采用非常宽松的策略，只有明显不兼容的才报告
    final obviouslyIncompatible = [
      ['blob', 'text'],
      ['blob', 'varchar'],
      ['blob', 'integer'],
      ['blob', 'real'],
      ['integer', 'text'],
      ['integer', 'varchar'],
      ['real', 'text'],
      ['real', 'varchar'],
    ];

    for (final incompatible in obviouslyIncompatible) {
      if ((incompatible[0] == existingBaseType &&
              incompatible[1] == requiredBaseType) ||
          (incompatible[1] == existingBaseType &&
              incompatible[0] == requiredBaseType)) {
        LogManager.e('DatabaseTypeConverterHelper',
            'SQLite字段类型不兼容: $existingBaseType vs $requiredBaseType');
        return true;
      }
    }

    // 默认情况下，SQLite的类型系统很宽松，认为是兼容的
    return false;
  }

  /// 转换为 MySQL 类型
  static String convertToMySQLType(String columnDef) {
    String mysqlType = columnDef;

    // SQLite到MySQL的类型映射
    final typeMapping = {
      'TEXT': 'VARCHAR(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci',
      'INTEGER': 'INT',
      'REAL': 'DECIMAL(10,2)',
      'BLOB': 'LONGBLOB',
      "datetime('now')": 'CURRENT_TIMESTAMP',
    };

    for (final entry in typeMapping.entries) {
      mysqlType = mysqlType.replaceAll(entry.key, entry.value);
    }

    // 移除SQLite特有的约束
    mysqlType = mysqlType
        .replaceAll('AUTOINCREMENT', 'AUTO_INCREMENT')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return mysqlType;
  }

  /// 转换为 SQLite 类型
  static String convertToSQLiteType(String columnDef) {
    String sqliteType = columnDef;

    // MySQL到SQLite的类型映射
    final typeMapping = {
      'VARCHAR(255)': 'TEXT',
      'VARCHAR(100)': 'TEXT',
      'VARCHAR(50)': 'TEXT',
      'VARCHAR(20)': 'TEXT',
      'DATETIME': 'TEXT',
      'DATE': 'TEXT',
      'DECIMAL(10,2)': 'REAL',
      'INT': 'INTEGER',
      'LONGBLOB': 'BLOB',
      'CURRENT_TIMESTAMP': "datetime('now')",
    };

    for (final entry in typeMapping.entries) {
      sqliteType = sqliteType.replaceAll(entry.key, entry.value);
    }

    // 移除MySQL特有的约束
    sqliteType = sqliteType
        .replaceAll('ON UPDATE CURRENT_TIMESTAMP', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return sqliteType;
  }

  /// 转换为 SQLite 列定义
  static String convertToSQLiteColumnDefinition(String columnDef) {
    String sqliteColumnDef = columnDef;

    // MySQL到SQLite的类型转换
    final typeConversions = {
      'VARCHAR(255)': 'TEXT',
      'VARCHAR(500)': 'TEXT',
      'VARCHAR(1000)': 'TEXT',
      'VARCHAR(100)': 'TEXT',
      'VARCHAR(50)': 'TEXT',
      'VARCHAR(20)': 'TEXT',
      'DATETIME': 'TEXT',
      'DATE': 'TEXT',
      'DECIMAL(10,2)': 'REAL',
      'INT': 'INTEGER',
      'LONGBLOB': 'BLOB',
      'TINYINT(1)': 'INTEGER',
    };

    for (final entry in typeConversions.entries) {
      sqliteColumnDef = sqliteColumnDef.replaceAll(entry.key, entry.value);
    }

    // 移除MySQL特有的约束和修饰符
    sqliteColumnDef = sqliteColumnDef
        .replaceAll('AUTO_INCREMENT', '')
        .replaceAll('ON UPDATE CURRENT_TIMESTAMP', '')
        .replaceAll('CURRENT_TIMESTAMP', "datetime('now')")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return sqliteColumnDef;
  }

  /// 提取默认值
  static String? extractDefaultValue(String columnDef) {
    final defaultMatch = RegExp(r'DEFAULT\s+([^,\s]+)').firstMatch(columnDef);
    if (defaultMatch != null) {
      return defaultMatch.group(1);
    }
    return null;
  }

  /// 转换列定义为 MySQL 格式
  static String convertColumnDefinitionToMySQL(
      String columnName, String sqliteDef) {
    // 移除PRIMARY KEY等约束，只保留类型和基本属性
    String cleanDef = sqliteDef;

    // 处理PRIMARY KEY
    if (cleanDef.contains('PRIMARY KEY')) {
      cleanDef = cleanDef.replaceAll('PRIMARY KEY', '').trim();
    }

    // 处理AUTOINCREMENT
    if (cleanDef.contains('AUTOINCREMENT')) {
      cleanDef = cleanDef.replaceAll('AUTOINCREMENT', '').trim();
    }

    // 类型转换
    if (cleanDef.startsWith('INTEGER')) {
      if (columnName == 'id') {
        return 'id INT AUTO_INCREMENT PRIMARY KEY';
      } else {
        return '$columnName INT';
      }
    } else if (cleanDef.startsWith('TEXT')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName VARCHAR(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL';
      } else {
        return '$columnName VARCHAR(1000) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci';
      }
    } else if (cleanDef.startsWith('REAL')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName DECIMAL(10,2) NOT NULL';
      } else {
        return '$columnName DECIMAL(10,2)';
      }
    } else if (cleanDef.startsWith('BLOB')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName LONGBLOB NOT NULL';
      } else {
        return '$columnName LONGBLOB';
      }
    } else if (cleanDef.startsWith('datetime')) {
      if (cleanDef.contains('NOT NULL')) {
        return '$columnName DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP';
      } else {
        return '$columnName DATETIME DEFAULT CURRENT_TIMESTAMP';
      }
    }

    // 默认情况，保持原样
    return '$columnName $cleanDef';
  }

  /// 安全地解码 JSON
  static dynamic decodeJsonSafely(dynamic data) {
    try {
      // 处理 NULL 值
      if (data == null) {
        return <String, dynamic>{};
      }

      if (data is String) {
        // 如果是空字符串，返回默认值
        if (data.isEmpty) {
          return <String, dynamic>{};
        }
        // 如果是字符串，尝试直接解码
        return jsonDecode(data);
      } else if (data is Uint8List) {
        // 如果是Uint8List，转换为字符串后解码
        final stringData = String.fromCharCodes(data);
        return jsonDecode(stringData);
      } else if (data is Blob) {
        // 如果是Blob，转换为字符串后解码
        final stringData = String.fromCharCodes(data.toBytes());
        return jsonDecode(stringData);
      } else {
        // 其他类型，尝试转换为字符串后解码
        final stringData = data.toString();
        if (stringData == 'null' || stringData.isEmpty) {
          return <String, dynamic>{};
        }
        return jsonDecode(stringData);
      }
    } catch (e) {
      LogManager.e('DatabaseTypeConverterHelper', 'JSON解码失败: $e, 原始数据',
          error: data);
      // 解码失败时返回默认值
      if (data.toString().contains('errors') || data.toString().contains('[')) {
        return <String>[];
      } else {
        return <String, dynamic>{};
      }
    }
  }

  /// 安全地解析整数
  static int safeIntParse(dynamic data) {
    try {
      if (data is num) {
        return data.toInt();
      } else if (data is String) {
        return int.tryParse(data) ?? 0;
      } else if (data == null) {
        return 0;
      } else {
        return int.tryParse(data.toString()) ?? 0;
      }
    } catch (e) {
      LogManager.e('DatabaseTypeConverterHelper', '整数解析失败: $e, 原始数据',
          error: data);
      return 0;
    }
  }

  /// 安全地解析字符串
  static String safeStringParse(dynamic data) {
    try {
      if (data is String) {
        return data;
      } else if (data == null) {
        return '';
      } else {
        return data.toString();
      }
    } catch (e) {
      LogManager.e('DatabaseTypeConverterHelper', '字符串解析失败: $e, 原始数据',
          error: data);
      return '';
    }
  }

  /// 安全地解析日期时间
  static DateTime safeDateTimeParse(dynamic data) {
    try {
      if (data is DateTime) {
        return data;
      } else if (data is String) {
        return DateTimeFormatter.fromDbString(data);
      } else if (data == null) {
        return DateTime.now();
      } else {
        // 尝试解析其他类型
        final stringData = data.toString();
        if (stringData.contains('-') && stringData.contains(':')) {
          return DateTimeFormatter.fromDbString(stringData);
        } else {
          return DateTime.now();
        }
      }
    } catch (e) {
      LogManager.e('DatabaseTypeConverterHelper', '日期时间解析失败: $e, 原始数据',
          error: data);
      return DateTime.now();
    }
  }
}

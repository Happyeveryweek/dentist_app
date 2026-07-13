import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql1/mysql1.dart';
import 'package:crypto/crypto.dart';
import '../../../utils/log_manager.dart';

/// 数据库类型转换辅助类
class DatabaseTypeConverterHelper {
  /// 密码哈希
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = md5.convert(bytes);
    return digest.toString();
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
}

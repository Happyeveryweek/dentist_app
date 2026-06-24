import 'package:mysql1/mysql1.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dentist_app/utils/datetime_formatter.dart';
import './app_logger.dart';

/// MySQL 查询结果行处理器
///
/// 职责：
/// - 处理 MySQL 查询结果中的 Blob 字段
/// - 处理 DateTime 类型转换
/// - 处理 Uint8List 类型转换
/// - 处理字符串编码修复
class MysqlRowProcessor {
  /// 处理 MySQL 查询结果中的 Blob 字段和其他类型
  static Map<String, dynamic> processRow(ResultRow row) {
    final Map<String, dynamic> processedMap = {};

    for (var entry in row.fields.entries) {
      var value = entry.value;

      // 处理DateTime类型，将其转换为ISO字符串
      if (value is DateTime) {
        try {
          final stringValue = DateTimeFormatter.toDbString(value);
          processedMap[entry.key] = stringValue;
        } catch (e) {
          AppLogger.info('MysqlRowProcessor: DateTime转换失败: $e');
          processedMap[entry.key] = '';
        }
      }
      // 处理图片数据字段，使用String.fromCharCodes处理Blob类型
      else if (entry.key == 'image_data' || entry.key == 'thumbnail_data') {
        if (value is Blob) {
          try {
            // 使用String.fromCharCodes处理Blob，参考windows_app的实现
            final blobString = String.fromCharCodes(value.toBytes());
            processedMap[entry.key] = blobString;
          } catch (e) {
            AppLogger.info('MysqlRowProcessor: 图片字段转换失败: $e');
            processedMap[entry.key] = '';
          }
        } else if (value is Uint8List) {
          try {
            // 使用String.fromCharCodes处理Uint8List
            final stringValue = String.fromCharCodes(value);
            processedMap[entry.key] = stringValue;
          } catch (e) {
            AppLogger.info('MysqlRowProcessor: Uint8List转换失败: $e');
            processedMap[entry.key] = '';
          }
        } else if (value is String) {
          // 如果已经是String类型，直接使用
          processedMap[entry.key] = value;
        } else {
          AppLogger.info(
            'MysqlRowProcessor: 图片字段 ${entry.key} 类型异常: ${value.runtimeType}',
          );
          processedMap[entry.key] = '';
        }
      }
      // 处理其他Blob类型，将其转换为字符串
      else if (value is Blob) {
        try {
          final bytes = value.toBytes();
          if (bytes.isNotEmpty) {
            // 尝试UTF-8解码
            final stringValue = utf8.decode(bytes, allowMalformed: true);
            processedMap[entry.key] = stringValue;
          } else {
            processedMap[entry.key] = '';
          }
        } catch (e) {
          AppLogger.info('MysqlRowProcessor: Blob转换失败: $e');
          processedMap[entry.key] = '';
        }
      } else if (value is Uint8List) {
        // 处理Uint8List类型（某些MySQL驱动可能返回这种类型）
        try {
          if (value.isNotEmpty) {
            final stringValue = utf8.decode(value, allowMalformed: true);
            processedMap[entry.key] = stringValue;
          } else {
            processedMap[entry.key] = '';
          }
        } catch (e) {
          AppLogger.info('MysqlRowProcessor: Uint8List转换失败: $e');
          processedMap[entry.key] = '';
        }
      } else if (value is String) {
        // 只有在明显出现乱码特征时才尝试修复，避免把正常中文再次解坏
        processedMap[entry.key] = _normalizeStringValue(value);
      } else {
        processedMap[entry.key] = value;
      }
    }

    return processedMap;
  }

  static String _normalizeStringValue(String value) {
    if (value.isEmpty) {
      return value;
    }

    final hasPercentEncoding = value.contains('%');
    final hasReplacementChar = value.contains('�');
    final hasMojibakePattern = RegExp(r'[ÃÂÄÅÆÇÐÑØÙÚÛÜÝÞßà-ÿ]').hasMatch(value);

    if (!hasPercentEncoding && !hasReplacementChar && !hasMojibakePattern) {
      return value;
    }

    if (hasPercentEncoding) {
      try {
        final decoded = Uri.decodeComponent(value);
        if (decoded.isNotEmpty && decoded != value) {
          return decoded;
        }
      } catch (_) {
        // 继续尝试其他修复方式
      }
    }

    try {
      final decoded = utf8.decode(latin1.encode(value), allowMalformed: true);
      if (decoded.isNotEmpty) {
        return decoded;
      }
    } catch (_) {
      // 保持原值
    }

    return value;
  }
}

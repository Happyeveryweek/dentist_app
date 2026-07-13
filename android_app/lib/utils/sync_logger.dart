import 'dart:convert';
import 'datetime_formatter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import './app_logger.dart';

/// 同步日志模型
class SyncLog {
  final String id;
  final DateTime timestamp;
  final bool success;
  final String message;
  final Map<String, int> tableCounts;
  final Map<String, String> tableDetails;
  final String? error;
  final String? schemaChanges;

  SyncLog({
    String? id,
    DateTime? timestamp,
    required this.success,
    required this.message,
    required this.tableCounts,
    required this.tableDetails,
    this.error,
    this.schemaChanges,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();

  // 从JSON创建日志
  factory SyncLog.fromJson(Map<String, dynamic> json) {
    return SyncLog(
      id: json['id'],
      timestamp: DateTimeFormatter.fromDbString(json['timestamp']),
      success: json['success'],
      message: json['message'],
      tableCounts: Map<String, int>.from(json['table_counts']),
      tableDetails: Map<String, String>.from(json['table_details']),
      error: json['error'],
      schemaChanges: json['schema_changes'],
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': DateTimeFormatter.toDbString(timestamp),
      'success': success,
      'message': message,
      'table_counts': tableCounts,
      'table_details': tableDetails,
      'error': error,
      'schema_changes': schemaChanges,
    };
  }

  // 获取格式化的时间字符串
  String get formattedTime {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
  }

  // 获取状态文本
  String get statusText {
    return success ? '成功' : '失败';
  }

  // 获取状态颜色
  String get statusColor {
    return success ? 'green' : 'red';
  }
}

/// 同步日志管理器
class SyncLogger {
  static const String _logFileName = 'sync_logs.json';
  static const int _maxLogs = 100; // 最多保存100条日志

  /// 获取日志文件路径
  static Future<String> getLogFilePath() async {
    final appDir = await getApplicationDocumentsDirectory();
    return path.join(appDir.path, _logFileName);
  }

  /// 记录同步日志
  static Future<void> logSync({
    required bool success,
    required String message,
    required Map<String, int> tableCounts,
    required Map<String, String> tableDetails,
    String? error,
    String? schemaChanges,
  }) async {
    try {
      final log = SyncLog(
        success: success,
        message: message,
        tableCounts: tableCounts,
        tableDetails: tableDetails,
        error: error,
        schemaChanges: schemaChanges,
      );

      final logs = await getAllLogs();
      logs.insert(0, log); // 添加到最前面

      // 限制日志数量
      if (logs.length > _maxLogs) {
        logs.removeRange(_maxLogs, logs.length);
      }

      await _saveLogs(logs);
    } catch (e) {
      AppLogger.info('记录同步日志失败: $e');
    }
  }

  /// 获取所有日志
  static Future<List<SyncLog>> getAllLogs() async {
    try {
      final logFile = File(await getLogFilePath());
      if (await logFile.exists()) {
        final jsonString = await logFile.readAsString();
        final jsonList = jsonDecode(jsonString) as List;
        return jsonList.map((json) => SyncLog.fromJson(json)).toList();
      }
    } catch (e) {
      AppLogger.info('读取同步日志失败: $e');
    }
    return [];
  }

  /// 清除所有日志
  static Future<void> clearAllLogs() async {
    try {
      final logFile = File(await getLogFilePath());
      if (await logFile.exists()) {
        await logFile.delete();
      }
    } catch (e) {
      AppLogger.info('清除同步日志失败: $e');
    }
  }

  /// 保存日志到文件
  static Future<void> _saveLogs(List<SyncLog> logs) async {
    try {
      final logFile = File(await getLogFilePath());
      final jsonList = logs.map((log) => log.toJson()).toList();
      await logFile.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      AppLogger.info('保存同步日志失败: $e');
    }
  }
}

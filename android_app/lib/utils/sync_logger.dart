import 'dart:convert';
import 'datetime_formatter.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import './app_logger.dart';
import 'map_parser.dart';

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
  final String? sourceDatabase;
  final String? targetDatabase;
  final int? durationMs;

  SyncLog({
    String? id,
    DateTime? timestamp,
    required this.success,
    required this.message,
    required this.tableCounts,
    required this.tableDetails,
    this.error,
    this.schemaChanges,
    this.sourceDatabase,
    this.targetDatabase,
    this.durationMs,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
       timestamp = timestamp ?? DateTime.now();

  // 从JSON创建日志
  factory SyncLog.fromJson(Map<String, dynamic> json) {
    final parser = MapParser(json, context: 'SyncLog');
    return SyncLog(
      id: parser.stringOptional('id'),
      timestamp: parser.optional(
        'timestamp',
        (value) => DateTimeFormatter.fromDbString(value.toString()),
      ),
      success: parser.boolean('success'),
      message: parser.string('message'),
      tableCounts: _parseTableCounts(json['table_counts']),
      tableDetails: _parseTableDetails(json['table_details']),
      error: parser.stringOptional('error'),
      schemaChanges: parser.stringOptional('schema_changes'),
      sourceDatabase: parser.stringOptional('source_database'),
      targetDatabase:
          parser.stringOptional('target_database') ??
          parser.stringOptional('target_database_path'),
      durationMs: parser.integerOptional('duration_ms'),
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
      'source_database': sourceDatabase,
      'target_database': targetDatabase,
      'duration_ms': durationMs,
    };
  }

  int get totalRecords =>
      tableCounts.values.fold(0, (sum, count) => sum + count);

  static Map<String, int> _parseTableCounts(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, count) {
      final parsedCount = count is int ? count : int.tryParse('$count') ?? 0;
      return MapEntry('$key', parsedCount);
    });
  }

  static Map<String, String> _parseTableDetails(dynamic value) {
    if (value is! Map) return {};
    return value.map((key, detail) => MapEntry('$key', '$detail'));
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
    String? sourceDatabase,
    String? targetDatabase,
    int? durationMs,
  }) async {
    try {
      final log = SyncLog(
        success: success,
        message: message,
        tableCounts: tableCounts,
        tableDetails: tableDetails,
        error: error,
        schemaChanges: schemaChanges,
        sourceDatabase: sourceDatabase,
        targetDatabase: targetDatabase,
        durationMs: durationMs,
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

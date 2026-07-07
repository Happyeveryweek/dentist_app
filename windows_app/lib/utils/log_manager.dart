import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'app_paths.dart';
import 'package:flutter/foundation.dart';

/// 日志管理器
/// 统一管理应用的所有日志文件
class LogManager {
  static LogManager? _instance;
  static LogManager get instance => _instance ??= LogManager._();
  LogManager._();

  static const int maxLogFileSize = 10 * 1024 * 1024; // 10MB
  static const int maxLogFiles = 5; // 保留最多5个日志文件

  /// 写入应用日志
  static Future<void> writeAppLog(String message,
      {String level = 'INFO'}) async {
    await _writeLog(AppPaths.appLogPath, message, level: level);
  }

  /// 写入错误日志
  static Future<void> writeErrorLog(String message,
      {String? stackTrace}) async {
    String fullMessage = message;
    if (stackTrace != null) {
      fullMessage += '\nStack Trace:\n$stackTrace';
    }
    await _writeLog(AppPaths.errorLogPath, fullMessage, level: 'ERROR');
  }

  /// 写入调试日志
  static Future<void> writeDebugLog(String message) async {
    await _writeLog(AppPaths.appLogPath, message, level: 'DEBUG');
  }

  /// 写入信息日志
  static Future<void> writeInfoLog(String message) async {
    await _writeLog(AppPaths.appLogPath, message, level: 'INFO');
  }

  /// 写入同步日志
  static Future<void> writeSyncLog(String message,
      {String level = 'INFO'}) async {
    await _writeLog(AppPaths.syncLogPath, message, level: level);
  }

  /// 写入结构化同步日志
  static Future<void> logSyncOperation({
    required String module,
    required String action,
    required String table,
    required String status,
    int? recordId,
    String? summary,
    String? error,
  }) async {
    final payload = <String, dynamic>{
      'module': module,
      'action': action,
      'table': table,
      'status': status,
      'direction': 'sqlite_to_mysql',
    };

    if (recordId != null) {
      payload['record_id'] = recordId;
    }
    if (summary != null && summary.isNotEmpty) {
      payload['summary'] = summary;
    }
    if (error != null && error.isNotEmpty) {
      payload['error'] = error;
    }

    final level = status == 'failed'
        ? 'ERROR'
        : status == 'skipped'
            ? 'WARNING'
            : 'INFO';
    await writeSyncLog(jsonEncode(payload), level: level);
  }

  /// 写入警告日志
  static Future<void> writeWarningLog(String message) async {
    await _writeLog(AppPaths.appLogPath, message, level: 'WARNING');
  }

  // ==================== 同步日志门面（供业务代码直接调用） ====================

  /// 调试日志（仅在 kDebugMode 输出，Release 模式不落盘）
  static void d(String tag, String message, {Object? error}) {
    if (kDebugMode) {
      debugPrint('D/$tag: $message');
    }
  }

  /// 信息日志
  static void i(String tag, String message, {Object? error}) {
    if (kDebugMode) debugPrint('I/$tag: $message');
    final buffer = StringBuffer('[$tag] $message');
    if (error != null) buffer.write('\nError: $error');
    writeInfoLog(buffer.toString()).ignore();
  }

  /// 警告日志
  static void w(String tag, String message, {Object? error}) {
    if (kDebugMode) debugPrint('W/$tag: $message');
    final buffer = StringBuffer('[$tag] $message');
    if (error != null) buffer.write('\nError: $error');
    writeWarningLog(buffer.toString()).ignore();
  }

  /// 错误日志
  static void e(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer('[$tag] $message');
    if (error != null) buffer.write('\nError: $error');
    if (stackTrace != null) buffer.write('\n$stackTrace');

    if (kDebugMode) debugPrint('E/$tag: $message');
    writeErrorLog(buffer.toString(), stackTrace: stackTrace?.toString())
        .ignore();
  }

  /// 通用日志写入方法
  static Future<void> _writeLog(String logPath, String message,
      {String level = 'INFO'}) async {
    try {
      // 确保日志目录存在
      await AppPaths.ensureDirectoryExists(AppPaths.logDirectory);

      final logFile = File(logPath);
      final timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
      final logEntry = '[$timestamp] [$level] $message\n';

      // 检查文件大小，如果太大则轮转
      if (await logFile.exists()) {
        final fileSize = await logFile.length();
        if (fileSize > maxLogFileSize) {
          await _rotateLogFile(logPath);
        }
      }

      // 写入日志
      await logFile.writeAsString(logEntry, mode: FileMode.append);
    } catch (e) {
      debugPrint('写入日志失败: $e');
    }
  }

  /// 轮转日志文件
  static Future<void> _rotateLogFile(String logPath) async {
    try {
      final logFile = File(logPath);
      if (!await logFile.exists()) return;

      final directory = logFile.parent;
      final baseName = logFile.uri.pathSegments.last.split('.').first;
      final extension = logFile.uri.pathSegments.last.split('.').last;

      // 删除最旧的日志文件
      final oldestLogFile =
          File('${directory.path}/$baseName.${maxLogFiles - 1}.$extension');
      if (await oldestLogFile.exists()) {
        await oldestLogFile.delete();
      }

      // 重命名现有的日志文件
      for (int i = maxLogFiles - 2; i >= 1; i--) {
        final currentFile = File('${directory.path}/$baseName.$i.$extension');
        final nextFile =
            File('${directory.path}/$baseName.${i + 1}.$extension');
        if (await currentFile.exists()) {
          await currentFile.rename(nextFile.path);
        }
      }

      // 重命名当前日志文件
      final firstBackupFile = File('${directory.path}/$baseName.1.$extension');
      await logFile.rename(firstBackupFile.path);
    } catch (e) {
      debugPrint('轮转日志文件失败: $e');
    }
  }

  /// 获取日志文件列表
  static Future<List<File>> getLogFiles() async {
    try {
      final logDir = Directory(AppPaths.logDirectory);
      if (!await logDir.exists()) return [];

      final files = await logDir
          .list()
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      files
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      return files;
    } catch (e) {
      debugPrint('获取日志文件列表失败: $e');
      return [];
    }
  }

  /// 清理旧日志文件
  static Future<void> cleanupOldLogs({int daysToKeep = 30}) async {
    try {
      final logFiles = await getLogFiles();
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

      for (final file in logFiles) {
        final lastModified = await file.lastModified();
        if (lastModified.isBefore(cutoffDate)) {
          await file.delete();
          debugPrint('删除旧日志文件: ${file.path}');
        }
      }
    } catch (e) {
      debugPrint('清理旧日志文件失败: $e');
    }
  }

  /// 获取日志统计信息
  static Future<Map<String, dynamic>> getLogStats() async {
    try {
      final logFiles = await getLogFiles();
      int totalSize = 0;
      int totalLines = 0;

      for (final file in logFiles) {
        final stat = await file.stat();
        totalSize += stat.size;

        // 计算行数（简单估算）
        if (stat.size > 0) {
          final bytes = await file.readAsBytes();
          final content = utf8.decode(bytes, allowMalformed: true);
          totalLines += content.split('\n').length;
        }
      }

      return {
        'fileCount': logFiles.length,
        'totalSize': totalSize,
        'totalSizeFormatted': _formatFileSize(totalSize),
        'totalLines': totalLines,
        'logDirectory': AppPaths.logDirectory,
      };
    } catch (e) {
      debugPrint('获取日志统计信息失败: $e');
      return {
        'fileCount': 0,
        'totalSize': 0,
        'totalSizeFormatted': '0 B',
        'totalLines': 0,
        'logDirectory': AppPaths.logDirectory,
      };
    }
  }

  /// 格式化文件大小
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 导出所有日志到指定目录
  static Future<String?> exportLogs(String exportPath) async {
    try {
      final exportDir = Directory(exportPath);
      if (!await exportDir.exists()) {
        await exportDir.create(recursive: true);
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      // exportFileName 仅保留用于未来扩展 ZIP 导出，当前未使用

      // 这里可以实现ZIP压缩逻辑
      // 为了简化，我们先创建一个包含所有日志的文本文件
      final allLogsFile = File('${exportDir.path}/all_logs_$timestamp.txt');
      final logFiles = await getLogFiles();

      final buffer = StringBuffer();
      buffer.writeln('牙科诊所管理系统 - 日志导出');
      buffer.writeln(
          '导出时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
      buffer.writeln('=' * 80);
      buffer.writeln();

      for (final file in logFiles) {
        buffer.writeln('文件: ${file.path}');
        buffer.writeln(
            '修改时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(await file.lastModified())}');
        buffer.writeln('-' * 40);

        try {
          final bytes = await file.readAsBytes();
          final content = utf8.decode(bytes, allowMalformed: true);
          buffer.writeln(content);
        } catch (e) {
          buffer.writeln('读取文件失败: $e');
        }

        buffer.writeln();
        buffer.writeln('=' * 80);
        buffer.writeln();
      }

      await allLogsFile.writeAsString(buffer.toString());
      return allLogsFile.path;
    } catch (e) {
      debugPrint('导出日志失败: $e');
      return null;
    }
  }

  /// 初始化日志管理器
  static Future<void> initialize() async {
    try {
      // 确保日志目录存在
      await AppPaths.ensureDirectoryExists(AppPaths.logDirectory);

      // 写入启动日志
      await writeInfoLog('应用启动 - 日志管理器初始化完成');

      // 清理旧日志（可选）
      await cleanupOldLogs();

      debugPrint('日志管理器初始化完成');
    } catch (e) {
      debugPrint('日志管理器初始化失败: $e');
    }
  }
}

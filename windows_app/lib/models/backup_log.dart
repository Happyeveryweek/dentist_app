import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

class BackupLog {
  final DateTime backupDate;
  final String backupPath;
  final bool success;
  final String? errorMessage;

  BackupLog({
    required this.backupDate,
    required this.backupPath,
    required this.success,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'backupDate': backupDate.toIso8601String(),
      'backupPath': backupPath,
      'success': success,
      'errorMessage': errorMessage,
    };
  }

  factory BackupLog.fromJson(Map<String, dynamic> json) {
    return BackupLog(
      backupDate: DateTime.parse(json['backupDate']),
      backupPath: json['backupPath'],
      success: json['success'],
      errorMessage: json['errorMessage'],
    );
  }

  static Future<String> getLogFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return path.join(directory.path, 'backup_logs.json');
  }

  static Future<List<BackupLog>> getLogs() async {
    try {
      final logFilePath = await getLogFilePath();
      final file = File(logFilePath);
      
      if (!await file.exists()) {
        return [];
      }
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((json) => BackupLog.fromJson(json)).toList();
    } catch (e) {
      print('读取备份日志出错: $e');
      return [];
    }
  }

  static Future<void> addLog(BackupLog log) async {
    try {
      final logFilePath = await getLogFilePath();
      final file = File(logFilePath);
      
      List<BackupLog> logs = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.isNotEmpty) {
          final List<dynamic> jsonList = json.decode(content);
          logs = jsonList.map((json) => BackupLog.fromJson(json)).toList();
        }
      }
      
      logs.add(log);
      
      // 保留最近的100条记录
      if (logs.length > 100) {
        logs = logs.sublist(logs.length - 100);
      }
      
      final jsonList = logs.map((log) => log.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      print('添加备份日志出错: $e');
    }
  }

  static Future<DateTime?> getLastBackupDate() async {
    try {
      final logs = await getLogs();
      if (logs.isEmpty) {
        return null;
      }
      
      // 按日期排序，找出最近的成功备份
      logs.sort((a, b) => b.backupDate.compareTo(a.backupDate));
      for (var log in logs) {
        if (log.success) {
          return log.backupDate;
        }
      }
      
      return null;
    } catch (e) {
      print('获取最后备份日期出错: $e');
      return null;
    }
  }
  
  // 清空所有备份日志
  static Future<bool> clearAllLogs() async {
    try {
      final logFilePath = await getLogFilePath();
      final file = File(logFilePath);
      
      if (await file.exists()) {
        // 写入空数组，清空日志
        await file.writeAsString('[]');
        
        // 同时重置SettingsProvider中的lastBackupDate
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('lastBackupDate');
        
        return true;
      }
      return false;
    } catch (e) {
      print('清空备份日志出错: $e');
      return false;
    }
  }
}
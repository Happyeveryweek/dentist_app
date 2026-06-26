import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import '../utils/log_manager.dart';

/// 数据库结构检测日志模型
class DatabaseStructureLog {
  final int? id;
  final String dataSourceType;
  final DateTime detectionTime;
  final String status;
  final int requiredTables;
  final int missingTables;
  final int structureChanges;
  final List<String> errors;
  final Map<String, dynamic> details;
  final String summary;
  final DateTime createdAt;

  DatabaseStructureLog({
    this.id,
    required this.dataSourceType,
    required this.detectionTime,
    required this.status,
    required this.requiredTables,
    required this.missingTables,
    required this.structureChanges,
    required this.errors,
    required this.details,
    required this.summary,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 从Map创建对象
  factory DatabaseStructureLog.fromMap(Map<String, dynamic> map) {
    DateTime created = DateTime.now();
    if (map['created_at'] != null) {
      try {
        if (map['created_at'] is DateTime) {
          created = map['created_at'];
        } else {
          created = DateTimeFormatter.fromDbString(map['created_at']);
        }
      } catch (e) {
        LogManager.e(
            'DatabaseStructureLog', '解析created_at错误: ${map['created_at']}');
      }
    }

    // 安全解析detection_time
    DateTime detectionTime;
    try {
      if (map['detection_time'] is DateTime) {
        detectionTime = map['detection_time'];
      } else if (map['detection_time'] is String) {
        detectionTime = DateTimeFormatter.fromDbString(map['detection_time']);
      } else {
        detectionTime = DateTime.now();
      }
    } catch (e) {
      LogManager.e('DatabaseStructureLog',
          '解析detection_time错误: ${map['detection_time']}');
      detectionTime = DateTime.now();
    }

    // 安全解析errors字段
    List<String> errorsList;
    try {
      if (map['errors'] is List) {
        errorsList = List<String>.from(map['errors']);
      } else if (map['errors'] is String) {
        // 如果是JSON字符串，尝试解析
        final decoded = jsonDecode(map['errors']);
        if (decoded is List) {
          errorsList = List<String>.from(decoded);
        } else {
          errorsList = [];
        }
      } else {
        errorsList = [];
      }
    } catch (e) {
      LogManager.e('DatabaseStructureLog', '解析errors字段错误: ${map['errors字段']}');
      errorsList = [];
    }

    // 安全解析details字段
    Map<String, dynamic> detailsMap;
    try {
      if (map['details'] is Map) {
        detailsMap = Map<String, dynamic>.from(map['details']);
      } else if (map['details'] is String) {
        // 如果是JSON字符串，尝试解析
        final decoded = jsonDecode(map['details']);
        if (decoded is Map) {
          detailsMap = Map<String, dynamic>.from(decoded);
        } else {
          detailsMap = {};
        }
      } else {
        detailsMap = {};
      }
    } catch (e) {
      LogManager.e(
          'DatabaseStructureLog', '解析details字段错误: ${map['details字段']}');
      detailsMap = {};
    }

    return DatabaseStructureLog(
      id: map['id'],
      dataSourceType: map['data_source_type'] ?? '',
      detectionTime: detectionTime,
      status: map['status'] ?? '',
      requiredTables: map['required_tables'] ?? 0,
      missingTables: map['missing_tables'] ?? 0,
      structureChanges: map['structure_changes'] ?? 0,
      errors: errorsList,
      details: detailsMap,
      summary: map['summary'] ?? '',
      createdAt: created,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'data_source_type': dataSourceType,
      'detection_time': DateFormat('yyyy-MM-dd HH:mm:ss').format(detectionTime),
      'status': status,
      'required_tables': requiredTables,
      'missing_tables': missingTables,
      'structure_changes': structureChanges,
      'errors': errors,
      'details': details,
      'summary': summary,
      'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(createdAt),
    };
  }

  /// 创建副本
  DatabaseStructureLog copyWith({
    int? id,
    String? dataSourceType,
    DateTime? detectionTime,
    String? status,
    int? requiredTables,
    int? missingTables,
    int? structureChanges,
    List<String>? errors,
    Map<String, dynamic>? details,
    String? summary,
    DateTime? createdAt,
  }) {
    return DatabaseStructureLog(
      id: id ?? this.id,
      dataSourceType: dataSourceType ?? this.dataSourceType,
      detectionTime: detectionTime ?? this.detectionTime,
      status: status ?? this.status,
      requiredTables: requiredTables ?? this.requiredTables,
      missingTables: missingTables ?? this.missingTables,
      structureChanges: structureChanges ?? this.structureChanges,
      errors: errors ?? this.errors,
      details: details ?? this.details,
      summary: summary ?? this.summary,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// 生成摘要信息
  String generateSummary() {
    final tablesCreated = (details['tablesCreated'] as List?)?.length ?? 0;
    final tablesUpdated = (details['tablesUpdated'] as List?)?.length ?? 0;
    final columnsAdded = (details['columnsAdded'] as List?)?.length ?? 0;

    if (errors.isNotEmpty) {
      return '检测失败: ${errors.length} 个错误';
    } else if (tablesCreated > 0 || tablesUpdated > 0 || columnsAdded > 0) {
      return '检测完成: 创建${1}个表, 更新${1}个表, 添加${1}个字段';
    } else {
      return '检测完成: 数据库结构正常，无需更新';
    }
  }
}

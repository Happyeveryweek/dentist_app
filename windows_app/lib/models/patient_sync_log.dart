import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../utils/app_paths.dart';
import '../utils/datetime_formatter.dart';

class PatientSyncLog {
  final DateTime syncTime;
  final String entityType;
  final String entityName;
  final String action;
  final String status;
  final int? patientId;
  final int? recordId;
  final String? patientName;
  final dynamic medicalRecordNumber;
  final List<PatientSyncFieldChange> fieldChanges;
  final String? errorMessage;

  PatientSyncLog({
    required this.syncTime,
    this.entityType = 'patient',
    this.entityName = '患者基本信息',
    required this.action,
    required this.status,
    this.patientId,
    this.recordId,
    this.patientName,
    this.medicalRecordNumber,
    this.fieldChanges = const [],
    this.errorMessage,
  });

  bool get success => status == 'success';
  bool get hasFieldChanges => fieldChanges.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'syncTime': DateTimeFormatter.toDbString(syncTime),
      'entityType': entityType,
      'entityName': entityName,
      'action': action,
      'status': status,
      'patientId': patientId,
      'recordId': recordId,
      'patientName': patientName,
      'medicalRecordNumber': medicalRecordNumber,
      'fieldChanges': fieldChanges.map((item) => item.toJson()).toList(),
      'errorMessage': errorMessage,
    };
  }

  factory PatientSyncLog.fromJson(Map<String, dynamic> json) {
    return PatientSyncLog(
      syncTime: DateTimeFormatter.fromDbString(json['syncTime']),
      entityType: json['entityType']?.toString() ?? 'patient',
      entityName: json['entityName']?.toString() ?? '患者基本信息',
      action: json['action']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      patientId: json['patientId'] is int ? json['patientId'] as int : null,
      recordId: json['recordId'] is int
          ? json['recordId'] as int
          : json['patientId'] is int
              ? json['patientId'] as int
              : null,
      patientName: json['patientName']?.toString(),
      medicalRecordNumber: json['medicalRecordNumber'],
      fieldChanges: (json['fieldChanges'] is List)
          ? (json['fieldChanges'] as List)
              .whereType<Map<String, dynamic>>()
              .map(PatientSyncFieldChange.fromJson)
              .toList()
          : const [],
      errorMessage: json['errorMessage']?.toString(),
    );
  }

  static Future<String> getLogFilePath() async {
    try {
      return AppPaths.patientSyncLogPath;
    } catch (_) {
      final directory = await getApplicationDocumentsDirectory();
      return path.join(directory.path, 'patient_sync_logs.json');
    }
  }

  static Future<List<PatientSyncLog>> getLogs() async {
    try {
      final logFilePath = await getLogFilePath();
      final file = File(logFilePath);

      if (!await file.exists()) {
        return [];
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(content);
      return jsonList
          .whereType<Map<String, dynamic>>()
          .map(PatientSyncLog.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addLog(PatientSyncLog log) async {
    try {
      final logFilePath = await getLogFilePath();
      final file = File(logFilePath);
      final parent = file.parent;
      if (!await parent.exists()) {
        await parent.create(recursive: true);
      }

      var logs = <PatientSyncLog>[];
      if (await file.exists()) {
        final content = await file.readAsString();
        if (content.trim().isNotEmpty) {
          final List<dynamic> jsonList = json.decode(content);
          logs = jsonList
              .whereType<Map<String, dynamic>>()
              .map(PatientSyncLog.fromJson)
              .toList();
        }
      }

      logs.add(log);

      if (logs.length > 200) {
        logs = logs.sublist(logs.length - 200);
      }

      final jsonList = logs.map((item) => item.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (_) {}
  }

  static Future<bool> clearAllLogs() async {
    try {
      final logFilePath = await getLogFilePath();
      final file = File(logFilePath);

      if (await file.exists()) {
        await file.writeAsString('[]');
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

class PatientSyncFieldChange {
  final String field;
  final String label;
  final String? oldValue;
  final String? newValue;

  const PatientSyncFieldChange({
    required this.field,
    required this.label,
    this.oldValue,
    this.newValue,
  });

  Map<String, dynamic> toJson() {
    return {
      'field': field,
      'label': label,
      'oldValue': oldValue,
      'newValue': newValue,
    };
  }

  factory PatientSyncFieldChange.fromJson(Map<String, dynamic> json) {
    return PatientSyncFieldChange(
      field: json['field']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      oldValue: json['oldValue']?.toString(),
      newValue: json['newValue']?.toString(),
    );
  }
}

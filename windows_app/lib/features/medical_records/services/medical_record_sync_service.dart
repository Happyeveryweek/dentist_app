import 'package:mysql1/mysql1.dart';
import '../../patients/services/patient_sync_log_helper.dart';
import '../../../models/patient_sync_log.dart';
import '../../../utils/log_manager.dart';
import '../../../models/data_source.dart';

/// 病历同步服务
/// 负责处理 SQLite → MySQL 的数据同步逻辑（从 MedicalRecordProvider 中提取）
class MedicalRecordSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  MedicalRecordSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 判断是否需要同步（当前使用 SQLite 数据源时需要同步到 MySQL）
  bool get needsSync => getEffectiveDataSourceType().isSqliteDataSource;

  /// 尝试将SQLite中的病历记录同步到MySQL（非阻塞操作）
  Future<void> syncMedicalRecordToMySQL(
      Map<String, dynamic> recordMap, int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        final summary =
            'patient_id=${recordMap['patient_id'] ?? ''}, record_number=${recordMap['record_number'] ?? ''}';
        if (conn == null) {
          await LogManager.logSyncOperation(
            module: 'medical_record',
            action: 'upsert',
            table: 'patient_medical_records',
            status: 'skipped',
            recordId: recordId,
            summary: summary,
            error: 'mysql_connection_unavailable',
          );
          await _addPatientSyncLog(
            action: 'upsert',
            status: 'skipped',
            patientId: _intValue(recordMap['patient_id']),
            recordId: recordId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w(
              'MedicalRecordSyncService', 'MySQL连接不可用，跳过病历记录同步(id=$recordId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT * FROM patient_medical_records WHERE id = ? LIMIT 1',
            [recordId],
          );

          final normalizedRecordMap = Map<String, dynamic>.from(recordMap)
            ..remove('id');
          final fields = normalizedRecordMap.keys.toList();
          final values = fields.map((key) => normalizedRecordMap[key]).toList();

          if (existResult.isNotEmpty) {
            final fieldChanges = PatientSyncLogHelper.buildFieldChanges(
              oldValues: existResult.first.fields,
              newValues: normalizedRecordMap,
              fields: _medicalRecordSyncFields,
            );
            final setClause = fields.map((field) => '$field = ?').join(', ');
            final result = await conn.query(
              'UPDATE patient_medical_records SET $setClause WHERE id = ?',
              [...values, recordId],
            );
            await LogManager.logSyncOperation(
              module: 'medical_record',
              action: 'update',
              table: 'patient_medical_records',
              status: 'success',
              recordId: recordId,
              summary: summary,
            );
            await _addPatientSyncLog(
              action: 'update',
              status: 'success',
              patientId: _intValue(recordMap['patient_id']),
              recordId: recordId,
              fieldChanges: fieldChanges,
            );
            LogManager.i('MedicalRecordSyncService',
                '成功更新MySQL病历记录(id=$recordId)，影响行数: ${result.affectedRows}');
          } else {
            final fieldChanges = PatientSyncLogHelper.buildCreateChanges(
                normalizedRecordMap, _medicalRecordSyncFields);
            final insertFields = ['id', ...fields];
            final placeholders =
                List.filled(insertFields.length, '?').join(', ');
            final result = await conn.query(
              'INSERT INTO patient_medical_records (${insertFields.join(', ')}) VALUES ($placeholders)',
              [recordId, ...values],
            );
            await LogManager.logSyncOperation(
              module: 'medical_record',
              action: 'create',
              table: 'patient_medical_records',
              status: 'success',
              recordId: recordId,
              summary: summary,
            );
            await _addPatientSyncLog(
              action: 'create',
              status: 'success',
              patientId: _intValue(recordMap['patient_id']),
              recordId: recordId,
              fieldChanges: fieldChanges,
            );
            LogManager.i('MedicalRecordSyncService',
                '成功将病历记录(id=$recordId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          await LogManager.logSyncOperation(
            module: 'medical_record',
            action: 'upsert',
            table: 'patient_medical_records',
            status: 'failed',
            recordId: recordId,
            summary: summary,
            error: e.toString(),
          );
          await _addPatientSyncLog(
            action: 'upsert',
            status: 'failed',
            patientId: _intValue(recordMap['patient_id']),
            recordId: recordId,
            error: e.toString(),
          );
          LogManager.e('MedicalRecordSyncService', '同步病历记录到MySQL时出错', error: e);
        }
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'medical_record',
          action: 'upsert',
          table: 'patient_medical_records',
          status: 'failed',
          recordId: recordId,
          summary:
              'patient_id=${recordMap['patient_id'] ?? ''}, record_number=${recordMap['record_number'] ?? ''}',
          error: e.toString(),
        );
        await _addPatientSyncLog(
          action: 'upsert',
          status: 'failed',
          patientId: _intValue(recordMap['patient_id']),
          recordId: recordId,
          error: e.toString(),
        );
        LogManager.e('MedicalRecordSyncService', '病历记录同步到MySQL发生不可预期错误',
            error: e);
      }
    });
  }

  /// 尝试从MySQL删除病历记录（非阻塞操作）
  Future<void> syncDeleteMedicalRecordToMySQL(int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await LogManager.logSyncOperation(
            module: 'medical_record',
            action: 'delete',
            table: 'patient_medical_records',
            status: 'skipped',
            recordId: recordId,
            error: 'mysql_connection_unavailable',
          );
          await _addPatientSyncLog(
            action: 'delete',
            status: 'skipped',
            recordId: recordId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w('MedicalRecordSyncService',
              'MySQL连接不可用，跳过病历记录删除同步(id=$recordId)');
          return;
        }

        final existing = await conn.query(
          'SELECT patient_id FROM patient_medical_records WHERE id = ? LIMIT 1',
          [recordId],
        );
        final patientId = existing.isNotEmpty
            ? _intValue(existing.first['patient_id'])
            : null;
        final result = await conn.query(
          'DELETE FROM patient_medical_records WHERE id = ?',
          [recordId],
        );
        await LogManager.logSyncOperation(
          module: 'medical_record',
          action: 'delete',
          table: 'patient_medical_records',
          status: 'success',
          recordId: recordId,
        );
        await _addPatientSyncLog(
          action: 'delete',
          status: 'success',
          patientId: patientId,
          recordId: recordId,
        );
        LogManager.i('MedicalRecordSyncService',
            '成功从MySQL删除病历记录(id=$recordId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'medical_record',
          action: 'delete',
          table: 'patient_medical_records',
          status: 'failed',
          recordId: recordId,
          error: e.toString(),
        );
        await _addPatientSyncLog(
          action: 'delete',
          status: 'failed',
          recordId: recordId,
          error: e.toString(),
        );
        LogManager.e('MedicalRecordSyncService', '病历记录删除同步到MySQL时出错', error: e);
      }
    });
  }

  /// 尝试将SQLite中的病历模板同步到MySQL（非阻塞操作）
  Future<void> syncTemplateToMySQL(
      Map<String, dynamic> templateMap, int templateId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w('MedicalRecordSyncService',
              'MySQL连接不可用，跳过病历模板同步(id=$templateId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT id FROM medical_record_templates WHERE id = ? LIMIT 1',
            [templateId],
          );

          if (existResult.isNotEmpty) {
            final result = await conn.query('''
              UPDATE medical_record_templates SET
                name = ?, category = ?, description = ?,
                created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              templateMap['name'],
              templateMap['category'],
              templateMap['description'] ?? templateMap['content'] ?? '',
              templateMap['created_at'],
              templateMap['updated_at'],
              templateId,
            ]);
            LogManager.i('MedicalRecordSyncService',
                '成功更新MySQL病历模板(id=$templateId)，影响行数: ${result.affectedRows}');
          } else {
            final result = await conn.query('''
              INSERT INTO medical_record_templates
              (id, name, category, description, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              templateId,
              templateMap['name'],
              templateMap['category'],
              templateMap['description'] ?? templateMap['content'] ?? '',
              templateMap['created_at'],
              templateMap['updated_at'],
            ]);
            LogManager.i('MedicalRecordSyncService',
                '成功将病历模板(id=$templateId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          LogManager.e('MedicalRecordSyncService', '同步病历模板到MySQL时出错', error: e);
        }
      } catch (e) {
        LogManager.e('MedicalRecordSyncService', '病历模板同步到MySQL发生不可预期错误',
            error: e);
      }
    });
  }

  /// 尝试从MySQL删除病历模板（非阻塞操作）
  Future<void> syncDeleteTemplateToMySQL(int templateId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w('MedicalRecordSyncService',
              'MySQL连接不可用，跳过病历模板删除同步(id=$templateId)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM medical_record_templates WHERE id = ?',
            [templateId],
          );
          LogManager.i('MedicalRecordSyncService',
              '成功从MySQL删除病历模板(id=$templateId)，影响行数: ${result.affectedRows}');
        } catch (e) {
          LogManager.e(
              'MedicalRecordSyncService', '从MySQL删除病历模板(id=$templateId)时出错',
              error: e);
        }
      } catch (e) {
        LogManager.e('MedicalRecordSyncService', '病历模板删除同步到MySQL发生不可预期错误',
            error: e);
      }
    });
  }

  Future<void> _addPatientSyncLog({
    required String action,
    required String status,
    int? patientId,
    int? recordId,
    List<PatientSyncFieldChange> fieldChanges = const [],
    String? error,
  }) {
    return PatientSyncLog.addLog(
      PatientSyncLog(
        syncTime: DateTime.now(),
        entityType: 'medical_record',
        entityName: '病历记录',
        action: action,
        status: status,
        patientId: patientId,
        recordId: recordId,
        fieldChanges: fieldChanges,
        errorMessage: error,
      ),
    );
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse(value.toString());
  }

  static const Map<String, String> _medicalRecordSyncFields = {
    'patient_id': '患者ID',
    'record_number': '病历编号',
    'record_date': '病历日期',
    'doctor_name': '医生',
    'chief_complaint': '主诉',
    'present_illness': '现病史',
    'diagnosis': '诊断',
    'treatment_plan': '治疗计划',
    'treatment': '治疗过程',
    'notes': '备注',
  };
}

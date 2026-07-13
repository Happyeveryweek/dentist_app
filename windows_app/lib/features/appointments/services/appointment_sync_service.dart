import 'package:mysql1/mysql1.dart';
import '../../patients/services/patient_sync_log_helper.dart';
import '../../../models/patient_sync_log.dart';
import '../../../utils/log_manager.dart';

/// 预约同步服务
/// 负责处理 SQLite → MySQL 的数据同步逻辑（从 AppointmentProvider 中提取）
class AppointmentSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  AppointmentSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 判断是否需要同步（当前使用 SQLite 数据源时需要同步到 MySQL）
  bool get needsSync => getEffectiveDataSourceType() == 'sqlite';

  /// 尝试将SQLite中的预约同步到MySQL（非阻塞操作）
  Future<void> syncAppointmentToMySQL(
      Map<String, dynamic> appointmentMap, int appointmentId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await _addPatientSyncLog(
            action: 'upsert',
            status: 'skipped',
            patientId: _intValue(appointmentMap['patient_id']),
            recordId: appointmentId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w(
              'AppointmentSyncService', 'MySQL连接不可用，跳过预约同步(id=$appointmentId)');
          return;
        }

        try {
          // 检查是否已存在
          final existResult = await conn.query(
            'SELECT * FROM appointments WHERE id = ? LIMIT 1',
            [appointmentId],
          );

          if (existResult.isNotEmpty) {
            final fieldChanges = PatientSyncLogHelper.buildFieldChanges(
              oldValues: existResult.first.fields,
              newValues: appointmentMap,
              fields: _appointmentSyncFields,
            );
            // 更新操作
            final result = await conn.query('''
              UPDATE appointments SET
                patient_id = ?, appointment_date = ?, appointment_time = ?,
                status = ?, treatment_type = ?, notes = ?, cost = ?,
                created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              appointmentMap['patient_id'],
              appointmentMap['appointment_date'],
              appointmentMap['appointment_time'],
              appointmentMap['status'],
              appointmentMap['treatment_type'],
              appointmentMap['notes'],
              appointmentMap['cost'],
              appointmentMap['created_at'],
              appointmentMap['updated_at'],
              appointmentId,
            ]);
            await _addPatientSyncLog(
              action: 'update',
              status: 'success',
              patientId: _intValue(appointmentMap['patient_id']),
              recordId: appointmentId,
              fieldChanges: fieldChanges,
            );
            LogManager.i('AppointmentSyncService',
                '成功更新MySQL预约(id=$appointmentId)，影响行数: ${result.affectedRows}');
          } else {
            final fieldChanges = PatientSyncLogHelper.buildCreateChanges(
                appointmentMap, _appointmentSyncFields);
            // 插入操作
            final result = await conn.query('''
              INSERT INTO appointments
              (id, patient_id, appointment_date, appointment_time, status, treatment_type, notes, cost, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              appointmentId,
              appointmentMap['patient_id'],
              appointmentMap['appointment_date'],
              appointmentMap['appointment_time'],
              appointmentMap['status'],
              appointmentMap['treatment_type'],
              appointmentMap['notes'],
              appointmentMap['cost'],
              appointmentMap['created_at'],
              appointmentMap['updated_at'],
            ]);
            await _addPatientSyncLog(
              action: 'create',
              status: 'success',
              patientId: _intValue(appointmentMap['patient_id']),
              recordId: appointmentId,
              fieldChanges: fieldChanges,
            );
            LogManager.i('AppointmentSyncService',
                '成功将预约(id=$appointmentId)同步到MySQL（新建），插入ID: ${result.insertId}');
          }
        } catch (e) {
          await _addPatientSyncLog(
            action: 'upsert',
            status: 'failed',
            patientId: _intValue(appointmentMap['patient_id']),
            recordId: appointmentId,
            error: e.toString(),
          );
          LogManager.e('AppointmentSyncService', '同步预约到MySQL时出错', error: e);
        }
      } catch (e) {
        await _addPatientSyncLog(
          action: 'upsert',
          status: 'failed',
          patientId: _intValue(appointmentMap['patient_id']),
          recordId: appointmentId,
          error: e.toString(),
        );
        LogManager.e('AppointmentSyncService', '预约同步到MySQL发生不可预期错误', error: e);
      }
    });
  }

  /// 尝试从MySQL删除预约（非阻塞操作）
  Future<void> syncDeleteAppointmentToMySQL(int appointmentId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await _addPatientSyncLog(
            action: 'delete',
            status: 'skipped',
            recordId: appointmentId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w('AppointmentSyncService',
              'MySQL连接不可用，跳过预约删除同步(id=$appointmentId)');
          return;
        }

        try {
          final existing = await conn.query(
            'SELECT patient_id FROM appointments WHERE id = ? LIMIT 1',
            [appointmentId],
          );
          final patientId = existing.isNotEmpty
              ? _intValue(existing.first['patient_id'])
              : null;
          final result = await conn.query(
            'DELETE FROM appointments WHERE id = ?',
            [appointmentId],
          );
          await _addPatientSyncLog(
            action: 'delete',
            status: 'success',
            patientId: patientId,
            recordId: appointmentId,
          );
          LogManager.i('AppointmentSyncService',
              '成功从MySQL删除预约(id=$appointmentId)，影响行数: ${result.affectedRows}');
        } catch (e) {
          await _addPatientSyncLog(
            action: 'delete',
            status: 'failed',
            recordId: appointmentId,
            error: e.toString(),
          );
          LogManager.e(
              'AppointmentSyncService', '从MySQL删除预约(id=$appointmentId)时出错',
              error: e);
        }
      } catch (e) {
        LogManager.e('AppointmentSyncService', '预约删除同步到MySQL发生不可预期错误',
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
        entityType: 'appointment',
        entityName: '预约记录',
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

  static const Map<String, String> _appointmentSyncFields = {
    'patient_id': '患者ID',
    'appointment_date': '预约日期',
    'appointment_time': '预约时间',
    'status': '预约状态',
    'treatment_type': '治疗类型',
    'notes': '备注',
    'cost': '费用',
  };
}

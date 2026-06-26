import 'package:mysql1/mysql1.dart';
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
          LogManager.w(
              'AppointmentSyncService', 'MySQL连接不可用，跳过预约同步(id=$appointmentId)');
          return;
        }

        try {
          // 检查是否已存在
          final existResult = await conn.query(
            'SELECT id FROM appointments WHERE id = ? LIMIT 1',
            [appointmentId],
          );

          if (existResult.isNotEmpty) {
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
            LogManager.i('AppointmentSyncService',
                '成功更新MySQL预约(id=$appointmentId)，影响行数: ${result.affectedRows}');
          } else {
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
            LogManager.i('AppointmentSyncService',
                '成功将预约(id=$appointmentId)同步到MySQL（新建），插入ID: ${result.insertId}');
          }
        } catch (e) {
          LogManager.e('AppointmentSyncService', '同步预约到MySQL时出错', error: e);
        }
      } catch (e) {
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
          LogManager.w('AppointmentSyncService',
              'MySQL连接不可用，跳过预约删除同步(id=$appointmentId)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM appointments WHERE id = ?',
            [appointmentId],
          );
          LogManager.i('AppointmentSyncService',
              '成功从MySQL删除预约(id=$appointmentId)，影响行数: ${result.affectedRows}');
        } catch (e) {
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
}

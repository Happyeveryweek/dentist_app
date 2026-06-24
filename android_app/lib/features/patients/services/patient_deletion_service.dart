import '../../../models/database_models.dart';
import '../../../utils/database_operation_wrapper.dart';
import '../helpers/patient_cache_helper.dart';
import 'patient_initialization_service.dart';
import '../../../utils/app_logger.dart';

/// 患者删除编排服务
/// 职责：删除患者前清理关联预约、删除患者本身、清理缓存
class PatientDeletionService {
  Future<int> deletePatient({
    required int patientId,
    required PatientInitializationService initService,
    required DatabaseOperationWrapper dbWrapper,
    required PatientCacheHelper cacheHelper,
  }) async {
    return await dbWrapper.wrapOperation('deletePatient', () async {
      try {
        AppLogger.info('开始删除患者ID $patientId 及其关联预约');

        final appointments = await _getAppointmentsByPatientId(
          patientId,
          initService,
        );
        AppLogger.info('找到患者关联的预约记录: ${appointments.length}条');

        int appointmentsDeleted = 0;
        for (final appointment in appointments) {
          if (appointment.id != null) {
            try {
              final result = await _deleteAppointment(
                appointment.id!,
                initService,
              );
              appointmentsDeleted += result;
              AppLogger.info('已删除预约 ID: ${appointment.id}');
            } catch (e) {
              AppLogger.info('删除患者相关预约时出错 ID: ${appointment.id}, 错误: $e');
            }
          }
        }
        AppLogger.info('成功删除关联预约: $appointmentsDeleted条');

        final success = await initService.currentDataSource.deletePatient(
          patientId,
        );
        final result = success ? 1 : 0;

        cacheHelper.clearCache();

        return result;
      } catch (e) {
        AppLogger.info('删除患者错误: $e');
        rethrow;
      }
    });
  }

  Future<List<Appointment>> _getAppointmentsByPatientId(
    int patientId,
    PatientInitializationService initService,
  ) async {
    try {
      List<Map<String, dynamic>> maps;

      if (initService.dataSourceType == 'sqlite') {
        final db = initService.sqliteDataSource?.database;
        final result = await db?.query(
          'appointments',
          where: 'patient_id = ?',
          whereArgs: [patientId],
        );
        maps = result?.cast<Map<String, dynamic>>() ?? [];
      } else if (initService.dataSourceType == 'mysql') {
        AppLogger.info('MySQL 数据源暂不支持直接查询预约');
        maps = [];
      } else {
        throw Exception('不支持的数据库类型: ${initService.dataSourceType}');
      }

      return List.generate(maps.length, (i) => Appointment.fromMap(maps[i]));
    } catch (e) {
      AppLogger.info('获取患者预约错误: $e');
      return [];
    }
  }

  Future<int> _deleteAppointment(
    int id,
    PatientInitializationService initService,
  ) async {
    try {
      if (initService.dataSourceType == 'sqlite') {
        final db = initService.sqliteDataSource?.database;
        final result =
            await db?.delete(
              'appointments',
              where: 'id = ?',
              whereArgs: [id],
            ) ??
            0;
        AppLogger.info('SQLite删除预约成功，ID: $id, 影响行数: $result');
        return result;
      } else if (initService.dataSourceType == 'mysql') {
        AppLogger.info('MySQL 数据源暂不支持删除预约');
        return 0;
      } else {
        throw Exception('不支持的数据库类型: ${initService.dataSourceType}');
      }
    } catch (e) {
      AppLogger.info('删除预约错误: $e');
      rethrow;
    }
  }
}

import 'package:dentist_app_windows/config/app_defaults.dart';
import 'package:dentist_app_windows/models/app_module.dart';
import 'package:dentist_app_windows/models/appointment_status.dart';
import 'package:dentist_app_windows/models/appointment.dart';
import 'package:dentist_app_windows/models/data_source.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('数据源和模式只接受稳定存储值', () {
    expect(DataSourceType.tryParse('sqlite'), DataSourceType.sqlite);
    expect(DataSourceMode.tryParse('modular'), DataSourceMode.modular);
    expect(DataSourceType.tryParse('unknown'), isNull);
    expect(DataSourceMode.tryParse('unknown'), isNull);
  });

  test('模块定义覆盖导航模块，并保留病历历史配置键', () {
    expect(AppModule.tryParse('medical_records'), AppModule.medicalRecords);
    expect(AppModule.medicalRecords.dataSourceConfigKey, 'medical');
    expect(AppModule.patients.dataSourceConfigKey, 'patients');
  });

  test('预约状态兼容既有中文值并序列化为稳定英文值', () {
    for (final status in AppointmentStatus.values) {
      expect(AppointmentStatus.tryParse(status.storageValue), status);
      expect(AppointmentStatus.tryParse(status.displayName), status);
      expect(
        AppointmentStatus.normalizeStorageValue(status.displayName),
        status.storageValue,
      );
    }
    expect(AppointmentStatus.tryParse('未知状态'), isNull);
  });

  test('预约模型将历史中文状态规范为稳定存储值', () {
    final appointment = Appointment.fromMap({
      'id': 1,
      'patient_id': 1,
      'appointment_date': '2026-07-20 09:00:00',
      'appointment_time': '09:00:00',
      'status': '已完成',
      'created_at': '2026-07-20 09:00:00',
      'updated_at': '2026-07-20 09:00:00',
    });

    expect(appointment.status, AppointmentStatus.completed.storageValue);
    expect(appointment.toMap()['status'],
        AppointmentStatus.completed.storageValue);
  });

  test('MySQL 默认端口有唯一配置入口', () {
    expect(MySqlConnectionPolicy.defaultPort, 3306);
  });
}

import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../providers/patient_provider.dart';
import '../utils/log_manager.dart';
import 'appointment_data_source.dart';

/// SQLite 预约数据源实现
class SqliteAppointmentDataSource implements AppointmentDataSource {
  final Database _database;
  PatientProvider? _patientProvider;

  SqliteAppointmentDataSource(this._database);

  @override
  void setPatientProvider(PatientProvider patientProvider) {
    _patientProvider = patientProvider;
  }

  @override
  Future<List<Appointment>> getAllAppointments() async {
    final result = await _database.query(
      'appointments',
      orderBy: 'appointment_date DESC',
    );

    return await _convertResultsToAppointments(result);
  }

  @override
  Future<Appointment?> getAppointmentById(int id) async {
    final result = await _database.query(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (result.isEmpty) return null;

    final appointments = await _convertResultsToAppointments(result);
    return appointments.isNotEmpty ? appointments.first : null;
  }

  @override
  Future<int> createAppointment(Appointment appointment) async {
    final map = appointment.toMap();
    map.remove('id'); // 移除ID，让数据库自动生成

    // 确保appointment_time字段有值
    if (!map.containsKey('appointment_time') ||
        map['appointment_time'] == null) {
      // 从appointment_date中提取时间部分
      map['appointment_time'] =
          _extractTimeFromDateTime(appointment.appointmentDate);
    }

    return await _database.insert('appointments', map);
  }

  @override
  Future<bool> updateAppointment(Appointment appointment) async {
    final map = appointment.toMap();

    // 确保appointment_time字段有值
    if (!map.containsKey('appointment_time') ||
        map['appointment_time'] == null) {
      // 从appointment_date中提取时间部分
      map['appointment_time'] =
          _extractTimeFromDateTime(appointment.appointmentDate);
    }

    final count = await _database.update(
      'appointments',
      map,
      where: 'id = ?',
      whereArgs: [appointment.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteAppointment(int id) async {
    final count = await _database.delete(
      'appointments',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final result = await _database.query(
      'appointments',
      where: 'appointment_date BETWEEN ? AND ?',
      whereArgs: [
        DateFormat('yyyy-MM-dd HH:mm:ss').format(startOfDay),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(endOfDay),
      ],
      orderBy: 'appointment_date ASC',
    );

    return await _convertResultsToAppointments(result);
  }

  @override
  Future<List<Appointment>> getAppointmentsByPatient(int patientId) async {
    final result = await _database.query(
      'appointments',
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'appointment_date DESC',
    );

    return await _convertResultsToAppointments(result);
  }

  @override
  Future<List<Appointment>> getAppointmentsByDoctor(String doctorName) async {
    // 先通过PatientProvider获取该医生的所有患者ID
    List<int> patientIds = [];
    final patientProvider = _patientProvider;
    if (patientProvider != null) {
      try {
        final patients = await patientProvider.getAllPatientsInDataSource(
          'sqlite',
        );
        patientIds = patients
            .where((p) => p.doctor == doctorName)
            .map((p) => p.id)
            .whereType<int>()
            .toList();
      } catch (e) {
        LogManager.e('SqliteAppointmentDataSource', '获取医生患者列表失败', error: e);
        return [];
      }
    }

    if (patientIds.isEmpty) {
      return [];
    }

    final placeholders = patientIds.map((_) => '?').join(',');
    final result = await _database.query(
      'appointments',
      where: 'patient_id IN ($placeholders)',
      whereArgs: patientIds,
      orderBy: 'appointment_date DESC',
    );

    return await _convertResultsToAppointments(result);
  }

  @override
  Future<List<Appointment>> getTodayAppointments({String? doctorName}) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    List<String> conditions = [];
    List<dynamic> args = [];

    // 添加日期条件
    conditions.add('appointment_date BETWEEN ? AND ?');
    args.addAll([
      DateFormat('yyyy-MM-dd HH:mm:ss').format(startOfDay),
      DateFormat('yyyy-MM-dd HH:mm:ss').format(endOfDay),
    ]);

    // 如果指定了医生，通过PatientProvider获取该医生的患者ID
    final patientProvider = _patientProvider;
    if (doctorName != null &&
        doctorName.isNotEmpty &&
        patientProvider != null) {
      try {
        final patients = await patientProvider.getAllPatientsInDataSource(
          'sqlite',
        );
        final patientIds = patients
            .where((p) => p.doctor == doctorName)
            .map((p) => p.id)
            .whereType<int>()
            .toList();

        if (patientIds.isEmpty) {
          return [];
        }

        final placeholders = patientIds.map((_) => '?').join(',');
        conditions.add('patient_id IN ($placeholders)');
        args.addAll(patientIds);
      } catch (e) {
        LogManager.e('SqliteAppointmentDataSource', '获取医生患者列表失败', error: e);
        return [];
      }
    }

    final result = await _database.query(
      'appointments',
      where: conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'appointment_date ASC',
    );

    return await _convertResultsToAppointments(result);
  }

  // 辅助方法：从DateTime中提取时间字符串 (HH:MM:SS)
  String _extractTimeFromDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 辅助方法：将查询结果转换为Appointment对象列表
  Future<List<Appointment>> _convertResultsToAppointments(
      List<Map<String, dynamic>> results) async {
    final appointments = <Appointment>[];

    for (final row in results) {
      try {
        final appointment = Appointment.fromMap(row);

        // 通过PatientProvider获取患者信息
        final patientId = appointment.patientId;
        final patientProvider = _patientProvider;
        if (patientId != null && patientProvider != null) {
          try {
            final patient = await patientProvider.getPatient(
              patientId,
              effectiveDataSourceType: 'sqlite',
            );
            if (patient != null) {
              appointment.patient = patient;
            }
          } catch (e) {
            LogManager.e(
                'SqliteAppointmentDataSource', '获取患者信息失败 (ID: $patientId)',
                error: e);
          }
        }

        appointments.add(appointment);
      } catch (e) {
        LogManager.e('SqliteAppointmentDataSource', '转换预约数据失败', error: e);
      }
    }

    return appointments;
  }
}

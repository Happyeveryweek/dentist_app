import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/database_models.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/app_logger.dart';

// 抽象预约数据源接口
abstract class AppointmentDataSource {
  Future<List<Appointment>> getAllAppointments({String? doctorFilter});
  Future<Appointment?> getAppointmentById(int id);
  Future<int> createAppointment(Appointment appointment);
  Future<bool> updateAppointment(Appointment appointment);
  Future<bool> deleteAppointment(int id);
  Future<List<Appointment>> searchAppointments(
    String keyword, {
    String? doctorFilter,
  });
  Future<int> getAppointmentsCount({String? doctorFilter});
  Future<List<Appointment>> getAppointmentsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  });
  Future<List<Appointment>> getAppointmentsByPatientId(
    int patientId, {
    String? doctorFilter,
  });
}

// SQLite预约数据源实现
class SqliteAppointmentDataSource implements AppointmentDataSource {
  final Database _database;

  SqliteAppointmentDataSource(this._database);

  // 提供database getter以保持向后兼容
  Database get database => _database;

  @override
  Future<List<Appointment>> getAllAppointments({String? doctorFilter}) async {
    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
    ''';

    List<dynamic> params = [];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' WHERE p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final result = await _database.rawQuery(query, params);
    return result.map((e) => Appointment.fromMap(e)).toList();
  }

  @override
  Future<Appointment?> getAppointmentById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM appointments WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    return Appointment.fromMap(result.first);
  }

  @override
  Future<int> createAppointment(Appointment appointment) async {
    return await _database.insert('appointments', appointment.toMap());
  }

  @override
  Future<bool> updateAppointment(Appointment appointment) async {
    final count = await _database.update(
      'appointments',
      appointment.toMap(),
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
  Future<List<Appointment>> searchAppointments(
    String keyword, {
    String? doctorFilter,
  }) async {
    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE (p.name LIKE ? OR a.treatment_type LIKE ? OR a.notes LIKE ?)
    ''';

    List<dynamic> params = ['%$keyword%', '%$keyword%', '%$keyword%'];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' AND p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final result = await _database.rawQuery(query, params);
    return result.map((e) => Appointment.fromMap(e)).toList();
  }

  @override
  Future<int> getAppointmentsCount({String? doctorFilter}) async {
    String query = '''
      SELECT COUNT(*) as count 
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
    ''';

    List<dynamic> params = [];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' WHERE p.doctor = ?';
      params.add(doctorFilter);
    }

    final result = await _database.rawQuery(query, params);
    final row = result.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<List<Appointment>> getAppointmentsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  }) async {
    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.appointment_date BETWEEN ? AND ?
    ''';

    List<dynamic> params = [
      DateTimeFormatter.toDbString(startDate).split(' ')[0],
      DateTimeFormatter.toDbString(endDate).split(' ')[0],
    ];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' AND p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final result = await _database.rawQuery(query, params);
    return result.map((e) => Appointment.fromMap(e)).toList();
  }

  @override
  Future<List<Appointment>> getAppointmentsByPatientId(
    int patientId, {
    String? doctorFilter,
  }) async {
    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.patient_id = ?
    ''';

    List<dynamic> params = [patientId];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' AND p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final result = await _database.rawQuery(query, params);
    return result.map((e) => Appointment.fromMap(e)).toList();
  }
}

// MySQL预约数据源实现（使用动态连接获取）
class MySqlAppointmentDataSource implements AppointmentDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlAppointmentDataSource.withConnectionGetter(this._getConnection);

  // 辅助方法：处理MySQL行数据转换
  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];

      // 处理日期字段 - 使用统一格式
      if (field == 'appointment_date' ||
          field == 'created_at' ||
          field == 'updated_at') {
        if (value is DateTime) {
          // 如果MySQL返回的是UTC时间，转换为本地时间
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        // 处理Blob字段，特别是文本字段
        if (field == 'doctor' ||
            field == 'treatment_type' ||
            field == 'notes' ||
            field == 'patient_name') {
          try {
            final bytes = value.toBytes();
            if (bytes.isNotEmpty) {
              final stringValue = utf8.decode(bytes, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            AppLogger.info('Blob转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else if (value is Uint8List) {
        // 处理Uint8List类型
        if (field == 'doctor' ||
            field == 'treatment_type' ||
            field == 'notes' ||
            field == 'patient_name') {
          try {
            if (value.isNotEmpty) {
              final stringValue = utf8.decode(value, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            AppLogger.info('Uint8List转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else {
        map[field] = value;
      }
    }
    return map;
  }

  @override
  Future<List<Appointment>> getAllAppointments({String? doctorFilter}) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
    ''';

    List<dynamic> params = [];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' WHERE p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final results = await connection.query(query, params);
    return results
        .map((row) => Appointment.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<Appointment?> getAppointmentById(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      '''
      SELECT a.*, p.name as patient_name
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.id = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return Appointment.fromMap(_convertMySqlRow(row));
  }

  @override
  Future<int> createAppointment(Appointment appointment) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      '''
      INSERT INTO appointments (patient_id, appointment_date, appointment_time, treatment_type, 
                               status, notes, cost, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''',
      [
        appointment.patientId,
        DateTimeFormatter.toDbString(appointment.appointmentDate).split(' ')[0],
        DateTimeFormatter.toDbString(
          appointment.appointmentDate,
        ).split(' ')[1], // 提取时间部分
        appointment.treatmentType,
        appointment.status,
        appointment.notes,
        appointment.cost,
      ],
    );

    return result.insertId!;
  }

  @override
  Future<bool> updateAppointment(Appointment appointment) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      '''
      UPDATE appointments 
      SET patient_id = ?, appointment_date = ?, appointment_time = ?, treatment_type = ?, 
          status = ?, notes = ?, cost = ?, updated_at = NOW()
      WHERE id = ?
    ''',
      [
        appointment.patientId,
        DateTimeFormatter.toDbString(appointment.appointmentDate).split(' ')[0],
        DateTimeFormatter.toDbString(
          appointment.appointmentDate,
        ).split(' ')[1], // 提取时间部分
        appointment.treatmentType,
        appointment.status,
        appointment.notes,
        appointment.cost,
        appointment.id,
      ],
    );

    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deleteAppointment(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      'DELETE FROM appointments WHERE id = ?',
      [id],
    );
    return result.affectedRows! > 0;
  }

  @override
  Future<List<Appointment>> searchAppointments(
    String keyword, {
    String? doctorFilter,
  }) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE (p.name LIKE ? OR a.treatment_type LIKE ? OR a.notes LIKE ?)
    ''';

    List<dynamic> params = ['%$keyword%', '%$keyword%', '%$keyword%'];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' AND p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final results = await connection.query(query, params);
    return results
        .map((row) => Appointment.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<int> getAppointmentsCount({String? doctorFilter}) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = '''
      SELECT COUNT(*) as count 
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
    ''';

    List<dynamic> params = [];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' WHERE p.doctor = ?';
      params.add(doctorFilter);
    }

    final results = await connection.query(query, params);
    final row = results.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<List<Appointment>> getAppointmentsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  }) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    // 将DateTime转换为统一格式
    final startDateStr = DateTimeFormatter.toDbString(startDate);
    final endDateStr = DateTimeFormatter.toDbString(endDate);

    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.appointment_date BETWEEN ? AND ?
    ''';

    List<dynamic> params = [startDateStr, endDateStr];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' AND p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final results = await connection.query(query, params);
    return results
        .map((row) => Appointment.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<List<Appointment>> getAppointmentsByPatientId(
    int patientId, {
    String? doctorFilter,
  }) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = '''
      SELECT a.*, p.name as patient_name, p.doctor as patient_doctor
      FROM appointments a
      LEFT JOIN patients p ON a.patient_id = p.id
      WHERE a.patient_id = ?
    ''';

    List<dynamic> params = [patientId];

    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      query += ' AND p.doctor = ?';
      params.add(doctorFilter);
    }

    query += ' ORDER BY a.appointment_date DESC, a.appointment_time DESC';

    final results = await connection.query(query, params);
    return results
        .map((row) => Appointment.fromMap(_convertMySqlRow(row)))
        .toList();
  }
}

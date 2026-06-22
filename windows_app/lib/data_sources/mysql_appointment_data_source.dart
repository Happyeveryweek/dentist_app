import 'package:mysql1/mysql1.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../providers/patient_provider.dart';
import '../utils/datetime_formatter.dart';
import 'base_mysql_data_source.dart';
import 'appointment_data_source.dart';

/// MySQL 预约数据源实现
class MySqlAppointmentDataSource extends BaseMySqlDataSource implements AppointmentDataSource {
  PatientProvider? _patientProvider;

  MySqlAppointmentDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );

  @override
  void setPatientProvider(PatientProvider patientProvider) {
    _patientProvider = patientProvider;
  }

  @override
  Future<List<Appointment>> getAllAppointments() async {
    final result = await executeQuery('SELECT * FROM appointments ORDER BY appointment_date DESC');
    return await _convertResultsToAppointments(result);
  }

  @override
  Future<Appointment?> getAppointmentById(int id) async {
    final result = await executeQuery('SELECT * FROM appointments WHERE id = ?', [id]);
    if (result.isEmpty) return null;
    final appointments = await _convertResultsToAppointments(result);
    return appointments.isNotEmpty ? appointments.first : null;
  }

  @override
  Future<int> createAppointment(Appointment appointment) async {
    final result = await executeQuery('''
      INSERT INTO appointments (patient_id, appointment_date, appointment_time, status, treatment_type, notes, cost, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''', [
      appointment.patient_id,
      DateFormat('yyyy-MM-dd HH:mm:ss').format(appointment.appointment_date),
      _extractTimeFromDateTime(appointment.appointment_date),
      appointment.status,
      appointment.treatment_type,
      appointment.notes,
      appointment.cost,
    ]);
    return result.insertId ?? 0;
  }

  @override
  Future<bool> updateAppointment(Appointment appointment) async {
    final result = await executeQuery('''
      UPDATE appointments 
      SET patient_id = ?, appointment_date = ?, appointment_time = ?, status = ?, treatment_type = ?, notes = ?, cost = ?, updated_at = NOW()
      WHERE id = ?
    ''', [
      appointment.patient_id,
      DateFormat('yyyy-MM-dd HH:mm:ss').format(appointment.appointment_date),
      _extractTimeFromDateTime(appointment.appointment_date),
      appointment.status,
      appointment.treatment_type,
      appointment.notes,
      appointment.cost,
      appointment.id,
    ]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteAppointment(int id) async {
    final result = await executeQuery('DELETE FROM appointments WHERE id = ?', [id]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    final result = await executeQuery('SELECT * FROM appointments WHERE DATE(appointment_date) = ? ORDER BY appointment_date ASC', [dateString]);
    return await _convertResultsToAppointments(result);
  }

  @override
  Future<List<Appointment>> getAppointmentsByPatient(int patientId) async {
    final result = await executeQuery('SELECT * FROM appointments WHERE patient_id = ? ORDER BY appointment_date DESC', [patientId]);
    return await _convertResultsToAppointments(result);
  }

  @override
  Future<List<Appointment>> getAppointmentsByDoctor(String doctorName) async {
    List<int> patientIds = [];
    if (_patientProvider != null) {
      try {
        final patients = await _patientProvider!.getAllPatients();
        patientIds = patients.where((p) => p.doctor == doctorName).map((p) => p.id!).toList();
      } catch (_) {}
    }
    if (patientIds.isEmpty) return [];
    final placeholders = patientIds.map((_) => '?').join(',');
    final result = await executeQuery('SELECT * FROM appointments WHERE patient_id IN ($placeholders) ORDER BY appointment_date DESC', patientIds);
    return await _convertResultsToAppointments(result);
  }

  @override
  Future<List<Appointment>> getTodayAppointments({String? doctorName}) async {
    final dateString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    List<String> conditions = ['DATE(appointment_date) = ?'];
    List<dynamic> args = [dateString];
    
    if (doctorName != null && doctorName.isNotEmpty && _patientProvider != null) {
      try {
        final patients = await _patientProvider!.getAllPatients();
        final patientIds = patients.where((p) => p.doctor == doctorName).map((p) => p.id!).toList();
        if (patientIds.isEmpty) return [];
        conditions.add('patient_id IN (${patientIds.map((_) => "?").join(",")})');
        args.addAll(patientIds);
      } catch (_) {}
    }
    final result = await executeQuery('SELECT * FROM appointments WHERE ${conditions.join(' AND ')} ORDER BY appointment_date ASC', args);
    return await _convertResultsToAppointments(result);
  }

  @override
  Future<int> getAppointmentsCount({String? searchQuery}) async {
    String sql = 'SELECT COUNT(*) as count FROM appointments';
    List<dynamic> args = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      List<int> patientIds = [];
      if (_patientProvider != null) {
        try { patientIds = await _patientProvider!.searchPatientIds(searchQuery); } catch (_) {}
      }
      List<String> cond = ['treatment_type LIKE ?', 'notes LIKE ?', 'status LIKE ?'];
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
      if (patientIds.isNotEmpty) {
        cond.add('patient_id IN (${patientIds.map((_) => "?").join(",")})');
        args.addAll(patientIds);
      }
      sql += ' WHERE ${cond.join(" OR ")}';
    }
    
    final result = await executeQuery(sql, args);
    final dynamic v = result.first['count'] ?? result.first[0];
    return v is int ? v : (v as BigInt).toInt();
  }

  @override
  Future<List<Appointment>> getPaginatedAppointments({
    int page = 1, int pageSize = 10, String sortBy = 'appointment_date',
    String sortOrder = 'DESC', String? searchQuery, DateTime? filterDate, String? filterDoctor,
  }) async {
    final offset = (page - 1) * pageSize;
    List<String> conditions = [];
    List<dynamic> args = [];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      List<int> pIds = [];
      if (_patientProvider != null) { try { pIds = await _patientProvider!.searchPatientIds(searchQuery); } catch (_) {} }
      List<String> sCond = ['treatment_type LIKE ?', 'notes LIKE ?', 'status LIKE ?'];
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
      if (pIds.isNotEmpty) { sCond.add('patient_id IN (${pIds.map((_) => "?").join(",")})'); args.addAll(pIds); }
      conditions.add('(${sCond.join(" OR ")})');
    }
    
    if (filterDate != null) {
      conditions.add('DATE(appointment_date) = ?');
      args.add(DateFormat('yyyy-MM-dd').format(filterDate));
    }
    
    if (filterDoctor != null && filterDoctor.trim().isNotEmpty && _patientProvider != null) {
      try {
        final patients = await _patientProvider!.getAllPatients();
        final pIds = patients.where((p) => p.doctor == filterDoctor).map((p) => p.id!).toList();
        if (pIds.isEmpty) return [];
        conditions.add('patient_id IN (${pIds.map((_) => "?").join(",")})');
        args.addAll(pIds);
      } catch (_) {}
    }
    
    final where = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    final result = await executeQuery('SELECT * FROM appointments $where ORDER BY $sortBy $sortOrder LIMIT ?, ?', [...args, offset, pageSize]);
    return await _convertResultsToAppointments(result);
  }

  @override
  Future<Map<String, dynamic>> getAppointmentStatistics() async {
    final totalRes = await executeQuery('SELECT COUNT(*) as total FROM appointments');
    final int total = (totalRes.first['total'] is BigInt) ? (totalRes.first['total'] as BigInt).toInt() : (totalRes.first['total'] ?? 0);
    
    final statusRes = await executeQuery('SELECT status, COUNT(*) as count FROM appointments GROUP BY status');
    final statusStats = <String, int>{};
    for (final row in statusRes) {
      statusStats[row['status']?.toString() ?? ''] = (row['count'] is BigInt) ? (row['count'] as BigInt).toInt() : (row['count'] ?? 0);
    }
    
    final todayRes = await executeQuery('SELECT COUNT(*) as count FROM appointments WHERE DATE(appointment_date) = CURDATE()');
    final int todayCount = (todayRes.first['count'] is BigInt) ? (todayRes.first['count'] as BigInt).toInt() : (todayRes.first['count'] ?? 0);
    
    return {'totalAppointments': total, 'statusStatistics': statusStats, 'todayAppointments': todayCount};
  }

  String _extractTimeFromDateTime(DateTime dateTime) => 
      '${dateTime.hour.toString().padLeft(2, "0")}:${dateTime.minute.toString().padLeft(2, "0")}:${dateTime.second.toString().padLeft(2, "0")}';

  Future<List<Appointment>> _convertResultsToAppointments(dynamic results) async {
    final appointments = <Appointment>[];
    for (final row in results) {
      try {
        final map = convertRowToMap(row);
        final appointment = Appointment.fromMap(map);
        if (appointment.patient_id != null && _patientProvider != null) {
          try {
            final patient = await _patientProvider!.getPatient(appointment.patient_id!);
            if (patient != null) appointment.patient = patient;
          } catch (_) {}
        }
        appointments.add(appointment);
      } catch (_) {}
    }
    return appointments;
  }
}

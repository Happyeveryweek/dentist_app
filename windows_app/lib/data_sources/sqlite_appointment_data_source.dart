import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import '../models/appointment.dart';
import '../providers/patient_provider.dart';
import '../utils/datetime_formatter.dart';
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
    if (!map.containsKey('appointment_time') || map['appointment_time'] == null) {
      // 从appointment_date中提取时间部分
      map['appointment_time'] = _extractTimeFromDateTime(appointment.appointment_date);
    }
    
    return await _database.insert('appointments', map);
  }

  @override
  Future<bool> updateAppointment(Appointment appointment) async {
    final map = appointment.toMap();
    
    // 确保appointment_time字段有值
    if (!map.containsKey('appointment_time') || map['appointment_time'] == null) {
      // 从appointment_date中提取时间部分
      map['appointment_time'] = _extractTimeFromDateTime(appointment.appointment_date);
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
    if (_patientProvider != null) {
      try {
        final patients = await _patientProvider!.getAllPatients();
        patientIds = patients
            .where((p) => p.doctor == doctorName)
            .map((p) => p.id!)
            .toList();
      } catch (e) {
        print('获取医生患者列表失败: $e');
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
    if (doctorName != null && doctorName.isNotEmpty && _patientProvider != null) {
      try {
        final patients = await _patientProvider!.getAllPatients();
        final patientIds = patients
            .where((p) => p.doctor == doctorName)
            .map((p) => p.id!)
            .toList();
        
        if (patientIds.isEmpty) {
          return [];
        }
        
        final placeholders = patientIds.map((_) => '?').join(',');
        conditions.add('patient_id IN ($placeholders)');
        args.addAll(patientIds);
      } catch (e) {
        print('获取医生患者列表失败: $e');
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

  @override
  Future<int> getAppointmentsCount({String? searchQuery}) async {
    if (searchQuery == null || searchQuery.trim().isEmpty) {
      final result = await _database.rawQuery('SELECT COUNT(*) FROM appointments');
      return Sqflite.firstIntValue(result) ?? 0;
    }
    
    // 先通过PatientProvider搜索患者ID
    List<int> patientIds = [];
    if (_patientProvider != null) {
      try {
        patientIds = await _patientProvider!.searchPatientIds(searchQuery);
      } catch (e) {
        print('搜索患者ID失败: $e');
      }
    }
    
    // 构建查询条件
    List<String> conditions = [];
    List<dynamic> args = [];
    
    // 添加预约字段搜索条件
    conditions.add('(treatment_type LIKE ? OR notes LIKE ? OR status LIKE ?)');
    args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    
    // 添加患者ID搜索条件
    if (patientIds.isNotEmpty) {
      final placeholders = patientIds.map((_) => '?').join(',');
      conditions.add('patient_id IN ($placeholders)');
      args.addAll(patientIds);
    }
    
    final whereClause = conditions.join(' OR ');
    final result = await _database.rawQuery('SELECT COUNT(*) FROM appointments WHERE $whereClause', args);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<Appointment>> getPaginatedAppointments({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'appointment_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? filterDate,
    String? filterDoctor,
  }) async {
    final offset = (page - 1) * pageSize;
    List<String> conditions = [];
    List<dynamic> whereArgs = [];
    
    // 处理搜索查询
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      // 先通过PatientProvider搜索患者ID
      List<int> patientIds = [];
      if (_patientProvider != null) {
        try {
          patientIds = await _patientProvider!.searchPatientIds(searchQuery);
        } catch (e) {
          print('搜索患者ID失败: $e');
        }
      }
      
      List<String> searchConditions = [];
      // 添加预约字段搜索条件
      searchConditions.add('(treatment_type LIKE ? OR notes LIKE ? OR status LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
      
      // 添加患者ID搜索条件
      if (patientIds.isNotEmpty) {
        final placeholders = patientIds.map((_) => '?').join(',');
        searchConditions.add('patient_id IN ($placeholders)');
        whereArgs.addAll(patientIds);
      }
      
      conditions.add('(${searchConditions.join(' OR ')})');
    }
    
    // 处理日期过滤
    if (filterDate != null) {
      final startOfDay = DateTime(filterDate.year, filterDate.month, filterDate.day);
      final endOfDay = DateTime(filterDate.year, filterDate.month, filterDate.day, 23, 59, 59);
      conditions.add('appointment_date BETWEEN ? AND ?');
      whereArgs.addAll([
        DateFormat('yyyy-MM-dd HH:mm:ss').format(startOfDay),
        DateFormat('yyyy-MM-dd HH:mm:ss').format(endOfDay),
      ]);
    }
    
    // 处理医生过滤
    if (filterDoctor != null && filterDoctor.trim().isNotEmpty && _patientProvider != null) {
      try {
        final patients = await _patientProvider!.getAllPatients();
        final patientIds = patients
            .where((p) => p.doctor == filterDoctor)
            .map((p) => p.id!)
            .toList();
        
        if (patientIds.isEmpty) {
          return [];
        }
        
        final placeholders = patientIds.map((_) => '?').join(',');
        conditions.add('patient_id IN ($placeholders)');
        whereArgs.addAll(patientIds);
      } catch (e) {
        print('获取医生患者列表失败: $e');
        return [];
      }
    }
    
    final whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
    
    final sql = '''
      SELECT * FROM appointments
      $whereClause
      ORDER BY $sortBy $sortOrder
      LIMIT $pageSize OFFSET $offset
    ''';
    
    final result = await _database.rawQuery(sql, whereArgs);
    return await _convertResultsToAppointments(result.cast<Map<String, dynamic>>());
  }

  @override
  Future<Map<String, dynamic>> getAppointmentStatistics() async {
    final totalResult = await _database.rawQuery('SELECT COUNT(*) as total FROM appointments');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;
    
    final statusResult = await _database.rawQuery('''
      SELECT status, COUNT(*) as count 
      FROM appointments 
      GROUP BY status
    ''');
    
    final statusStats = <String, int>{};
    for (final row in statusResult) {
      statusStats[row['status'] as String] = row['count'] as int;
    }
    
    final todayResult = await _database.rawQuery('''
      SELECT COUNT(*) as count 
      FROM appointments 
      WHERE date(appointment_date) = date('now')
    ''');
    final todayCount = Sqflite.firstIntValue(todayResult) ?? 0;
    
    return {
      'totalAppointments': total,
      'statusStatistics': statusStats,
      'todayAppointments': todayCount,
    };
  }

  // 辅助方法：从DateTime中提取时间字符串 (HH:MM:SS)
  String _extractTimeFromDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 辅助方法：将查询结果转换为Appointment对象列表
  Future<List<Appointment>> _convertResultsToAppointments(List<Map<String, dynamic>> results) async {
    final appointments = <Appointment>[];
    
    for (final row in results) {
      try {
        final appointment = Appointment.fromMap(row);
        
        // 通过PatientProvider获取患者信息
        if (appointment.patient_id != null && _patientProvider != null) {
          try {
            final patient = await _patientProvider!.getPatient(appointment.patient_id!);
            if (patient != null) {
              appointment.patient = patient;
            }
          } catch (e) {
            print('获取患者信息失败 (ID: ${appointment.patient_id}): $e');
          }
        }
        
        appointments.add(appointment);
      } catch (e) {
        print('转换预约数据失败: $e');
      }
    }
    
    return appointments;
  }
}

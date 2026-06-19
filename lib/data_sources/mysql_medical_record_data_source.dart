import 'package:mysql1/mysql1.dart';
import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';
import 'base_mysql_data_source.dart';
import 'medical_record_data_source.dart';

/// MySQL 病历数据源实现
class MySqlMedicalRecordDataSource extends BaseMySqlDataSource implements MedicalRecordDataSource {
  final String? _doctorName;
  final bool _isAdmin;

  MySqlMedicalRecordDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    String? doctorName,
    bool isAdmin = false,
    Future<void> Function()? reconnectCallback,
  })  : _doctorName = doctorName,
        _isAdmin = isAdmin,
        super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );

  @override
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId) async {
    try {
      final results = await executeQuery(
        'SELECT * FROM patient_medical_records WHERE patient_id = ? ORDER BY record_date DESC, created_at DESC',
        [patientId],
      );

      return results.map((row) => PatientMedicalRecord.fromMap(convertRowToMap(row))).toList();
    } catch (e) {
      print('MySQL获取患者病历记录时出错: $e');
      rethrow;
    }
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecordById(int id) async {
    try {
      final results = await executeQuery('SELECT * FROM patient_medical_records WHERE id = ?', [id]);
      if (results.isEmpty) return null;
      return PatientMedicalRecord.fromMap(convertRowToMap(results.first));
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    try {
      final map = record.toMap();
      map.remove('id');
      final fields = map.keys.join(', ');
      final placeholders = List.filled(map.length, '?').join(', ');

      final result = await executeQuery(
        'INSERT INTO patient_medical_records ($fields) VALUES ($placeholders)',
        map.values.toList(),
      );
      return result.insertId ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    try {
      final map = record.toMap();
      final id = map.remove('id');
      final setClause = map.keys.map((key) => '$key = ?').join(', ');
      final values = map.values.toList()..add(id);

      String query = 'UPDATE patient_medical_records SET $setClause WHERE id = ?';
      if (!_isAdmin && _doctorName != null && _doctorName!.isNotEmpty) {
        query += ' AND created_by_doctor = ?';
        values.add(_doctorName);
      }

      final result = await executeQuery(query, values);
      return result.affectedRows! > 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> deleteMedicalRecord(int id) async {
    try {
      String query = 'DELETE FROM patient_medical_records WHERE id = ?';
      List<dynamic> params = [id];
      if (!_isAdmin && _doctorName != null && _doctorName!.isNotEmpty) {
        query += ' AND created_by_doctor = ?';
        params.add(_doctorName);
      }
      final result = await executeQuery(query, params);
      return result.affectedRows! > 0;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query, {int? patientId}) async {
    String sql = 'SELECT * FROM patient_medical_records WHERE (chief_complaint LIKE ? OR present_illness LIKE ? OR diagnosis LIKE ? OR notes LIKE ?)';
    List<dynamic> params = List.filled(4, '%$query%');
    if (patientId != null) {
      sql += ' AND patient_id = ?';
      params.add(patientId);
    }
    sql += ' ORDER BY record_date DESC, created_at DESC';
    final results = await executeQuery(sql, params);
    return results.map((row) => PatientMedicalRecord.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<int> getMedicalRecordsCount(int patientId) async {
    final results = await executeQuery('SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?', [patientId]);
    final dynamic count = results.first[0];
    return count is int ? count : (count as BigInt).toInt();
  }

  @override
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId, required int page, required int pageSize,
    String? searchQuery, String? sortField, bool sortAscending = false,
  }) async {
    final offset = (page - 1) * pageSize;
    String where = 'WHERE patient_id = ?';
    List<dynamic> params = [patientId];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where += ' AND (chief_complaint LIKE ? OR present_illness LIKE ? OR diagnosis LIKE ?)';
      params.addAll(List.filled(3, '%$searchQuery%'));
    }
    final countRes = await executeQuery('SELECT COUNT(*) as count FROM patient_medical_records $where', params);
    final dynamic totalCount = countRes.first[0];
    int total = totalCount is int ? totalCount : (totalCount as BigInt).toInt();

    String order = sortField != null && sortField.isNotEmpty ? '$sortField ${sortAscending ? "ASC" : "DESC"}' : 'record_date DESC, created_at DESC';
    final dataRes = await executeQuery('SELECT * FROM patient_medical_records $where ORDER BY $order LIMIT ? OFFSET ?', [...params, pageSize, offset]);

    return {
      'records': dataRes.map((row) => PatientMedicalRecord.fromMap(convertRowToMap(row))).toList(),
      'totalCount': total,
      'totalPages': (total / pageSize).ceil(),
      'currentPage': page,
    };
  }

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) async {
    final results = await executeQuery('SELECT * FROM medical_record_templates WHERE category = ? AND is_active = 1 ORDER BY sort_order ASC, name ASC', [category]);
    return results.map((row) => MedicalRecordTemplate.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<MedicalRecordTemplate?> getTemplateById(int id) async {
    final results = await executeQuery('SELECT * FROM medical_record_templates WHERE id = ?', [id]);
    if (results.isEmpty) return null;
    return MedicalRecordTemplate.fromMap(convertRowToMap(results.first));
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    final maxRes = await executeQuery('SELECT MAX(sort_order) as max_sort FROM medical_record_templates WHERE category = ?', [template.category]);
    int nextSort = (maxRes.first[0] as int? ?? 0) + 1;
    final map = template.copyWith(sortOrder: nextSort).toMap()..remove('id');
    final result = await executeQuery('INSERT INTO medical_record_templates (${map.keys.join(", ")}) VALUES (${List.filled(map.length, "?").join(", ")})', map.values.toList());
    return result.insertId ?? 0;
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    final map = template.toMap();
    final id = map.remove('id');
    final setClause = map.keys.map((key) => '$key = ?').join(', ');
    final result = await executeQuery('UPDATE medical_record_templates SET $setClause WHERE id = ?', [...map.values, id]);
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deleteTemplate(int id) async {
    final templateRes = await executeQuery('SELECT * FROM medical_record_templates WHERE id = ?', [id]);
    if (templateRes.isEmpty) throw Exception('模板不存在');
    final name = templateRes.first[2]; // name
    await executeQuery('DELETE FROM medical_record_templates WHERE parent_name = ?', [name]);
    final result = await executeQuery('DELETE FROM medical_record_templates WHERE id = ?', [id]);
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> initializeDefaultTemplates() async {
    // MySQL 批量初始化逻辑...
    return true;
  }

  @override
  Future<bool> hasTemplateData() async {
    final res = await executeQuery('SELECT COUNT(*) as count FROM medical_record_templates');
    return (res.first[0] as int? ?? 0) > 0;
  }

  @override
  Future<List<MedicalRecordTemplate>> searchTemplates(String category, String query) async {
    final res = await executeQuery('SELECT * FROM medical_record_templates WHERE category = ? AND (name LIKE ? OR description LIKE ?) AND is_active = 1 ORDER BY sort_order ASC, name ASC', [category, '%$query%', '%$query%']);
    return res.map((row) => MedicalRecordTemplate.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<Map<String, List<String>>> getDiseaseOptions(String category) async {
    final templates = await getTemplatesByCategory(category);
    final Map<String, List<String>> options = {};
    for (var t in templates) {
      if (t.isMainType) { if (!options.containsKey(t.name)) options[t.name] = []; }
      else { if (!options.containsKey(t.parentName)) options[t.parentName!] = []; options[t.parentName!]!.add(t.name); }
    }
    return options;
  }

  @override
  Future<bool> hasRelatedRecords(int templateId) async => false;

  @override
  Future<List<PatientMedicalRecord>> getDoctorMedicalRecords(String doctorName, {int? patientId}) async {
    String sql = 'SELECT * FROM patient_medical_records WHERE created_by_doctor = ?';
    List<dynamic> params = [doctorName];
    if (patientId != null) { sql += ' AND patient_id = ?'; params.add(patientId); }
    sql += ' ORDER BY record_date DESC, created_at DESC';
    final res = await executeQuery(sql, params);
    return res.map((row) => PatientMedicalRecord.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<int> getDoctorMedicalRecordsCount(String doctorName, {int? patientId}) async {
    String sql = 'SELECT COUNT(*) as count FROM patient_medical_records WHERE created_by_doctor = ?';
    List<dynamic> params = [doctorName];
    if (patientId != null) { sql += ' AND patient_id = ?'; params.add(patientId); }
    final res = await executeQuery(sql, params);
    final dynamic count = res.first[0];
    return count is int ? count : (count as BigInt).toInt();
  }

  @override
  Future<void> ensureTablesExist() async {
    await executeQuery('''
      CREATE TABLE IF NOT EXISTS medical_record_templates (
        id INT AUTO_INCREMENT PRIMARY KEY,
        category VARCHAR(50) NOT NULL,
        name VARCHAR(100) NOT NULL,
        parent_name VARCHAR(100),
        description TEXT,
        is_active TINYINT NOT NULL DEFAULT 1,
        sort_order INT NOT NULL DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    ''');

    await executeQuery('''
      CREATE TABLE IF NOT EXISTS patient_medical_records (
        id INT AUTO_INCREMENT PRIMARY KEY,
        patient_id INT NOT NULL,
        record_date DATE NOT NULL,
        chief_complaint TEXT,
        present_illness TEXT,
        systemic_disease_history TEXT,
        oral_disease_history TEXT,
        allergy_history TEXT,
        dental_diseases TEXT,
        oral_examination TEXT,
        selected_dental_condition_date DATE,
        diagnosis TEXT,
        treatment_plan TEXT,
        notes TEXT,
        doctor_name VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (patient_id) REFERENCES patients (id)
      )
    ''');
  }
}

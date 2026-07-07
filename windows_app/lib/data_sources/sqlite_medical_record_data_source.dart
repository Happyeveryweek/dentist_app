import 'package:sqflite/sqflite.dart';
import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';
import '../utils/log_manager.dart';
import 'medical_record_data_source.dart';

/// SQLite 病历数据源实现
class SqliteMedicalRecordDataSource implements MedicalRecordDataSource {
  final Database _database;
  final String? _doctorName;
  final bool _isAdmin;

  // 辅助方法：安全检查医生名称
  bool get _hasDoctorName {
    final doctorName = _doctorName;
    return doctorName != null && doctorName.isNotEmpty;
  }

  SqliteMedicalRecordDataSource(this._database,
      {String? doctorName, bool isAdmin = false})
      : _doctorName = doctorName,
        _isAdmin = isAdmin;

  @override
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(
      int patientId) async {
    try {
      final maps = await _database.query(
        'patient_medical_records',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'record_date DESC, created_at DESC',
      );
      return List.generate(
          maps.length, (i) => PatientMedicalRecord.fromMap(maps[i]));
    } catch (e) {
      LogManager.e(
          'SqliteMedicalRecordDataSource', 'getPatientMedicalRecords 出错',
          error: e);
      return [];
    }
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecordById(int id) async {
    try {
      final maps = await _database
          .query('patient_medical_records', where: 'id = ?', whereArgs: [id]);
      return maps.isNotEmpty ? PatientMedicalRecord.fromMap(maps.first) : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    return await _database.insert('patient_medical_records', record.toMap());
  }

  @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    if (record.id == null) throw Exception('必须提供ID');
    String where = 'id = ?';
    List<dynamic> args = [record.id];
    if (!_isAdmin && _hasDoctorName) {
      where += ' AND created_by_doctor = ?';
      args.add(_doctorName);
    }
    final result = await _database.update(
        'patient_medical_records', record.toMap(),
        where: where, whereArgs: args);
    return result > 0;
  }

  @override
  Future<bool> deleteMedicalRecord(int id) async {
    try {
      await _database.transaction((txn) async {
        String where = 'id = ?';
        List<dynamic> args = [id];
        if (!_isAdmin && _hasDoctorName) {
          where += ' AND created_by_doctor = ?';
          args.add(_doctorName);
        }
        await txn.delete('patient_medical_records',
            where: where, whereArgs: args);
      });
      return true;
    } catch (e) {
      LogManager.e('SqliteMedicalRecordDataSource', '删除病历记录时出错', error: e);
      return false;
    }
  }

  @override
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query,
      {int? patientId}) async {
    String where =
        '(record_number LIKE ? OR chief_complaint LIKE ? OR present_illness LIKE ? OR diagnosis LIKE ? OR doctor_name LIKE ?)';
    List<dynamic> args = List.filled(5, '%$query%');
    if (patientId != null) {
      where += ' AND patient_id = ?';
      args.add(patientId);
    }
    final results = await _database.rawQuery(
        'SELECT * FROM patient_medical_records WHERE $where ORDER BY record_date DESC',
        args);
    return results.map((data) => PatientMedicalRecord.fromMap(data)).toList();
  }

  @override
  Future<int> getMedicalRecordsCount(int patientId) async {
    final res = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?',
        [patientId]);
    return res.first['count'] as int;
  }

  @override
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
  }) async {
    final offset = (page - 1) * pageSize;
    String where = 'patient_id = ?';
    List<dynamic> args = [patientId];
    if (searchQuery != null && searchQuery.isNotEmpty) {
      where +=
          ' AND (record_number LIKE ? OR chief_complaint LIKE ? OR present_illness LIKE ? OR diagnosis LIKE ? OR doctor_name LIKE ?)';
      args.addAll(List.filled(5, '%$searchQuery%'));
    }
    final countRes = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patient_medical_records WHERE $where',
        args);
    int total = countRes.first['count'] as int;
    String orderBy = sortField != null && sortField.isNotEmpty
        ? '$sortField ${sortAscending ? "ASC" : "DESC"}'
        : 'record_date DESC, created_at DESC';
    final maps = await _database.rawQuery(
        'SELECT * FROM patient_medical_records WHERE $where ORDER BY $orderBy LIMIT $pageSize OFFSET $offset',
        args);
    return {
      'records': maps.map((m) => PatientMedicalRecord.fromMap(m)).toList(),
      'totalCount': total
    };
  }

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(
      String category) async {
    final maps = await _database.query('medical_record_templates',
        where: 'category = ? AND is_active = 1',
        whereArgs: [category],
        orderBy: 'sort_order ASC, name ASC');
    return maps.map((m) => MedicalRecordTemplate.fromMap(m)).toList();
  }

  @override
  Future<MedicalRecordTemplate?> getTemplateById(int id) async {
    final maps = await _database
        .query('medical_record_templates', where: 'id = ?', whereArgs: [id]);
    return maps.isNotEmpty ? MedicalRecordTemplate.fromMap(maps.first) : null;
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    final maxRes = await _database.rawQuery(
        'SELECT MAX(sort_order) as max_sort FROM medical_record_templates WHERE category = ?',
        [template.category]);
    int nextSort = (maxRes.first['max_sort'] as int? ?? 0) + 1;
    return await _database.insert('medical_record_templates',
        template.copyWith(sortOrder: nextSort).toMap());
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    final res = await _database.update(
        'medical_record_templates', template.toMap(),
        where: 'id = ?', whereArgs: [template.id]);
    return res > 0;
  }

  @override
  Future<bool> deleteTemplate(int id) async {
    final res = await _database
        .query('medical_record_templates', where: 'id = ?', whereArgs: [id]);
    if (res.isEmpty) return false;
    await _database.transaction((txn) async {
      await txn.delete('medical_record_templates',
          where: 'parent_name = ?', whereArgs: [res.first['name']]);
      await txn
          .delete('medical_record_templates', where: 'id = ?', whereArgs: [id]);
    });
    return true;
  }

  @override
  Future<bool> initializeDefaultTemplates() async {
    return false;
  }

  @override
  Future<bool> hasTemplateData() async {
    final res = await _database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='medical_record_templates'");
    if (res.isEmpty) return false;
    final count = await _database
        .rawQuery('SELECT COUNT(*) as count FROM medical_record_templates');
    return (count.first['count'] as int) > 0;
  }

  @override
  Future<bool> hasRelatedRecords(int templateId) async => false;

  @override
  Future<List<MedicalRecordTemplate>> searchTemplates(
      String category, String query) async {
    final maps = await _database.query('medical_record_templates',
        where:
            'category = ? AND is_active = 1 AND (name LIKE ? OR description LIKE ? OR parent_name LIKE ?)',
        whereArgs: [category, '%$query%', '%$query%', '%$query%'],
        orderBy: 'sort_order ASC, name ASC');
    return maps.map((m) => MedicalRecordTemplate.fromMap(m)).toList();
  }

  @override
  Future<Map<String, List<String>>> getDiseaseOptions(String category) async {
    final templates = await getTemplatesByCategory(category);
    final Map<String, List<String>> options = {};
    for (var t in templates) {
      if (t.isMainType) {
        if (!options.containsKey(t.name)) options[t.name] = [];
      } else {
        final parentName = t.parentName;
        if (parentName == null) continue;
        options.putIfAbsent(parentName, () => []).add(t.name);
      }
    }
    return options;
  }

  @override
  Future<List<PatientMedicalRecord>> getDoctorMedicalRecords(String doctorName,
      {int? patientId}) async {
    String where = 'created_by_doctor = ?';
    List<dynamic> args = [doctorName];
    if (patientId != null) {
      where += ' AND patient_id = ?';
      args.add(patientId);
    }
    final maps = await _database.query('patient_medical_records',
        where: where,
        whereArgs: args,
        orderBy: 'record_date DESC, created_at DESC');
    return maps.map((m) => PatientMedicalRecord.fromMap(m)).toList();
  }

  @override
  Future<int> getDoctorMedicalRecordsCount(String doctorName,
      {int? patientId}) async {
    String where = 'created_by_doctor = ?';
    List<dynamic> args = [doctorName];
    if (patientId != null) {
      where += ' AND patient_id = ?';
      args.add(patientId);
    }
    final res = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patient_medical_records WHERE $where',
        args);
    return res.first['count'] as int;
  }

  @override
  Future<void> ensureTablesExist() async {
    // 检查 medical_record_templates 表是否存在
    final templateResult = await _database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='medical_record_templates'");

    if (templateResult.isEmpty) {
      await _database.execute('''
        CREATE TABLE medical_record_templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category VARCHAR(50) NOT NULL,
          name VARCHAR(100) NOT NULL,
          parent_name VARCHAR(100),
          description TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
    }

    // 检查 patient_medical_records 表是否存在
    final recordResult = await _database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='patient_medical_records'");

    if (recordResult.isEmpty) {
      await _database.execute('''
        CREATE TABLE patient_medical_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL,
          record_date TEXT NOT NULL,
          chief_complaint TEXT,
          present_illness TEXT,
          systemic_disease_history TEXT,
          oral_disease_history TEXT,
          allergy_history TEXT,
          dental_diseases TEXT,
          oral_examination TEXT,
          selected_dental_condition_date TEXT,
          diagnosis TEXT,
          treatment_plan TEXT,
          notes TEXT,
          doctor_name VARCHAR(100),
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (patient_id) REFERENCES patients (id)
        )
      ''');
    }
  }
}

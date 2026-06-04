import 'package:sqflite/sqflite.dart';

import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';
import 'medical_record_data_source.dart';

class SqliteMedicalRecordDataSource implements MedicalRecordDataSource {
  final Database _database;

  SqliteMedicalRecordDataSource(this._database);

  Database get database => _database;

  @override
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM patient_medical_records WHERE patient_id = ? ORDER BY record_date DESC, created_at DESC',
      [patientId],
    );
    return result.map((e) => PatientMedicalRecord.fromMap(e)).toList();
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecord(int recordId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM patient_medical_records WHERE id = ?',
      [recordId],
    );
    if (result.isEmpty) return null;
    return PatientMedicalRecord.fromMap(result.first);
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    return _database.insert('patient_medical_records', record.toMap());
  }

  @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    final count = await _database.update(
      'patient_medical_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteMedicalRecord(int recordId) async {
    final count = await _database.delete(
      'patient_medical_records',
      where: 'id = ?',
      whereArgs: [recordId],
    );
    return count > 0;
  }

  @override
  Future<bool> hasMedicalRecords(int patientId) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?',
      [patientId],
    );
    return ((result.first['count'] as int?) ?? 0) > 0;
  }

  @override
  Future<List<MedicalRecordTemplate>> getMedicalRecordTemplates() async {
    final result = await _database.rawQuery(
      'SELECT * FROM medical_record_templates WHERE is_active = 1 ORDER BY category ASC, sort_order ASC, name ASC',
    );
    return result.map((e) => MedicalRecordTemplate.fromMap(e)).toList();
  }

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) async {
    final result = await _database.rawQuery(
      'SELECT * FROM medical_record_templates WHERE category = ? AND is_active = 1 ORDER BY sort_order ASC, name ASC',
      [category],
    );
    return result.map((e) => MedicalRecordTemplate.fromMap(e)).toList();
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    return _database.insert('medical_record_templates', template.toMap());
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    final count = await _database.update(
      'medical_record_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteTemplate(int templateId) async {
    final count = await _database.delete(
      'medical_record_templates',
      where: 'id = ?',
      whereArgs: [templateId],
    );
    return count > 0;
  }

}

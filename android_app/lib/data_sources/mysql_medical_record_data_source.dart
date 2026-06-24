import 'package:mysql1/mysql1.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';
import '../utils/datetime_formatter.dart';
import 'medical_record_data_source.dart';

class MySqlMedicalRecordDataSource implements MedicalRecordDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlMedicalRecordDataSource.withConnectionGetter(this._getConnection);

  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      final value = row[field];
      if (field == 'created_at' ||
          field == 'updated_at' ||
          field == 'record_date') {
        if (value is DateTime) {
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        try {
          final bytes = value.toBytes();
          map[field] =
              bytes.isNotEmpty ? utf8.decode(bytes, allowMalformed: true) : '';
        } catch (_) {
          map[field] = '';
        }
      } else if (value is Uint8List) {
        try {
          map[field] =
              value.isNotEmpty ? utf8.decode(value, allowMalformed: true) : '';
        } catch (_) {
          map[field] = '';
        }
      } else {
        map[field] = value;
      }
    }
    return map;
  }

  MySqlConnection _connection() {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    return connection;
  }

  @override
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(
    int patientId,
  ) async {
    final results = await _connection().query(
      'SELECT * FROM patient_medical_records WHERE patient_id = ? ORDER BY record_date DESC, created_at DESC',
      [patientId],
    );
    return results
        .map((row) => PatientMedicalRecord.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecord(int recordId) async {
    final results = await _connection().query(
      'SELECT * FROM patient_medical_records WHERE id = ?',
      [recordId],
    );
    if (results.isEmpty) return null;
    return PatientMedicalRecord.fromMap(_convertMySqlRow(results.first));
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    final result = await _connection().query(
      '''
      INSERT INTO patient_medical_records (
        patient_id, record_number, record_date, chief_complaint, present_illness,
        past_medical_history, past_dental_history, allergy_history, oral_examination,
        diagnosis, treatment_plan, notes, doctor_name, created_by_doctor,
        selected_dental_condition_date, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''',
      [
        record.patientId,
        record.recordNumber,
        DateTimeFormatter.toDbString(record.recordDate),
        record.chiefComplaint,
        record.presentIllness,
        record.pastMedicalHistory,
        record.pastDentalHistory,
        record.allergyHistory,
        record.oralExamination,
        record.diagnosis,
        record.treatmentPlan,
        record.notes,
        record.doctorName,
        record.createdByDoctor,
        record.selectedDentalConditionDate,
      ],
    );
    return result.insertId ?? 0;
  }

  @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    final result = await _connection().query(
      '''
      UPDATE patient_medical_records SET
        patient_id = ?, record_number = ?, record_date = ?, chief_complaint = ?,
        present_illness = ?, past_medical_history = ?, past_dental_history = ?,
        allergy_history = ?, oral_examination = ?, diagnosis = ?, treatment_plan = ?,
        notes = ?, doctor_name = ?, created_by_doctor = ?, selected_dental_condition_date = ?,
        updated_at = NOW()
      WHERE id = ?
    ''',
      [
        record.patientId,
        record.recordNumber,
        DateTimeFormatter.toDbString(record.recordDate),
        record.chiefComplaint,
        record.presentIllness,
        record.pastMedicalHistory,
        record.pastDentalHistory,
        record.allergyHistory,
        record.oralExamination,
        record.diagnosis,
        record.treatmentPlan,
        record.notes,
        record.doctorName,
        record.createdByDoctor,
        record.selectedDentalConditionDate,
        record.id,
      ],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteMedicalRecord(int recordId) async {
    final result = await _connection().query(
      'DELETE FROM patient_medical_records WHERE id = ?',
      [recordId],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> hasMedicalRecords(int patientId) async {
    final results = await _connection().query(
      'SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?',
      [patientId],
    );
    return ((results.first['count'] as int?) ?? 0) > 0;
  }

  @override
  Future<List<MedicalRecordTemplate>> getMedicalRecordTemplates() async {
    final results = await _connection().query('''
      SELECT * FROM medical_record_templates
      WHERE is_active = 1
      ORDER BY category ASC, sort_order ASC, name ASC
    ''');
    return results
        .map((row) => MedicalRecordTemplate.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(
    String category,
  ) async {
    final results = await _connection().query(
      '''
      SELECT * FROM medical_record_templates
      WHERE category = ? AND is_active = 1
      ORDER BY sort_order ASC, name ASC
    ''',
      [category],
    );
    return results
        .map((row) => MedicalRecordTemplate.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    final result = await _connection().query(
      '''
      INSERT INTO medical_record_templates (
        category, name, parent_name, description, is_active, sort_order,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''',
      [
        template.category,
        template.name,
        template.parentName,
        template.description,
        template.isActive ? 1 : 0,
        template.sortOrder,
      ],
    );
    return result.insertId ?? 0;
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    final result = await _connection().query(
      '''
      UPDATE medical_record_templates SET
        category = ?, name = ?, parent_name = ?, description = ?,
        is_active = ?, sort_order = ?, updated_at = NOW()
      WHERE id = ?
    ''',
      [
        template.category,
        template.name,
        template.parentName,
        template.description,
        template.isActive ? 1 : 0,
        template.sortOrder,
        template.id,
      ],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteTemplate(int templateId) async {
    final result = await _connection().query(
      'DELETE FROM medical_record_templates WHERE id = ?',
      [templateId],
    );
    return (result.affectedRows ?? 0) > 0;
  }
}

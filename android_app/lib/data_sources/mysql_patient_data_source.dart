import 'package:mysql1/mysql1.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/database_models.dart';
import '../utils/pinyin_util.dart';
import '../utils/datetime_formatter.dart';
import 'patient_data_source.dart';
import '../utils/app_logger.dart';

class MySqlPatientDataSource implements PatientDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlPatientDataSource.withConnectionGetter(this._getConnection);

  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];

      if (field == 'created_at' ||
          field == 'updated_at' ||
          field == 'first_visit_date') {
        if (value is DateTime) {
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        if (field == 'name' ||
            field == 'phone' ||
            field == 'identification_number' ||
            field == 'address') {
          try {
            final bytes = value.toBytes();
            map[field] =
                bytes.isNotEmpty
                    ? utf8.decode(bytes, allowMalformed: true)
                    : '';
          } catch (e) {
            AppLogger.info('Blob转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else if (value is Uint8List) {
        if (field == 'name' ||
            field == 'phone' ||
            field == 'identification_number' ||
            field == 'address') {
          try {
            map[field] =
                value.isNotEmpty
                    ? utf8.decode(value, allowMalformed: true)
                    : '';
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
  Future<List<Patient>> getAllPatients() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query('''
      SELECT id, medical_record_number, name, name_pinyin, name_initials, age, gender, phone,
             identification_number, doctor, address, address_pinyin, first_visit_date,
             dental_condition, treatment_items, total_cost, created_at, updated_at
      FROM patients
      ORDER BY created_at DESC
    ''');

    return results
        .map((row) => Patient.fromMap(_convertMySqlRow(row)))
        .toList();
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      '''
      SELECT id, medical_record_number, name, name_pinyin, name_initials, age, gender, phone,
             identification_number, doctor, address, address_pinyin, first_visit_date,
             dental_condition, treatment_items, total_cost, created_at, updated_at
      FROM patients
      WHERE id = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;
    return Patient.fromMap(_convertMySqlRow(results.first));
  }

  @override
  Future<int> createPatient(Patient patient) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    final result = await connection.query(
      '''
      INSERT INTO patients (medical_record_number, name, name_pinyin, name_initials, age, gender, phone,
                           identification_number, doctor, address, address_pinyin, first_visit_date,
                           dental_condition, treatment_items, total_cost, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''',
      [
        patient.medicalRecordNumber,
        patient.name,
        patient.namePinyin,
        patient.nameInitials,
        patient.age,
        patient.gender,
        patient.phone,
        patient.identificationNumber,
        patient.doctor,
        patient.address,
        patient.addressPinyin,
        DateTimeFormatter.toDbString(patient.firstVisitDate),
        patient.dentalCondition,
        patient.treatmentItems,
        patient.totalCost,
      ],
    );

    return result.insertId ?? 0;
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    final result = await connection.query(
      '''
      UPDATE patients
      SET medical_record_number = ?, name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?,
          identification_number = ?, doctor = ?, address = ?, address_pinyin = ?, first_visit_date = ?,
          dental_condition = ?, treatment_items = ?, total_cost = ?, updated_at = NOW()
      WHERE id = ?
    ''',
      [
        patient.medicalRecordNumber,
        patient.name,
        patient.namePinyin,
        patient.nameInitials,
        patient.age,
        patient.gender,
        patient.phone,
        patient.identificationNumber,
        patient.doctor,
        patient.address,
        patient.addressPinyin,
        DateTimeFormatter.toDbString(patient.firstVisitDate),
        patient.dentalCondition,
        patient.treatmentItems,
        patient.totalCost,
        patient.id,
      ],
    );

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePatient(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query('DELETE FROM patients WHERE id = ?', [
      id,
    ]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<Patient>> searchPatients(String keyword) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return await getAllPatients();
    }

    final lowerKeyword = trimmed.toLowerCase();
    final searchPattern = '%$lowerKeyword%';
    final noSpaceQuery = lowerKeyword.replaceAll(' ', '');
    final noSpacePattern = '%$noSpaceQuery%';

    final results = await connection.query(
      '''
      SELECT * FROM patients
      WHERE LOWER(name) LIKE ?
      OR phone LIKE ?
      OR (address IS NOT NULL AND LOWER(address) LIKE ?)
      OR (identification_number IS NOT NULL AND identification_number LIKE ?)
      OR (name_pinyin IS NOT NULL AND (LOWER(name_pinyin) LIKE ? OR LOWER(name_pinyin) LIKE ? OR LOWER(REPLACE(name_pinyin, ' ', '')) LIKE ?))
      OR (address_pinyin IS NOT NULL AND (LOWER(address_pinyin) LIKE ? OR LOWER(address_pinyin) LIKE ? OR LOWER(REPLACE(address_pinyin, ' ', '')) LIKE ?))
      OR (name_initials IS NOT NULL AND LOWER(name_initials) LIKE ?)
      OR (medical_record_number IS NOT NULL AND CAST(medical_record_number AS CHAR) LIKE ?)

      UNION ALL

      SELECT * FROM patients
      WHERE LOWER(name) = ?
      OR phone = ?
      OR LOWER(address) = ?
      OR identification_number = ?
      OR LOWER(name_pinyin) = ?
      OR LOWER(address_pinyin) = ?
      OR LOWER(name_initials) = ?
      OR CAST(medical_record_number AS CHAR) = ?

      ORDER BY
      CASE
        WHEN LOWER(name) = ? THEN 0
        WHEN phone = ? THEN 1
        WHEN medical_record_number = ? THEN 2
        ELSE 10
      END
      ''',
      [
        searchPattern,
        searchPattern,
        searchPattern,
        searchPattern,
        searchPattern,
        noSpacePattern,
        searchPattern,
        searchPattern,
        noSpacePattern,
        searchPattern,
        searchPattern,
        searchPattern,
        lowerKeyword,
        trimmed,
        lowerKeyword,
        trimmed,
        lowerKeyword,
        lowerKeyword,
        lowerKeyword,
        trimmed,
        lowerKeyword,
        trimmed,
        trimmed,
      ],
    );

    final patients =
        results.map((row) => Patient.fromMap(_convertMySqlRow(row))).toList();
    final uniquePatients = <int?, Patient>{};
    for (var patient in patients) {
      if (patient.id != null) {
        uniquePatients[patient.id] = patient;
      }
    }
    return uniquePatients.values.toList();
  }

  @override
  Future<int> getPatientsCount() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      'SELECT COUNT(*) as count FROM patients',
    );
    final row = results.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<List<Patient>> getPaginatedPatients(
    int page,
    int pageSize, {
    String? sortField,
    bool? ascending,
  }) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final offset = (page - 1) * pageSize;
    String orderBy = 'updated_at DESC';

    if (sortField != null) {
      switch (sortField) {
        case 'age':
          orderBy = 'age ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'medical_record':
          orderBy =
              'medical_record_number ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'updated':
          orderBy = 'updated_at ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'name':
          orderBy = 'name ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        default:
          orderBy = 'updated_at DESC';
      }
    }

    final results = await connection.query(
      '''
      SELECT * FROM patients
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''',
      [pageSize, offset],
    );

    return results
        .map((row) => Patient.fromMap(_convertMySqlRow(row)))
        .toList();
  }
}

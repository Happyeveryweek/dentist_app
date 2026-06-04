import 'package:sqflite/sqflite.dart';
import 'dart:typed_data';

import '../models/database_models.dart';
import '../utils/pinyin_util.dart';
import '../utils/datetime_formatter.dart';
import 'patient_data_source.dart';

class SqlitePatientDataSource implements PatientDataSource {
  final Database _database;

  SqlitePatientDataSource(this._database);

  Database get database => _database;

  @override
  Future<List<Patient>> getAllPatients() async {
    final result = await _database.rawQuery(
      'SELECT * FROM patients ORDER BY created_at DESC',
    );
    return result.map((e) => Patient.fromMap(e)).toList();
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM patients WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    return Patient.fromMap(result.first);
  }

  @override
  Future<int> createPatient(Patient patient) async {
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    return await _database.insert('patients', patient.toMap());
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }

    final count = await _database.update(
      'patients',
      patient.toMap(),
      where: 'id = ?',
      whereArgs: [patient.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deletePatient(int id) async {
    final count = await _database.delete(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<List<Patient>> searchPatients(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return await getAllPatients();
    }

    final lowercaseQuery = trimmed.toLowerCase();
    final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');

    final where = '''
      LOWER(name) LIKE ? OR
      phone LIKE ? OR
      LOWER(address) LIKE ? OR
      identification_number LIKE ? OR
      (name_pinyin IS NOT NULL AND (LOWER(name_pinyin) LIKE ? OR LOWER(name_pinyin) LIKE ? OR LOWER(replace(name_pinyin, ' ', '')) LIKE ?)) OR
      (address_pinyin IS NOT NULL AND (LOWER(address_pinyin) LIKE ? OR LOWER(address_pinyin) LIKE ? OR LOWER(replace(address_pinyin, ' ', '')) LIKE ?)) OR
      (name_initials IS NOT NULL AND LOWER(name_initials) LIKE ?) OR
      (cast(medical_record_number as TEXT) LIKE ?)
    ''';

    final whereArgs = [
      '%$lowercaseQuery%',
      '%$lowercaseQuery%',
      '%$lowercaseQuery%',
      '%$lowercaseQuery%',
      '%$lowercaseQuery%',
      '%$noSpaceQuery%',
      '%$lowercaseQuery%',
      '%$lowercaseQuery%',
      '%$noSpaceQuery%',
      '%$lowercaseQuery%',
      '%$lowercaseQuery%',
      '%$lowercaseQuery%',
    ];

    final result = await _database.query('patients', where: where, whereArgs: whereArgs);

    final patients = <Patient>[];
    for (var map in result) {
      try {
        patients.add(Patient.fromMap(map));
      } catch (e) {
        print('转换患者对象错误: $e, 数据: $map');
      }
    }

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
    final result = await _database.rawQuery('SELECT COUNT(*) as count FROM patients');
    final row = result.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<List<Patient>> getPaginatedPatients(
    int page,
    int pageSize, {
    String? sortField,
    bool? ascending,
  }) async {
    final offset = (page - 1) * pageSize;
    String orderBy = 'updated_at DESC';

    if (sortField != null) {
      switch (sortField) {
        case 'age':
          orderBy = 'age ${ascending == true ? 'ASC' : 'DESC'}';
          break;
        case 'medical_record':
          orderBy = 'medical_record_number ${ascending == true ? 'ASC' : 'DESC'}';
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

    final result = await _database.rawQuery('''
      SELECT * FROM patients
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''', [pageSize, offset]);
    return result.map((e) => Patient.fromMap(e)).toList();
  }
}

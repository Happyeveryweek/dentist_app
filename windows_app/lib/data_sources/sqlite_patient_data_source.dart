import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../utils/datetime_formatter.dart';
import 'patient_data_source.dart';

/// SQLite 患者数据源实现
class SqlitePatientDataSource implements PatientDataSource {
  final Database _database;
  final String? _doctorName;
  final bool _isAdmin;
  
  bool get _hasDoctorName => _doctorName != null && _doctorName!.isNotEmpty;

  SqlitePatientDataSource(this._database, {String? doctorName, bool isAdmin = false})
      : _doctorName = doctorName,
        _isAdmin = isAdmin;

  _PatientQueryParts _buildQueryParts(
    List<String> clauses,
    List<dynamic> args, {
    bool includeDoctorFilter = true,
  }) {
    final whereParts = <String>[];
    if (clauses.isNotEmpty) {
      whereParts.addAll(clauses);
    }
    if (includeDoctorFilter && !_isAdmin && _hasDoctorName) {
      whereParts.add('doctor = ?');
      args.add(_doctorName);
    }
    return _PatientQueryParts(
      whereParts.join(' AND '),
      args,
    );
  }

  _PatientQueryParts _buildTextSearchParts(String query) {
    final queryNoSpace = query.replaceAll(' ', '');
    return _PatientQueryParts(
      '('
      'medical_record_number LIKE ? OR '
      'name LIKE ? OR '
      '(name_pinyin IS NOT NULL AND name_pinyin LIKE ?) OR '
      '(name_pinyin IS NOT NULL AND REPLACE(name_pinyin, \' \', \'\') LIKE ?) OR '
      '(name_initials IS NOT NULL AND name_initials LIKE ?) OR '
      'phone LIKE ? OR '
      'address LIKE ? OR '
      '(address_pinyin IS NOT NULL AND address_pinyin LIKE ?) OR '
      '(address_pinyin IS NOT NULL AND REPLACE(address_pinyin, \' \', \'\') LIKE ?)'
      ')',
      [
        '%$query%',
        '%$query%',
        '%$query%',
        '%$queryNoSpace%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$queryNoSpace%',
      ],
    );
  }

  _PatientQueryParts _buildCountAndPageSearchParts(String query) {
    final queryNoSpace = query.replaceAll(' ', '');
    return _PatientQueryParts(
      '('
      'name LIKE ? OR '
      'phone LIKE ? OR '
      'address LIKE ? OR '
      'identification_number LIKE ? OR '
      '(name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR REPLACE(name_pinyin, \' \', \'\') LIKE ?)) OR '
      '(name_initials IS NOT NULL AND name_initials LIKE ?) OR '
      '(address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR REPLACE(address_pinyin, \' \', \'\') LIKE ?))'
      ')',
      [
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$query%',
        '%$queryNoSpace%',
        '%$query%',
        '%$query%',
        '%$queryNoSpace%',
      ],
    );
  }

  _PatientQueryParts _buildPatientIdSearchParts(String query) {
    return _PatientQueryParts(
      '(name LIKE ? OR name_pinyin LIKE ? OR name_initials LIKE ? OR medical_record_number LIKE ?)',
      List<dynamic>.filled(4, '%$query%'),
    );
  }

  _PatientQueryParts _buildPagedQueryParts({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
  }) {
    final clauses = <String>[];
    final args = <dynamic>[];

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final searchParts = _buildCountAndPageSearchParts(searchQuery);
      clauses.add(searchParts.where);
      args.addAll(searchParts.args);
    }

    if (startDate != null && endDate != null) {
      clauses.add('$dateFilterType BETWEEN ? AND ?');
      args.addAll([
        DateTimeFormatter.toDbString(startDate),
        DateTimeFormatter.toDbString(endDate),
      ]);
    }

    return _buildQueryParts(clauses, args);
  }

  String _whereOrEmpty(String where) => where.isEmpty ? '' : ' WHERE $where';

  @override
  Future<List<Patient>> getAllPatients() async {
    try {
      final maps = await _database.query('patients');
      return maps.map((m) => Patient.fromMap(m)).toList();
    } catch (e) {
      print('SqlitePatientDataSource: getAllPatients 出错: $e');
      return [];
    }
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    try {
      final parts = _buildQueryParts(['id = ?'], [id]);
      final maps = await _database.query(
        'patients',
        where: parts.where,
        whereArgs: parts.args,
      );
      return maps.isNotEmpty ? Patient.fromMap(maps.first) : null;
    } catch (e) {
      print('SqlitePatientDataSource: getPatientById 出错: $e');
      return null;
    }
  }

  @override
  Future<int> createPatient(Patient patient) async {
    try {
      return await _database.insert('patients', patient.toMap());
    } catch (e) {
      print('SqlitePatientDataSource: createPatient 出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    if (patient.id == null) throw Exception('更新患者时必须提供ID');
    try {
      final result = await _database.update('patients', patient.toMap(), where: 'id = ?', whereArgs: [patient.id]);
      return result > 0;
    } catch (e) {
      print('SqlitePatientDataSource: updatePatient 出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deletePatient(int patientId) async {
    try {
      // 级联清理逻辑迁移
      final materialIds = (await _database.rawQuery('SELECT id FROM patient_materials WHERE patient_id = ?', [patientId]))
          .map((row) => row['id'] as int).toList();
      
      if (materialIds.isNotEmpty) {
        final placeholders = materialIds.map((_) => '?').join(',');
        await _database.delete('material_images', where: 'material_id IN ($placeholders)', whereArgs: materialIds);
      }

      await _database.delete('patient_materials', where: 'patient_id = ?', whereArgs: [patientId]);

      final financialRecordIds = (await _database.rawQuery('SELECT id FROM financial_records WHERE patient_id = ?', [patientId]))
          .map((row) => row['id'] as int).toList();
      
      if (financialRecordIds.isNotEmpty) {
        final placeholders = financialRecordIds.map((_) => '?').join(',');
        await _database.delete('financial_items', where: 'financial_record_id IN ($placeholders)', whereArgs: financialRecordIds);
      }
      
      await _database.delete('financial_records', where: 'patient_id = ?', whereArgs: [patientId]);
      await _database.delete('appointments', where: 'patient_id = ?', whereArgs: [patientId]);
      await _database.delete('patient_medical_records', where: 'patient_id = ?', whereArgs: [patientId]);
      
      final patientResult = await _database.delete('patients', where: 'id = ?', whereArgs: [patientId]);
      return patientResult > 0;
    } catch (e) {
      print('SqlitePatientDataSource: deletePatient 出错: $e');
      throw Exception('删除患者失败: $e');
    }
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    try {
      final searchParts = _buildTextSearchParts(query);
      final parts = _buildQueryParts([searchParts.where], searchParts.args);
      final List<Map<String, dynamic>> results = await _database.rawQuery(
        'SELECT * FROM patients${_whereOrEmpty(parts.where)} ORDER BY updated_at DESC, id DESC',
        parts.args,
      );
      return results.map((data) => Patient.fromMap(data)).toList();
    } catch (e) {
      print('SqlitePatientDataSource: searchPatients 出错: $e');
      return [];
    }
  }

  @override
  Future<int> getPatientsCount({String? searchQuery}) async {
    try {
      final clauses = <String>[];
      final args = <dynamic>[];
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final searchParts = _buildCountAndPageSearchParts(searchQuery);
        clauses.add(searchParts.where);
        args.addAll(searchParts.args);
      }
      final parts = _buildQueryParts(clauses, args);
      final result = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patients${_whereOrEmpty(parts.where)}',
        parts.args,
      );
      final count = result.first['count'];
      return count is int ? count : (count as num).toInt();
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> getPatientsPage({
    required int page, required int pageSize, String? searchQuery,
    String? sortField, bool sortAscending = false,
    DateTime? startDate, DateTime? endDate, String dateFilterType = 'first_visit_date',
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      final parts = _buildPagedQueryParts(
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        dateFilterType: dateFilterType,
      );
      final countResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patients${_whereOrEmpty(parts.where)}',
        parts.args,
      );
      final totalCountValue = countResult.first['count'];
      final totalCount = totalCountValue is int ? totalCountValue : (totalCountValue as num).toInt();

      String orderBy = 'updated_at DESC';
      if (sortField != null && sortField.isNotEmpty) {
        String field = (sortField == 'medical_record_number') ? 'CAST(medical_record_number AS INTEGER)' : sortField;
        orderBy = '$field ${sortAscending ? "ASC" : "DESC"}';
      }

      final List<Map<String, dynamic>> maps = await _database.rawQuery(
        'SELECT * FROM patients${_whereOrEmpty(parts.where)} ORDER BY $orderBy LIMIT $pageSize OFFSET $offset',
        parts.args,
      );

      return {
        'patients': maps.map((m) => Patient.fromMap(m)).toList(),
        'totalCount': totalCount,
        'totalPages': (totalCount / pageSize).ceil(),
        'currentPage': page,
      };
    } catch (e) {
      print('SqlitePatientDataSource: getPatientsPage 出错: $e');
      rethrow;
    }
  }

  @override
  Future<List<Patient>> getPatientsByDoctor(String doctorName) async {
    try {
      final maps = await _database.query('patients', where: 'doctor = ?', whereArgs: [doctorName]);
      return maps.map((m) => Patient.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<int>> searchPatientIds(String query) async {
    try {
      final idSearchParts = _buildPatientIdSearchParts(query);
      final parts = _buildQueryParts([idSearchParts.where], idSearchParts.args);
      final maps = await _database.query(
        'patients',
        columns: ['id'],
        where: parts.where,
        whereArgs: parts.args,
      );
      return maps.map((m) => m['id'] as int).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<List<Patient>> getPatientsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final placeholders = List.filled(ids.length, '?').join(',');
      final parts = _buildQueryParts(['id IN ($placeholders)'], [...ids]);
      final maps = await _database.query(
        'patients',
        where: parts.where,
        whereArgs: parts.args,
      );
      return maps.map((m) => Patient.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> checkMedicalRecordExists(int mrn, [int? excludeId]) async {
    try {
      final clauses = <String>['medical_record_number = ?'];
      final args = <dynamic>[mrn];
      if (excludeId != null) {
        clauses.add('id != ?');
        args.add(excludeId);
      }
      final parts = _buildQueryParts(clauses, args, includeDoctorFilter: false);
      final result = await _database.query(
        'patients',
        where: parts.where,
        whereArgs: parts.args,
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> checkPatientNameExists(String name, [int? excludeId]) async {
    try {
      final clauses = <String>['name = ?'];
      final args = <dynamic>[name];
      if (excludeId != null) {
        clauses.add('id != ?');
        args.add(excludeId);
      }
      final parts = _buildQueryParts(clauses, args, includeDoctorFilter: false);
      final result = await _database.query(
        'patients',
        where: parts.where,
        whereArgs: parts.args,
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> updateAllPatientsPinyin() async {
    throw UnimplementedError('updateAllPatientsPinyin should be implemented in Provider/Service layer');
  }

  @override
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material) async {
    final id = await _database.insert('patient_materials', material.toMap());
    return material.copyWith(id: id);
  }

  @override
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    final results = await _database.query('patient_materials', where: 'patient_id = ?', whereArgs: [patientId], orderBy: 'created_at DESC');
    return results.map((m) => PatientMaterial.fromMap(m)).toList();
  }

  @override
  Future<bool> updatePatientMaterial(PatientMaterial material) async {
    final count = await _database.update('patient_materials', material.toMap(), where: 'id = ?', whereArgs: [material.id]);
    return count > 0;
  }

  @override
  Future<bool> deletePatientMaterial(int id) async {
    await _database.transaction((txn) async {
      await txn.delete('material_images', where: 'material_id = ?', whereArgs: [id]);
      await txn.delete('patient_materials', where: 'id = ?', whereArgs: [id]);
    });
    return true;
  }

  @override
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    final result = await _database.query('material_images', where: 'material_id = ?', whereArgs: [materialId], orderBy: 'created_at DESC');
    return result.map((e) => MaterialImage.fromMap(e)).toList();
  }

  @override
  Future<MaterialImage?> getMaterialImage(int imageId) async {
    final result = await _database.query(
      'material_images',
      where: 'id = ?',
      whereArgs: [imageId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return MaterialImage.fromMap(result.first);
  }

  @override
  Future<MaterialImage> addMaterialImage(MaterialImage image) async {
    final id = await _database.insert('material_images', image.toMap());
    return image.copyWith(id: id);
  }

  @override
  Future<bool> updateMaterialImage(MaterialImage image) async {
    final count = await _database.update('material_images', image.toMap(), where: 'id = ?', whereArgs: [image.id]);
    return count > 0;
  }

  @override
  Future<bool> deleteMaterialImage(int imageId) async {
    final count = await _database.delete('material_images', where: 'id = ?', whereArgs: [imageId]);
    return count > 0;
  }
}

class _PatientQueryParts {
  final String where;
  final List<dynamic> args;

  _PatientQueryParts(this.where, this.args);
}

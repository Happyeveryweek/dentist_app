import 'package:mysql1/mysql1.dart';
import '../models/patient.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../utils/datetime_formatter.dart';
import '../utils/log_manager.dart';
import 'base_mysql_data_source.dart';
import 'patient_data_source.dart';

/// MySQL 患者数据源实现
class MySqlPatientDataSource extends BaseMySqlDataSource
    implements PatientDataSource {
  final String? _doctorName;
  final bool _isAdmin;

  bool get _hasDoctorName {
    final doctorName = _doctorName;
    return doctorName != null && doctorName.isNotEmpty;
  }

  _PatientQueryParts _buildQueryParts(
    List<String> clauses,
    List<dynamic> args, {
    bool includeDoctorFilter = true,
  }) {
    final whereParts = <String>[];
    if (clauses.isNotEmpty) {
      whereParts.addAll(clauses);
    }
    if (includeDoctorFilter && !_isAdmin) {
      if (_hasDoctorName) {
        whereParts.add('doctor = ?');
        args.add(_doctorName);
      } else {
        whereParts.add('1 = 0');
      }
    }
    return _PatientQueryParts(whereParts.join(' AND '), args);
  }

  _PatientQueryParts _buildTextSearchParts(String query) {
    final queryNoSpace = query.replaceAll(' ', '');
    return _PatientQueryParts(
      '('
      'medical_record_number LIKE ? OR '
      'name LIKE ? OR '
      'identification_number LIKE ? OR '
      'name_pinyin LIKE ? OR '
      'REPLACE(name_pinyin, " ", "") LIKE ? OR '
      'name_initials LIKE ? OR '
      'phone LIKE ? OR '
      'address LIKE ? OR '
      'address_pinyin LIKE ? OR '
      'REPLACE(address_pinyin, " ", "") LIKE ?'
      ')',
      [
        '%$query%',
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
    return _buildTextSearchParts(query);
  }

  _PatientQueryParts _buildPatientIdSearchParts(String query) {
    return _buildTextSearchParts(query);
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

  int _readCount(dynamic value) {
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  MySqlPatientDataSource.withConnectionGetter(
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
  Future<List<Patient>> getAllPatients() async {
    try {
      final parts = _buildQueryParts([], []);
      final results = await executeQuery(
        'SELECT * FROM patients${_whereOrEmpty(parts.where)}',
        parts.args,
      );
      List<Patient> patients = [];
      for (var row in results) {
        patients.add(Patient.fromMap(convertRowToMap(row)));
      }
      return patients;
    } catch (e) {
      LogManager.e('MySqlPatientDataSource', 'getAllPatients 出错', error: e);
      return [];
    }
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    try {
      final parts = _buildQueryParts(['id = ?'], [id]);
      final results = await executeQuery(
        'SELECT * FROM patients${_whereOrEmpty(parts.where)}',
        parts.args,
      );
      if (results.isEmpty) return null;
      return Patient.fromMap(convertRowToMap(results.first));
    } catch (e) {
      LogManager.e('MySqlPatientDataSource', 'getPatientById 出错', error: e);
      return null;
    }
  }

  @override
  Future<int> createPatient(Patient patient) async {
    try {
      final m = patient.toMap();
      final result = await executeQuery('''
        INSERT INTO patients (name, name_pinyin, name_initials, age, gender, phone, medical_record_number, address, address_pinyin, identification_number, doctor, dental_condition, treatment_items, first_visit_date, total_cost, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        m['name'],
        m['name_pinyin'],
        m['name_initials'],
        m['age'],
        m['gender'],
        m['phone'],
        m['medical_record_number'],
        m['address'],
        m['address_pinyin'],
        m['identification_number'],
        m['doctor'],
        m['dental_condition'],
        m['treatment_items'],
        m['first_visit_date'],
        m['total_cost'],
        m['created_at'],
        m['updated_at'],
      ]);
      return result.insertId ?? 0;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    if (patient.id == null) throw Exception('更新患者必须提供ID');
    try {
      final m = patient.toMap();
      final result = await executeQuery('''
        UPDATE patients SET name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?, medical_record_number = ?, address = ?, address_pinyin = ?, identification_number = ?, doctor = ?, dental_condition = ?, treatment_items = ?, first_visit_date = ?, total_cost = ?, updated_at = ? WHERE id = ?
      ''', [
        m['name'],
        m['name_pinyin'],
        m['name_initials'],
        m['age'],
        m['gender'],
        m['phone'],
        m['medical_record_number'],
        m['address'],
        m['address_pinyin'],
        m['identification_number'],
        m['doctor'],
        m['dental_condition'],
        m['treatment_items'],
        m['first_visit_date'],
        m['total_cost'],
        m['updated_at'],
        patient.id,
      ]);
      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> deletePatient(int patientId) async {
    try {
      await executeQuery('START TRANSACTION');
      final materialIdsResult = await executeQuery(
          'SELECT id FROM patient_materials WHERE patient_id = ?', [patientId]);
      final materialIds =
          materialIdsResult.map((row) => row[0] as int).toList();
      if (materialIds.isNotEmpty) {
        final placeholders = materialIds.map((_) => '?').join(',');
        await executeQuery(
            'DELETE FROM material_images WHERE material_id IN ($placeholders)',
            materialIds);
      }
      await executeQuery(
          'DELETE FROM patient_materials WHERE patient_id = ?', [patientId]);

      final financialRecordIds = (await executeQuery(
              'SELECT id FROM financial_records WHERE patient_id = ?',
              [patientId]))
          .map((row) => row[0] as int)
          .toList();
      if (financialRecordIds.isNotEmpty) {
        final placeholders = financialRecordIds.map((_) => '?').join(',');
        await executeQuery(
            'DELETE FROM financial_items WHERE financial_record_id IN ($placeholders)',
            financialRecordIds);
      }

      await executeQuery(
          'DELETE FROM financial_records WHERE patient_id = ?', [patientId]);
      await executeQuery(
          'DELETE FROM appointments WHERE patient_id = ?', [patientId]);
      await executeQuery(
          'DELETE FROM patient_medical_records WHERE patient_id = ?',
          [patientId]);
      final result =
          await executeQuery('DELETE FROM patients WHERE id = ?', [patientId]);
      await executeQuery('COMMIT');
      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      try {
        await executeQuery('ROLLBACK');
      } catch (_) {}
      throw Exception('MySQL删除患者失败: $e');
    }
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    try {
      final searchParts = _buildTextSearchParts(query);
      final parts = _buildQueryParts([searchParts.where], searchParts.args);
      final results = await executeQuery(
        'SELECT * FROM patients${_whereOrEmpty(parts.where)} ORDER BY updated_at DESC, id DESC',
        parts.args,
      );
      return results
          .map((row) => Patient.fromMap(convertRowToMap(row)))
          .toList();
    } catch (e) {
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
      final results = await executeQuery(
        'SELECT COUNT(*) as count FROM patients${_whereOrEmpty(parts.where)}',
        parts.args,
      );
      final dynamic count = results.first['count'] ?? results.first[0];
      return _readCount(count);
    } catch (e) {
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> getPatientsPage({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      final parts = _buildPagedQueryParts(
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        dateFilterType: dateFilterType,
      );

      final countResults = await executeQuery(
        'SELECT COUNT(*) as count FROM patients${_whereOrEmpty(parts.where)}',
        parts.args,
      );
      final dynamic countVal =
          countResults.first['count'] ?? countResults.first[0];
      final totalCount = _readCount(countVal);

      String orderBy = 'updated_at DESC';
      if (sortField != null && sortField.isNotEmpty) {
        String field = sortField == 'medical_record_number'
            ? 'CAST(medical_record_number AS SIGNED)'
            : (sortField == 'first_visit_date'
                ? 'first_visit_date'
                : sortField);
        orderBy = '$field ${sortAscending ? 'ASC' : 'DESC'}';
      }

      final results = await executeQuery(
        'SELECT * FROM patients${_whereOrEmpty(parts.where)} ORDER BY $orderBy LIMIT ? OFFSET ?',
        [...parts.args, pageSize, offset],
      );
      return {
        'patients': results
            .map((row) => Patient.fromMap(convertRowToMap(row)))
            .toList(),
        'totalCount': totalCount,
        'totalPages': (totalCount / pageSize).ceil(),
        'currentPage': page,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<Patient>> getPatientsByDoctor(String doctorName) async {
    final results = await executeQuery(
        'SELECT * FROM patients WHERE doctor = ?', [doctorName]);
    return results.map((row) => Patient.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<List<int>> searchPatientIds(String query) async {
    try {
      final idSearchParts = _buildPatientIdSearchParts(query);
      final parts = _buildQueryParts([idSearchParts.where], idSearchParts.args);
      final results = await executeQuery(
        'SELECT id FROM patients${_whereOrEmpty(parts.where)}',
        parts.args,
      );
      return results.map((r) => r['id'] as int).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Patient>> getPatientsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final placeholders = List.filled(ids.length, '?').join(',');
    final parts = _buildQueryParts(['id IN ($placeholders)'], [...ids]);
    final results = await executeQuery(
      'SELECT * FROM patients${_whereOrEmpty(parts.where)}',
      parts.args,
    );
    return results.map((row) => Patient.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<bool> checkMedicalRecordExists(int mrn, [int? excludeId]) async {
    final clauses = <String>['medical_record_number = ?'];
    final args = <dynamic>[mrn];
    if (excludeId != null) {
      clauses.add('id != ?');
      args.add(excludeId);
    }
    final parts = _buildQueryParts(clauses, args, includeDoctorFilter: false);
    final results = await executeQuery(
      'SELECT id FROM patients${_whereOrEmpty(parts.where)} LIMIT 1',
      parts.args,
    );
    return results.isNotEmpty;
  }

  @override
  Future<bool> checkPatientNameExists(String name, [int? excludeId]) async {
    final clauses = <String>['name = ?'];
    final args = <dynamic>[name];
    if (excludeId != null) {
      clauses.add('id != ?');
      args.add(excludeId);
    }
    final parts = _buildQueryParts(clauses, args, includeDoctorFilter: false);
    final results = await executeQuery(
      'SELECT id FROM patients${_whereOrEmpty(parts.where)} LIMIT 1',
      parts.args,
    );
    return results.isNotEmpty;
  }

  @override
  Future<void> updateAllPatientsPinyin() async {
    throw UnimplementedError(
        'updateAllPatientsPinyin should be implemented in Provider layer');
  }

  @override
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material) async {
    final result = await executeQuery(
        'INSERT INTO patient_materials (patient_id, description, created_at, updated_at) VALUES (?, ?, ?, ?)',
        [
          material.patientId,
          material.description,
          DateTimeFormatter.toDbString(material.createdAt),
          DateTimeFormatter.toDbString(material.updatedAt)
        ]);
    return material.copyWith(id: result.insertId);
  }

  @override
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    final results = await executeQuery(
        'SELECT * FROM patient_materials WHERE patient_id = ? ORDER BY created_at DESC',
        [patientId]);
    return results
        .map((row) => PatientMaterial.fromMap(convertRowToMap(row)))
        .toList();
  }

  @override
  Future<bool> updatePatientMaterial(PatientMaterial material) async {
    final result = await executeQuery(
        'UPDATE patient_materials SET description = ?, updated_at = ? WHERE id = ?',
        [
          material.description,
          DateTimeFormatter.toDbString(material.updatedAt),
          material.id
        ]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePatientMaterial(int id) async {
    await executeQuery('START TRANSACTION');
    try {
      await executeQuery(
          'DELETE FROM material_images WHERE material_id = ?', [id]);
      await executeQuery('DELETE FROM patient_materials WHERE id = ?', [id]);
      await executeQuery('COMMIT');
      return true;
    } catch (e) {
      await executeQuery('ROLLBACK');
      return false;
    }
  }

  @override
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    final results = await executeQuery(
        'SELECT * FROM material_images WHERE material_id = ? ORDER BY created_at DESC',
        [materialId]);
    return results
        .map((row) => MaterialImage.fromMap(convertRowToMap(row)))
        .toList();
  }

  @override
  Future<List<MaterialImage>> getMaterialImageMetadata(int materialId) async {
    final results = await executeQuery(
      'SELECT id, material_id, image_type, file_size, thumbnail_size, original_name, image_path, created_at, has_thumbnail '
      'FROM material_images WHERE material_id = ? ORDER BY created_at DESC',
      [materialId],
    );
    return results
        .map((row) => MaterialImage.fromMap(convertRowToMap(row)))
        .toList();
  }

  @override
  Future<MaterialImage?> getMaterialImage(int imageId) async {
    final results = await executeQuery(
      'SELECT * FROM material_images WHERE id = ? LIMIT 1',
      [imageId],
    );
    if (results.isEmpty) return null;
    return MaterialImage.fromMap(convertRowToMap(results.first));
  }

  @override
  Future<MaterialImage> addMaterialImage(MaterialImage image) async {
    final result = await executeQuery(
        'INSERT INTO material_images (material_id, original_name, image_data, thumbnail_data, image_type, file_size, thumbnail_size, has_thumbnail, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())',
        [
          image.materialId,
          image.originalName,
          image.imageData,
          image.thumbnailData,
          image.imageType,
          image.fileSize,
          image.thumbnailSize,
          image.hasThumbnail ? 1 : 0
        ]);
    return image.copyWith(id: result.insertId);
  }

  @override
  Future<bool> updateMaterialImage(MaterialImage image) async {
    final result = await executeQuery(
        'UPDATE material_images SET material_id = ?, original_name = ?, image_data = ?, thumbnail_data = ?, image_type = ?, file_size = ?, thumbnail_size = ?, has_thumbnail = ? WHERE id = ?',
        [
          image.materialId,
          image.originalName,
          image.imageData,
          image.thumbnailData,
          image.imageType,
          image.fileSize,
          image.thumbnailSize,
          image.hasThumbnail ? 1 : 0,
          image.id
        ]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteMaterialImage(int imageId) async {
    final result = await executeQuery(
        'DELETE FROM material_images WHERE id = ?', [imageId]);
    return (result.affectedRows ?? 0) > 0;
  }
}

class _PatientQueryParts {
  final String where;
  final List<dynamic> args;

  _PatientQueryParts(this.where, this.args);
}

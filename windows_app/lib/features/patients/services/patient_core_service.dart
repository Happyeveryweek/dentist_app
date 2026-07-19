import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../models/patient.dart';
import '../../../models/patient_sync_log.dart';
import 'patient_sync_log_helper.dart';
import '../../../utils/datetime_formatter.dart';
import '../../../utils/log_manager.dart';
import '../../../utils/pinyin_util.dart';
import '../../../data_sources/patient_data_source.dart';

/// 患者核心业务服务
/// 负责处理增删改业务逻辑、数据同步以及二进制格式转换
class PatientCoreService {
  final PatientDataSource? Function() getCurrentDataSource;
  final MySqlConnection? Function() getSyncMysqlConnection;
  final Database? Function() getDatabase;
  final MySqlConnection? Function() getMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  Database? get database => getDatabase();

  PatientCoreService({
    required this.getCurrentDataSource,
    required this.getSyncMysqlConnection,
    required this.getDatabase,
    required this.getMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 添加患者
  Future<int> addPatient(Patient patient) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) throw Exception('数据源未初始化');

    final Map<String, dynamic> patientMap = patient.toMap();
    final nowStr = DateTimeFormatter.toDbString(DateTime.now());
    patientMap['created_at'] = nowStr;
    patientMap['updated_at'] = nowStr;
    patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
    patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);
    final address = patient.address;
    if (address != null) {
      patientMap['address_pinyin'] = PinyinUtil.toPinyin(address);
    }

    final id = await dataSource.createPatient(Patient.fromMap(patientMap));

    if (getEffectiveDataSourceType() == 'sqlite') {
      _trySyncPatientToMySQL(patientMap, id);
    }
    return id;
  }

  /// 更新患者
  Future<bool> updatePatient(Patient patient) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) throw Exception('数据源未初始化');
    if (patient.id == null) throw Exception('更新患者必须提供ID');

    final Map<String, dynamic> patientMap = patient.toMap();
    patientMap['updated_at'] = DateTimeFormatter.toDbString(DateTime.now());
    patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
    patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);
    final address = patient.address;
    if (address != null) {
      patientMap['address_pinyin'] = PinyinUtil.toPinyin(address);
    }

    final patientId = patient.id;
    final success = await dataSource.updatePatient(Patient.fromMap(patientMap));

    if (success &&
        patientId != null &&
        getEffectiveDataSourceType() == 'sqlite') {
      await _doSyncPatientToMySQL(patientMap, patientId);
    }
    return success;
  }

  /// 删除患者
  Future<bool> deletePatient(int patientId,
      {String? patientName, dynamic medicalRecordNumber}) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) throw Exception('数据源未初始化');

    final effectiveType = getEffectiveDataSourceType();
    final success = await dataSource.deletePatient(patientId);

    // 当患者管理与其他模块使用不同数据库时，同步清理另一数据库中的关联数据
    if (success) {
      if (effectiveType == 'sqlite') {
        await _deleteRelatedDataFromMySQL(patientId);
      } else if (effectiveType == 'mysql') {
        await _deleteRelatedDataFromSQLite(patientId);
      }
    }

    if (success && effectiveType == 'sqlite') {
      _trySyncDeletePatientToMySQL(patientId,
          patientName: patientName, medicalRecordNumber: medicalRecordNumber);
    }
    return success;
  }

  /// 清理 MySQL 中指定患者的关联数据（患者主库为 SQLite 时使用）
  Future<void> _deleteRelatedDataFromMySQL(int patientId) async {
    try {
      final conn = getSyncMysqlConnection();
      if (conn == null) return;

      try {
        await conn.query('START TRANSACTION');
        final matIds = (await conn.query(
                'SELECT id FROM patient_materials WHERE patient_id = ?',
                [patientId]))
            .map((r) => r['id'] as int)
            .toList();
        if (matIds.isNotEmpty) {
          final placeholders = matIds.map((_) => '?').join(',');
          await conn.query(
              'DELETE FROM material_images WHERE material_id IN ($placeholders)',
              matIds);
        }
        await conn.query(
            'DELETE FROM patient_materials WHERE patient_id = ?', [patientId]);

        final financialRecordIds = (await conn.query(
                'SELECT id FROM financial_records WHERE patient_id = ?',
                [patientId]))
            .map((r) => r['id'] as int)
            .toList();
        if (financialRecordIds.isNotEmpty) {
          final placeholders = financialRecordIds.map((_) => '?').join(',');
          await conn.query(
              'DELETE FROM financial_items WHERE financial_record_id IN ($placeholders)',
              financialRecordIds);
        }
        await conn.query(
            'DELETE FROM financial_records WHERE patient_id = ?', [patientId]);
        await conn.query(
            'DELETE FROM appointments WHERE patient_id = ?', [patientId]);
        await conn.query(
            'DELETE FROM patient_medical_records WHERE patient_id = ?',
            [patientId]);
        await conn.query('COMMIT');
      } catch (_) {
        await conn.query('ROLLBACK');
        rethrow;
      }
    } catch (e) {
      LogManager.e('PatientCoreService', 'PatientCoreService: 清理 MySQL 关联数据失败',
          error: e);
    }
  }

  /// 清理 SQLite 中指定患者的关联数据（患者主库为 MySQL 时使用）
  Future<void> _deleteRelatedDataFromSQLite(int patientId) async {
    try {
      final db = getDatabase();
      if (db == null) return;

      final materialIds = (await db.rawQuery(
              'SELECT id FROM patient_materials WHERE patient_id = ?',
              [patientId]))
          .map((row) => row['id'] as int)
          .toList();
      if (materialIds.isNotEmpty) {
        final placeholders = materialIds.map((_) => '?').join(',');
        await db.delete('material_images',
            where: 'material_id IN ($placeholders)', whereArgs: materialIds);
      }
      await db.delete('patient_materials',
          where: 'patient_id = ?', whereArgs: [patientId]);

      final financialRecordIds = (await db.rawQuery(
              'SELECT id FROM financial_records WHERE patient_id = ?',
              [patientId]))
          .map((row) => row['id'] as int)
          .toList();
      if (financialRecordIds.isNotEmpty) {
        final placeholders = financialRecordIds.map((_) => '?').join(',');
        await db.delete('financial_items',
            where: 'financial_record_id IN ($placeholders)',
            whereArgs: financialRecordIds);
      }
      await db.delete('financial_records',
          where: 'patient_id = ?', whereArgs: [patientId]);
      await db.delete('appointments',
          where: 'patient_id = ?', whereArgs: [patientId]);
      await db.delete('patient_medical_records',
          where: 'patient_id = ?', whereArgs: [patientId]);
    } catch (e) {
      LogManager.e('PatientCoreService', 'PatientCoreService: 清理 SQLite 关联数据失败',
          error: e);
    }
  }

  /// 检查病历号是否存在
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber,
      [int? excludePatientId]) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) throw Exception('数据源未初始化');
    return await dataSource.checkMedicalRecordExists(
        medicalRecordNumber, excludePatientId);
  }

  /// 检查姓名是否存在
  Future<bool> checkPatientNameExists(String name,
      [int? excludePatientId]) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) throw Exception('数据源未初始化');
    return await dataSource.checkPatientNameExists(name, excludePatientId);
  }

  // ==================== 牙齿状况数据格式处理 ====================

  String processDentalConditionFormat(String sqlContent) {
    final regex = RegExp(r'INSERT INTO `(\w+)`.*VALUES.*', multiLine: true);
    return sqlContent.replaceAllMapped(regex, (match) {
      String statement = match.group(0) ?? '';
      String tableName = match.group(1) ?? '';
      if (tableName == 'patients') {
        statement = _processBinaryField(statement, 'dental_condition');
        statement = _processBinaryField(statement, 'treatment_items');
        statement = _processBinaryField(statement, 'total_cost');
      }
      statement = _processAnyBinaryField(statement);
      return statement;
    });
  }

  String _processAnyBinaryField(String sqlStatement) {
    RegExp binaryRegex = RegExp(r"', X'([0-9A-Fa-f]+)'");
    return sqlStatement.replaceAllMapped(binaryRegex, (match) {
      String hexData = match.group(1) ?? '';
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          bytes.add(int.parse(hexData.substring(i, i + 2), radix: 16));
        }
      }
      return "', '${String.fromCharCodes(bytes)}'";
    });
  }

  String _processBinaryField(String sqlStatement, String fieldName) {
    RegExp regex = RegExp("$fieldName', X'([0-9A-Fa-f]+)'");
    return sqlStatement.replaceAllMapped(regex, (match) {
      String hexData = match.group(1) ?? '';
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          bytes.add(int.parse(hexData.substring(i, i + 2), radix: 16));
        }
      }
      return "$fieldName', '${String.fromCharCodes(bytes)}'";
    });
  }

  // =================== 后台同步私有逻辑 ===================

  /// 手动同步单个患者到 MySQL，等待完成并返回是否成功
  Future<bool> syncPatientToMySQL(int patientId) async {
    if (getEffectiveDataSourceType() != 'sqlite') return false;
    final dataSource = getCurrentDataSource();
    if (dataSource == null) return false;

    try {
      final patient = await dataSource.getPatientById(patientId);
      if (patient == null) return false;

      final patientMap = patient.toMap();
      patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
      patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);
      final address = patient.address;
      if (address != null) {
        patientMap['address_pinyin'] = PinyinUtil.toPinyin(address);
      }

      return await _doSyncPatientToMySQL(patientMap, patientId);
    } catch (e) {
      LogManager.e('PatientCoreService', '手动同步患者失败', error: e);
      return false;
    }
  }

  /// 对比 SQLite 与 MySQL 中同一患者数据是否一致
  /// 返回 true=一致 / false=不一致 / null=无法比较（连接不可用或非 SQLite 主库）
  Future<bool?> comparePatientSyncStatus(int patientId) async {
    if (getEffectiveDataSourceType() != 'sqlite') return null;

    try {
      final dataSource = getCurrentDataSource();
      if (dataSource == null) return null;

      final sqlitePatient = await dataSource.getPatientById(patientId);
      if (sqlitePatient == null) return null;

      final conn = getSyncMysqlConnection();
      if (conn == null) return null;

      final results = await conn.query(
        'SELECT * FROM patients WHERE id = ? LIMIT 1',
        [patientId],
      );
      if (results.isEmpty) return false;

      final sqliteMap = sqlitePatient.toMap();
      final changes = PatientSyncLogHelper.buildFieldChanges(
        oldValues: results.first.fields,
        newValues: sqliteMap,
        fields: _patientSyncFields,
      );
      return changes.isEmpty;
    } catch (e) {
      LogManager.e('PatientCoreService', '对比患者同步状态失败', error: e);
      return null;
    }
  }

  void _trySyncPatientToMySQL(Map<String, dynamic> patientMap, int sqliteId) {
    Future.microtask(() => _doSyncPatientToMySQL(patientMap, sqliteId));
  }

  Future<bool> _doSyncPatientToMySQL(
      Map<String, dynamic> patientMap, int sqliteId) async {
    try {
      final conn = getSyncMysqlConnection();
      final summary =
          'name=${patientMap['name']}, mrn=${patientMap['medical_record_number'] ?? ''}';
      if (conn == null) {
        await _logPatientSyncOperation(
          module: 'patient',
          action: 'upsert',
          table: 'patients',
          status: 'skipped',
          recordId: sqliteId,
          summary: summary,
          error: 'mysql_connection_unavailable',
        );
        return false;
      }

      Results existById = await conn.query(
        'SELECT * FROM patients WHERE id = ? LIMIT 1',
        [sqliteId],
      );
      final isUpdate = existById.isNotEmpty;
      final fieldChanges = isUpdate
          ? PatientSyncLogHelper.buildFieldChanges(
              oldValues: existById.first.fields,
              newValues: patientMap,
              fields: _patientSyncFields,
            )
          : PatientSyncLogHelper.buildCreateChanges(
              patientMap, _patientSyncFields);

      if (isUpdate) {
        await conn.query('''
            UPDATE patients SET
              name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?,
              medical_record_number = ?, address = ?, address_pinyin = ?, identification_number = ?,
              doctor = ?, dental_condition = ?, treatment_items = ?, first_visit_date = ?, total_cost = ?, created_at = ?, updated_at = ?
            WHERE id = ?
          ''', [
          patientMap['name'],
          patientMap['name_pinyin'],
          patientMap['name_initials'],
          patientMap['age'],
          patientMap['gender'],
          patientMap['phone'],
          patientMap['medical_record_number'],
          patientMap['address'],
          patientMap['address_pinyin'],
          patientMap['identification_number'],
          patientMap['doctor'],
          patientMap['dental_condition'],
          patientMap['treatment_items'],
          patientMap['first_visit_date'],
          patientMap['total_cost'],
          patientMap['created_at'],
          patientMap['updated_at'],
          sqliteId,
        ]);
      } else {
        await conn.query('''
            INSERT INTO patients
            (id, name, name_pinyin, name_initials, age, gender, phone, medical_record_number, address, address_pinyin, identification_number, doctor, dental_condition, treatment_items, first_visit_date, total_cost, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
          sqliteId,
          patientMap['name'],
          patientMap['name_pinyin'],
          patientMap['name_initials'],
          patientMap['age'],
          patientMap['gender'],
          patientMap['phone'],
          patientMap['medical_record_number'],
          patientMap['address'],
          patientMap['address_pinyin'],
          patientMap['identification_number'],
          patientMap['doctor'],
          patientMap['dental_condition'],
          patientMap['treatment_items'],
          patientMap['first_visit_date'],
          patientMap['total_cost'],
          patientMap['created_at'],
          patientMap['updated_at'],
        ]);
      }
      await _logPatientSyncOperation(
        module: 'patient',
        action: isUpdate ? 'update' : 'create',
        table: 'patients',
        status: 'success',
        recordId: sqliteId,
        summary: summary,
        fieldChanges: fieldChanges,
      );
      return true;
    } catch (e) {
      await _logPatientSyncOperation(
        module: 'patient',
        action: 'upsert',
        table: 'patients',
        status: 'failed',
        recordId: sqliteId,
        summary:
            'name=${patientMap['name']}, mrn=${patientMap['medical_record_number'] ?? ''}',
        error: e.toString(),
      );
      LogManager.e('PatientCoreService', 'PatientCoreService: MySQL同步失败',
          error: e);
      return false;
    }
  }

  void _trySyncDeletePatientToMySQL(int patientId,
      {String? patientName, dynamic medicalRecordNumber}) {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        final summary =
            'name=${patientName ?? ''}, mrn=${medicalRecordNumber ?? ''}';
        if (conn == null) {
          await _logPatientSyncOperation(
            module: 'patient',
            action: 'delete',
            table: 'patients',
            status: 'skipped',
            recordId: patientId,
            summary: summary,
            error: 'mysql_connection_unavailable',
          );
          return;
        }

        final check = await conn.query(
            'SELECT id, name FROM patients WHERE id = ? LIMIT 1', [patientId]);
        if (check.isEmpty) {
          await _logPatientSyncOperation(
            module: 'patient',
            action: 'delete',
            table: 'patients',
            status: 'skipped',
            recordId: patientId,
            summary: summary,
            error: 'mysql_record_not_found',
          );
          return;
        }
        if (patientName != null && check.first['name'] != patientName) {
          await _logPatientSyncOperation(
            module: 'patient',
            action: 'delete',
            table: 'patients',
            status: 'skipped',
            recordId: patientId,
            summary: summary,
            error: 'mysql_record_name_mismatch',
          );
          return;
        }

        await conn.query('START TRANSACTION');

        final matIds = (await conn.query(
                'SELECT id FROM patient_materials WHERE patient_id = ?',
                [patientId]))
            .map((r) => r['id'] as int)
            .toList();
        if (matIds.isNotEmpty) {
          final p = matIds.map((_) => '?').join(',');
          await conn.query(
              'DELETE FROM material_images WHERE material_id IN ($p)', matIds);
        }
        await conn.query(
            'DELETE FROM patient_materials WHERE patient_id = ?', [patientId]);
        final financialRecordIds = (await conn.query(
                'SELECT id FROM financial_records WHERE patient_id = ?',
                [patientId]))
            .map((r) => r['id'] as int)
            .toList();
        if (financialRecordIds.isNotEmpty) {
          final p = financialRecordIds.map((_) => '?').join(',');
          await conn.query(
              'DELETE FROM financial_items WHERE financial_record_id IN ($p)',
              financialRecordIds);
        }
        await conn.query(
            'DELETE FROM financial_records WHERE patient_id = ?', [patientId]);
        await conn.query(
            'DELETE FROM appointments WHERE patient_id = ?', [patientId]);
        await conn.query(
            'DELETE FROM patient_medical_records WHERE patient_id = ?',
            [patientId]);
        await conn.query('DELETE FROM patients WHERE id = ?', [patientId]);
        await conn.query('COMMIT');
        await _logPatientSyncOperation(
          module: 'patient',
          action: 'delete',
          table: 'patients',
          status: 'success',
          recordId: patientId,
          summary: summary,
        );
      } catch (e) {
        try {
          final conn = getSyncMysqlConnection();
          if (conn != null) await conn.query('ROLLBACK');
        } catch (_) {}
        await _logPatientSyncOperation(
          module: 'patient',
          action: 'delete',
          table: 'patients',
          status: 'failed',
          recordId: patientId,
          summary:
              'name=${patientName ?? ''}, mrn=${medicalRecordNumber ?? ''}',
          error: e.toString(),
        );
        LogManager.e('PatientCoreService', 'PatientCoreService: MySQL同步删除失败',
            error: e);
      }
    });
  }

  Future<void> _logPatientSyncOperation({
    required String module,
    required String action,
    required String table,
    required String status,
    String entityType = 'patient',
    String entityName = '患者基本信息',
    int? recordId,
    int? patientId,
    String? summary,
    List<PatientSyncFieldChange> fieldChanges = const [],
    String? error,
  }) async {
    await LogManager.logSyncOperation(
      module: module,
      action: action,
      table: table,
      status: status,
      recordId: recordId,
      summary: summary,
      error: error,
    );

    await PatientSyncLog.addLog(
      PatientSyncLog(
        syncTime: DateTime.now(),
        entityType: entityType,
        entityName: entityName,
        action: action,
        status: status,
        patientId: patientId ?? recordId,
        recordId: recordId,
        patientName: PatientSyncLogHelper.extractSummaryValue(summary, 'name'),
        medicalRecordNumber:
            PatientSyncLogHelper.extractSummaryValue(summary, 'mrn'),
        fieldChanges: fieldChanges,
        errorMessage: error,
      ),
    );
  }

  static const Map<String, String> _patientSyncFields = {
    'name': '姓名',
    'age': '年龄',
    'gender': '性别',
    'phone': '电话',
    'medical_record_number': '病历号',
    'address': '地址',
    'identification_number': '身份证号',
    'doctor': '医生',
    'dental_condition': '牙齿状况',
    'treatment_items': '治疗项目',
    'first_visit_date': '初诊日期',
    'total_cost': '总费用',
  };
}

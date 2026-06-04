import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../models/patient.dart';
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
    if (patient.address != null) {
      patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
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
    if (patient.address != null) {
      patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
    }

    final success = await dataSource.updatePatient(Patient.fromMap(patientMap));
    
    if (success && getEffectiveDataSourceType() == 'sqlite') {
      _trySyncPatientToMySQL(patientMap, patient.id!);
    }
    return success;
  }

  /// 删除患者
  Future<bool> deletePatient(int patientId, {String? patientName, dynamic medicalRecordNumber}) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) throw Exception('数据源未初始化');

    final success = await dataSource.deletePatient(patientId);
    
    if (success && getEffectiveDataSourceType() == 'sqlite') {
      _trySyncDeletePatientToMySQL(patientId, patientName: patientName, medicalRecordNumber: medicalRecordNumber);
    }
    return success;
  }

  /// 检查病历号是否存在
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber, [int? excludePatientId]) async {
    final dataSource = getCurrentDataSource();
    if (dataSource == null) throw Exception('数据源未初始化');
    return await dataSource.checkMedicalRecordExists(medicalRecordNumber, excludePatientId);
  }

  /// 检查姓名是否存在
  Future<bool> checkPatientNameExists(String name, [int? excludePatientId]) async {
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
        if (i + 1 < hexData.length) bytes.add(int.parse(hexData.substring(i, i + 2), radix: 16));
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
        if (i + 1 < hexData.length) bytes.add(int.parse(hexData.substring(i, i + 2), radix: 16));
      }
      return "$fieldName', '${String.fromCharCodes(bytes)}'";
    });
  }

  // =================== 后台同步私有逻辑 ===================

  void _trySyncPatientToMySQL(Map<String, dynamic> patientMap, int sqliteId) {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        final summary = 'name=${patientMap['name']}, mrn=${patientMap['medical_record_number'] ?? ''}';
        if (conn == null) {
          await LogManager.logSyncOperation(
            module: 'patient',
            action: 'upsert',
            table: 'patients',
            status: 'skipped',
            recordId: sqliteId,
            summary: summary,
            error: 'mysql_connection_unavailable',
          );
          return;
        }
        
        final name = patientMap['name'];
        final mrn = patientMap['medical_record_number'];

        Results existById = await conn.query('SELECT id, name FROM patients WHERE id = ? LIMIT 1', [sqliteId]);
        bool isUpdate = false;
        int targetId = sqliteId;

        if (existById.isNotEmpty && existById.first['name'] == name) {
          isUpdate = true;
        } else if (mrn != null) {
          Results existByMrn = await conn.query('SELECT id FROM patients WHERE medical_record_number = ? AND name = ? LIMIT 1', [mrn, name]);
          if (existByMrn.isNotEmpty) {
            isUpdate = true;
            targetId = existByMrn.first['id'];
          }
        }

        if (isUpdate) {
          await conn.query('''
            UPDATE patients SET
              name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?,
              medical_record_number = ?, address = ?, address_pinyin = ?, identification_number = ?,
              doctor = ?, dental_condition = ?, treatment_items = ?, first_visit_date = ?, total_cost = ?, created_at = ?, updated_at = ?
            WHERE id = ?
          ''', [
            patientMap['name'], patientMap['name_pinyin'], patientMap['name_initials'], patientMap['age'], patientMap['gender'], patientMap['phone'],
            patientMap['medical_record_number'], patientMap['address'], patientMap['address_pinyin'], patientMap['identification_number'],
            patientMap['doctor'], patientMap['dental_condition'], patientMap['treatment_items'], patientMap['first_visit_date'], patientMap['total_cost'],
            patientMap['created_at'], patientMap['updated_at'], targetId,
          ]);
        } else {
          await conn.query('''
            INSERT INTO patients
            (id, name, name_pinyin, name_initials, age, gender, phone, medical_record_number, address, address_pinyin, identification_number, doctor, dental_condition, treatment_items, first_visit_date, total_cost, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            sqliteId, patientMap['name'], patientMap['name_pinyin'], patientMap['name_initials'], patientMap['age'], patientMap['gender'], patientMap['phone'],
            patientMap['medical_record_number'], patientMap['address'], patientMap['address_pinyin'], patientMap['identification_number'],
            patientMap['doctor'], patientMap['dental_condition'], patientMap['treatment_items'], patientMap['first_visit_date'], patientMap['total_cost'],
            patientMap['created_at'], patientMap['updated_at'],
          ]);
        }
        await LogManager.logSyncOperation(
          module: 'patient',
          action: isUpdate ? 'update' : 'create',
          table: 'patients',
          status: 'success',
          recordId: sqliteId,
          summary: summary,
        );
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'patient',
          action: 'upsert',
          table: 'patients',
          status: 'failed',
          recordId: sqliteId,
          summary: 'name=${patientMap['name']}, mrn=${patientMap['medical_record_number'] ?? ''}',
          error: e.toString(),
        );
        print('PatientCoreService: MySQL同步失败: $e');
      }
    });
  }

  void _trySyncDeletePatientToMySQL(int patientId, {String? patientName, dynamic medicalRecordNumber}) {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        final summary = 'name=${patientName ?? ''}, mrn=${medicalRecordNumber ?? ''}';
        if (conn == null) {
          await LogManager.logSyncOperation(
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
        
        final check = await conn.query('SELECT id, name FROM patients WHERE id = ? LIMIT 1', [patientId]);
        if (check.isEmpty) {
          await LogManager.logSyncOperation(
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
          await LogManager.logSyncOperation(
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

        await conn.query('SET FOREIGN_KEY_CHECKS = 0');
        
        final matIds = (await conn.query('SELECT id FROM patient_materials WHERE patient_id = ?', [patientId])).map((r) => r['id'] as int).toList();
        if (matIds.isNotEmpty) {
          final p = matIds.map((_) => '?').join(',');
          await conn.query('DELETE FROM material_images WHERE material_id IN ($p)', matIds);
        }
        await conn.query('DELETE FROM patient_materials WHERE patient_id = ?', [patientId]);
        await conn.query('DELETE FROM financial_records WHERE patient_id = ?', [patientId]);
        await conn.query('DELETE FROM appointments WHERE patient_id = ?', [patientId]);
        await conn.query('DELETE FROM patient_medical_records WHERE patient_id = ?', [patientId]);
        await conn.query('DELETE FROM patients WHERE id = ?', [patientId]);
        
        await conn.query('SET FOREIGN_KEY_CHECKS = 1');
        await LogManager.logSyncOperation(
          module: 'patient',
          action: 'delete',
          table: 'patients',
          status: 'success',
          recordId: patientId,
          summary: summary,
        );
      } catch (e) {
        await LogManager.logSyncOperation(
          module: 'patient',
          action: 'delete',
          table: 'patients',
          status: 'failed',
          recordId: patientId,
          summary: 'name=${patientName ?? ''}, mrn=${medicalRecordNumber ?? ''}',
          error: e.toString(),
        );
        print('PatientCoreService: MySQL同步删除失败: $e');
      }
    });
  }
}

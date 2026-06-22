import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/database_models.dart';
import '../utils/pinyin_util.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';

// 抽象患者数据源接口
abstract class PatientDataSource {
  Future<List<Patient>> getAllPatients();
  Future<Patient?> getPatientById(int id);
  Future<int> createPatient(Patient patient);
  Future<bool> updatePatient(Patient patient);
  Future<bool> deletePatient(int id);
  Future<List<Patient>> searchPatients(String keyword);
  Future<int> getPatientsCount();
  Future<List<Patient>> getPaginatedPatients(int page, int pageSize, {String? sortField, bool? ascending});
}

// SQLite患者数据源实现
class SqlitePatientDataSource implements PatientDataSource {
  final Database _database;

  SqlitePatientDataSource(this._database);

  // 提供database getter以保持向后兼容
  Database get database => _database;

  @override
  Future<List<Patient>> getAllPatients() async {
    final result = await _database.rawQuery(
      'SELECT * FROM patients ORDER BY created_at DESC'
    );
    return result.map((e) => Patient.fromMap(e)).toList();
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM patients WHERE id = ?', [id]
    );
    if (result.isEmpty) return null;
    return Patient.fromMap(result.first);
  }

  @override
  Future<int> createPatient(Patient patient) async {
    // 自动生成拼音
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }
    
    return await _database.insert('patients', patient.toMap());
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    // 自动更新拼音
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
    // 为拼音搜索创建另一个不带空格的查询条件
    final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');

    // 构建搜索SQL - 增加对拼音搜索的支持，包括无空格的情况和首字母搜索
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

    // 为每个搜索条件添加模糊匹配参数
    final whereArgs = [
      '%$lowercaseQuery%', // name
      '%$lowercaseQuery%', // phone
      '%$lowercaseQuery%', // address
      '%$lowercaseQuery%', // identification_number
      '%$lowercaseQuery%', // name_pinyin
      '%$noSpaceQuery%', // name_pinyin (无空格)
      '%$lowercaseQuery%', // name_pinyin 中移除空格后匹配
      '%$lowercaseQuery%', // address_pinyin
      '%$noSpaceQuery%', // address_pinyin (无空格)
      '%$lowercaseQuery%', // address_pinyin 中移除空格后匹配
      '%$lowercaseQuery%', // name_initials
      '%$lowercaseQuery%', // medical_record_number
    ];

    final result = await _database.query('patients', where: where, whereArgs: whereArgs);

    List<Patient> patients = [];
    for (var map in result) {
      try {
        Patient patient = Patient.fromMap(map);
        patients.add(patient);
      } catch (e) {
        print('转换患者对象错误: $e, 数据: $map');
      }
    }

    // 添加结果去重逻辑
    Map<int?, Patient> uniquePatients = <int?, Patient>{};
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
  Future<List<Patient>> getPaginatedPatients(int page, int pageSize, {String? sortField, bool? ascending}) async {
    final offset = (page - 1) * pageSize;
    
    // 根据排序字段和方向构建排序SQL
    String orderBy = 'updated_at DESC'; // 默认按更新时间降序
    
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

// MySQL患者数据源实现（使用动态连接获取）
class MySqlPatientDataSource implements PatientDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlPatientDataSource.withConnectionGetter(this._getConnection);

  // 辅助方法：处理MySQL行数据转换
  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];
      
      // 处理日期字段 - 使用统一格式
      if (field == 'created_at' || field == 'updated_at' || field == 'first_visit_date') {
        if (value is DateTime) {
          // 如果MySQL返回的是UTC时间，转换为本地时间
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        // 处理Blob字段，特别是文本字段
        if (field == 'name' || field == 'phone' || field == 'identification_number' || field == 'address') {
          try {
            final bytes = value.toBytes();
            if (bytes.isNotEmpty) {
              final stringValue = utf8.decode(bytes, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            print('Blob转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else if (value is Uint8List) {
        // 处理Uint8List类型
        if (field == 'name' || field == 'phone' || field == 'identification_number' || field == 'address') {
          try {
            if (value.isNotEmpty) {
              final stringValue = utf8.decode(value, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            print('Uint8List转换失败: $e');
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
    
    return results.map((row) => Patient.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('''
      SELECT id, medical_record_number, name, name_pinyin, name_initials, age, gender, phone, 
             identification_number, doctor, address, address_pinyin, first_visit_date, 
             dental_condition, treatment_items, total_cost, created_at, updated_at
      FROM patients 
      WHERE id = ?
    ''', [id]);
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    return Patient.fromMap(_convertMySqlRow(row));
  }

  @override
  Future<int> createPatient(Patient patient) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    // 自动生成拼音
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }
    
    final result = await connection.query('''
      INSERT INTO patients (medical_record_number, name, name_pinyin, name_initials, age, gender, phone, 
                           identification_number, doctor, address, address_pinyin, first_visit_date, 
                           dental_condition, treatment_items, total_cost, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''', [
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
      patient.firstVisitDate != null ? DateTimeFormatter.toDbString(patient.firstVisitDate!) : null,
      patient.dentalCondition,
      patient.treatmentItems,
      patient.totalCost,
    ]);
    
    return result.insertId ?? 0;
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    // 自动更新拼音
    patient.namePinyin = PinyinUtil.toPinyin(patient.name);
    patient.nameInitials = PinyinUtil.getInitials(patient.name);
    if (patient.address != null && patient.address!.isNotEmpty) {
      patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
    }
    
    final result = await connection.query('''
      UPDATE patients 
      SET medical_record_number = ?, name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?, 
          identification_number = ?, doctor = ?, address = ?, address_pinyin = ?, first_visit_date = ?, 
          dental_condition = ?, treatment_items = ?, total_cost = ?, updated_at = NOW()
      WHERE id = ?
    ''', [
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
      patient.firstVisitDate != null ? DateTimeFormatter.toDbString(patient.firstVisitDate!) : null,
      patient.dentalCondition,
      patient.treatmentItems,
      patient.totalCost,
      patient.id,
    ]);
    
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePatient(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('DELETE FROM patients WHERE id = ?', [id]);
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

    // 构建模糊搜索参数（统一小写，MySQL LOWER() 对应）
    final lowerKeyword = trimmed.toLowerCase();
    final searchPattern = '%$lowerKeyword%';

    // 为拼音搜索创建无空格版本
    final noSpaceQuery = lowerKeyword.replaceAll(' ', '');
    final noSpacePattern = '%$noSpaceQuery%';

    // 执行查询 - 添加对拼音字段的支持并优化查询，支持无空格拼音
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
      
      -- 添加精确匹配的结果（会排在前面）
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
        // 模糊匹配参数
        searchPattern, // name
        searchPattern, // phone
        searchPattern, // address
        searchPattern, // identification_number
        searchPattern, // name_pinyin
        noSpacePattern, // name_pinyin 无空格
        searchPattern, // name_pinyin 中的空格替换为空字符串后匹配
        searchPattern, // address_pinyin
        noSpacePattern, // address_pinyin 无空格
        searchPattern, // address_pinyin 中的空格替换为空字符串后匹配
        searchPattern, // name_initials
        searchPattern, // medical_record_number
        // 精确匹配参数
        lowerKeyword, // name
        trimmed, // phone
        lowerKeyword, // address
        trimmed, // identification_number
        lowerKeyword, // name_pinyin
        lowerKeyword, // address_pinyin
        lowerKeyword, // name_initials
        trimmed, // medical_record_number
        // 排序优先级参数
        lowerKeyword, // name (优先级0)
        trimmed, // phone (优先级1)
        trimmed, // medical_record_number (优先级2)
      ],
    );

    // 转换并去重患者数据
    List<Patient> patients = results.map((row) => Patient.fromMap(_convertMySqlRow(row))).toList();

    // 添加结果去重逻辑
    Map<int?, Patient> uniquePatients = <int?, Patient>{};
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
    
    final results = await connection.query('SELECT COUNT(*) as count FROM patients');
    final row = results.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<List<Patient>> getPaginatedPatients(int page, int pageSize, {String? sortField, bool? ascending}) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final offset = (page - 1) * pageSize;
    
    // 根据排序字段和方向构建排序SQL
    String orderBy = 'updated_at DESC'; // 默认按更新时间降序
    
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
    
    final results = await connection.query('''
      SELECT id, medical_record_number, name, name_pinyin, name_initials, age, gender, phone, 
             identification_number, doctor, address, address_pinyin, first_visit_date, 
             dental_condition, treatment_items, total_cost, created_at, updated_at, medical_history
      FROM patients 
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''', [pageSize, offset]);
    
    return results.map((row) => Patient.fromMap(_convertMySqlRow(row))).toList();
  }
}

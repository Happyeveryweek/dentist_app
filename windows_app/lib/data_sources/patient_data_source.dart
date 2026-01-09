import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'base_mysql_data_source.dart';

// 抽象患者数据源接口
abstract class PatientDataSource {
  Future<List<Patient>> getAllPatients();
  Future<Patient?> getPatientById(int id);
  Future<int> createPatient(Patient patient);
  Future<bool> updatePatient(Patient patient);
  Future<bool> deletePatient(int id);
  Future<List<Patient>> searchPatients(String query);
  
  // 分页查询方法
  Future<int> getPatientsCount({String? searchQuery});
  Future<Map<String, dynamic>> getPatientsPage({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
  });
  
  // 患者特有方法
  Future<List<Patient>> getPatientsByDoctor(String doctorName);
  Future<List<int>> searchPatientIds(String query);
  Future<List<Patient>> getPatientsByIds(List<int> ids);
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber, [int? excludePatientId]);
  Future<bool> checkPatientNameExists(String name, [int? excludePatientId]);
  Future<void> updateAllPatientsPinyin();
  
  // 患者材料相关方法
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material);
  Future<List<PatientMaterial>> getPatientMaterials(int patientId);
  Future<bool> updatePatientMaterial(PatientMaterial material);
  Future<bool> deletePatientMaterial(int id);
  
  // 患者材料图片相关方法
  Future<List<MaterialImage>> getMaterialImages(int materialId);
  Future<MaterialImage> addMaterialImage(MaterialImage image);
  Future<bool> updateMaterialImage(MaterialImage image);
  Future<bool> deleteMaterialImage(int imageId);
}

// SQLite患者数据源实现
class SqlitePatientDataSource implements PatientDataSource {
  final Database _database;
  final String? _doctorName;
  final bool _isAdmin;
  
  // 辅助方法：安全检查医生名称
  bool get _hasDoctorName => _doctorName != null && _doctorName!.isNotEmpty;

  SqlitePatientDataSource(this._database, {String? doctorName, bool isAdmin = false})
      : _doctorName = doctorName,
        _isAdmin = isAdmin;

  @override
  Future<List<Patient>> getAllPatients() async {
    try {
      // 所有用户都可以查看所有患者数据（权限控制在UI层面）
      final maps = await _database.query('patients');

      return List.generate(maps.length, (i) {
        return Patient.fromMap(maps[i]);
      });
    } catch (e) {
      print('获取患者时出错: $e');
      return [];
    }
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    try {
      List<Map<String, dynamic>> maps;

      if (_isAdmin) {
        // 管理员可以查看任何患者
        maps = await _database.query(
          'patients',
          where: 'id = ?',
          whereArgs: [id],
        );
      } else {
        // 医生只能查看自己的患者
        if (!_hasDoctorName) {
          maps = await _database.query(
            'patients',
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          maps = await _database.query(
            'patients',
            where: 'id = ? AND doctor = ?',
            whereArgs: [id, _doctorName],
          );
        }
      }

      if (maps.isNotEmpty) {
        return Patient.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('获取患者时出错: $e');
      return null;
    }
  }

  @override
  Future<int> createPatient(Patient patient) async {
    try {
      final id = await _database.insert('patients', patient.toMap());
      return id;
    } catch (e) {
      print('添加患者时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    if (patient.id == null) {
      throw Exception('更新患者时必须提供ID');
    }

    try {
      final result = await _database.update(
        'patients',
        patient.toMap(),
        where: 'id = ?',
        whereArgs: [patient.id],
      );
      return result > 0;
    } catch (e) {
      print('更新患者数据时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deletePatient(int patientId) async {
    try {
      // 1. 首先获取该患者的所有材料ID
      final materialIdsResult = await _database.rawQuery('''
        SELECT id FROM patient_materials WHERE patient_id = ?
      ''', [patientId]);
      
      final materialIds = materialIdsResult.map((row) => row['id'] as int).toList();
      
      // 2. 删除这些材料相关的图片
      if (materialIds.isNotEmpty) {
        final placeholders = materialIds.map((_) => '?').join(',');
        await _database.delete(
          'material_images',
          where: 'material_id IN ($placeholders)',
          whereArgs: materialIds,
        );
      }

      // 3. 删除患者材料
      await _database.delete(
        'patient_materials',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      // 4. 删除财务记录
      final financialRecordIds = await _database.rawQuery('''
        SELECT id FROM financial_records WHERE patient_id = ?
      ''', [patientId]);
      
      if (financialRecordIds.isNotEmpty) {
        final recordIds = financialRecordIds.map((row) => row['id'] as int).toList();
        final placeholders = recordIds.map((_) => '?').join(',');
        
        await _database.delete(
          'financial_items',
          where: 'financial_record_id IN ($placeholders)',
          whereArgs: recordIds,
        );
      }
      
      await _database.delete(
        'financial_records',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      // 5. 删除预约记录
      await _database.delete(
        'appointments',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      // 6. 删除患者病历记录
      await _database.delete(
        'patient_medical_records',
        where: 'patient_id = ?',
        whereArgs: [patientId],
      );

      // 7. 最后删除患者记录
      final patientResult = await _database.delete(
        'patients',
        where: 'id = ?',
        whereArgs: [patientId],
      );

      return patientResult > 0;
    } catch (e) {
      print('删除患者时出错: $e');
      throw Exception('删除患者失败: $e');
    }
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    try {
      // 处理查询字符串，生成无空格版本用于拼音搜索
      String queryNoSpace = query.replaceAll(' ', '');

      // 构建权限过滤条件
      String whereClause = '''
        medical_record_number LIKE ? 
        OR name LIKE ? 
        OR (name_pinyin IS NOT NULL AND name_pinyin LIKE ?)
        OR (name_pinyin IS NOT NULL AND REPLACE(name_pinyin, ' ', '') LIKE ?)
        OR (name_initials IS NOT NULL AND name_initials LIKE ?)
        OR phone LIKE ? 
        OR address LIKE ?
        OR (address_pinyin IS NOT NULL AND address_pinyin LIKE ?)
        OR (address_pinyin IS NOT NULL AND REPLACE(address_pinyin, ' ', '') LIKE ?)
      ''';

      List<dynamic> whereArgs = [
        '%$query%', // 病历号
        '%$query%', // 姓名
        '%$query%', // 姓名拼音带空格
        '%$queryNoSpace%', // 删除数据库中拼音空格后匹配无空格输入
        '%$query%', // 姓名首字母
        '%$query%', // 电话
        '%$query%', // 地址
        '%$query%', // 地址拼音带空格
        '%$queryNoSpace%', // 删除数据库中拼音空格后匹配无空格输入
      ];

      // 添加医生权限过滤
      if (!_isAdmin && _hasDoctorName) {
        whereClause += ' AND doctor = ?';
        whereArgs.add(_doctorName);
      }

      final List<Map<String, dynamic>> results = await _database.rawQuery(
        'SELECT * FROM patients WHERE $whereClause ORDER BY updated_at DESC, id DESC',
        whereArgs,
      );

      return results.map((data) => Patient.fromMap(data)).toList();
    } catch (e) {
      print('搜索患者时出错: $e');
      return [];
    }
  }

  @override
  Future<int> getPatientsCount({String? searchQuery}) async {
    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        String queryNoSpace = searchQuery.replaceAll(' ', '');
        whereClause = '''
          name LIKE ? 
          OR phone LIKE ? 
          OR address LIKE ? 
          OR identification_number LIKE ? 
          OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?))
          OR (name_initials IS NOT NULL AND name_initials LIKE ?)
          OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
        ''';

        whereArgs = [
          '%$searchQuery%', // 姓名
          '%$searchQuery%', // 电话
          '%$searchQuery%', // 地址
          '%$searchQuery%', // 身份证号
          '%$searchQuery%', // 姓名拼音带空格
          '%$queryNoSpace%', // 姓名拼音无空格
          '%$searchQuery%', // 姓名首字母
          '%$searchQuery%', // 地址拼音带空格
          '%$queryNoSpace%', // 地址拼音无空格
        ];
      }

      // 添加医生权限过滤
      if (!_isAdmin && _hasDoctorName) {
        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += 'doctor = ?';
        whereArgs.add(_doctorName);
      }

      final countResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
        whereArgs,
      );
      return countResult.first['count'] as int;
    } catch (e) {
      print('获取患者数量时出错: $e');
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
      List<Patient> patients = [];
      int totalCount = 0;

      // 处理搜索和排序
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        String queryNoSpace = searchQuery.replaceAll(' ', '');

        whereClause = '''
        name LIKE ? 
        OR phone LIKE ? 
        OR address LIKE ? 
        OR identification_number LIKE ? 
        OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?))
        OR (name_initials IS NOT NULL AND name_initials LIKE ?)
        OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
        ''';

        whereArgs = [
          '%$searchQuery%', // 姓名
          '%$searchQuery%', // 电话
          '%$searchQuery%', // 地址
          '%$searchQuery%', // 身份证号
          '%$searchQuery%', // 姓名拼音带空格
          '%$queryNoSpace%', // 姓名拼音无空格
          '%$searchQuery%', // 姓名首字母
          '%$searchQuery%', // 地址拼音带空格
          '%$queryNoSpace%', // 地址拼音无空格
        ];
      }

      // 添加日期过滤条件
      if (startDate != null && endDate != null) {
        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += '$dateFilterType BETWEEN ? AND ?';
        whereArgs.add(DateTimeFormatter.toDbString(startDate));
        whereArgs.add(DateTimeFormatter.toDbString(endDate));
      }

      // 添加医生权限过滤
      if (!_isAdmin && _hasDoctorName) {
        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += 'doctor = ?';
        whereArgs.add(_doctorName);
      }

      // 获取总数
      final countResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
        whereArgs,
      );
      totalCount = countResult.first['count'] as int;

      // 处理排序
      String orderBy = 'updated_at DESC'; // 默认排序

      if (sortField != null && sortField.isNotEmpty) {
        String fieldName = sortField;
        if (sortField == 'medical_record_number') {
          fieldName = 'CAST(medical_record_number AS INTEGER)';
        }
        orderBy = '$fieldName ${sortAscending ? 'ASC' : 'DESC'}';
      }

      // 执行查询
      final List<Map<String, dynamic>> maps = await _database.rawQuery(
        'SELECT * FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''} ORDER BY $orderBy LIMIT $pageSize OFFSET $offset',
        whereArgs,
      );

      // 转换为Patient对象
      patients = maps.map((map) => Patient.fromMap(map)).toList();

      return {
        'patients': patients,
        'totalCount': totalCount,
        'totalPages': (totalCount / pageSize).ceil(),
        'currentPage': page,
      };
    } catch (e) {
      print('获取患者分页数据时出错: $e');
      rethrow;
    }
  }

  @override
  Future<List<Patient>> getPatientsByDoctor(String doctorName) async {
    try {
      final maps = await _database.query(
        'patients',
        where: 'doctor = ?',
        whereArgs: [doctorName],
      );

      return List.generate(maps.length, (i) {
        return Patient.fromMap(maps[i]);
      });
    } catch (e) {
      print('根据医生获取患者时出错: $e');
      return [];
    }
  }

  @override
  Future<List<int>> searchPatientIds(String query) async {
    try {
      final conditions = <String>[];
      final args = <Object?>[];
      conditions.add('(name LIKE ? OR name_pinyin LIKE ? OR name_initials LIKE ? OR medical_record_number LIKE ?)');
      args.addAll(['%$query%', '%$query%', '%$query%', '%$query%']);
      
      if (!_isAdmin && _hasDoctorName) {
        conditions.add('doctor = ?');
        args.add(_doctorName);
      }
      
      final where = conditions.join(' AND ');
      final maps = await _database.query('patients', columns: ['id'], where: where, whereArgs: args);
      return maps.map((m) => m['id'] as int).toList();
    } catch (e) {
      print('searchPatientIds 出错: $e');
      return [];
    }
  }

  @override
  Future<List<Patient>> getPatientsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    try {
      final placeholders = List.filled(ids.length, '?').join(',');
      String whereClause = 'id IN ($placeholders)';
      final whereArgs = <Object?>[...ids];
      
      if (!_isAdmin && _hasDoctorName) {
        whereClause += ' AND doctor = ?';
        whereArgs.add(_doctorName);
      }
      
      final maps = await _database.query('patients', where: whereClause, whereArgs: whereArgs);
      return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
    } catch (e) {
      print('getPatientsByIds 出错: $e');
      return [];
    }
  }

  @override
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber, [int? excludePatientId]) async {
    try {
      String whereClause = 'medical_record_number = ?';
      List<dynamic> whereArgs = [medicalRecordNumber];

      if (excludePatientId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excludePatientId);
      }

      final result = await _database.query(
        'patients',
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('检查病历号存在性时出错: $e');
      return false;
    }
  }

  @override
  Future<bool> checkPatientNameExists(String name, [int? excludePatientId]) async {
    try {
      String whereClause = 'name = ?';
      List<dynamic> whereArgs = [name];

      if (excludePatientId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excludePatientId);
      }

      final result = await _database.query(
        'patients',
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );

      return result.isNotEmpty;
    } catch (e) {
      print('检查患者姓名存在性时出错: $e');
      return false;
    }
  }

  @override
  Future<void> updateAllPatientsPinyin() async {
    // 这个方法需要在Provider层实现，因为需要访问PinyinUtil
    throw UnimplementedError('updateAllPatientsPinyin should be implemented in Provider layer');
  }

  // 患者材料相关方法实现
  @override
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material) async {
    try {
      final id = await _database.insert('patient_materials', material.toMap());
      return material.copyWith(id: id);
    } catch (e) {
      print('添加患者材料失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    try {
      final results = await _database.query(
        'patient_materials',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'created_at DESC',
      );
      
      return results.map((map) => PatientMaterial.fromMap(map)).toList();
    } catch (e) {
      print('获取患者材料失败: $e');
      return [];
    }
  }

  @override
  Future<bool> updatePatientMaterial(PatientMaterial material) async {
    try {
      final count = await _database.update(
        'patient_materials',
        material.toMap(),
        where: 'id = ?',
        whereArgs: [material.id],
      );
      return count > 0;
    } catch (e) {
      print('更新患者材料失败: $e');
      return false;
    }
  }

  @override
  Future<bool> deletePatientMaterial(int id) async {
    try {
      // 使用联表删除，确保图片被正确删除
      await _database.transaction((txn) async {
        // 先删除关联的图片数据
        await txn.delete(
          'material_images',
          where: 'material_id = ?',
          whereArgs: [id],
        );

        // 然后删除材料记录
        await txn.delete(
          'patient_materials',
          where: 'id = ?',
          whereArgs: [id],
        );
      });
      return true;
    } catch (e) {
      print('删除患者材料失败: $e');
      return false;
    }
  }

  // 患者材料图片相关方法实现
  @override
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    try {
      final result = await _database.query(
        'material_images',
        where: 'material_id = ?',
        whereArgs: [materialId],
        orderBy: 'created_at DESC',
      );
      return result.map((e) => MaterialImage.fromMap(e)).toList();
    } catch (e) {
      print('获取材料图片失败: $e');
      return [];
    }
  }

  @override
  Future<MaterialImage> addMaterialImage(MaterialImage image) async {
    try {
      final id = await _database.insert('material_images', image.toMap());
      return image.copyWith(id: id);
    } catch (e) {
      print('添加材料图片失败: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateMaterialImage(MaterialImage image) async {
    try {
      final count = await _database.update(
        'material_images',
        image.toMap(),
        where: 'id = ?',
        whereArgs: [image.id],
      );
      return count > 0;
    } catch (e) {
      print('更新材料图片失败: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteMaterialImage(int imageId) async {
    try {
      final count = await _database.delete(
        'material_images',
        where: 'id = ?',
        whereArgs: [imageId],
      );
      return count > 0;
    } catch (e) {
      print('删除材料图片失败: $e');
      return false;
    }
  }
}

// MySQL患者数据源实现
class MySqlPatientDataSource extends BaseMySqlDataSource implements PatientDataSource {
  final String? _doctorName;
  final bool _isAdmin;
  
  // 辅助方法：安全检查医生名称
  bool get _hasDoctorName => _doctorName != null && _doctorName!.isNotEmpty;

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
      print('MySqlPatientDataSource: 开始获取所有患者数据...');
      
      // 所有用户都可以查看所有患者数据（权限控制在UI层面）
      final results = await executeQuery('SELECT * FROM patients');
      
      print('MySqlPatientDataSource: 查询返回 ${results.length} 条记录');
      print('MySqlPatientDataSource: 开始转换数据...');

      List<Patient> patients = [];
      for (var row in results) {
        final map = convertRowToMap(row);
        patients.add(Patient.fromMap(map));
      }

      return patients;
    } catch (e) {
      print('获取所有患者时出错: $e');
      return [];
    }
  }

  @override
  Future<Patient?> getPatientById(int id) async {
    try {
      Results results;

      if (_isAdmin) {
        // 管理员可以查看任何患者
        results = await executeQuery('SELECT * FROM patients WHERE id = ?', [id]);
      } else {
        // 医生只能查看自己的患者
        if (!_hasDoctorName) {
          results = await executeQuery('SELECT * FROM patients WHERE id = ?', [id]);
        } else {
          results = await executeQuery(
              'SELECT * FROM patients WHERE id = ? AND doctor = ?',
              [id, _doctorName]);
        }
      }

      if (results.isEmpty) {
        return null;
      }

      final row = results.first;
      final map = convertRowToMap(row);
      return Patient.fromMap(map);
    } catch (e) {
      print('获取患者时出错: $e');
      return null;
    }
  }

  @override
  Future<int> createPatient(Patient patient) async {
    try {
      final patientMap = patient.toMap();
      final result = await executeQuery('''
        INSERT INTO patients (name, name_pinyin, name_initials, age, gender, phone, medical_record_number, address, address_pinyin, identification_number, doctor, dental_condition, treatment_items, first_visit_date, total_cost, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
      ]);

      return result.insertId ?? 0;
    } catch (e) {
      print('添加患者(MySQL)时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updatePatient(Patient patient) async {
    if (patient.id == null) {
      throw Exception('更新患者时必须提供ID');
    }

    try {
      final patientMap = patient.toMap();
      final result = await executeQuery('''
        UPDATE patients SET name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?, medical_record_number = ?, address = ?, address_pinyin = ?, identification_number = ?, doctor = ?, dental_condition = ?, treatment_items = ?, first_visit_date = ?, total_cost = ?, updated_at = ? WHERE id = ?
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
        patientMap['updated_at'],
        patient.id,
      ]);

      return result.affectedRows! > 0;
    } catch (e) {
      print('更新患者数据(MySQL)时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deletePatient(int patientId) async {
    try {
      // 禁用外键约束检查，以便我们可以按顺序删除
      await executeQuery('SET FOREIGN_KEY_CHECKS = 0');

      // 1. 首先获取该患者的所有材料ID
      final materialIdsResult = await executeQuery('''
        SELECT id FROM patient_materials WHERE patient_id = ?
      ''', [patientId]);
      
      final materialIds = materialIdsResult.map((row) => row[0] as int).toList();
      
      // 2. 删除这些材料相关的图片
      if (materialIds.isNotEmpty) {
        final placeholders = materialIds.map((_) => '?').join(',');
        await executeQuery(
          'DELETE FROM material_images WHERE material_id IN ($placeholders)',
          materialIds,
        );
      }

      // 3. 删除患者材料
      await executeQuery(
        'DELETE FROM patient_materials WHERE patient_id = ?',
        [patientId],
      );

      // 4. 删除财务记录
      final financialRecordIds = await executeQuery('''
        SELECT id FROM financial_records WHERE patient_id = ?
      ''', [patientId]);
      
      if (financialRecordIds.isNotEmpty) {
        final recordIds = financialRecordIds.map((row) => row[0] as int).toList();
        if (recordIds.isNotEmpty) {
          final placeholders = recordIds.map((_) => '?').join(',');
          await executeQuery(
            'DELETE FROM financial_items WHERE financial_record_id IN ($placeholders)',
            recordIds,
          );
        }
      }
      
      await executeQuery(
        'DELETE FROM financial_records WHERE patient_id = ?',
        [patientId],
      );

      // 5. 删除预约记录
      await executeQuery(
        'DELETE FROM appointments WHERE patient_id = ?',
        [patientId],
      );

      // 6. 删除患者病历记录
      await executeQuery(
        'DELETE FROM patient_medical_records WHERE patient_id = ?',
        [patientId],
      );

      // 7. 最后删除患者记录
      final patientResult = await executeQuery(
        'DELETE FROM patients WHERE id = ?',
        [patientId],
      );

      // 恢复外键约束检查
      await executeQuery('SET FOREIGN_KEY_CHECKS = 1');

      return patientResult.affectedRows! > 0;
    } catch (e) {
      print('MySQL删除患者时出错: $e');
      // 确保恢复外键约束检查
      try {
        await executeQuery('SET FOREIGN_KEY_CHECKS = 1');
      } catch (e2) {
        print('恢复外键约束检查时出错: $e2');
      }
      throw Exception('删除患者失败: $e');
    }
  }

  @override
  Future<List<Patient>> searchPatients(String query) async {
    try {
      // 优先尝试包含拼音列的查询；失败则回退到基础查询（name/MRN）
      String queryNoSpace = query.replaceAll(' ', '');
      
      String whereClause = '''
        (name LIKE ? OR name_pinyin LIKE ? OR name_initials LIKE ? OR medical_record_number LIKE ? OR phone LIKE ? OR address LIKE ? OR address_pinyin LIKE ?)
      ''';
      
      List<dynamic> whereArgs = [
        '%$query%', '%$query%', '%$query%', '%$query%', '%$query%', '%$query%', '%$query%'
      ];

      // 添加医生权限过滤
      if (!_isAdmin && _hasDoctorName) {
        whereClause += ' AND doctor = ?';
        whereArgs.add(_doctorName);
      }

      try {
        final results = await executeQuery(
          'SELECT * FROM patients WHERE $whereClause ORDER BY updated_at DESC',
          whereArgs,
        );

        List<Patient> patients = [];
        for (var row in results) {
          final map = convertRowToMap(row);
          patients.add(Patient.fromMap(map));
        }
        return patients;
      } catch (e1) {
        print('包含拼音列的MySQL查询失败，回退到基础查询: $e1');
        // 回退到基础查询
        String basicWhereClause = '(name LIKE ? OR medical_record_number LIKE ?)';
        List<dynamic> basicWhereArgs = ['%$query%', '%$query%'];
        
        if (!_isAdmin && _hasDoctorName) {
          basicWhereClause += ' AND doctor = ?';
          basicWhereArgs.add(_doctorName);
        }

        final results = await executeQuery(
          'SELECT * FROM patients WHERE $basicWhereClause ORDER BY updated_at DESC',
          basicWhereArgs,
        );

        List<Patient> patients = [];
        for (var row in results) {
          final map = convertRowToMap(row);
          patients.add(Patient.fromMap(map));
        }
        return patients;
      }
    } catch (e) {
      print('搜索患者时出错: $e');
      return [];
    }
  }

  @override
  Future<int> getPatientsCount({String? searchQuery}) async {
    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        String queryNoSpace = searchQuery.replaceAll(' ', '');
        whereClause = '''
          name LIKE ? 
          OR phone LIKE ? 
          OR address LIKE ? 
          OR identification_number LIKE ? 
          OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?))
          OR (name_initials IS NOT NULL AND name_initials LIKE ?)
          OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
        ''';

        whereArgs = [
          '%$searchQuery%', // 姓名
          '%$searchQuery%', // 电话
          '%$searchQuery%', // 地址
          '%$searchQuery%', // 身份证号
          '%$searchQuery%', // 姓名拼音带空格
          '%$queryNoSpace%', // 姓名拼音无空格
          '%$searchQuery%', // 姓名首字母
          '%$searchQuery%', // 地址拼音带空格
          '%$queryNoSpace%', // 地址拼音无空格
        ];
      }

      // 添加医生权限过滤
      if (!_isAdmin && _hasDoctorName) {
        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += 'doctor = ?';
        whereArgs.add(_doctorName);
      }

      final countResults = await executeQuery(
        'SELECT COUNT(*) as count FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
        whereArgs,
      );
      
      final row = countResults.first;
      final dynamic count = row['count'] ?? row[0];
      if (count is int) return count;
      if (count is BigInt) return count.toInt();
      return 0;
    } catch (e) {
      print('获取患者数量时出错: $e');
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
      List<Patient> patients = [];
      int totalCount = 0;

      // 处理搜索和排序
      String whereClause = '';
      List<dynamic> whereArgs = [];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        String queryNoSpace = searchQuery.replaceAll(' ', '');

        whereClause = '''
        name LIKE ? 
        OR phone LIKE ? 
        OR address LIKE ? 
        OR identification_number LIKE ? 
        OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?))
        OR (name_initials IS NOT NULL AND name_initials LIKE ?)
        OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
        ''';

        whereArgs = [
          '%$searchQuery%', // 姓名
          '%$searchQuery%', // 电话
          '%$searchQuery%', // 地址
          '%$searchQuery%', // 身份证号
          '%$searchQuery%', // 姓名拼音带空格
          '%$queryNoSpace%', // 姓名拼音无空格
          '%$searchQuery%', // 姓名首字母
          '%$searchQuery%', // 地址拼音带空格
          '%$queryNoSpace%', // 地址拼音无空格
        ];
      }

      // 添加日期过滤条件
      if (startDate != null && endDate != null) {
        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += '$dateFilterType BETWEEN ? AND ?';
        whereArgs.add(DateTimeFormatter.toDbString(startDate));
        whereArgs.add(DateTimeFormatter.toDbString(endDate));
      }

      // 添加医生权限过滤
      if (!_isAdmin && _hasDoctorName) {
        if (whereClause.isNotEmpty) {
          whereClause += ' AND ';
        }
        whereClause += 'doctor = ?';
        whereArgs.add(_doctorName);
      }

      // 获取总数
      final countResults = await executeQuery(
        'SELECT COUNT(*) as count FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
        whereArgs,
      );
      
      final countRow = countResults.first;
      final dynamic count = countRow['count'] ?? countRow[0];
      if (count is int) {
        totalCount = count;
      } else if (count is BigInt) {
        totalCount = count.toInt();
      }

      // 处理排序
      String orderBy = 'updated_at DESC'; // 默认排序

      if (sortField != null && sortField.isNotEmpty) {
        String mysqlSortField = sortField;
        if (sortField == 'medicalRecordNumber') {
          mysqlSortField = 'medical_record_number';
        } else if (sortField == 'firstVisitDate') {
          mysqlSortField = 'first_visit_date';
        }

        // 对病历号进行数值排序
        if (mysqlSortField == 'medical_record_number') {
          mysqlSortField = 'CAST(medical_record_number AS SIGNED)';
        }

        orderBy = '$mysqlSortField ${sortAscending ? 'ASC' : 'DESC'}';
      }

      // 执行分页查询
      final results = await executeQuery(
        'SELECT * FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''} ORDER BY $orderBy LIMIT ? OFFSET ?',
        [...whereArgs, pageSize, offset],
      );

      // 转换为Patient对象
      for (var row in results) {
        final map = convertRowToMap(row);
        patients.add(Patient.fromMap(map));
      }

      return {
        'patients': patients,
        'totalCount': totalCount,
        'totalPages': (totalCount / pageSize).ceil(),
        'currentPage': page,
      };
    } catch (e) {
      print('获取MySQL患者分页数据时出错: $e');
      rethrow;
    }
  }

  @override
  Future<List<Patient>> getPatientsByDoctor(String doctorName) async {
    try {
      final results = await executeQuery('SELECT * FROM patients WHERE doctor = ?', [doctorName]);

      List<Patient> patients = [];
      for (var row in results) {
        final map = convertRowToMap(row);
        patients.add(Patient.fromMap(map));
      }

      return patients;
    } catch (e) {
      print('根据医生获取患者时出错: $e');
      return [];
    }
  }

  @override
  Future<List<int>> searchPatientIds(String query) async {
    try {
      // 优先尝试包含拼音列的查询；失败则回退到基础查询（name/MRN）
      final commonArgs = <Object?>['%$query%', '%$query%', '%$query%', '%$query%'];
      final baseArgs = <Object?>['%$query%', '%$query%'];
      
      try {
        var where = '(name LIKE ? OR name_pinyin LIKE ? OR name_initials LIKE ? OR medical_record_number LIKE ?)';
        var args = [...commonArgs];
        if (!_isAdmin && _hasDoctorName) {
          where += ' AND doctor = ?';
          args.add(_doctorName);
        }
        final results = await executeQuery('SELECT id FROM patients WHERE ' + where, args);
        return results.map((r) => r['id'] as int).toList();
      } catch (e1) {
        print('包含拼音列的MySQL查询失败，回退到基础查询: $e1');
        try {
          var where = '(name LIKE ? OR medical_record_number LIKE ?)';
          var args = [...baseArgs];
          if (!_isAdmin && _hasDoctorName) {
            where += ' AND doctor = ?';
            args.add(_doctorName);
          }
          final results = await executeQuery('SELECT id FROM patients WHERE ' + where, args);
          return results.map((r) => r['id'] as int).toList();
        } catch (e2) {
          print('基础MySQL查询也失败: $e2');
          return [];
        }
      }
    } catch (e) {
      print('searchPatientIds MySQL 出错: $e');
      return [];
    }
  }

  @override
  Future<List<Patient>> getPatientsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    try {
      final placeholders = List.filled(ids.length, '?').join(',');
      String whereClause = 'id IN ($placeholders)';
      final whereArgs = <Object?>[...ids];
      
      if (!_isAdmin && _hasDoctorName) {
        whereClause += ' AND doctor = ?';
        whereArgs.add(_doctorName);
      }
      
      final results = await executeQuery('SELECT * FROM patients WHERE ' + whereClause, whereArgs);
      final list = <Patient>[];
      for (final row in results) {
        final map = convertRowToMap(row);
        list.add(Patient.fromMap(map));
      }
      return list;
    } catch (e) {
      print('getPatientsByIds MySQL 出错: $e');
      return [];
    }
  }

  @override
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber, [int? excludePatientId]) async {
    try {
      String whereClause = 'medical_record_number = ?';
      List<dynamic> whereArgs = [medicalRecordNumber];

      if (excludePatientId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excludePatientId);
      }

      final results = await executeQuery(
        'SELECT id FROM patients WHERE $whereClause LIMIT 1',
        whereArgs,
      );

      return results.isNotEmpty;
    } catch (e) {
      print('检查病历号存在性时出错: $e');
      return false;
    }
  }

  @override
  Future<bool> checkPatientNameExists(String name, [int? excludePatientId]) async {
    try {
      String whereClause = 'name = ?';
      List<dynamic> whereArgs = [name];

      if (excludePatientId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excludePatientId);
      }

      final results = await executeQuery(
        'SELECT id FROM patients WHERE $whereClause LIMIT 1',
        whereArgs,
      );

      return results.isNotEmpty;
    } catch (e) {
      print('检查患者姓名存在性时出错: $e');
      return false;
    }
  }

  @override
  Future<void> updateAllPatientsPinyin() async {
    // 这个方法需要在Provider层实现，因为需要访问PinyinUtil
    throw UnimplementedError('updateAllPatientsPinyin should be implemented in Provider layer');
  }

  // 患者材料相关方法实现
  @override
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material) async {
    try {
      final result = await executeQuery('''
        INSERT INTO patient_materials (patient_id, description, created_at, updated_at)
        VALUES (?, ?, ?, ?)
      ''', [
        material.patientId,
        material.description,
        material.createdAt != null ? DateTimeFormatter.toDbString(material.createdAt!) : null,
        material.updatedAt != null ? DateTimeFormatter.toDbString(material.updatedAt!) : null,
      ]);
      
      final id = result.insertId;
      return material.copyWith(id: id);
    } catch (e) {
      print('添加患者材料失败: $e');
      rethrow;
    }
  }

  @override
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    try {
      final results = await executeQuery('''
        SELECT * FROM patient_materials 
        WHERE patient_id = ? 
        ORDER BY created_at DESC
      ''', [patientId]);
      
      List<PatientMaterial> materials = [];
      for (var row in results) {
        final map = convertRowToMap(row);
        materials.add(PatientMaterial.fromMap(map));
      }
      return materials;
    } catch (e) {
      print('获取患者材料失败: $e');
      return [];
    }
  }

  @override
  Future<bool> updatePatientMaterial(PatientMaterial material) async {
    try {
      final result = await executeQuery('''
        UPDATE patient_materials 
        SET description = ?, updated_at = ?
        WHERE id = ?
      ''', [
        material.description,
        material.updatedAt != null ? DateTimeFormatter.toDbString(material.updatedAt!) : null,
        material.id,
      ]);
      
      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      print('更新患者材料失败: $e');
      return false;
    }
  }

  @override
  Future<bool> deletePatientMaterial(int id) async {
    try {
      // MySQL联表删除
      await executeQuery('START TRANSACTION');
      try {
        // 先删除关联的图片
        await executeQuery(
          'DELETE FROM material_images WHERE material_id = ?',
          [id],
        );
        
        // 再删除材料记录
        await executeQuery(
          'DELETE FROM patient_materials WHERE id = ?',
          [id],
        );
        
        await executeQuery('COMMIT');
        return true;
      } catch (e) {
        await executeQuery('ROLLBACK');
        rethrow;
      }
    } catch (e) {
      print('删除患者材料失败: $e');
      return false;
    }
  }

  // 患者材料图片相关方法实现
  @override
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    try {
      final results = await executeQuery('''
        SELECT * FROM material_images 
        WHERE material_id = ? 
        ORDER BY created_at DESC
      ''', [materialId]);
      
      List<MaterialImage> images = [];
      for (var row in results) {
        final map = convertRowToMap(row);
        images.add(MaterialImage.fromMap(map));
      }
      return images;
    } catch (e) {
      print('获取材料图片失败: $e');
      return [];
    }
  }

  @override
  Future<MaterialImage> addMaterialImage(MaterialImage image) async {
    try {
      final result = await executeQuery('''
        INSERT INTO material_images (material_id, original_name, image_data, thumbnail_data, image_type, file_size, thumbnail_size, has_thumbnail, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW())
      ''', [
        image.materialId,
        image.originalName,
        image.imageData,
        image.thumbnailData,
        image.imageType,
        image.fileSize,
        image.thumbnailSize,
        image.hasThumbnail ? 1 : 0,
      ]);
      
      return image.copyWith(id: result.insertId);
    } catch (e) {
      print('添加材料图片失败: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateMaterialImage(MaterialImage image) async {
    try {
      final result = await executeQuery('''
        UPDATE material_images 
        SET material_id = ?, original_name = ?, image_data = ?, thumbnail_data = ?, image_type = ?, file_size = ?, thumbnail_size = ?, has_thumbnail = ?
        WHERE id = ?
      ''', [
        image.materialId,
        image.originalName,
        image.imageData,
        image.thumbnailData,
        image.imageType,
        image.fileSize,
        image.thumbnailSize,
        image.hasThumbnail ? 1 : 0,
        image.id,
      ]);
      
      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      print('更新材料图片失败: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteMaterialImage(int imageId) async {
    try {
      final result = await executeQuery('DELETE FROM material_images WHERE id = ?', [imageId]);
      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      print('删除材料图片失败: $e');
      return false;
    }
  }
}



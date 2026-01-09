import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient_medical_record.dart';

import '../models/medical_record_template.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'base_mysql_data_source.dart';

/// 抽象病历数据源接口
abstract class MedicalRecordDataSource {
  // 病历主记录操作
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId);
  Future<PatientMedicalRecord?> getMedicalRecordById(int id);
  Future<int> createMedicalRecord(PatientMedicalRecord record);
  Future<bool> updateMedicalRecord(PatientMedicalRecord record);
  Future<bool> deleteMedicalRecord(int id);
  

  
  // 搜索和统计功能
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query, {int? patientId});
  Future<int> getMedicalRecordsCount(int patientId);
  
  // 基于医生的查询方法
  Future<List<PatientMedicalRecord>> getDoctorMedicalRecords(String doctorName, {int? patientId});
  Future<int> getDoctorMedicalRecordsCount(String doctorName, {int? patientId});
  
  // 分页查询
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
  });
  

  
  // 模板数据操作
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category);
  Future<MedicalRecordTemplate?> getTemplateById(int id);
  Future<int> createTemplate(MedicalRecordTemplate template);
  Future<bool> updateTemplate(MedicalRecordTemplate template);
  Future<bool> deleteTemplate(int id);
  
  // 初始化预设数据
  Future<bool> initializeDefaultTemplates();
  Future<bool> hasTemplateData();
  
  // 检查关联数据
  Future<bool> hasRelatedRecords(int templateId);
  
  // 模板数据搜索和过滤
  Future<List<MedicalRecordTemplate>> searchTemplates(String category, String query);
  Future<Map<String, List<String>>> getDiseaseOptions(String category);
}

/// SQLite病历数据源实现
class SqliteMedicalRecordDataSource implements MedicalRecordDataSource {
  final Database _database;
  final String? _doctorName;
  final bool _isAdmin;
  
  // 辅助方法：安全检查医生名称
  bool get _hasDoctorName => _doctorName != null && _doctorName!.isNotEmpty;

  SqliteMedicalRecordDataSource(this._database, {String? doctorName, bool isAdmin = false})
      : _doctorName = doctorName,
        _isAdmin = isAdmin;

  @override
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId) async {
    try {
      // 查看病历记录不需要权限过滤，所有医生都能查看所有病历
      final maps = await _database.query(
        'patient_medical_records',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'record_date DESC, created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return PatientMedicalRecord.fromMap(maps[i]);
      });
    } catch (e) {
      print('获取患者病历记录时出错: $e');
      return [];
    }
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecordById(int id) async {
    try {
      // 查看病历记录不需要权限过滤，所有医生都能查看所有病历
      final maps = await _database.query(
        'patient_medical_records',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return PatientMedicalRecord.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('根据ID获取病历记录时出错: $e');
      return null;
    }
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    try {
      // 验证必要字段
      if (record.patientId <= 0) {
        throw Exception('患者ID无效');
      }
      
      if (record.chiefComplaint.trim().isEmpty) {
        throw Exception('主诉不能为空');
      }
      
      if (record.doctorName.trim().isEmpty) {
        throw Exception('医生姓名不能为空');
      }
      
      final id = await _database.insert('patient_medical_records', record.toMap());
      
      if (id <= 0) {
        throw Exception('创建病历记录失败：数据库返回无效ID');
      }
      
      return id;
    } catch (e) {
      print('创建病历记录时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    if (record.id == null) {
      throw Exception('更新病历记录时必须提供ID');
    }

    try {
      // 验证必要字段
      if (record.patientId <= 0) {
        throw Exception('患者ID无效');
      }
      
      if (record.chiefComplaint.trim().isEmpty) {
        throw Exception('主诉不能为空');
      }
      
      if (record.doctorName.trim().isEmpty) {
        throw Exception('医生姓名不能为空');
      }
      
      String whereClause = 'id = ?';
      List<dynamic> whereArgs = [record.id];

      // 添加医生权限过滤（如果不是管理员且有医生名称）
      if (!_isAdmin && _hasDoctorName) {
        whereClause += ' AND created_by_doctor = ?';
        whereArgs.add(_doctorName);
      }

      final result = await _database.update(
        'patient_medical_records',
        record.toMap(),
        where: whereClause,
        whereArgs: whereArgs,
      );
      
      if (result == 0) {
        throw Exception('更新病历记录失败：未找到匹配的记录或权限不足');
      }
      
      return result > 0;
    } catch (e) {
      print('更新病历记录时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteMedicalRecord(int id) async {
    try {
      // 使用事务确保数据一致性
      await _database.transaction((txn) async {


        // 然后删除病历主记录
        String whereClause = 'id = ?';
        List<dynamic> whereArgs = [id];

        // 添加医生权限过滤（如果不是管理员且有医生名称）
        if (!_isAdmin && _hasDoctorName) {
          whereClause += ' AND created_by_doctor = ?';
          whereArgs.add(_doctorName);
        }

        await txn.delete(
          'patient_medical_records',
          where: whereClause,
          whereArgs: whereArgs,
        );
      });
      return true;
    } catch (e) {
      print('删除病历记录时出错: $e');
      return false;
    }
  }



  @override
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query, {int? patientId}) async {
    try {
      String whereClause = '''
        (record_number LIKE ? 
        OR chief_complaint LIKE ? 
        OR present_illness LIKE ? 
        OR diagnosis LIKE ? 
        OR doctor_name LIKE ?)
      ''';

      List<dynamic> whereArgs = [
        '%$query%', // 病历编号
        '%$query%', // 主诉
        '%$query%', // 现病史
        '%$query%', // 诊断
        '%$query%', // 医生姓名
      ];

      // 如果指定了患者ID，添加患者过滤
      if (patientId != null) {
        whereClause += ' AND patient_id = ?';
        whereArgs.add(patientId);
      }

      // 搜索病历记录不需要权限过滤，所有医生都能搜索所有病历

      final List<Map<String, dynamic>> results = await _database.rawQuery(
        'SELECT * FROM patient_medical_records WHERE $whereClause ORDER BY record_date DESC, created_at DESC',
        whereArgs,
      );

      return results.map((data) => PatientMedicalRecord.fromMap(data)).toList();
    } catch (e) {
      print('搜索病历记录时出错: $e');
      return [];
    }
  }

  @override
  Future<int> getMedicalRecordsCount(int patientId) async {
    try {
      // 统计病历记录不需要权限过滤，所有医生都能查看所有病历的统计信息
      final countResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?',
        [patientId],
      );
      return countResult.first['count'] as int;
    } catch (e) {
      print('获取病历记录数量时出错: $e');
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      List<PatientMedicalRecord> records = [];
      int totalCount = 0;

      // 构建查询条件
      String whereClause = 'patient_id = ?';
      List<dynamic> whereArgs = [patientId];

      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClause += ''' AND (
          record_number LIKE ? 
          OR chief_complaint LIKE ? 
          OR present_illness LIKE ? 
          OR diagnosis LIKE ? 
          OR doctor_name LIKE ?
        )''';
        whereArgs.addAll([
          '%$searchQuery%',
          '%$searchQuery%',
          '%$searchQuery%',
          '%$searchQuery%',
          '%$searchQuery%',
        ]);
      }

      // 分页查询病历记录不需要权限过滤，所有医生都能查看所有病历

      // 获取总数
      final countResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patient_medical_records WHERE $whereClause',
        whereArgs,
      );
      totalCount = countResult.first['count'] as int;

      // 处理排序
      String orderBy = 'record_date DESC, created_at DESC'; // 默认排序

      if (sortField != null && sortField.isNotEmpty) {
        orderBy = '$sortField ${sortAscending ? 'ASC' : 'DESC'}';
      }

      // 执行分页查询
      final List<Map<String, dynamic>> maps = await _database.rawQuery(
        'SELECT * FROM patient_medical_records WHERE $whereClause ORDER BY $orderBy LIMIT $pageSize OFFSET $offset',
        whereArgs,
      );

      // 转换为PatientMedicalRecord对象
      records = maps.map((map) => PatientMedicalRecord.fromMap(map)).toList();

      return {
        'records': records,
        'totalCount': totalCount,
        'totalPages': (totalCount / pageSize).ceil(),
        'currentPage': page,
      };
    } catch (e) {
      print('获取病历记录分页数据时出错: $e');
      rethrow;
    }
  }



  // ==================== 模板数据操作方法 ====================

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) async {
    try {
      final maps = await _database.query(
        'medical_record_templates',
        where: 'category = ? AND is_active = 1',
        whereArgs: [category],
        orderBy: 'sort_order ASC, name ASC',
      );

      final templates = List.generate(maps.length, (i) {
        return MedicalRecordTemplate.fromMap(maps[i]);
      });
      
      return templates;
    } catch (e) {
      print('SqliteMedicalRecordDataSource.getTemplatesByCategory: 获取模板数据时出错: $e');
      return [];
    }
  }

  @override
  Future<MedicalRecordTemplate?> getTemplateById(int id) async {
    try {
      final maps = await _database.query(
        'medical_record_templates',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return MedicalRecordTemplate.fromMap(maps.first);
      }
      return null;
    } catch (e) {
      print('根据ID获取模板数据时出错: $e');
      return null;
    }
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    try {
      // 验证必要字段
      if (template.category.trim().isEmpty) {
        throw Exception('模板类别不能为空');
      }
      
      if (template.name.trim().isEmpty) {
        throw Exception('模板名称不能为空');
      }
      
      // 检查是否已存在相同名称的模板
      final existing = await _database.query(
        'medical_record_templates',
        where: 'category = ? AND name = ? AND parent_name = ?',
        whereArgs: [template.category, template.name, template.parentName],
      );
      
      if (existing.isNotEmpty) {
        throw Exception('已存在相同名称的模板');
      }
      
      // 获取该类别下的最大sort_order值
      final maxSortOrderResult = await _database.rawQuery(
        'SELECT MAX(sort_order) as max_sort FROM medical_record_templates WHERE category = ?',
        [template.category],
      );
      
      int nextSortOrder = 1;
      if (maxSortOrderResult.isNotEmpty && maxSortOrderResult.first['max_sort'] != null) {
        nextSortOrder = (maxSortOrderResult.first['max_sort'] as int) + 1;
      }
      
      // 创建新模板，使用计算出的sort_order
      final templateWithSortOrder = template.copyWith(sortOrder: nextSortOrder);
      final id = await _database.insert('medical_record_templates', templateWithSortOrder.toMap());
      
      if (id <= 0) {
        throw Exception('创建模板失败：数据库返回无效ID');
      }
      
      print('SQLite创建模板成功，ID: $id, sort_order: $nextSortOrder');
      return id;
    } catch (e) {
      print('创建模板数据时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    if (template.id == null) {
      throw Exception('更新模板数据时必须提供ID');
    }

    try {
      final result = await _database.update(
        'medical_record_templates',
        template.toMap(),
        where: 'id = ?',
        whereArgs: [template.id],
      );
      return result > 0;
    } catch (e) {
      print('更新模板数据时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> deleteTemplate(int id) async {
    print('🔥🔥🔥 SqliteMedicalRecordDataSource.deleteTemplate: 开始删除模板ID: $id');
    print('🔥🔥🔥 数据库路径: ${_database.path}');
    
    try {
      // 先查询要删除的记录
      final beforeDelete = await _database.query(
        'medical_record_templates',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🔥🔥🔥 删除前记录: $beforeDelete');
      
      if (beforeDelete.isEmpty) {
        print('🔥🔥🔥 错误：要删除的记录不存在！ID: $id');
        throw Exception('要删除的模板不存在');
      }
      
      // 检查是否有关联的子类型
      final childTemplates = await _database.query(
        'medical_record_templates',
        where: 'parent_name = ?',
        whereArgs: [beforeDelete.first['name']],
      );
      
      // 使用事务确保数据一致性
      await _database.transaction((txn) async {
        // 如果是主类型，先删除所有子类型
        if (childTemplates.isNotEmpty) {
          print('🔥🔥🔥 删除 ${childTemplates.length} 个子类型');
          await txn.delete(
            'medical_record_templates',
            where: 'parent_name = ?',
            whereArgs: [beforeDelete.first['name']],
          );
        }
        
        // 删除主记录
        print('🔥🔥🔥 执行删除主记录操作...');
        final result = await txn.delete(
          'medical_record_templates',
          where: 'id = ?',
          whereArgs: [id],
        );
        print('🔥🔥🔥 删除操作完成，影响行数: $result');
        
        if (result == 0) {
          throw Exception('删除操作未影响任何记录');
        }
      });
      
      // 验证删除结果
      final afterDelete = await _database.query(
        'medical_record_templates',
        where: 'id = ?',
        whereArgs: [id],
      );
      print('🔥🔥🔥 删除后查询结果: $afterDelete');
      
      // 显示当前总数
      final totalCount = await _database.rawQuery('SELECT COUNT(*) as count FROM medical_record_templates');
      print('🔥🔥🔥 删除后总数: ${totalCount.first['count']}');
      
      if (afterDelete.isEmpty) {
        print('🔥🔥🔥 删除成功！');
        return true;
      } else {
        print('🔥🔥🔥 删除验证失败！');
        throw Exception('删除验证失败');
      }
    } catch (e) {
      print('🔥🔥🔥 删除模板数据时出错: $e');
      rethrow; // 重新抛出异常，让上层处理
    }
  }

  @override
  Future<bool> initializeDefaultTemplates() async {
    try {
      // 清空现有模板数据
      await _database.delete('medical_record_templates');
      print('SQLite已清空现有模板数据');

      // 获取所有默认模板数据
      final defaultTemplates = DefaultTemplateInitializer.getAllDefaultTemplates();

      // 批量插入模板数据
      await _database.transaction((txn) async {
        for (final template in defaultTemplates) {
          await txn.insert('medical_record_templates', template.toMap());
        }
      });

      print('SQLite默认模板初始化完成，共插入 ${defaultTemplates.length} 条记录');
      return true;
    } catch (e) {
      print('初始化默认模板数据时出错: $e');
      return false;
    }
  }

  @override
  Future<bool> hasTemplateData() async {
    try {
      // 先检查表是否存在
      final tableExists = await _database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='medical_record_templates'"
      );
      
      if (tableExists.isEmpty) {
        return false;
      }
      
      final countResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM medical_record_templates',
      );
      final count = countResult.first['count'] as int;
      
      return count > 0;
    } catch (e) {
      print('SqliteMedicalRecordDataSource.hasTemplateData: 检查模板数据时出错: $e');
      return false;
    }
  }

  @override
  Future<bool> hasRelatedRecords(int templateId) async {
    // 不再使用 medical_record_items 表，直接返回 false
    return false;
  }

  @override
  Future<List<MedicalRecordTemplate>> searchTemplates(String category, String query) async {
    try {
      String whereClause = 'category = ? AND is_active = 1';
      List<dynamic> whereArgs = [category];

      if (query.isNotEmpty) {
        whereClause += ' AND (name LIKE ? OR description LIKE ? OR parent_name LIKE ?)';
        whereArgs.addAll(['%$query%', '%$query%', '%$query%']);
      }

      final maps = await _database.query(
        'medical_record_templates',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'sort_order ASC, name ASC',
      );

      return List.generate(maps.length, (i) {
        return MedicalRecordTemplate.fromMap(maps[i]);
      });
    } catch (e) {
      print('搜索模板数据时出错: $e');
      return [];
    }
  }

  @override
  Future<Map<String, List<String>>> getDiseaseOptions(String category) async {
    try {
      final templates = await getTemplatesByCategory(category);
      final Map<String, List<String>> options = {};

      for (final template in templates) {
        if (template.isMainType) {
          // 主疾病类型
          if (!options.containsKey(template.name)) {
            options[template.name] = [];
          }
        } else {
          // 子类型
          final parentName = template.parentName!;
          if (!options.containsKey(parentName)) {
            options[parentName] = [];
          }
          options[parentName]!.add(template.name);
        }
      }

      return options;
    } catch (e) {
      print('获取疾病选项时出错: $e');
      return {};
    }
  }

  @override
  Future<List<PatientMedicalRecord>> getDoctorMedicalRecords(String doctorName, {int? patientId}) async {
    try {
      String whereClause = 'created_by_doctor = ?';
      List<dynamic> whereArgs = [doctorName];

      if (patientId != null) {
        whereClause += ' AND patient_id = ?';
        whereArgs.add(patientId);
      }

      final maps = await _database.query(
        'patient_medical_records',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'record_date DESC, created_at DESC',
      );

      return List.generate(maps.length, (i) {
        return PatientMedicalRecord.fromMap(maps[i]);
      });
    } catch (e) {
      print('获取医生病历记录时出错: $e');
      return [];
    }
  }

  @override
  Future<int> getDoctorMedicalRecordsCount(String doctorName, {int? patientId}) async {
    try {
      String whereClause = 'created_by_doctor = ?';
      List<dynamic> whereArgs = [doctorName];

      if (patientId != null) {
        whereClause += ' AND patient_id = ?';
        whereArgs.add(patientId);
      }

      final countResult = await _database.rawQuery(
        'SELECT COUNT(*) as count FROM patient_medical_records WHERE $whereClause',
        whereArgs,
      );
      return countResult.first['count'] as int;
    } catch (e) {
      print('获取医生病历记录数量时出错: $e');
      return 0;
    }
  }
}

// MySQL病历数据源实现
class MySqlMedicalRecordDataSource extends BaseMySqlDataSource implements MedicalRecordDataSource {
  final String? _doctorName;
  final bool _isAdmin;

  MySqlMedicalRecordDataSource(
    MySqlConnection connection, {
    String? doctorName,
    bool isAdmin = false,
  })  : _doctorName = doctorName,
        _isAdmin = isAdmin,
        super(
          connectionProvider: () async => connection,
        );

  MySqlMedicalRecordDataSource.withConnectionGetter(
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
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId) async {
    try {
      // 查看病历记录不需要权限过滤，所有医生都能查看所有病历
      String query = '''
        SELECT * FROM patient_medical_records 
        WHERE patient_id = ?
        ORDER BY record_date DESC, created_at DESC
      ''';

      final results = await executeQuery(query, [patientId]);
      
      return results.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = results.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return PatientMedicalRecord.fromMap(map);
      }).toList();
    } catch (e) {
      print('MySQL获取患者病历记录时出错: $e');
      rethrow;
    }
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecordById(int id) async {
    try {
      // 查看病历记录不需要权限过滤，所有医生都能查看所有病历
      String query = '''
        SELECT * FROM patient_medical_records 
        WHERE id = ?
      ''';

      final results = await executeQuery(query, [id]);
      
      if (results.isNotEmpty) {
        final row = results.first;
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = results.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return PatientMedicalRecord.fromMap(map);
      }
      return null;
    } catch (e) {
      print('MySQL根据ID获取病历记录时出错: $e');
      rethrow;
    }
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    try {
      final map = record.toMap();
      map.remove('id'); // 移除ID，让数据库自动生成

      final fields = map.keys.join(', ');
      final placeholders = List.filled(map.length, '?').join(', ');
      
      final result = await executeQuery(
        'INSERT INTO patient_medical_records ($fields) VALUES ($placeholders)',
        map.values.toList(),
      );
      
      return result.insertId ?? 0;
    } catch (e) {
      print('MySQL创建病历记录时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    try {
      final map = record.toMap();
      final id = map.remove('id');
      
      final setClause = map.keys.map((key) => '$key = ?').join(', ');
      final values = map.values.toList()..add(id);
      
      String query = 'UPDATE patient_medical_records SET $setClause WHERE id = ?';
      
      // 非管理员用户只能更新自己的病历记录
      if (!_isAdmin && _doctorName != null && _doctorName!.isNotEmpty) {
        query += ' AND created_by_doctor = ?';
        values.add(_doctorName);
      }
      
      final result = await executeQuery(query, values);
      return result.affectedRows! > 0;
    } catch (e) {
      print('MySQL更新病历记录时出错: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteMedicalRecord(int id) async {
    try {
      String query = 'DELETE FROM patient_medical_records WHERE id = ?';
      List<dynamic> params = [id];
      
      // 非管理员用户只能删除自己的病历记录
      if (!_isAdmin && _doctorName != null && _doctorName!.isNotEmpty) {
        query += ' AND created_by_doctor = ?';
        params.add(_doctorName);
      }
      
      final result = await executeQuery(query, params);
      return result.affectedRows! > 0;
    } catch (e) {
      print('MySQL删除病历记录时出错: $e');
      return false;
    }
  }

  @override
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query, {int? patientId}) async {
    try {
      String sql = '''
        SELECT * FROM patient_medical_records 
        WHERE (chief_complaint LIKE ? OR present_illness LIKE ? OR diagnosis LIKE ? OR notes LIKE ?)
      ''';
      
      List<dynamic> params = ['%$query%', '%$query%', '%$query%', '%$query%'];
      
      if (patientId != null) {
        sql += ' AND patient_id = ?';
        params.add(patientId);
      }
      
      // 搜索病历记录不需要权限过滤，所有医生都能搜索所有病历
      
      sql += ' ORDER BY record_date DESC, created_at DESC';

      final results = await executeQuery(sql, params);
      
      return results.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = results.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return PatientMedicalRecord.fromMap(map);
      }).toList();
    } catch (e) {
      print('MySQL搜索病历记录时出错: $e');
      return [];
    }
  }

  @override
  Future<int> getMedicalRecordsCount(int patientId) async {
    try {
      // 统计病历记录不需要权限过滤，所有医生都能查看所有病历的统计信息
      String query = 'SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?';
      
      final results = await executeQuery(query, [patientId]);
      return results.first[0] ?? 0;
    } catch (e) {
      print('MySQL获取病历记录数量时出错: $e');
      return 0;
    }
  }

  @override
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
  }) async {
    try {
      final offset = (page - 1) * pageSize;
      
      String whereClause = 'WHERE patient_id = ?';
      List<dynamic> params = [patientId];
      
      if (searchQuery != null && searchQuery.isNotEmpty) {
        whereClause += ' AND (chief_complaint LIKE ? OR present_illness LIKE ? OR diagnosis LIKE ?)';
        params.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
      }
      
      // 分页查询病历记录不需要权限过滤，所有医生都能查看所有病历
      
      // 获取总数
      final countResults = await executeQuery(
        'SELECT COUNT(*) as count FROM patient_medical_records $whereClause',
        params,
      );
      final totalCount = countResults.first[0] ?? 0;
      
      // 获取分页数据
      String orderClause = 'ORDER BY ';
      if (sortField != null && sortField.isNotEmpty) {
        orderClause += '$sortField ${sortAscending ? 'ASC' : 'DESC'}';
      } else {
        orderClause += 'record_date DESC, created_at DESC';
      }
      
      final dataResults = await executeQuery(
        'SELECT * FROM patient_medical_records $whereClause $orderClause LIMIT ? OFFSET ?',
        [...params, pageSize, offset],
      );
      
      final records = dataResults.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = dataResults.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return PatientMedicalRecord.fromMap(map);
      }).toList();

      return {
        'records': records,
        'totalCount': totalCount,
        'totalPages': (totalCount / pageSize).ceil(),
        'currentPage': page,
      };
    } catch (e) {
      print('MySQL获取病历记录分页数据时出错: $e');
      rethrow;
    }
  }



  // ==================== 模板数据操作方法 ====================

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) async {
    try {
      final results = await executeQuery(
        'SELECT * FROM medical_record_templates WHERE category = ? AND is_active = 1 ORDER BY sort_order ASC, name ASC',
        [category],
      );

      return results.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = results.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return MedicalRecordTemplate.fromMap(map);
      }).toList();
    } catch (e) {
      print('MySQL获取模板数据时出错: $e');
      return [];
    }
  }

  @override
  Future<MedicalRecordTemplate?> getTemplateById(int id) async {
    try {
      final results = await executeQuery(
        'SELECT * FROM medical_record_templates WHERE id = ?',
        [id],
      );

      if (results.isNotEmpty) {
        final row = results.first;
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = results.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return MedicalRecordTemplate.fromMap(map);
      }
      return null;
    } catch (e) {
      print('MySQL根据ID获取模板数据时出错: $e');
      return null;
    }
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    try {
      // 获取该类别下的最大sort_order值
      final maxSortOrderResult = await executeQuery(
        'SELECT MAX(sort_order) as max_sort FROM medical_record_templates WHERE category = ?',
        [template.category],
      );
      
      int nextSortOrder = 1;
      if (maxSortOrderResult.isNotEmpty && maxSortOrderResult.first[0] != null) {
        nextSortOrder = (maxSortOrderResult.first[0] as int) + 1;
      }
      
      // 创建新模板，使用计算出的sort_order
      final templateWithSortOrder = template.copyWith(sortOrder: nextSortOrder);
      final map = templateWithSortOrder.toMap();
      map.remove('id'); // 移除ID，让数据库自动生成

      final fields = map.keys.join(', ');
      final placeholders = List.filled(map.length, '?').join(', ');
      
      final result = await executeQuery(
        'INSERT INTO medical_record_templates ($fields) VALUES ($placeholders)',
        map.values.toList(),
      );
      
      final insertId = result.insertId ?? 0;
      print('MySQL创建模板成功，ID: $insertId, sort_order: $nextSortOrder');
      return insertId;
    } catch (e) {
      print('MySQL创建模板数据时出错: $e');
      rethrow;
    }
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    try {
      final map = template.toMap();
      final id = map.remove('id');
      
      final setClause = map.keys.map((key) => '$key = ?').join(', ');
      final values = map.values.toList()..add(id);
      
      final result = await executeQuery(
        'UPDATE medical_record_templates SET $setClause WHERE id = ?',
        values,
      );
      
      return result.affectedRows! > 0;
    } catch (e) {
      print('MySQL更新模板数据时出错: $e');
      return false;
    }
  }

  @override
  Future<bool> deleteTemplate(int id) async {
    try {
      // 先查询要删除的记录
      final templateResults = await executeQuery(
        'SELECT * FROM medical_record_templates WHERE id = ?',
        [id],
      );
      
      if (templateResults.isEmpty) {
        throw Exception('要删除的模板不存在');
      }
      
      final templateName = templateResults.first[2]; // name字段
      
      // 检查是否有关联的子类型
      final childResults = await executeQuery(
        'SELECT COUNT(*) as count FROM medical_record_templates WHERE parent_name = ?',
        [templateName],
      );
      
      final childCount = childResults.first[0] as int;
      
      // 如果是主类型且有子类型，先删除子类型
      if (childCount > 0) {
        await executeQuery(
          'DELETE FROM medical_record_templates WHERE parent_name = ?',
          [templateName],
        );
      }
      
      // 删除主记录
      final result = await executeQuery(
        'DELETE FROM medical_record_templates WHERE id = ?',
        [id],
      );
      
      if (result.affectedRows! == 0) {
        throw Exception('删除操作未影响任何记录');
      }
      
      return true;
    } catch (e) {
      print('MySQL删除模板数据时出错: $e');
      rethrow; // 重新抛出异常，让上层处理
    }
  }

  @override
  Future<bool> initializeDefaultTemplates() async {
    try {
      // 清空现有模板数据
      await executeQuery('DELETE FROM medical_record_templates');
      print('MySQL已清空现有模板数据');

      // 获取所有默认模板
      final templates = DefaultTemplateInitializer.getAllDefaultTemplates();
      
      // 批量插入
      for (final template in templates) {
        await createTemplate(template);
      }
      
      print('MySQL默认模板初始化完成，共插入 ${templates.length} 条记录');
      return true;
    } catch (e) {
      print('MySQL初始化默认模板时出错: $e');
      return false;
    }
  }

  @override
  Future<bool> hasTemplateData() async {
    try {
      final results = await executeQuery(
        'SELECT COUNT(*) as count FROM medical_record_templates',
      );
      return results.first[0] > 0;
    } catch (e) {
      print('MySQL检查模板数据时出错: $e');
      return false;
    }
  }

  @override
  Future<List<MedicalRecordTemplate>> searchTemplates(String category, String query) async {
    try {
      final results = await executeQuery(
        'SELECT * FROM medical_record_templates WHERE category = ? AND (name LIKE ? OR description LIKE ?) AND is_active = 1 ORDER BY sort_order ASC, name ASC',
        [category, '%$query%', '%$query%'],
      );

      return results.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = results.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return MedicalRecordTemplate.fromMap(map);
      }).toList();
    } catch (e) {
      print('MySQL搜索模板时出错: $e');
      return [];
    }
  }

  @override
  Future<Map<String, List<String>>> getDiseaseOptions(String category) async {
    try {
      final templates = await getTemplatesByCategory(category);
      final Map<String, List<String>> options = {};

      for (final template in templates) {
        if (template.isMainType) {
          // 主疾病类型
          if (!options.containsKey(template.name)) {
            options[template.name] = [];
          }
        } else {
          // 子类型
          final parentName = template.parentName!;
          if (!options.containsKey(parentName)) {
            options[parentName] = [];
          }
          options[parentName]!.add(template.name);
        }
      }

      return options;
    } catch (e) {
      print('MySQL获取疾病选项时出错: $e');
      return {};
    }
  }

  @override
  Future<bool> hasRelatedRecords(int templateId) async {
    // 不再使用 medical_record_items 表，直接返回 false
    return false;
  }

  @override
  Future<List<PatientMedicalRecord>> getDoctorMedicalRecords(String doctorName, {int? patientId}) async {
    try {
      String query = 'SELECT * FROM patient_medical_records WHERE created_by_doctor = ?';
      List<dynamic> params = [doctorName];

      if (patientId != null) {
        query += ' AND patient_id = ?';
        params.add(patientId);
      }

      query += ' ORDER BY record_date DESC, created_at DESC';

      final results = await executeQuery(query, params);
      
      return results.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < row.length; i++) {
          final field = results.fields[i];
          map[field.name ?? 'field_$i'] = row[i];
        }
        return PatientMedicalRecord.fromMap(map);
      }).toList();
    } catch (e) {
      print('MySQL获取医生病历记录时出错: $e');
      return [];
    }
  }

  @override
  Future<int> getDoctorMedicalRecordsCount(String doctorName, {int? patientId}) async {
    try {
      String query = 'SELECT COUNT(*) as count FROM patient_medical_records WHERE created_by_doctor = ?';
      List<dynamic> params = [doctorName];

      if (patientId != null) {
        query += ' AND patient_id = ?';
        params.add(patientId);
      }

      final results = await executeQuery(query, params);
      return results.first[0] ?? 0;
    } catch (e) {
      print('MySQL获取医生病历记录数量时出错: $e');
      return 0;
    }
  }
}

import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/patient_medical_record.dart';
import '../models/medical_record_item.dart';
import '../models/medical_record_template.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';

// 抽象病历数据源接口
abstract class MedicalRecordDataSource {
  // 患者病历相关方法
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId);
  Future<PatientMedicalRecord?> getMedicalRecord(int recordId);
  Future<int> createMedicalRecord(PatientMedicalRecord record);
  Future<bool> updateMedicalRecord(PatientMedicalRecord record);
  Future<bool> deleteMedicalRecord(int recordId);
  Future<bool> hasMedicalRecords(int patientId);
  
  // 病历项目相关方法
  Future<List<MedicalRecordItem>> getMedicalRecordItems(int recordId);
  Future<int> createMedicalRecordItem(MedicalRecordItem item);
  Future<bool> updateMedicalRecordItem(MedicalRecordItem item);
  Future<bool> deleteMedicalRecordItem(int itemId);
  
  // 病历模板相关方法
  Future<List<MedicalRecordTemplate>> getMedicalRecordTemplates();
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category);
  Future<int> createTemplate(MedicalRecordTemplate template);
  Future<bool> updateTemplate(MedicalRecordTemplate template);
  Future<bool> deleteTemplate(int templateId);
  
  // 复合查询方法
  Future<Map<String, dynamic>> getMedicalRecordWithItems(int recordId);
}

// SQLite病历数据源实现
class SqliteMedicalRecordDataSource implements MedicalRecordDataSource {
  final Database _database;

  SqliteMedicalRecordDataSource(this._database);

  // 提供database getter以保持向后兼容
  Database get database => _database;

  @override
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM patient_medical_records WHERE patient_id = ? ORDER BY record_date DESC, created_at DESC',
      [patientId]
    );
    return result.map((e) => PatientMedicalRecord.fromMap(e)).toList();
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecord(int recordId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM patient_medical_records WHERE id = ?', 
      [recordId]
    );
    if (result.isEmpty) return null;
    return PatientMedicalRecord.fromMap(result.first);
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    return await _database.insert('patient_medical_records', record.toMap());
  }

  @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    final count = await _database.update(
      'patient_medical_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteMedicalRecord(int recordId) async {
    // 先删除相关的病历项目
    await _database.delete(
      'medical_record_items',
      where: 'medical_record_id = ?',
      whereArgs: [recordId],
    );
    
    // 再删除病历记录
    final count = await _database.delete(
      'patient_medical_records',
      where: 'id = ?',
      whereArgs: [recordId],
    );
    return count > 0;
  }

  @override
  Future<bool> hasMedicalRecords(int patientId) async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?',
      [patientId]
    );
    final count = result.first['count'] as int;
    return count > 0;
  } 
 @override
  Future<List<MedicalRecordItem>> getMedicalRecordItems(int recordId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM medical_record_items WHERE medical_record_id = ? ORDER BY sort_order ASC, created_at ASC',
      [recordId]
    );
    return result.map((e) => MedicalRecordItem.fromMap(e)).toList();
  }

  @override
  Future<int> createMedicalRecordItem(MedicalRecordItem item) async {
    return await _database.insert('medical_record_items', item.toMap());
  }

  @override
  Future<bool> updateMedicalRecordItem(MedicalRecordItem item) async {
    final count = await _database.update(
      'medical_record_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteMedicalRecordItem(int itemId) async {
    final count = await _database.delete(
      'medical_record_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    return count > 0;
  }

  @override
  Future<List<MedicalRecordTemplate>> getMedicalRecordTemplates() async {
    final result = await _database.rawQuery(
      'SELECT * FROM medical_record_templates WHERE is_active = 1 ORDER BY category ASC, sort_order ASC, name ASC'
    );
    return result.map((e) => MedicalRecordTemplate.fromMap(e)).toList();
  }

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) async {
    final result = await _database.rawQuery(
      'SELECT * FROM medical_record_templates WHERE category = ? AND is_active = 1 ORDER BY sort_order ASC, name ASC',
      [category]
    );
    return result.map((e) => MedicalRecordTemplate.fromMap(e)).toList();
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    return await _database.insert('medical_record_templates', template.toMap());
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    final count = await _database.update(
      'medical_record_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteTemplate(int templateId) async {
    final count = await _database.delete(
      'medical_record_templates',
      where: 'id = ?',
      whereArgs: [templateId],
    );
    return count > 0;
  }

  @override
  Future<Map<String, dynamic>> getMedicalRecordWithItems(int recordId) async {
    final record = await getMedicalRecord(recordId);
    if (record == null) {
      throw Exception('病历记录不存在: $recordId');
    }
    
    final items = await getMedicalRecordItems(recordId);
    
    return {
      'record': record,
      'items': items,
    };
  }
}

// MySQL病历数据源实现（使用动态连接获取）
class MySqlMedicalRecordDataSource implements MedicalRecordDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlMedicalRecordDataSource.withConnectionGetter(this._getConnection);

  // 辅助方法：处理MySQL行数据转换
  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];
      
      // 处理日期字段 - 使用统一格式
      if (field == 'created_at' || field == 'updated_at' || field == 'record_date') {
        if (value is DateTime) {
          // 如果MySQL返回的是UTC时间，转换为本地时间
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        // 处理Blob字段，特别是文本字段
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
      } else if (value is Uint8List) {
        // 处理Uint8List类型
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
    }
    return map;
  }

  @override
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('''
      SELECT * FROM patient_medical_records 
      WHERE patient_id = ? 
      ORDER BY record_date DESC, created_at DESC
    ''', [patientId]);
    
    return results.map((row) => PatientMedicalRecord.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<PatientMedicalRecord?> getMedicalRecord(int recordId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('''
      SELECT * FROM patient_medical_records WHERE id = ?
    ''', [recordId]);
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    return PatientMedicalRecord.fromMap(_convertMySqlRow(row));
  }

  @override
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('''
      INSERT INTO patient_medical_records (
        patient_id, record_number, record_date, chief_complaint, present_illness,
        past_medical_history, past_dental_history, allergy_history, oral_examination,
        diagnosis, treatment_plan, notes, doctor_name, created_by_doctor,
        selected_dental_condition_date, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''', [
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
    ]);
    
    return result.insertId!;
  } 
 @override
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('''
      UPDATE patient_medical_records SET
        patient_id = ?, record_number = ?, record_date = ?, chief_complaint = ?,
        present_illness = ?, past_medical_history = ?, past_dental_history = ?,
        allergy_history = ?, oral_examination = ?, diagnosis = ?, treatment_plan = ?,
        notes = ?, doctor_name = ?, created_by_doctor = ?, selected_dental_condition_date = ?,
        updated_at = NOW()
      WHERE id = ?
    ''', [
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
    ]);
    
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deleteMedicalRecord(int recordId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    // MySQL的外键约束会自动删除相关的病历项目（ON DELETE CASCADE）
    final result = await connection.query(
      'DELETE FROM patient_medical_records WHERE id = ?', 
      [recordId]
    );
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> hasMedicalRecords(int patientId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query(
      'SELECT COUNT(*) as count FROM patient_medical_records WHERE patient_id = ?',
      [patientId]
    );
    final count = results.first['count'] as int;
    return count > 0;
  }

  @override
  Future<List<MedicalRecordItem>> getMedicalRecordItems(int recordId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('''
      SELECT * FROM medical_record_items 
      WHERE medical_record_id = ? 
      ORDER BY sort_order ASC, created_at ASC
    ''', [recordId]);
    
    return results.map((row) => MedicalRecordItem.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<int> createMedicalRecordItem(MedicalRecordItem item) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('''
      INSERT INTO medical_record_items (
        medical_record_id, item_type, item_name, item_value, item_unit,
        item_notes, sort_order, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''', [
      item.medicalRecordId,
      item.itemType,
      item.itemName,
      item.itemValue,
      item.itemUnit,
      item.itemNotes,
      item.sortOrder,
    ]);
    
    return result.insertId!;
  }

  @override
  Future<bool> updateMedicalRecordItem(MedicalRecordItem item) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('''
      UPDATE medical_record_items SET
        medical_record_id = ?, item_type = ?, item_name = ?, item_value = ?,
        item_unit = ?, item_notes = ?, sort_order = ?, updated_at = NOW()
      WHERE id = ?
    ''', [
      item.medicalRecordId,
      item.itemType,
      item.itemName,
      item.itemValue,
      item.itemUnit,
      item.itemNotes,
      item.sortOrder,
      item.id,
    ]);
    
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deleteMedicalRecordItem(int itemId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query(
      'DELETE FROM medical_record_items WHERE id = ?', 
      [itemId]
    );
    return result.affectedRows! > 0;
  }

  @override
  Future<List<MedicalRecordTemplate>> getMedicalRecordTemplates() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('''
      SELECT * FROM medical_record_templates 
      WHERE is_active = 1 
      ORDER BY category ASC, sort_order ASC, name ASC
    ''');
    
    return results.map((row) => MedicalRecordTemplate.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('''
      SELECT * FROM medical_record_templates 
      WHERE category = ? AND is_active = 1 
      ORDER BY sort_order ASC, name ASC
    ''', [category]);
    
    return results.map((row) => MedicalRecordTemplate.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('''
      INSERT INTO medical_record_templates (
        category, name, parent_name, description, is_active, sort_order,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''', [
      template.category,
      template.name,
      template.parentName,
      template.description,
      template.isActive ? 1 : 0,
      template.sortOrder,
    ]);
    
    return result.insertId!;
  }

  @override
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('''
      UPDATE medical_record_templates SET
        category = ?, name = ?, parent_name = ?, description = ?,
        is_active = ?, sort_order = ?, updated_at = NOW()
      WHERE id = ?
    ''', [
      template.category,
      template.name,
      template.parentName,
      template.description,
      template.isActive ? 1 : 0,
      template.sortOrder,
      template.id,
    ]);
    
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deleteTemplate(int templateId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query(
      'DELETE FROM medical_record_templates WHERE id = ?', 
      [templateId]
    );
    return result.affectedRows! > 0;
  }

  @override
  Future<Map<String, dynamic>> getMedicalRecordWithItems(int recordId) async {
    final record = await getMedicalRecord(recordId);
    if (record == null) {
      throw Exception('病历记录不存在: $recordId');
    }
    
    final items = await getMedicalRecordItems(recordId);
    
    return {
      'record': record,
      'items': items,
    };
  }
}
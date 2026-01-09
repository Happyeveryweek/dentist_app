import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/database_models.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/database_config.dart';
import '../utils/database_utils.dart';
import '../utils/database_operation_wrapper.dart';
import '../data_sources/patient_data_source.dart';
import '../utils/pinyin_util.dart'; // 导入拼音工具类
import '../utils/datetime_formatter.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql1/mysql1.dart';
import 'package:excel/excel.dart';
import 'dart:async'; // 添加Timer支持
import 'user_provider.dart'; // 导入UserProvider用于权限检查

// 患者管理提供者，专门处理患者相关的数据库操作
class PatientProvider extends ChangeNotifier {
  // 缓存数据
  List<Patient>? _cachedPatients;
  
  // 数据源具体实现
  SqlitePatientDataSource? _sqliteDataSource;
  MySqlPatientDataSource? _mysqlDataSource;
  
  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;
  
  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;
  
  // 数据库类型
  String _dataSourceType = 'sqlite'; // 默认使用sqlite
  
  // 初始化标志
  bool initialized = false;
  
  // UserProvider引用（用于权限检查）
  UserProvider? _userProvider;
  
  // 设置数据源类型
  void setDataSourceType(String dataSourceType) {
    _dataSourceType = dataSourceType;
    _safeNotifyListeners();
  }

  // 安全的notifyListeners方法
  void _safeNotifyListeners() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqlitePatientDataSource(database);
  }
  
  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlPatientDataSource.withConnectionGetter(() => _currentMysqlConnection);
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  PatientDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL患者数据源未初始化');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite患者数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  // 获取最新的MySQL连接（防止连接过期）
  MySqlConnection? get _currentMysqlConnection {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
      return null;
    }
    
    // 每次都从DatabaseProvider获取最新连接
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      return latestConnection;
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
      return null;
    }
  }

  // 统一的数据库初始化方法
  Future<void> initializeFromDatabase(dynamic dbProvider, {UserProvider? userProvider}) async {
    if (initialized) return;
    
    try {
      print('PatientProvider 开始初始化...');
      
      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;
      
      // 保存UserProvider引用
      _userProvider = userProvider;
      
      // 设置数据源类型
      setDataSourceType(dbProvider.dbType);
      
      if (dbProvider.dbType == 'sqlite') {
        final database = await dbProvider.sqliteDatabase;
        if (database != null) {
          setSqliteDataSource(database);
          print('✅ PatientProvider SQLite数据源设置成功');
          initialized = true;
        } else {
          throw Exception('SQLite数据库为null，无法创建数据源');
        }
      } else if (dbProvider.dbType == 'mysql') {
        final mysqlConnection = dbProvider.mysqlConnection;
        if (mysqlConnection != null) {
          setMySqlDataSource(mysqlConnection);
          print('✅ PatientProvider MySQL数据源设置成功');
          initialized = true;
        } else {
          throw Exception('MySQL连接为null，无法创建数据源');
        }
      }
      
      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);
      
      print('PatientProvider 初始化完成');
    } catch (e) {
      print('PatientProvider 初始化失败: $e');
      // 不抛出异常，让应用继续运行
      initialized = false;
    }
  }
  
  // 设置UserProvider引用
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }
  
  // 获取医生过滤条件
  String? _getDoctorFilter() {
    if (_userProvider?.currentUser == null) {
      return null;
    }
    
    return _userProvider!.buildDoctorFilter(_userProvider!.currentUser);
  }
  
  // 检查是否需要数据过滤
  bool _shouldFilterByDoctor() {
    if (_userProvider?.currentUser == null) {
      return false;
    }
    
    return _userProvider!.shouldFilterByDoctor(_userProvider!.currentUser);
  }

  // 获取数据源类型
  String get dataSourceType => _dataSourceType;



  // 强制刷新患者数据
  Future<void> forceRefreshPatients() async {
    _cachedPatients = null;
    _safeNotifyListeners();
  }



  // 导出患者表
  Future<String> exportPatientsTable(String destinationDir) async {
    try {
      // 检查数据库类型，只允许导出SQLite数据库
      if (_dataSourceType != 'sqlite') {
        throw Exception('目前只支持导出SQLite数据库患者表');
      }

      print('开始导出患者表数据');

      // 获取所有患者数据
      final patients = await getAllPatients();
      if (patients.isEmpty) {
        throw Exception('没有患者数据可导出');
      }

      // 使用数据库工具类导出患者表
      final exportPath = await DatabaseUtils.exportPatientsTable(
        '', // 需要数据库路径，这里需要从DatabaseProvider获取
        destinationDir,
      );

      if (exportPath.isEmpty) {
        throw Exception('导出过程中发生错误');
      }

      print('患者表已成功导出到: $exportPath');
      return exportPath;
    } catch (e) {
      print('导出患者表错误: $e');
      throw Exception('患者表导出失败: $e');
    }
  }

  // 使用SAF保存患者数据备份
  Future<String> savePatientBackupWithSaf(
    String jsonData,
    String fileName,
  ) async {
    try {
      // 请求权限
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        throw Exception('需要存储权限才能备份患者数据');
      }

      // 将JSON数据写入临时文件
      final directory = await getTemporaryDirectory();
      final tempFile = File('${directory.path}/$fileName');
      await tempFile.writeAsString(jsonData);

      // 使用SAF让用户选择保存位置
      const mimeType = 'application/json';

      final params = SaveFileDialogParams(
        sourceFilePath: tempFile.path,
        fileName: fileName,
        mimeTypesFilter: [mimeType],
      );

      final filePath = await FlutterFileDialog.saveFile(params: params);

      // 删除临时文件
      await tempFile.delete();

      if (filePath == null) {
        throw Exception('用户取消了备份操作');
      }

      return '患者数据已备份到: $filePath';
    } catch (e) {
      print('SAF备份患者数据错误: $e');
      throw Exception('备份患者数据失败：$e');
    }
  }
  
  // 获取当前活跃的数据源
  PatientDataSource? get _activeDataSource {
    switch (_dataSourceType) {
      case 'sqlite':
        return _sqliteDataSource;
      case 'mysql':
        return _mysqlDataSource;
      default:
        return null;
    }
  }

  // 获取所有患者（Android端不过滤查看权限）
  Future<List<Patient>> getAllPatients() async {
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getAllPatients', () async {
      try {
        if (_cachedPatients != null) {
          // Android端：返回所有缓存数据，不过滤
          return _cachedPatients!;
        }

        // 使用数据源模式（统一接口）
        final patients = await _currentDataSource.getAllPatients();

        
        _cachedPatients = patients; // 缓存数据
        return patients; // Android端：返回所有数据，不过滤
      } catch (e) {
        print('获取所有患者失败: $e');
        print('错误堆栈: ${StackTrace.current}');
        return [];
      }
    });
  }
  
  // Android端不需要数据查看过滤 - 所有用户都能查看所有数据
  // 权限控制只在编辑和删除操作时生效
  List<Patient> _applyDoctorFilter(List<Patient> patients) {
    final currentUser = _userProvider?.currentUser;

    
    // Android端：所有用户都能查看所有数据，权限控制只在编辑/删除时生效
    return patients;
  }

  // 获取患者总数（Android端不过滤查看权限）
  Future<int> getPatientCount() async {
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('getPatientCount', () async {
      try {
        // Android端：所有用户都能查看所有数据，直接返回数据库总数
        final count = await _currentDataSource.getPatientsCount();
        return count;
      } catch (e) {
        print('获取患者总数错误: $e');
        return 0;
      }
    });
  }

  // 获取最大病历号
  Future<int> getMaxMedicalRecordNumber() async {
    try {
              print('正在获取最大病历号...');
        if (_dataSourceType == 'sqlite') {
          final db = _sqliteDataSource?.database;
          if (db != null) {
            final result = await db.rawQuery(
              'SELECT MAX(medical_record_number) as max_id FROM patients',
            );
            final maxId = Sqflite.firstIntValue(result) ?? 0;
            print('SQLite数据库中的最大病历号: $maxId');
            return maxId;
          }
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn != null) {
          final results = await conn.query(
            'SELECT MAX(medical_record_number) as max_id FROM patients',
          );
          if (results.isNotEmpty) {
            final maxId = results.first.fields['max_id'] as int? ?? 0;
            print('MySQL数据库中的最大病历号: $maxId');
            return maxId;
          }
        }
      }

      // 如果无法获取数据，默认返回0，新病历号为1
      print('无法获取最大病历号，使用默认值0');
      return 0;
    } catch (e) {
      print('获取最大病历号错误: $e');
      return 0;
    }
  }

  // 分页获取患者（带权限过滤）
  Future<List<Patient>> getPatientsPage(
    int page,
    int pageSize, {
    String? sortField,
    bool? ascending,
  }) async {
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getPatientsPage', () async {
      try {
        // 使用数据源模式（统一接口），传递排序参数
        final patients = await _currentDataSource.getPaginatedPatients(
          page, 
          pageSize, 
          sortField: sortField, 
          ascending: ascending,
        );
        
        // Android端：不过滤查看权限，返回所有数据
        return patients;
      } catch (e) {
        print('分页获取患者错误: $e');
        return [];
      }
    });
  }

  // 搜索患者（带权限过滤）
  Future<List<Patient>> searchPatients(String query) async {
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('searchPatients', () async {
      try {
        // 使用数据源模式（统一接口）
        final patients = await _currentDataSource.searchPatients(query);
        
        // Android端：不过滤查看权限，返回所有数据

        
        return patients;
      } catch (e) {
        print('搜索患者错误: $e');
        return [];
      }
    });
  }



  // 获取最后一位患者
  Future<Patient?> getLastPatient() async {
    try {
      if (_dataSourceType == 'sqlite') {
        final db = _sqliteDataSource?.database;
        if (db != null) {
          final List<Map<String, dynamic>> maps = await db.query(
            'patients',
            orderBy: 'medical_record_number DESC',
            limit: 1,
          );
          if (maps.isNotEmpty) {
            return Patient.fromMap(maps.first);
          }
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn != null) {
          final results = await conn.query(
            'SELECT * FROM patients ORDER BY medical_record_number DESC LIMIT 1',
          );
          if (results.isNotEmpty) {
            return Patient.fromMap(results.first.fields);
          }
        }
      }
      return null;
    } catch (e) {
      print('获取最后一位患者错误: $e');
      return null;
    }
  }

  // 根据ID获取患者
  Future<Patient?> getPatientById(int id) async {
    try {
      // 使用数据源模式（统一接口）
      return await _currentDataSource.getPatientById(id);
    } catch (e) {
      print('根据ID获取患者失败: $e');
      return null;
    }
  }

  // 添加患者
  Future<int> addPatient(Patient patient) async {
    if (_dbWrapper == null) return -1;
    
    return await _dbWrapper!.wrapOperation('addPatient', () async {
      try {
        // 使用数据源模式（统一接口）
        final result = await _currentDataSource.createPatient(patient);

        // 清除缓存
        _cachedPatients = null;
        _safeNotifyListeners();
        return result;
      } catch (e) {
        print('添加患者失败: $e');
        rethrow;
      }
    });
  }

  // 更新患者
  Future<bool> updatePatient(Patient patient) async {
    if (_dbWrapper == null) return false;
    
    return await _dbWrapper!.wrapOperation('updatePatient', () async {
      try {
        print('开始更新患者数据: ${patient.toMap()}');

        // 生成更新时间
        patient.updatedAt = DateTime.now();

        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updatePatient(patient);

        // 清除缓存
        if (success) {
          _cachedPatients = null;
          _safeNotifyListeners();
        }

        return success;
      } catch (e) {
        print('更新患者错误: $e');
        return false;
      }
    });
  }

  // 删除患者
  Future<int> deletePatient(int id) async {
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('deletePatient', () async {
      try {
        print('开始删除患者ID $id 及其关联预约');

        // 1. 先获取该患者的所有预约
        final appointments = await _getAppointmentsByPatientId(id);
        print('找到患者关联的预约记录: ${appointments.length}条');

        // 2. 删除该患者的所有预约
        int appointmentsDeleted = 0;
        for (var appointment in appointments) {
          if (appointment.id != null) {
            try {
              final result = await _deleteAppointment(appointment.id!);
              appointmentsDeleted += result;
              print('已删除预约 ID: ${appointment.id}');
            } catch (e) {
              print('删除患者相关预约时出错 ID: ${appointment.id}, 错误: $e');
              // 继续尝试删除其他预约，不中断流程
            }
          }
        }
        print('成功删除关联预约: $appointmentsDeleted条');

        // 3. 删除患者
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deletePatient(id);
        final result = success ? 1 : 0;

        // 4. 清除缓存
        _cachedPatients = null;
        _safeNotifyListeners();

        return result;
      } catch (e) {
        print('删除患者错误: $e');
        rethrow;
      }
    });
  }

  // 私有方法：获取患者的所有预约（用于删除患者时清理关联预约）
  Future<List<Appointment>> _getAppointmentsByPatientId(int patientId) async {
    try {
      List<Map<String, dynamic>> maps;

      if (_dataSourceType == 'sqlite') {
        final db = _sqliteDataSource?.database;
        final result = await db?.query(
          'appointments',
          where: 'patient_id = ?',
          whereArgs: [patientId],
        );
        maps = result?.cast<Map<String, dynamic>>() ?? [];
      } else if (_dataSourceType == 'mysql') {
        // 使用MySQL查询
        final conn = _currentMysqlConnection;
        if (conn != null) {
          final results = await conn.query(
            'SELECT * FROM appointments WHERE patient_id = ?',
            [patientId],
          );
          // 转换MySQL结果为Map格式
          maps = results.map((row) {
            final map = <String, dynamic>{};
            for (var field in row.fields.keys) {
              map[field] = row[field];
            }
            return map;
          }).toList();
        } else {
          maps = [];
        }
      } else {
        throw Exception('不支持的数据库类型: $_dataSourceType');
      }

      return List.generate(maps.length, (i) {
        return Appointment.fromMap(maps[i]);
      });
    } catch (e) {
      print('获取患者预约错误: $e');
      return [];
    }
  }

  // 私有方法：删除预约（用于删除患者时清理关联预约）
  Future<int> _deleteAppointment(int id) async {
    int result = 0;

    try {
      if (_dataSourceType == 'sqlite') {
        // SQLite方式删除预约
        final db = _sqliteDataSource?.database;
        result = await db?.delete(
          'appointments',
          where: 'id = ?',
          whereArgs: [id],
        ) ?? 0;
        print('SQLite删除预约成功，ID: $id, 影响行数: $result');
      } else if (_dataSourceType == 'mysql') {
        // MySQL方式删除预约
        print('使用MySQL删除预约，ID: $id...');

        // 确保MySQL连接可用
        final conn = _currentMysqlConnection;
        if (conn != null) {
          // 执行MySQL删除
          var response = await conn.query(
            'DELETE FROM appointments WHERE id = ?',
            [id],
          );

          try {
            result = response.affectedRows ?? 0;
          } catch (e) {
            print('获取MySQL影响行数错误: $e，假设成功删除1行');
            result = 1; // 假设成功删除了一行
          }

          print('MySQL删除预约成功，ID: $id, 影响行数: $result');
        }
      } else {
        throw Exception('不支持的数据库类型: $_dataSourceType');
      }

      return result;
    } catch (e) {
      print('删除预约错误: $e');
      rethrow;
    }
  }

  // ==================== MySQL 操作逻辑 ====================

  /// 从MySQL获取所有患者
  Future<List<Patient>> _getAllPatientsFromMySQL() async {
    final conn = _currentMysqlConnection;
    if (conn == null) {
      print('MySQL连接未初始化');
      return [];
    }

    try {
      final results = await conn.query('SELECT * FROM patients ORDER BY name');
      
             return results.map((row) => Patient.fromMap({
         'id': row['id'],
         'name': row['name']?.toString() ?? '',
         'phone': row['phone']?.toString(),
         'gender': row['gender']?.toString(),
         'address': row['address']?.toString(),
         'first_visit_date': row['first_visit_date']?.toString(),
         'created_at': row['created_at']?.toString(),
         'updated_at': row['updated_at']?.toString(),
         'medical_record_number': row['medical_record_number']?.toString(),
         'doctor': row['doctor']?.toString(),
         'age': row['age'] ?? 0,
         'identification_number': row['identification_number']?.toString(),
         'dental_condition': row['dental_condition']?.toString(),
         'treatment_items': row['treatment_items']?.toString(),
         'total_cost': row['total_cost'] ?? 0.0,
         'name_pinyin': row['name_pinyin']?.toString(),
         'name_initials': row['name_initials']?.toString(),
         'address_pinyin': row['address_pinyin']?.toString(),
       })).toList();
    } catch (e) {
      print('MySQL查询所有患者失败: $e');
      return [];
    }
  }

  /// 从MySQL根据ID获取患者
  Future<Patient?> _getPatientByIdFromMySQL(int id) async {
    final conn = _currentMysqlConnection;
    if (conn == null) {
      print('MySQL连接未初始化');
      return null;
    }

    try {
      final results = await conn.query(
        'SELECT * FROM patients WHERE id = ?',
        [id],
      );
      
      if (results.isNotEmpty) {
        final row = results.first;
                 return Patient.fromMap({
           'id': row['id'],
           'name': row['name']?.toString() ?? '',
           'phone': row['phone']?.toString(),
           'gender': row['gender']?.toString(),
           'address': row['address']?.toString(),
           'first_visit_date': row['first_visit_date']?.toString(),
           'created_at': row['created_at']?.toString(),
           'updated_at': row['updated_at']?.toString(),
           'medical_record_number': row['medical_record_number']?.toString(),
           'doctor': row['doctor']?.toString(),
           'age': row['age'] ?? 0,
           'identification_number': row['identification_number']?.toString(),
           'dental_condition': row['dental_condition']?.toString(),
           'treatment_items': row['treatment_items']?.toString(),
           'total_cost': row['total_cost'] ?? 0.0,
           'name_pinyin': row['name_pinyin']?.toString(),
           'name_initials': row['name_initials']?.toString(),
           'address_pinyin': row['address_pinyin']?.toString(),
         });
      }
      
      print('MySQL中未找到ID为 $id 的患者');
      return null;
    } catch (e) {
      print('MySQL查询患者失败: $e');
      return null;
    }
  }

  /// 向MySQL添加患者
  Future<int> _addPatientToMySQL(Patient patient) async {
    final conn = _currentMysqlConnection;
    if (conn == null) {
      throw Exception('MySQL连接未初始化');
    }

    try {
      // 自动生成拼音
      patient.namePinyin = PinyinUtil.toPinyin(patient.name);
      patient.nameInitials = PinyinUtil.getInitials(patient.name);
      if (patient.address != null && patient.address!.isNotEmpty) {
        patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
      }

      // 确保更新时间是最新的
      patient.updatedAt = DateTime.now();

      final result = await conn.query(
        'INSERT INTO patients (name, phone, gender, address, first_visit_date, created_at, updated_at, medical_record_number, doctor, age, identification_number, dental_condition, treatment_items, total_cost, name_pinyin, name_initials, address_pinyin) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          patient.name,
          patient.phone,
          patient.gender,
          patient.address,
          patient.firstVisitDate != null ? DateTimeFormatter.toDbString(patient.firstVisitDate!) : null,
          patient.createdAt != null ? DateTimeFormatter.toDbString(patient.createdAt!) : null,
          patient.updatedAt != null ? DateTimeFormatter.toDbString(patient.updatedAt!) : null,
          patient.medicalRecordNumber,
          patient.doctor,
          patient.age,
          patient.identificationNumber,
          patient.dentalCondition,
          patient.treatmentItems,
          patient.totalCost,
          patient.namePinyin,
          patient.nameInitials,
          patient.addressPinyin,
        ],
      );
      
      // 获取插入的ID
      final idResult = await conn.query('SELECT LAST_INSERT_ID() as id');
      if (idResult.isNotEmpty) {
        return idResult.first['id'] as int;
      }
      return 0;
    } catch (e) {
      print('MySQL添加患者失败: $e');
      rethrow;
    }
  }

  /// 在MySQL中更新患者
  Future<int> _updatePatientInMySQL(Patient patient) async {
    final conn = _currentMysqlConnection;
    if (conn == null) {
      throw Exception('MySQL连接未初始化');
    }

    try {
      // 自动更新拼音
      patient.namePinyin = PinyinUtil.toPinyin(patient.name);
      patient.nameInitials = PinyinUtil.getInitials(patient.name);
      if (patient.address != null && patient.address!.isNotEmpty) {
        patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
      }

      patient.updatedAt = DateTime.now();

      final result = await conn.query(
        'UPDATE patients SET name = ?, phone = ?, gender = ?, address = ?, first_visit_date = ?, updated_at = ?, medical_record_number = ?, doctor = ?, age = ?, identification_number = ?, dental_condition = ?, treatment_items = ?, total_cost = ?, name_pinyin = ?, name_initials = ?, address_pinyin = ? WHERE id = ?',
        [
          patient.name,
          patient.phone,
          patient.gender,
          patient.address,
          patient.firstVisitDate != null ? DateTimeFormatter.toDbString(patient.firstVisitDate!) : null,
          patient.updatedAt != null ? DateTimeFormatter.toDbString(patient.updatedAt!) : null,
          patient.medicalRecordNumber,
          patient.doctor,
          patient.age,
          patient.identificationNumber,
          patient.dentalCondition,
          patient.treatmentItems,
          patient.totalCost,
          patient.namePinyin,
          patient.nameInitials,
          patient.addressPinyin,
          patient.id,
        ],
      );
      return result.affectedRows ?? 0;
    } catch (e) {
      print('MySQL更新患者失败: $e');
      rethrow;
    }
  }

  /// 从MySQL删除患者
  Future<int> _deletePatientFromMySQL(int id) async {
    final conn = _currentMysqlConnection;
    if (conn == null) {
      throw Exception('MySQL连接未初始化');
    }

    try {
      // 先删除相关的财务项目记录
      await conn.query(
        'DELETE fi FROM financial_items fi INNER JOIN financial_records fr ON fi.financial_record_id = fr.id WHERE fr.patient_id = ?',
        [id]
      );
      
      // 然后删除财务记录
      await conn.query(
        'DELETE FROM financial_records WHERE patient_id = ?',
        [id]
      );
      
      // 最后删除患者
      final result = await conn.query(
        'DELETE FROM patients WHERE id = ?',
        [id],
      );
      return result.affectedRows ?? 0;
    } catch (e) {
      print('MySQL删除患者失败: $e');
      rethrow;
    }
  }

  // MySQL分页获取患者
  Future<List<Patient>> _getPatientsPageFromMySQL(
    int page,
    int pageSize,
    String? sortField,
    bool? ascending,
  ) async {
    try {
      final conn = _currentMysqlConnection;
      if (conn == null) {
        throw Exception('MySQL连接未初始化');
      }

      final offset = (page - 1) * pageSize;

      // 根据排序字段和方向构建排序SQL
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

      // 执行查询
      final results = await conn.query(
        'SELECT * FROM patients ORDER BY $orderBy LIMIT ? OFFSET ?',
        [pageSize, offset],
      );

      List<Patient> patients = [];
      for (var row in results) {
        try {
          // 构建Map
          final map = <String, dynamic>{};

          for (var field in row.fields.keys) {
            map[field] = row[field];
          }

          // 特殊处理性别 - 转换为中文格式
          if (map.containsKey('gender')) {
            String genderValue = map['gender'].toString().toLowerCase();
            if (genderValue == 'male') {
              map['gender'] = '男';
            } else if (genderValue == 'female') {
              map['gender'] = '女';
            }
          }

          // 创建患者对象
          final patient = Patient.fromMap(map);
          patients.add(patient);
        } catch (e) {
          print('转换MySQL行数据错误: $e');
        }
      }

      return patients;
    } catch (e) {
      print('MySQL分页查询错误: $e');
      rethrow;
    }
  }

  // MySQL搜索患者
  Future<List<Patient>> _searchPatientsFromMySQL(String query) async {
    if (query.isEmpty) {
      return await _getAllPatientsFromMySQL();
    }

    try {
      final conn = _currentMysqlConnection;
      if (conn == null) {
        throw Exception('MySQL连接未初始化');
      }

      // 构建模糊搜索参数
      final searchPattern = '%$query%';

      // 为拼音搜索创建无空格版本
      final noSpaceQuery = query.replaceAll(' ', '');
      final noSpacePattern = '%$noSpaceQuery%';

      // 执行查询 - 添加对拼音字段的支持并优化查询，支持无空格拼音
      final results = await conn.query(
        '''
        SELECT * FROM patients 
        WHERE name LIKE ? 
        OR phone LIKE ? 
        OR (address IS NOT NULL AND address LIKE ?) 
        OR (identification_number IS NOT NULL AND identification_number LIKE ?) 
        OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?)) 
        OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
        OR (name_initials IS NOT NULL AND name_initials LIKE ?)
        OR (medical_record_number IS NOT NULL AND CAST(medical_record_number AS CHAR) LIKE ?)
        
        -- 添加精确匹配的结果（会排在前面）
        UNION ALL
        
        SELECT * FROM patients 
        WHERE name = ? 
        OR phone = ? 
        OR address = ? 
        OR identification_number = ? 
        OR name_pinyin = ? 
        OR address_pinyin = ?
        OR name_initials = ?
        OR CAST(medical_record_number AS CHAR) = ?
        
        ORDER BY
        CASE 
          WHEN name = ? THEN 0
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
          query, // name
          query, // phone
          query, // address
          query, // identification_number
          query, // name_pinyin
          query, // address_pinyin
          query, // name_initials
          query, // medical_record_number
          // 排序优先级参数
          query, // name (优先级0)
          query, // phone (优先级1)
          query, // medical_record_number (优先级2)
        ],
      );

      // 转换并去重患者数据
      List<Patient> patients = _convertMySQLResultsToPatients(results);

      // 添加结果去重逻辑
      Map<int?, Patient> uniquePatients = <int?, Patient>{};
      for (var patient in patients) {
        if (patient.id != null) {
          uniquePatients[patient.id] = patient;
        }
      }

      return uniquePatients.values.toList();
    } catch (e) {
      print('MySQL搜索患者错误: $e');
      return [];
    }
  }

  // 辅助方法：转换MySQL结果为患者列表
  List<Patient> _convertMySQLResultsToPatients(Results results) {
    final patients = <Patient>[];

    for (var row in results) {
      try {
        // 构建Map
        final map = <String, dynamic>{};

        for (var field in row.fields.keys) {
          map[field] = row[field];
        }

        // 特殊处理性别 - 转换为中文格式
        if (map.containsKey('gender')) {
          String genderValue = map['gender'].toString().toLowerCase();
          if (genderValue == 'male') {
            map['gender'] = '男';
          } else if (genderValue == 'female') {
            map['gender'] = '女';
          }
        }

        // 创建患者对象
        final patient = Patient.fromMap(map);
        patients.add(patient);
      } catch (e) {
        print('转换MySQL行数据错误: $e');
      }
    }

    return patients;
  }

  // ==================== SQLite 操作逻辑 ====================

  /// 从SQLite获取所有患者
  Future<List<Patient>> _getAllPatientsFromSQLite() async {
    final db = _sqliteDataSource?.database;
    if (db == null) {
      print('无法获取SQLite数据库实例');
      print('数据库提供者状态: 数据库已初始化');
      return [];
    }
    
    print('成功获取数据库实例: ${db.path}');
    print('开始查询患者表...');
    
    // 检查患者表是否存在
    try {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='patients'");
      print('患者表检查结果: $tables');
      if (tables.isEmpty) {
        print('患者表不存在！');
        return [];
      }
    } catch (e) {
      print('检查患者表存在性时出错: $e');
    }
    
    final List<Map<String, dynamic>> maps = await db.query('patients', orderBy: 'name');
    print('查询到 ${maps.length} 个患者记录');
    
    // 打印前几个患者的调试信息
    if (maps.isNotEmpty) {
      print('第一个患者数据: ${maps.first}');
    }
    
    final patients = List.generate(maps.length, (i) {
      return Patient.fromMap(maps[i]);
    });
    
    print('成功解析 ${patients.length} 个患者对象');
    return patients;
  }

  /// 从SQLite根据ID获取患者
  Future<Patient?> _getPatientByIdFromSQLite(int id) async {
    final db = _sqliteDataSource?.database;
    if (db == null) {
      print('SQLite数据库未初始化');
      return null;
    }

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        'patients',
        where: 'id = ?',
        whereArgs: [id],
      );
      
      if (maps.isNotEmpty) {
        return Patient.fromMap(maps.first);
      }
      
      print('SQLite中未找到ID为 $id 的患者');
      return null;
    } catch (e) {
      print('SQLite查询患者失败: $e');
      return null;
    }
  }

  /// 向SQLite添加患者
  Future<int> _addPatientToSQLite(Patient patient) async {
    final db = _sqliteDataSource?.database;
    if (db == null) {
      throw Exception('SQLite数据库未初始化');
    }

    try {
      // 自动生成拼音
      patient.namePinyin = PinyinUtil.toPinyin(patient.name);
      patient.nameInitials = PinyinUtil.getInitials(patient.name);
      if (patient.address != null && patient.address!.isNotEmpty) {
        patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
      }

      // 确保更新时间是最新的
      patient.updatedAt = DateTime.now();

      print('添加患者 - 名称拼音: ${patient.namePinyin}');
      print('添加患者 - 姓名首字母: ${patient.nameInitials}');
      print('添加患者 - 地址拼音: ${patient.addressPinyin}');

      return await db.insert('patients', patient.toMap());
    } catch (e) {
      print('SQLite添加患者失败: $e');
      rethrow;
    }
  }

  /// 在SQLite中更新患者
  Future<int> _updatePatientInSQLite(Patient patient) async {
    final db = _sqliteDataSource?.database;
    if (db == null) {
      throw Exception('SQLite数据库未初始化');
    }

    try {
      // 自动更新拼音
      patient.namePinyin = PinyinUtil.toPinyin(patient.name);
      patient.nameInitials = PinyinUtil.getInitials(patient.name);
      if (patient.address != null && patient.address!.isNotEmpty) {
        patient.addressPinyin = PinyinUtil.toPinyin(patient.address!);
      }

      // 更新修改时间
      patient.updatedAt = DateTime.now();

      print('更新患者 - 名称拼音: ${patient.namePinyin}');
      print('更新患者 - 姓名首字母: ${patient.nameInitials}');
      print('更新患者 - 地址拼音: ${patient.addressPinyin}');

      final rowsAffected = await db.update(
        'patients',
        patient.toMap(),
        where: 'id = ?',
        whereArgs: [patient.id],
      );
      print('SQLite更新患者结果: 影响了 $rowsAffected 行');
      return rowsAffected;
    } catch (e) {
      print('SQLite更新患者失败: $e');
      rethrow;
    }
  }

  /// 从SQLite删除患者
  Future<int> _deletePatientFromSQLite(int id) async {
    final db = _sqliteDataSource?.database;
    if (db == null) {
      throw Exception('SQLite数据库未初始化');
    }

    try {
      // 先删除相关的财务项目记录
      await db.delete(
        'financial_items',
        where: 'financial_record_id IN (SELECT id FROM financial_records WHERE patient_id = ?)',
        whereArgs: [id],
      );
      
      // 然后删除财务记录
      await db.delete(
        'financial_records',
        where: 'patient_id = ?',
        whereArgs: [id],
      );
      
      // 最后删除患者
      return await db.delete(
        'patients',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('SQLite删除患者失败: $e');
      rethrow;
    }
  }

  // SQLite分页获取患者
  Future<List<Patient>> _getPatientsPageFromSQLite(
    int page,
    int pageSize,
    String? sortField,
    bool? ascending,
  ) async {
    try {
      final db = _sqliteDataSource?.database;
      if (db == null) {
        throw Exception('SQLite数据库未初始化');
      }

      final offset = (page - 1) * pageSize;

      String orderBy = 'updated_at DESC';

      // 基于排序字段和排序方向设置orderBy
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

      final maps = await db.query(
        'patients',
        limit: pageSize,
        offset: offset,
        orderBy: orderBy,
      );

      List<Patient> patients = [];
      for (var map in maps) {
        try {
          Patient patient = Patient.fromMap(map);
          patients.add(patient);
        } catch (e) {
          print('转换患者对象错误: $e, 数据: $map');
        }
      }

      return patients;
    } catch (e) {
      print('SQLite分页查询错误: $e');
      return [];
    }
  }

  // SQLite搜索患者
  Future<List<Patient>> _searchPatientsFromSQLite(String query) async {
    if (query.isEmpty) {
      return await _getAllPatientsFromSQLite();
    }

    try {
      final db = _sqliteDataSource?.database;
      if (db == null) {
        throw Exception('SQLite数据库未初始化');
      }

      final lowercaseQuery = query.toLowerCase();

      // 为拼音搜索创建另一个不带空格的查询条件
      final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');

      // 构建搜索SQL - 增加对拼音搜索的支持，包括无空格的情况和首字母搜索
      final where = '''
        name LIKE ? OR 
        phone LIKE ? OR
        address LIKE ? OR
        identification_number LIKE ? OR
        (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR name_pinyin LIKE ? OR replace(name_pinyin, ' ', '') LIKE ?)) OR
        (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR address_pinyin LIKE ? OR replace(address_pinyin, ' ', '') LIKE ?)) OR
        (name_initials IS NOT NULL AND name_initials LIKE ?) OR
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

      final maps = await db.query('patients', where: where, whereArgs: whereArgs);

      List<Patient> patients = [];
      for (var map in maps) {
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
    } catch (e) {
      print('SQLite搜索患者错误: $e');
      return [];
    }
  }

  // 将牙齿状况JSON转换为易读文本
  String convertDentalJsonToText(Map<String, dynamic> jsonData) {
    StringBuffer buffer = StringBuffer();

    // 处理日期
    if (jsonData.containsKey('date-0')) {
      buffer.writeln('检查日期: ${jsonData['date-0']}');
    }

    // 处理图表1
    buffer.writeln('\n图表1');
    if (jsonData.containsKey('chart1-top-left-0')) {
      buffer.writeln('左上: ${jsonData['chart1-top-left-0']}');
    }
    if (jsonData.containsKey('chart1-top-right-0')) {
      buffer.writeln('右上: ${jsonData['chart1-top-right-0']}');
    }
    if (jsonData.containsKey('chart1-bottom-left-0')) {
      buffer.writeln('左下: ${jsonData['chart1-bottom-left-0']}');
    }
    if (jsonData.containsKey('chart1-bottom-right-0')) {
      buffer.writeln('右下: ${jsonData['chart1-bottom-right-0']}');
    }

    // 处理图表2
    buffer.writeln('\n图表2');
    if (jsonData.containsKey('chart2-top-left-0')) {
      buffer.writeln('左上: ${jsonData['chart2-top-left-0']}');
    }
    if (jsonData.containsKey('chart2-top-right-0')) {
      buffer.writeln('右上: ${jsonData['chart2-top-right-0']}');
    }
    if (jsonData.containsKey('chart2-bottom-left-0')) {
      buffer.writeln('左下: ${jsonData['chart2-bottom-left-0']}');
    }
    if (jsonData.containsKey('chart2-bottom-right-0')) {
      buffer.writeln('右下: ${jsonData['chart2-bottom-right-0']}');
    }

    return buffer.toString();
  }

  // 格式化牙齿状况信息，使其更易读
  String formatDentalCondition(String dentalCondition) {
    if (dentalCondition.isEmpty) return '';

    try {
      // 分行处理
      List<String> lines = dentalCondition.split('\n');
      List<String> formattedLines = [];

      // 日期行处理
      for (int i = 0; i < lines.length; i++) {
        String line = lines[i].trim();

        // 提取日期
        if (line.startsWith('检查日期:')) {
          String date = line.substring(5).trim();
          formattedLines.add('检查日期: $date');
          continue;
        }

        // 处理图表行
        if (line.startsWith('图表')) {
          String chartName = line.substring(0, line.length - 1); // 去掉末尾冒号
          formattedLines.add('\n$chartName');

          // 收集该图表下的所有数据
          List<String> chartData = [];
          int j = i + 1;
          while (j < lines.length &&
              lines[j].trim().isNotEmpty &&
              !lines[j].trim().startsWith('图表')) {
            String dataLine = lines[j].trim();

            // 格式化每个位置的数据
            if (dataLine.startsWith('左上:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('左上: $value');
            } else if (dataLine.startsWith('右上:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('右上: $value');
            } else if (dataLine.startsWith('左下:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('左下: $value');
            } else if (dataLine.startsWith('右下:')) {
              String value = dataLine.substring(3).trim();
              chartData.add('右下: $value');
            } else {
              chartData.add(dataLine);
            }
            j++;
          }

          // 将图表数据添加到格式化行中
          formattedLines.addAll(chartData);
          i = j - 1; // 更新循环索引
        } else if (line.isNotEmpty) {
          // 其他内容直接添加
          formattedLines.add(line);
        }
      }

      // 合并所有行
      return formattedLines.join('\n');
    } catch (e) {
      print('格式化牙齿状况失败: $e');
      return dentalCondition; // 如果格式化失败，返回原始字符串
    }
  }
}



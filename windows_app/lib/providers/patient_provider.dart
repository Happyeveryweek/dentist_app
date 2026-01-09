import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import '../models/patient.dart';
import '../utils/datetime_formatter.dart';
import '../utils/datetime_formatter.dart';
import '../models/appointment.dart';

import '../models/user.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/material.dart' as material_models;
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../utils/mysql_sync_connection_helper.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../providers/settings_provider.dart';
import '../utils/pinyin_util.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import '../data_sources/patient_data_source.dart';
import 'user_provider.dart';

/// 患者管理提供者
/// 负责处理所有与患者相关的数据库操作
class PatientProvider extends ChangeNotifier {
  // 数据源实例
  SqlitePatientDataSource? _sqliteDataSource;
  MySqlPatientDataSource? _mysqlDataSource;
  
  // 用户权限提供者引用
  UserProvider? _userProvider;
  
  // 缓存机制
  List<Patient>? _cachedPatients;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20);
  
  // 连接状态
  bool _isConnected = true;
  String? _lastError;
  
  // 数据库提供者引用
  dynamic _databaseProvider;
  
  // 数据库实例（保留向后兼容）
  Database? _database;
  MySqlConnection? _mysqlConnection;
  
  // 数据源类型（保留向后兼容）
  String _dataSourceType = 'sqlite';
  
  // 有效数据源类型（考虑模块化配置）
  String? _effectiveDataSourceType;
  
  // 当前用户信息
  User? _currentUser;
  
  // 刷新标志
  bool _patientsNeedRefresh = false;
  
  // Getters
  bool get initialized => _currentDataSource != null || _database != null || _mysqlConnection != null;
  bool get patientsNeedRefresh => _patientsNeedRefresh;
  String get dataSourceType => _effectiveDataSourceType ?? _dataSourceType;
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  
  // 获取当前数据源
  PatientDataSource? get _currentDataSource {
    if (_effectiveDataSourceType == 'mysql') {
      return _mysqlDataSource;
    } else if (_effectiveDataSourceType == 'sqlite') {
      return _sqliteDataSource;
    }
    return null;
  }
  
  // MySQL动态连接获取
  MySqlConnection? get _currentMysqlConnection {
    if (_effectiveDataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }
    
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        return latestConnection;
      }
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
    }
    
    return _mysqlConnection;
  }
  
  /// 获取用于同步的MySQL连接
  /// 
  /// 说明：
  /// - 此连接专门用于SQLite→MySQL数据同步
  /// - 无论当前模块使用什么数据源，都能获取到MySQL连接
  /// - 自动从DatabaseProvider获取最新连接，确保连接有效
  /// 
  /// 使用场景：
  /// - 当模块配置为SQLite时，需要同步数据到MySQL
  /// - 不能使用_currentMysqlConnection（它在SQLite模式下不会获取连接）
  MySqlConnection? get _syncMysqlConnection {
    return MySqlSyncConnectionHelper.getSyncConnection(
      databaseProvider: _databaseProvider,
      cachedConnection: _mysqlConnection,
      onConnectionUpdate: (newConnection) {
        _mysqlConnection = newConnection;
      },
    );
  }
  
  // 构造函数
  PatientProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
    User? currentUser,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
    _currentUser = currentUser;
  }

  // 智能初始化（支持模块化配置）
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    UserProvider? userProvider,
  }) async {
    try {
      _databaseProvider = dbProvider;
      _userProvider = userProvider;
      
      // 确定要使用的数据源类型
      String dbType = 'sqlite';
      
      // 如果是模块化模式且有模块配置，优先使用模块配置
      if (dataSourceMode == 'modular' && 
          moduleDataSources != null && 
          moduleDataSources.containsKey('patients')) {
        dbType = moduleDataSources['patients']!;
        print('PatientProvider使用模块化配置: patients -> $dbType');
      } else {
        // 否则使用全局配置
        dbType = dbProvider.dataSourceType ?? 'sqlite';
        print('PatientProvider使用全局配置: $dbType');
      }
      
      _effectiveDataSourceType = dbType;
      
      // 获取当前用户信息（优先从UserProvider获取，其次从_currentUser）
      final currentUser = _userProvider?.currentUser ?? _currentUser;
      final doctorName = currentUser?.doctor;
      final isAdmin = currentUser?.role == 'admin';
      
      // 一次性初始化正确的数据源（不再基于用户权限过滤数据）
      if (dbType == 'sqlite') {
        final database = dbProvider.database;
        if (database != null) {
          _sqliteDataSource = SqlitePatientDataSource(
            database,
            doctorName: null, // 不传递医生名称，让所有用户都能看到所有数据
            isAdmin: true,    // 设置为管理员权限，让数据源不过滤数据
          );
          _database = database; // 保持向后兼容
          _isConnected = true;
          _clearError();
          print('PatientProvider: SQLite数据源初始化完成，权限过滤: 禁用（UI层控制）');
        } else {
          _setError('SQLite数据库连接不可用');
        }
      } else if (dbType == 'mysql') {
        final mysqlConn = dbProvider.mysqlConnection;
        if (mysqlConn != null) {
          _mysqlDataSource = MySqlPatientDataSource.withConnectionGetter(
            () async => mysqlConn,
            doctorName: null, // 不传递医生名称，让所有用户都能看到所有数据
            isAdmin: true,    // 设置为管理员权限，让数据源不过滤数据
            reconnectCallback: () async {
              if (dbProvider != null) {
                try {
                  await dbProvider.initializeMySQL();
                  print('✅ PatientProvider: MySQL重连成功');
                } catch (e) {
                  print('❌ PatientProvider: MySQL重连失败: $e');
                }
              }
            },
          );
          _mysqlConnection = dbProvider.mysqlConnection; // 保持向后兼容
          
          // 测试MySQL连接
          final testResult = await _testMySqlConnection();
          if (testResult) {
            _isConnected = true;
            _clearError();
                      } else {
            _setError('MySQL连接测试失败');
            print('❌ PatientProvider MySQL连接测试失败，但数据源已初始化');
          }
        } else {
          _setError('MySQL连接不可用');
          print('❌ PatientProvider: MySQL连接不可用，跳过数据源初始化');
        }
      }
      
      // 清除缓存，强制重新加载
      clearCache();
      
    } catch (e) {
      print('PatientProvider初始化失败: $e');
      _setError('初始化失败: $e');
    }
  }
  
  // 缓存管理
  bool _isCacheValid() {
    return _cachedPatients != null && 
           _lastCacheTime != null && 
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  void _updateCache(List<Patient> patients) {
    _cachedPatients = patients;
    _lastCacheTime = DateTime.now();
  }
  
  void clearCache() {
    _cachedPatients = null;
    _lastCacheTime = null;
    print('PatientProvider: 缓存已清除');
  }
  
  // 错误处理
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
    print('PatientProvider错误: $error');
  }
  
  void _clearError() {
    _lastError = null;
    _isConnected = true;
  }
  
  // MySQL连接测试
  Future<bool> _testMySqlConnection() async {
    if (_currentMysqlConnection == null) return false;
    
    try {
      final conn = _currentMysqlConnection;
      if (conn == null) return false;
      
      await conn.query('SELECT 1').timeout(
        const Duration(seconds: 10),
      );
      _isConnected = true;
      _clearError();
      return true;
    } catch (e) {
      _setError('MySQL连接测试失败: $e');
      return false;
    }
  }

  // 根据ID列表批量获取患者（按“患者管理”实际数据源：可SQLite或MySQL）
  Future<List<Patient>> getPatientsByIds(
    List<int> ids, {
    bool enforceDoctorFilter = true,
    String? effectiveDataSourceType, // 可显式指定数据源；为空时沿用内部 _dataSourceType
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    if (ids.isEmpty) return [];

    // 权限
    User? currentUser = _currentUser;
    bool isAdmin = currentUser?.role == 'admin';
    String? doctorName = currentUser?.doctor;

    final ds = effectiveDataSourceType ?? _dataSourceType;

    if (ds == 'sqlite') {
      final placeholders = List.filled(ids.length, '?').join(',');
      String whereClause = 'id IN ($placeholders)';
      final whereArgs = <Object?>[...ids];
      if (enforceDoctorFilter && !isAdmin && doctorName != null && doctorName.isNotEmpty) {
        whereClause += ' AND doctor = ?';
        whereArgs.add(doctorName);
      }
      try {
        final maps = await _database!.query('patients', where: whereClause, whereArgs: whereArgs);
        return List.generate(maps.length, (i) => Patient.fromMap(maps[i]));
      } catch (e) {
        print('getPatientsByIds 出错: $e');
        return [];
      }
    } else if (ds == 'mysql') {
      try {
        final conn = _mysqlConnection;
        if (conn == null) return [];
        final placeholders = List.filled(ids.length, '?').join(',');
        String whereClause = 'id IN ($placeholders)';
        final whereArgs = <Object?>[...ids];
        if (enforceDoctorFilter && !isAdmin && doctorName != null && doctorName.isNotEmpty) {
          whereClause += ' AND doctor = ?';
          whereArgs.add(doctorName);
        }
        final results = await conn.query('SELECT * FROM patients WHERE ' + whereClause, whereArgs);
        final list = <Patient>[];
        for (final row in results) {
          final map = <String, dynamic>{};
          for (final k in row.fields.keys) { map[k] = row[k]; }
          // 处理可能的日期字符串
          if (map['first_visit_date'] is String) {
            try { map['first_visit_date'] = DateTimeFormatter.fromDbString(map['first_visit_date']); } catch (_) {}
          }
          list.add(Patient.fromMap(map));
        }
        return list;
      } catch (e) {
        print('getPatientsByIds MySQL 出错: $e');
        return [];
      }
    }
    return [];
  }

  // 按关键字搜索患者ID（姓名/拼音/首字母/病历号），数据源随“患者管理”配置
  Future<List<int>> searchPatientIds(String query, {String? effectiveDataSourceType}) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    if (query.trim().isEmpty) return [];

    // 权限
    User? currentUser = _currentUser;
    bool isAdmin = currentUser?.role == 'admin';
    String? doctorName = currentUser?.doctor;

    final ds = effectiveDataSourceType ?? _dataSourceType;

    if (ds == 'sqlite') {
      final conditions = <String>[];
      final args = <Object?>[];
      conditions.add('(name LIKE ? OR name_pinyin LIKE ? OR name_initials LIKE ? OR medical_record_number LIKE ?)');
      args.addAll(['%$query%', '%$query%', '%$query%', '%$query%']);
      if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
        conditions.add('doctor = ?');
        args.add(doctorName);
      }
      final where = conditions.join(' AND ');
      try {
        final maps = await _database!.query('patients', columns: ['id'], where: where, whereArgs: args);
        return maps.map((m) => m['id'] as int).toList();
      } catch (e) {
        print('searchPatientIds 出错: $e');
        return [];
      }
    } else if (ds == 'mysql') {
      final conn = _mysqlConnection;
      if (conn == null) return [];
      // 优先尝试包含拼音列的查询；失败则回退到基础查询（name/MRN）
      final commonArgs = <Object?>['%$query%', '%$query%', '%$query%', '%$query%'];
      final baseArgs = <Object?>['%$query%', '%$query%'];
      try {
        var where = '(name LIKE ? OR name_pinyin LIKE ? OR name_initials LIKE ? OR medical_record_number LIKE ?)';
        var args = [...commonArgs];
        if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
          where += ' AND doctor = ?';
          args.add(doctorName);
        }
        final results = await conn.query('SELECT id FROM patients WHERE ' + where, args);
        return results.map((r) => r['id'] as int).toList();
      } catch (e1) {
        print('包含拼音列的MySQL查询失败，回退到基础查询: $e1');
        try {
          var where = '(name LIKE ? OR medical_record_number LIKE ?)';
          var args = [...baseArgs];
          if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
            where += ' AND doctor = ?';
            args.add(doctorName);
          }
          final results = await conn.query('SELECT id FROM patients WHERE ' + where, args);
          return results.map((r) => r['id'] as int).toList();
        } catch (e2) {
          print('基础MySQL查询也失败: $e2');
          return [];
        }
      }
    }
    return [];
  }
  
  // 设置数据库连接（向后兼容）
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
  }) {
    print('PatientProvider: setDatabaseConnection被调用，但已升级为数据源架构');
    // 这个方法保留用于向后兼容，但实际初始化应该使用initializeFromDatabase
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) {
      _currentUser = currentUser;
      // 如果已经有数据源，需要重新初始化以应用新的用户信息
      if (_sqliteDataSource != null || _mysqlDataSource != null) {
        _reinitializeDataSourcesWithUser();
      }
    }
  }
  
  // 重新初始化数据源以应用新的用户信息
  void _reinitializeDataSourcesWithUser() {
    // 优先从UserProvider获取用户信息
    final currentUser = _userProvider?.currentUser ?? _currentUser;
    final doctorName = currentUser?.doctor;
    final isAdmin = currentUser?.role == 'admin';
    
    if (_effectiveDataSourceType == 'sqlite' && _database != null) {
      _sqliteDataSource = SqlitePatientDataSource(
        _database!,
        doctorName: doctorName,
        isAdmin: isAdmin,
      );
      print('PatientProvider: SQLite数据源权限更新，权限过滤: ${!isAdmin ? "启用($doctorName)" : "禁用(管理员)"}');
    } else if (_effectiveDataSourceType == 'mysql' && _mysqlConnection != null) {
      _mysqlDataSource = MySqlPatientDataSource.withConnectionGetter(
        () async {
          final conn = await _currentMysqlConnection;
          return conn;
        },
        doctorName: doctorName,
        isAdmin: isAdmin,
        reconnectCallback: () async {
          if (_databaseProvider != null) {
            try {
              await _databaseProvider.initializeMySQL();
              print('✅ PatientProvider: MySQL重连成功');
            } catch (e) {
              print('❌ PatientProvider: MySQL重连失败: $e');
            }
          }
        },
      );
      print('PatientProvider: MySQL数据源权限更新，权限过滤: ${!isAdmin ? "启用($doctorName)" : "禁用(管理员)"}');
    }
  }
  
  // 标记刷新
  void markPatientsNeedRefresh() {
    _patientsNeedRefresh = true;
    notifyListeners();
  }
  
  // 重置刷新标志
  void resetPatientsRefreshFlag() {
    _patientsNeedRefresh = false;
  }

  // 获取当前用户
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }
    
    // 如果没有当前用户信息，尝试从DatabaseProvider获取
    // 这里需要确保PatientProvider能够访问到DatabaseProvider中的用户信息
    // 由于Provider的依赖关系，我们需要通过其他方式获取用户信息
    
    return _currentUser;
  }

  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
    // 如果已经有数据源，需要重新初始化以应用新的用户信息
    if (_sqliteDataSource != null || _mysqlDataSource != null) {
      _reinitializeDataSourcesWithUser();
      // 清除缓存，强制重新加载数据
      clearCache();
    }
  }
  
  // 设置用户权限提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    // 重新初始化数据源以应用权限
    if (_sqliteDataSource != null || _mysqlDataSource != null) {
      _reinitializeDataSourcesWithUser();
      // 清除缓存，强制重新加载数据
      clearCache();
    }
  }

  // =================== 患者相关方法 ===================

  // 获取所有患者
  Future<List<Patient>> getAllPatients() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

      // 如果有数据源，优先使用数据源
    if (_currentDataSource != null) {
      try {
        print('PatientProvider: 使用数据源获取患者数据，数据源类型: $_effectiveDataSourceType');
        
        // 检查缓存
        if (_isCacheValid()) {
          print('PatientProvider: 使用缓存数据');
          return _cachedPatients!;
        }

        // 从数据源获取数据
        print('PatientProvider: 开始从数据源获取患者数据...');
        final dataSource = _currentDataSource;
        if (dataSource == null) {
          throw Exception('数据源未初始化: _effectiveDataSourceType=$_effectiveDataSourceType, _sqliteDataSource=${_sqliteDataSource != null}, _mysqlDataSource=${_mysqlDataSource != null}');
        }
        final patients = await dataSource.getAllPatients();
                // 更新缓存
        _updateCache(patients);
        
        // 标记已刷新
        _patientsNeedRefresh = false;
        
        return patients;
      } catch (e) {
        print('获取所有患者时出错: $e');
        _setError('获取患者失败: $e');
        
        // 优雅降级：如果有缓存数据，返回缓存
        if (_cachedPatients != null) {
          print('PatientProvider: 连接失败，返回缓存数据');
          return _cachedPatients!;
        }
        
        // 如果数据源失败，抛出异常
        rethrow;
      }
    }

    // 如果没有数据源，抛出异常
    throw Exception('数据源未初始化，无法获取患者数据');
  }

  // 根据医生姓名获取患者
  Future<List<Patient>> getPatientsByDoctor(String doctorName) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 标记已刷新
    _patientsNeedRefresh = false;

    if (_dataSourceType == 'sqlite') {
      try {
        final maps = await _database!.query(
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
    } else {
      // MySQL数据获取
      try {
        // 移除打印语句，减少日志输出

        final conn = _currentMysqlConnection;
        if (conn == null) {
          throw Exception('MySQL连接不可用');
        }
        final results = await conn.query('SELECT * FROM patients WHERE doctor = ?', [doctorName]);

        List<Patient> patients = [];
        for (var row in results) {
          final Map<String, dynamic> map = {};
          for (var field in row.fields.keys) {
            var value = row[field];
            // 处理Blob类型，将其转换为字符串
            if (value is Blob) {
              try {
                final blobString = String.fromCharCodes(value.toBytes());
                map[field] = blobString;
              } catch (e) {
                print('Blob转换失败: $e');
                map[field] = '';
              }
            } else if (value is Uint8List) {
              // 处理Uint8List类型（某些MySQL驱动可能返回这种类型）
              try {
                final stringValue = String.fromCharCodes(value);
                // 移除打印语句，减少日志输出
                map[field] = stringValue;
              } catch (e) {
                print('Uint8List转换失败: $e');
                map[field] = '';
              }
            } else {
              map[field] = value;
            }
          }

          // 确保first_visit_date字段是DateTime类型
          if (map['first_visit_date'] != null &&
              map['first_visit_date'] is String) {
            try {
              map['first_visit_date'] = DateTimeFormatter.fromDbString(map['first_visit_date']);
            } catch (e) {
              print('解析first_visit_date失败: $e, 使用当前日期');
              map['first_visit_date'] = DateTime.now();
            }
          }

          patients.add(Patient.fromMap(map));
        }

        // 移除打印语句，减少日志输出
        return patients;
      } catch (e) {
        print('根据医生获取患者时出错: $e');
        return [];
      }
    }
  }

  // 根据ID获取患者
  Future<Patient?> getPatient(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 如果有数据源，优先使用数据源
    if (_currentDataSource != null) {
      try {
                final dataSource = _currentDataSource;
        if (dataSource == null) {
          throw Exception('数据源未初始化，无法获取患者');
        }
        final patient = await dataSource.getPatientById(id);
        
                return patient;
      } catch (e) {
        print('数据源获取患者失败: $e');
        _setError('获取患者失败: $e');
        return null;
      }
    }

    // 如果没有数据源，抛出异常
    throw Exception('数据源未初始化，无法获取患者');
  }

  // 将Android应用的患者数据转换为Windows应用期望的格式
  Map<String, dynamic> _convertAndroidPatientToMap(
      Map<String, dynamic> androidMap) {
    // 移除打印语句，减少日志输出

    // 创建一个新的Map以保存转换后的数据
    final Map<String, dynamic> windowsMap = {
      'id': androidMap['id'],
      'name': androidMap['name'] ?? '',
      'age': androidMap['age'] ?? 0,
      'gender': androidMap['gender'] ?? '',
      'phone': androidMap['phoneNumber'] ?? '', // Android中可能是phoneNumber
      'medical_record_number': androidMap['medicalRecordNumber'], // 字段名转换
      'address': androidMap['address'],
      'identification_number': androidMap['identificationNumber'], // 字段名转换
      'doctor': androidMap['doctor'],
      'dental_condition': androidMap['dentalCondition'], // 字段名转换
      'treatment_items': androidMap['treatmentItems'], // 字段名转换
      'total_cost': androidMap['totalCost']?.toDouble() ?? 0.0, // 字段名转换
    };

    // 处理日期字段
    if (androidMap['registrationDate'] != null) {
      windowsMap['first_visit_date'] =
          androidMap['registrationDate']; // 注意Android使用registrationDate
    } else if (androidMap['firstVisitDate'] != null) {
      windowsMap['first_visit_date'] =
          androidMap['firstVisitDate']; // 有些Android应用可能使用firstVisitDate
    } else {
      windowsMap['first_visit_date'] = DateTimeFormatter.nowDbString();
    }

    return windowsMap;
  }

  // 搜索患者 - 包含姓名、电话、备注等信息的模糊搜索
  Future<List<Patient>> searchPatients(
    String query, {
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
    Map<String, String>? advancedCriteria,
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 检查数据库连接状态
    if (_dataSourceType == 'sqlite' && _database != null) {
      try {
        // 检查数据库是否已关闭
        if (!_database!.isOpen) {
          print('检测到数据库连接已关闭，尝试重新初始化...');
          await _ensureDatabaseConnection();
        }
      } catch (e) {
        print('检查数据库连接状态时出错: $e');
        // 尝试重新初始化数据库连接
        await _ensureDatabaseConnection();
      }
    }

    try {
      final db = _database;
      // 检查数据库连接状态
      if (db == null) {
        return [];
      }

      List<Patient> patients = [];

      // 是否是高级搜索
      bool isAdvancedSearch =
          advancedCriteria != null && advancedCriteria.isNotEmpty;

      if (isAdvancedSearch) {
        // 处理多条件高级搜索
        String nameQuery = advancedCriteria['name'] ?? '';
        String addressQuery = advancedCriteria['address'] ?? '';
        String phoneQuery = advancedCriteria['phone'] ?? '';
        String doctorQuery = advancedCriteria['doctor'] ?? '';
        String medicalRecordQuery = advancedCriteria['medical_record'] ?? '';

        // 生成带空格和不带空格的搜索词，以提高拼音搜索的准确性
        String nameQueryNoSpace = nameQuery.replaceAll(' ', '');
        String addressQueryNoSpace = addressQuery.replaceAll(' ', '');

        // 构建SQL查询
        String sql = '''
          SELECT * FROM patients WHERE 1=1
        ''';

        List<dynamic> arguments = [];

        // 添加名称搜索条件 - 支持姓名、姓名拼音和姓名首字母搜索
        if (nameQuery.isNotEmpty) {
          sql += '''
            AND (
              name LIKE ? OR 
              name_pinyin LIKE ? OR 
              REPLACE(name_pinyin, ' ', '') LIKE ? OR
              name_initials LIKE ?
            )
          ''';
          arguments.add('%$nameQuery%'); // 原始姓名查询
          arguments.add('%$nameQuery%'); // 拼音带空格匹配
          arguments.add('%$nameQueryNoSpace%'); // 数据库中删除空格后匹配无空格输入
          arguments.add('%$nameQuery%'); // 首字母匹配
        }

        // 添加地址搜索条件 - 支持地址和地址拼音搜索
        if (addressQuery.isNotEmpty) {
          sql += '''
            AND (
              address LIKE ? OR 
              address_pinyin LIKE ? OR
              REPLACE(address_pinyin, ' ', '') LIKE ?
            )
          ''';
          arguments.add('%$addressQuery%'); // 原始地址查询
          arguments.add('%$addressQuery%'); // 拼音带空格匹配
          arguments.add('%$addressQueryNoSpace%'); // 数据库中删除空格后匹配无空格输入
        }

        // 添加电话搜索条件
        if (phoneQuery.isNotEmpty) {
          sql += ' AND phone LIKE ?';
          arguments.add('%$phoneQuery%');
        }

        // 添加医生搜索条件
        if (doctorQuery.isNotEmpty) {
          sql += ' AND doctor LIKE ?';
          arguments.add('%$doctorQuery%');
        }

        // 添加病历号搜索条件
        if (medicalRecordQuery.isNotEmpty) {
          sql += ' AND medical_record_number LIKE ?';
          arguments.add('%$medicalRecordQuery%');
        }

        // 添加日期过滤
        if (startDate != null) {
          sql += ' AND $dateFilterType >= ?';
          arguments.add(DateTimeFormatter.toDbString(startDate));
        }
        if (endDate != null) {
          sql += ' AND $dateFilterType <= ?';
          arguments.add(DateTimeFormatter.toDbString(endDate));
        }

        // 添加排序
        sql +=
            ' ORDER BY ${sortField ?? 'updated_at'} ${sortAscending ? 'ASC' : 'DESC'}, id DESC';

        final List<Map<String, dynamic>> results =
            await db.rawQuery(sql, arguments);
        patients = results.map((data) => Patient.fromMap(data)).toList();
      } else {
        // 使用传统的模糊搜索
        // 处理查询字符串，生成无空格版本用于拼音搜索
        String queryNoSpace = query.replaceAll(' ', '');

        // 更改查询方式，确保拼音和首字母搜索能正常工作
        final List<Map<String, dynamic>> results = await db.rawQuery(
          '''
          SELECT * FROM patients 
          WHERE medical_record_number LIKE ? 
          OR name LIKE ? 
          OR (name_pinyin IS NOT NULL AND name_pinyin LIKE ?)
          OR (name_pinyin IS NOT NULL AND REPLACE(name_pinyin, ' ', '') LIKE ?)
          OR (name_initials IS NOT NULL AND name_initials LIKE ?)
          OR phone LIKE ? 
          OR address LIKE ?
          OR (address_pinyin IS NOT NULL AND address_pinyin LIKE ?)
          OR (address_pinyin IS NOT NULL AND REPLACE(address_pinyin, ' ', '') LIKE ?)
          ${startDate != null ? 'AND $dateFilterType >= ?' : ''}
          ${endDate != null ? 'AND $dateFilterType <= ?' : ''}
          ORDER BY ${sortField ?? 'updated_at'} ${sortAscending ? 'ASC' : 'DESC'}, id DESC
          ''',
          [
            '%$query%', // 病历号
            '%$query%', // 姓名
            '%$query%', // 姓名拼音带空格
            '%$queryNoSpace%', // 删除数据库中拼音空格后匹配无空格输入
            '%$query%', // 姓名首字母
            '%$query%', // 电话
            '%$query%', // 地址
            '%$query%', // 地址拼音带空格
            '%$queryNoSpace%', // 删除数据库中拼音空格后匹配无空格输入
            if (startDate != null) DateTimeFormatter.toDbString(startDate),
            if (endDate != null) DateTimeFormatter.toDbString(endDate),
          ],
        );
        patients = results.map((data) => Patient.fromMap(data)).toList();
      }

      // 返回搜索结果
      return patients;
    } catch (e) {
      print('搜索患者时出错: $e');
      return [];
    }
  }

  // 获取患者分页数据
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
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    print('获取患者分页数据: 页码=$page, 每页数量=$pageSize, 排序字段=$sortField, 升序=$sortAscending');
    print('使用数据源类型: $_effectiveDataSourceType');

    // 使用数据源架构
    final dataSource = _currentDataSource;
    if (dataSource == null) {
      throw Exception('数据源未初始化: _effectiveDataSourceType=$_effectiveDataSourceType, _sqliteDataSource=${_sqliteDataSource != null}, _mysqlDataSource=${_mysqlDataSource != null}');
    }

    try {
      final result = await dataSource.getPatientsPage(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        sortField: sortField,
        sortAscending: sortAscending,
        startDate: startDate,
        endDate: endDate,
        dateFilterType: dateFilterType,
      );
      print('数据源分页查询成功: 总数=${result['totalCount']}, 当前页数据=${result['patients'].length}');
      return result;
    } catch (e) {
      print('数据源分页查询失败: $e');
      rethrow;
    }
  }

  // 辅助方法：获取数据库表名
  Future<List<String>> _getTableNames() async {
    if (_dataSourceType == 'sqlite') {
      final result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      return result.map((table) => table['name'] as String).toList();
    } else {
      // MySQL获取表名
      final conn = _currentMysqlConnection;
      if (conn == null) {
        return [];
      }
      final result = await conn.query('SHOW TABLES');
      // 确保不为null
      List<String> tableNames = [];
      for (var row in result) {
        if (row.fields.isNotEmpty &&
            row.values != null &&
            row.values!.isNotEmpty) {
          final values = row.values;
          if (values != null && values.isNotEmpty) {
            var value = values.first;
            tableNames.add(value?.toString() ?? '');
          }
        }
      }
      return tableNames;
    }
  }

  // 尝试将SQLite中刚插入的patient记录同步到MySQL（保留相同id）
  // 这是一个非阻塞操作：如果MySQL不可用或同步失败，仅记录错误
  Future<void> _trySyncPatientToMySQL(
      Map<String, dynamic> patientMap, int sqliteId) async {
    // 异步执行，同步不是必须成功才能返回SQLite id
    print('尝试将患者(id=$sqliteId)同步到MySQL - 开始，同步在后台执行。当前_mysqlConnection=${_mysqlConnection != null}');
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过患者同步(id=$sqliteId)');
          return;
        }

        // 更严谨的患者匹配逻辑：优先通过ID匹配，其次通过病历号+姓名+首诊日期的组合匹配
        try {
          final mrn = patientMap['medical_record_number'];
          final name = patientMap['name'];
          final firstVisitDate = patientMap['first_visit_date'];
          print('检查MySQL中是否已存在患者: SQLiteID=$sqliteId, 病历号=$mrn, 姓名=$name');
          
          // 第一步：通过ID精确匹配（最可靠）
          Results existById = await conn.query(
            'SELECT id, name, medical_record_number, first_visit_date FROM patients WHERE id = ? LIMIT 1',
            [sqliteId],
          );
          
          Map<String, dynamic>? existingPatient;
          
          if (existById.isNotEmpty) {
            final row = existById.first;
            final existingName = row['name']?.toString() ?? '';
            final existingMrn = row['medical_record_number'];
            final existingFirstVisit = row['first_visit_date']?.toString() ?? '';
            
            print('通过ID找到MySQL患者: ID=$sqliteId, 姓名=$existingName, 病历号=$existingMrn');
            
            // 验证关键信息是否匹配，防止ID冲突
            bool isValidMatch = true;
            
            // 如果姓名不匹配，可能是ID冲突
            if (existingName != name) {
              print('警告：ID匹配但姓名不符 - MySQL姓名:$existingName, SQLite姓名:$name');
              isValidMatch = false;
            }
            
            // 如果病历号都不为空且不匹配，可能是ID冲突
            if (mrn != null && existingMrn != null && existingMrn != mrn) {
              print('警告：ID匹配但病历号不符 - MySQL病历号:$existingMrn, SQLite病历号:$mrn');
              isValidMatch = false;
            }
            
            if (isValidMatch) {
              existingPatient = {
                'id': row['id'],
                'name': existingName,
                'medical_record_number': existingMrn,
                'first_visit_date': existingFirstVisit,
                'match_type': 'id'
              };
            }
          }
          
          // 第二步：如果ID匹配失败，尝试通过病历号+姓名组合匹配（仅当病历号不为空时）
          if (existingPatient == null && mrn != null) {
            Results existByMrnAndName = await conn.query(
              'SELECT id, name, medical_record_number, first_visit_date FROM patients WHERE medical_record_number = ? AND name = ? LIMIT 1',
              [mrn, name],
            );
            
            if (existByMrnAndName.isNotEmpty) {
              final row = existByMrnAndName.first;
              print('通过病历号+姓名找到MySQL患者: ID=${row['id']}, 姓名=${row['name']}, 病历号=${row['medical_record_number']}');
              
              existingPatient = {
                'id': row['id'],
                'name': row['name']?.toString() ?? '',
                'medical_record_number': row['medical_record_number'],
                'first_visit_date': row['first_visit_date']?.toString() ?? '',
                'match_type': 'mrn_name'
              };
            }
          }
          
          // 第三步：如果前两步都失败，尝试通过姓名+首诊日期匹配（最后的保险措施）
          if (existingPatient == null && firstVisitDate != null) {
            Results existByNameAndDate = await conn.query(
              'SELECT id, name, medical_record_number, first_visit_date FROM patients WHERE name = ? AND first_visit_date = ? LIMIT 1',
              [name, firstVisitDate],
            );
            
            if (existByNameAndDate.isNotEmpty) {
              final row = existByNameAndDate.first;
              print('通过姓名+首诊日期找到MySQL患者: ID=${row['id']}, 姓名=${row['name']}, 首诊日期=${row['first_visit_date']}');
              
              // 额外验证：如果病历号都不为空但不匹配，则不认为是同一患者
              final existingMrn = row['medical_record_number'];
              if (mrn != null && existingMrn != null && existingMrn != mrn) {
                print('姓名+日期匹配但病历号冲突，跳过匹配 - MySQL病历号:$existingMrn, SQLite病历号:$mrn');
              } else {
                existingPatient = {
                  'id': row['id'],
                  'name': row['name']?.toString() ?? '',
                  'medical_record_number': existingMrn,
                  'first_visit_date': row['first_visit_date']?.toString() ?? '',
                  'match_type': 'name_date'
                };
              }
            }
          }
          
          Results exist;
          if (existingPatient != null) {
            exist = await conn.query('SELECT id FROM patients WHERE id = ? LIMIT 1', [existingPatient['id']]);
          } else {
            // 创建一个空的Results对象 - 使用正确的SQL语法
            exist = await conn.query('SELECT 1 LIMIT 0'); // 这会返回一个空的Results
          }

          if (exist.isNotEmpty && existingPatient != null) {
            final existingId = existingPatient['id'] as int;
            final matchType = existingPatient['match_type'] as String;
            print('MySQL中已存在患者记录，准备更新: 现有ID=$existingId, 匹配方式=$matchType');
            
            final updateSql = '''
              UPDATE patients SET
                name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?,
                medical_record_number = ?, address = ?, address_pinyin = ?, identification_number = ?,
                doctor = ?, dental_condition = ?, treatment_items = ?, first_visit_date = ?, total_cost = ?, created_at = ?, updated_at = ?
              WHERE id = ?
            ''';
            final updateParams = [
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
              existingId,
            ];

            try {
              final result = await conn.query(updateSql, updateParams);
              print('成功更新MySQL患者(id=$existingId)，影响行数: ${result.affectedRows}');
              print('更新的患者信息: 姓名=${patientMap['name']}, 更新时间=${patientMap['updated_at']}');
            } catch (e) {
              print('更新MySQL患者(id=$existingId)时出错: $e');
              print('更新SQL: $updateSql');
              print('更新参数: $updateParams');
            }
          } else {
            print('MySQL中不存在该患者记录，准备插入新记录: SQLiteID=$sqliteId');
            
            final insertSql = '''
              INSERT INTO patients
              (id, name, name_pinyin, name_initials, age, gender, phone, medical_record_number, address, address_pinyin, identification_number, doctor, dental_condition, treatment_items, first_visit_date, total_cost, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''';
            final insertParams = [
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
            ];

            try {
              final result = await conn.query(insertSql, insertParams);
              print('成功将患者(id=$sqliteId)同步到MySQL（新建），插入ID: ${result.insertId}');
              print('插入的患者信息: 姓名=${patientMap['name']}, 创建时间=${patientMap['created_at']}');
            } catch (e) {
              print('插入MySQL患者(id=$sqliteId)时出错: $e');
              print('插入SQL: $insertSql');
              print('插入参数: $insertParams');
            }
          }
        } catch (e) {
          print('将患者同步到MySQL时出错: $e');
        }
      } catch (e) {
        print('患者同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  // 尝试将SQLite中删除的患者记录同步删除到MySQL（非阻塞操作）
  Future<void> _trySyncDeletePatientToMySQL(int patientId, {String? patientName, dynamic medicalRecordNumber}) async {
    print('尝试从MySQL删除患者(id=$patientId) - 开始，删除在后台执行');
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过患者删除同步(id=$patientId)');
          return;
        }

        // 严谨的删除逻辑：先确认患者存在，然后验证关键信息，最后按顺序删除相关数据
        try {
          // 1. 首先确认患者是否存在
          final patientCheck = await conn.query(
            'SELECT id, name, medical_record_number FROM patients WHERE id = ? LIMIT 1',
            [patientId],
          );

          if (patientCheck.isEmpty) {
            print('MySQL中不存在患者(id=$patientId)，无需删除');
            return;
          }

          final patientInfo = patientCheck.first;
          final existingName = patientInfo['name']?.toString() ?? '';
          final existingMrn = patientInfo['medical_record_number'];
          
          print('确认MySQL中存在患者: ID=$patientId, 姓名=$existingName, 病历号=$existingMrn');
          
          // 2. 验证关键信息以防止误删除
          bool isValidForDeletion = true;
          String validationErrors = '';
          
          // 验证姓名（如果提供了姓名参数）
          if (patientName != null && patientName.isNotEmpty) {
            if (existingName != patientName) {
              isValidForDeletion = false;
              validationErrors += '姓名不匹配(MySQL:$existingName, 期望:$patientName); ';
              print('警告：删除验证失败 - 姓名不匹配: MySQL姓名=$existingName, 期望姓名=$patientName');
            }
          }
          
          // 验证病历号（如果提供了病历号参数）
          if (medicalRecordNumber != null) {
            if (existingMrn != medicalRecordNumber) {
              isValidForDeletion = false;
              validationErrors += '病历号不匹配(MySQL:$existingMrn, 期望:$medicalRecordNumber); ';
              print('警告：删除验证失败 - 病历号不匹配: MySQL病历号=$existingMrn, 期望病历号=$medicalRecordNumber');
            }
          }
          
          // 如果验证失败，拒绝删除
          if (!isValidForDeletion) {
            print('❌ 拒绝删除患者(id=$patientId): 验证失败 - $validationErrors');
            print('为防止误删除，已跳过MySQL同步删除操作');
            return;
          }
          
          print('✅ 患者信息验证通过，继续删除操作: ID=$patientId, 姓名=$existingName, 病历号=$existingMrn');

          // 3. 禁用外键约束检查
          await conn.query('SET FOREIGN_KEY_CHECKS = 0');

          // 4. 获取该患者的所有材料ID
          final materialIdsResult = await conn.query(
            'SELECT id FROM patient_materials WHERE patient_id = ?',
            [patientId],
          );
          
          final materialIds = materialIdsResult.map((row) => row['id'] as int).toList();
          print('找到${materialIds.length}个患者材料ID需要删除');

          // 5. 删除材料相关的图片
          if (materialIds.isNotEmpty) {
            final placeholders = materialIds.map((_) => '?').join(',');
            final materialImagesResult = await conn.query(
              'DELETE FROM material_images WHERE material_id IN ($placeholders)',
              materialIds,
            );
            print('已删除${materialImagesResult.affectedRows}张材料图片');
          }

          // 6. 删除患者材料
          final materialsResult = await conn.query(
            'DELETE FROM patient_materials WHERE patient_id = ?',
            [patientId],
          );
          print('已删除${materialsResult.affectedRows}条材料记录');

          // 7. 删除财务相关记录
          final financialRecordIds = await conn.query(
            'SELECT id FROM financial_records WHERE patient_id = ?',
            [patientId],
          );
          
          if (financialRecordIds.isNotEmpty) {
            final recordIds = financialRecordIds.map((row) => row['id'] as int).toList();
            final placeholders = recordIds.map((_) => '?').join(',');
            
            // 删除财务详情
            final financialItemsResult = await conn.query(
              'DELETE FROM financial_items WHERE financial_record_id IN ($placeholders)',
              recordIds,
            );
            print('已删除${financialItemsResult.affectedRows}条财务详情记录');
          }
          
          // 删除财务记录
          final financialResult = await conn.query(
            'DELETE FROM financial_records WHERE patient_id = ?',
            [patientId],
          );
          print('已删除${financialResult.affectedRows}条财务记录');

          // 8. 删除预约记录
          final appointmentsResult = await conn.query(
            'DELETE FROM appointments WHERE patient_id = ?',
            [patientId],
          );
          print('已删除${appointmentsResult.affectedRows}条预约记录');

          // 9. 删除患者病历记录
          final medicalRecordsResult = await conn.query(
            'DELETE FROM patient_medical_records WHERE patient_id = ?',
            [patientId],
          );
          print('已删除${medicalRecordsResult.affectedRows}条病历记录');

          // 10. 最后删除患者记录
          final patientResult = await conn.query(
            'DELETE FROM patients WHERE id = ?',
            [patientId],
          );
          print('已删除${patientResult.affectedRows}条患者记录');

          // 11. 重新启用外键约束检查
          await conn.query('SET FOREIGN_KEY_CHECKS = 1');

          print('成功从MySQL删除患者(id=$patientId)及其所有相关数据');

        } catch (e) {
          print('从MySQL删除患者时出错: $e');
          // 确保重新启用外键约束检查
          try {
            await conn.query('SET FOREIGN_KEY_CHECKS = 1');
          } catch (fkError) {
            print('重新启用外键约束检查失败: $fkError');
          }
        }
      } catch (e) {
        print('患者删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  // 添加患者
  Future<int> addPatient(Patient patient) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 如果有数据源，优先使用数据源
    if (_currentDataSource != null) {
      try {
        // 明确设置创建时间和更新时间
        final Map<String, dynamic> patientMap = patient.toMap();
        final now = DateTime.now();
        final nowStr = DateTimeFormatter.toDbString(now);
        patientMap['created_at'] = nowStr;
        patientMap['updated_at'] = nowStr;

        // 自动生成拼音字段
        patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
        patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);
        
        if (patient.address != null) {
          patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
        }

        // 创建新的Patient对象
        final updatedPatient = Patient.fromMap(patientMap);
        
        final dataSource = _currentDataSource;
        if (dataSource == null) {
          throw Exception('数据源未初始化，无法创建患者');
        }
        final id = await dataSource.createPatient(updatedPatient);

        // 清除缓存，标记需要刷新
        clearCache();
        _patientsNeedRefresh = true;
        notifyListeners();

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
                    _trySyncPatientToMySQL(patientMap, id);
        }

        return id;
      } catch (e) {
        print('数据源添加患者失败: $e');
        _setError('添加患者失败: $e');
        // 如果数据源失败，抛出异常
        rethrow;
      }
    }

    // 如果没有数据源，抛出异常
    throw Exception('数据源未初始化，无法添加患者');
  }

  // 更新患者
  Future<int> updatePatient(Patient patient) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (patient.id == null) {
      throw Exception('更新患者时必须提供ID');
    }

    // 如果有数据源，优先使用数据源
    if (_currentDataSource != null) {
      try {
        // 明确设置更新时间为当前时间
        final Map<String, dynamic> patientMap = patient.toMap();
        final now = DateTime.now();
        patientMap['updated_at'] = DateTimeFormatter.toDbString(now);

        // 自动更新拼音字段 - 无论拼音字段是否为空，只要有姓名和地址信息就更新
        patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
        patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);
        print('更新姓名拼音: ${patientMap['name_pinyin']}');
        print('更新姓名首字母: ${patientMap['name_initials']}');

        if (patient.address != null) {
          patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
          print('更新地址拼音: ${patientMap['address_pinyin']}');
        }

        print('更新患者ID: ${patient.id}, 设置更新时间为: ${patientMap['updated_at']}');

        // 创建更新后的Patient对象
        final updatedPatient = Patient.fromMap(patientMap);
        
        final dataSource = _currentDataSource;
        if (dataSource == null) {
          throw Exception('数据源未初始化，无法更新患者');
        }
        final success = await dataSource.updatePatient(updatedPatient);

        if (success) {
          // 清除缓存，标记需要刷新
          clearCache();
          _patientsNeedRefresh = true;
          notifyListeners();

          // 如果当前使用的是SQLite数据源，需要同步到MySQL
          if (_effectiveDataSourceType == 'sqlite') {
                        _trySyncPatientToMySQL(patientMap, patient.id!);
          }

          return 1; // 成功更新返回1
        } else {
          return 0; // 更新失败返回0
        }
      } catch (e) {
        print('数据源更新患者失败: $e');
        _setError('更新患者失败: $e');
        rethrow;
      }
    }

    // 如果没有数据源，抛出异常
    throw Exception('数据源未初始化，无法更新患者');
  }

  // 删除患者
  Future<void> deletePatient(int patientId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 如果有数据源，优先使用数据源
    if (_currentDataSource != null) {
      try {
                // 在删除前先获取患者信息，用于MySQL同步验证
        Patient? patientToDelete;
        String? patientName;
        dynamic medicalRecordNumber;
        
        if (_effectiveDataSourceType == 'sqlite') {
          try {
            patientToDelete = await getPatient(patientId);
            if (patientToDelete != null) {
              patientName = patientToDelete.name;
              medicalRecordNumber = patientToDelete.medical_record_number;
              print('获取待删除患者信息: 姓名=$patientName, 病历号=$medicalRecordNumber');
            }
          } catch (e) {
            print('获取待删除患者信息失败: $e，将继续删除但MySQL同步验证可能受限');
          }
        }
        
        final dataSource = _currentDataSource;
        if (dataSource == null) {
          throw Exception('数据源未初始化，无法删除患者');
        }
        final success = await dataSource.deletePatient(patientId);

        if (success) {
          // 清除缓存，标记需要刷新
          clearCache();
          _patientsNeedRefresh = true;
          notifyListeners();

          // 如果当前使用的是SQLite数据源，需要同步到MySQL
          if (_effectiveDataSourceType == 'sqlite') {
                        _trySyncDeletePatientToMySQL(
              patientId, 
              patientName: patientName, 
              medicalRecordNumber: medicalRecordNumber
            );
          }

                  } else {
          throw Exception('删除患者失败：数据源返回false');
        }
      } catch (e) {
        print('数据源删除患者失败: $e');
        _setError('删除患者失败: $e');
        rethrow;
      }
    } else {
      // 如果没有数据源，抛出异常
      throw Exception('数据源未初始化，无法删除患者');
    }
  }

  // 更新所有患者的拼音数据
  Future<void> updateAllPatientsPinyin() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    List<Patient> patients = await getAllPatients();
    int updatedCount = 0;

    for (var patient in patients) {
      Map<String, dynamic> patientMap = patient.toMap();

      // 更新拼音和首字母字段
      patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
      patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);

      if (patient.address != null && patient.address!.isNotEmpty) {
        patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
      }

      try {
        if (_dataSourceType == 'sqlite') {
          await _database!.update(
            'patients',
            {
              'name_pinyin': patientMap['name_pinyin'],
              'name_initials': patientMap['name_initials'],
              'address_pinyin': patientMap['address_pinyin'],
            },
            where: 'id = ?',
            whereArgs: [patient.id],
          );
          updatedCount++;
        } else {
          await _mysqlConnection!.query(
            'UPDATE patients SET name_pinyin = ?, name_initials = ?, address_pinyin = ? WHERE id = ?',
            [
              patientMap['name_pinyin'],
              patientMap['name_initials'],
              patientMap['address_pinyin'],
              patient.id,
            ],
          );
          updatedCount++;
        }
      } catch (e) {
        print('更新患者拼音数据时出错: $e');
      }
    }

    print('已更新 $updatedCount/${patients.length} 位患者的拼音和首字母数据');

    // 标记患者数据需要刷新
    _patientsNeedRefresh = true;
    notifyListeners();
  }

  // 检查病历号是否已存在
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber,
      [int? excludePatientId]) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      if (_dataSourceType == 'sqlite') {
        final db = await database;

        // 构建查询条件
        String whereClause = 'medical_record_number = ?';
        List<dynamic> whereArgs = [medicalRecordNumber];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final result = await db!.query(
          'patients',
          where: whereClause,
          whereArgs: whereArgs,
          limit: 1,
        );

        return result.isNotEmpty;
      } else if (_dataSourceType == 'mysql') {
        final conn = await mysqlConnection;

        // 构建查询条件
        String whereClause = 'medical_record_number = ?';
        List<dynamic> whereArgs = [medicalRecordNumber];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final results = await conn!.query(
          'SELECT id FROM patients WHERE $whereClause LIMIT 1',
          whereArgs,
        );

        return results.isNotEmpty;
      }

      return false;
    } catch (e) {
      print('检查病历号存在性时出错: $e');
      return false;
    }
  }

  // 检查姓名是否已存在
  Future<bool> checkPatientNameExists(String name,
      [int? excludePatientId]) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      if (_dataSourceType == 'sqlite') {
        final db = await database;

        // 构建查询条件
        String whereClause = 'name = ?';
        List<dynamic> whereArgs = [name];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final result = await db!.query(
          'patients',
          where: whereClause,
          whereArgs: whereArgs,
          limit: 1,
        );

        return result.isNotEmpty;
      } else if (_dataSourceType == 'mysql') {
        final conn = await mysqlConnection;

        // 构建查询条件
        String whereClause = 'name = ?';
        List<dynamic> whereArgs = [name];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final results = await conn!.query(
          'SELECT id FROM patients WHERE $whereClause LIMIT 1',
          whereArgs,
        );

        return results.isNotEmpty;
      }

      return false;
    } catch (e) {
      print('检查患者姓名存在性时出错: $e');
      return false;
    }
  }

  // ==================== 牙齿状况数据格式处理 ====================

  // 处理牙齿状况的数据格式
  String processDentalConditionFormat(String sqlContent) {
    print('处理所有INSERT语句中的二进制数据,不仅仅是patients表');
    
    // 正则表达式匹配INSERT INTO语句并捕获表名
    final regex = RegExp(r'INSERT INTO `(\w+)`.*VALUES.*', multiLine: true);
    
    return sqlContent.replaceAllMapped(regex, (match) {
      String statement = match.group(0) ?? '';
      String tableName = match.group(1) ?? '';
      
      // 处理常见的二进制字段
      if (tableName == 'patients') {
        // 处理患者表中的特定字段
        statement = _processBinaryDentalCondition(statement);
        statement = _processTreatmentItems(statement);
        statement = _processTotalCost(statement);
      }
      
      // 处理所有表中的任何可能的二进制数据格式
      statement = _processAnyBinaryField(statement);
      
      return statement;
    });
  }

  // 处理任何表中的二进制数据字段
  String _processAnyBinaryField(String sqlStatement) {
    // 正则表达式匹配任何字段后的x'...'格式的十六进制数据
    RegExp binaryRegex = RegExp(r"', X'([0-9A-Fa-f]+)'");
    
    return sqlStatement.replaceAllMapped(binaryRegex, (match) {
      String hexData = match.group(1) ?? '';
      
      // 将十六进制字符串转换为字节数组
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          String hexByte = hexData.substring(i, i + 2);
          int byteValue = int.parse(hexByte, radix: 16);
          bytes.add(byteValue);
        }
      }
      
      // 将字节数组转换为字符串
      String decodedString = String.fromCharCodes(bytes);
      
      // 返回处理后的字符串，用单引号包围
      return "', '$decodedString'";
    });
  }

  // 处理牙齿状况字段
  String _processBinaryDentalCondition(String sqlStatement) {
    // 匹配牙齿状况字段的十六进制数据
    RegExp dentalRegex = RegExp(r"dental_condition', X'([0-9A-Fa-f]+)'");
    
    return sqlStatement.replaceAllMapped(dentalRegex, (match) {
      String hexData = match.group(1) ?? '';
      
      // 将十六进制字符串转换为字节数组
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          String hexByte = hexData.substring(i, i + 2);
          int byteValue = int.parse(hexByte, radix: 16);
          bytes.add(byteValue);
        }
      }
      
      // 将字节数组转换为字符串
      String decodedString = String.fromCharCodes(bytes);
      
      // 返回处理后的字符串
      return "dental_condition', '$decodedString'";
    });
  }

  // 处理治疗项目字段
  String _processTreatmentItems(String sqlStatement) {
    // 匹配治疗项目字段的十六进制数据
    RegExp dentalRegex = RegExp(r"treatment_items', X'([0-9A-Fa-f]+)'");
    
    return sqlStatement.replaceAllMapped(dentalRegex, (match) {
      String hexData = match.group(1) ?? '';
      
      // 将十六进制字符串转换为字节数组
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          String hexByte = hexData.substring(i, i + 2);
          int byteValue = int.parse(hexByte, radix: 16);
          bytes.add(byteValue);
        }
      }
      
      // 将字节数组转换为字符串
      String decodedString = String.fromCharCodes(bytes);
      
      // 返回处理后的字符串
      return "treatment_items', '$decodedString'";
    });
  }

  // 处理总费用字段
  String _processTotalCost(String sqlStatement) {
    // 匹配总费用字段的十六进制数据
    RegExp costRegex = RegExp(r"total_cost', X'([0-9A-Fa-f]+)'");
    
    return sqlStatement.replaceAllMapped(costRegex, (match) {
      String hexData = match.group(1) ?? '';
      
      // 将十六进制字符串转换为字节数组
      List<int> bytes = [];
      for (int i = 0; i < hexData.length; i += 2) {
        if (i + 1 < hexData.length) {
          String hexByte = hexData.substring(i, i + 2);
          int byteValue = int.parse(hexByte, radix: 16);
          bytes.add(byteValue);
        }
      }
      
      // 将字节数组转换为字符串
      String decodedString = String.fromCharCodes(bytes);
      
      // 返回处理后的字符串
      return "total_cost', '$decodedString'";
    });
  }

  // 获取当前用户信息
  User? get currentUser => _currentUser;

  // =================== 患者材料相关方法 ===================

  /// 添加患者材料
  Future<PatientMaterial> addPatientMaterial(PatientMaterial material) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用有效数据源类型，确保与患者模块配置一致
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      print('添加患者材料，使用数据源类型: $effectiveDataSourceType');
      
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        final id = await db.insert('patient_materials', material.toMap());
        final savedMaterial = material.copyWith(id: id);
        print('SQLite患者材料添加成功: 材料ID=$id');
        
        // 尝试同步到MySQL（非阻塞）
        try {
          _trySyncPatientMaterialToMySQL(savedMaterial, isUpdate: false);
        } catch (e) {
          print('同步患者材料到MySQL时发生错误（本地不影响保存）: $e');
        }
        
        return savedMaterial;
      } else if (effectiveDataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未建立');
        
        // 检查表结构，如果字段不匹配则重建表
        try {
          final result = await conn.query('DESCRIBE patient_materials');
          bool needsRebuild = false;
          
          // 检查必要的字段是否存在
          final requiredFields = ['description', 'created_at', 'updated_at'];
          final existingFields = result.map((row) => row[0].toString()).toList();
          
          for (final field in requiredFields) {
            if (!existingFields.contains(field)) {
              needsRebuild = true;
              break;
            }
          }
          
          if (needsRebuild) {
            print('patient_materials表结构不匹配，正在重建...');
            // 先删除所有数据，然后重建表
            await conn.query('DELETE FROM patient_materials');
            await conn.query('DROP TABLE patient_materials');
            await conn.query('''
              CREATE TABLE patient_materials (
                id INT AUTO_INCREMENT PRIMARY KEY,
                patient_id INT NOT NULL,
                description TEXT NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (patient_id) REFERENCES patients (id)
              )
            ''');
            print('patient_materials表重建完成');
          }
        } catch (e) {
          print('检查patient_materials表结构时出错: $e');
          // 如果检查失败，尝试重建表
          try {
            await conn.query('DELETE FROM patient_materials');
            await conn.query('DROP TABLE patient_materials');
            await conn.query('''
              CREATE TABLE patient_materials (
                id INT AUTO_INCREMENT PRIMARY KEY,
                patient_id INT NOT NULL,
                description TEXT NOT NULL,
                created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                FOREIGN KEY (patient_id) REFERENCES patients (id)
              )
            ''');
            print('patient_materials表重建完成');
          } catch (e2) {
            print('重建patient_materials表失败: $e2');
            throw Exception('重建patient_materials表失败: $e2');
          }
        }
        
        final result = await conn.query('''
          INSERT INTO patient_materials (patient_id, description, created_at, updated_at)
          VALUES (?, ?, ?, ?)
        ''', [
          material.patientId,
          material.description,
          material.createdAt != null ? DateTimeFormatter.toDbString(material.createdAt!) : null,
          material.updatedAt != null ? DateTimeFormatter.toDbString(material.updatedAt!) : null,
        ]);
        
        final id = result.insertId;
        print('MySQL患者材料添加成功: 材料ID=$id');
        return material.copyWith(id: id);
      } else {
        throw Exception('不支持的数据源类型: $effectiveDataSourceType');
      }
    } catch (e) {
      print('添加患者材料失败: $e');
      rethrow;
    }
  }

  /// 获取患者的所有材料
  Future<List<PatientMaterial>> getPatientMaterials(int patientId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      List<PatientMaterial> materials = [];
      
      // 使用有效数据源类型，确保与患者模块配置一致
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      print('获取患者材料，使用数据源类型: $effectiveDataSourceType');

      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        final maps = await db.query(
          'patient_materials',
          where: 'patient_id = ?',
          whereArgs: [patientId],
          orderBy: 'created_at DESC',
        );
        
        materials = maps.map((map) => PatientMaterial.fromMap(map)).toList();
        print('从SQLite获取到患者材料数量: ${materials.length}');
      } else if (effectiveDataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未建立');
        
        final results = await conn.query('''
          SELECT * FROM patient_materials 
          WHERE patient_id = ? 
          ORDER BY created_at DESC
        ''', [patientId]);
        
        for (var row in results) {
          final map = <String, dynamic>{};
          for (var field in row.fields.keys) {
            var value = row[field];
            // 处理Blob类型数据
            if (value is Blob) {
              try {
                final blobString = String.fromCharCodes(value.toBytes());
                map[field] = blobString;
              } catch (e) {
                print('Blob转换失败: $e');
                map[field] = value.toString();
              }
            } else {
              map[field] = value;
            }
          }
          materials.add(PatientMaterial.fromMap(map));
        }
        print('从MySQL获取到患者材料数量: ${materials.length}');
      }
      
      return materials;
    } catch (e) {
      print('获取患者材料失败: $e');
      return [];
    }
  }

  /// 更新患者材料
  Future<bool> updatePatientMaterial(PatientMaterial material) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return false;
        
        final count = await db.update(
          'patient_materials',
          material.toMap(),
          where: 'id = ?',
          whereArgs: [material.id],
        );
        
        if (count > 0) {
          // 尝试同步到MySQL（非阻塞）
          try {
            print('SQLite患者材料更新成功，开始同步到MySQL: 材料ID=${material.id}');
            _trySyncPatientMaterialToMySQL(material, isUpdate: true);
          } catch (e) {
            print('同步患者材料到MySQL时发生错误（本地不影响保存）: $e');
          }
        }
        
        return count > 0;
      } else {
        final conn = _currentMysqlConnection;
        if (conn == null) return false;
        
        final result = await conn.query('''
          UPDATE patient_materials 
          SET description = ?, updated_at = ?
          WHERE id = ?
        ''', [
          material.description,
          material.updatedAt != null ? DateTimeFormatter.toDbString(material.updatedAt!) : null,
          material.id,
        ]);
        
        return (result.affectedRows ?? 0) > 0;
      }
    } catch (e) {
      print('更新患者材料失败: $e');
      return false;
    }
  }

  /// 删除患者材料
  Future<bool> deletePatientMaterial(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return false;

        bool success = false;
        // 使用联表删除，确保图片被正确删除
        await db.transaction((txn) async {
          // 先删除关联的图片数据
          final imageCount = await txn.delete(
            'material_images',
            where: 'material_id = ?',
            whereArgs: [id],
          );
          print('删除患者材料 $id 的关联图片: $imageCount 张');

          // 再删除材料记录
          final materialCount = await txn.delete(
            'patient_materials',
            where: 'id = ?',
            whereArgs: [id],
          );
          print('删除患者材料记录: $materialCount 条');
          success = materialCount > 0;
        });
        
        if (success) {
          // 尝试同步删除到MySQL（非阻塞）
          try {
            print('SQLite患者材料删除成功，开始同步删除到MySQL: 材料ID=$id');
            _trySyncDeletePatientMaterialToMySQL(id);
          } catch (e) {
            print('同步删除患者材料到MySQL时发生错误（本地不影响删除）: $e');
          }
        }
        
        return success;
      } else {
        final conn = _currentMysqlConnection;
        if (conn == null) return false;

        // MySQL联表删除
        await conn.query('START TRANSACTION');
        try {
          // 先删除关联的图片
          final imageResult = await conn.query(
            'DELETE FROM material_images WHERE material_id = ?',
            [id],
          );
          
          // 再删除材料记录
          final materialResult = await conn.query(
            'DELETE FROM patient_materials WHERE id = ?',
            [id],
          );
          
          await conn.query('COMMIT');
          print('删除患者材料成功: ID=$id，删除了 ${imageResult.affectedRows} 张图片和 ${materialResult.affectedRows} 条材料记录');
        } catch (e) {
          await conn.query('ROLLBACK');
          rethrow;
        }
        return true;
      }
    } catch (e) {
      print('删除患者材料 $id 失败: $e');
      return false;
    }
  }

  /// 添加材料图片
  Future<MaterialImage> addMaterialImage(MaterialImage image) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用有效数据源类型，确保与患者模块配置一致
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      print('添加材料图片，使用数据源类型: $effectiveDataSourceType');
      
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        // 检查数据库表结构是否支持缩略图
        final tableInfo = await db.rawQuery('PRAGMA table_info(material_images)');
        final hasThumbnailSupport = tableInfo.any((col) => col['name'] == 'thumbnail_data');
        
        MaterialImage savedImage;
        if (hasThumbnailSupport) {
          // 支持缩略图的新表结构
          final id = await db.insert('material_images', image.toMap());
          savedImage = image.copyWith(id: id);
        } else {
          // 旧表结构，只保存基本字段
          final basicMap = {
            'material_id': image.materialId,
            'image_data': image.imageData,
            'image_type': image.imageType,
            'file_size': image.fileSize,
            'original_name': image.originalName,
            'created_at': DateTimeFormatter.toDbString(image.createdAt),
          };
          final id = await db.insert('material_images', basicMap);
          savedImage = image.copyWith(id: id);
        }
        
        print('SQLite材料图片添加成功: 图片ID=${savedImage.id}');
        
        // 尝试同步到MySQL（非阻塞）
        try {
          _trySyncMaterialImageToMySQL(savedImage);
        } catch (e) {
          print('同步材料图片到MySQL时发生错误（本地不影响保存）: $e');
        }
        
        return savedImage;
      } else if (effectiveDataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未建立');
        
        // 检查MySQL表结构是否支持缩略图
        try {
          final tableInfo = await conn.query('DESCRIBE material_images');
          final hasThumbnailSupport = tableInfo.any((row) => row[0] == 'thumbnail_data');
          
          if (hasThumbnailSupport) {
            // 支持缩略图的新表结构
            final result = await conn.query('''
              INSERT INTO material_images (material_id, image_data, thumbnail_data, image_type, file_size, thumbnail_size, original_name, created_at, has_thumbnail)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              image.materialId,
              image.imageData,
              image.thumbnailData,
              image.imageType,
              image.fileSize,
              image.thumbnailSize,
              image.originalName ?? '',
              DateTimeFormatter.toDbString(image.createdAt),
              image.hasThumbnail ? 1 : 0,
            ]);
            
            final id = result.insertId;
            print('MySQL材料图片添加成功: 图片ID=$id');
            return image.copyWith(id: id);
          } else {
            // 旧表结构，只保存基本字段
            final result = await conn.query('''
              INSERT INTO material_images (material_id, image_data, image_type, file_size, original_name, created_at)
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              image.materialId,
              image.imageData,
              image.imageType,
              image.fileSize,
              image.originalName ?? '',
              DateTimeFormatter.toDbString(image.createdAt),
            ]);
            
            final id = result.insertId;
            print('MySQL材料图片添加成功: 图片ID=$id');
            return image.copyWith(id: id);
          }
        } catch (e) {
          print('检查MySQL表结构失败，使用基本插入: $e');
          // 如果检查失败，使用基本插入
          final result = await conn.query('''
            INSERT INTO material_images (material_id, image_data, image_type, file_size, original_name, created_at)
            VALUES (?, ?, ?, ?, ?, ?)
          ''', [
            image.materialId,
            image.imageData,
            image.imageType,
            image.fileSize,
            image.originalName ?? '',
            DateTimeFormatter.toDbString(image.createdAt),
          ]);
          
          final id = result.insertId;
          print('MySQL材料图片添加成功: 图片ID=$id');
          return image.copyWith(id: id);
        }
      } else {
        throw Exception('不支持的数据源类型: $effectiveDataSourceType');
      }
    } catch (e) {
      print('添加材料图片失败: $e');
      rethrow;
    }
  }

  /// 获取单个材料图片（包含完整原图数据）
  Future<MaterialImage?> getMaterialImage(int imageId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用有效数据源类型，确保与患者模块配置一致
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      print('获取单个材料图片，使用数据源类型: $effectiveDataSourceType, imageId: $imageId');

      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        final maps = await db.query(
          'material_images',
          where: 'id = ?',
          whereArgs: [imageId],
          limit: 1,
        );
        
        if (maps.isNotEmpty) {
          final image = MaterialImage.fromMap(maps.first);
          print('从SQLite获取到单个材料图片: ID=$imageId, 原图大小=${image.imageData.length}');
          return image;
        }
      } else if (effectiveDataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未建立');
        
        final results = await conn.query('''
          SELECT * FROM material_images 
          WHERE id = ? 
          LIMIT 1
        ''', [imageId]);
        
        if (results.isNotEmpty) {
          final row = results.first;
          final map = <String, dynamic>{};
          for (var field in row.fields.keys) {
            var value = row[field];
            // 处理Blob类型数据
            if (value is Blob) {
              map[field] = value.toBytes();
            } else {
              map[field] = value;
            }
          }
          final image = MaterialImage.fromMap(map);
          print('从MySQL获取到单个材料图片: ID=$imageId, 原图大小=${image.imageData.length}');
          return image;
        }
      }
      
      print('未找到图片: ID=$imageId');
      return null;
    } catch (e) {
      print('获取单个材料图片失败: $e');
      return null;
    }
  }

  /// 获取材料的所有图片
  Future<List<MaterialImage>> getMaterialImages(int materialId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      List<MaterialImage> images = [];
      
      // 使用有效数据源类型，确保与患者模块配置一致
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      print('获取材料图片，使用数据源类型: $effectiveDataSourceType, materialId: $materialId');

      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        final maps = await db.query(
          'material_images',
          where: 'material_id = ?',
          whereArgs: [materialId],
          orderBy: 'created_at ASC',
        );
        
        images = maps.map((map) => MaterialImage.fromMap(map)).toList();
        print('从SQLite获取到材料图片数量: ${images.length}');
      } else if (effectiveDataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未建立');
        
        final results = await conn.query('''
          SELECT * FROM material_images 
          WHERE material_id = ? 
          ORDER BY created_at ASC
        ''', [materialId]);
        
        for (var row in results) {
          final map = <String, dynamic>{};
          for (var field in row.fields.keys) {
            var value = row[field];
            // 处理Blob类型数据
            if (value is Blob) {
              map[field] = value.toBytes();
            } else {
              map[field] = value;
            }
          }
          images.add(MaterialImage.fromMap(map));
        }
        print('从MySQL获取到材料图片数量: ${images.length}');
      }
      
      return images;
    } catch (e) {
      print('获取材料图片失败: $e');
      return [];
    }
  }

  /// 删除材料图片
  Future<bool> deleteMaterialImage(int imageId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return false;
        
        final count = await db.delete(
          'material_images',
          where: 'id = ?',
          whereArgs: [imageId],
        );
        
        if (count > 0) {
          // 尝试同步删除到MySQL（非阻塞）
          try {
            print('SQLite材料图片删除成功，开始同步删除到MySQL: 图片ID=$imageId');
            _trySyncDeleteMaterialImageToMySQL(imageId);
          } catch (e) {
            print('同步删除材料图片到MySQL时发生错误（本地不影响删除）: $e');
          }
        }
        
        return count > 0;
      } else {
        final conn = _currentMysqlConnection;
        if (conn == null) return false;
        
        final result = await conn.query(
          'DELETE FROM material_images WHERE id = ?',
          [imageId],
        );
        
        return (result.affectedRows ?? 0) > 0;
      }
    } catch (e) {
      print('删除材料图片失败: $e');
      return false;
    }
  }

  /// 获取患者材料（包含图片信息）
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithImages(int patientId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      print('开始获取患者材料及图片: patient_id=$patientId');
      print('当前数据源类型: ${_effectiveDataSourceType ?? _dataSourceType}');
      print('数据库连接状态: database=${_database != null}, mysql=${_currentMysqlConnection != null}');
      
      final materials = await getPatientMaterials(patientId);
      print('获取到材料数量: ${materials.length}');
      
      List<PatientMaterialWithImages> result = [];
      
      for (var material in materials) {
        try {
          // 获取材料的图片
          final images = await getMaterialImages(material.id!);
          print('材料 ${material.id} 的图片数量: ${images.length}');
          
          result.add(PatientMaterialWithImages(
            material: material,
            images: images,
          ));
        } catch (e) {
          print('获取材料 ${material.id} 的图片时出错: $e');
          // 即使获取图片失败，也要添加材料（图片为空）
          result.add(PatientMaterialWithImages(
            material: material,
            images: [],
          ));
        }
      }
      
      print('最终返回材料数量: ${result.length}');
      return result;
    } catch (e) {
      print('获取患者材料及图片失败: $e');
      return [];
    }
  }

  /// 只获取患者材料缩略图（快速加载）
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithThumbnails(int patientId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      print('开始获取患者材料及缩略图: patient_id=$patientId');
      
      final materials = await getPatientMaterials(patientId);
      print('获取到材料数量: ${materials.length}');
      
      List<PatientMaterialWithImages> result = [];
      
      // 使用有效数据源类型，确保与患者模块配置一致
      final effectiveDataSourceType = _effectiveDataSourceType ?? _dataSourceType;
      print('获取缩略图，使用数据源类型: $effectiveDataSourceType');
      
      for (var material in materials) {
        try {
          // 获取材料的缩略图
          List<MaterialImage> thumbnails = [];
          
          if (effectiveDataSourceType == 'sqlite') {
            final db = _database;
            if (db != null) {
              final maps = await db.query(
                'material_images',
                columns: ['id', 'material_id', 'thumbnail_data', 'image_type', 'file_size', 'original_name', 'created_at', 'has_thumbnail'],
                where: 'material_id = ?',
                whereArgs: [material.id],
                orderBy: 'created_at ASC',
              );
              
              thumbnails = maps.map((map) => MaterialImage.fromMap(map)).toList();
              print('从SQLite获取材料 ${material.id} 的缩略图数量: ${thumbnails.length}');
            }
          } else if (effectiveDataSourceType == 'mysql') {
            final conn = _currentMysqlConnection;
            if (conn != null) {
              final results = await conn.query('''
                SELECT id, material_id, thumbnail_data, image_type, file_size, original_name, created_at, has_thumbnail
                FROM material_images 
                WHERE material_id = ? 
                ORDER BY created_at ASC
              ''', [material.id]);
              
              for (var row in results) {
                final map = <String, dynamic>{};
                for (var field in row.fields.keys) {
                  var value = row[field];
                  if (value is Blob) {
                    map[field] = value.toBytes();
                  } else {
                    map[field] = value;
                  }
                }
                thumbnails.add(MaterialImage.fromMap(map));
              }
              print('从MySQL获取材料 ${material.id} 的缩略图数量: ${thumbnails.length}');
            }
          }
          
          result.add(PatientMaterialWithImages(
            material: material,
            images: thumbnails,
          ));
        } catch (e) {
          print('获取材料 ${material.id} 的缩略图时出错: $e');
          // 即使获取缩略图失败，也要添加材料（图片为空）
          result.add(PatientMaterialWithImages(
            material: material,
            images: [],
          ));
        }
      }
      
      print('最终返回材料数量: ${result.length}');
      return result;
    } catch (e) {
      print('获取患者材料及缩略图失败: $e');
      return [];
    }
  }

  // 确保数据库连接可用
  Future<void> _ensureDatabaseConnection() async {
    try {
      if (_dataSourceType == 'sqlite') {
        // 检查数据库连接状态
        if (_database == null || !_database!.isOpen) {
          print('SQLite数据库连接已关闭，需要重新设置连接');
          throw Exception('SQLite数据库连接已关闭，请重新设置数据库连接');
        }
      } else if (_dataSourceType == 'mysql') {
        // 检查MySQL连接状态
        if (_mysqlConnection == null) {
          print('MySQL数据库连接已关闭，需要重新设置连接');
          throw Exception('MySQL数据库连接已关闭，请重新设置数据库连接');
        }
      }
    } catch (e) {
      print('数据库连接检查失败: $e');
      throw Exception('数据库连接检查失败: $e');
    }
  }

  // =================== 患者材料同步方法 ===================

  /// 尝试将SQLite中的患者材料同步到MySQL（非阻塞操作）
  Future<void> _trySyncPatientMaterialToMySQL(PatientMaterial material, {required bool isUpdate}) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过患者材料同步(id=${material.id})');
          return;
        }

        if (isUpdate) {
          // 更新操作
          try {
            final result = await conn.query('''
              UPDATE patient_materials SET
                patient_id = ?, description = ?, created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              material.patientId,
              material.description,
              material.createdAt != null ? DateTimeFormatter.toDbString(material.createdAt!) : null,
              material.updatedAt != null ? DateTimeFormatter.toDbString(material.updatedAt!) : null,
              material.id,
            ]);
            print('成功更新MySQL患者材料(id=${material.id})，影响行数: ${result.affectedRows}');
          } catch (e) {
            print('更新MySQL患者材料(id=${material.id})时出错: $e');
          }
        } else {
          // 插入操作
          try {
            // 先检查是否已存在
            final existResult = await conn.query(
              'SELECT id FROM patient_materials WHERE id = ? LIMIT 1',
              [material.id],
            );

            if (existResult.isNotEmpty) {
              // 已存在，执行更新
              final result = await conn.query('''
                UPDATE patient_materials SET
                  patient_id = ?, description = ?, created_at = ?, updated_at = ?
                WHERE id = ?
              ''', [
                material.patientId,
                material.description,
                material.createdAt != null ? DateTimeFormatter.toDbString(material.createdAt!) : null,
                material.updatedAt != null ? DateTimeFormatter.toDbString(material.updatedAt!) : null,
                material.id,
              ]);
              print('MySQL中已存在患者材料，执行更新(id=${material.id})，影响行数: ${result.affectedRows}');
            } else {
              // 不存在，执行插入
              final result = await conn.query('''
                INSERT INTO patient_materials (id, patient_id, description, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?)
              ''', [
                material.id,
                material.patientId,
                material.description,
                material.createdAt != null ? DateTimeFormatter.toDbString(material.createdAt!) : null,
                material.updatedAt != null ? DateTimeFormatter.toDbString(material.updatedAt!) : null,
              ]);
              print('成功插入MySQL患者材料(id=${material.id})，插入ID: ${result.insertId}');
            }
          } catch (e) {
            print('同步MySQL患者材料(id=${material.id})时出错: $e');
          }
        }
      } catch (e) {
        print('患者材料同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除患者材料（非阻塞操作）
  Future<void> _trySyncDeletePatientMaterialToMySQL(int materialId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过患者材料删除同步(id=$materialId)');
          return;
        }

        // MySQL联表删除
        await conn.query('START TRANSACTION');
        try {
          // 先删除关联的图片
          final imageResult = await conn.query(
            'DELETE FROM material_images WHERE material_id = ?',
            [materialId],
          );
          
          // 再删除材料记录
          final materialResult = await conn.query(
            'DELETE FROM patient_materials WHERE id = ?',
            [materialId],
          );
          
          await conn.query('COMMIT');
          print('成功从MySQL删除患者材料(id=$materialId)，删除了 ${imageResult.affectedRows} 张图片和 ${materialResult.affectedRows} 条材料记录');
        } catch (e) {
          await conn.query('ROLLBACK');
          print('从MySQL删除患者材料(id=$materialId)时出错: $e');
        }
      } catch (e) {
        print('患者材料删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试将SQLite中的材料图片同步到MySQL（非阻塞操作）
  Future<void> _trySyncMaterialImageToMySQL(MaterialImage image) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过材料图片同步(id=${image.id})');
          return;
        }

        try {
          // 先检查是否已存在
          final existResult = await conn.query(
            'SELECT id FROM material_images WHERE id = ? LIMIT 1',
            [image.id],
          );

          if (existResult.isNotEmpty) {
            print('MySQL中已存在材料图片(id=${image.id})，跳过插入');
            return;
          }

          // 检查MySQL表结构是否支持缩略图
          final tableInfo = await conn.query('DESCRIBE material_images');
          final hasThumbnailSupport = tableInfo.any((row) => row[0] == 'thumbnail_data');
          
          if (hasThumbnailSupport) {
            // 支持缩略图的新表结构
            final result = await conn.query('''
              INSERT INTO material_images (id, material_id, image_data, thumbnail_data, image_type, file_size, thumbnail_size, original_name, created_at, has_thumbnail)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              image.id,
              image.materialId,
              image.imageData,
              image.thumbnailData,
              image.imageType,
              image.fileSize,
              image.thumbnailSize,
              image.originalName ?? '',
              DateTimeFormatter.toDbString(image.createdAt),
              image.hasThumbnail ? 1 : 0,
            ]);
            print('成功插入MySQL材料图片(id=${image.id})，插入ID: ${result.insertId}');
          } else {
            // 旧表结构，只保存基本字段
            final result = await conn.query('''
              INSERT INTO material_images (id, material_id, image_data, image_type, file_size, original_name, created_at)
              VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', [
              image.id,
              image.materialId,
              image.imageData,
              image.imageType,
              image.fileSize,
              image.originalName ?? '',
              DateTimeFormatter.toDbString(image.createdAt),
            ]);
            print('成功插入MySQL材料图片(id=${image.id})，插入ID: ${result.insertId}');
          }
        } catch (e) {
          print('同步MySQL材料图片(id=${image.id})时出错: $e');
        }
      } catch (e) {
        print('材料图片同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除材料图片（非阻塞操作）
  Future<void> _trySyncDeleteMaterialImageToMySQL(int imageId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过材料图片删除同步(id=$imageId)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM material_images WHERE id = ?',
            [imageId],
          );
          print('成功从MySQL删除材料图片(id=$imageId)，影响行数: ${result.affectedRows}');
        } catch (e) {
          print('从MySQL删除材料图片(id=$imageId)时出错: $e');
        }
      } catch (e) {
        print('材料图片删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试建立MySQL连接的辅助方法
  Future<MySqlConnection?> _tryEstablishMySQLConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mysqlJson = prefs.getString('mysqlSettings');
      Map<String, dynamic>? settings;

      if (mysqlJson != null && mysqlJson.isNotEmpty) {
        try {
          settings = Map<String, dynamic>.from(jsonDecode(mysqlJson));
          print('从 SharedPreferences mysqlSettings 读取 MySQL 配置');
        } catch (e) {
          print('解析 SharedPreferences 中 mysqlSettings 失败: $e');
          settings = null;
        }
      }

      // 如果没有整体 json 配置，回退到单项配置键（兼容旧版保存方式）
      if (settings == null) {
        final host = prefs.getString('mysqlHost') ?? '';
        if (host.isNotEmpty) {
          settings = {
            'host': host,
            'port': prefs.getString('mysqlPort') ?? '3306',
            'database': prefs.getString('mysqlDatabase') ?? '',
            'username': prefs.getString('mysqlUsername') ?? '',
            'password': prefs.getString('mysqlPassword') ?? '',
          };
          print('从 SharedPreferences 单独键(mysqlHost/mysqlPort/...) 读取 MySQL 配置');
        }
      }

      if (settings != null) {
        final host = settings['host'];
        final port = int.tryParse(settings['port']?.toString() ?? '3306') ?? 3306;
        final database = settings['database'];
        final username = settings['username'];
        final password = settings['password'];

        final conn = await MySqlConnection.connect(ConnectionSettings(
          host: host,
          port: port,
          db: database,
          user: username,
          password: password,
        ));

        // 强制使用 utf8mb4 字符集以避免中文/特殊字符乱码
        try {
          await conn.query("SET NAMES 'utf8mb4'");
          await conn.query("SET character_set_connection = 'utf8mb4'");
          await conn.query("SET character_set_results = 'utf8mb4'");
        } catch (e) {
          print('设置MySQL会话字符集失败: $e');
        }

        // 保存以便后续复用
        _mysqlConnection = conn;
        return conn;
      }
    } catch (e) {
      print('尝试建立MySQL连接失败: $e');
    }
    return null;
  }
}

/// 患者材料及其图片的组合类
class PatientMaterialWithImages {
  final PatientMaterial material;
  final List<MaterialImage> images;

  PatientMaterialWithImages({
    required this.material,
    required this.images,
  });
}

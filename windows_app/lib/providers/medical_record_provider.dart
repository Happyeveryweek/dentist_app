import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/patient.dart';
import '../models/patient_medical_record.dart';

import '../models/medical_record_template.dart';
import '../data_sources/medical_record_data_source.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../utils/datetime_formatter.dart';
import '../utils/medical_record_pdf_exporter.dart';
import '../utils/mysql_sync_connection_helper.dart';

/// 病历管理提供者
/// 负责处理所有与患者病历相关的数据库操作和状态管理
/// 已升级为数据源架构 + 缓存机制 + MySQL动态连接获取
class MedicalRecordProvider extends ChangeNotifier {
  // 实例标识符，用于调试
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  // 数据源实例
  SqliteMedicalRecordDataSource? _sqliteDataSource;
  MySqlMedicalRecordDataSource? _mysqlDataSource;
  
  // 用户权限提供者引用
  UserProvider? _userProvider;
  
  // 缓存机制（病历记录缓存）
  Map<int, List<PatientMedicalRecord>> _cachedMedicalRecords = {};
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 15);
  
  // 模板数据缓存（20分钟有效期）
  Map<String, List<MedicalRecordTemplate>> _cachedTemplates = {};
  DateTime? _lastTemplateCacheTime;
  static const Duration _templateCacheValidDuration = Duration(minutes: 20);
  
  // 连接状态
  bool _isConnected = true;
  String? _lastError;
  
  // 数据库提供者引用（用于MySQL动态连接获取）
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
  
  // 加载状态
  bool _isLoading = false;
  
  // 刷新标志
  bool _templatesNeedRefresh = false;
  
  // Getters
  bool get initialized => _currentDataSource != null || _database != null || _mysqlConnection != null;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  bool get isLoading => _isLoading;
  String get dataSourceType => _effectiveDataSourceType ?? _dataSourceType;
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  bool get templatesNeedRefresh => _templatesNeedRefresh;
  bool get hasValidTemplateCache => _isTemplateCacheValid();
  DateTime? get lastTemplateCacheTime => _lastTemplateCacheTime;
  int get cachedTemplatesCount => _cachedTemplates.values.fold(0, (sum, list) => sum + list.length);
  
  // 检查数据源是否真正可用
  bool get isDataSourceReady {
    final dataSource = _currentDataSource;
    final ready = dataSource != null && _effectiveDataSourceType != null;
    print('MedicalRecordProvider.isDataSourceReady: $ready (dataSource=${dataSource != null}, effectiveType=$_effectiveDataSourceType)');
    return ready;
  }
  
  // 获取当前数据源
  MedicalRecordDataSource? get _currentDataSource {
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
  MedicalRecordProvider({
    UserProvider? userProvider,
    User? currentUser,
  }) {
    _userProvider = userProvider;
    _currentUser = currentUser;
    print('MedicalRecordProvider 实例创建: $_instanceId');
  }

  // 同步初始化方法（立即设置数据源）
  void initializeFromDatabaseSync(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    UserProvider? userProvider,
  }) {
    print('MedicalRecordProvider($_instanceId).initializeFromDatabaseSync: 开始同步初始化');
    
    _databaseProvider = dbProvider;
    _userProvider = userProvider;
    
    // 确定要使用的数据源类型
    String dbType = 'sqlite';
    
    // 病历管理始终跟随患者管理的数据源配置
    if (dataSourceMode == 'modular' && 
        moduleDataSources != null && 
        moduleDataSources.containsKey('patients')) {
      dbType = moduleDataSources['patients']!;
      print('MedicalRecordProvider($_instanceId): 跟随患者模块配置: patients -> $dbType');
    } else {
      // 否则使用全局配置
      dbType = dbProvider.dataSourceType ?? 'sqlite';
      print('MedicalRecordProvider($_instanceId): 使用全局配置: $dbType');
    }
    
    _effectiveDataSourceType = dbType;
    
    // 获取当前用户信息（优先从UserProvider获取，其次从_currentUser）
    final currentUser = _userProvider?.currentUser ?? _currentUser;
    final doctorName = currentUser?.doctor;
    final isAdmin = currentUser?.role == 'admin';
    
    // 立即初始化数据源
    if (dbType == 'sqlite') {
      final database = dbProvider.database;
      print('MedicalRecordProvider($_instanceId): 初始化SQLite数据源，database=${database != null ? "存在" : "null"}');
      if (database != null) {
        _sqliteDataSource = SqliteMedicalRecordDataSource(
          database,
          doctorName: doctorName,
          isAdmin: isAdmin ?? false,
        );
        _database = database; // 保持向后兼容
        _isConnected = true;
        _clearError();
        print('MedicalRecordProvider($_instanceId): SQLite数据源初始化完成');
        
        // 异步检查和创建表
        _ensureTablesExistAsync(database);
      } else {
        print('MedicalRecordProvider($_instanceId): SQLite数据库连接不可用');
        _setError('SQLite数据库连接不可用');
      }
    } else if (dbType == 'mysql') {
      print('MedicalRecordProvider($_instanceId): 初始化MySQL数据源');
      _mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
        () async {
          final conn = await _currentMysqlConnection;
          return conn;
        },
        doctorName: doctorName,
        isAdmin: isAdmin ?? false,
        reconnectCallback: () async {
          if (dbProvider != null) {
            try {
              await dbProvider.initializeMySQL();
              print('✅ MedicalRecordProvider: MySQL重连成功');
            } catch (e) {
              print('❌ MedicalRecordProvider: MySQL重连失败: $e');
            }
          }
        },
      );
      _mysqlConnection = dbProvider.mysqlConnection; // 保持向后兼容
      _isConnected = true;
      _clearError();
      print('MedicalRecordProvider($_instanceId): MySQL数据源初始化完成');
    }
    
    // 清除缓存，强制重新加载
    clearCache();
    
    print('MedicalRecordProvider($_instanceId).initializeFromDatabaseSync: 同步初始化完成');
  }

  // 异步检查和创建表
  Future<void> _ensureTablesExistAsync(Database database) async {
    try {
      await _ensureTablesExist(database);
      // 初始化默认模板数据（如果需要）
      await _initializeDefaultTemplatesIfNeeded();
    } catch (e) {
      print('MedicalRecordProvider($_instanceId): 异步表检查失败: $e');
    }
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
      
      // 病历管理始终跟随患者管理的数据源配置
      if (dataSourceMode == 'modular' && 
          moduleDataSources != null && 
          moduleDataSources.containsKey('patients')) {
        dbType = moduleDataSources['patients']!;
        print('MedicalRecordProvider跟随患者模块配置: patients -> $dbType');
      } else {
        // 否则使用全局配置
        dbType = dbProvider.dataSourceType ?? 'sqlite';
        print('MedicalRecordProvider使用全局配置: $dbType');
      }
      
      _effectiveDataSourceType = dbType;
      
      // 获取当前用户信息（优先从UserProvider获取，其次从_currentUser）
      final currentUser = _userProvider?.currentUser ?? _currentUser;
      final doctorName = currentUser?.doctor;
      final isAdmin = currentUser?.role == 'admin';
      
      // 一次性初始化正确的数据源
      if (dbType == 'sqlite') {
        final database = dbProvider.database;
        print('MedicalRecordProvider: 初始化SQLite数据源，database=${database != null ? "存在" : "null"}');
        if (database != null) {
          // 检查并创建必要的表
          await _ensureTablesExist(database);
          
          _sqliteDataSource = SqliteMedicalRecordDataSource(
            database,
            doctorName: doctorName,
            isAdmin: isAdmin ?? false,
          );
          _database = database; // 保持向后兼容
          _isConnected = true;
          _clearError();
          print('MedicalRecordProvider: SQLite数据源初始化完成，_effectiveDataSourceType=$_effectiveDataSourceType');
        } else {
          print('MedicalRecordProvider: SQLite数据库连接不可用');
          _setError('SQLite数据库连接不可用');
        }
      } else if (dbType == 'mysql') {
        print('MedicalRecordProvider: 初始化MySQL数据源');
        _mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
          () async {
            final conn = await _currentMysqlConnection;
            return conn;
          },
          doctorName: doctorName,
          isAdmin: isAdmin ?? false,
          reconnectCallback: () async {
            if (dbProvider != null) {
              try {
                await dbProvider.initializeMySQL();
                print('✅ MedicalRecordProvider: MySQL重连成功');
              } catch (e) {
                print('❌ MedicalRecordProvider: MySQL重连失败: $e');
              }
            }
          },
        );
        _mysqlConnection = dbProvider.mysqlConnection; // 保持向后兼容
        
        // 测试MySQL连接
        final testResult = await _testMySqlConnection();
        if (testResult) {
          print('MedicalRecordProvider: MySQL数据源初始化完成，_effectiveDataSourceType=$_effectiveDataSourceType');
        } else {
          print('MedicalRecordProvider: MySQL连接测试失败，但数据源已初始化，_effectiveDataSourceType=$_effectiveDataSourceType');
        }
      }
      
      // 清除缓存，强制重新加载
      clearCache();
      
      // 初始化默认模板数据（如果需要）
      _initializeDefaultTemplatesIfNeeded();
      
    } catch (e) {
      print('MedicalRecordProvider初始化失败: $e');
      _setError('初始化失败: $e');
    }
  }
  
  /// 如果需要，初始化默认模板数据
  Future<void> _initializeDefaultTemplatesIfNeeded() async {
    try {
      // 检查是否已有模板数据
      final hasData = await hasTemplateData();
      if (!hasData) {
        await initializeDefaultTemplates();
      }
    } catch (e) {
      print('MedicalRecordProvider: 初始化默认模板时出错: $e');
      // 不抛出异常，避免影响整体初始化
    }
  }
  

  
  // 缓存管理
  bool _isCacheValid() {
    return _lastCacheTime != null && 
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  bool _isTemplateCacheValid() {
    return _lastTemplateCacheTime != null && 
           DateTime.now().difference(_lastTemplateCacheTime!) < _templateCacheValidDuration;
  }
  
  void _updateCache(int patientId, List<PatientMedicalRecord> records) {
    _cachedMedicalRecords[patientId] = records;
    _lastCacheTime = DateTime.now();
  }
  

  
  void _updateTemplateCache(String category, List<MedicalRecordTemplate> templates) {
    _cachedTemplates[category] = templates;
    _lastTemplateCacheTime = DateTime.now();
  }
  
  void clearCache() {
    _cachedMedicalRecords.clear();
    _lastCacheTime = null;
    print('MedicalRecordProvider: 缓存已清除');
  }
  
  void clearTemplateCache() {
    _cachedTemplates.clear();
    _lastTemplateCacheTime = null;
  }
  
  void clearAllCache() {
    clearCache();
    clearTemplateCache();
  }
  
  // 错误处理
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
    print('MedicalRecordProvider错误: $error');
  }
  
  void _clearError() {
    _lastError = null;
    _isConnected = true;
  }

  /// 确保必要的表存在
  Future<void> _ensureTablesExist(Database database) async {
    try {
      
      // 检查medical_record_templates表是否存在
      final result = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='medical_record_templates'"
      );
      
      if (result.isEmpty) {
        print('MedicalRecordProvider: medical_record_templates表不存在，开始创建...');
        
        // 创建表的SQL
        const createTableSql = '''
          CREATE TABLE medical_record_templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            category VARCHAR(50) NOT NULL,
            name VARCHAR(100) NOT NULL,
            parent_name VARCHAR(100),
            description TEXT,
            is_active INTEGER NOT NULL DEFAULT 1,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''';
        
        await database.execute(createTableSql);
        print('MedicalRecordProvider: medical_record_templates表创建成功');
      } else {
        print('MedicalRecordProvider: medical_record_templates表已存在');
      }
      
      // 检查其他必要的表
      final tables = {
        'patient_medical_records': '''
          CREATE TABLE patient_medical_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            record_date TEXT NOT NULL,
            chief_complaint TEXT,
            present_illness TEXT,
            systemic_disease_history TEXT,
            oral_disease_history TEXT,
            allergy_history TEXT,
            dental_diseases TEXT,
            oral_examination TEXT,
            selected_dental_condition_date TEXT,
            diagnosis TEXT,
            treatment_plan TEXT,
            notes TEXT,
            doctor_name VARCHAR(100),
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients (id)
          )
        ''',

      };
      
      for (final entry in tables.entries) {
        final tableName = entry.key;
        final createSql = entry.value;
        
        final result = await database.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'"
        );
        
        if (result.isEmpty) {
          print('MedicalRecordProvider: $tableName表不存在，开始创建...');
          await database.execute(createSql);
          print('MedicalRecordProvider: $tableName表创建成功');
        }
      }
    } catch (e) {
      print('MedicalRecordProvider: 创建表时出错: $e');
      // 不抛出异常，让应用继续运行
    }
  }
  
  // MySQL连接测试
  Future<bool> _testMySqlConnection() async {
    if (_currentMysqlConnection == null) return false;
    
    try {
      await _currentMysqlConnection!.query('SELECT 1').timeout(
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
  
  // 标记模板刷新
  void markTemplatesNeedRefresh() {
    _templatesNeedRefresh = true;
    notifyListeners();
  }
  
  // 重置模板刷新标志
  void resetTemplatesRefreshFlag() {
    _templatesNeedRefresh = false;
  }
  
  // 设置数据库连接（向后兼容）
  Future<void> setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
  }) async {
    print('MedicalRecordProvider: setDatabaseConnection被调用，但已升级为数据源架构');
    // 这个方法保留用于向后兼容，但实际初始化应该使用initializeFromDatabase
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) _currentUser = currentUser;
  }
  
  // 设置用户权限提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    // 重新初始化数据源以应用权限
    if (_sqliteDataSource != null) {
      _reinitializeDataSourcesWithUser();
      // 清除缓存，强制重新加载数据
      clearCache();
    }
  }
  
  // 重新初始化数据源以应用新的用户信息
  void _reinitializeDataSourcesWithUser() {
    // 优先从UserProvider获取用户信息
    final currentUser = _userProvider?.currentUser ?? _currentUser;
    final doctorName = currentUser?.doctor;
    final isAdmin = currentUser?.role == 'admin';
    
    if (_effectiveDataSourceType == 'sqlite' && _databaseProvider?.database != null) {
      _sqliteDataSource = SqliteMedicalRecordDataSource(
        _databaseProvider!.database!,
        doctorName: doctorName,
        isAdmin: isAdmin ?? false,
      );
      print('MedicalRecordProvider: SQLite数据源权限更新');
    } else if (_effectiveDataSourceType == 'mysql' && _databaseProvider?.mysqlConnection != null) {
      _mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
        () async {
          final conn = await _currentMysqlConnection;
          if (conn == null) throw Exception('MySQL连接不可用');
          return conn;
        },
        doctorName: doctorName,
        isAdmin: isAdmin ?? false,
        reconnectCallback: () async {
          if (_databaseProvider != null) {
            try {
              await _databaseProvider.initializeMySQL();
              print('✅ MedicalRecordProvider: MySQL重连成功');
            } catch (e) {
              print('❌ MedicalRecordProvider: MySQL重连失败: $e');
            }
          }
        },
      );
      print('MedicalRecordProvider: MySQL数据源权限更新');
    }
  }
  
  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
    // 如果已经有数据源，需要重新初始化以应用新的用户信息
    if (_sqliteDataSource != null) {
      _reinitializeDataSourcesWithUser();
      // 清除缓存，强制重新加载数据
      clearCache();
    }
  }

  // 更新模块数据源配置
  void updateModuleDataSources(Map<String, String> moduleDataSources) {
    print('MedicalRecordProvider.updateModuleDataSources - 模块数据源配置已更新: $moduleDataSources');
    
    // 如果病历模块的数据源类型发生变化，需要重新初始化
    if (_databaseProvider != null) {
      // 病历管理使用与患者管理相同的数据源
      final newDataSourceType = moduleDataSources['patients'] ?? 'sqlite';
      if (newDataSourceType != _effectiveDataSourceType) {
        print('病历模块数据源类型变更: $_effectiveDataSourceType -> $newDataSourceType');
        
        initializeFromDatabase(
          _databaseProvider,
          moduleDataSources: moduleDataSources,
          dataSourceMode: 'modular',
          userProvider: _userProvider,
        );
      }
    }
  }
  
  // 数据验证
  String? _validateMedicalRecord(PatientMedicalRecord record) {
    if (record.patientId <= 0) {
      return '患者ID无效';
    }
    
    if (record.recordDate.isAfter(DateTime.now().add(Duration(days: 1)))) {
      return '病历日期不能是未来日期';
    }
    
    if (record.chiefComplaint.trim().isEmpty) {
      return '主诉不能为空';
    }
    
    if (record.doctorName.trim().isEmpty) {
      return '医生姓名不能为空';
    }
    
    return null; // 验证通过
  }
  

  
  // 设置加载状态
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      // 使用 WidgetsBinding.instance.addPostFrameCallback 来避免在 build 期间调用 notifyListeners
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
  // ================ 病历CRUD操作方法 ===================
  
  /// 获取患者的所有病历记录
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId, {bool forceRefresh = false}) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      // 检查缓存
      if (!forceRefresh && _isCacheValid() && _cachedMedicalRecords.containsKey(patientId)) {
                return _cachedMedicalRecords[patientId]!;
      }

      // 从数据源获取数据
            final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final records = await dataSource.getPatientMedicalRecords(patientId);
            // 更新缓存
      _updateCache(patientId, records);
      
      _clearError();
      return records;
    } catch (e) {
      print('获取患者病历记录时出错: $e');
      _setError('获取病历记录失败: $e');
      
      // 优雅降级：如果有缓存数据，返回缓存
      if (_cachedMedicalRecords.containsKey(patientId)) {
        print('MedicalRecordProvider: 连接失败，返回缓存数据');
        return _cachedMedicalRecords[patientId]!;
      }
      
      return [];
    } finally {
      _setLoading(false);
    }
  }
  
  /// 根据ID获取病历记录
  Future<PatientMedicalRecord?> getMedicalRecordById(int id) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      print('MedicalRecordProvider: 获取病历记录，ID: $id');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final record = await dataSource.getMedicalRecordById(id);
      print('MedicalRecordProvider: ${record != null ? '找到病历记录' : '未找到病历记录'}');
      
      _clearError();
      return record;
    } catch (e) {
      print('根据ID获取病历记录时出错: $e');
      _setError('获取病历记录失败: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 创建新的病历记录
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      // 数据验证
      final validationError = _validateMedicalRecord(record);
      if (validationError != null) {
        throw Exception('数据验证失败: $validationError');
      }
      
      // 权限检查和自动设置创建医生
      final currentUser = _userProvider?.currentUser ?? _currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }
      
      // 自动设置创建医生字段为当前登录医生
      final recordWithCreator = record.copyWith(
        createdByDoctor: currentUser.doctor ?? currentUser.username,
      );
      
      // 非管理员用户只能创建自己的病历记录
      if (currentUser.role != 'admin' && 
          currentUser.doctor != null && 
          currentUser.doctor!.isNotEmpty &&
          recordWithCreator.doctorName != currentUser.doctor) {
        throw Exception('权限不足：只能创建自己的病历记录');
      }
      
      print('MedicalRecordProvider: 创建病历记录，患者ID: ${record.patientId}');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final id = await dataSource.createMedicalRecord(recordWithCreator);
      
      if (id > 0) {
        print('MedicalRecordProvider: 病历记录创建成功，ID: $id');
        
        // 清除相关缓存
        _cachedMedicalRecords.remove(recordWithCreator.patientId);
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
          print('MedicalRecordProvider: SQLite病历记录创建成功，开始同步到MySQL: 病历ID=$id');
          _trySyncMedicalRecordToMySQL(recordWithCreator.copyWith(id: id), isUpdate: false);
        }
        
        _clearError();
        notifyListeners();
      } else {
        throw Exception('创建病历记录失败');
      }
      
      return id;
    } catch (e) {
      print('创建病历记录时出错: $e');
      _setError('创建病历记录失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 更新病历记录
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      // 数据验证
      final validationError = _validateMedicalRecord(record);
      if (validationError != null) {
        throw Exception('数据验证失败: $validationError');
      }
      
      // 权限检查
      final currentUser = _userProvider?.currentUser ?? _currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }
      
      // 非管理员用户只能更新自己创建的病历记录
      if (currentUser.role != 'admin' && 
          currentUser.doctor != null && 
          currentUser.doctor!.isNotEmpty) {
        // 先获取原记录检查权限
        final originalRecord = await getMedicalRecordById(record.id!);
        if (originalRecord == null) {
          throw Exception('病历记录不存在');
        }
        
        // 检查是否是自己创建的病历记录
        final createdByDoctor = originalRecord.createdByDoctor ?? originalRecord.doctorName;
        if (createdByDoctor != currentUser.doctor) {
          throw Exception('权限不足：只能更新自己创建的病历记录');
        }
      }
      
      print('MedicalRecordProvider: 更新病历记录，ID: ${record.id}');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final success = await dataSource.updateMedicalRecord(record);
      
      if (success) {
        print('MedicalRecordProvider: 病历记录更新成功');
        
        // 清除相关缓存
        _cachedMedicalRecords.remove(record.patientId);
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
          print('MedicalRecordProvider: SQLite病历记录更新成功，开始同步到MySQL: 病历ID=${record.id}');
          _trySyncMedicalRecordToMySQL(record, isUpdate: true);
        }
        
        _clearError();
        notifyListeners();
      } else {
        throw Exception('更新病历记录失败');
      }
      
      return success;
    } catch (e) {
      print('更新病历记录时出错: $e');
      _setError('更新病历记录失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 删除病历记录
  Future<bool> deleteMedicalRecord(int id) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      // 权限检查
      final currentUser = _userProvider?.currentUser ?? _currentUser;
      if (currentUser == null) {
        throw Exception('用户未登录');
      }
      
      // 非管理员用户只能删除自己创建的病历记录
      if (currentUser.role != 'admin' && 
          currentUser.doctor != null && 
          currentUser.doctor!.isNotEmpty) {
        // 先获取原记录检查权限
        final originalRecord = await getMedicalRecordById(id);
        if (originalRecord == null) {
          throw Exception('病历记录不存在');
        }
        
        // 检查是否是自己创建的病历记录
        final createdByDoctor = originalRecord.createdByDoctor ?? originalRecord.doctorName;
        if (createdByDoctor != currentUser.doctor) {
          throw Exception('权限不足：只能删除自己创建的病历记录');
        }
      }
      
      print('MedicalRecordProvider: 删除病历记录，ID: $id');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      // 先获取记录信息用于清除缓存
      final recordToDelete = await dataSource.getMedicalRecordById(id);
      
      final success = await dataSource.deleteMedicalRecord(id);
      
      if (success) {
        print('MedicalRecordProvider: 病历记录删除成功');
        
        // 清除相关缓存
        if (recordToDelete != null) {
          _cachedMedicalRecords.remove(recordToDelete.patientId);
        }

        
        _clearError();
        notifyListeners();
      } else {
        throw Exception('删除病历记录失败');
      }
      
      return success;
    } catch (e) {
      print('删除病历记录时出错: $e');
      _setError('删除病历记录失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 搜索病历记录
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query, {int? patientId}) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    if (query.trim().isEmpty) {
      return [];
    }

    try {
      _setLoading(true);
      
      print('MedicalRecordProvider: 搜索病历记录，关键词: $query');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final records = await dataSource.searchMedicalRecords(query, patientId: patientId);
            _clearError();
      return records;
    } catch (e) {
      print('搜索病历记录时出错: $e');
      _setError('搜索病历记录失败: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }
  
  /// 获取病历记录数量
  Future<int> getMedicalRecordsCount(int patientId) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final count = await dataSource.getMedicalRecordsCount(patientId);
      _clearError();
      return count;
    } catch (e) {
      print('获取病历记录数量时出错: $e');
      _setError('获取病历记录数量失败: $e');
      return 0;
    }
  }
  
  /// 分页获取病历记录
  Future<Map<String, dynamic>> getMedicalRecordsPage({
    required int patientId,
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
  }) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      print('MedicalRecordProvider: 分页获取病历记录，患者ID: $patientId, 页码: $page');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final result = await dataSource.getMedicalRecordsPage(
        patientId: patientId,
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        sortField: sortField,
        sortAscending: sortAscending,
      );
      
      print('MedicalRecordProvider: 分页查询成功，总数: ${result['totalCount']}, 当前页: ${result['records'].length}');
      
      _clearError();
      return result;
    } catch (e) {
      print('分页获取病历记录时出错: $e');
      _setError('分页获取病历记录失败: $e');
      return {
        'records': <PatientMedicalRecord>[],
        'totalCount': 0,
        'totalPages': 0,
        'currentPage': page,
      };
    } finally {
      _setLoading(false);
    }
  }


  

  

  

  

  

  

  

  
  // =================== 权限检查辅助方法 ===================
  
  /// 检查病历记录操作权限
  Future<void> _checkMedicalRecordPermission(int recordId) async {
    final currentUser = _userProvider?.currentUser ?? _currentUser;
    if (currentUser == null) {
      throw Exception('用户未登录');
    }
    
    // 管理员拥有所有权限
    if (currentUser.role == 'admin') {
      return;
    }
    
    // 非管理员用户需要检查是否是自己创建的病历记录
    if (currentUser.doctor != null && currentUser.doctor!.isNotEmpty) {
      final record = await getMedicalRecordById(recordId);
      if (record == null) {
        throw Exception('病历记录不存在');
      }
      
      // 检查是否是自己创建的病历记录
      final createdByDoctor = record.createdByDoctor ?? record.doctorName;
      if (createdByDoctor != currentUser.doctor) {
        throw Exception('权限不足：只能操作自己创建的病历记录');
      }
    } else {
      throw Exception('权限不足：用户没有医生权限');
    }
  }
  
  // =================== 模板管理方法 ===================
  
  /// 根据类别获取模板列表
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category, {bool forceRefresh = false}) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      // 检查缓存
      if (!forceRefresh && _isTemplateCacheValid() && _cachedTemplates.containsKey(category)) {
                return _cachedTemplates[category]!;
      }

      // 从数据源获取数据
            final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final templates = await dataSource.getTemplatesByCategory(category);
            // 更新缓存
      _updateTemplateCache(category, templates);
      
      _clearError();
      return templates;
    } catch (e) {
      print('获取模板列表时出错: $e');
      _setError('获取模板列表失败: $e');
      
      // 优雅降级：如果有缓存数据，返回缓存
      if (_cachedTemplates.containsKey(category)) {
        print('MedicalRecordProvider: 连接失败，返回缓存数据');
        return _cachedTemplates[category]!;
      }
      
      return [];
    } finally {
      _setLoading(false);
    }
  }
  
  /// 根据ID获取模板
  Future<MedicalRecordTemplate?> getTemplateById(int id) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
            final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final template = await dataSource.getTemplateById(id);
      print('MedicalRecordProvider: ${template != null ? '找到模板' : '未找到模板'}');
      
      _clearError();
      return template;
    } catch (e) {
      print('根据ID获取模板时出错: $e');
      _setError('获取模板失败: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 创建新模板
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      // 数据验证
      if (template.category.trim().isEmpty) {
        throw Exception('模板类别不能为空');
      }
      
      if (template.name.trim().isEmpty) {
        throw Exception('模板名称不能为空');
      }
      
            final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final id = await dataSource.createTemplate(template);
      
      if (id > 0) {
                // 清除相关缓存
        _cachedTemplates.remove(template.category);
        markTemplatesNeedRefresh();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
          print('MedicalRecordProvider: SQLite模板创建成功，开始同步到MySQL: 模板ID=$id');
          _trySyncTemplateToMySQL(template.copyWith(id: id), isUpdate: false);
        }
        
        _clearError();
        notifyListeners();
      } else {
        throw Exception('创建模板失败');
      }
      
      return id;
    } catch (e) {
      print('创建模板时出错: $e');
      _setError('创建模板失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 更新模板
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      // 数据验证
      if (template.id == null) {
        throw Exception('更新模板时必须提供ID');
      }
      
      if (template.category.trim().isEmpty) {
        throw Exception('模板类别不能为空');
      }
      
      if (template.name.trim().isEmpty) {
        throw Exception('模板名称不能为空');
      }
      
            final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final success = await dataSource.updateTemplate(template);
      
      if (success) {
                // 清除相关缓存
        _cachedTemplates.remove(template.category);
        markTemplatesNeedRefresh();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
          print('MedicalRecordProvider: SQLite模板更新成功，开始同步到MySQL: 模板ID=${template.id}');
          _trySyncTemplateToMySQL(template, isUpdate: true);
        }
        
        _clearError();
        notifyListeners();
      } else {
        throw Exception('更新模板失败');
      }
      
      return success;
    } catch (e) {
      print('更新模板时出错: $e');
      _setError('更新模板失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 删除模板
  Future<bool> deleteTemplate(int id) async {
    print('🚀🚀🚀 MedicalRecordProvider($_instanceId).deleteTemplate: 开始删除模板ID: $id');
    
    if (!initialized) {
      print('🚀🚀🚀 数据源未初始化');
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        print('🚀🚀🚀 当前数据源为null，_effectiveDataSourceType=$_effectiveDataSourceType');
        print('🚀🚀🚀 _sqliteDataSource=${_sqliteDataSource != null ? "存在" : "null"}');
        print('🚀🚀🚀 _mysqlDataSource=${_mysqlDataSource != null ? "存在" : "null"}');
        throw Exception('数据源未初始化');
      }
      
      print('🚀🚀🚀 使用数据源类型: $_effectiveDataSourceType');
      print('🚀🚀🚀 数据源实例: ${dataSource.runtimeType}');
      
      // 先获取模板信息用于清除缓存
      final templateToDelete = await dataSource.getTemplateById(id);
      print('🚀🚀🚀 要删除的模板: ${templateToDelete?.name} (ID: ${templateToDelete?.id})');
      
      if (templateToDelete == null) {
        print('🚀🚀🚀 错误：找不到要删除的模板，ID: $id');
        return false;
      }
      
      print('🚀🚀🚀 调用数据源删除方法...');
      final success = await dataSource.deleteTemplate(id);
      print('🚀🚀🚀 数据源删除结果: $success');
      
      if (success) {
        print('🚀🚀🚀 删除成功，清除缓存');
        clearTemplateCache();
        markTemplatesNeedRefresh();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
          print('MedicalRecordProvider: SQLite模板删除成功，开始同步删除到MySQL: 模板ID=$id');
          _trySyncDeleteTemplateToMySQL(id, templateToDelete.name);
        }
        
        _clearError();
        notifyListeners();
        print('🚀🚀🚀 删除操作完成');
      } else {
        print('🚀🚀🚀 数据源返回删除失败');
        throw Exception('删除模板失败');
      }
      
      return success;
    } catch (e) {
      print('🚀🚀🚀 删除模板时出错: $e');
      _setError('删除模板失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 初始化默认模板
  Future<bool> initializeDefaultTemplates() async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      print('MedicalRecordProvider: 初始化默认模板');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final success = await dataSource.initializeDefaultTemplates();
      
      if (success) {
        print('MedicalRecordProvider: 默认模板初始化成功');
        
        // 清除所有模板缓存
        clearTemplateCache();
        
        _clearError();
        notifyListeners();
      } else {
        throw Exception('初始化默认模板失败');
      }
      
      return success;
    } catch (e) {
      print('初始化默认模板时出错: $e');
      _setError('初始化默认模板失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 检查是否有模板数据
  Future<bool> hasTemplateData() async {
    print('MedicalRecordProvider($_instanceId).hasTemplateData: 开始检查');
    
    if (!initialized) {
      print('MedicalRecordProvider($_instanceId).hasTemplateData: 数据源未初始化');
      throw Exception('数据源未初始化');
    }

    try {
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        print('MedicalRecordProvider($_instanceId).hasTemplateData: 当前数据源为null，_effectiveDataSourceType=$_effectiveDataSourceType');
        throw Exception('数据源未初始化');
      }
      
      print('MedicalRecordProvider($_instanceId).hasTemplateData: 使用数据源类型: $_effectiveDataSourceType');
      final hasData = await dataSource.hasTemplateData();
      print('MedicalRecordProvider($_instanceId).hasTemplateData: 检查结果: $hasData');
      _clearError();
      return hasData;
    } catch (e) {
      print('MedicalRecordProvider($_instanceId).hasTemplateData: 检查模板数据时出错: $e');
      _setError('检查模板数据失败: $e');
      return false;
    }
  }
  
  /// 测试数据源连接（调试用）
  Future<void> testDataSourceConnection() async {
    print('MedicalRecordProvider($_instanceId).testDataSourceConnection: 开始测试');
    
    try {
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        print('MedicalRecordProvider($_instanceId).testDataSourceConnection: 数据源为null');
        return;
      }
      
      // 测试查询所有模板
      final allTemplates = await dataSource.getTemplatesByCategory('systemic_disease');
      print('MedicalRecordProvider($_instanceId).testDataSourceConnection: 查询到 ${allTemplates.length} 个全身疾病模板');
      
      if (allTemplates.isNotEmpty) {
        print('MedicalRecordProvider($_instanceId).testDataSourceConnection: 第一个模板: ${allTemplates.first.name} (ID: ${allTemplates.first.id})');
      }
      
    } catch (e) {
      print('MedicalRecordProvider($_instanceId).testDataSourceConnection: 测试失败: $e');
    }
  }
  
  /// 加载模板数据（按类别）
  Future<void> loadTemplateData(String category) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      print('MedicalRecordProvider: 加载模板数据，类别: $category');
      
      // 强制刷新该类别的模板数据
      await getTemplatesByCategory(category, forceRefresh: true);
      
      print('MedicalRecordProvider: 模板数据加载完成');
      _clearError();
    } catch (e) {
      print('加载模板数据时出错: $e');
      _setError('加载模板数据失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 获取疾病选项（供病历表单使用）
  Future<Map<String, List<String>>> getDiseaseOptions(String category) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      // 强制刷新模板数据，不使用缓存
      final templates = await dataSource.getTemplatesByCategory(category);
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
      
      _clearError();
      return options;
    } catch (e) {
      print('获取疾病选项时出错: $e');
      _setError('获取疾病选项失败: $e');
      return {};
    }
  }
  
  /// 搜索模板
  Future<List<MedicalRecordTemplate>> searchTemplates(String category, String query) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
            final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final templates = await dataSource.searchTemplates(category, query);
            _clearError();
      return templates;
    } catch (e) {
      print('搜索模板时出错: $e');
      _setError('搜索模板失败: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }
  
  /// 检查模板是否有关联记录
  Future<bool> hasRelatedRecords(int templateId) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final hasRelated = await dataSource.hasRelatedRecords(templateId);
      _clearError();
      return hasRelated;
    } catch (e) {
      print('检查模板关联记录时出错: $e');
      _setError('检查模板关联记录失败: $e');
      return false;
    }
  }
  
  /// 获取所有类别的模板数据（用于初始化）
  Future<Map<String, List<MedicalRecordTemplate>>> getAllTemplates({bool forceRefresh = false}) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      final Map<String, List<MedicalRecordTemplate>> allTemplates = {};
      
      // 获取所有类别的模板
      for (final category in MedicalRecordTemplateCategory.all) {
        final templates = await getTemplatesByCategory(category, forceRefresh: forceRefresh);
        allTemplates[category] = templates;
      }
      
      _clearError();
      return allTemplates;
    } catch (e) {
      print('获取所有模板时出错: $e');
      _setError('获取所有模板失败: $e');
      return {};
    } finally {
      _setLoading(false);
    }
  }
  
  /// 批量创建模板
  Future<List<int>> createTemplates(List<MedicalRecordTemplate> templates) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    if (templates.isEmpty) {
      return [];
    }

    try {
      _setLoading(true);
      
      final List<int> createdIds = [];
      final Set<String> affectedCategories = {};
      
      for (final template in templates) {
        final id = await createTemplate(template);
        createdIds.add(id);
        affectedCategories.add(template.category);
      }
      
      // 清除受影响类别的缓存
      for (final category in affectedCategories) {
        _cachedTemplates.remove(category);
      }
      
            _clearError();
      notifyListeners();
      
      return createdIds;
    } catch (e) {
      print('批量创建模板时出错: $e');
      _setError('批量创建模板失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
  
  /// 获取主疾病类型（没有父级的模板）
  Future<List<MedicalRecordTemplate>> getMainDiseaseTypes(String category) async {
    final templates = await getTemplatesByCategory(category);
    return templates.where((template) => template.isMainType).toList();
  }
  
  /// 获取子疾病类型（有父级的模板）
  Future<List<MedicalRecordTemplate>> getSubDiseaseTypes(String category, String parentName) async {
    final templates = await getTemplatesByCategory(category);
    return templates.where((template) => 
      template.isSubType && template.parentName == parentName
    ).toList();
  }

  /// 获取指定医生的病历记录
  Future<List<PatientMedicalRecord>> getDoctorMedicalRecords(String doctorName, {int? patientId}) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      _setLoading(true);
      
      print('MedicalRecordProvider: 获取医生病历记录，医生: $doctorName, 患者ID: $patientId');
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final records = await dataSource.getDoctorMedicalRecords(doctorName, patientId: patientId);
            _clearError();
      return records;
    } catch (e) {
      print('获取医生病历记录时出错: $e');
      _setError('获取医生病历记录失败: $e');
      return [];
    } finally {
      _setLoading(false);
    }
  }

  /// 获取指定医生的病历记录数量
  Future<int> getDoctorMedicalRecordsCount(String doctorName, {int? patientId}) async {
    if (!initialized) {
      throw Exception('数据源未初始化');
    }

    try {
      final dataSource = _currentDataSource;
      if (dataSource == null) {
        throw Exception('数据源未初始化');
      }
      
      final count = await dataSource.getDoctorMedicalRecordsCount(doctorName, patientId: patientId);
      _clearError();
      return count;
    } catch (e) {
      print('获取医生病历记录数量时出错: $e');
      _setError('获取医生病历记录数量失败: $e');
      return 0;
    }
  }

  /// 检查当前用户是否有权限操作指定病历记录
  Future<bool> hasPermissionForRecord(int recordId) async {
    try {
      await _checkMedicalRecordPermission(recordId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 检查当前用户是否为管理员
  bool get isCurrentUserAdmin {
    final currentUser = _userProvider?.currentUser ?? _currentUser;
    return currentUser?.role == 'admin';
  }

  /// 获取当前用户的医生名称
  String? get currentDoctorName {
    final currentUser = _userProvider?.currentUser ?? _currentUser;
    return currentUser?.doctor;
  }

  // =================== PDF导出方法 ===================
  
  /// 导出病历为PDF
  Future<Uint8List> exportMedicalRecordToPdf(
    Patient patient,
    PatientMedicalRecord record, {
    String? clinicName,
    String? clinicLogo,
  }) async {
    try {
      _setLoading(true);
      
      // 使用PDF导出器生成PDF
      final pdfBytes = await MedicalRecordPdfExporter.generatePdf(
        patient,
        record,
        clinicName: clinicName,
        clinicLogo: clinicLogo,
      );
      
      _clearError();
      return pdfBytes;
    } catch (e) {
      print('导出病历PDF时出错: $e');
      _setError('导出病历PDF失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // =================== MySQL同步方法 ===================
  
  /// 尝试将SQLite中的病历记录同步到MySQL（非阻塞操作）
  Future<void> _trySyncMedicalRecordToMySQL(PatientMedicalRecord record, {required bool isUpdate}) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过病历记录同步(id=${record.id})');
          return;
        }

        if (isUpdate) {
          // 更新操作
          try {
            final result = await conn.query('''
              UPDATE patient_medical_records SET
                patient_id = ?, record_number = ?, record_date = ?, chief_complaint = ?, present_illness = ?,
                past_medical_history = ?, past_dental_history = ?, allergy_history = ?,
                oral_examination = ?, selected_dental_condition_date = ?,
                diagnosis = ?, treatment_plan = ?, notes = ?, doctor_name = ?,
                created_at = ?, updated_at = ?
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
              record.selectedDentalConditionDate,
              record.diagnosis,
              record.treatmentPlan,
              record.notes,
              record.doctorName,
              DateTimeFormatter.toDbString(record.createdAt),
              DateTimeFormatter.toDbString(record.updatedAt),
              record.id,
            ]);
            print('成功更新MySQL病历记录(id=${record.id})，影响行数: ${result.affectedRows}');
          } catch (e) {
            print('更新MySQL病历记录(id=${record.id})时出错: $e');
          }
        } else {
          // 插入操作
          try {
            // 先检查是否已存在
            final existResult = await conn.query(
              'SELECT id FROM patient_medical_records WHERE id = ? LIMIT 1',
              [record.id],
            );

            if (existResult.isNotEmpty) {
              // 已存在，执行更新
              final result = await conn.query('''
                UPDATE patient_medical_records SET
                  patient_id = ?, record_number = ?, record_date = ?, chief_complaint = ?, present_illness = ?,
                  past_medical_history = ?, past_dental_history = ?, allergy_history = ?,
                  oral_examination = ?, selected_dental_condition_date = ?,
                  diagnosis = ?, treatment_plan = ?, notes = ?, doctor_name = ?,
                  created_at = ?, updated_at = ?
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
                record.selectedDentalConditionDate,
                record.diagnosis,
                record.treatmentPlan,
                record.notes,
                record.doctorName,
                DateTimeFormatter.toDbString(record.createdAt),
                DateTimeFormatter.toDbString(record.updatedAt),
                record.id,
              ]);
              print('MySQL中已存在病历记录，执行更新(id=${record.id})，影响行数: ${result.affectedRows}');
            } else {
              // 不存在，执行插入
              final result = await conn.query('''
                INSERT INTO patient_medical_records 
                (id, patient_id, record_number, record_date, chief_complaint, present_illness,
                 past_medical_history, past_dental_history, allergy_history,
                 oral_examination, selected_dental_condition_date,
                 diagnosis, treatment_plan, notes, doctor_name, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''', [
                record.id,
                record.patientId,
                record.recordNumber,
                DateTimeFormatter.toDbString(record.recordDate),
                record.chiefComplaint,
                record.presentIllness,
                record.pastMedicalHistory,
                record.pastDentalHistory,
                record.allergyHistory,
                record.oralExamination,
                record.selectedDentalConditionDate,
                record.diagnosis,
                record.treatmentPlan,
                record.notes,
                record.doctorName,
                DateTimeFormatter.toDbString(record.createdAt),
                DateTimeFormatter.toDbString(record.updatedAt),
              ]);
              print('成功插入MySQL病历记录(id=${record.id})，插入ID: ${result.insertId}');
            }
          } catch (e) {
            print('同步MySQL病历记录(id=${record.id})时出错: $e');
          }
        }
      } catch (e) {
        print('病历记录同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试将SQLite中的模板同步到MySQL（非阻塞操作）
  Future<void> _trySyncTemplateToMySQL(MedicalRecordTemplate template, {required bool isUpdate}) async {
    Future.microtask(() async {
      try {
        // 获取当前的MySQL连接
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过模板同步(id=${template.id})');
          return;
        }

        if (isUpdate) {
          // 更新操作
          try {
            final result = await conn.query('''
              UPDATE medical_record_templates SET
                category = ?, name = ?, parent_name = ?, description = ?,
                is_active = ?, sort_order = ?, created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              template.category,
              template.name,
              template.parentName,
              template.description,
              template.isActive ? 1 : 0,
              template.sortOrder,
              DateTimeFormatter.toDbString(template.createdAt),
              DateTimeFormatter.toDbString(template.updatedAt),
              template.id,
            ]);
            print('成功更新MySQL模板(id=${template.id})，影响行数: ${result.affectedRows}');
          } catch (e) {
            print('更新MySQL模板(id=${template.id})时出错: $e');
          }
        } else {
          // 插入操作
          try {
            // 先检查是否已存在
            final existResult = await conn.query(
              'SELECT id FROM medical_record_templates WHERE id = ? LIMIT 1',
              [template.id],
            );

            if (existResult.isNotEmpty) {
              // 已存在，执行更新
              final result = await conn.query('''
                UPDATE medical_record_templates SET
                  category = ?, name = ?, parent_name = ?, description = ?,
                  is_active = ?, sort_order = ?, created_at = ?, updated_at = ?
                WHERE id = ?
              ''', [
                template.category,
                template.name,
                template.parentName,
                template.description,
                template.isActive ? 1 : 0,
                template.sortOrder,
                DateTimeFormatter.toDbString(template.createdAt),
                DateTimeFormatter.toDbString(template.updatedAt),
                template.id,
              ]);
              print('MySQL中已存在模板，执行更新(id=${template.id})，影响行数: ${result.affectedRows}');
            } else {
              // 不存在，执行插入
              final result = await conn.query('''
                INSERT INTO medical_record_templates 
                (id, category, name, parent_name, description, is_active, sort_order, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
              ''', [
                template.id,
                template.category,
                template.name,
                template.parentName,
                template.description,
                template.isActive ? 1 : 0,
                template.sortOrder,
                DateTimeFormatter.toDbString(template.createdAt),
                DateTimeFormatter.toDbString(template.updatedAt),
              ]);
              print('成功插入MySQL模板(id=${template.id})，插入ID: ${result.insertId}');
            }
          } catch (e) {
            print('同步MySQL模板(id=${template.id})时出错: $e');
          }
        }
      } catch (e) {
        print('模板同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除模板（非阻塞操作，包括级联删除子模板）
  Future<void> _trySyncDeleteTemplateToMySQL(int id, String templateName) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过模板删除同步(id=$id)');
          return;
        }

        try {
          // 使用事务确保数据一致性
          await conn.query('START TRANSACTION');
          
          try {
            // 先删除所有子模板（parent_name = 当前模板名称）
            final childResult = await conn.query(
              'DELETE FROM medical_record_templates WHERE parent_name = ?',
              [templateName],
            );
            print('删除了 ${childResult.affectedRows} 个子模板');
            
            // 再删除主模板
            final result = await conn.query(
              'DELETE FROM medical_record_templates WHERE id = ?',
              [id],
            );
            print('成功从MySQL删除模板(id=$id)，影响行数: ${result.affectedRows}');
            
            await conn.query('COMMIT');
          } catch (e) {
            await conn.query('ROLLBACK');
            print('从MySQL删除模板(id=$id)时出错: $e');
          }
        } catch (e) {
          print('从MySQL删除模板事务失败: $e');
        }
      } catch (e) {
        print('模板删除同步到MySQL发生不可预期错误: $e');
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

        return conn;
      }
    } catch (e) {
      print('尝试建立MySQL连接失败: $e');
    }
    return null;
  }
}

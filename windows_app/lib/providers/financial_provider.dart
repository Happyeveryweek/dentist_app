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

import '../providers/patient_provider.dart';
import '../utils/datetime_formatter.dart';
import '../providers/user_provider.dart';
import '../models/patient.dart';
import '../models/appointment.dart';
// 随访记录相关导入已移除
import '../models/user.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/material.dart' as material_models;
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../providers/settings_provider.dart';
import '../utils/pinyin_util.dart';
import '../utils/mysql_sync_connection_helper.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import '../data_sources/financial_data_source.dart';

/// 财务管理提供者
/// 负责处理所有与财务相关的数据库操作
class FinancialProvider extends ChangeNotifier {
  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;
  
  // 数据源类型
  String _dataSourceType = 'sqlite';
  
  // 模块数据源配置
  Map<String, String>? _moduleDataSources;
  
  // 标志：是否使用了临时覆盖的模块数据源配置（降级时）
  bool _isUsingTemporaryModuleDataSources = false;
  
  // 当前用户信息
  User? _currentUser;
  
  // 刷新标志
  bool _financialsNeedRefresh = false;
  
  // 缓存机制（类似采购管理）
  List<FinancialRecord>? _cachedRecords;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20); // 财务数据缓存20分钟
  
  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;
  
  // 患者提供者引用（用于获取患者信息）
  PatientProvider? _patientProvider;
  
  // 用户权限提供者引用
  UserProvider? _userProvider;
  
  // 数据源具体实现
  SqliteFinancialDataSource? _sqliteDataSource;
  MySqlFinancialDataSource? _mysqlDataSource;
  
  // 连接状态
  bool _isConnected = true;
  String? _lastError;
  
  // Getters
  bool get initialized => _database != null || _mysqlConnection != null;
  bool get financialsNeedRefresh => _financialsNeedRefresh;
  String get dataSourceType => _dataSourceType;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  
  // 缓存相关getters
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;
  
  // 获取有效的数据源类型（考虑模块化配置）
  String get _effectiveDataSourceType {
    if (_moduleDataSources != null && _moduleDataSources!.containsKey('financial')) {
      return _moduleDataSources!['financial']!;
    }
    return _dataSourceType;
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqliteFinancialDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlConnection = connection;
    _mysqlDataSource = MySqlFinancialDataSource.withConnectionGetter(
      () async {
        final conn = await _currentMysqlConnection;
        return conn;
      },
      reconnectCallback: () async {
        // 重连回调：尝试重新初始化MySQL连接
        if (_databaseProvider != null) {
          try {
            await _databaseProvider.initializeMySQL();
            print('✅ FinancialProvider: MySQL重连成功');
          } catch (e) {
            print('❌ FinancialProvider: MySQL重连失败: $e');
          }
        }
      },
    );
  }
  
  // 设置患者提供者
  void setPatientProvider(PatientProvider patientProvider) {
    _patientProvider = patientProvider;
    
    // 清除缓存，强制重新加载数据以应用权限过滤
    clearCache();
    
    print('✅ FinancialProvider已设置PatientProvider引用');
  }
  
  // 设置用户权限提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    
    // 清除缓存，强制重新加载数据以应用权限过滤
    clearCache();
    
    print('✅ FinancialProvider已设置UserProvider引用，权限过滤已启用');
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  FinancialDataSource get _currentDataSource {
    final effectiveType = _effectiveDataSourceType;
    
    if (effectiveType == 'mysql') {
      // 如果要求使用MySQL但未初始化，尝试降级到SQLite
      if (_mysqlDataSource == null) {
        if (_sqliteDataSource != null) {
          print('⚠️ MySQL财务数据源未初始化，自动降级到SQLite');
          return _sqliteDataSource!;
        }
        throw Exception('MySQL财务数据源未初始化 - 模块配置要求使用MySQL但数据源未设置');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite财务数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  // 获取最新的MySQL连接（防止连接过期）
  Future<MySqlConnection?> get _currentMysqlConnection async {
    if (_effectiveDataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }
    
    // 每次都从DatabaseProvider获取最新连接
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        // 验证连接是否有效
        final isValid = await _validateConnection(latestConnection);
        if (isValid) {
          _mysqlConnection = latestConnection;
          return latestConnection;
        } else {
          print('⚠️ MySQL连接已失效，尝试重新获取...');
          // 连接失效，尝试重新初始化
          await _databaseProvider.initializeMySQL();
          final newConnection = _databaseProvider.mysqlConnection;
          if (newConnection != null) {
            _mysqlConnection = newConnection;
            return newConnection;
          }
        }
      }
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
    }
    
    return _mysqlConnection;
  }
  
  // 验证MySQL连接是否有效
  Future<bool> _validateConnection(MySqlConnection connection) async {
    try {
      await connection.query('SELECT 1').timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('连接验证超时');
        },
      );
      return true;
    } catch (e) {
      print('MySQL连接验证失败: $e');
      return false;
    }
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

  // 测试MySQL连接是否有效
  Future<bool> _testMySqlConnection() async {
    try {
      final conn = await _currentMysqlConnection;
      if (conn == null) return false;
      
      await conn.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      _isConnected = true;
      _clearError();
      return true;
    } catch (e) {
      print('MySQL连接测试失败: $e');
      _mysqlConnection = null;
      _setError('MySQL连接测试失败: $e');
      return false;
    }
  }

  // 清除错误状态
  void _clearError() {
    _lastError = null;
    notifyListeners();
  }

  // 设置错误状态
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
    notifyListeners();
  }

  // 确保MySQL连接有效
  Future<void> _ensureMySQLConnection() async {
    try {
      // 使用_currentMysqlConnection getter，它会自动从DatabaseProvider获取最新连接并验证
      final conn = await _currentMysqlConnection;
      if (conn == null) {
        throw Exception('MySQL连接不可用');
      }
      
      _isConnected = true;
      _clearError();
    } catch (e) {
      print('❌ FinancialProvider MySQL连接验证失败: $e');
      _setError('MySQL连接失败: $e');
      rethrow;
    }
  }

  // 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedRecords != null && 
           _lastCacheTime != null &&
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  // 更新缓存
  void _updateCache(List<FinancialRecord> records) {
    _cachedRecords = List.from(records);
    _lastCacheTime = DateTime.now();
      }
  
  // 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _lastCacheTime = null;
    _financialsNeedRefresh = true; // 标记需要刷新
        // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 构造函数
  FinancialProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
    User? currentUser,
    Map<String, String>? moduleDataSources,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
    _currentUser = currentUser;
    _moduleDataSources = moduleDataSources;
    
    // 不再自动检查表是否存在，表结构检测由SettingsProvider统一管理
  }
  
  // 设置数据库连接
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
    Map<String, String>? moduleDataSources,
  }) {
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) _currentUser = currentUser;
    if (moduleDataSources != null) _moduleDataSources = moduleDataSources;
    
    // 不再自动检查表是否存在，表结构检测由SettingsProvider统一管理
  }
  
  // 标记刷新
  void markFinancialsNeedRefresh() {
    _financialsNeedRefresh = true;
    notifyListeners();
  }
  
  // 从DatabaseProvider初始化（支持模块化配置）
  Future<void> initializeFromDatabase(dynamic dbProvider, {Map<String, String>? moduleDataSources, String? dataSourceMode, PatientProvider? patientProvider, UserProvider? userProvider}) async {
    try {
      print('FinancialProvider开始从DatabaseProvider初始化...');
      
      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;
      
      // 仅在没有使用临时覆盖时更新模块配置
      // 这样可以避免ChangeNotifierProxyProvider的update覆盖降级时的临时配置
      if (!_isUsingTemporaryModuleDataSources) {
        _moduleDataSources = moduleDataSources;
      } else {
        print('⏸️ initializeFromDatabase：已使用临时模块数据源配置，跳过覆盖');
      }
      
      // 保存患者提供者和用户权限提供者引用
      if (patientProvider != null) {
        _patientProvider = patientProvider;
        print('✅ FinancialProvider已设置PatientProvider引用');
      }
      
      if (userProvider != null) {
        _userProvider = userProvider;
        print('✅ FinancialProvider已设置UserProvider引用');
      }
      
      // 确定要使用的数据源类型
      String dbType = 'sqlite';
      
      // 如果是模块化模式且有模块配置，优先使用模块配置
      if (dataSourceMode == 'modular' && moduleDataSources != null && moduleDataSources.containsKey('financial')) {
        dbType = moduleDataSources['financial']!;
        print('FinancialProvider使用模块化配置: financial -> $dbType');
      } else {
        // 否则使用全局配置
        try {
          if (dbProvider.dataSourceType != null) {
            dbType = dbProvider.dataSourceType;
          }
        } catch (e) {
          print('获取dataSourceType失败，使用默认值: $e');
        }
        print('FinancialProvider使用全局配置: $dbType');
      }
      
      // 设置数据源类型
      _dataSourceType = dbType;
      
      // 根据确定的数据源类型初始化对应的数据源
      if (dbType == 'sqlite') {
        // 初始化SQLite数据源
        try {
          if (dbProvider.database != null) {
            _database = dbProvider.database;
            setSqliteDataSource(dbProvider.database);
                      }
        } catch (e) {
          print('获取SQLite数据库失败: $e');
        }
      } else if (dbType == 'mysql') {
        // 初始化MySQL数据源
        try {
          final mysqlConnection = dbProvider.mysqlConnection;
          if (mysqlConnection != null) {
            _mysqlConnection = mysqlConnection;
            setMySqlDataSource(mysqlConnection);
                      } else {
            print('⚠️ MySQL连接为null，自动降级到SQLite');
            _dataSourceType = 'sqlite';
            // 立即更新模块配置，避免后续代码仍然尝试使用MySQL
            if (_moduleDataSources != null) {
              _moduleDataSources!['financial'] = 'sqlite';
              print('✅ 已更新模块配置: financial -> sqlite');
            }
            
            // 降级到SQLite
            if (dbProvider.database != null) {
              _database = dbProvider.database;
              setSqliteDataSource(dbProvider.database);
              print('✅ FinancialProvider已降级到SQLite数据源');
            } else {
              print('❌ SQLite数据库也不可用');
            }
          }
        } catch (e) {
          print('获取MySQL连接失败: $e');
          // 尝试降级到SQLite
          _dataSourceType = 'sqlite';
          // 立即更新模块配置，避免后续代码仍然尝试使用MySQL
          if (_moduleDataSources != null) {
            _moduleDataSources!['financial'] = 'sqlite';
            print('✅ 已更新模块配置: financial -> sqlite');
          }
          
          if (dbProvider.database != null) {
            _database = dbProvider.database;
            try {
              setSqliteDataSource(dbProvider.database);
              print('✅ FinancialProvider已降级到SQLite数据源');
            } catch (fallbackError) {
              print('❌ 降级到SQLite也失败: $fallbackError');
            }
          }
        }
      }
      
      print('FinancialProvider初始化完成，数据源类型: $dbType');
    } catch (e) {
      print('FinancialProvider初始化失败: $e');
      _dataSourceType = 'sqlite';
    }
    
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 更新模块数据源配置
  void updateModuleDataSources(Map<String, String> moduleDataSources) {
    _moduleDataSources = moduleDataSources;
    _isUsingTemporaryModuleDataSources = true; // 标记为使用了临时覆盖
    print('FinancialProvider.updateModuleDataSources - 模块数据源配置已更新: $_moduleDataSources');
    print('⏸️ FinancialProvider.updateModuleDataSources - 已设置临时覆盖标志');
    
    // 检查当前需要的数据源是否已初始化
    final requiredType = _effectiveDataSourceType;
    print('FinancialProvider.updateModuleDataSources - 当前需要的数据源类型: $requiredType');
    
    if (requiredType == 'mysql' && _mysqlDataSource == null) {
      print('⚠️ 警告：模块配置要求使用MySQL，但MySQL数据源未初始化');
      print('⚠️ MySQL连接状态: ${_mysqlConnection != null ? "已连接" : "未连接"}');
      
      // 尝试从DatabaseProvider获取MySQL连接并初始化
      if (_databaseProvider != null) {
        try {
          final mysqlConnection = _databaseProvider.mysqlConnection;
          if (mysqlConnection != null) {
            _mysqlConnection = mysqlConnection;
            setMySqlDataSource(mysqlConnection);
            print('✅ 已重新初始化MySQL数据源');
          } else {
            print('❌ 无法获取MySQL连接');
          }
        } catch (e) {
          print('❌ 获取MySQL连接失败: $e');
        }
      }
    } else if (requiredType == 'sqlite' && _sqliteDataSource == null) {
      print('⚠️ 警告：模块配置要求使用SQLite，但SQLite数据源未初始化');
      print('⚠️ SQLite连接状态: ${_database != null ? "已连接" : "未连接"}');
      
      // 尝试从DatabaseProvider获取SQLite连接并初始化
      if (_databaseProvider != null) {
        try {
          final database = _databaseProvider.database;
          if (database != null) {
            _database = database;
            setSqliteDataSource(database);
            print('✅ 已重新初始化SQLite数据源');
          } else {
            print('❌ 无法获取SQLite数据库');
          }
        } catch (e) {
          print('❌ 获取SQLite数据库失败: $e');
        }
      }
    }
    
    // 通知所有监听者配置已更新
    notifyListeners();
  }
  
  // 重置刷新标志
  void resetFinancialsRefreshFlag() {
    _financialsNeedRefresh = false;
  }

  // =================== 新的数据源模式方法 ===================
  
  // =================== 权限过滤方法 ===================
  
  // 获取医生过滤条件（用于数据库层面过滤）
  String? _getDoctorFilter() {
    try {
                  // 如果没有用户权限提供者或当前用户是管理员，不进行过滤
      if (_userProvider == null || _userProvider!.currentUser == null) {
                return null;
      }
      
      final currentUser = _userProvider!.currentUser!;
            if (currentUser.isAdmin) {
                return null; // 管理员不过滤
      }
      
      // 获取当前用户的医生字段
      final doctorName = currentUser.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回一个不存在的值，确保查询结果为空
                return '__NO_DOCTOR__';
      }
      
            return doctorName;
    } catch (e) {
      print('❌ 获取医生过滤条件失败: $e');
      // 出错时返回安全的过滤条件
      return '__NO_DOCTOR__';
    }
  }
  
  // 应用权限过滤（通过患者医生字段过滤财务记录）
  Future<List<FinancialRecord>> _applyPermissionFilter(List<FinancialRecord> records) async {
    try {
      // 如果没有用户权限提供者或当前用户是管理员，不进行过滤
      if (_userProvider == null || _userProvider!.currentUser == null) {
        return records;
      }
      
      final currentUser = _userProvider!.currentUser!;
      if (currentUser.isAdmin) {
        return records;
      }
      
      // 获取当前用户的医生字段
      final doctorName = currentUser.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回空列表
        print('当前用户没有医生字段，返回空财务记录列表');
        return [];
      }
      
      // 过滤财务记录：只显示患者医生字段匹配的记录
      List<FinancialRecord> filteredRecords = [];
      
      for (final record in records) {
        if (record.patientId != null) {
          // 通过患者提供者获取患者信息
          if (_patientProvider != null) {
            final patient = await _patientProvider!.getPatient(record.patientId!);
            if (patient != null && patient.doctor == doctorName) {
              filteredRecords.add(record);
            }
          }
        }
      }
      
            return filteredRecords;
      
    } catch (e) {
      print('应用财务记录权限过滤失败: $e');
      // 出错时返回空列表，确保安全
      return [];
    }
  }
  
  // 获取所有财务记录（纯数据源模式，支持权限过滤）
  Future<List<FinancialRecord>> getAllFinancialRecordsNew() async {
    if (!initialized) {
      return _cachedRecords ?? []; // 优雅降级而不是抛出异常
    }

    try {
      // 优先检查缓存
      if (_isCacheValid() && !_financialsNeedRefresh) {
        print('使用缓存的财务记录数据: ${_cachedRecords!.length} 条');
        return _cachedRecords!;
      }
      
      print('🔄 从数据库获取最新财务记录...');
      
      // 使用数据源模式（统一接口）
      List<FinancialRecord> records = await _currentDataSource.getAllFinancialRecords();
            // 应用权限过滤
      records = await _applyPermissionFilter(records);

      // 更新缓存
      _updateCache(records);
      _financialsNeedRefresh = false; // 清除刷新标志
      print('✅ 财务记录缓存已更新');
      
      return records;
    } catch (e) {
      print('❌ 获取财务记录失败: $e');
      
      // 优雅降级：如果有缓存就返回缓存，否则返回空列表
      if (_isCacheValid()) {
        print('使用缓存的财务记录数据，查询失败: $e');
        return _cachedRecords!;
      }
      
      return []; // 返回空列表而不是抛出异常
    }
  }

  // 分页：获取财务记录总数
  Future<int> getFinancialRecordsCount({
    String? searchQuery,
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化 - SQLite: ${_database != null}, MySQL: ${_mysqlConnection != null}');
    }

    try {
      // 使用数据源模式（统一接口）
      final count = await _currentDataSource.getFinancialRecordsCount(searchQuery: searchQuery);
            return count;
    } catch (e) {
      print('getFinancialRecordsCount 出错: $e');
      return 0;
    }
  }

  // 分页：获取财务记录
  Future<List<FinancialRecord>> getFinancialRecords({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化 - SQLite: ${_database != null}, MySQL: ${_mysqlConnection != null}');
    }

    try {
      // 使用数据源模式（统一接口）
      List<FinancialRecord> records = await _currentDataSource.getPaginatedFinancialRecords(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
      );
            // 应用权限过滤
      records = await _applyPermissionFilter(records);
      
      return records;
    } catch (e) {
      print('getFinancialRecords 出错: $e');
      return [];
    }
  }

  // 添加财务记录
  Future<int> addFinancialRecord(FinancialRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 调试日志
      print('📝 addFinancialRecord: 当前_moduleDataSources = $_moduleDataSources');
      print('📝 addFinancialRecord: 当前_effectiveDataSourceType = $_effectiveDataSourceType');
      print('📝 addFinancialRecord: 当前_sqliteDataSource = ${_sqliteDataSource != null ? "已初始化" : "未初始化"}');
      print('📝 addFinancialRecord: 当前_mysqlDataSource = ${_mysqlDataSource != null ? "已初始化" : "未初始化"}');
      
      // 使用数据源模式（统一接口）
      final recordId = await _currentDataSource.createFinancialRecord(record);
            // 清除缓存并标记需要刷新
      clearCache();
      markFinancialsNeedRefresh();
      
      // 如果当前使用的是SQLite数据源，需要同步到MySQL
      if (_effectiveDataSourceType == 'sqlite') {
                final recordMap = record.toMap();
        recordMap['id'] = recordId;
        _trySyncFinancialRecordToMySQL(recordMap, recordId);
      }
      
      return recordId;
    } catch (e) {
      print('添加财务记录时出错: $e');
      throw Exception('添加财务记录失败: $e');
    }
  }

  // 更新财务记录
  Future<bool> updateFinancialRecord(FinancialRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.updateFinancialRecord(record);
            if (success) {
        // 清除缓存并标记需要刷新
        clearCache();
        markFinancialsNeedRefresh();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite' && record.id != null) {
                    final recordMap = record.toMap();
          _trySyncFinancialRecordToMySQL(recordMap, record.id!);
        }
      }
      return success;
    } catch (e) {
      print('更新财务记录时出错: $e');
      return false;
    }
  }

  // 删除财务记录
  Future<bool> deleteFinancialRecord(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.deleteFinancialRecord(id);
            if (success) {
        // 清除缓存并标记需要刷新
        clearCache();
        markFinancialsNeedRefresh();
        
        // 如果当前使用的是SQLite数据源，需要同步删除到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
                    _trySyncDeleteFinancialRecordToMySQL(id);
        }
      }
      return success;
    } catch (e) {
      print('删除财务记录时出错: $e');
      return false;
    }
  }

  // 获取财务项目
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final items = await _currentDataSource.getFinancialItemsByRecordId(recordId);
            return items;
    } catch (e) {
      print('获取财务项目时出错: $e');
      return [];
    }
  }

  // 添加财务项目
  Future<int> addFinancialItem(FinancialItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 调试日志
      print('📝 addFinancialItem: 当前_moduleDataSources = $_moduleDataSources');
      print('📝 addFinancialItem: 当前_effectiveDataSourceType = $_effectiveDataSourceType');
      print('📝 addFinancialItem: 当前_sqliteDataSource = ${_sqliteDataSource != null ? "已初始化" : "未初始化"}');
      print('📝 addFinancialItem: 当前_mysqlDataSource = ${_mysqlDataSource != null ? "已初始化" : "未初始化"}');
      
      // 使用数据源模式（统一接口）
      final id = await _currentDataSource.createFinancialItem(item);
            markFinancialsNeedRefresh();
      
      // 如果当前使用的是SQLite数据源，需要同步到MySQL
      if (_effectiveDataSourceType == 'sqlite') {
                final itemMap = item.toMap();
        itemMap['id'] = id;
        _trySyncFinancialItemToMySQL(itemMap, id);
      }
      
      return id;
    } catch (e) {
      print('添加财务项目时出错: $e');
      throw Exception('添加财务项目失败: $e');
    }
  }

  // 更新财务项目
  Future<bool> updateFinancialItem(FinancialItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.updateFinancialItem(item);
            if (success) {
        markFinancialsNeedRefresh();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite' && item.id != null) {
                    final itemMap = item.toMap();
          _trySyncFinancialItemToMySQL(itemMap, item.id!);
        }
      }
      return success;
    } catch (e) {
      print('更新财务项目时出错: $e');
      return false;
    }
  }

  // 删除财务项目
  Future<bool> deleteFinancialItem(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.deleteFinancialItem(id);
            if (success) {
        markFinancialsNeedRefresh();
        
        // 如果当前使用的是SQLite数据源，需要同步删除到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
                    _trySyncDeleteFinancialItemToMySQL(id);
        }
      }
      return success;
    } catch (e) {
      print('删除财务项目时出错: $e');
      return false;
    }
  }

  // 获取财务统计信息
  Future<Map<String, dynamic>> getFinancialStatistics() async {
    if (!initialized) {
      return {
        'totalReceivable': 0.0,
        'totalReceived': 0.0,
        'totalPending': 0.0,
      };
    }

    try {
      // 使用数据源模式（统一接口）
      final stats = await _currentDataSource.getFinancialStatistics();
            return stats;
    } catch (e) {
      print('获取财务统计信息时出错: $e');
      return {
        'totalReceivable': 0.0,
        'totalReceived': 0.0,
        'totalPending': 0.0,
      };
    }
  }

  // =================== 兼容性方法（保持向后兼容） ===================
  
  // 确保必要的表存在
  Future<void> _ensureTablesExist() async {
    if (!initialized) return;
    
    try {
      await ensureFinancialRecordsTableExists();
    } catch (e) {
      print('确保财务表存在时出错: $e');
    }
  }

  // 确保财务记录表存在
  Future<void> ensureFinancialRecordsTableExists() async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    
    if (effectiveDataSourceType == 'sqlite') {
      final db = _database;
      if (db == null) return;
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS financial_records (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patient_id INTEGER NOT NULL,
          total_quantity INTEGER DEFAULT 0,
          notes TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      await db.execute('''
        CREATE TABLE IF NOT EXISTS financial_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          financial_record_id INTEGER NOT NULL,
          item_name TEXT NOT NULL,
          item_price REAL NOT NULL,
          processing_fee REAL DEFAULT 0,
          quantity INTEGER DEFAULT 1,
          total_price REAL NOT NULL,
          charge_date TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          FOREIGN KEY (financial_record_id) REFERENCES financial_records (id) ON DELETE CASCADE
        )
      ''');
    } else if (effectiveDataSourceType == 'mysql') {
      await _ensureMySQLConnection();
      final conn = await _currentMysqlConnection;
      if (conn == null) return;
      
      await conn.query('''
        CREATE TABLE IF NOT EXISTS financial_records (
          id INT AUTO_INCREMENT PRIMARY KEY,
          patient_id INT NOT NULL,
          total_quantity INT DEFAULT 0,
          notes TEXT,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        )
      ''');
      
      await conn.query('''
        CREATE TABLE IF NOT EXISTS financial_items (
          id INT AUTO_INCREMENT PRIMARY KEY,
          financial_record_id INT NOT NULL,
          item_name VARCHAR(255) NOT NULL,
          item_price DECIMAL(10,2) NOT NULL,
          processing_fee DECIMAL(10,2) DEFAULT 0,
          quantity INT DEFAULT 1,
          total_price DECIMAL(10,2) NOT NULL,
          charge_date DATE NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
          FOREIGN KEY (financial_record_id) REFERENCES financial_records (id) ON DELETE CASCADE
        )
      ''');
    }
  }

  // 安全获取notes字段内容
  String _safeGetNotes(dynamic notes) {
    if (notes == null) return '';
    if (notes is String) return notes;
    if (notes is List<int>) {
      try {
        return utf8.decode(notes);
      } catch (e) {
        print('解码notes字段失败: $e');
        return '';
      }
    }
    return notes.toString();
  }

  // =================== 向后兼容的方法 ===================
  
  // 获取所有财务记录（向后兼容）
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    if (!initialized) {
      return _cachedRecords ?? [];
    }

    try {
      // 优先检查缓存
      if (_isCacheValid() && !_financialsNeedRefresh) {
        print('使用缓存的财务记录数据: ${_cachedRecords!.length} 条');
        return _cachedRecords!;
      }
      
      print('🔄 从数据库获取最新财务记录...');
      
      // 使用数据源模式（统一接口）
      final records = await _currentDataSource.getAllFinancialRecords();
            // 更新缓存
      _updateCache(records);
      _financialsNeedRefresh = false;
      print('✅ 财务记录缓存已更新');
      
      return records;
    } catch (e) {
      print('❌ 获取财务记录失败: $e');
      
      // 优雅降级：如果有缓存就返回缓存，否则返回空列表
      if (_isCacheValid()) {
        print('使用缓存的财务记录数据，查询失败: $e');
        return _cachedRecords!;
      }
      
      return [];
    }
  }

  // 获取财务项目（向后兼容）
  Future<List<FinancialItem>> getFinancialItems(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final items = await _currentDataSource.getFinancialItemsByRecordId(recordId);
            return items;
    } catch (e) {
      print('获取财务项目时出错: $e');
      return [];
    }
  }

  // 患者维度分页聚合（用于"按患者显示"Route B）
  Future<Map<String, dynamic>> getPatientAggregatesPage({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    List<int>? patientIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    print('🔍 getPatientAggregatesPage开始执行: _moduleDataSources=$_moduleDataSources, effectiveDataSourceType=$effectiveDataSourceType');
    print('🔍 _sqliteDataSource=${_sqliteDataSource != null ? "已初始化" : "未初始化"}, _mysqlDataSource=${_mysqlDataSource != null ? "已初始化" : "未初始化"}');
    
    if (!initialized) return {'total': 0, 'rows': <Map<String, dynamic>>[]};

    final offset = (page - 1) * pageSize;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add('fr.patient_id IN ($placeholders)');
      whereArgs.addAll(patientIds);
    }
    
    if (startDate != null) { 
      conditions.add('fi.charge_date >= ?'); 
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]); 
    }
    if (endDate != null) { 
      conditions.add('fi.charge_date <= ?'); 
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]); 
    }
    if (conditions.isNotEmpty) { 
      whereClause = 'WHERE ' + conditions.join(' AND '); 
    }

    late final String orderExprSql;
    final bool isDateOrder;
    if (sortBy == 'charge_date') {
      orderExprSql = 'MAX(COALESCE(fi.charge_date, fr.created_at))';
      isDateOrder = true;
    } else if (sortBy == 'updated_at') {
      orderExprSql = 'MAX(COALESCE(fi.updated_at, fr.updated_at))';
      isDateOrder = true;
    } else if (sortBy == 'received_sum') {
      orderExprSql = 'COALESCE(SUM(fi.total_price), 0)';
      isDateOrder = false;
    } else if (sortBy == 'receivable_sum') {
      orderExprSql = 'COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0)';
      isDateOrder = false;
    } else if (sortBy == 'debt_sum') {
      orderExprSql = 'COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0) - COALESCE(SUM(fi.total_price), 0)';
      isDateOrder = false;
    } else {
      orderExprSql = 'MAX(fr.updated_at)';
      isDateOrder = true;
    }

    try {
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database; 
        if (db == null) return {'total': 0, 'rows': <Map<String, dynamic>>[]};

        final totalQuery = '''
          SELECT COUNT(*) AS cnt FROM (
            SELECT fr.patient_id
            FROM financial_records fr
            LEFT JOIN financial_items fi ON fi.financial_record_id = fr.id
            $whereClause
            GROUP BY fr.patient_id
          ) t
        ''';
        final totalRes = await db.rawQuery(totalQuery, whereArgs);
        final total = Sqflite.firstIntValue(totalRes) ?? 0;

        final rowsQuery = '''
          SELECT fr.patient_id AS patient_id,
                 MAX(COALESCE(fi.charge_date, fr.created_at)) AS latest_charge_date,
                 MAX(COALESCE(fi.updated_at, fr.updated_at)) AS last_updated,
                 COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0) AS receivable_sum,
                 COALESCE(SUM(fi.total_price), 0) AS received_sum,
                 COALESCE(SUM(fi.processing_fee), 0) AS processing_sum
          FROM financial_records fr
          LEFT JOIN financial_items fi ON fi.financial_record_id = fr.id
          $whereClause
          GROUP BY fr.patient_id
          ORDER BY ${isDateOrder ? 'datetime(' + orderExprSql + ')' : orderExprSql} $sortOrder
          LIMIT ? OFFSET ?
        ''';
        final rowsArgs = [...whereArgs, pageSize, offset];
        final rowsRes = await db.rawQuery(rowsQuery, rowsArgs);
        final rows = rowsRes.map((r) => {
          'patient_id': r['patient_id'],
          'latest_charge_date': r['latest_charge_date'],
          'last_updated': r['last_updated'],
          'receivable_sum': r['receivable_sum'],
          'received_sum': r['received_sum'],
          'processing_sum': r['processing_sum'],
        }).toList();
        return {'total': total, 'rows': rows};
      } else if (effectiveDataSourceType == 'mysql') {
        await _ensureMySQLConnection();
        final conn = await _currentMysqlConnection; 
        if (conn == null) return {'total': 0, 'rows': <Map<String, dynamic>>[]};

        final totalQuery = '''
          SELECT COUNT(*) AS cnt FROM (
            SELECT fr.patient_id
            FROM financial_records fr
            LEFT JOIN financial_items fi ON fi.financial_record_id = fr.id
            $whereClause
            GROUP BY fr.patient_id
          ) t
        ''';
        final totalRes = await conn.query(totalQuery, whereArgs);
        final totalRow = totalRes.first;
        final int total = (totalRow['cnt'] is BigInt) ? (totalRow['cnt'] as BigInt).toInt() : (totalRow['cnt'] ?? 0);

        final rowsQuery = '''
          SELECT fr.patient_id AS patient_id,
                 MAX(COALESCE(fi.charge_date, fr.created_at)) AS latest_charge_date,
                 MAX(COALESCE(fi.updated_at, fr.updated_at)) AS last_updated,
                 COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0) AS receivable_sum,
                 COALESCE(SUM(fi.total_price), 0) AS received_sum,
                 COALESCE(SUM(fi.processing_fee), 0) AS processing_sum
          FROM financial_records fr
          LEFT JOIN financial_items fi ON fi.financial_record_id = fr.id
          $whereClause
          GROUP BY fr.patient_id
          ORDER BY $orderExprSql $sortOrder
          LIMIT ? OFFSET ?
        ''';
        final rowsArgs = [...whereArgs, pageSize, offset];
        final rowsRes = await conn.query(rowsQuery, rowsArgs);
        final rows = rowsRes.map((r) => {
          'patient_id': (r['patient_id'] is BigInt) ? (r['patient_id'] as BigInt).toInt() : r['patient_id'],
          'latest_charge_date': r['latest_charge_date']?.toString(),
          'last_updated': r['last_updated']?.toString(),
          'receivable_sum': (r['receivable_sum'] is BigInt) ? (r['receivable_sum'] as BigInt).toDouble() : (r['receivable_sum'] as num?)?.toDouble() ?? 0.0,
          'received_sum': (r['received_sum'] is BigInt) ? (r['received_sum'] as BigInt).toDouble() : (r['received_sum'] as num?)?.toDouble() ?? 0.0,
          'processing_sum': (r['processing_sum'] is BigInt) ? (r['processing_sum'] as BigInt).toDouble() : (r['processing_sum'] as num?)?.toDouble() ?? 0.0,
        }).toList();
        return {'total': total, 'rows': rows};
      }
    } catch (e) {
      print('❌ getPatientAggregatesPage 失败: $e');
      rethrow;
    }
    return {'total': 0, 'rows': <Map<String, dynamic>>[]};
  }

  // 获取某患者"最近更新"的代表财务记录
  Future<FinancialRecord?> getLatestRecordForPatient(int patientId) async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    if (!initialized) return null;
    try {
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database; 
        if (db == null) return null;
        final res = await db.query(
          'financial_records',
          columns: ['id', 'patient_id', 'total_quantity', 'notes', 'created_at', 'updated_at'],
          where: 'patient_id = ?',
          whereArgs: [patientId],
          orderBy: 'updated_at DESC',
          limit: 1,
        );
        if (res.isEmpty) return null;
        return FinancialRecord.fromMap(res.first);
      } else if (effectiveDataSourceType == 'mysql') {
        await _ensureMySQLConnection();
        final conn = await _currentMysqlConnection; 
        if (conn == null) return null;
        final rows = await conn.query(
          'SELECT id, patient_id, total_quantity, notes, created_at, updated_at FROM financial_records WHERE patient_id = ? ORDER BY updated_at DESC LIMIT 1',
          [patientId],
        );
        if (rows.isEmpty) return null;
        final row = rows.first;
        return FinancialRecord.fromMap({
          'id': row['id'],
          'patient_id': row['patient_id'],
          'total_quantity': row['total_quantity'],
          'notes': _safeGetNotes(row['notes']),
          'created_at': row['created_at']?.toString(),
          'updated_at': row['updated_at']?.toString(),
        });
      }
    } catch (e) {
      print('❌ getLatestRecordForPatient 失败: $e');
    }
    return null;
  }

  // 其他向后兼容方法
  Future<void> updatePatientFinancialSummary(int patientId) async {
    print('updatePatientFinancialSummary called for patient $patientId - 在新架构中此方法可能不需要');
  }

  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(int patientId) async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    if (!initialized) return [];

    try {
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return [];
        
        final List<Map<String, dynamic>> maps = await db.query(
          'financial_records',
          columns: ['id', 'patient_id', 'total_quantity', 'notes', 'created_at', 'updated_at'],
          where: 'patient_id = ?',
          whereArgs: [patientId],
          orderBy: 'updated_at DESC',
        );

        return List.generate(maps.length, (i) {
          return FinancialRecord.fromMap(maps[i]);
        });
      } else if (effectiveDataSourceType == 'mysql') {
        await _ensureMySQLConnection();
        final conn = await _currentMysqlConnection;
        if (conn == null) return [];
        
        final results = await conn.query(
          'SELECT id, patient_id, total_quantity, notes, created_at, updated_at FROM financial_records WHERE patient_id = ? ORDER BY updated_at DESC',
          [patientId]
        );
        
        return results.map((row) => FinancialRecord.fromMap({
          'id': row['id'],
          'patient_id': row['patient_id'],
          'total_quantity': row['total_quantity'],
          'notes': _safeGetNotes(row['notes']),
          'created_at': row['created_at']?.toString(),
          'updated_at': row['updated_at']?.toString(),
        })).toList();
      }
    } catch (e) {
      print('获取患者财务记录失败: $e');
    }
    return [];
  }

  Future<FinancialRecord?> getFinancialRecordById(int id) async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    if (!initialized) return null;

    try {
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return null;
        
        final List<Map<String, dynamic>> maps = await db.query(
          'financial_records',
          columns: ['id', 'patient_id', 'total_quantity', 'notes', 'created_at', 'updated_at'],
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );

        if (maps.isNotEmpty) {
          return FinancialRecord.fromMap(maps.first);
        }
      } else if (effectiveDataSourceType == 'mysql') {
        await _ensureMySQLConnection();
        final conn = await _currentMysqlConnection;
        if (conn == null) return null;
        
        final results = await conn.query(
          'SELECT id, patient_id, total_quantity, notes, created_at, updated_at FROM financial_records WHERE id = ? LIMIT 1',
          [id]
        );
        
        if (results.isNotEmpty) {
          final row = results.first;
          return FinancialRecord.fromMap({
            'id': row['id'],
            'patient_id': row['patient_id'],
            'total_quantity': row['total_quantity'],
            'notes': _safeGetNotes(row['notes']),
            'created_at': row['created_at']?.toString(),
            'updated_at': row['updated_at']?.toString(),
          });
        }
      }
    } catch (e) {
      print('获取财务记录失败: $e');
    }
    return null;
  }

  // 获取收费项总数和分页收费项等方法
  Future<int> getFinancialItemsCount({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
  }) async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    if (!initialized) return 0;

    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add('financial_record_id IN (SELECT id FROM financial_records WHERE patient_id IN (' + placeholders + '))');
      whereArgs.addAll(patientIds);
    }

    if (chargeItemQuery != null && chargeItemQuery.isNotEmpty) {
      conditions.add('item_name LIKE ?');
      whereArgs.add('%$chargeItemQuery%');
    }

    if (startDate != null) {
      conditions.add('charge_date >= ?');
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('charge_date <= ?');
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }

    if (receivableMin != null) {
      conditions.add('item_price >= ?');
      whereArgs.add(receivableMin);
    }
    if (receivableMax != null) {
      conditions.add('item_price <= ?');
      whereArgs.add(receivableMax);
    }
    if (receivedMin != null) {
      conditions.add('total_price >= ?');
      whereArgs.add(receivedMin);
    }
    if (receivedMax != null) {
      conditions.add('total_price <= ?');
      whereArgs.add(receivedMax);
    }
    if (processingMin != null) {
      conditions.add('processing_fee >= ?');
      whereArgs.add(processingMin);
    }
    if (processingMax != null) {
      conditions.add('processing_fee <= ?');
      whereArgs.add(processingMax);
    }

    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ' + conditions.join(' AND ');
    }

    try {
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return 0;
        final result = await db.rawQuery('SELECT COUNT(*) FROM financial_items$whereClause', whereArgs);
        return Sqflite.firstIntValue(result) ?? 0;
      } else if (effectiveDataSourceType == 'mysql') {
        await _ensureMySQLConnection();
        final conn = await _currentMysqlConnection;
        if (conn == null) return 0;
        final results = await conn.query('SELECT COUNT(*) as count FROM financial_items$whereClause', whereArgs);
        final row = results.first;
        final dynamic v = row['count'] ?? row[0];
        if (v is int) return v;
        if (v is BigInt) return v.toInt();
        return 0;
      }
    } catch (e) {
      print('❌ 获取收费项总数失败: $e');
      rethrow;
    }
    return 0;
  }

  Future<List<Map<String, dynamic>>> getFinancialItemsWithDetails({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
  }) async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    if (!initialized) return [];

    final offset = (page - 1) * pageSize;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add('fi.financial_record_id IN (SELECT id FROM financial_records WHERE patient_id IN (' + placeholders + '))');
      whereArgs.addAll(patientIds);
    }

    if (chargeItemQuery != null && chargeItemQuery.isNotEmpty) {
      conditions.add('fi.item_name LIKE ?');
      whereArgs.add('%$chargeItemQuery%');
    }

    if (startDate != null) {
      conditions.add('fi.charge_date >= ?');
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('fi.charge_date <= ?');
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }

    if (receivableMin != null) {
      conditions.add('fi.item_price >= ?');
      whereArgs.add(receivableMin);
    }
    if (receivableMax != null) {
      conditions.add('fi.item_price <= ?');
      whereArgs.add(receivableMax);
    }
    if (receivedMin != null) {
      conditions.add('fi.total_price >= ?');
      whereArgs.add(receivedMin);
    }
    if (receivedMax != null) {
      conditions.add('fi.total_price <= ?');
      whereArgs.add(receivedMax);
    }
    if (processingMin != null) {
      conditions.add('fi.processing_fee >= ?');
      whereArgs.add(processingMin);
    }
    if (processingMax != null) {
      conditions.add('fi.processing_fee <= ?');
      whereArgs.add(processingMax);
    }

    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ' + conditions.join(' AND ');
    }

    final orderBy = 'fi.$sortBy $sortOrder';

    try {
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return [];
        
        final query = '''
          SELECT fi.*, fr.patient_id, fr.notes
          FROM financial_items fi
          JOIN financial_records fr ON fi.financial_record_id = fr.id
          $whereClause
          ORDER BY $orderBy
          LIMIT ? OFFSET ?
        ''';
        
        final results = await db.rawQuery(query, [...whereArgs, pageSize, offset]);
        
        return results.map((row) => {
          'item': FinancialItem.fromMap({
            'id': row['id'],
            'financial_record_id': row['financial_record_id'],
            'item_name': row['item_name'],
            'item_price': row['item_price'],
            'processing_fee': row['processing_fee'],
            'quantity': row['quantity'],
            'total_price': row['total_price'],
            'charge_date': row['charge_date'],
            'created_at': row['created_at'],
            'updated_at': row['updated_at'],
          }),
          'patient_id': row['patient_id'],
          'record_notes': row['notes'],
        }).toList();
      } else if (effectiveDataSourceType == 'mysql') {
        await _ensureMySQLConnection();
        final conn = await _currentMysqlConnection;
        if (conn == null) return [];
        
        String query = '''
          SELECT fi.*, fr.patient_id, fr.notes
          FROM financial_items fi
          JOIN financial_records fr ON fi.financial_record_id = fr.id
          $whereClause
          ORDER BY $orderBy
          LIMIT $offset, $pageSize
        ''';
        
        final results = await conn.query(query, whereArgs);
        
        return results.map((row) => {
          'item': FinancialItem.fromMap({
            'id': row['id'],
            'financial_record_id': row['financial_record_id'],
            'item_name': row['item_name']?.toString(),
            'item_price': row['item_price'],
            'processing_fee': row['processing_fee'],
            'quantity': row['quantity'],
            'total_price': row['total_price'],
            'charge_date': row['charge_date']?.toString(),
            'created_at': row['created_at']?.toString(),
            'updated_at': row['updated_at']?.toString(),
          }),
          'patient_id': row['patient_id'],
          'record_notes': row['notes']?.toString(),
        }).toList();
      }
    } catch (e) {
      print('❌ 获取分页收费项失败: $e');
      rethrow;
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getAllFinancialItemsWithDetailsFiltered({
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
  }) async {
    print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 开始获取财务统计数据');
    final effectiveDataSourceType = _effectiveDataSourceType;
    if (!initialized) return [];

    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    // 添加权限过滤条件
    final doctorFilter = _getDoctorFilter();
    if (doctorFilter != null) {
      conditions.add('p.doctor = ?');
      whereArgs.add(doctorFilter);
      print('✅ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 应用医生过滤: $doctorFilter');
    } else {
      print('⚠️ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 无权限过滤（管理员或未设置）');
    }

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add('fr.patient_id IN ($placeholders)');
      whereArgs.addAll(patientIds);
    }

    if (chargeItemQuery != null && chargeItemQuery.isNotEmpty) {
      conditions.add('fi.item_name LIKE ?');
      whereArgs.add('%$chargeItemQuery%');
    }

    if (startDate != null) {
      conditions.add('fi.charge_date >= ?');
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('fi.charge_date <= ?');
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }

    if (receivableMin != null) { 
      conditions.add('fi.item_price >= ?'); 
      whereArgs.add(receivableMin); 
    }
    if (receivableMax != null) { 
      conditions.add('fi.item_price <= ?'); 
      whereArgs.add(receivableMax); 
    }
    if (receivedMin != null) { 
      conditions.add('fi.total_price >= ?'); 
      whereArgs.add(receivedMin); 
    }
    if (receivedMax != null) { 
      conditions.add('fi.total_price <= ?'); 
      whereArgs.add(receivedMax); 
    }
    if (processingMin != null) { 
      conditions.add('fi.processing_fee >= ?'); 
      whereArgs.add(processingMin); 
    }
    if (processingMax != null) { 
      conditions.add('fi.processing_fee <= ?'); 
      whereArgs.add(processingMax); 
    }

    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ' + conditions.join(' AND ');
    }

    final orderBy = 'fi.$sortBy $sortOrder';

    try {
      if (effectiveDataSourceType == 'sqlite') {
        final db = _database; 
        if (db == null) return [];
        final query = '''
          SELECT fi.*, fr.patient_id, fr.notes
          FROM financial_items fi
          JOIN financial_records fr ON fi.financial_record_id = fr.id
          JOIN patients p ON fr.patient_id = p.id
          $whereClause
          ORDER BY $orderBy
        ''';
        print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - SQLite查询: $query');
        print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 参数: $whereArgs');
        final results = await db.rawQuery(query, whereArgs);
        print('✅ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - SQLite查询成功，获取到 ${results.length} 条记录');
        return results.map((row) => {
          'item': FinancialItem.fromMap({
            'id': row['id'],
            'financial_record_id': row['financial_record_id'],
            'item_name': row['item_name'],
            'item_price': row['item_price'],
            'processing_fee': row['processing_fee'],
            'quantity': row['quantity'],
            'total_price': row['total_price'],
            'charge_date': row['charge_date'],
            'created_at': row['created_at'],
            'updated_at': row['updated_at'],
          }),
          'patient_id': row['patient_id'],
          'record_notes': row['notes'],
        }).toList();
      } else if (effectiveDataSourceType == 'mysql') {
        // 确保MySQL连接有效，如果连接断开则重新连接
        await _ensureMySQLConnection();
        final conn = await _currentMysqlConnection; 
        if (conn == null) {
          print('❌ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - MySQL连接失败');
          return [];
        }
        final query = '''
          SELECT fi.*, fr.patient_id, fr.notes
          FROM financial_items fi
          JOIN financial_records fr ON fi.financial_record_id = fr.id
          JOIN patients p ON fr.patient_id = p.id
          $whereClause
          ORDER BY $orderBy
        ''';
        print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - MySQL查询: $query');
        print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 参数: $whereArgs');
        final results = await conn.query(query, whereArgs);
        print('✅ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - MySQL查询成功，获取到 ${results.length} 条记录');
        return results.map((row) => {
          'item': FinancialItem.fromMap({
            'id': row['id'],
            'financial_record_id': row['financial_record_id'],
            'item_name': row['item_name']?.toString(),
            'item_price': row['item_price'],
            'processing_fee': row['processing_fee'],
            'quantity': row['quantity'],
            'total_price': row['total_price'],
            'charge_date': row['charge_date']?.toString(),
            'created_at': row['created_at']?.toString(),
            'updated_at': row['updated_at']?.toString(),
          }),
          'patient_id': row['patient_id'],
          'record_notes': row['notes']?.toString(),
        }).toList();
      }
    } catch (e) {
      print('❌ 获取所有收费项(用于统计)失败: $e');
      rethrow;
    }
    return [];
  }

  // =================== SQLite→MySQL 同步方法 ===================
  
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
          print('从 SharedPreferences 单独键读取 MySQL 配置');
        }
      }

      if (settings != null) {
        try {
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

          try {
            await conn.query("SET NAMES 'utf8mb4'");
            await conn.query("SET character_set_connection = 'utf8mb4'");
            await conn.query("SET character_set_results = 'utf8mb4'");
          } catch (e) {
            print('设置MySQL会话字符集失败: $e');
          }

          _mysqlConnection = conn;
          return conn;
        } catch (e) {
          print('尝试初始化MySQL连接失败: $e');
          return null;
        }
      }
    } catch (e) {
      print('读取SharedPreferences以获取MySQL设置失败: $e');
    }
    return null;
  }

  /// 尝试将SQLite中的财务记录同步到MySQL（非阻塞操作）
  Future<void> _trySyncFinancialRecordToMySQL(Map<String, dynamic> recordMap, int recordId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过财务记录同步(id=$recordId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT id FROM financial_records WHERE id = ? LIMIT 1',
            [recordId],
          );

          if (existResult.isNotEmpty) {
            // 更新操作
            final result = await conn.query('''
              UPDATE financial_records SET
                patient_id = ?, total_quantity = ?, notes = ?,
                created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              recordMap['patient_id'],
              recordMap['total_quantity'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
              recordId,
            ]);
            print('成功更新MySQL财务记录(id=$recordId)，影响行数: ${result.affectedRows}');
          } else {
            // 插入操作
            final result = await conn.query('''
              INSERT INTO financial_records
              (id, patient_id, total_quantity, notes, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              recordId,
              recordMap['patient_id'],
              recordMap['total_quantity'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
            ]);
            print('成功将财务记录(id=$recordId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          print('同步财务记录到MySQL时出错: $e');
        }
      } catch (e) {
        print('财务记录同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除财务记录（非阻塞操作，级联删除财务项目）
  Future<void> _trySyncDeleteFinancialRecordToMySQL(int recordId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过财务记录删除同步(id=$recordId)');
          return;
        }

        try {
          // 先删除关联的财务项目
          final itemsResult = await conn.query(
            'DELETE FROM financial_items WHERE financial_record_id = ?',
            [recordId],
          );
          print('成功从MySQL删除财务项目，影响行数: ${itemsResult.affectedRows}');
          
          // 再删除财务记录
          final recordResult = await conn.query(
            'DELETE FROM financial_records WHERE id = ?',
            [recordId],
          );
          print('成功从MySQL删除财务记录(id=$recordId)，影响行数: ${recordResult.affectedRows}');
        } catch (e) {
          print('从MySQL删除财务记录(id=$recordId)时出错: $e');
        }
      } catch (e) {
        print('财务记录删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试将SQLite中的财务项目同步到MySQL（非阻塞操作）
  Future<void> _trySyncFinancialItemToMySQL(Map<String, dynamic> itemMap, int itemId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过财务项目同步(id=$itemId)');
          return;
        }

        final existResult = await conn.query(
          'SELECT id FROM financial_items WHERE id = ? LIMIT 1',
          [itemId],
        );

        if (existResult.isNotEmpty) {
          // 更新操作
          final result = await conn.query('''
            UPDATE financial_items SET
              financial_record_id = ?, item_name = ?, item_price = ?,
              processing_fee = ?, quantity = ?, total_price = ?,
              charge_date = ?, created_at = ?, updated_at = ?
            WHERE id = ?
          ''', [
            itemMap['financial_record_id'],
            itemMap['item_name'],
            itemMap['item_price'],
            itemMap['processing_fee'],
            itemMap['quantity'],
            itemMap['total_price'],
            itemMap['charge_date'],
            itemMap['created_at'],
            itemMap['updated_at'],
            itemId,
          ]);
          print('成功更新MySQL财务项目(id=$itemId)，影响行数: ${result.affectedRows}');
        } else {
          // 插入操作
          final result = await conn.query('''
            INSERT INTO financial_items
            (id, financial_record_id, item_name, item_price, processing_fee, quantity, total_price, charge_date, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            itemId,
            itemMap['financial_record_id'],
            itemMap['item_name'],
            itemMap['item_price'],
            itemMap['processing_fee'],
            itemMap['quantity'],
            itemMap['total_price'],
            itemMap['charge_date'],
            itemMap['created_at'],
            itemMap['updated_at'],
          ]);
          print('成功将财务项目(id=$itemId)同步到MySQL，插入ID: ${result.insertId}');
        }
      } catch (e) {
        print('财务项目同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除财务项目（非阻塞操作）
  Future<void> _trySyncDeleteFinancialItemToMySQL(int itemId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过财务项目删除同步(id=$itemId)');
          return;
        }

        final result = await conn.query(
          'DELETE FROM financial_items WHERE id = ?',
          [itemId],
        );
        print('成功从MySQL删除财务项目(id=$itemId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        print('财务项目删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }
}
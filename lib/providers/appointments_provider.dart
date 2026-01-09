import 'package:flutter/foundation.dart';
import '../models/database_models.dart';
import '../utils/database_operation_wrapper.dart';
import '../data_sources/appointment_data_source.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:mysql1/mysql1.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'user_provider.dart'; // 导入UserProvider用于权限检查

// 预约管理提供者，用于管理应用程序与预约相关的数据库操作
class AppointmentsProvider extends ChangeNotifier {
  // 数据库连接
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _dataSourceType = 'sqlite';
  
  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;
  
  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;
  
  // UserProvider引用（用于权限检查）
  UserProvider? _userProvider;
  
  // 数据源具体实现
  SqliteAppointmentDataSource? _sqliteDataSource;
  MySqlAppointmentDataSource? _mysqlDataSource;
  
  // 初始化标志
  bool _isInitializedFlag = false;
  
  // 缓存数据
  List<Appointment>? _cachedAppointments;
  
  // 缓存机制
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 15); // 预约数据缓存15分钟
  
  // 刷新标志
  bool _appointmentsNeedRefresh = false;
  
  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;
  
  // Getters
  bool get initialized => _database != null || _currentMysqlConnection != null;
  bool get appointmentsNeedRefresh => _appointmentsNeedRefresh;
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  String? get lastError => _lastError;
  
  // 检查数据库是否已初始化
  bool get isInitialized {
    if (_dataSourceType == 'mysql') {
      return _currentMysqlConnection != null;
    } else {
      return _database != null;
    }
  }
  
  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqliteAppointmentDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlAppointmentDataSource.withConnectionGetter(() => _currentMysqlConnection);
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  AppointmentDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL预约数据源未初始化');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite预约数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  // 获取最新的MySQL连接（防止连接过期）
  MySqlConnection? get _currentMysqlConnection {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }
    
    // 每次都从DatabaseProvider获取最新连接
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        _mysqlConnection = latestConnection;
        return latestConnection;
      }
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
    }
    
    return _mysqlConnection;
  }

  // 获取当前数据源类型
  String get dataSourceType => _dataSourceType;
  
  // 缓存相关方法
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedAppointmentsCount => _cachedAppointments?.length ?? 0;
  
  // 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedAppointments != null && 
           _lastCacheTime != null &&
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  // 更新缓存
  void _updateCache(List<Appointment> appointments) {
    _cachedAppointments = List.from(appointments);
    _lastCacheTime = DateTime.now();
    print('预约数据缓存已更新: ${appointments.length} 条记录');
  }
  
  // 清除缓存
  void clearCache() {
    _cachedAppointments = null;
    _lastCacheTime = null;
    _appointmentsNeedRefresh = true; // 标记需要刷新
    print('预约数据缓存已清除，标记需要刷新');
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 从DatabaseProvider获取数据库连接（保持向后兼容）
  Future<void> initializeFromDatabase(dynamic dbProvider, {UserProvider? userProvider}) async {
    if (_isInitializedFlag) return;
    
    try {
      print('AppointmentsProvider开始初始化...');
      
      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;
      
      // 保存UserProvider引用
      _userProvider = userProvider;
      
      // 兼容处理，支持DatabaseProvider的不同接口
      String dbType = 'sqlite';
      if (dbProvider.dbType != null) {
        dbType = dbProvider.dbType;
      } else if (dbProvider.dataSourceType != null) {
        dbType = dbProvider.dataSourceType;
      }
      
      if (dbType == 'mysql') {
        final mysqlConnection = dbProvider.mysqlConnection;
        if (mysqlConnection != null) {
          _mysqlConnection = mysqlConnection;
          _dataSourceType = 'mysql';
          
          // 创建MySQL数据源
          setMySqlDataSource(mysqlConnection);
          
          _isInitializedFlag = true;
          print('✅ AppointmentsProvider MySQL数据源设置成功');
        } else {
          print('警告：MySQL连接为null，尝试SQLite');
          final database = await dbProvider.sqliteDatabase;
          if (database != null) {
            _database = database;
            _dataSourceType = 'sqlite';
            
            // 创建SQLite数据源
            setSqliteDataSource(database);
            
            _isInitializedFlag = true;
            print('AppointmentsProvider 回退到SQLite数据源设置成功');
          } else {
            print('警告：SQLite数据库实例为null，延迟初始化...');
            // 延迟重试
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isInitializedFlag) {
                initializeFromDatabase(dbProvider);
              }
            });
            return;
          }
        }
      } else {
        // 异步获取SQLite数据库实例
        try {
          final database = await dbProvider.sqliteDatabase;
          if (database != null) {
            _database = database;
            _dataSourceType = 'sqlite';
            
            // 创建SQLite数据源
            setSqliteDataSource(database);
            
            _isInitializedFlag = true;
            print('✅ AppointmentsProvider SQLite数据源设置成功');
          } else {
            print('警告：SQLite数据库实例为null，延迟初始化...');
            // 延迟重试
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isInitializedFlag) {
                initializeFromDatabase(dbProvider);
              }
            });
            return;
          }
        } catch (e) {
          print('获取SQLite数据库失败: $e');
          // 尝试通过其他方式获取
          if (dbProvider.database != null) {
            _database = dbProvider.database;
            _dataSourceType = 'sqlite';
            
            // 创建SQLite数据源
            setSqliteDataSource(dbProvider.database);
            
            _isInitializedFlag = true;
            print('通过备用方式获取SQLite数据库: ${_database != null ? "成功" : "失败"}');
          } else {
            print('警告：所有数据库获取方式都失败');
            return;
          }
        }
      }
      
      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);
      
      print('AppointmentsProvider初始化完成');
    } catch (e) {
      print('AppointmentsProvider初始化失败: $e');
      // 设置默认值，但不标记为已初始化
      _dataSourceType = 'sqlite';
      _isInitializedFlag = false;
    }
    
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 标记需要刷新
  void markAppointmentsNeedRefresh() {
    _appointmentsNeedRefresh = true;
    notifyListeners();
  }
  
  // 清除刷新标志
  void clearAppointmentsNeedRefresh() {
    _appointmentsNeedRefresh = false;
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
  
  // 获取所有预约（带缓存）
  Future<List<Appointment>> getAllAppointments() async {
    if (!initialized) {
      return _cachedAppointments ?? []; // 优雅降级而不是抛出异常
    }
    
    if (_dbWrapper == null) return _cachedAppointments ?? [];
    
    return await _dbWrapper!.wrapOperation('getAllAppointments', () async {
      try {
        // 优先检查缓存
        if (_isCacheValid()) {
          print('使用缓存的预约数据: ${_cachedAppointments!.length} 条');
          return _cachedAppointments!;
        }
        
        print('🔄 从数据库获取最新预约数据...');
        List<Appointment> appointments = [];

        // 使用数据源模式（统一接口）
        // Android端：不过滤查看权限，所有用户都能查看所有数据
        appointments = await _currentDataSource.getAllAppointments(doctorFilter: null);


        // 更新缓存
        _updateCache(appointments);
        print('✅ 预约数据缓存已更新');
        return appointments;
      } catch (e) {
        print('❌ 获取预约数据失败: $e');
        
        // 优雅降级：如果有缓存就返回缓存，否则返回空列表
        if (_isCacheValid()) {
          print('使用缓存的预约数据，查询失败: $e');
          return _cachedAppointments!;
        }
        
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 获取预约总数
  Future<int> getAppointmentCount() async {
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('getAppointmentCount', () async {
      try {
        print('正在获取预约总数...');
        
        // 使用数据源模式（统一接口）
        // Android端：不过滤查看权限，返回所有预约总数
        final count = await _currentDataSource.getAppointmentsCount(doctorFilter: null);

        return count;
      } catch (e) {
        print('获取预约总数错误: $e');
        return 0;
      }
    });
  }

  // 获取今日预约
  Future<List<Appointment>> getTodayAppointments() async {
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getTodayAppointments', () async {
      try {
        final today = DateTime.now();
        final startDate = DateTime(today.year, today.month, today.day);
        final endDate = DateTime(today.year, today.month, today.day, 23, 59, 59);
        
        // 使用数据源模式（统一接口）
        // Android端：不过滤查看权限，返回所有今日预约
        return await _currentDataSource.getAppointmentsByDateRange(startDate, endDate, doctorFilter: null);
      } catch (e) {
        print('获取今日预约错误: $e');
        return [];
      }
    });
  }

  // 添加预约
  Future<int> addAppointment(Appointment appointment) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return -1;
    
    return await _dbWrapper!.wrapOperation('addAppointment', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createAppointment(appointment);

        if (id > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markAppointmentsNeedRefresh();
          print('✅ 预约添加成功，已清除缓存并标记刷新');
        }

        return id;
      } catch (e) {
        print('添加预约失败: $e');
        rethrow;
      }
    });
  }

  // 更新预约
  Future<bool> updateAppointment(Appointment appointment) async {
    if (!initialized || appointment.id == null) {
      throw Exception('数据库未初始化或预约ID为空');
    }
    
    if (_dbWrapper == null) return false;
    
    return await _dbWrapper!.wrapOperation('updateAppointment', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updateAppointment(appointment);

        if (success) {
          // 清除缓存并标记需要刷新
          clearCache();
          markAppointmentsNeedRefresh();
          print('✅ 预约更新成功，已清除缓存并标记刷新');
        }

        return success;
      } catch (e) {
        print('更新预约失败: $e');
        rethrow;
      }
    });
  }

  // 删除预约
  Future<bool> deleteAppointment(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dbWrapper == null) return false;
    
    return await _dbWrapper!.wrapOperation('deleteAppointment', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deleteAppointment(id);

        if (success) {
          // 清除缓存并标记需要刷新
          clearCache();
          markAppointmentsNeedRefresh();
          print('✅ 预约删除成功，已清除缓存并标记刷新');
        }

        return success;
      } catch (e) {
        print('删除预约失败: $e');
        rethrow;
      }
    });
  }

  // 根据患者ID获取预约
  Future<List<Appointment>> getAppointmentsByPatientId(int patientId) async {
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getAppointmentsByPatientId', () async {
      try {
        // 使用数据源模式（统一接口）
        final doctorFilter = _getDoctorFilter();
        return await _currentDataSource.getAppointmentsByPatientId(patientId, doctorFilter: doctorFilter);
      } catch (e) {
        print('获取患者预约错误: $e');
        return [];
      }
    });
  }

  // 搜索预约
  Future<List<Appointment>> searchAppointments(String keyword) async {
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('searchAppointments', () async {
      try {
        // 使用数据源模式（统一接口）
        final doctorFilter = _getDoctorFilter();
        return await _currentDataSource.searchAppointments(keyword, doctorFilter: doctorFilter);
      } catch (e) {
        print('搜索预约错误: $e');
        return [];
      }
    });
  }

  // 根据日期范围获取预约
  Future<List<Appointment>> getAppointmentsByDateRange(DateTime startDate, DateTime endDate) async {
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getAppointmentsByDateRange', () async {
      try {
        // 使用数据源模式（统一接口）
        final doctorFilter = _getDoctorFilter();
        return await _currentDataSource.getAppointmentsByDateRange(startDate, endDate, doctorFilter: doctorFilter);
      } catch (e) {
        print('根据日期范围获取预约错误: $e');
        return [];
      }
    });
  }
  
  // 强制刷新预约数据缓存
  Future<void> forceRefreshAppointments() async {
    print('强制刷新预约数据缓存');
    _cachedAppointments = null;
    // 通知监听器
    notifyListeners();
  }
}


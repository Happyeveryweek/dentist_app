import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import '../utils/datetime_formatter.dart';
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
import '../providers/patient_provider.dart';
import '../providers/user_provider.dart';
import '../utils/pinyin_util.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import '../data_sources/appointment_data_source.dart';
import '../features/appointments/services/appointment_mysql_connection_service.dart';
import '../features/appointments/services/appointment_sync_service.dart';

/// 预约管理提供者
/// 负责处理所有与预约相关的数据库操作
class AppointmentProvider extends ChangeNotifier {
  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;

  // 数据源类型
  String _dataSourceType = 'sqlite';

  // 模块数据源配置
  Map<String, String>? _moduleDataSources;

  // 当前用户信息
  User? _currentUser;

  // 刷新标志
  bool _appointmentsNeedRefresh = false;

  // 缓存机制（类似其他模块）
  List<Appointment>? _cachedAppointments;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration =
      Duration(minutes: 20); // 预约数据缓存20分钟

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 患者提供者引用（用于获取患者信息）
  PatientProvider? _patientProvider;

  // 用户权限提供者引用
  UserProvider? _userProvider;

  // 数据源具体实现
  SqliteAppointmentDataSource? _sqliteDataSource;
  MySqlAppointmentDataSource? _mysqlDataSource;

  // 同步服务
  late final AppointmentSyncService _syncService;
  late final AppointmentMysqlConnectionService _mysqlConnectionService;

  // 连接状态
  bool _isConnected = true;
  String? _lastError;

  // Getters
  bool get initialized => _database != null || _mysqlConnection != null;
  String get dataSourceType => _effectiveDataSourceType;
  bool get appointmentsNeedRefresh => _appointmentsNeedRefresh;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  // 缓存相关getters
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedAppointmentsCount => _cachedAppointments?.length ?? 0;
  List<Appointment> get cachedAppointments => _cachedAppointments == null
      ? []
      : List.unmodifiable(_cachedAppointments!);

  // 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedAppointments != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  // 构造函数
  AppointmentProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
    User? currentUser,
    PatientProvider? patientProvider,
    UserProvider? userProvider,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
    _currentUser = currentUser;
    _patientProvider = patientProvider;
    _userProvider = userProvider;
    _patientProvider = patientProvider;

    _mysqlConnectionService = AppointmentMysqlConnectionService(
      getDatabaseProvider: () => _databaseProvider,
      getCachedConnection: () => _mysqlConnection,
      setCachedConnection: (connection) {
        _mysqlConnection = connection;
      },
      getEffectiveDataSourceType: () => _effectiveDataSourceType,
    );

    _syncService = AppointmentSyncService(
      getSyncMysqlConnection: () => _mysqlConnectionService.getSyncConnection(),
      getEffectiveDataSourceType: () => _effectiveDataSourceType,
    );
  }

  // 设置数据库连接
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
    PatientProvider? patientProvider,
  }) {
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) _currentUser = currentUser;
    if (patientProvider != null) _patientProvider = patientProvider;
  }

  // 标记刷新
  void markAppointmentsNeedRefresh() {
    _appointmentsNeedRefresh = true;
    notifyListeners();
  }

  // 重置刷新标志
  void resetAppointmentsRefreshFlag() {
    _appointmentsNeedRefresh = false;
  }

  // 设置患者提供者
  void setPatientProvider(PatientProvider patientProvider) {
    _patientProvider = patientProvider;

    // 将PatientProvider传递给已初始化的数据源
    if (_sqliteDataSource != null) {
      _sqliteDataSource!.setPatientProvider(patientProvider);
    }
    if (_mysqlDataSource != null) {
      _mysqlDataSource!.setPatientProvider(patientProvider);
    }

    print('✅ AppointmentProvider已设置PatientProvider并传递给数据源');
  }

  // 设置用户权限提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;

    // 清除缓存，强制重新加载数据以应用权限过滤
    clearCache();

    print('✅ AppointmentProvider已设置UserProvider引用，权限过滤已启用');
  }

  // 获取有效的数据源类型（考虑模块化配置）
  String get _effectiveDataSourceType {
    if (_moduleDataSources != null &&
        _moduleDataSources!.containsKey('appointments')) {
      return _moduleDataSources!['appointments']!;
    }
    return _dataSourceType;
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqliteAppointmentDataSource(database);
    // 如果已有PatientProvider，立即设置
    if (_patientProvider != null) {
      _sqliteDataSource!.setPatientProvider(_patientProvider!);
    }
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlConnection = connection;
    _mysqlDataSource = MySqlAppointmentDataSource.withConnectionGetter(
      () async {
        final conn = await _mysqlConnectionService.getCurrentConnection();
        return conn;
      },
      reconnectCallback: () async {
        try {
          await _mysqlConnectionService.reconnectConnection();
          print('✅ AppointmentProvider: MySQL重连成功');
        } catch (e) {
          print('❌ AppointmentProvider: MySQL重连失败: $e');
        }
      },
    );
    // 如果已有PatientProvider，立即设置
    if (_patientProvider != null) {
      _mysqlDataSource!.setPatientProvider(_patientProvider!);
    }
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  AppointmentDataSource get _currentDataSource {
    final effectiveType = _effectiveDataSourceType;
    if (effectiveType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL预约数据源未初始化 - 模块配置要求使用MySQL但数据源未设置');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite预约数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  // 测试MySQL连接是否有效
  Future<bool> _testMySqlConnection() async {
    final success = await _mysqlConnectionService.testCurrentConnection();
    if (success) {
      _isConnected = true;
      _clearError();
      return true;
    }

    _setError('MySQL连接测试失败');
    return false;
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

  // 更新缓存
  void _updateCache(List<Appointment> appointments) {
    _cachedAppointments = List.from(appointments);
    _lastCacheTime = DateTime.now();
  }

  // 清除缓存
  void clearCache() {
    _cachedAppointments = null;
    _lastCacheTime = null;
    _appointmentsNeedRefresh = true; // 标记需要刷新
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 智能初始化（支持模块化配置）
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    PatientProvider? patientProvider,
    UserProvider? userProvider,
  }) async {
    try {
      print('🔧 AppointmentProvider.initializeFromDatabase 开始初始化');
      print('🔧 AppointmentProvider - 数据源模式: $dataSourceMode');
      print('🔧 AppointmentProvider - 模块配置: $moduleDataSources');
      print('🔧 AppointmentProvider - 全局数据源类型: ${dbProvider?.dataSourceType}');

      // 保存数据库提供者引用
      _databaseProvider = dbProvider;

      // 保存患者提供者引用
      if (patientProvider != null) {
        _patientProvider = patientProvider;
        print('🔧 AppointmentProvider已设置PatientProvider引用');
      }

      // 保存用户权限提供者引用
      if (userProvider != null) {
        _userProvider = userProvider;
        print('🔧 AppointmentProvider已设置UserProvider引用');
      }

      // 保存模块配置
      _moduleDataSources = moduleDataSources;

      // 确定要使用的数据源类型
      String dbType = 'sqlite';

      // 如果是模块化模式且有预约模块配置，优先使用模块配置
      if (dataSourceMode == 'modular' &&
          moduleDataSources != null &&
          moduleDataSources.containsKey('appointments')) {
        dbType = moduleDataSources['appointments']!;
        print('🔧 AppointmentProvider使用模块化配置: appointments -> $dbType');
      } else {
        // 否则使用全局配置
        dbType = dbProvider?.dataSourceType ?? 'sqlite';
        print('🔧 AppointmentProvider使用全局配置: $dbType');
      }

      // 更新数据源类型
      _dataSourceType = dbType;

      // 一次性初始化正确的数据源
      if (dbType == 'sqlite') {
        final database = dbProvider?.database;
        if (database != null) {
          _database = database;
          setSqliteDataSource(database);
        } else {
          throw Exception('SQLite数据库连接不可用');
        }
      } else if (dbType == 'mysql') {
        final mysqlConnection = dbProvider?.mysqlConnection;
        if (mysqlConnection != null) {
          _mysqlConnection = mysqlConnection;
          setMySqlDataSource(mysqlConnection);

          // 测试MySQL连接
          final isConnected = await _testMySqlConnection();
          if (isConnected) {
            print('AppointmentProvider: MySQL数据源初始化完成');
          } else {
            print('⚠️ AppointmentProvider: MySQL连接测试失败，自动降级到SQLite');

            // 修改数据源类型（同时修改基础类型和模块配置）
            _dataSourceType = 'sqlite';
            if (_moduleDataSources != null &&
                _moduleDataSources!.containsKey('appointments')) {
              _moduleDataSources!['appointments'] = 'sqlite';
            }

            // 降级到SQLite
            final database = dbProvider?.database;
            if (database != null) {
              _database = database;
              setSqliteDataSource(database);
              print('AppointmentProvider: 已降级到SQLite数据源');
            } else {
              throw Exception('SQLite数据库连接不可用');
            }
          }
        } else {
          // MySQL连接不可用，自动降级到SQLite
          print('⚠️ AppointmentProvider: MySQL连接不可用，自动降级到SQLite');

          // 修改数据源类型（同时修改基础类型和模块配置）
          _dataSourceType = 'sqlite';
          if (_moduleDataSources != null &&
              _moduleDataSources!.containsKey('appointments')) {
            _moduleDataSources!['appointments'] = 'sqlite';
          }

          // 降级到SQLite
          final database = dbProvider?.database;
          if (database != null) {
            _database = database;
            setSqliteDataSource(database);
            print('AppointmentProvider: 已降级到SQLite数据源');
          } else {
            throw Exception('SQLite数据库连接不可用');
          }
        }
      }

      // 如果已有PatientProvider，确保传递给数据源
      if (_patientProvider != null) {
        if (_sqliteDataSource != null) {
          _sqliteDataSource!.setPatientProvider(_patientProvider!);
        }
        if (_mysqlDataSource != null) {
          _mysqlDataSource!.setPatientProvider(_patientProvider!);
        }
        print('✅ AppointmentProvider已将PatientProvider传递给数据源');
      }

      // 清除缓存，强制重新加载数据
      clearCache();
    } catch (e) {
      print('❌ AppointmentProvider初始化失败: $e');
      _setError('预约数据源初始化失败: $e');
      rethrow;
    }
  }

  // =================== 预约相关方法 ===================

  // 通过PatientProvider获取患者信息
  Future<Patient?> getPatientForAppointment(int patientId) async {
    if (_patientProvider == null) {
      print('⚠️ PatientProvider未设置，无法获取患者信息');
      return null;
    }

    try {
      return await _patientProvider!.getPatient(patientId);
    } catch (e) {
      print('通过PatientProvider获取患者信息失败: $e');
      return null;
    }
  }

  // 获取患者的预约（使用数据源架构）
  Future<List<Appointment>> getAppointmentsByPatient(int patientId) async {
    try {
      return await _currentDataSource.getAppointmentsByPatient(patientId);
    } catch (e) {
      print('获取患者预约失败: $e');
      _setError('获取患者预约失败: $e');
      return [];
    }
  }

  // 辅助方法：格式化日期时间
  String _formatDateTime(DateTime dateTime) {
    return DateTimeFormatter.toDbString(dateTime);
  }

  // 辅助方法：从DateTime中提取时间字符串 (HH:MM:SS)
  String _extractTimeFromDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // 根据日期获取预约（使用数据源架构，支持权限过滤）
  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    try {
      List<Appointment> appointments =
          await _currentDataSource.getAppointmentsByDate(date);

      // 应用权限过滤
      appointments = await _applyPermissionFilter(appointments);

      return appointments;
    } catch (e) {
      print('根据日期获取预约失败: $e');
      _setError('获取预约失败: $e');
      return [];
    }
  }

  // 获取所有预约（使用缓存机制和数据源架构，支持权限过滤）
  Future<List<Appointment>> getAllAppointments(
      {bool forceRefresh = false}) async {
    try {
      // 检查缓存是否有效
      if (!forceRefresh && _isCacheValid()) {
        return List.from(_cachedAppointments!);
      }

      // 从数据源获取数据
      List<Appointment> appointments =
          await _currentDataSource.getAllAppointments();

      // 应用权限过滤
      appointments = await _applyPermissionFilter(appointments);

      // 更新缓存
      _updateCache(appointments);

      // 重置刷新标志
      _appointmentsNeedRefresh = false;

      return appointments;
    } catch (e) {
      print('获取预约数据失败: $e');
      _setError('获取预约数据失败: $e');

      // 如果有缓存数据，返回缓存（优雅降级）
      if (_cachedAppointments != null) {
        print('使用缓存数据作为降级方案: ${_cachedAppointments!.length} 条记录');
        return List.from(_cachedAppointments!);
      }

      return [];
    }
  }

  // 添加预约（使用数据源架构）
  Future<int> addAppointment(Appointment appointment) async {
    try {
      final id = await _currentDataSource.createAppointment(appointment);
      if (id > 0) {
        await getAllAppointments(forceRefresh: true);
        notifyListeners();

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync) {
          final appointmentMap = appointment.toMap();
          appointmentMap['id'] = id; // 确保包含ID
          _syncService.syncAppointmentToMySQL(appointmentMap, id);
        }
      }
      return id;
    } catch (e) {
      print('添加预约失败: $e');
      _setError('添加预约失败: $e');
      rethrow;
    }
  }

  // 更新预约（使用数据源架构）
  Future<int> updateAppointment(Appointment appointment) async {
    if (appointment.id == null) {
      throw Exception('更新预约时必须提供ID');
    }

    try {
      final success = await _currentDataSource.updateAppointment(appointment);
      if (success) {
        await getAllAppointments(forceRefresh: true);
        notifyListeners();

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync) {
          final appointmentMap = appointment.toMap();
          _syncService.syncAppointmentToMySQL(appointmentMap, appointment.id!);
        }

        return 1;
      }
      return 0;
    } catch (e) {
      print('更新预约失败: $e');
      _setError('更新预约失败: $e');
      rethrow;
    }
  }

  // 删除预约（使用数据源架构）
  Future<void> deleteAppointment(int appointmentId) async {
    try {
      final success = await _currentDataSource.deleteAppointment(appointmentId);
      if (success) {
        await getAllAppointments(forceRefresh: true);
        notifyListeners();
        print('预约删除成功');

        // 如果当前使用的是SQLite数据源，需要同步删除到MySQL
        if (_syncService.needsSync) {
          _syncService.syncDeleteAppointmentToMySQL(appointmentId);
        }
      } else {
        throw Exception('删除预约失败：未找到指定预约');
      }
    } catch (e) {
      print('删除预约失败: $e');
      _setError('删除预约失败: $e');
      rethrow;
    }
  }

  // 辅助方法：解析日期时间
  DateTime? _parseDateTime(dynamic dateValue) {
    if (dateValue == null) return null;
    if (dateValue is DateTime) return dateValue;
    if (dateValue is String) {
      try {
        return DateTimeFormatter.fromDbString(dateValue);
      } catch (e) {
        print('解析日期失败: $e');
        return null;
      }
    }
    return null;
  }

  // 获取当前用户 - 兼容原有接口
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    // 从数据库中获取当前登录用户信息
    return _currentUser;
  }

  // 获取今日预约（使用数据源架构）
  Future<List<Appointment>> getTodayAppointments({String? doctorName}) async {
    try {
      return await _currentDataSource.getTodayAppointments(
          doctorName: doctorName);
    } catch (e) {
      print('获取今日预约失败: $e');
      _setError('获取今日预约失败: $e');
      return [];
    }
  }

  // 获取特定医生的所有预约（使用数据源架构）
  Future<List<Appointment>> getAppointmentsByDoctor(String doctorName) async {
    try {
      List<Appointment> appointments =
          await _currentDataSource.getAppointmentsByDoctor(doctorName);

      // 应用权限过滤
      appointments = await _applyPermissionFilter(appointments);

      return appointments;
    } catch (e) {
      print('获取医生预约失败: $e');
      _setError('获取医生预约失败: $e');
      return [];
    }
  }

  // =================== 权限过滤方法 ===================

  // 应用权限过滤（通过患者医生字段过滤预约）
  Future<List<Appointment>> _applyPermissionFilter(
      List<Appointment> appointments) async {
    try {
      // 如果没有用户权限提供者或当前用户是管理员，不进行过滤
      if (_userProvider == null || _userProvider!.currentUser == null) {
        return appointments;
      }

      final currentUser = _userProvider!.currentUser!;
      if (currentUser.isAdmin) {
        return appointments;
      }

      // 获取当前用户的医生字段
      final doctorName = currentUser.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回空列表
        print('当前用户没有医生字段，返回空预约列表');
        return [];
      }

      // 过滤预约：只显示患者医生字段匹配的预约
      List<Appointment> filteredAppointments = [];

      for (final appointment in appointments) {
        if (appointment.patientId != null) {
          // 通过患者提供者获取患者信息
          if (_patientProvider != null) {
            final patient =
                await _patientProvider!.getPatient(appointment.patientId!);
            if (patient != null && patient.doctor == doctorName) {
              filteredAppointments.add(appointment);
            }
          }
        }
      }

      return filteredAppointments;
    } catch (e) {
      print('应用权限过滤失败: $e');
      // 出错时返回空列表，确保安全
      return [];
    }
  }

  // =================== 新增数据源架构方法 ===================

  // 分页获取预约
  Future<List<Appointment>> getPaginatedAppointments({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'appointment_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? filterDate,
    String? filterDoctor,
  }) async {
    try {
      return await _currentDataSource.getPaginatedAppointments(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
        filterDate: filterDate,
        filterDoctor: filterDoctor,
      );
    } catch (e) {
      print('分页获取预约失败: $e');
      _setError('分页获取预约失败: $e');
      return [];
    }
  }

  // 获取预约总数
  Future<int> getAppointmentsCount({String? searchQuery}) async {
    try {
      return await _currentDataSource.getAppointmentsCount(
          searchQuery: searchQuery);
    } catch (e) {
      print('获取预约总数失败: $e');
      _setError('获取预约总数失败: $e');
      return 0;
    }
  }

  // 获取预约统计信息
  Future<Map<String, dynamic>> getAppointmentStatistics() async {
    try {
      return await _currentDataSource.getAppointmentStatistics();
    } catch (e) {
      print('获取预约统计信息失败: $e');
      _setError('获取预约统计信息失败: $e');
      return {
        'totalAppointments': 0,
        'statusStatistics': <String, int>{},
        'todayAppointments': 0,
      };
    }
  }

  // 根据ID获取预约
  Future<Appointment?> getAppointmentById(int id) async {
    try {
      return await _currentDataSource.getAppointmentById(id);
    } catch (e) {
      print('根据ID获取预约失败: $e');
      _setError('获取预约失败: $e');
      return null;
    }
  }

  // 创建预约（使用数据源架构）
  Future<int> createAppointment(Appointment appointment) async {
    try {
      final id = await _currentDataSource.createAppointment(appointment);
      if (id > 0) {
        await getAllAppointments(forceRefresh: true);
        notifyListeners();
      }
      return id;
    } catch (e) {
      print('创建预约失败: $e');
      _setError('创建预约失败: $e');
      return 0;
    }
  }

  // 模块数据源配置更新（向后兼容）
  void updateModuleDataSources(Map<String, String>? moduleDataSources) {
    _moduleDataSources = moduleDataSources;
    print('AppointmentProvider模块数据源配置已更新: $moduleDataSources');

    // 如果有模块配置且当前是模块化模式，重新初始化数据源
    if (moduleDataSources != null &&
        moduleDataSources.containsKey('appointments') &&
        _databaseProvider != null) {
      final newDataSourceType = moduleDataSources['appointments']!;
      if (newDataSourceType != _dataSourceType) {
        print('预约模块数据源类型变更: $_dataSourceType -> $newDataSourceType');

        // 重新初始化数据源
        initializeFromDatabase(
          _databaseProvider,
          moduleDataSources: moduleDataSources,
          dataSourceMode: 'modular',
        );
      }
    }
  }
}

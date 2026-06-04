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
import '../features/appointments/providers/appointment_cache_mixin.dart';
import '../features/appointments/providers/appointment_database_mixin.dart';
import '../features/appointments/providers/appointment_permission_mixin.dart';
import '../features/appointments/services/appointment_initialization_service.dart';

// 预约管理提供者，用于管理应用程序与预约相关的数据库操作
class AppointmentsProvider extends ChangeNotifier with AppointmentCacheMixin, AppointmentDatabaseMixin, AppointmentPermissionMixin {
  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;
  final AppointmentInitializationService _initializationService = AppointmentInitializationService();

  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;

  // Getters
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  String? get lastError => _lastError;

  // 从DatabaseProvider获取数据库连接（保持向后兼容）
  Future<void> initializeFromDatabase(dynamic dbProvider, {UserProvider? userProvider}) async {
    if (isInitializedFlag) return;

    try {
      print('AppointmentsProvider开始初始化...');

      // 保存DatabaseProvider引用
      databaseProvider = dbProvider;

      // 保存UserProvider引用
      this.userProvider = userProvider;

      final result = await _initializationService.initializeFromDatabase(
        dbProvider: dbProvider,
      );

      database = result.database;
      mysqlConnection = result.mysqlConnection;
      dataSourceType = result.dataSourceType;
      if (dataSourceType == 'mysql' && mysqlConnection != null) {
        setMySqlDataSource(mysqlConnection!);
      } else if (database != null) {
        setSqliteDataSource(database!);
      }

      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);

      isInitializedFlag = result.initialized;
      print('AppointmentsProvider初始化完成');
    } catch (e) {
      print('AppointmentsProvider初始化失败: $e');
      // 设置默认值，但不标记为已初始化
      dataSourceType = 'sqlite';
      isInitializedFlag = false;
    }
    
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
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
      return cachedAppointments ?? []; // 优雅降级而不是抛出异常
    }

    if (_dbWrapper == null) return cachedAppointments ?? [];
    
    return await _dbWrapper!.wrapOperation('getAllAppointments', () async {
      try {
        // 优先检查缓存
        if (isCacheValid()) {
          print('使用缓存的预约数据: ${cachedAppointments!.length} 条');
          return cachedAppointments!;
        }

        print('🔄 从数据库获取最新预约数据...');
        List<Appointment> appointments = [];

        // 使用数据源模式（统一接口）
        // Android端：不过滤查看权限，所有用户都能查看所有数据
        appointments = await currentDataSource.getAllAppointments(doctorFilter: null);


        // 更新缓存
        updateCache(appointments);
        print('✅ 预约数据缓存已更新');
        return appointments;
      } catch (e) {
        print('❌ 获取预约数据失败: $e');

        // 优雅降级：如果有缓存就返回缓存，否则返回空列表
        if (isCacheValid()) {
          print('使用缓存的预约数据，查询失败: $e');
          return cachedAppointments!;
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
        final count = await currentDataSource.getAppointmentsCount(doctorFilter: null);

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
        return await currentDataSource.getAppointmentsByDateRange(startDate, endDate, doctorFilter: null);
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
        final id = await currentDataSource.createAppointment(appointment);

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
        final success = await currentDataSource.updateAppointment(appointment);

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
        final success = await currentDataSource.deleteAppointment(id);

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
        final doctorFilter = getDoctorFilter();
        return await currentDataSource.getAppointmentsByPatientId(patientId, doctorFilter: doctorFilter);
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
        final doctorFilter = getDoctorFilter();
        return await currentDataSource.searchAppointments(keyword, doctorFilter: doctorFilter);
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
        final doctorFilter = getDoctorFilter();
        return await currentDataSource.getAppointmentsByDateRange(startDate, endDate, doctorFilter: doctorFilter);
      } catch (e) {
        print('根据日期范围获取预约错误: $e');
        return [];
      }
    });
  }
}

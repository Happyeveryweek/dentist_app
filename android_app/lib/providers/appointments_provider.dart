import 'package:flutter/foundation.dart';
import '../models/database_models.dart';
import '../utils/database_operation_wrapper.dart';
import 'user_provider.dart'; // 导入UserProvider用于权限检查
import '../features/appointments/providers/appointment_cache_mixin.dart';
import '../features/appointments/providers/appointment_database_mixin.dart';
import '../features/appointments/providers/appointment_permission_mixin.dart';
import '../features/appointments/services/appointment_initialization_service.dart';
import '../utils/app_logger.dart';

// 预约管理提供者，用于管理应用程序与预约相关的数据库操作
class AppointmentsProvider extends ChangeNotifier
    with
        AppointmentCacheMixin,
        AppointmentDatabaseMixin,
        AppointmentPermissionMixin {
  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;
  final AppointmentInitializationService _initializationService =
      AppointmentInitializationService();

  // 连接状态
  final bool _isConnected = true;
  final bool _isReconnecting = false;
  String? _lastError;

  // Getters
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  String? get lastError => _lastError;

  // 从DatabaseProvider获取数据库连接（保持向后兼容）
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    UserProvider? userProvider,
  }) async {
    if (isInitializedFlag) return;

    try {
      AppLogger.info('AppointmentsProvider开始初始化...');

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
      final conn = mysqlConnection;
      final db = database;
      if (dataSourceType == 'mysql' && conn != null) {
        setMySqlDataSource(conn);
      } else if (db != null) {
        setSqliteDataSource(db);
      }

      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);

      isInitializedFlag = result.initialized;
      AppLogger.info('AppointmentsProvider初始化完成');
    } catch (e) {
      AppLogger.info('AppointmentsProvider初始化失败: $e');
      // 设置默认值，但不标记为已初始化
      dataSourceType = 'sqlite';
      isInitializedFlag = false;
    }

    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 获取所有预约（带缓存）
  Future<List<Appointment>> getAllAppointments() async {
    if (!hasAppointmentAccess) return [];
    if (!initialized) {
      return cachedAppointments ?? []; // 优雅降级而不是抛出异常
    }

    final wrapper = _dbWrapper;
    final cached = cachedAppointments;
    if (wrapper == null) return cached ?? [];

    return await wrapper.wrapOperation('getAllAppointments', () async {
      try {
        // 优先检查缓存
        if (isCacheValid() && cached != null) {
          AppLogger.info('使用缓存的预约数据: ${cached.length} 条');
          return cached;
        }

        AppLogger.info('🔄 从数据库获取最新预约数据...');
        List<Appointment> appointments = [];

        appointments = await currentDataSource.getAllAppointments(
          doctorFilter: getDoctorFilter(),
        );

        // 更新缓存
        updateCache(appointments);
        AppLogger.info('✅ 预约数据缓存已更新');
        return appointments;
      } catch (e) {
        AppLogger.info('❌ 获取预约数据失败: $e');
        if (_isConnectionError(e)) rethrow;

        // 优雅降级：如果有缓存就返回缓存，否则返回空列表
        if (isCacheValid() && cached != null) {
          AppLogger.info('使用缓存的预约数据，查询失败: $e');
          return cached;
        }

        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('broken pipe') ||
        errorString.contains('connection reset') ||
        errorString.contains('closed') ||
        errorString.contains('disconnected') ||
        errorString.contains('cannot write to socket') ||
        errorString.contains('bad state');
  }

  // 获取预约总数
  Future<int> getAppointmentCount() async {
    if (!hasAppointmentAccess) return 0;
    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('getAppointmentCount', () async {
      try {
        AppLogger.info('正在获取预约总数...');

        final count = await currentDataSource.getAppointmentsCount(
          doctorFilter: getDoctorFilter(),
        );

        return count;
      } catch (e) {
        AppLogger.info('获取预约总数错误: $e');
        return 0;
      }
    });
  }

  // 获取今日预约
  Future<List<Appointment>> getTodayAppointments() async {
    if (!hasAppointmentAccess) return [];
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getTodayAppointments', () async {
      try {
        final today = DateTime.now();
        final startDate = DateTime(today.year, today.month, today.day);
        final endDate = DateTime(
          today.year,
          today.month,
          today.day,
          23,
          59,
          59,
        );

        return await currentDataSource.getAppointmentsByDateRange(
          startDate,
          endDate,
          doctorFilter: getDoctorFilter(),
        );
      } catch (e) {
        AppLogger.info('获取今日预约错误: $e');
        return [];
      }
    });
  }

  // 添加预约
  Future<int> addAppointment(Appointment appointment) async {
    if (!hasAppointmentAccess) return -1;
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return -1;

    return await wrapper.wrapOperation('addAppointment', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await currentDataSource.createAppointment(appointment);

        if (id > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markAppointmentsNeedRefresh();
          AppLogger.info('✅ 预约添加成功，已清除缓存并标记刷新');
        }

        return id;
      } catch (e) {
        AppLogger.info('添加预约失败: $e');
        rethrow;
      }
    });
  }

  // 更新预约
  Future<bool> updateAppointment(Appointment appointment) async {
    if (!hasAppointmentAccess) return false;
    if (!initialized || appointment.id == null) {
      throw Exception('数据库未初始化或预约ID为空');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return false;

    return await wrapper.wrapOperation('updateAppointment', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await currentDataSource.updateAppointment(appointment);

        if (success) {
          // 清除缓存并标记需要刷新
          clearCache();
          markAppointmentsNeedRefresh();
          AppLogger.info('✅ 预约更新成功，已清除缓存并标记刷新');
        }

        return success;
      } catch (e) {
        AppLogger.info('更新预约失败: $e');
        rethrow;
      }
    });
  }

  // 删除预约
  Future<bool> deleteAppointment(int id) async {
    if (!hasAppointmentAccess) return false;
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return false;

    return await wrapper.wrapOperation('deleteAppointment', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await currentDataSource.deleteAppointment(id);

        if (success) {
          // 清除缓存并标记需要刷新
          clearCache();
          markAppointmentsNeedRefresh();
          AppLogger.info('✅ 预约删除成功，已清除缓存并标记刷新');
        }

        return success;
      } catch (e) {
        AppLogger.info('删除预约失败: $e');
        rethrow;
      }
    });
  }

  // 根据患者ID获取预约
  Future<List<Appointment>> getAppointmentsByPatientId(int patientId) async {
    if (!hasAppointmentAccess) return [];
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getAppointmentsByPatientId', () async {
      try {
        // 使用数据源模式（统一接口）
        final doctorFilter = getDoctorFilter();
        return await currentDataSource.getAppointmentsByPatientId(
          patientId,
          doctorFilter: doctorFilter,
        );
      } catch (e) {
        AppLogger.info('获取患者预约错误: $e');
        return [];
      }
    });
  }

  // 搜索预约
  Future<List<Appointment>> searchAppointments(String keyword) async {
    if (!hasAppointmentAccess) return [];
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('searchAppointments', () async {
      try {
        // 使用数据源模式（统一接口）
        final doctorFilter = getDoctorFilter();
        return await currentDataSource.searchAppointments(
          keyword,
          doctorFilter: doctorFilter,
        );
      } catch (e) {
        AppLogger.info('搜索预约错误: $e');
        return [];
      }
    });
  }

  // 根据日期范围获取预约
  Future<List<Appointment>> getAppointmentsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!hasAppointmentAccess) return [];
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getAppointmentsByDateRange', () async {
      try {
        // 使用数据源模式（统一接口）
        final doctorFilter = getDoctorFilter();
        return await currentDataSource.getAppointmentsByDateRange(
          startDate,
          endDate,
          doctorFilter: doctorFilter,
        );
      } catch (e) {
        AppLogger.info('根据日期范围获取预约错误: $e');
        return [];
      }
    });
  }
}

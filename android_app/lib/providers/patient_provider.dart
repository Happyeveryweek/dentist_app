import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/database_models.dart';
import 'package:sqflite/sqflite.dart';
import '../utils/database_operation_wrapper.dart';
import '../data_sources/patient_data_source.dart'
    hide SqlitePatientDataSource, MySqlPatientDataSource;
import 'dart:async';
import 'user_provider.dart';
import '../features/patients/services/patient_initialization_service.dart';
import '../features/patients/services/patient_export_service.dart';
import '../features/patients/helpers/patient_cache_helper.dart';
import '../features/patients/services/patient_deletion_service.dart';
import '../utils/app_logger.dart';

// 患者管理提供者，专门处理患者相关的状态管理和流程编排
class PatientProvider extends ChangeNotifier {
  // 初始化服务
  final PatientInitializationService _initService =
      PatientInitializationService();
  final PatientDeletionService _deletionService = PatientDeletionService();

  // 导出服务
  PatientExportService? _exportService;

  // 缓存助手
  final PatientCacheHelper _cacheHelper = PatientCacheHelper();
  UserProvider? _userProvider;

  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;

  // 初始化标志
  bool initialized = false;

  // 设置数据源类型
  void setDataSourceType(String dataSourceType) {
    _initService.setDataSourceType(dataSourceType);
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

  // 获取当前数据源（必须可用，否则抛出异常）
  PatientDataSource get _currentDataSource {
    return _initService.currentDataSource;
  }

  // 统一的数据库初始化方法
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    UserProvider? userProvider,
  }) async {
    if (initialized) return;

    try {
      AppLogger.info('PatientProvider 开始初始化...');

      // 使用初始化服务
      final success = await _initService.initializeFromDatabase(dbProvider);
      if (success) {
        // 初始化导出服务
        _exportService = PatientExportService(_initService.dataSourceType);

        // 初始化数据库操作包装器
        _dbWrapper = DatabaseOperationWrapper(dbProvider);

        initialized = true;
        AppLogger.info('PatientProvider 初始化完成');
      } else {
        initialized = false;
      }
    } catch (e) {
      AppLogger.info('PatientProvider 初始化失败: $e');
      initialized = false;
    }
  }

  // 设置UserProvider引用
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    _cacheHelper.clearCache();
  }

  bool get _hasPatientAccess {
    final user = _userProvider?.currentUser;
    return user?.role == 'admin' ||
        (user?.role == 'doctor' && user?.doctor?.isNotEmpty == true);
  }

  bool _canAccessPatient(Patient patient) {
    final user = _userProvider?.currentUser;
    return user?.role == 'admin' ||
        (user?.role == 'doctor' &&
            user?.doctor?.isNotEmpty == true &&
            patient.doctor == user?.doctor);
  }

  List<Patient> _filterPatients(List<Patient> patients) =>
      patients.where(_canAccessPatient).toList();

  // 获取数据源类型
  String get dataSourceType => _initService.dataSourceType;

  Patient? getCachedPatientById(int id) =>
      _cacheHelper.getCachedPatientById(id);

  // 强制刷新患者数据
  Future<void> forceRefreshPatients() async {
    _cacheHelper.clearCache();
    _safeNotifyListeners();
  }

  // 导出患者表
  Future<String> exportPatientsTable(String destinationDir) async {
    final service = _exportService;
    if (service == null) {
      throw Exception('导出服务未初始化');
    }
    return await service.exportPatientsTable(destinationDir);
  }

  // 使用SAF保存患者数据备份
  Future<String> savePatientBackupWithSaf(
    String jsonData,
    String fileName,
  ) async {
    final service = _exportService;
    if (service == null) {
      throw Exception('导出服务未初始化');
    }
    return await service.savePatientBackupWithSaf(jsonData, fileName);
  }

  // 获取所有患者（Android端不过滤查看权限）
  Future<List<Patient>> getAllPatients() async {
    if (!_hasPatientAccess) return [];
    final wrapper = _dbWrapper;
    final requestSessionRevision = _userProvider?.sessionRevision;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getAllPatients', () async {
      try {
        final cachedPatients = _cacheHelper.cachedPatients;
        if (_cacheHelper.hasCache() && cachedPatients != null) {
          // Android端：返回所有缓存数据，不过滤
          return _filterPatients(cachedPatients);
        }

        // 使用数据源模式（统一接口）
        final patients = await _currentDataSource.getAllPatients();

        if (requestSessionRevision != _userProvider?.sessionRevision) {
          return [];
        }

        _cacheHelper.setCachedPatients(patients); // 缓存数据
        return _filterPatients(patients);
      } catch (e) {
        AppLogger.info('获取所有患者失败: $e');
        AppLogger.info('错误堆栈: ${StackTrace.current}');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      }
    });
  }

  // 获取患者总数（Android端不过滤查看权限）
  Future<int> getPatientCount() async {
    if (!_hasPatientAccess) return 0;
    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('getPatientCount', () async {
      try {
        // Android端：所有用户都能查看所有数据，直接返回数据库总数
        return (await getAllPatients()).length;
      } catch (e) {
        AppLogger.info('获取患者总数错误: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return 0;
      }
    });
  }

  // 获取最大病历号
  Future<int> getMaxMedicalRecordNumber() async {
    try {
      AppLogger.info('正在获取最大病历号...');
      if (_initService.dataSourceType == 'sqlite') {
        final db = _initService.sqliteDataSource?.database;
        if (db != null) {
          final result = await db.rawQuery(
            'SELECT MAX(medical_record_number) as max_id FROM patients',
          );
          final maxId = Sqflite.firstIntValue(result) ?? 0;
          AppLogger.info('SQLite数据库中的最大病历号: $maxId');
          return maxId;
        }
      } else if (_initService.dataSourceType == 'mysql') {
        final conn = _initService.mysqlDataSource;
        if (conn != null) {
          // 这里需要从 MySQL 数据源获取连接，暂时跳过
          AppLogger.info('MySQL 数据源暂不支持获取最大病历号');
          return 0;
        }
      }

      // 如果无法获取数据，默认返回0，新病历号为1
      AppLogger.info('无法获取最大病历号，使用默认值0');
      return 0;
    } catch (e) {
      AppLogger.info('获取最大病历号错误: $e');
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
    if (!_hasPatientAccess) return [];
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getPatientsPage', () async {
      try {
        // 使用数据源模式（统一接口），传递排序参数
        final patients = await _currentDataSource.getPaginatedPatients(
          page,
          pageSize,
          sortField: sortField,
          ascending: ascending,
        );

        // Android端：不过滤查看权限，返回所有数据
        return _filterPatients(patients);
      } catch (e) {
        AppLogger.info('分页获取患者错误: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      }
    });
  }

  // 搜索患者（带权限过滤）
  Future<List<Patient>> searchPatients(String query) async {
    if (!_hasPatientAccess) return [];
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    // 统一在入口处trim，防止前后空格导致搜索失败
    final trimmedQuery = query.trim();

    return await wrapper.wrapOperation('searchPatients', () async {
      try {
        // 使用数据源模式（统一接口）
        final patients = await _currentDataSource.searchPatients(trimmedQuery);

        // Android端：不过滤查看权限，返回所有数据

        return _filterPatients(patients);
      } catch (e) {
        AppLogger.info('搜索患者错误: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      }
    });
  }

  // 根据ID获取患者
  Future<Patient?> getPatientById(int id) async {
    if (!_hasPatientAccess) return null;
    final cachedPatient = _cacheHelper.getCachedPatientById(id);
    if (cachedPatient != null) {
      return _canAccessPatient(cachedPatient) ? cachedPatient : null;
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return null;

    final requestSessionRevision = _userProvider?.sessionRevision;
    return await wrapper.wrapOperation('getPatientById', () async {
      try {
        // 使用数据源模式（统一接口）
        final patient = await _currentDataSource.getPatientById(id);
        if (requestSessionRevision != _userProvider?.sessionRevision) {
          return null;
        }
        if (patient != null) {
          _cacheHelper.cachePatient(patient);
        }
        return patient != null && _canAccessPatient(patient) ? patient : null;
      } catch (e) {
        AppLogger.info('根据ID获取患者失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return null;
      }
    });
  }

  // 添加患者
  Future<int> addPatient(Patient patient) async {
    if (!_hasPatientAccess) return -1;
    final user = _userProvider?.currentUser;
    final doctor = user?.doctor?.trim();
    if (doctor != null && doctor.isNotEmpty) {
      patient.doctor = doctor;
    }
    final wrapper = _dbWrapper;
    if (wrapper == null) return -1;

    return await wrapper.wrapOperation('addPatient', () async {
      try {
        // 使用数据源模式（统一接口）
        final result = await _currentDataSource.createPatient(patient);

        // 清除缓存
        _cacheHelper.clearCache();
        _safeNotifyListeners();
        return result;
      } catch (e) {
        AppLogger.info('添加患者失败: $e');
        rethrow;
      }
    });
  }

  // 更新患者
  Future<bool> updatePatient(Patient patient) async {
    if (!_hasPatientAccess || !_canAccessPatient(patient)) return false;
    final wrapper = _dbWrapper;
    if (wrapper == null) return false;

    return await wrapper.wrapOperation('updatePatient', () async {
      try {
        AppLogger.info('开始更新患者数据: ${patient.toMap()}');

        // 生成更新时间
        patient.updatedAt = DateTime.now();

        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updatePatient(patient);

        // 清除缓存
        if (success) {
          _cacheHelper.clearCache();
          _safeNotifyListeners();
        }

        return success;
      } catch (e) {
        AppLogger.info('更新患者错误: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return false;
      }
    });
  }

  // 删除患者
  Future<int> deletePatient(int id) async {
    final patient = await getPatientById(id);
    if (patient == null) return 0;
    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    final result = await _deletionService.deletePatient(
      patientId: id,
      initService: _initService,
      dbWrapper: wrapper,
      cacheHelper: _cacheHelper,
    );
    _safeNotifyListeners();
    return result;
  }
}

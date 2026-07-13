import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/patient_medical_record.dart';
import '../models/medical_record_template.dart';
import '../data_sources/medical_record_data_source.dart';
import '../data_sources/sqlite_medical_record_data_source.dart';
import '../data_sources/mysql_medical_record_data_source.dart';
import '../utils/database_operation_wrapper.dart';
import '../features/medical_records/services/medical_record_initialization_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../utils/app_logger.dart';

/// 病历管理提供者，专门处理病历相关的数据库操作
/// Android端专注于查看和PDF导出功能，不包含编辑权限控制
class MedicalRecordProvider extends ChangeNotifier {
  // 缓存数据
  List<MedicalRecordTemplate>? _cachedTemplates;

  // 数据源具体实现
  SqliteMedicalRecordDataSource? _sqliteDataSource;
  MySqlMedicalRecordDataSource? _mysqlDataSource;
  final MedicalRecordInitializationService _initializationService =
      MedicalRecordInitializationService();

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;

  // 数据库类型
  String _dataSourceType = 'sqlite'; // 默认使用sqlite

  // 初始化标志
  bool initialized = false;

  // 状态管理
  bool _isLoading = false;
  bool _hasError = false;
  String? _errorMessage;

  // 缓存时间管理
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Getters
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  String get dataSourceType => _dataSourceType;

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
    _sqliteDataSource = SqliteMedicalRecordDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
      () => _currentMysqlConnection,
    );
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  MedicalRecordDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      final dataSource = _mysqlDataSource;
      if (dataSource == null) {
        throw Exception('MySQL病历数据源未初始化');
      }
      return dataSource;
    } else {
      final dataSource = _sqliteDataSource;
      if (dataSource == null) {
        throw Exception('SQLite病历数据源未初始化');
      }
      return dataSource;
    }
  }

  // 获取最新的MySQL连接（防止连接过期）
  MySqlConnection? get _currentMysqlConnection {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
      return null;
    }

    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      return latestConnection;
    } catch (e) {
      AppLogger.info('获取最新MySQL连接失败: $e');
      return null;
    }
  }

  // 统一的数据库初始化方法
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (initialized) return;

    try {
      AppLogger.info('MedicalRecordProvider 开始初始化...');

      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;
      final result = await _initializationService.initializeFromDatabase(
        dbProvider: dbProvider,
      );

      _dataSourceType = result.dataSourceType;
      if (_dataSourceType == 'mysql') {
        _mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
          () => _currentMysqlConnection,
        );
        AppLogger.info('✅ MedicalRecordProvider MySQL数据源设置成功');
      } else {
        final db = result.database;
        if (db == null) {
          throw Exception('SQLite数据库实例为空');
        }
        _sqliteDataSource = SqliteMedicalRecordDataSource(db);
        AppLogger.info('✅ MedicalRecordProvider SQLite数据源设置成功');
      }

      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);
      initialized = result.initialized;

      AppLogger.info('MedicalRecordProvider 初始化完成');
    } catch (e) {
      AppLogger.info('MedicalRecordProvider 初始化失败: $e');
      initialized = false;
    }
  }

  // 设置加载状态
  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotifyListeners();
  }

  // 设置错误状态
  void _setError(String? error) {
    _hasError = error != null;
    _errorMessage = error;
    _safeNotifyListeners();
  }

  // 清除错误状态
  void clearError() {
    _hasError = false;
    _errorMessage = null;
    _safeNotifyListeners();
  }

  // 检查缓存是否有效
  bool _isCacheValid() {
    final lastCacheTime = _lastCacheTime;
    if (lastCacheTime == null) return false;
    return DateTime.now().difference(lastCacheTime) < _cacheValidDuration;
  }

  // 强制刷新缓存
  void forceRefresh() {
    _cachedTemplates = null;
    _lastCacheTime = null;
    _safeNotifyListeners();
  }

  // 获取患者的所有病历记录（带包装器，用于复杂操作）
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(
    int patientId,
  ) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getPatientMedicalRecords', () async {
      try {
        _setLoading(true);
        _setError(null);

        final records = await _currentDataSource.getPatientMedicalRecords(
          patientId,
        );

        _lastCacheTime = DateTime.now();

        return records;
      } catch (e) {
        AppLogger.info('获取患者病历记录失败: $e');
        _setError('获取病历记录失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      } finally {
        _setLoading(false);
      }
    });
  }

  // 简单获取患者病历记录（不使用包装器，像患者提供者的getPatientById一样）
  Future<List<PatientMedicalRecord>> getPatientMedicalRecordsSimple(
    int patientId,
  ) async {
    try {
      // 直接使用数据源，不触发连接管理
      return await _currentDataSource.getPatientMedicalRecords(patientId);
    } catch (e) {
      AppLogger.info('简单获取患者病历记录失败: $e');
      if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
      return [];
    }
  }

  // 获取单个病历记录
  Future<PatientMedicalRecord?> getMedicalRecord(int recordId) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return null;

    return await wrapper.wrapOperation('getMedicalRecord', () async {
      try {
        _setLoading(true);
        _setError(null);

        final record = await _currentDataSource.getMedicalRecord(recordId);
        return record;
      } catch (e) {
        AppLogger.info('获取病历记录失败: $e');
        _setError('获取病历记录失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return null;
      } finally {
        _setLoading(false);
      }
    });
  }

  // 检查患者是否有病历记录
  Future<bool> hasMedicalRecords(int patientId) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return false;

    return await wrapper.wrapOperation('hasMedicalRecords', () async {
      try {
        return await _currentDataSource.hasMedicalRecords(patientId);
      } catch (e) {
        AppLogger.info('检查患者病历记录失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return false;
      }
    });
  }

  // 获取病历模板
  Future<List<MedicalRecordTemplate>> getMedicalRecordTemplates() async {
    final wrapper = _dbWrapper;
    final cachedTemplates = _cachedTemplates;
    if (wrapper == null) return cachedTemplates ?? [];

    return await wrapper.wrapOperation('getMedicalRecordTemplates', () async {
      try {
        // 检查缓存
        if (cachedTemplates != null && _isCacheValid()) {
          return cachedTemplates;
        }

        _setLoading(true);
        _setError(null);

        final templates = await _currentDataSource.getMedicalRecordTemplates();

        // 更新缓存
        _cachedTemplates = templates;
        _lastCacheTime = DateTime.now();

        return templates;
      } catch (e) {
        AppLogger.info('获取病历模板失败: $e');
        _setError('获取病历模板失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      } finally {
        _setLoading(false);
      }
    });
  }

  // 根据类别获取病历模板
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(
    String category,
  ) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('getTemplatesByCategory', () async {
      try {
        _setLoading(true);
        _setError(null);

        final templates = await _currentDataSource.getTemplatesByCategory(
          category,
        );
        return templates;
      } catch (e) {
        AppLogger.info('获取分类病历模板失败: $e');
        _setError('获取分类病历模板失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      } finally {
        _setLoading(false);
      }
    });
  }

  // 初始化默认模板数据（如果数据库中没有模板数据）
  Future<void> initializeDefaultTemplates() async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return;

    await wrapper.wrapOperation('initializeDefaultTemplates', () async {
      try {
        _setLoading(true);
        _setError(null);

        // 检查是否已有模板数据
        final existingTemplates =
            await _currentDataSource.getMedicalRecordTemplates();
        if (existingTemplates.isNotEmpty) {
          AppLogger.info('模板数据已存在，跳过初始化');
          return;
        }

        AppLogger.info('开始初始化默认模板数据...');

        // 获取所有默认模板
        final defaultTemplates =
            DefaultTemplateInitializer.getAllDefaultTemplates();

        // 批量插入模板
        int insertedCount = 0;
        for (final template in defaultTemplates) {
          try {
            await _currentDataSource.createTemplate(template);
            insertedCount++;
          } catch (e) {
            AppLogger.info('插入模板失败: ${template.name}, 错误: $e');
          }
        }

        AppLogger.info('成功初始化 $insertedCount 个默认模板');

        // 清除缓存以便重新加载
        _cachedTemplates = null;
      } catch (e) {
        AppLogger.info('初始化默认模板失败: $e');
        _setError('初始化默认模板失败: $e');
      } finally {
        _setLoading(false);
      }
    });
  }

  // 获取牙科疾病模板
  Future<List<MedicalRecordTemplate>> getDentalDiseaseTemplates() async {
    return await getTemplatesByCategory(
      MedicalRecordTemplateCategory.dentalDisease,
    );
  }

  // 获取全身疾病模板
  Future<List<MedicalRecordTemplate>> getSystemicDiseaseTemplates() async {
    return await getTemplatesByCategory(
      MedicalRecordTemplateCategory.systemicDisease,
    );
  }

  // 获取过敏类型模板
  Future<List<MedicalRecordTemplate>> getAllergyTemplates() async {
    return await getTemplatesByCategory(MedicalRecordTemplateCategory.allergy);
  }

  // 清除所有缓存
  void clearAllCache() {
    _cachedTemplates = null;
    _lastCacheTime = null;
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    // 清理资源
    _cachedTemplates = null;
    super.dispose();
  }
}

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../models/patient.dart';
import '../models/patient_medical_record.dart';

import '../models/medical_record_template.dart';
import '../data_sources/medical_record_data_source.dart';
import '../features/medical_records/services/medical_record_sync_service.dart';
import '../features/medical_records/services/medical_record_template_service.dart';
import '../features/medical_records/services/medical_record_data_source_initializer.dart';
import '../features/medical_records/services/medical_record_permission_service.dart';
import '../features/medical_records/services/medical_record_service.dart';
import '../features/medical_records/helpers/medical_record_cache_helper.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../models/data_source.dart';
import '../utils/medical_record_pdf_exporter.dart';
import '../utils/log_manager.dart';

/// 病历管理提供者
/// 负责处理所有与患者病历相关的数据库操作和状态管理
/// 已升级为数据源架构 + 缓存机制 + MySQL动态连接获取
class MedicalRecordProvider extends ChangeNotifier {
  // 实例标识符，用于调试
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString();
  // 数据源实例
  SqliteMedicalRecordDataSource? _sqliteDataSource;
  MySqlMedicalRecordDataSource? _mysqlDataSource;

  // 同步服务
  MedicalRecordSyncService? _syncServiceInstance;
  MedicalRecordSyncService get _syncService =>
      _syncServiceInstance ??= MedicalRecordSyncService(
        getSyncMysqlConnection: () => _syncMysqlConnection,
        getEffectiveDataSourceType: () =>
            _effectiveDataSourceType ?? _dataSourceType,
      );

  // 模板管理服务
  MedicalRecordTemplateService? _templateServiceInstance;
  MedicalRecordTemplateService get _templateService =>
      _templateServiceInstance ??= MedicalRecordTemplateService(
        getCurrentDataSource: () => _currentDataSource,
        setLoading: _setLoading,
        clearError: _clearError,
        setError: _setError,
        notifyListeners: notifyListeners,
        markTemplatesNeedRefresh: markTemplatesNeedRefresh,
        syncService: _syncService,
      );

  // 数据源初始化服务
  MedicalRecordDataSourceInitializer? _dataSourceInitializerInstance;
  MedicalRecordDataSourceInitializer get _dataSourceInitializer =>
      _dataSourceInitializerInstance ??= MedicalRecordDataSourceInitializer(
        getDatabaseProvider: () => _databaseProvider,
        getUserProvider: () => _userProvider,
        getCurrentUser: () => _currentUser,
        setError: _setError,
        printLog: (message) => LogManager.w('MedicalRecordProvider', message),
      );

  // 权限检查服务
  MedicalRecordPermissionService? _permissionServiceInstance;
  MedicalRecordPermissionService get _permissionService =>
      _permissionServiceInstance ??= MedicalRecordPermissionService(
        getUserProvider: () => _userProvider,
        getCurrentUser: () => _currentUser,
        getMedicalRecordById: getMedicalRecordById,
      );

  // 病历记录管理服务
  MedicalRecordService? _medicalRecordServiceInstance;
  MedicalRecordService get _medicalRecordService =>
      _medicalRecordServiceInstance ??= MedicalRecordService(
        getCurrentDataSource: () => _currentDataSource,
        setLoading: _setLoading,
        clearError: _clearError,
        setError: _setError,
        notifyListeners: notifyListeners,
        syncService: _syncService,
        permissionService: _permissionService,
        cacheHelper: _cacheHelper,
      );

  // 缓存管理助手
  MedicalRecordCacheHelper? _cacheHelperInstance;
  MedicalRecordCacheHelper get _cacheHelper =>
      _cacheHelperInstance ??= MedicalRecordCacheHelper();

  // 用户权限提供者引用
  UserProvider? _userProvider;

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
  bool get initialized =>
      _currentDataSource != null ||
      _database != null ||
      _mysqlConnection != null;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  bool get isLoading => _isLoading;
  String get dataSourceType => _effectiveDataSourceType ?? _dataSourceType;
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  bool get templatesNeedRefresh => _templatesNeedRefresh;
  bool get hasValidTemplateCache => _cacheHelper.isTemplateCacheValid();
  int get cachedTemplatesCount => _cacheHelper.cachedTemplatesCount;

  // 检查数据源是否真正可用
  bool get isDataSourceReady {
    final dataSource = _currentDataSource;
    final ready = dataSource != null && _effectiveDataSourceType != null;
    LogManager.w('MedicalRecordProvider',
        'MedicalRecordProvider.isDataSourceReady: $ready (dataSource=${dataSource != null}, effectiveType=$_effectiveDataSourceType)');
    return ready;
  }

  // 获取当前数据源
  MedicalRecordDataSource? get _currentDataSource {
    final type = DataSourceType.tryParse(_effectiveDataSourceType);
    if (type == DataSourceType.mysql) {
      return _mysqlDataSource;
    } else if (type == DataSourceType.sqlite) {
      return _sqliteDataSource;
    }
    return null;
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
    return _dataSourceInitializer.getSyncMysqlConnection(
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
    LogManager.w(
        'MedicalRecordProvider', 'MedicalRecordProvider 实例创建: $_instanceId');

    // 服务实例通过 getter 懒加载
  }

  // 同步初始化方法（立即设置数据源）
  void initializeFromDatabaseSync(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    UserProvider? userProvider,
  }) {
    LogManager.w('MedicalRecordProvider',
        'MedicalRecordProvider($_instanceId).initializeFromDatabaseSync: 开始同步初始化');

    _databaseProvider = dbProvider;
    _userProvider = userProvider;

    final result = _dataSourceInitializer.initializeFromDatabaseSync(
      moduleDataSources: moduleDataSources,
      dataSourceMode: dataSourceMode,
      userProvider: userProvider,
      currentUser: _currentUser,
      onSqliteDataSourceReady: (dataSource) {
        _sqliteDataSource = dataSource;
      },
      onMysqlDataSourceReady: (dataSource) {
        _mysqlDataSource = dataSource;
      },
      onDatabaseReady: (database) {
        _database = database;
        _isConnected = true;
        _clearError();
        // 异步检查和创建表
        _ensureTablesExistAsync(database);
      },
      onMysqlConnectionReady: (connection) {
        _mysqlConnection = connection;
        _isConnected = true;
        _clearError();
      },
      onDataSourceTypeChanged: (dataSourceType) {
        _effectiveDataSourceType = dataSourceType;
      },
    );

    if (result.success) {
      // 清除缓存，强制重新加载
      _cacheHelper.clearAllCache();
      LogManager.i('MedicalRecordProvider',
          'MedicalRecordProvider($_instanceId).initializeFromDatabaseSync: 同步初始化完成');
    } else {
      _setError(result.error ?? '初始化失败');
    }
  }

  // 异步检查和创建表
  Future<void> _ensureTablesExistAsync(Database database) async {
    try {
      await _ensureTablesExist();
      // 初始化默认模板数据（如果需要）
      await _initializeDefaultTemplatesIfNeeded();
    } catch (e) {
      LogManager.e('MedicalRecordProvider',
          'MedicalRecordProvider($_instanceId): 异步表检查失败',
          error: e);
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

      final result = await _dataSourceInitializer.initializeFromDatabase(
        moduleDataSources: moduleDataSources,
        dataSourceMode: dataSourceMode,
        userProvider: userProvider,
        currentUser: _currentUser,
        onSqliteDataSourceReady: (dataSource) {
          _sqliteDataSource = dataSource;
        },
        onMysqlDataSourceReady: (dataSource) {
          _mysqlDataSource = dataSource;
        },
        onDatabaseReady: (database) {
          _database = database;
          _isConnected = true;
          _clearError();
        },
        onMysqlConnectionReady: (connection) {
          _mysqlConnection = connection;
          _isConnected = true;
          _clearError();
        },
        onDataSourceTypeChanged: (dataSourceType) {
          _effectiveDataSourceType = dataSourceType;
        },
        onEnsureTablesExist: () async {
          await _ensureTablesExist();
        },
      );

      if (result.success) {
        // 清除缓存，强制重新加载
        _cacheHelper.clearAllCache();

        // 初始化默认模板数据（如果需要）
        await _initializeDefaultTemplatesIfNeeded();
      } else {
        _setError(result.error ?? '初始化失败');
      }
    } catch (e) {
      LogManager.e('MedicalRecordProvider', 'MedicalRecordProvider初始化失败',
          error: e);
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
      LogManager.e('MedicalRecordProvider', 'MedicalRecordProvider: 初始化默认模板时出错',
          error: e);
      // 不抛出异常，避免影响整体初始化
    }
  }

  // 错误处理
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
    LogManager.e('MedicalRecordProvider', 'MedicalRecordProvider错误',
        error: error);
  }

  void _clearError() {
    _lastError = null;
    _isConnected = true;
  }

  /// 确保必要的表存在
  Future<void> _ensureTablesExist() async {
    final dataSource = _currentDataSource;
    if (dataSource == null) return;
    try {
      await dataSource.ensureTablesExist();
    } catch (e) {
      LogManager.e('MedicalRecordProvider', 'MedicalRecordProvider: 创建表时出错',
          error: e);
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
    LogManager.w('MedicalRecordProvider',
        'MedicalRecordProvider: setDatabaseConnection被调用，但已升级为数据源架构');
    // 这个方法保留用于向后兼容，但实际初始化应该使用initializeFromDatabase
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) _currentUser = currentUser;
  }

  // 清除缓存（向后兼容）
  void clearCache() {
    _cacheHelper.clearCache();
  }

  // 清除模板缓存（向后兼容）
  void clearTemplateCache() {
    _cacheHelper.clearTemplateCache();
  }

  // 清除所有缓存（向后兼容）
  void clearAllCache() {
    _cacheHelper.clearAllCache();
  }

  // 设置用户权限提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    // 重新初始化数据源以应用权限
    if (_sqliteDataSource != null) {
      _reinitializeDataSourcesWithUser();
      // 清除缓存，强制重新加载数据
      _cacheHelper.clearCache();
    }
  }

  // 重新初始化数据源以应用新的用户信息
  void _reinitializeDataSourcesWithUser() {
    final result = _dataSourceInitializer.reinitializeDataSourcesWithUser(
      effectiveDataSourceType: _effectiveDataSourceType,
      database: _database,
      cachedMysqlConnection: _mysqlConnection,
      userProvider: _userProvider,
      currentUser: _currentUser,
    );

    if (result.success) {
      if (result.sqliteDataSource != null) {
        _sqliteDataSource = result.sqliteDataSource;
      }
      if (result.mysqlDataSource != null) {
        _mysqlDataSource = result.mysqlDataSource;
      }
    }
  }

  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
    // 如果已经有数据源，需要重新初始化以应用新的用户信息
    if (_sqliteDataSource != null) {
      _reinitializeDataSourcesWithUser();
      // 清除缓存，强制重新加载数据
      _cacheHelper.clearCache();
    }
  }

  // 更新模块数据源配置
  void updateModuleDataSources(Map<String, String> moduleDataSources) {
    LogManager.i('MedicalRecordProvider',
        'MedicalRecordProvider.updateModuleDataSources - 模块数据源配置已更新: $moduleDataSources');

    // 如果病历模块的数据源类型发生变化，需要重新初始化
    if (_databaseProvider != null) {
      // 病历管理使用与患者管理相同的数据源
      final newDataSourceType = moduleDataSources['patients'] ?? 'sqlite';
      if (newDataSourceType != _effectiveDataSourceType) {
        LogManager.w('MedicalRecordProvider',
            '病历模块数据源类型变更: $_effectiveDataSourceType -> $newDataSourceType');

        initializeFromDatabase(
          _databaseProvider,
          moduleDataSources: moduleDataSources,
          dataSourceMode: 'modular',
          userProvider: _userProvider,
        );
      }
    }
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
  Future<List<PatientMedicalRecord>> getPatientMedicalRecords(int patientId,
      {bool forceRefresh = false}) async {
    return _medicalRecordService.getPatientMedicalRecords(patientId,
        forceRefresh: forceRefresh);
  }

  /// 根据ID获取病历记录
  Future<PatientMedicalRecord?> getMedicalRecordById(int id) async {
    return _medicalRecordService.getMedicalRecordById(id);
  }

  /// 创建新的病历记录
  Future<int> createMedicalRecord(PatientMedicalRecord record) async {
    return _medicalRecordService.createMedicalRecord(record);
  }

  /// 更新病历记录
  Future<bool> updateMedicalRecord(PatientMedicalRecord record) async {
    return _medicalRecordService.updateMedicalRecord(record);
  }

  /// 删除病历记录
  Future<bool> deleteMedicalRecord(int id) async {
    return _medicalRecordService.deleteMedicalRecord(id);
  }

  /// 搜索病历记录
  Future<List<PatientMedicalRecord>> searchMedicalRecords(String query,
      {int? patientId}) async {
    return _medicalRecordService.searchMedicalRecords(query,
        patientId: patientId);
  }

  /// 获取病历记录数量
  Future<int> getMedicalRecordsCount(int patientId) async {
    return _medicalRecordService.getMedicalRecordsCount(patientId);
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
    return _medicalRecordService.getMedicalRecordsPage(
      patientId: patientId,
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      sortField: sortField,
      sortAscending: sortAscending,
    );
  }

  /// 检查当前用户是否有权限操作指定病历记录

  Future<bool> hasPermissionForRecord(int recordId) async {
    return _permissionService.hasPermissionForRecord(recordId);
  }

  /// 检查当前用户是否为管理员
  bool get isCurrentUserAdmin {
    return _permissionService.isCurrentUserAdmin;
  }

  /// 获取当前用户的医生名称
  String? get currentDoctorName {
    return _permissionService.currentDoctorName;
  }

  // =================== 模板管理方法 ===================

  /// 根据类别获取模板列表
  Future<List<MedicalRecordTemplate>> getTemplatesByCategory(String category,
      {bool forceRefresh = false}) async {
    return _templateService.getTemplatesByCategory(
      category,
      forceRefresh: forceRefresh,
      cachedTemplates: _cacheHelper.cachedTemplates,
      lastTemplateCacheTime: _cacheHelper.lastTemplateCacheTimeFor(category),
      cacheValidDuration: MedicalRecordCacheHelper.templateCacheValidDuration,
      updateTemplateCache: _cacheHelper.updateTemplateCache,
    );
  }

  /// 根据ID获取模板
  Future<MedicalRecordTemplate?> getTemplateById(int id) async {
    return _templateService.getTemplateById(id);
  }

  /// 创建新模板
  Future<int> createTemplate(MedicalRecordTemplate template) async {
    final id = await _templateService.createTemplate(
      template,
      cachedTemplates: _cacheHelper.cachedTemplates,
      clearTemplateCache: () {},
    );
    if (id > 0) {
      _cacheHelper.upsertTemplate(template.copyWith(id: id));
    }
    return id;
  }

  /// 更新模板
  Future<bool> updateTemplate(MedicalRecordTemplate template) async {
    final success = await _templateService.updateTemplate(
      template,
      cachedTemplates: _cacheHelper.cachedTemplates,
      clearTemplateCache: () {},
    );
    if (success) {
      _cacheHelper.upsertTemplate(template);
    }
    return success;
  }

  /// 删除模板
  Future<bool> deleteTemplate(int id) async {
    final success = await _templateService.deleteTemplate(
      id,
      clearTemplateCache: () {},
    );
    if (success) {
      _cacheHelper.removeTemplateById(id);
    }
    return success;
  }

  /// 初始化默认模板
  Future<bool> initializeDefaultTemplates() async {
    return _templateService.initializeDefaultTemplates(
      clearTemplateCache: () => _cacheHelper.clearTemplateCache(),
    );
  }

  /// 检查是否有模板数据
  Future<bool> hasTemplateData() async {
    return _templateService.hasTemplateData();
  }

  /// 获取所有模板
  Future<Map<String, List<MedicalRecordTemplate>>> getAllTemplates(
      {bool forceRefresh = false}) async {
    return _templateService.getAllTemplates(
      forceRefresh: forceRefresh,
      cachedTemplates: _cacheHelper.cachedTemplates,
      getLastTemplateCacheTime: _cacheHelper.lastTemplateCacheTimeFor,
      cacheValidDuration: MedicalRecordCacheHelper.templateCacheValidDuration,
      updateTemplateCache: _cacheHelper.updateTemplateCache,
    );
  }

  /// 批量创建模板
  Future<List<int>> createTemplates(
      List<MedicalRecordTemplate> templates) async {
    return _templateService.createTemplates(
      templates,
      cachedTemplates: _cacheHelper.cachedTemplates,
      clearTemplateCache: () => _cacheHelper.clearTemplateCache(),
    );
  }

  /// 获取主要疾病类型
  Future<List<MedicalRecordTemplate>> getMainDiseaseTypes(
      String category) async {
    return _templateService.getMainDiseaseTypes(category);
  }

  /// 获取子疾病类型
  Future<List<MedicalRecordTemplate>> getSubDiseaseTypes(
      String category, String parentName) async {
    return _templateService.getSubDiseaseTypes(category, parentName);
  }

  /// 搜索模板
  Future<List<MedicalRecordTemplate>> searchTemplates(
      String query, String category) async {
    return _templateService.searchTemplates(query, category);
  }

  /// 检查模板是否有相关记录
  Future<bool> hasRelatedRecords(int templateId) async {
    return _templateService.hasRelatedRecords(templateId);
  }

  /// 获取疾病选项
  Future<Map<String, List<String>>> getDiseaseOptions(String category) async {
    return _templateService.getDiseaseOptions(category);
  }

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
      LogManager.e('MedicalRecordProvider', '导出病历PDF时出错', error: e);
      _setError('导出病历PDF失败: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}

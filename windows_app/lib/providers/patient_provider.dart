import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';

import '../models/patient.dart';
import '../models/user.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../models/patient_material_with_images.dart';
import '../data_sources/patient_data_source.dart';
import '../utils/mysql_sync_connection_helper.dart';
import 'database_provider.dart';
import 'user_provider.dart';
import '../features/patients/services/patient_material_service.dart';
import '../features/patients/services/patient_material_sync_service.dart';
import '../features/patients/services/patient_search_service.dart';
import '../features/patients/services/patient_core_service.dart';
import '../features/patients/services/patient_list_service.dart';
import '../features/patients/services/patient_initialization_service.dart';

export '../models/patient_material_with_images.dart'
    show PatientMaterialWithImages;

/// 患者管理提供者
/// 负责维护患者相关的 UI 状态，并将具体业务逻辑委托给专门的服务层
class PatientProvider extends ChangeNotifier {
  // 数据源实例
  SqlitePatientDataSource? _sqliteDataSource;
  MySqlPatientDataSource? _mysqlDataSource;

  // 患者相关服务
  late final PatientMaterialService _materialService;
  late final PatientSearchService _searchService;
  late final PatientCoreService _coreService;
  late final PatientListService _listService;

  // 用户权限提供者引用
  UserProvider? _userProvider;
  
  // 缓存机制
  List<Patient>? _cachedPatients;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20);
  
  // 连接状态
  bool _isConnected = true;
  String? _lastError;
  Future<void>? _initializationFuture;
  String? _lastInitializationSignature;
  
  // 数据库提供者引用
  dynamic _databaseProvider;
  
  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;
  
  // 数据源类型
  String _dataSourceType = 'sqlite';
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
    if (_effectiveDataSourceType == 'mysql') return _mysqlDataSource;
    if (_effectiveDataSourceType == 'sqlite') return _sqliteDataSource;
    return null;
  }
  
  // MySQL 动态连接获取
  MySqlConnection? get _currentMysqlConnection {
    if (_effectiveDataSourceType != 'mysql' || _databaseProvider == null) return _mysqlConnection;
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) return latestConnection;
    } catch (e) {
      print('PatientProvider: 获取最新MySQL连接失败: $e');
    }
    return _mysqlConnection;
  }

  MySqlConnection? get _syncMysqlConnection {
    return MySqlSyncConnectionHelper.getSyncConnection(
      databaseProvider: _databaseProvider is DatabaseProvider
          ? _databaseProvider as DatabaseProvider
          : null,
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

    // 初始化服务，通过闭包桥接 Provider 的实时状态
    _materialService = PatientMaterialService(
      getCurrentDataSource: () => _currentDataSource,
      syncService: PatientMaterialSyncService(
        getSyncMysqlConnection: () => _syncMysqlConnection,
        getEffectiveDataSourceType: () => _effectiveDataSourceType ?? _dataSourceType,
      ),
    );

    _searchService = PatientSearchService(
      getCurrentDataSource: () => _currentDataSource,
    );

    _listService = PatientListService(
      getCurrentDataSource: () => _currentDataSource,
    );

    _coreService = PatientCoreService(
      getCurrentDataSource: () => _currentDataSource,
      getSyncMysqlConnection: () => _syncMysqlConnection,
      getMysqlConnection: () => _currentMysqlConnection,
      getDatabase: () => _database,
      getEffectiveDataSourceType: () => _effectiveDataSourceType ?? _dataSourceType,
    );
  }

  // 智能初始化 (委托至 PatientInitializationService)
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    UserProvider? userProvider,
  }) async {
    final signature = _buildInitializationSignature(
      dbProvider: dbProvider,
      moduleDataSources: moduleDataSources,
      dataSourceMode: dataSourceMode,
      userProvider: userProvider,
    );

    if (_initializationFuture != null) {
      await _initializationFuture;
      return;
    }

    if (_lastInitializationSignature == signature &&
        (_sqliteDataSource != null || _mysqlDataSource != null)) {
      return;
    }

    _initializationFuture = _initializeFromDatabaseInternal(
      dbProvider: dbProvider,
      moduleDataSources: moduleDataSources,
      dataSourceMode: dataSourceMode,
      userProvider: userProvider,
      signature: signature,
    );
    try {
      await _initializationFuture;
    } finally {
      _initializationFuture = null;
    }
  }

  String _buildInitializationSignature({
    required dynamic dbProvider,
    required Map<String, String>? moduleDataSources,
    required String? dataSourceMode,
    required UserProvider? userProvider,
  }) {
    final currentUserId = userProvider?.currentUser?.id ?? _currentUser?.id ?? 'none';
    final moduleSignature = moduleDataSources == null
        ? 'none'
        : (() {
            final entries = moduleDataSources.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            return entries.map((e) => '${e.key}:${e.value}').join(',');
          })();
    final dbType = () {
      try {
        return dbProvider.dataSourceType?.toString() ?? 'unknown';
      } catch (_) {
        return 'unknown';
      }
    }();
    return '${dataSourceMode ?? 'global'}|$moduleSignature|$currentUserId|$dbType';
  }

  Future<void> _initializeFromDatabaseInternal({
    required dynamic dbProvider,
    required Map<String, String>? moduleDataSources,
    required String? dataSourceMode,
    required UserProvider? userProvider,
    required String signature,
  }) async {
    try {
      print('PatientProvider.initializeFromDatabase: 开始初始化');
      _databaseProvider = dbProvider;
      _userProvider = userProvider;

      final config = await PatientInitializationService.initializeDataSources(
        dbProvider: dbProvider,
        moduleDataSources: moduleDataSources,
        dataSourceMode: dataSourceMode,
        currentUser: _userProvider?.currentUser ?? _currentUser,
      );

      _effectiveDataSourceType = config['effectiveType'];
      _sqliteDataSource = config['sqliteDataSource'];
      _mysqlDataSource = config['mysqlDataSource'];
      _database = config['database'];
      _mysqlConnection = config['mysqlConnection'];

      if (_effectiveDataSourceType == 'sqlite' && _sqliteDataSource == null) {
        throw Exception('SQLite数据库连接不可用');
      }
      if (_effectiveDataSourceType == 'mysql' && _mysqlDataSource == null) {
        throw Exception('MySQL数据库连接不可用');
      }

      _isConnected = true;
      _lastError = null;
      _lastInitializationSignature = signature;
      clearCache();
      print('PatientProvider.initializeFromDatabase: 完成，数据源类型: $_effectiveDataSourceType');
    } catch (e) {
      print('PatientProvider.initializeFromDatabase: 失败: $e');
      _lastError = '初始化失败: $e';
      _isConnected = false;
    }
  }
  
  // 重新初始化数据源以应用新的用户信息 (委托至 PatientInitializationService)
  void _reinitializeDataSourcesWithUser() {
    final result = PatientInitializationService.reinitializeWithUser(
      effectiveType: _effectiveDataSourceType ?? _dataSourceType,
      user: _userProvider?.currentUser ?? _currentUser,
      database: _database,
      mysqlConnection: _currentMysqlConnection,
      mysqlConnectionGetter: () async => _currentMysqlConnection,
      onReconnect: () async {
        if (_databaseProvider != null) await _databaseProvider.initializeMySQL();
      },
    );

    _sqliteDataSource = result['sqliteDataSource'];
    _mysqlDataSource = result['mysqlDataSource'];
  }

  // 缓存管理
  bool _isCacheValid() => _cachedPatients != null && _lastCacheTime != null &&
      DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;

  void _updateCache(List<Patient> patients) {
    _cachedPatients = patients;
    _lastCacheTime = DateTime.now();
  }
  
  void clearCache() {
    _cachedPatients = null;
    _lastCacheTime = null;
  }

  // =================== 患者列表与查询 (委托至 ListService/SearchService) ===================

  Future<List<Patient>> getAllPatients() async {
    if (!initialized) throw Exception('数据库未初始化');
    if (_isCacheValid()) return _cachedPatients!;
    final patients = await _listService.getAllPatients();
    _updateCache(patients);
    _patientsNeedRefresh = false;
    return patients;
  }

  Future<List<Patient>> getPatientsByDoctor(String doctorName) async {
    _patientsNeedRefresh = false;
    return _listService.getPatientsByDoctor(doctorName);
  }

  Future<List<Patient>> getPatientsByIds(
    List<int> ids, {
    bool enforceDoctorFilter = true,
    String? effectiveDataSourceType,
  }) async {
    return _listService.getPatientsByIds(ids);
  }

  Future<Patient?> getPatient(int id) async {
    if (!initialized) throw Exception('数据库未初始化');
    return _currentDataSource?.getPatientById(id);
  }

  Future<Map<String, dynamic>> getPatientsPage({
    required int page, required int pageSize, String? searchQuery,
    String? sortField, bool sortAscending = false,
    DateTime? startDate, DateTime? endDate, String dateFilterType = 'first_visit_date',
  }) async {
    return _listService.getPatientsPage(
      page: page, pageSize: pageSize, searchQuery: searchQuery,
      sortField: sortField, sortAscending: sortAscending,
      startDate: startDate, endDate: endDate, dateFilterType: dateFilterType,
    );
  }

  Future<List<int>> searchPatientIds(
    String query, {
    String? effectiveDataSourceType,
  }) async {
    return _searchService.searchPatientIds(query);
  }

  Future<List<Patient>> searchPatients(String query, {
    String? sortField, bool sortAscending = false,
    DateTime? startDate, DateTime? endDate, String dateFilterType = 'first_visit_date',
    Map<String, String>? advancedCriteria,
  }) async {
    return _searchService.searchPatients(
      query, sortField: sortField, sortAscending: sortAscending,
      startDate: startDate, endDate: endDate, dateFilterType: dateFilterType,
      advancedCriteria: advancedCriteria,
    );
  }

  // =================== 患者核心业务 (委托至 CoreService) ===================

  Future<int> addPatient(Patient patient) async {
    final id = await _coreService.addPatient(patient);
    clearCache();
    markPatientsNeedRefresh();
    return id;
  }

  Future<int> updatePatient(Patient patient) async {
    final success = await _coreService.updatePatient(patient);
    if (success) {
      clearCache();
      markPatientsNeedRefresh();
      return 1;
    }
    return 0;
  }

  Future<void> deletePatient(int patientId) async {
    Patient? p;
    try { p = await getPatient(patientId); } catch (_) {}
    final success = await _coreService.deletePatient(patientId, patientName: p?.name, medicalRecordNumber: p?.medical_record_number);
    if (success) {
      clearCache();
      markPatientsNeedRefresh();
    }
  }

  Future<void> updateAllPatientsPinyin() async {
    await _searchService.updateAllPatientsPinyin();
    markPatientsNeedRefresh();
  }

  Future<bool> checkMedicalRecordExists(int mrn, [int? excludeId]) => _coreService.checkMedicalRecordExists(mrn, excludeId);
  Future<bool> checkPatientNameExists(String name, [int? excludeId]) => _coreService.checkPatientNameExists(name, excludeId);
  String processDentalConditionFormat(String sql) => _coreService.processDentalConditionFormat(sql);

  // =================== 状态管理辅助 ===================

  void markPatientsNeedRefresh() {
    _patientsNeedRefresh = true;
    notifyListeners();
  }

  void resetPatientsRefreshFlag() => _patientsNeedRefresh = false;

  void setCurrentUser(User user) {
    _currentUser = user;
    _reinitializeDataSourcesWithUser();
    clearCache();
  }

  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
    _reinitializeDataSourcesWithUser();
    clearCache();
  }

  // =================== 患者材料委托 ===================

  Future<PatientMaterial> addPatientMaterial(PatientMaterial m) => _materialService.addPatientMaterial(m);
  Future<List<PatientMaterial>> getPatientMaterials(int id) => _materialService.getPatientMaterials(id);
  Future<bool> updatePatientMaterial(PatientMaterial m) => _materialService.updatePatientMaterial(m);
  Future<bool> deletePatientMaterial(int id) => _materialService.deletePatientMaterial(id);
  Future<MaterialImage> addMaterialImage(MaterialImage i) => _materialService.addMaterialImage(i);
  Future<MaterialImage?> getMaterialImage(int id) => _materialService.getMaterialImage(id);
  Future<List<MaterialImage>> getMaterialImages(int id) => _materialService.getMaterialImages(id);
  Future<bool> deleteMaterialImage(int id) => _materialService.deleteMaterialImage(id);
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithImages(int id) => _materialService.getPatientMaterialsWithImages(id);
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithThumbnails(int id) => _materialService.getPatientMaterialsWithThumbnails(id);

  // 向后兼容方法
  User? get currentUser => _currentUser;

  // 设置数据库连接（向后兼容，不建议新代码使用）
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
  }) {
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) {
      _currentUser = currentUser;
      _reinitializeDataSourcesWithUser();
    }
  }
}

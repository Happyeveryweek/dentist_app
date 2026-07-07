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
import '../utils/pinyin_util.dart';
import '../utils/log_manager.dart';

export '../models/patient_material_with_images.dart'
    show PatientMaterialWithImages;

/// 患者管理提供者
/// 负责维护患者相关的 UI 状态，并将具体业务逻辑委托给专门的服务层
class PatientProvider extends ChangeNotifier {
  // 数据源实例
  SqlitePatientDataSource? _sqliteDataSource;
  MySqlPatientDataSource? _mysqlDataSource;

  // 患者相关服务（通过 getter 懒加载，闭包依赖 Provider 实时状态）
  PatientMaterialService? _materialServiceInstance;
  PatientMaterialService get _materialService =>
      _materialServiceInstance ??= PatientMaterialService(
        getCurrentDataSource: () => _currentDataSource,
        syncService: PatientMaterialSyncService(
          getSyncMysqlConnection: () => _syncMysqlConnection,
          getEffectiveDataSourceType: () =>
              _effectiveDataSourceType ?? _dataSourceType,
        ),
      );
  PatientSearchService? _searchServiceInstance;
  PatientSearchService get _searchService =>
      _searchServiceInstance ??= PatientSearchService(
        getCurrentDataSource: () => _currentDataSource,
      );
  PatientCoreService? _coreServiceInstance;
  PatientCoreService get _coreService =>
      _coreServiceInstance ??= PatientCoreService(
        getCurrentDataSource: () => _currentDataSource,
        getSyncMysqlConnection: () => _syncMysqlConnection,
        getMysqlConnection: () => _currentMysqlConnection,
        getDatabase: () => _database,
        getEffectiveDataSourceType: () =>
            _effectiveDataSourceType ?? _dataSourceType,
      );
  PatientListService? _listServiceInstance;
  PatientListService get _listService =>
      _listServiceInstance ??= PatientListService(
        getCurrentDataSource: () => _currentDataSource,
      );

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
  bool get initialized =>
      _currentDataSource != null ||
      _database != null ||
      _mysqlConnection != null;
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

  PatientDataSource? _dataSourceForType(String? effectiveDataSourceType) {
    final requestedType = effectiveDataSourceType ?? dataSourceType;
    if (requestedType == dataSourceType) {
      return _currentDataSource;
    }

    if (requestedType == 'sqlite') {
      final database = _database;
      if (_sqliteDataSource == null && database != null) {
        final doctor = _currentUser?.doctor;
        final isAdmin = _currentUser == null || _currentUser?.role == 'admin';
        _sqliteDataSource = SqlitePatientDataSource(
          database,
          doctorName: doctor,
          isAdmin: isAdmin,
        );
      }
      return _sqliteDataSource;
    }

    if (requestedType == 'mysql') {
      MySqlConnection? mysqlConnection = _currentMysqlConnection;
      if (mysqlConnection == null && _databaseProvider != null) {
        try {
          mysqlConnection = _databaseProvider.mysqlConnection;
        } catch (e) {
          LogManager.e('PatientProvider', 'PatientProvider: 获取指定MySQL连接失败',
              error: e);
        }
      }
      if (_mysqlDataSource == null && mysqlConnection != null) {
        final doctor = _currentUser?.doctor;
        final isAdmin = _currentUser == null || _currentUser?.role == 'admin';
        _mysqlConnection = mysqlConnection;
        _mysqlDataSource = MySqlPatientDataSource.withConnectionGetter(
          () async => _currentMysqlConnection,
          doctorName: doctor,
          isAdmin: isAdmin,
          reconnectCallback: () async {
            if (_databaseProvider != null) {
              await _databaseProvider.initializeMySQL();
            }
          },
        );
      }
      return _mysqlDataSource;
    }

    return _currentDataSource;
  }

  // MySQL 动态连接获取
  MySqlConnection? get _currentMysqlConnection {
    if (_effectiveDataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) return latestConnection;
    } catch (e) {
      LogManager.e('PatientProvider', 'PatientProvider: 获取最新MySQL连接失败',
          error: e);
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

    // 服务实例通过 getter 懒加载
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
    final currentUserId =
        userProvider?.currentUser?.id ?? _currentUser?.id ?? 'none';
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
      LogManager.w(
          'PatientProvider', 'PatientProvider.initializeFromDatabase: 开始初始化');
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
      LogManager.i('PatientProvider',
          'PatientProvider.initializeFromDatabase: 完成，数据源类型: $_effectiveDataSourceType');
    } catch (e) {
      LogManager.e(
          'PatientProvider', 'PatientProvider.initializeFromDatabase: 失败',
          error: e);
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
        if (_databaseProvider != null) {
          await _databaseProvider.initializeMySQL();
        }
      },
    );

    _sqliteDataSource = result['sqliteDataSource'];
    _mysqlDataSource = result['mysqlDataSource'];
  }

  // 缓存管理
  bool _isCacheValid() {
    final patients = _cachedPatients;
    final lastTime = _lastCacheTime;
    return patients != null &&
        lastTime != null &&
        DateTime.now().difference(lastTime) < _cacheValidDuration;
  }

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
    if (_isCacheValid()) {
      final cached = _cachedPatients;
      if (cached != null) return cached;
    }
    final patients = await _listService.getAllPatients();
    _updateCache(patients);
    _patientsNeedRefresh = false;
    return patients;
  }

  Future<List<Patient>> getAllPatientsInDataSource(
    String effectiveDataSourceType,
  ) async {
    final ds = _dataSourceForType(effectiveDataSourceType);
    if (ds == null) return [];
    return ds.getAllPatients();
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
    final ds = _dataSourceForType(effectiveDataSourceType);
    if (ds == null) return [];
    return ds.getPatientsByIds(ids);
  }

  Future<Patient?> getPatient(int id, {String? effectiveDataSourceType}) async {
    if (!initialized) throw Exception('数据库未初始化');
    final ds = _dataSourceForType(effectiveDataSourceType);
    return ds?.getPatientById(id);
  }

  Future<List<Patient>> searchPatientsInDataSource(
    String query, {
    String? effectiveDataSourceType,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return [];
    final ds = _dataSourceForType(effectiveDataSourceType);
    if (ds == null) return [];
    return ds.searchPatients(normalizedQuery);
  }

  Future<Patient?> resolvePatientForDataSource(
    Patient sourcePatient, {
    required String targetDataSourceType,
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    final sourceId = sourcePatient.id;
    if (sourceId != null) {
      final directMatches = await getPatientsByIds(
        [sourceId],
        effectiveDataSourceType: targetDataSourceType,
      );
      if (directMatches.isNotEmpty &&
          _matchesPatientIdentity(sourcePatient, directMatches.first)) {
        return directMatches.first;
      }
    }

    final candidates = <Patient>[];
    final seenIds = <int?>{};

    void addCandidates(Iterable<Patient> patients) {
      for (final patient in patients) {
        final key = patient.id;
        if (seenIds.add(key)) {
          candidates.add(patient);
        }
      }
    }

    final mrn = sourcePatient.medicalRecordNumber;
    if (mrn != null) {
      addCandidates(await searchPatientsInDataSource(
        mrn.toString(),
        effectiveDataSourceType: targetDataSourceType,
      ));
    }

    final identificationNumber =
        _normalizeIdentity(sourcePatient.identificationNumber);
    if (identificationNumber.isNotEmpty) {
      addCandidates(await searchPatientsInDataSource(
        identificationNumber,
        effectiveDataSourceType: targetDataSourceType,
      ));
    }

    final name = sourcePatient.name.trim();
    if (name.isNotEmpty) {
      addCandidates(await searchPatientsInDataSource(
        name,
        effectiveDataSourceType: targetDataSourceType,
      ));
    }

    for (final candidate in candidates) {
      if (_matchesPatientIdentity(sourcePatient, candidate)) {
        return candidate;
      }
    }

    return null;
  }

  Future<Patient?> ensurePatientInDataSource(
    Patient sourcePatient, {
    required String targetDataSourceType,
  }) async {
    if (targetDataSourceType == 'mysql') {
      return _upsertPatientToMySQL(sourcePatient);
    }

    final existing = await resolvePatientForDataSource(
      sourcePatient,
      targetDataSourceType: targetDataSourceType,
    );
    if (existing != null) {
      return existing;
    }

    return null;
  }

  Future<Patient?> _upsertPatientToMySQL(Patient sourcePatient) async {
    final mysqlConnection = _currentMysqlConnection;
    if (mysqlConnection == null) {
      LogManager.w('PatientProvider', '无法补齐财务侧患者：MySQL连接不可用');
      return null;
    }

    final patientMap = sourcePatient.toMap();
    final sourceId = sourcePatient.id;
    if (sourceId == null) {
      LogManager.w('PatientProvider', '无法补齐财务侧患者：SQLite患者ID为空');
      return null;
    }

    patientMap['name_pinyin'] =
        sourcePatient.namePinyin ?? PinyinUtil.toPinyin(sourcePatient.name);
    patientMap['name_initials'] = sourcePatient.nameInitials ??
        PinyinUtil.getInitials(sourcePatient.name);
    final address = sourcePatient.address;
    if (address != null && address.isNotEmpty) {
      patientMap['address_pinyin'] =
          sourcePatient.addressPinyin ?? PinyinUtil.toPinyin(address);
    }

    try {
      final existById = await mysqlConnection.query(
        'SELECT id FROM patients WHERE id = ? LIMIT 1',
        [sourceId],
      );
      if (existById.isNotEmpty) {
        await mysqlConnection.query(
          '''
            UPDATE patients SET
              name = ?, name_pinyin = ?, name_initials = ?, age = ?, gender = ?, phone = ?,
              medical_record_number = ?, address = ?, address_pinyin = ?, identification_number = ?,
              doctor = ?, dental_condition = ?, treatment_items = ?, first_visit_date = ?, total_cost = ?, created_at = ?, updated_at = ?
            WHERE id = ?
          ''',
          [
            patientMap['name'],
            patientMap['name_pinyin'],
            patientMap['name_initials'],
            patientMap['age'],
            patientMap['gender'],
            patientMap['phone'],
            patientMap['medical_record_number'],
            patientMap['address'],
            patientMap['address_pinyin'],
            patientMap['identification_number'],
            patientMap['doctor'],
            patientMap['dental_condition'],
            patientMap['treatment_items'],
            patientMap['first_visit_date'],
            patientMap['total_cost'],
            patientMap['created_at'],
            patientMap['updated_at'],
            sourceId,
          ],
        );
        return getPatient(sourceId, effectiveDataSourceType: 'mysql');
      }

      await mysqlConnection.query(
        '''
          INSERT INTO patients
          (id, name, name_pinyin, name_initials, age, gender, phone, medical_record_number, address, address_pinyin, identification_number, doctor, dental_condition, treatment_items, first_visit_date, total_cost, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          sourceId,
          patientMap['name'],
          patientMap['name_pinyin'],
          patientMap['name_initials'],
          patientMap['age'],
          patientMap['gender'],
          patientMap['phone'],
          patientMap['medical_record_number'],
          patientMap['address'],
          patientMap['address_pinyin'],
          patientMap['identification_number'],
          patientMap['doctor'],
          patientMap['dental_condition'],
          patientMap['treatment_items'],
          patientMap['first_visit_date'],
          patientMap['total_cost'],
          patientMap['created_at'],
          patientMap['updated_at'],
        ],
      );
    } catch (e) {
      LogManager.e('PatientProvider', '补齐目标数据源患者失败', error: e);
      return null;
    }

    return getPatient(sourceId, effectiveDataSourceType: 'mysql');
  }

  Future<Map<String, dynamic>> getPatientsPage({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
  }) async {
    return _listService.getPatientsPage(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      sortField: sortField,
      sortAscending: sortAscending,
      startDate: startDate,
      endDate: endDate,
      dateFilterType: dateFilterType,
    );
  }

  Future<List<int>> searchPatientIds(
    String query, {
    String? effectiveDataSourceType,
  }) async {
    if (query.trim().isEmpty) return [];
    final ds = _dataSourceForType(effectiveDataSourceType);
    if (ds == null) return [];
    return ds.searchPatientIds(query);
  }

  Future<List<Patient>> searchPatients(
    String query, {
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
    Map<String, String>? advancedCriteria,
  }) async {
    return _searchService.searchPatients(
      query,
      sortField: sortField,
      sortAscending: sortAscending,
      startDate: startDate,
      endDate: endDate,
      dateFilterType: dateFilterType,
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

  static String _normalizeIdentity(String? value) {
    return value?.trim().toLowerCase() ?? '';
  }

  static bool _matchesPatientIdentity(Patient source, Patient candidate) {
    final sourceMrn = source.medicalRecordNumber;
    final candidateMrn = candidate.medicalRecordNumber;
    final sourceName = source.name.trim();
    final candidateName = candidate.name.trim();
    final sourceIdentity = _normalizeIdentity(source.identificationNumber);
    final candidateIdentity =
        _normalizeIdentity(candidate.identificationNumber);

    if (sourceMrn != null &&
        candidateMrn != null &&
        sourceMrn == candidateMrn &&
        sourceName.isNotEmpty &&
        sourceName == candidateName) {
      return true;
    }

    if (sourceIdentity.isNotEmpty &&
        candidateIdentity.isNotEmpty &&
        sourceIdentity == candidateIdentity) {
      return true;
    }

    return false;
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
    try {
      p = await getPatient(patientId);
    } catch (_) {}
    final success = await _coreService.deletePatient(patientId,
        patientName: p?.name, medicalRecordNumber: p?.medicalRecordNumber);
    if (success) {
      clearCache();
      markPatientsNeedRefresh();
    }
  }

  Future<void> updateAllPatientsPinyin() async {
    await _searchService.updateAllPatientsPinyin();
    markPatientsNeedRefresh();
  }

  Future<bool> checkMedicalRecordExists(int mrn, [int? excludeId]) =>
      _coreService.checkMedicalRecordExists(mrn, excludeId);
  Future<bool> checkPatientNameExists(String name, [int? excludeId]) =>
      _coreService.checkPatientNameExists(name, excludeId);
  String processDentalConditionFormat(String sql) =>
      _coreService.processDentalConditionFormat(sql);

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

  Future<PatientMaterial> addPatientMaterial(PatientMaterial m) =>
      _materialService.addPatientMaterial(m);
  Future<List<PatientMaterial>> getPatientMaterials(int id) =>
      _materialService.getPatientMaterials(id);
  Future<bool> updatePatientMaterial(PatientMaterial m) =>
      _materialService.updatePatientMaterial(m);
  Future<bool> deletePatientMaterial(int id) =>
      _materialService.deletePatientMaterial(id);
  Future<MaterialImage> addMaterialImage(MaterialImage i) =>
      _materialService.addMaterialImage(i);
  Future<MaterialImage?> getMaterialImage(int id) =>
      _materialService.getMaterialImage(id);
  Future<List<MaterialImage>> getMaterialImages(int id) =>
      _materialService.getMaterialImages(id);
  Future<bool> deleteMaterialImage(int id) =>
      _materialService.deleteMaterialImage(id);
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithImages(
          int id) =>
      _materialService.getPatientMaterialsWithImages(id);
  Future<List<PatientMaterialWithImages>> getPatientMaterialsWithThumbnails(
          int id) =>
      _materialService.getPatientMaterialsWithThumbnails(id);

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

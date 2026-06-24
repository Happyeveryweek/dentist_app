import 'package:flutter/foundation.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:dentist_app/models/financial_record.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/utils/database_operation_wrapper.dart';
import 'package:dentist_app/data_sources/financial_data_source.dart';
import 'package:dentist_app/features/financial/helpers/financial_cache_helper.dart';
import 'package:dentist_app/features/financial/services/financial_permission_service.dart';
import 'package:dentist_app/features/financial/services/financial_connection_service.dart';
import 'package:dentist_app/features/financial/services/financial_data_source_service.dart';
import 'package:dentist_app/features/financial/services/financial_data_cleaner_service.dart';
import 'package:dentist_app/features/financial/services/financial_statistics_service.dart';
import 'package:dentist_app/features/financial/services/financial_record_service.dart';
import 'package:dentist_app/features/financial/services/financial_item_service.dart';
import 'package:dentist_app/features/financial/services/financial_query_service.dart';
import 'package:dentist_app/features/financial/services/financial_initialization_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:async';
import '../utils/app_logger.dart';

class FinancialProvider extends ChangeNotifier {
  // 数据库连接
  Database? _database;
  String _dataSourceType = 'sqlite';

  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;

  // 初始化标志
  bool _isInitializedFlag = false;
  Future<void>? _initializationFuture;

  // 刷新标志
  bool _financialsNeedRefresh = false;

  // Service 和 Helper 实例
  final FinancialCacheHelper _cacheHelper = FinancialCacheHelper();
  final FinancialPermissionService _permissionService =
      FinancialPermissionService();
  final FinancialConnectionService _connectionService =
      FinancialConnectionService();
  final FinancialDataSourceService _dataSourceService =
      FinancialDataSourceService();
  final FinancialDataCleanerService _dataCleanerService =
      FinancialDataCleanerService();
  final FinancialStatisticsService _statisticsService =
      FinancialStatisticsService();
  final FinancialInitializationService _initializationService =
      FinancialInitializationService();
  late final FinancialRecordService _recordService = FinancialRecordService(
    dataSourceService: _dataSourceService,
  );
  late final FinancialItemService _itemService = FinancialItemService(
    dataSourceService: _dataSourceService,
  );
  late final FinancialQueryService _queryService = FinancialQueryService(
    dataSourceService: _dataSourceService,
    permissionService: _permissionService,
    connectionService: _connectionService,
  );

  // Getters
  bool get initialized =>
      _isInitializedFlag &&
      (_database != null || _currentMysqlConnection != null);
  bool get financialsNeedRefresh => _financialsNeedRefresh;
  bool get isConnected => _connectionService.isConnected;
  bool get isReconnecting => _connectionService.isReconnecting;
  String? get lastError => _connectionService.lastError;

  // 检查数据库是否已初始化
  bool get isInitialized {
    if (_dataSourceType == 'mysql') {
      return _isInitializedFlag && _currentMysqlConnection != null;
    } else {
      return _isInitializedFlag && _database != null;
    }
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _dataSourceService.setSqliteDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _dataSourceService.setMySqlDataSource(connection);
    _dataSourceService.setMySqlConnectionGetter(() => _currentMysqlConnection);
  }

  // 设置用户提供者（用于权限控制）
  void setUserProvider(UserProvider userProvider) {
    _permissionService.setUserProvider(userProvider);
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  FinancialDataSource get _currentDataSource {
    return _dataSourceService.currentDataSource;
  }

  // 获取当前 MySQL 连接
  MySqlConnection? get _currentMysqlConnection =>
      _connectionService.currentMysqlConnection;

  // 缓存相关方法（委托给 cacheHelper）
  bool get hasValidCache => _cacheHelper.hasValidCache;
  DateTime? get lastCacheTime => _cacheHelper.lastCacheTime;
  int get cachedRecordsCount => _cacheHelper.cachedRecordsCount;
  bool get hasCache => _cacheHelper.hasCache;
  List<FinancialRecord> get cachedRecords => _cacheHelper.cachedRecords;
  Map<int, List<FinancialItem>> get cachedItemsMap =>
      _cacheHelper.cachedItemsMap;

  // 更新缓存（供外部调用，用于后台加载过程中实时更新）
  void updateCacheManually(
    List<FinancialRecord> records,
    Map<int, List<FinancialItem>> itemsMap,
  ) {
    _cacheHelper.updateCacheManually(records, itemsMap);
  }

  // 清除缓存
  void clearCache() {
    _cacheHelper.clearCache();
    _financialsNeedRefresh = true; // 标记需要刷新
    AppLogger.info('财务数据缓存已清除，标记需要刷新');
    notifyListeners();
  }

  // 检查并清理无效的财务记录（patient_id为0或null）
  Future<Map<String, int>> checkAndCleanInvalidRecords() async {
    return await _dataCleanerService.checkAndCleanInvalidRecords(
      dataSourceType: _dataSourceType,
      sqliteDatabase: _database,
      mysqlConnection: _currentMysqlConnection,
      clearCache: () async {
        clearCache();
      },
      autoReconnect: _connectionService.autoReconnect,
    );
  }

  // 获取无效财务记录的详细信息
  Future<List<Map<String, dynamic>>> getInvalidRecordsInfo() async {
    return await _dataCleanerService.getInvalidRecordsInfo(
      dataSourceType: _dataSourceType,
      sqliteDatabase: _database,
      mysqlConnection: _currentMysqlConnection,
      autoReconnect: _connectionService.autoReconnect,
    );
  }

  // 从DatabaseProvider获取数据库连接
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag) return;
    if (_initializationFuture != null) {
      return await _initializationFuture!;
    }

    _initializationFuture = _initializeFromDatabaseInternal(dbProvider);
    try {
      return await _initializationFuture!;
    } finally {
      _initializationFuture = null;
    }
  }

  Future<void> _initializeFromDatabaseInternal(dynamic dbProvider) async {
    AppLogger.info('FinancialProvider开始初始化...');

    try {
      final result = await _initializationService.initializeFromDatabase(
        dbProvider: dbProvider,
        dataSourceService: _dataSourceService,
        connectionService: _connectionService,
      );

      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);
      _database = result.database;
      _dataSourceType = result.dataSourceType;

      // 同步所有 Service 的数据库连接信息
      setDatabaseConnection(
        database: _database,
        mysqlConnection: _currentMysqlConnection,
        dataSourceType: _dataSourceType,
      );
      if (_dataSourceType == 'mysql') {
        _dataSourceService.setMySqlConnectionGetter(
          () => _currentMysqlConnection,
        );
      }

      _isInitializedFlag = result.initialized;
      AppLogger.info(
        'FinancialProvider初始化完成: _isInitializedFlag = $_isInitializedFlag, _dataSourceType = $_dataSourceType',
      );
      // 延迟通知以避免在build阶段调用setState
      Future.microtask(() => notifyListeners());
    } catch (e) {
      AppLogger.info('FinancialProvider初始化失败: $e');
      // 设置默认值
      _dataSourceType = 'sqlite';
      _isInitializedFlag = true; // 标记为已初始化，避免重复尝试
      // 延迟通知以避免在build阶段调用setState
      Future.microtask(() => notifyListeners());
    }
  }

  // 构造函数
  FinancialProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
  }) {
    _database = database;
    _dataSourceType = dataSourceType;
  }

  // 设置数据库连接
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
  }) {
    if (database != null) _database = database;
    if (dataSourceType != null) {
      _dataSourceType = dataSourceType;
      _dataSourceService.setDataSourceType(dataSourceType);
    }
    if (_dataSourceType == 'mysql') {
      _dataSourceService.setMySqlConnectionGetter(
        () => _currentMysqlConnection,
      );
    }

    // 更新 recordService 的数据库连接
    _recordService.setDatabaseConnection(
      dataSourceType: _dataSourceType,
      database: _database,
      mysqlConnection: _currentMysqlConnection,
      dbWrapper: _dbWrapper,
    );

    // 更新 itemService 的数据库连接
    _itemService.setDatabaseConnection(
      dataSourceType: _dataSourceType,
      database: _database,
      mysqlConnection: _currentMysqlConnection,
      dbWrapper: _dbWrapper,
    );

    // 更新 queryService 的数据库连接
    _queryService.setDatabaseConnection(
      dataSourceType: _dataSourceType,
      database: _database,
      mysqlConnection: _currentMysqlConnection,
      dbWrapper: _dbWrapper,
    );
  }

  // 标记需要刷新
  void markFinancialsNeedRefresh() {
    _financialsNeedRefresh = true;
    notifyListeners();
  }

  // 清除刷新标志
  void clearFinancialsNeedRefresh() {
    _financialsNeedRefresh = false;
  }

  // =================== 财务记录相关方法 ===================

  // 获取所有财务记录（带缓存）
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dbWrapper == null) return [];

    return await _dbWrapper!.wrapOperation('getAllFinancialRecords', () async {
      try {
        AppLogger.info('🔄 从数据库获取最新财务记录...');

        // 优先检查缓存，避免不必要的数据库访问
        if (_cacheHelper.hasValidCache) {
          AppLogger.info('使用缓存的财务记录数据');
          return _cacheHelper.cachedRecords;
        }

        // 确保财务记录表存在
        await _dataSourceService.ensureFinancialRecordsTableExists(
          dataSourceType: _dataSourceType,
          sqliteDatabase: _database,
          mysqlConnection: _currentMysqlConnection,
        );

        List<FinancialRecord> records = [];

        // 检查是否需要权限过滤
        final doctorFilter = _permissionService.getDoctorFilter();
        if (doctorFilter != null && _permissionService.shouldFilterByDoctor()) {
          // 需要权限过滤，使用自定义查询
          records = await _permissionService.getFilteredFinancialRecords(
            doctorFilter,
            _dataSourceType,
            _database,
            _currentMysqlConnection,
          );
          AppLogger.info('✅ 权限过滤查询成功，获取到 ${records.length} 条财务记录（医生: $doctorFilter）');
        } else {
          // 使用数据源模式（统一接口）
          records = await _currentDataSource.getAllFinancialRecords();
          AppLogger.info('✅ 数据源模式查询成功，获取到 ${records.length} 条财务记录');
        }

        // 以下代码保留作为参考，但不再使用
        /*
        if (_dataSourceType == 'sqlite') {
        // 传统模式代码已移除，现在统一使用数据源模式
        */

        // 更新缓存
        _cacheHelper.updateCacheManually(records, {});
        AppLogger.info('✅ 财务记录缓存已更新');
        return records;
      } catch (e) {
        AppLogger.info('❌ 获取财务记录失败: $e');

        // 如果有缓存数据，返回缓存
        if (_cacheHelper.hasValidCache) {
          AppLogger.info('使用缓存的财务记录数据，查询失败: $e');
          return _cacheHelper.cachedRecords;
        }

        rethrow;
      }
    });
  }

  // 智能获取财务记录（优先使用缓存）
  Future<List<FinancialRecord>> getFinancialRecordsWithCache() async {
    if (_dbWrapper == null) return _cacheHelper.cachedRecords;

    return await _dbWrapper!.wrapOperation(
      'getFinancialRecordsWithCache',
      () async {
        try {
          // 优先检查缓存（像患者管理一样）
          if (_cacheHelper.hasValidCache) {
            AppLogger.info('使用缓存的财务记录数据: ${_cacheHelper.cachedRecords.length} 条');
            return _cacheHelper.cachedRecords;
          }

          // 尝试从数据库获取最新数据
          final records = await getAllFinancialRecords();
          return records;
        } catch (e) {
          AppLogger.info('获取财务记录失败: $e');
          // 优雅降级：如果有缓存就返回缓存，否则返回空列表（像患者管理一样）
          if (_cacheHelper.cachedRecords.isNotEmpty) {
            AppLogger.info('使用缓存的财务记录数据，连接异常: $e');
            return _cacheHelper.cachedRecords;
          }
          return []; // 返回空列表而不是抛出异常
        }
      },
    );
  }

  // 获取财务记录总数
  Future<int> getFinancialRecordsCount() async {
    if (!initialized) {
      return 0;
    }

    return await _queryService.getFinancialRecordsCount();
  }

  // 分页获取财务记录
  Future<List<FinancialRecord>> getPaginatedFinancialRecords(
    int page,
    int pageSize,
  ) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _queryService.getPaginatedFinancialRecords(page, pageSize);
  }

  // 获取财务记录总数
  Future<int> getFinancialRecordCount() async {
    if (!initialized) {
      return 0;
    }

    return await _wrapFinancialOperation(
      'getFinancialRecordCount',
      () => _queryService.getFinancialRecordCount(),
    );
  }

  // 搜索财务记录
  Future<List<FinancialRecord>> searchFinancialRecords(
    String keyword, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _queryService.searchFinancialRecords(
      keyword,
      startDate: startDate,
      endDate: endDate,
    );
  }

  // ── 全量统计缓存（委托给 cacheHelper）─────────────────────────────────────────────
  bool get hasValidStatsCache => _cacheHelper.hasValidStatsCache;
  bool get hasFullItemsCache => _cacheHelper.hasFullItemsCache;
  Map<String, dynamic>? get cachedStats => _cacheHelper.cachedStats;
  Map<int, List<FinancialItem>>? get cachedFullItemsMap =>
      _cacheHelper.cachedFullItemsMap;
  bool get isBackgroundLoadingFull => _cacheHelper.isBackgroundLoadingFull;

  void updateStatsCache(Map<String, dynamic> stats) {
    _cacheHelper.updateStatsCache(stats);
  }

  void clearStatsCache() {
    _cacheHelper.clearStatsCache();
  }

  /// 启动后台全量加载任务（widget 无关，加载完自动缓存）
  /// 如果已在加载中或缓存有效则跳过
  void ensureFullDataCached({bool forceRefresh = false}) {
    _cacheHelper.ensureFullDataCached(
      forceRefresh: forceRefresh,
      getAllRecords: getAllFinancialRecords,
      getItemsByRecordId: getFinancialItemsByRecordId,
      notifyListeners: notifyListeners,
    );
  }

  /// 渐进式加载统计：先快速显示初步数字，后台任务独立运行
  Future<void> loadStatsProgressively({
    required int initialCount,
    required int batchSize,
    required void Function(Map<String, dynamic> stats, bool isDone) onProgress,
    bool forceRefresh = false,
  }) async {
    if (!initialized) return;

    // 有完整缓存：先显示初步数字，再立即给出完整缓存
    if (!forceRefresh && _cacheHelper.hasFullItemsCache) {
      try {
        final initialRecords = await getPaginatedFinancialRecords(
          1,
          initialCount,
        );
        final initialItemsMap = <int, List<FinancialItem>>{};
        for (final r in initialRecords) {
          if (r.id != null) {
            try {
              initialItemsMap[r.id!] = await getFinancialItemsByRecordId(r.id!);
            } catch (_) {
              initialItemsMap[r.id!] = [];
            }
          }
        }
        onProgress(_cacheHelper.cachedStats!, false);
      } catch (_) {}
      onProgress(_cacheHelper.cachedStats!, true);
      return;
    }

    // 无完整缓存：先显示初步数字
    try {
      final initialRecords = await getPaginatedFinancialRecords(
        1,
        initialCount,
      );
      final initialItemsMap = <int, List<FinancialItem>>{};
      for (final r in initialRecords) {
        if (r.id != null) {
          try {
            initialItemsMap[r.id!] = await getFinancialItemsByRecordId(r.id!);
          } catch (_) {
            initialItemsMap[r.id!] = [];
          }
        }
      }
      onProgress(_cacheHelper.cachedStats!, false);
    } catch (_) {}

    // 启动后台全量加载（独立于 widget 生命周期）
    ensureFullDataCached(forceRefresh: forceRefresh);
  }

  // 带日期筛选的分页查询（日期为空则不筛选）
  Future<List<FinancialRecord>> getPaginatedFinancialRecordsWithDateFilter(
    int page,
    int pageSize, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _wrapFinancialOperation(
      'getPaginatedFinancialRecordsWithDateFilter',
      () => _queryService.getPaginatedFinancialRecordsWithDateFilter(
        page: page,
        pageSize: pageSize,
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  // 带日期筛选的记录总数
  Future<int> getFinancialRecordCountWithDateFilter({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!initialized) {
      return 0;
    }

    return await _wrapFinancialOperation(
      'getFinancialRecordCountWithDateFilter',
      () => _queryService.getFinancialRecordCount(
        startDate: startDate,
        endDate: endDate,
      ),
    );
  }

  // 添加财务记录
  Future<int> addFinancialRecord(FinancialRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _recordService.addFinancialRecord(
      record,
      clearCache: () async {
        clearCache();
      },
      markFinancialsNeedRefresh: markFinancialsNeedRefresh,
    );
  }

  // 更新财务记录
  Future<int> updateFinancialRecord(FinancialRecord record) async {
    if (!initialized || record.id == null) {
      throw Exception('数据库未初始化或记录ID为空');
    }

    return await _recordService.updateFinancialRecord(
      record,
      clearCache: () async {
        clearCache();
      },
      markFinancialsNeedRefresh: markFinancialsNeedRefresh,
    );
  }

  // 删除财务记录
  Future<int> deleteFinancialRecord(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _recordService.deleteFinancialRecord(
      recordId,
      clearCache: () async {
        clearCache();
      },
      markFinancialsNeedRefresh: markFinancialsNeedRefresh,
    );
  }

  // 根据患者ID获取财务记录
  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(
    int patientId,
  ) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _recordService.getFinancialRecordsByPatientId(patientId);
  }

  // =================== 财务项目明细相关方法（委托给 itemService）===================

  // 根据财务记录ID获取项目明细
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _itemService.getFinancialItemsByRecordId(recordId);
  }

  // 添加财务项目明细
  Future<int> addFinancialItem(FinancialItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _itemService.addFinancialItem(
      item,
      markFinancialsNeedRefresh: markFinancialsNeedRefresh,
    );
  }

  // 更新财务项目明细
  Future<int> updateFinancialItem(FinancialItem item) async {
    if (!initialized || item.id == null) {
      throw Exception('数据库未初始化或项目ID为空');
    }

    return await _itemService.updateFinancialItem(
      item,
      markFinancialsNeedRefresh: markFinancialsNeedRefresh,
    );
  }

  // 删除财务项目明细
  Future<int> deleteFinancialItem(int itemId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _itemService.deleteFinancialItem(
      itemId,
      markFinancialsNeedRefresh: markFinancialsNeedRefresh,
    );
  }

  // =================== 统计方法（委托给 statisticsService）===================

  // 获取患者总消费额
  Future<double> getPatientTotalCost(int patientId) async {
    return await _wrapFinancialOperation(
      'getPatientTotalCost',
      () => _statisticsService.getPatientTotalCost(
        patientId: patientId,
        dataSourceType: _dataSourceType,
        sqliteDatabase: _database,
        mysqlConnection: _currentMysqlConnection,
        getDoctorFilter: _permissionService.getDoctorFilter,
        shouldFilterByDoctor: _permissionService.shouldFilterByDoctor,
      ),
    );
  }

  // 获取所有财务记录的统计信息
  Future<Map<String, dynamic>> getFinancialStatistics() async {
    return await _wrapFinancialOperation(
      'getFinancialStatistics',
      () => _statisticsService.getFinancialStatistics(
        dataSourceType: _dataSourceType,
        sqliteDatabase: _database,
        mysqlConnection: _currentMysqlConnection,
        getDoctorFilter: _permissionService.getDoctorFilter,
        shouldFilterByDoctor: _permissionService.shouldFilterByDoctor,
      ),
    );
  }

  Future<T> _wrapFinancialOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    if (_dbWrapper == null) {
      return await operation();
    }
    return await _dbWrapper!.wrapOperation(operationName, operation);
  }

  /// 获取所有财务项目明细（带权限过滤）
  Future<List<Map<String, dynamic>>> getAllFinancialItemsWithDetailsFiltered({
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    DateTime? startDate,
    DateTime? endDate,
    String? patientName,
    String? itemName,
    double? priceMin,
    double? priceMax,
    double? processingMin,
    double? processingMax,
  }) async {
    if (!initialized) return [];

    return await _queryService.getAllFinancialItemsWithDetailsFiltered(
      sortBy: sortBy,
      sortOrder: sortOrder,
      startDate: startDate,
      endDate: endDate,
      patientName: patientName,
      itemName: itemName,
      priceMin: priceMin,
      priceMax: priceMax,
      processingMin: processingMin,
      processingMax: processingMax,
    );
  }
}

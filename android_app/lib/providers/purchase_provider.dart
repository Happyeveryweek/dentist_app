import 'package:flutter/foundation.dart';
import 'package:dentist_app/models/purchase_item.dart';
import 'package:dentist_app/models/purchase_record.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/utils/database_operation_wrapper.dart';
import 'package:dentist_app/data_sources/purchase_data_source.dart'
    hide MySqlPurchaseDataSource;
import 'package:dentist_app/data_sources/sqlite_purchase_data_source.dart';
import 'package:dentist_app/data_sources/mysql_purchase_data_source.dart';
import 'package:dentist_app/features/purchases/services/purchase_cache_service.dart';
import 'package:dentist_app/features/purchases/services/purchase_permission_service.dart';
import 'package:dentist_app/features/purchases/services/purchase_connection_service.dart';
import 'package:dentist_app/features/purchases/services/purchase_initialization_service.dart';
import 'package:dentist_app/features/purchases/services/purchase_statistics_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:async';
import '../utils/app_logger.dart';

class PurchaseProvider extends ChangeNotifier {
  // 数据库连接
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _dataSourceType = 'sqlite';

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 用户提供者引用（用于权限控制）
  UserProvider? _userProvider;

  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;

  // 数据源具体实现
  SqlitePurchaseDataSource? _sqliteDataSource;
  MySqlPurchaseDataSource? _mysqlDataSource;

  // 初始化标志
  bool _isInitializedFlag = false;

  // 服务实例
  PurchaseCacheService? _cacheService;
  PurchasePermissionService? _permissionService;
  PurchaseConnectionService? _connectionService;
  PurchaseDatabaseStatisticsService? _statisticsService;
  final PurchaseInitializationService _initializationService =
      PurchaseInitializationService();

  // 刷新标志
  bool _purchasesNeedRefresh = false;

  // Getters
  bool get initialized => _database != null || _currentMysqlConnection != null;
  bool get purchasesNeedRefresh => _purchasesNeedRefresh;
  bool get isConnected => _connectionService?.isConnected ?? true;
  bool get isReconnecting => _connectionService?.isReconnecting ?? false;
  String? get lastError => _connectionService?.lastError;
  bool get hasValidCache => _cacheService?.hasValidCache ?? false;
  DateTime? get lastCacheTime => _cacheService?.lastCacheTime;
  int get cachedRecordsCount => _cacheService?.cachedRecordsCount ?? 0;
  bool get hasCache => _cacheService?.hasCache ?? false;
  List<PurchaseRecord> get cachedRecords => _cacheService?.cachedRecords ?? [];

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
    _sqliteDataSource = SqlitePurchaseDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlPurchaseDataSource.withConnectionGetter(
      () => _currentMysqlConnection,
    );
  }

  // 设置用户提供者（用于权限控制）
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  PurchaseDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      final dataSource = _mysqlDataSource;
      if (dataSource == null) {
        throw Exception('MySQL采购数据源未初始化');
      }
      return dataSource;
    } else {
      final dataSource = _sqliteDataSource;
      if (dataSource == null) {
        throw Exception('SQLite采购数据源未初始化');
      }
      return dataSource;
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
      AppLogger.info('获取最新MySQL连接失败: $e');
    }

    return _mysqlConnection;
  }

  // 获取当前数据源类型
  String get dataSourceType => _dataSourceType;

  // 从DatabaseProvider获取数据库连接（保持向后兼容）
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag) return;

    try {
      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;
      final result = await _initializationService.initialize(
        dbProvider: dbProvider,
        userProvider: _userProvider,
        dataSourceType: _dataSourceType,
        database: _database,
        mysqlConnection: _mysqlConnection,
        log: print,
      );

      _database = result.database;
      _mysqlConnection = result.mysqlConnection;
      _dataSourceType = result.dataSourceType;
      _isInitializedFlag = result.initialized;
      _dbWrapper = result.dbWrapper;
      _cacheService = result.cacheService;
      _permissionService = result.permissionService;
      _connectionService = result.connectionService;
      _statisticsService = result.statisticsService;
      _sqliteDataSource = result.sqliteDataSource;
      _mysqlDataSource = result.mysqlDataSource;

      if (!_isInitializedFlag) {
        AppLogger.info('警告：采购Provider未完成初始化，延迟重试...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isInitializedFlag) {
            initializeFromDatabase(dbProvider);
          }
        });
        return;
      }

      AppLogger.info('PurchaseProvider初始化完成');
    } catch (e) {
      AppLogger.info('PurchaseProvider初始化失败: $e');
      // 设置默认值，但不标记为已初始化
      _dataSourceType = 'sqlite';
      _isInitializedFlag = false;
    }

    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 构造函数
  PurchaseProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
  }

  // 设置数据库连接
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
  }) {
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
  }

  // 标记需要刷新
  void markPurchasesNeedRefresh() {
    _purchasesNeedRefresh = true;
    notifyListeners();
  }

  // 清除刷新标志
  void clearPurchasesNeedRefresh() {
    _purchasesNeedRefresh = false;
  }

  // 清除缓存
  void clearCache() {
    _cacheService?.clearCache();
    _purchasesNeedRefresh = true; // 标记需要刷新
    AppLogger.info('采购数据缓存已清除，标记需要刷新');
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // =================== 采购记录相关方法 ===================

  // 获取所有采购记录（带缓存）
  Future<List<PurchaseRecord>> getAllPurchaseRecords() async {
    if (!initialized) {
      return cachedRecords; // 优雅降级而不是抛出异常
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return cachedRecords;

    return await wrapper.wrapOperation('getAllPurchaseRecords', () async {
      try {
        // 优先检查缓存（像财务管理一样）
        if (_cacheService?.isCacheValid() == true) {
          AppLogger.info('使用缓存的采购记录数据: ${cachedRecords.length} 条');
          return cachedRecords;
        }

        AppLogger.info('🔄 从数据库获取最新采购记录...');
        List<PurchaseRecord> records = [];

        // 检查是否需要权限过滤
        final doctorFilter = _permissionService?.getDoctorFilter();
        if (doctorFilter != null &&
            (_permissionService?.shouldFilterByDoctor() ?? false)) {
          // 使用数据源模式（带权限过滤）
          records = await _currentDataSource.getAllPurchases(
            doctorFilter: doctorFilter,
          );
          AppLogger.info('✅ 权限过滤查询成功，获取到 ${records.length} 条采购记录（医生：$doctorFilter）');
        } else {
          // 使用数据源模式（统一接口）
          records = await _currentDataSource.getAllPurchases();
          AppLogger.info('✅ 数据源模式查询成功，获取到 ${records.length} 条采购记录');
        }

        // 更新缓存
        _cacheService?.updateCache(records, {});
        AppLogger.info('✅ 采购记录缓存已更新');
        return records;
      } catch (e) {
        AppLogger.info('❌ 获取采购记录失败: $e');

        // 优雅降级：如果有缓存就返回缓存，否则返回空列表（像财务管理一样）
        if (_cacheService?.isCacheValid() == true) {
          AppLogger.info('使用缓存的采购记录数据，查询失败: $e');
          return cachedRecords;
        }

        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 智能获取采购记录（优先使用缓存）
  Future<List<PurchaseRecord>> getPurchaseRecordsWithCache() async {
    // 如果缓存有效且连接正常，直接返回缓存
    if (_cacheService?.isCacheValid() == true &&
        isConnected &&
        !_purchasesNeedRefresh) {
      AppLogger.info('使用缓存的采购记录数据: ${cachedRecords.length} 条');
      return cachedRecords;
    }

    try {
      AppLogger.info('🔄 缓存无效或需要刷新，从数据库获取最新数据...');
      // 尝试从数据库获取最新数据
      final records = await getAllPurchaseRecords();

      // 更新缓存并清除刷新标志
      _cacheService?.updateCache(records, {});
      _purchasesNeedRefresh = false;

      return records;
    } catch (e) {
      AppLogger.info('❌ 获取最新数据失败: $e');
      // 如果获取失败但有缓存，返回缓存数据
      if (hasCache) {
        AppLogger.info('使用缓存的采购记录数据，连接异常: $e');
        return cachedRecords;
      }
      rethrow;
    }
  }

  // 搜索采购记录
  Future<List<PurchaseRecord>> searchPurchaseRecords(String keyword) async {
    if (!initialized) {
      return [];
    }

    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return await getAllPurchaseRecords();
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return [];

    return await wrapper.wrapOperation('searchPurchaseRecords', () async {
      try {
        final doctorFilter = _permissionService?.getDoctorFilter();
        if (doctorFilter != null &&
            (_permissionService?.shouldFilterByDoctor() ?? false)) {
          return await _currentDataSource.searchPurchases(
            trimmed,
            doctorFilter: doctorFilter,
          );
        }

        return await _currentDataSource.searchPurchases(trimmed);
      } catch (e) {
        AppLogger.info('搜索采购记录失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      }
    });
  }

  // 根据ID获取采购记录
  Future<PurchaseRecord?> getPurchaseRecordById(int id) async {
    if (!initialized) {
      return null;
    }

    try {
      // 使用数据源模式（统一接口）
      return await _currentDataSource.getPurchaseById(id);
    } catch (e) {
      AppLogger.info('获取采购记录失败: $e');
      return null;
    }
  }

  // 添加采购记录
  Future<int> addPurchaseRecord(PurchaseRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return -1;

    return await wrapper.wrapOperation('addPurchaseRecord', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createPurchase(record);
        AppLogger.info('✅ 数据源模式添加成功，ID: $id');

        if (id > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markPurchasesNeedRefresh();
          AppLogger.info('✅ 采购记录添加成功，已清除缓存并标记刷新');
        }

        return id;
      } catch (e) {
        AppLogger.info('添加采购记录失败: $e');
        rethrow;
      }
    });
  }

  // 更新采购记录
  Future<int> updatePurchaseRecord(PurchaseRecord record) async {
    if (!initialized || record.id == null) {
      throw Exception('数据库未初始化或记录ID为空');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('updatePurchaseRecord', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updatePurchase(record);
        final count = success ? 1 : 0;
        AppLogger.info('✅ 数据源模式更新${success ? "成功" : "失败"}');

        if (count > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markPurchasesNeedRefresh();
          AppLogger.info('✅ 采购记录更新成功，已清除缓存并标记刷新');
        }

        return count;
      } catch (e) {
        AppLogger.info('更新采购记录失败: $e');
        rethrow;
      }
    });
  }

  // 删除采购记录
  Future<int> deletePurchaseRecord(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('deletePurchaseRecord', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deletePurchase(recordId);
        final count = success ? 1 : 0;

        if (count > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markPurchasesNeedRefresh();
          AppLogger.info('✅ 采购记录删除成功，已清除缓存并标记刷新');
        }

        return count;
      } catch (e) {
        AppLogger.info('删除采购记录失败: $e');
        rethrow;
      }
    });
  }

  // =================== 采购项目明细相关方法 ===================

  // 根据采购记录ID获取项目明细
  Future<List<PurchaseItem>> getPurchaseItemsByRecordId(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _wrapPurchaseItemOperation(
      'getPurchaseItemsByRecordId',
      () async {
        try {
          // 使用数据源模式（统一接口）
          final results = await _currentDataSource.getPurchaseItemsByRecordId(
            recordId,
          );
          return results
              .map((e) => PurchaseItem.fromMap(e, dataSource: _dataSourceType))
              .toList();
        } catch (e) {
          AppLogger.info('获取采购项目明细失败: $e');
          rethrow;
        }
      },
    );
  }

  // 添加采购项目明细
  Future<int> addPurchaseItem(PurchaseItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _wrapPurchaseItemOperation('addPurchaseItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createPurchaseItem(item);

        if (id > 0) {
          markPurchasesNeedRefresh();
        }

        return id;
      } catch (e) {
        AppLogger.info('添加采购项目明细失败: $e');
        rethrow;
      }
    });
  }

  // 更新采购项目明细
  Future<int> updatePurchaseItem(PurchaseItem item) async {
    if (!initialized || item.id == null) {
      throw Exception('数据库未初始化或项目ID为空');
    }

    return await _wrapPurchaseItemOperation('updatePurchaseItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updatePurchaseItem(item);
        final count = success ? 1 : 0;

        if (count > 0) {
          markPurchasesNeedRefresh();
        }

        return count;
      } catch (e) {
        AppLogger.info('更新采购项目明细失败: $e');
        rethrow;
      }
    });
  }

  // 删除采购项目明细
  Future<int> deletePurchaseItem(int itemId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _wrapPurchaseItemOperation('deletePurchaseItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deletePurchaseItem(itemId);
        final count = success ? 1 : 0;

        if (count > 0) {
          markPurchasesNeedRefresh();
        }

        return count;
      } catch (e) {
        AppLogger.info('删除采购项目明细失败: $e');
        rethrow;
      }
    });
  }

  Future<T> _wrapPurchaseItemOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) {
      return await operation();
    }
    return await wrapper.wrapOperation(operationName, operation);
  }

  // =================== 统计方法 ===================

  // 获取采购统计信息
  Future<Map<String, dynamic>> getPurchaseStatistics() async {
    if (!initialized) {
      return {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalQuantity': 0,
        'supplierCount': 0,
      };
    }

    return await _wrapPurchaseItemOperation('getPurchaseStatistics', () async {
      try {
        // 更新统计服务的数据库连接
        _statisticsService = PurchaseDatabaseStatisticsService(
          sqliteDatabase: _database,
          mysqlConnection: _currentMysqlConnection,
          mysqlConnectionGetter: () => _currentMysqlConnection,
          dataSourceType: _dataSourceType,
          getDoctorFilter: () => _permissionService?.getDoctorFilter(),
          shouldFilterByDoctor:
              () => _permissionService?.shouldFilterByDoctor() ?? false,
          testMySqlConnection:
              () =>
                  _connectionService?.testMySqlConnection(
                    _currentMysqlConnection,
                  ) ??
                  Future.value(false),
        );

        final statisticsService = _statisticsService;
        if (statisticsService == null) {
          return {
            'totalRecords': 0,
            'totalAmount': 0.0,
            'totalQuantity': 0,
            'supplierCount': 0,
          };
        }
        return await statisticsService.getPurchaseStatistics();
      } catch (e) {
        AppLogger.info('获取采购统计信息失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return {
          'totalRecords': 0,
          'totalAmount': 0.0,
          'totalQuantity': 0,
          'supplierCount': 0,
        };
      }
    });
  }

  // 根据日期范围获取采购统计
  Future<Map<String, dynamic>> getPurchaseStatisticsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (!initialized) {
      return {'totalRecords': 0, 'totalAmount': 0.0, 'totalQuantity': 0};
    }

    return await _wrapPurchaseItemOperation(
      'getPurchaseStatisticsByDateRange',
      () async {
        try {
          // 更新统计服务的数据库连接
          _statisticsService = PurchaseDatabaseStatisticsService(
            sqliteDatabase: _database,
            mysqlConnection: _currentMysqlConnection,
            mysqlConnectionGetter: () => _currentMysqlConnection,
            dataSourceType: _dataSourceType,
            getDoctorFilter: () => _permissionService?.getDoctorFilter(),
            shouldFilterByDoctor:
                () => _permissionService?.shouldFilterByDoctor() ?? false,
            testMySqlConnection:
                () =>
                    _connectionService?.testMySqlConnection(
                      _currentMysqlConnection,
                    ) ??
                    Future.value(false),
          );

          final statisticsService = _statisticsService;
          if (statisticsService == null) {
            return {'totalRecords': 0, 'totalAmount': 0.0, 'totalQuantity': 0};
          }
          return await statisticsService.getPurchaseStatisticsByDateRange(
            startDate,
            endDate,
          );
        } catch (e) {
          AppLogger.info('获取日期范围采购统计失败: $e');
          if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
          return {'totalRecords': 0, 'totalAmount': 0.0, 'totalQuantity': 0};
        }
      },
    );
  }
}

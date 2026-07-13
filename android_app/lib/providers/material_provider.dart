import 'package:flutter/foundation.dart';
import '../models/material.dart';
import '../utils/database_operation_wrapper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../data_sources/material_data_source.dart';
import '../features/materials/services/material_initialization_service.dart';
import 'dart:async';
import '../utils/app_logger.dart';

class MaterialProvider extends ChangeNotifier {
  // 数据库连接
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _dataSourceType = 'sqlite';

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;

  // 数据源实现
  SqliteMaterialDataSource? _sqliteDataSource;
  MySqlMaterialDataSource? _mysqlDataSource;
  final MaterialInitializationService _initializationService =
      MaterialInitializationService();

  // 初始化标志
  bool _isInitializedFlag = false;
  bool _isInitializing = false;

  // 刷新标志
  bool _materialsNeedRefresh = false;

  // Getters
  bool get initialized => _database != null || _mysqlConnection != null;
  bool get materialsNeedRefresh => _materialsNeedRefresh;

  // 检查数据库是否已初始化
  bool get isInitialized {
    if (_dataSourceType == 'mysql') {
      return _mysqlConnection != null;
    } else {
      return _database != null;
    }
  }

  // 获取当前数据源（优先使用数据源对象）
  MaterialDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      final dataSource = _mysqlDataSource;
      if (dataSource == null) throw Exception('MySQL材料数据源未初始化');
      return dataSource;
    } else {
      final dataSource = _sqliteDataSource;
      if (dataSource == null) throw Exception('SQLite材料数据源未初始化');
      return dataSource;
    }
  }

  // 获取最新的 MySQL 连接（从 DatabaseProvider 获取以避免过期连接）
  MySqlConnection? get _currentMysqlConnection {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }

    try {
      final latest = _databaseProvider.mysqlConnection;
      if (latest != null) {
        _mysqlConnection = latest;
        return latest;
      }
    } catch (e) {
      AppLogger.info('获取最新MySQL连接失败: $e');
    }
    return _mysqlConnection;
  }

  // 获取当前数据源类型
  String get dataSourceType => _dataSourceType;

  bool get isInitializing => _isInitializing;

  // 从DatabaseProvider获取数据库连接
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag || _isInitializing) return;

    _isInitializing = true;

    try {
      AppLogger.info('MaterialProvider开始初始化...');

      // 保存 DatabaseProvider 引用，用于动态获取 MySQL 连接
      _databaseProvider = dbProvider;

      final result = await _initializationService.initializeFromDatabase(
        dbProvider: dbProvider,
      );

      _database = result.database;
      _mysqlConnection = result.mysqlConnection;
      _dataSourceType = result.dataSourceType;

      if (_dataSourceType == 'mysql') {
        _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(
          () => _currentMysqlConnection,
        );
      } else {
        final db = _database;
        if (db != null) {
          _sqliteDataSource = SqliteMaterialDataSource(db);
        }
      }

      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);

      _isInitializedFlag = result.initialized;
      if (!_isInitializedFlag) {
        AppLogger.info('警告：MaterialProvider未完成初始化，延迟重试...');
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isInitializedFlag) {
            initializeFromDatabase(dbProvider);
          }
        });
        return;
      }

      AppLogger.info('MaterialProvider初始化完成');
    } catch (e) {
      AppLogger.info('MaterialProvider初始化失败: $e');
      _isInitializedFlag = false;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!_isInitializedFlag) {
          initializeFromDatabase(dbProvider);
        }
      });
    } finally {
      _isInitializing = false;
    }

    Future.microtask(() => notifyListeners());
  }

  Future<bool> ensureReady() async {
    if (initialized) {
      return true;
    }

    final dbProvider = _databaseProvider;
    if (dbProvider == null) {
      return false;
    }

    if (!_isInitializing) {
      await initializeFromDatabase(dbProvider);
    }

    for (int attempt = 0; attempt < 10; attempt++) {
      if (initialized) {
        return true;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!initialized && !_isInitializing) {
      await initializeFromDatabase(dbProvider);
    }

    return initialized;
  }

  // 构造函数
  MaterialProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
    // 初始化数据源实现（如果已经传入连接）
    try {
      final db = _database;
      if (db != null) {
        _sqliteDataSource = SqliteMaterialDataSource(db);
      }
      if (_mysqlConnection != null) {
        _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(
          () => _currentMysqlConnection,
        );
      }
    } catch (e) {
      AppLogger.info('MaterialProvider 构造时初始化数据源失败: $e');
    }
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
    // 更新数据源实现
    try {
      if (database != null) {
        _sqliteDataSource = SqliteMaterialDataSource(database);
      }
      if (mysqlConnection != null) {
        _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(
          () => _currentMysqlConnection,
        );
      }
    } catch (e) {
      AppLogger.info('设置数据源实现失败: $e');
    }
  }

  // 标记需要刷新
  void markMaterialsNeedRefresh() {
    _materialsNeedRefresh = true;
    notifyListeners();
  }

  // =================== 材料相关方法 ===================

  // 获取所有材料
  Future<List<DentalMaterial>> getAllMaterials() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    return await _wrapMaterialOperation('getAllMaterials', () async {
      try {
        // 使用数据源模式（统一接口）
        final materials = await _currentDataSource.getAllMaterials();

        return materials;
      } catch (e) {
        AppLogger.info('获取材料列表失败: $e');
        rethrow;
      }
    });
  }

  // 根据ID获取材料
  Future<DentalMaterial?> getMaterialById(int id) async {
    if (!initialized) {
      return null;
    }

    return await _wrapMaterialOperation('getMaterialById', () async {
      try {
        // 使用数据源模式（统一接口）
        return await _currentDataSource.getMaterialById(id);
      } catch (e) {
        AppLogger.info('获取材料失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return null;
      }
    });
  }

  // 根据名称搜索材料
  Future<List<DentalMaterial>> searchMaterials(String query) async {
    if (!initialized || query.isEmpty) {
      return [];
    }

    return await _wrapMaterialOperation('searchMaterials', () async {
      try {
        // 使用数据源模式（统一接口）
        return await _currentDataSource.searchMaterials(query);
      } catch (e) {
        AppLogger.info('搜索材料失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return [];
      }
    });
  }

  // 添加材料
  Future<int> addMaterial(DentalMaterial material) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return -1;

    return await wrapper.wrapOperation('addMaterial', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createMaterial(material);

        if (id > 0) {
          markMaterialsNeedRefresh();
        }

        return id;
      } catch (e) {
        AppLogger.info('添加材料失败: $e');
        rethrow;
      }
    });
  }

  // 更新材料
  Future<int> updateMaterial(DentalMaterial material) async {
    if (!initialized || material.id == null) {
      throw Exception('数据库未初始化或材料ID为空');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('updateMaterial', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updateMaterial(material);
        final count = success ? 1 : 0;

        if (count > 0) {
          markMaterialsNeedRefresh();
        }

        return count;
      } catch (e) {
        AppLogger.info('更新材料失败: $e');
        rethrow;
      }
    });
  }

  // 删除材料
  Future<int> deleteMaterial(int materialId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('deleteMaterial', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deleteMaterial(materialId);
        final count = success ? 1 : 0;

        if (count > 0) {
          markMaterialsNeedRefresh();
        }

        return count;
      } catch (e) {
        AppLogger.info('删除材料失败: $e');
        rethrow;
      }
    });
  }

  // 获取材料统计信息
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    if (!initialized) {
      return {'totalMaterials': 0, 'totalValue': 0.0, 'supplierCount': 0};
    }

    return await _wrapMaterialOperation('getMaterialStatistics', () async {
      try {
        // 使用数据源模式（统一接口）
        return await _currentDataSource.getMaterialStatistics();
      } catch (e) {
        AppLogger.info('获取材料统计信息失败: $e');
        if (DatabaseOperationWrapper.isConnectionError(e)) rethrow;
        return {'totalMaterials': 0, 'totalValue': 0.0, 'supplierCount': 0};
      }
    });
  }

  Future<T> _wrapMaterialOperation<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) {
      return await operation();
    }
    return await wrapper.wrapOperation(operationName, operation);
  }
}

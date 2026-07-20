import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';

import '../models/material.dart' as material_models;
import '../models/data_source.dart';
import '../data_sources/material_data_source.dart';
import '../features/materials/services/material_sync_service.dart';
import '../services/module_mysql_connection_service.dart';
import '../utils/log_manager.dart';

/// 材料管理提供者
/// 负责处理所有与材料相关的数据库操作（不包括患者材料，患者材料在PatientProvider中）
/// 已升级为数据源架构 + 缓存机制 + MySQL动态连接获取
class MaterialProvider extends ChangeNotifier {
  // 数据源实例
  SqliteMaterialDataSource? _sqliteDataSource;
  MySqlMaterialDataSource? _mysqlDataSource;

  // 同步服务
  MaterialSyncService? _syncServiceInstance;
  MaterialSyncService get _syncService =>
      _syncServiceInstance ??= MaterialSyncService(
        getSyncMysqlConnection: () =>
            _mysqlConnectionService.getSyncConnection(),
        getEffectiveDataSourceType: () =>
            _effectiveDataSourceType ?? _dataSourceType,
      );
  ModuleMysqlConnectionService? _mysqlConnectionServiceInstance;
  ModuleMysqlConnectionService get _mysqlConnectionService =>
      _mysqlConnectionServiceInstance ??= ModuleMysqlConnectionService(
        logTag: 'MaterialMysqlConnectionService',
        getDatabaseProvider: () => _databaseProvider,
        getCachedConnection: () => _mysqlConnection,
        setCachedConnection: (connection) {
          _mysqlConnection = connection;
        },
        getEffectiveDataSourceType: () =>
            _effectiveDataSourceType ?? _dataSourceType,
      );

  // 缓存机制（20分钟有效期）
  List<material_models.MaterialInfo>? _cachedMaterials;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20);

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

  // 刷新标志
  bool _materialsNeedRefresh = false;

  // Getters
  bool get initialized =>
      _currentDataSource != null ||
      _database != null ||
      _mysqlConnection != null;
  bool get materialsNeedRefresh => _materialsNeedRefresh;
  String get dataSourceType => _effectiveDataSourceType ?? _dataSourceType;
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedMaterialsCount => _cachedMaterials?.length ?? 0;

  // 获取当前数据源
  MaterialDataSource? get _currentDataSource {
    final type = DataSourceType.tryParse(_effectiveDataSourceType);
    if (type == DataSourceType.mysql) {
      // 如果要求使用MySQL但未初始化，尝试降级到SQLite
      if (_mysqlDataSource == null && _sqliteDataSource != null) {
        LogManager.d('MaterialProvider', '⚠️ MySQL材料数据源未初始化，自动降级到SQLite');
        return _sqliteDataSource;
      }
      return _mysqlDataSource;
    } else if (type == DataSourceType.sqlite) {
      return _sqliteDataSource;
    }
    return null;
  }

  // 获取当前数据源，未初始化时抛出异常
  MaterialDataSource get _requireDataSource {
    final dataSource = _currentDataSource;
    if (dataSource == null) {
      throw Exception('材料数据源未初始化');
    }
    return dataSource;
  }

  MaterialDataSource? _dataSourceForType(String? effectiveDataSourceType) {
    final requestedType = DataSourceType.tryParse(
      effectiveDataSourceType ?? dataSourceType,
    );
    if (requestedType?.storageValue == dataSourceType) {
      return _currentDataSource;
    }
    if (requestedType == DataSourceType.mysql) {
      return _mysqlDataSource;
    }
    if (requestedType == DataSourceType.sqlite) {
      return _sqliteDataSource;
    }
    return null;
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

    // 服务实例通过 getter 懒加载
  }

  // 智能初始化（支持模块化配置）
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
  }) async {
    try {
      _databaseProvider = dbProvider;

      // 确定要使用的数据源类型
      String dbType = 'sqlite';

      // 如果是模块化模式且有模块配置，优先使用模块配置
      final materialsType = moduleDataSources?['materials'];
      if (dataSourceMode.isModularDataSourceMode && materialsType != null) {
        dbType = materialsType;
        LogManager.d('MaterialProvider',
            'MaterialProvider使用模块化配置: materials -> $dbType');
      } else {
        // 否则使用全局配置
        dbType = dbProvider.dataSourceType ?? 'sqlite';
        LogManager.d('MaterialProvider', 'MaterialProvider使用全局配置: $dbType');
      }

      _effectiveDataSourceType = dbType;

      // 一次性初始化正确的数据源
      if (dbType.isSqliteDataSource) {
        final database = dbProvider.database;
        if (database != null) {
          _sqliteDataSource = SqliteMaterialDataSource(database);
          _database = database; // 保持向后兼容
          _isConnected = true;
          _clearError();
          LogManager.d('MaterialProvider', 'MaterialProvider: SQLite数据源初始化完成');
        } else {
          _setError('SQLite数据库连接不可用');
        }
      } else if (dbType.isMySqlDataSource) {
        // 检查MySQL连接是否可用
        final mysqlConn = dbProvider.mysqlConnection;
        if (mysqlConn == null) {
          LogManager.d('MaterialProvider',
              '⚠️ MaterialProvider: MySQL连接不可用，自动降级到SQLite');
          _effectiveDataSourceType = 'sqlite';

          // 降级到SQLite
          final database = dbProvider.database;
          if (database != null) {
            _sqliteDataSource = SqliteMaterialDataSource(database);
            _database = database;
            _isConnected = true;
            _clearError();
            LogManager.d('MaterialProvider', 'MaterialProvider: 已降级到SQLite数据源');
          } else {
            _setError('SQLite数据库连接不可用');
          }
        } else {
          _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(
            () async {
              final conn = await _mysqlConnectionService.getCurrentConnection();
              if (conn == null) throw Exception('MySQL连接不可用');
              return conn;
            },
            reconnectCallback: () async {
              try {
                await _mysqlConnectionService.reconnectConnection();
                LogManager.d(
                    'MaterialProvider', '✅ MaterialProvider: MySQL重连成功');
              } catch (e) {
                LogManager.d(
                    'MaterialProvider', '❌ MaterialProvider: MySQL重连失败: $e');
              }
            },
          );
          _mysqlConnection = dbProvider.mysqlConnection; // 保持向后兼容

          // 测试MySQL连接
          final testResult = await _testMySqlConnection();
          if (testResult) {
            LogManager.d('MaterialProvider', 'MaterialProvider: MySQL数据源初始化完成');
          } else {
            LogManager.d('MaterialProvider',
                '⚠️ MaterialProvider: MySQL连接测试失败，自动降级到SQLite');
            _effectiveDataSourceType = 'sqlite';

            // 降级到SQLite
            final database = dbProvider.database;
            if (database != null) {
              _sqliteDataSource = SqliteMaterialDataSource(database);
              _database = database;
              _isConnected = true;
              _clearError();
              LogManager.d(
                  'MaterialProvider', 'MaterialProvider: 已降级到SQLite数据源');
            } else {
              _setError('SQLite数据库连接不可用');
            }
          }
        }
      }

      // 清除缓存，强制重新加载
      clearCache();
    } catch (e) {
      LogManager.d('MaterialProvider', 'MaterialProvider初始化失败: $e');
      _setError('初始化失败: $e');
    }
  }

  // 缓存管理
  bool _isCacheValid() {
    final cached = _cachedMaterials;
    final lastTime = _lastCacheTime;
    return cached != null &&
        lastTime != null &&
        DateTime.now().difference(lastTime) < _cacheValidDuration;
  }

  void _updateCache(List<material_models.MaterialInfo> materials) {
    _cachedMaterials = materials;
    _lastCacheTime = DateTime.now();
  }

  void clearCache() {
    _cachedMaterials = null;
    _lastCacheTime = null;
    LogManager.d('MaterialProvider', 'MaterialProvider: 缓存已清除');
  }

  // 错误处理
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
    LogManager.d('MaterialProvider', 'MaterialProvider错误: $error');
  }

  void _clearError() {
    _lastError = null;
    _isConnected = true;
  }

  // MySQL连接测试
  Future<bool> _testMySqlConnection() async {
    final success = await _mysqlConnectionService.testCurrentConnection();
    if (success) {
      _isConnected = true;
      _clearError();
      return true;
    }

    _setError('MySQL连接测试失败');
    return false;
  }

  // 设置数据库连接（向后兼容）
  Future<void> setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
  }) async {
    LogManager.d('MaterialProvider',
        'MaterialProvider: setDatabaseConnection被调用，但已升级为数据源架构');
    // 这个方法保留用于向后兼容，但实际初始化应该使用initializeFromDatabase
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
  }

  // 标记刷新
  void markMaterialsNeedRefresh() {
    _materialsNeedRefresh = true;
    notifyListeners();
  }

  // 重置刷新标志
  void resetMaterialsRefreshFlag() {
    _materialsNeedRefresh = false;
  }

  // 更新模块数据源配置
  void updateModuleDataSources(Map<String, String> moduleDataSources) {
    LogManager.d('MaterialProvider',
        'MaterialProvider.updateModuleDataSources - 模块数据源配置已更新: $moduleDataSources');

    // 如果材料模块的数据源类型发生变化，需要重新初始化
    if (_databaseProvider != null) {
      final newDataSourceType =
          moduleDataSources['materials'] ?? _dataSourceType;
      if (newDataSourceType != _effectiveDataSourceType) {
        LogManager.d('MaterialProvider',
            '材料模块数据源类型变更: $_effectiveDataSourceType -> $newDataSourceType');

        initializeFromDatabase(
          _databaseProvider,
          moduleDataSources: moduleDataSources,
          dataSourceMode: 'modular',
        );
      }
    }
  }

  // =================== 材料相关方法 ===================

  // 获取所有材料（使用缓存机制和数据源架构）
  Future<List<material_models.MaterialInfo>> getAllMaterials({
    bool forceRefresh = false,
  }) async {
    try {
      // 检查缓存是否有效
      if (!forceRefresh && _isCacheValid()) {
        final cached = _cachedMaterials;
        if (cached != null) return List.from(cached);
      }

      if (forceRefresh) {
        clearCache();
      }

      LogManager.d('MaterialProvider', '正在从数据源获取最新材料数据...');

      // 从数据源获取数据
      final materials = await _requireDataSource.getAllMaterials();

      // 更新缓存
      _updateCache(materials);

      // 重置刷新标志
      _materialsNeedRefresh = false;

      return materials;
    } catch (e) {
      LogManager.d('MaterialProvider', '获取材料数据失败: $e');
      _setError('获取材料数据失败: $e');

      // 如果有缓存数据，返回缓存（优雅降级）
      final cached = _cachedMaterials;
      if (cached != null) {
        LogManager.d('MaterialProvider', '使用缓存数据作为降级方案: ${cached.length} 条记录');
        return List.from(cached);
      }

      return [];
    }
  }

  Future<List<material_models.MaterialInfo>> getAllMaterialsInDataSource(
    String effectiveDataSourceType, {
    bool forceRefresh = false,
  }) async {
    try {
      if (!forceRefresh &&
          effectiveDataSourceType == dataSourceType &&
          _isCacheValid()) {
        final cached = _cachedMaterials;
        if (cached != null) return List.from(cached);
      }

      final ds = _dataSourceForType(effectiveDataSourceType);
      if (ds == null) {
        throw Exception('材料数据源未初始化: $effectiveDataSourceType');
      }

      final materials = await ds.getAllMaterials();
      if (effectiveDataSourceType == dataSourceType) {
        _updateCache(materials);
        _materialsNeedRefresh = false;
      }
      return materials;
    } catch (e) {
      LogManager.d(
          'MaterialProvider', '按指定数据源获取材料失败($effectiveDataSourceType): $e');
      return [];
    }
  }

  // 根据ID获取材料（使用数据源架构）
  Future<material_models.MaterialInfo?> getMaterialById(int id) async {
    try {
      return await _requireDataSource.getMaterialById(id);
    } catch (e) {
      LogManager.d('MaterialProvider', '根据ID获取材料失败: $e');
      return null;
    }
  }

  // 添加材料（使用数据源架构）
  Future<int> addMaterial(material_models.MaterialInfo material) async {
    try {
      final id = await _requireDataSource.createMaterial(material);
      if (id > 0) {
        clearCache(); // 清除缓存
        notifyListeners();

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync) {
          final materialMap = material.toMap();
          materialMap['id'] = id;
          _syncService.syncMaterialToMySQL(materialMap, id);
        }
      }
      return id;
    } catch (e) {
      LogManager.d('MaterialProvider', '添加材料失败: $e');
      _setError('添加材料失败: $e');
      rethrow;
    }
  }

  // 更新材料
  Future<bool> updateMaterial(material_models.MaterialInfo material) async {
    try {
      final success = await _requireDataSource.updateMaterial(material);
      if (success) {
        _cachedMaterials = null;
        _lastCacheTime = null;
        _materialsNeedRefresh = false;

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        final materialId = material.id;
        if (_syncService.needsSync && materialId != null) {
          final materialMap = material.toMap();
          _syncService.syncMaterialToMySQL(materialMap, materialId);
        }
      }
      return success;
    } catch (e) {
      LogManager.d('MaterialProvider', '更新材料失败: $e');
      return false;
    }
  }

  // 删除材料
  Future<bool> deleteMaterial(int id) async {
    try {
      final success = await _requireDataSource.deleteMaterial(id);
      if (success) {
        clearCache();
        notifyListeners();

        // 如果当前使用的是SQLite数据源，需要同步删除到MySQL
        if (_syncService.needsSync) {
          _syncService.syncDeleteMaterialToMySQL(id);
        }
      }
      return success;
    } catch (e) {
      LogManager.d('MaterialProvider', '删除材料失败: $e');
      return false;
    }
  }

  // 搜索材料
  Future<List<material_models.MaterialInfo>> searchMaterials(
      String query) async {
    try {
      return await _requireDataSource.searchMaterials(query);
    } catch (e) {
      LogManager.d('MaterialProvider', '搜索材料失败: $e');
      return [];
    }
  }

  // 获取下一个材料编码
  Future<String> getNextMaterialCode() async {
    try {
      return await _requireDataSource.getNextMaterialCode();
    } catch (e) {
      LogManager.d('MaterialProvider', '获取下一个材料编码失败: $e');
      _setError('获取下一个材料编码失败: $e');
      return 'M301';
    }
  }

  // 根据编码获取材料
  Future<material_models.MaterialInfo?> getMaterialByCode(String code) async {
    try {
      return await _requireDataSource.getMaterialByCode(code);
    } catch (e) {
      LogManager.d('MaterialProvider', '根据编码获取材料失败: $e');
      _setError('获取材料失败: $e');
      return null;
    }
  }

  // 根据类别获取材料
  Future<List<material_models.MaterialInfo>> getMaterialsByCategory(
      String category) async {
    try {
      return await _requireDataSource.getMaterialsByCategory(category);
    } catch (e) {
      LogManager.d('MaterialProvider', '根据类别获取材料失败: $e');
      _setError('根据类别获取材料失败: $e');
      return [];
    }
  }

  // 获取材料统计信息
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    try {
      return await _requireDataSource.getMaterialStatistics();
    } catch (e) {
      LogManager.d('MaterialProvider', '获取材料统计信息失败: $e');
      _setError('获取材料统计信息失败: $e');
      return {};
    }
  }

  // 分页获取材料
  Future<List<material_models.MaterialInfo>> getPaginatedMaterials({
    int page = 1,
    int pageSize = 20,
    String? searchQuery,
  }) async {
    try {
      return await _requireDataSource.getPaginatedMaterials(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
      );
    } catch (e) {
      LogManager.d('MaterialProvider', '分页获取材料失败: $e');
      _setError('分页获取材料失败: $e');
      return [];
    }
  }

  // 获取材料总数
  Future<int> getMaterialsCount({String? searchQuery}) async {
    try {
      return await _requireDataSource.getMaterialsCount(
          searchQuery: searchQuery);
    } catch (e) {
      LogManager.d('MaterialProvider', '获取材料总数失败: $e');
      _setError('获取材料总数失败: $e');
      return 0;
    }
  }

  // 清空所有牙科材料
  Future<bool> clearAllDentalMaterials() async {
    try {
      final success = await _requireDataSource.clearAllMaterials();
      if (success) {
        clearCache();
        notifyListeners();
      }
      return success;
    } catch (e) {
      LogManager.d('MaterialProvider', '清空牙科材料失败: $e');
      return false;
    }
  }

  // =================== SQLite→MySQL 同步方法 ===================
}

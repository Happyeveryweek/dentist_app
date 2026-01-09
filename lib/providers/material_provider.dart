import 'package:flutter/foundation.dart';
import '../models/material.dart';
import '../models/database_models.dart';
import '../providers/database_provider.dart';
import '../utils/database_operation_wrapper.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:intl/intl.dart';
import '../data_sources/material_data_source.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

  // 缓存机制
  List<DentalMaterial>? _cachedMaterials;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20);

  // 连接/状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;
  
  
  // 初始化标志
  bool _isInitializedFlag = false;
  
  // 数据列表
  List<DentalMaterial> _materials = [];
  
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
      if (_mysqlDataSource == null) throw Exception('MySQL材料数据源未初始化');
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) throw Exception('SQLite材料数据源未初始化');
      return _sqliteDataSource!;
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
      print('获取最新MySQL连接失败: $e');
    }
    return _mysqlConnection;
  }

  // 获取当前数据源类型
  String get dataSourceType => _dataSourceType;

  // 从DatabaseProvider获取数据库连接
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag) return;

    try {
      print('MaterialProvider开始初始化...');

      // 保存 DatabaseProvider 引用，用于动态获取 MySQL 连接
      _databaseProvider = dbProvider;

      // 兼容处理，支持 DatabaseProvider 的不同接口
      String dbType = 'sqlite';
      if (dbProvider.dbType != null) {
        dbType = dbProvider.dbType;
      } else if (dbProvider.dataSourceType != null) {
        dbType = dbProvider.dataSourceType;
      }

      if (dbType == 'mysql') {
        // 尝试获取当前连接（dbProvider 可能持有最新连接）
        _mysqlConnection = dbProvider.mysqlConnection;
        _dataSourceType = 'mysql';
        // 设置 MySQL 数据源，使用动态连接 getter
        _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(() => _currentMysqlConnection);
        print('✅ MaterialProvider MySQL 数据源设置成功');
      } else {
        // 异步获取 SQLite 数据库实例
        try {
          _database = await dbProvider.sqliteDatabase;
          print('MaterialProvider SQLite 数据源设置成功: ${_database != null ? "成功" : "失败"}');
        } catch (e) {
          print('获取SQLite数据库失败: $e');
          if (dbProvider.database != null) {
            _database = dbProvider.database;
            print('通过备用方式获取SQLite数据库: ${_database != null ? "成功" : "失败"}');
          }
        }
        _dataSourceType = 'sqlite';
        if (_database != null) {
          _sqliteDataSource = SqliteMaterialDataSource(_database!);
        }
      }

      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);

      _isInitializedFlag = true;
      print('MaterialProvider初始化完成');
    } catch (e) {
      print('MaterialProvider初始化失败: $e');
      _dataSourceType = 'sqlite';
      _isInitializedFlag = true;
    }

    Future.microtask(() => notifyListeners());
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
      if (_database != null) {
        _sqliteDataSource = SqliteMaterialDataSource(_database!);
      }
      if (_mysqlConnection != null) {
        _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(() => _currentMysqlConnection);
      }
    } catch (e) {
      print('MaterialProvider 构造时初始化数据源失败: $e');
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
        _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(() => _currentMysqlConnection);
      }
    } catch (e) {
      print('设置数据源实现失败: $e');
    }
  }
  
  // 标记需要刷新
  void markMaterialsNeedRefresh() {
    _materialsNeedRefresh = true;
    notifyListeners();
  }
  
  // 清除刷新标志
  void clearMaterialsNeedRefresh() {
    _materialsNeedRefresh = false;
  }

  // =================== 材料相关方法 ===================
  
  // 获取所有材料
  Future<List<DentalMaterial>> getAllMaterials() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final materials = await _currentDataSource.getAllMaterials();
      
      // 更新缓存
      _cachedMaterials = List.from(materials);
      _lastCacheTime = DateTime.now();
      
      return materials;
    } catch (e) {
      print('获取材料列表失败: $e');
      rethrow;
    }
  }

  // 根据ID获取材料
  Future<DentalMaterial?> getMaterialById(int id) async {
    if (!initialized) {
      return null;
    }

    try {
      // 使用数据源模式（统一接口）
      return await _currentDataSource.getMaterialById(id);
    } catch (e) {
      print('获取材料失败: $e');
      return null;
    }
  }

  // 根据名称搜索材料
  Future<List<DentalMaterial>> searchMaterials(String query) async {
    if (!initialized || query.isEmpty) {
      return [];
    }

    try {
      // 使用数据源模式（统一接口）
      return await _currentDataSource.searchMaterials(query);
    } catch (e) {
      print('搜索材料失败: $e');
      return [];
    }
  }

  // 添加材料
  Future<int> addMaterial(DentalMaterial material) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return -1;
    
    return await _dbWrapper!.wrapOperation('addMaterial', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createMaterial(material);

        if (id > 0) {
          markMaterialsNeedRefresh();
        }

        return id;
      } catch (e) {
        print('添加材料失败: $e');
        rethrow;
      }
    });
  }

  // 更新材料
  Future<int> updateMaterial(DentalMaterial material) async {
    if (!initialized || material.id == null) {
      throw Exception('数据库未初始化或材料ID为空');
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('updateMaterial', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updateMaterial(material);
        final count = success ? 1 : 0;

        if (count > 0) {
          markMaterialsNeedRefresh();
        }

        return count;
      } catch (e) {
        print('更新材料失败: $e');
        rethrow;
      }
    });
  }

  // 删除材料
  Future<int> deleteMaterial(int materialId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('deleteMaterial', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deleteMaterial(materialId);
        final count = success ? 1 : 0;

        if (count > 0) {
          markMaterialsNeedRefresh();
        }

        return count;
      } catch (e) {
        print('删除材料失败: $e');
        rethrow;
      }
    });
  }

  // 检查材料名称是否已存在
  Future<bool> isMaterialNameExists(String materialName, {int? excludeId}) async {
    if (!initialized) {
      return false;
    }

    try {
      // 使用数据源模式（通过搜索实现）
      final results = await searchMaterials(materialName);
      if (results.isEmpty) return false;
      if (excludeId != null) {
        return results.any((m) => m.id != excludeId && m.materialName == materialName);
      }
      return results.any((m) => m.materialName == materialName);
    } catch (e) {
      print('检查材料名称是否存在失败: $e');
      return false;
    }
  }

  // 获取材料统计信息
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    if (!initialized) {
      return {
        'totalMaterials': 0,
        'totalValue': 0.0,
        'supplierCount': 0,
      };
    }

    try {
      // 使用数据源模式（统一接口）
      return await _currentDataSource.getMaterialStatistics();
    } catch (e) {
      print('获取材料统计信息失败: $e');
      return {
        'totalMaterials': 0,
        'totalValue': 0.0,
        'supplierCount': 0,
      };
    }
  }

  // 生成材料编码
  Future<String> generateMaterialCode() async {
    if (!initialized) {
      return 'M001';
    }

    try {
      String prefix = 'M';
      int nextNumber = 1;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return 'M001';
        
        final result = await db.rawQuery(
          'SELECT material_code FROM materials WHERE material_code LIKE ? ORDER BY material_code DESC LIMIT 1',
          ['M%']
        );
        
        if (result.isNotEmpty) {
          final lastCode = result.first['material_code'] as String?;
          if (lastCode != null && lastCode.startsWith('M')) {
            final numberStr = lastCode.substring(1);
            final number = int.tryParse(numberStr);
            if (number != null) {
              nextNumber = number + 1;
            }
          }
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) return 'M001';
        
        final results = await conn.query(
          'SELECT material_code FROM materials WHERE material_code LIKE ? ORDER BY material_code DESC LIMIT 1',
          ['M%']
        );
        
        if (results.isNotEmpty) {
          final lastCode = results.first['material_code']?.toString();
          if (lastCode != null && lastCode.startsWith('M')) {
            final numberStr = lastCode.substring(1);
            final number = int.tryParse(numberStr);
            if (number != null) {
              nextNumber = number + 1;
            }
          }
        }
      }

      return '$prefix${nextNumber.toString().padLeft(3, '0')}';
    } catch (e) {
      print('生成材料编码失败: $e');
      return 'M001';
    }
  }
}
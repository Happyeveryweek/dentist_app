import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';
import '../models/material.dart' as material_models;
import '../data_sources/material_data_source.dart';
import '../utils/mysql_sync_connection_helper.dart';

/// 材料管理提供者
/// 负责处理所有与材料相关的数据库操作（不包括患者材料，患者材料在PatientProvider中）
/// 已升级为数据源架构 + 缓存机制 + MySQL动态连接获取
class MaterialProvider extends ChangeNotifier {
  // 数据源实例
  SqliteMaterialDataSource? _sqliteDataSource;
  MySqlMaterialDataSource? _mysqlDataSource;
  
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
  
  // 当前用户信息
  User? _currentUser;
  
  // 刷新标志
  bool _materialsNeedRefresh = false;
  
  // Getters
  bool get initialized => _currentDataSource != null || _database != null || _mysqlConnection != null;
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
    if (_effectiveDataSourceType == 'mysql') {
      // 如果要求使用MySQL但未初始化，尝试降级到SQLite
      if (_mysqlDataSource == null && _sqliteDataSource != null) {
        print('⚠️ MySQL材料数据源未初始化，自动降级到SQLite');
        return _sqliteDataSource;
      }
      return _mysqlDataSource;
    } else if (_effectiveDataSourceType == 'sqlite') {
      return _sqliteDataSource;
    }
    return null;
  }
  
  // MySQL动态连接获取
  MySqlConnection? get _currentMysqlConnection {
    if (_effectiveDataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }
    
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        return latestConnection;
      }
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
    }
    
    return _mysqlConnection;
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
    return MySqlSyncConnectionHelper.getSyncConnection(
      databaseProvider: _databaseProvider,
      cachedConnection: _mysqlConnection,
      onConnectionUpdate: (newConnection) {
        _mysqlConnection = newConnection;
      },
    );
  }
  
  // 构造函数
  MaterialProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
    User? currentUser,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
    _currentUser = currentUser;
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
      if (dataSourceMode == 'modular' && 
          moduleDataSources != null && 
          moduleDataSources.containsKey('materials')) {
        dbType = moduleDataSources['materials']!;
        print('MaterialProvider使用模块化配置: materials -> $dbType');
      } else {
        // 否则使用全局配置
        dbType = dbProvider.dataSourceType ?? 'sqlite';
        print('MaterialProvider使用全局配置: $dbType');
      }
      
      _effectiveDataSourceType = dbType;
      
      // 一次性初始化正确的数据源
      if (dbType == 'sqlite') {
        final database = dbProvider.database;
        if (database != null) {
          _sqliteDataSource = SqliteMaterialDataSource(database);
          _database = database; // 保持向后兼容
          _isConnected = true;
          _clearError();
          print('MaterialProvider: SQLite数据源初始化完成');
        } else {
          _setError('SQLite数据库连接不可用');
        }
      } else if (dbType == 'mysql') {
        // 检查MySQL连接是否可用
        final mysqlConn = dbProvider.mysqlConnection;
        if (mysqlConn == null) {
          print('⚠️ MaterialProvider: MySQL连接不可用，自动降级到SQLite');
          _effectiveDataSourceType = 'sqlite';
          
          // 降级到SQLite
          final database = dbProvider.database;
          if (database != null) {
            _sqliteDataSource = SqliteMaterialDataSource(database);
            _database = database;
            _isConnected = true;
            _clearError();
            print('MaterialProvider: 已降级到SQLite数据源');
          } else {
            _setError('SQLite数据库连接不可用');
          }
        } else {
          _mysqlDataSource = MySqlMaterialDataSource.withConnectionGetter(
            () async {
              final conn = await _currentMysqlConnection;
              if (conn == null) throw Exception('MySQL连接不可用');
              return conn;
            },
            reconnectCallback: () async {
              if (dbProvider != null) {
                try {
                  await dbProvider.initializeMySQL();
                  print('✅ MaterialProvider: MySQL重连成功');
                } catch (e) {
                  print('❌ MaterialProvider: MySQL重连失败: $e');
                }
              }
            },
          );
          _mysqlConnection = dbProvider.mysqlConnection; // 保持向后兼容
          
          // 测试MySQL连接
          final testResult = await _testMySqlConnection();
          if (testResult) {
            print('MaterialProvider: MySQL数据源初始化完成');
          } else {
            print('⚠️ MaterialProvider: MySQL连接测试失败，自动降级到SQLite');
            _effectiveDataSourceType = 'sqlite';
            
            // 降级到SQLite
            final database = dbProvider.database;
            if (database != null) {
              _sqliteDataSource = SqliteMaterialDataSource(database);
              _database = database;
              _isConnected = true;
              _clearError();
              print('MaterialProvider: 已降级到SQLite数据源');
            } else {
              _setError('SQLite数据库连接不可用');
            }
          }
        }
      }
      
      // 清除缓存，强制重新加载
      clearCache();
      
    } catch (e) {
      print('MaterialProvider初始化失败: $e');
      _setError('初始化失败: $e');
    }
  }
  
  // 缓存管理
  bool _isCacheValid() {
    return _cachedMaterials != null && 
           _lastCacheTime != null && 
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  void _updateCache(List<material_models.MaterialInfo> materials) {
    _cachedMaterials = materials;
    _lastCacheTime = DateTime.now();
  }
  
  void clearCache() {
    _cachedMaterials = null;
    _lastCacheTime = null;
    print('MaterialProvider: 缓存已清除');
  }
  
  // 错误处理
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
    print('MaterialProvider错误: $error');
  }
  
  void _clearError() {
    _lastError = null;
    _isConnected = true;
  }
  
  // MySQL连接测试
  Future<bool> _testMySqlConnection() async {
    if (_currentMysqlConnection == null) return false;
    
    try {
      await _currentMysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 10),
      );
      _isConnected = true;
      _clearError();
      return true;
    } catch (e) {
      _setError('MySQL连接测试失败: $e');
      return false;
    }
  }

  // 设置数据库连接（向后兼容）
  Future<void> setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
  }) async {
    print('MaterialProvider: setDatabaseConnection被调用，但已升级为数据源架构');
    // 这个方法保留用于向后兼容，但实际初始化应该使用initializeFromDatabase
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) _currentUser = currentUser;
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
    print('MaterialProvider.updateModuleDataSources - 模块数据源配置已更新: $moduleDataSources');
    
    // 如果材料模块的数据源类型发生变化，需要重新初始化
    if (_databaseProvider != null) {
      final newDataSourceType = moduleDataSources['materials'] ?? _dataSourceType;
      if (newDataSourceType != _effectiveDataSourceType) {
        print('材料模块数据源类型变更: $_effectiveDataSourceType -> $newDataSourceType');
        
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
  Future<List<material_models.MaterialInfo>> getAllMaterials() async {
    try {
      // 检查缓存是否有效
      if (_isCacheValid()) {
                return List.from(_cachedMaterials!);
      }

      print('正在从数据源获取最新材料数据...');
      
      // 从数据源获取数据
      final materials = await _currentDataSource!.getAllMaterials();
      
      // 更新缓存
      _updateCache(materials);
      
      // 重置刷新标志
      _materialsNeedRefresh = false;
      
            return materials;
      
    } catch (e) {
      print('获取材料数据失败: $e');
      _setError('获取材料数据失败: $e');
      
      // 如果有缓存数据，返回缓存（优雅降级）
      if (_cachedMaterials != null) {
        print('使用缓存数据作为降级方案: ${_cachedMaterials!.length} 条记录');
        return List.from(_cachedMaterials!);
      }
      
      return [];
    }
  }
  
  // 根据ID获取材料（使用数据源架构）
  Future<material_models.MaterialInfo?> getMaterialById(int id) async {
    try {
      return await _currentDataSource!.getMaterialById(id);
    } catch (e) {
      print('根据ID获取材料失败: $e');
      return null;
    }
  }
  
  // 添加材料（使用数据源架构）
  Future<int> addMaterial(material_models.MaterialInfo material) async {
    try {
      final id = await _currentDataSource!.createMaterial(material);
      if (id > 0) {
        clearCache(); // 清除缓存
        notifyListeners();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
                    final materialMap = material.toMap();
          materialMap['id'] = id;
          _trySyncMaterialToMySQL(materialMap, id);
        }
      }
      return id;
    } catch (e) {
      print('添加材料失败: $e');
      _setError('添加材料失败: $e');
      rethrow;
    }
  }

  // 创建材料（兼容性方法）
  Future<bool> createMaterial(material_models.MaterialInfo material) async {
    try {
      final id = await _currentDataSource!.createMaterial(material);
      if (id > 0) {
        clearCache();
        notifyListeners();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
                    final materialMap = material.toMap();
          materialMap['id'] = id;
          _trySyncMaterialToMySQL(materialMap, id);
        }
        
        return true;
      }
      return false;
    } catch (e) {
      print('创建材料失败: $e');
      _setError('创建材料失败: $e');
      return false;
    }
  }

  // 更新材料
  Future<bool> updateMaterial(material_models.MaterialInfo material) async {
    try {
      final success = await _currentDataSource!.updateMaterial(material);
      if (success) {
        clearCache();
        notifyListeners();
        
        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_effectiveDataSourceType == 'sqlite' && material.id != null) {
                    final materialMap = material.toMap();
          _trySyncMaterialToMySQL(materialMap, material.id!);
        }
      }
      return success;
    } catch (e) {
      print('更新材料失败: $e');
      return false;
    }
  }

  // 删除材料
  Future<bool> deleteMaterial(int id) async {
    try {
      final success = await _currentDataSource!.deleteMaterial(id);
      if (success) {
        clearCache();
        notifyListeners();
        
        // 如果当前使用的是SQLite数据源，需要同步删除到MySQL
        if (_effectiveDataSourceType == 'sqlite') {
                    _trySyncDeleteMaterialToMySQL(id);
        }
      }
      return success;
    } catch (e) {
      print('删除材料失败: $e');
      return false;
    }
  }

  // 搜索材料
  Future<List<material_models.MaterialInfo>> searchMaterials(String query) async {
    try {
      return await _currentDataSource!.searchMaterials(query);
    } catch (e) {
      print('搜索材料失败: $e');
      return [];
    }
  }

  // 获取下一个材料编码
  Future<String> getNextMaterialCode() async {
    try {
      return await _currentDataSource!.getNextMaterialCode();
    } catch (e) {
      print('获取下一个材料编码失败: $e');
      _setError('获取下一个材料编码失败: $e');
      return 'M301';
    }
  }

  // 根据编码获取材料
  Future<material_models.MaterialInfo?> getMaterialByCode(String code) async {
    try {
      return await _currentDataSource!.getMaterialByCode(code);
    } catch (e) {
      print('根据编码获取材料失败: $e');
      _setError('获取材料失败: $e');
      return null;
    }
  }

  // 根据类别获取材料
  Future<List<material_models.MaterialInfo>> getMaterialsByCategory(String category) async {
    try {
      return await _currentDataSource!.getMaterialsByCategory(category);
    } catch (e) {
      print('根据类别获取材料失败: $e');
      _setError('根据类别获取材料失败: $e');
      return [];
    }
  }

  // 获取材料统计信息
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    try {
      return await _currentDataSource!.getMaterialStatistics();
    } catch (e) {
      print('获取材料统计信息失败: $e');
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
      return await _currentDataSource!.getPaginatedMaterials(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
      );
    } catch (e) {
      print('分页获取材料失败: $e');
      _setError('分页获取材料失败: $e');
      return [];
    }
  }

  // 获取材料总数
  Future<int> getMaterialsCount({String? searchQuery}) async {
    try {
      return await _currentDataSource!.getMaterialsCount(searchQuery: searchQuery);
    } catch (e) {
      print('获取材料总数失败: $e');
      _setError('获取材料总数失败: $e');
      return 0;
    }
  }

  // 清空所有牙科材料
  Future<bool> clearAllDentalMaterials() async {
    try {
      final success = await _currentDataSource!.clearAllMaterials();
      if (success) {
        clearCache();
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('清空牙科材料失败: $e');
      return false;
    }
  }

  // 清空所有材料（兼容性方法）
  Future<bool> clearAllMaterials() async {
    return await clearAllDentalMaterials();
  }

  // 更新现有材料的类型（兼容性方法）
  Future<void> updateExistingMaterialTypes() async {
    if (!initialized) return;
    
    try {
      print('开始更新现有材料的类型分类...');
      
      // 在数据源架构中，我们通过直接访问数据库来执行批量更新
      // 这是一个特殊的维护操作，不适合通过标准的数据源接口
      
      if (_effectiveDataSourceType == 'sqlite' && _database != null) {
        final db = _database!;
        
        // 根据材料名称和编码更新类型
        final updates = [
          // 药品类
          "UPDATE materials SET material_type = '药品' WHERE material_name LIKE '%胶囊%' OR material_name LIKE '%片%' OR material_name LIKE '%注射液%'",
          
          // 局部麻醉药
          "UPDATE materials SET material_type = '局部麻醉药' WHERE material_name LIKE '%卡因%' OR material_name LIKE '%利多卡因%' OR material_name LIKE '%布比卡因%'",
          
          // 消毒用品
          "UPDATE materials SET material_type = '消毒用品' WHERE material_name LIKE '%消毒%' OR material_name LIKE '%酒精%' OR material_name LIKE '%双氧水%' OR material_name LIKE '%生理盐水%'",
          
          // 一次性用品
          "UPDATE materials SET material_type = '一次性用品' WHERE material_name LIKE '%一次性%'",
          
          // 牙科材料
          "UPDATE materials SET material_type = '牙科材料' WHERE material_name LIKE '%水门汀%' OR material_name LIKE '%树脂%' OR material_name LIKE '%粘接剂%' OR material_name LIKE '%封闭剂%'",
          
          // 牙科器械
          "UPDATE materials SET material_type = '牙科器械' WHERE material_name LIKE '%探针%' OR material_name LIKE '%镊子%' OR material_name LIKE '%刮匙%' OR material_name LIKE '%手机%' OR material_name LIKE '%光固化灯%'",
          
          // 根管治疗器械
          "UPDATE materials SET material_type = '根管治疗器械' WHERE material_name LIKE '%根管%' OR material_name LIKE '%拔髓针%'",
          
          // 牙科耗材
          "UPDATE materials SET material_type = '牙科耗材' WHERE material_name LIKE '%车针%' OR material_name LIKE '%牙胶尖%' OR material_name LIKE '%牙胶条%' OR material_name LIKE '%牙胶块%'",
          
          // 正畸材料
          "UPDATE materials SET material_type = '正畸材料' WHERE material_name LIKE '%弓丝%' OR material_name LIKE '%结扎丝%'",
          
          // 口腔护理用品
          "UPDATE materials SET material_type = '口腔护理用品' WHERE material_name LIKE '%牙膏%' OR material_name LIKE '%牙刷%' OR material_name LIKE '%漱口水%'",
          
          // 防护用品
          "UPDATE materials SET material_type = '防护用品' WHERE material_name LIKE '%防护%' OR material_name LIKE '%口罩%' OR material_name LIKE '%手套%'",
          
          // 办公用品
          "UPDATE materials SET material_type = '办公用品' WHERE material_name LIKE '%标签%' OR material_name LIKE '%记录本%' OR material_name LIKE '%笔%'",
        ];
        
        for (final update in updates) {
          await db.execute(update);
        }
      } else if (_effectiveDataSourceType == 'mysql' && _currentMysqlConnection != null) {
        final conn = _currentMysqlConnection!;
        
        // MySQL 版本的更新语句
        final updates = [
          "UPDATE materials SET material_type = '药品' WHERE material_name LIKE '%胶囊%' OR material_name LIKE '%片%' OR material_name LIKE '%注射液%'",
          "UPDATE materials SET material_type = '局部麻醉药' WHERE material_name LIKE '%卡因%' OR material_name LIKE '%利多卡因%' OR material_name LIKE '%布比卡因%'",
          "UPDATE materials SET material_type = '消毒用品' WHERE material_name LIKE '%消毒%' OR material_name LIKE '%酒精%' OR material_name LIKE '%双氧水%' OR material_name LIKE '%生理盐水%'",
          "UPDATE materials SET material_type = '一次性用品' WHERE material_name LIKE '%一次性%'",
          "UPDATE materials SET material_type = '牙科材料' WHERE material_name LIKE '%水门汀%' OR material_name LIKE '%树脂%' OR material_name LIKE '%粘接剂%' OR material_name LIKE '%封闭剂%'",
          "UPDATE materials SET material_type = '牙科器械' WHERE material_name LIKE '%探针%' OR material_name LIKE '%镊子%' OR material_name LIKE '%刮匙%' OR material_name LIKE '%手机%' OR material_name LIKE '%光固化灯%'",
          "UPDATE materials SET material_type = '根管治疗器械' WHERE material_name LIKE '%根管%' OR material_name LIKE '%拔髓针%'",
          "UPDATE materials SET material_type = '牙科耗材' WHERE material_name LIKE '%车针%' OR material_name LIKE '%牙胶尖%' OR material_name LIKE '%牙胶条%' OR material_name LIKE '%牙胶块%'",
          "UPDATE materials SET material_type = '正畸材料' WHERE material_name LIKE '%弓丝%' OR material_name LIKE '%结扎丝%'",
          "UPDATE materials SET material_type = '口腔护理用品' WHERE material_name LIKE '%牙膏%' OR material_name LIKE '%牙刷%' OR material_name LIKE '%漱口水%'",
          "UPDATE materials SET material_type = '防护用品' WHERE material_name LIKE '%防护%' OR material_name LIKE '%口罩%' OR material_name LIKE '%手套%'",
          "UPDATE materials SET material_type = '办公用品' WHERE material_name LIKE '%标签%' OR material_name LIKE '%记录本%' OR material_name LIKE '%笔%'",
        ];
        
        for (final update in updates) {
          await conn.query(update);
        }
      }
      
      // 更新完成后清除缓存
      clearCache();
      
      print('已成功更新现有材料的类型分类');
    } catch (e) {
      print('更新材料类型失败: $e');
    }
  }

  // =================== SQLite→MySQL 同步方法 ===================
  
  /// 尝试建立MySQL连接的辅助方法
  Future<MySqlConnection?> _tryEstablishMySQLConnection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final mysqlJson = prefs.getString('mysqlSettings');
      Map<String, dynamic>? settings;

      if (mysqlJson != null && mysqlJson.isNotEmpty) {
        try {
          settings = Map<String, dynamic>.from(jsonDecode(mysqlJson));
          print('从 SharedPreferences mysqlSettings 读取 MySQL 配置');
        } catch (e) {
          print('解析 SharedPreferences 中 mysqlSettings 失败: $e');
          settings = null;
        }
      }

      if (settings == null) {
        final host = prefs.getString('mysqlHost') ?? '';
        if (host.isNotEmpty) {
          settings = {
            'host': host,
            'port': prefs.getString('mysqlPort') ?? '3306',
            'database': prefs.getString('mysqlDatabase') ?? '',
            'username': prefs.getString('mysqlUsername') ?? '',
            'password': prefs.getString('mysqlPassword') ?? '',
          };
          print('从 SharedPreferences 单独键读取 MySQL 配置');
        }
      }

      if (settings != null) {
        try {
          final host = settings['host'];
          final port = int.tryParse(settings['port']?.toString() ?? '3306') ?? 3306;
          final database = settings['database'];
          final username = settings['username'];
          final password = settings['password'];

          final conn = await MySqlConnection.connect(ConnectionSettings(
            host: host,
            port: port,
            db: database,
            user: username,
            password: password,
          ));

          try {
            await conn.query("SET NAMES 'utf8mb4'");
            await conn.query("SET character_set_connection = 'utf8mb4'");
            await conn.query("SET character_set_results = 'utf8mb4'");
          } catch (e) {
            print('设置MySQL会话字符集失败: $e');
          }

          _mysqlConnection = conn;
          return conn;
        } catch (e) {
          print('尝试初始化MySQL连接失败: $e');
          return null;
        }
      }
    } catch (e) {
      print('读取SharedPreferences以获取MySQL设置失败: $e');
    }
    return null;
  }

  /// 尝试将SQLite中的材料同步到MySQL（非阻塞操作）
  Future<void> _trySyncMaterialToMySQL(Map<String, dynamic> materialMap, int materialId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过材料同步(id=$materialId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT id FROM materials WHERE id = ? LIMIT 1',
            [materialId],
          );

          if (existResult.isNotEmpty) {
            // 更新操作
            final result = await conn.query('''
              UPDATE materials SET
                material_code = ?, material_name = ?, material_type = ?,
                specification = ?, unit = ?, unit_price = ?,
                stock_quantity = ?, min_stock = ?, supplier = ?,
                notes = ?, created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              materialMap['material_code'],
              materialMap['material_name'],
              materialMap['material_type'],
              materialMap['specification'],
              materialMap['unit'],
              materialMap['unit_price'],
              materialMap['stock_quantity'],
              materialMap['min_stock'],
              materialMap['supplier'],
              materialMap['notes'],
              materialMap['created_at'],
              materialMap['updated_at'],
              materialId,
            ]);
            print('成功更新MySQL材料(id=$materialId)，影响行数: ${result.affectedRows}');
          } else {
            // 插入操作
            final result = await conn.query('''
              INSERT INTO materials
              (id, material_code, material_name, material_type, specification, unit, unit_price, stock_quantity, min_stock, supplier, notes, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              materialId,
              materialMap['material_code'],
              materialMap['material_name'],
              materialMap['material_type'],
              materialMap['specification'],
              materialMap['unit'],
              materialMap['unit_price'],
              materialMap['stock_quantity'],
              materialMap['min_stock'],
              materialMap['supplier'],
              materialMap['notes'],
              materialMap['created_at'],
              materialMap['updated_at'],
            ]);
            print('成功将材料(id=$materialId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          print('同步材料到MySQL时出错: $e');
        }
      } catch (e) {
        print('材料同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除材料（非阻塞操作）
  Future<void> _trySyncDeleteMaterialToMySQL(int materialId) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过材料删除同步(id=$materialId)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM materials WHERE id = ?',
            [materialId],
          );
          print('成功从MySQL删除材料(id=$materialId)，影响行数: ${result.affectedRows}');
        } catch (e) {
          print('从MySQL删除材料(id=$materialId)时出错: $e');
        }
      } catch (e) {
        print('材料删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }
}
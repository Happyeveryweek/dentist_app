import 'package:flutter/foundation.dart';
import 'package:dentist_app/models/purchase_item.dart';
import 'package:dentist_app/models/purchase_record.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/utils/database_operation_wrapper.dart';
import 'package:dentist_app/data_sources/purchase_data_source.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
  
  // 数据列表
  List<PurchaseRecord> _purchaseRecords = [];
  List<PurchaseItem> _purchaseItems = [];
  
  // 缓存机制
  List<PurchaseRecord>? _cachedRecords;
  Map<String, dynamic>? _cachedStatistics;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20); // 采购数据缓存20分钟
  
  // 刷新标志
  bool _purchasesNeedRefresh = false;
  
  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;
  
  // Getters
  bool get initialized => _database != null || _currentMysqlConnection != null;
  bool get purchasesNeedRefresh => _purchasesNeedRefresh;
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  String? get lastError => _lastError;
  
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
    _mysqlDataSource = MySqlPurchaseDataSource.withConnectionGetter(() => _currentMysqlConnection);
  }

  // 设置用户提供者（用于权限控制）
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  PurchaseDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL采购数据源未初始化');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite采购数据源未初始化');
      }
      return _sqliteDataSource!;
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
      print('获取最新MySQL连接失败: $e');
    }
    
    return _mysqlConnection;
  }

  // 测试MySQL连接是否有效
  Future<bool> _testMySqlConnection() async {
    if (_currentMysqlConnection == null) return false;
    
    try {
      // 执行一个简单的查询来测试连接
      await _currentMysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      _isConnected = true;
      _clearError();
      return true;
    } catch (e) {
      print('MySQL连接测试失败: $e');
      // 如果连接失败，标记连接为无效
      _mysqlConnection = null;
      _setError('MySQL连接测试失败: $e');
      return false;
    }
  }

  // 获取当前数据源类型
  String get dataSourceType => _dataSourceType;
  
  // 缓存相关方法
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;
  
  // 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedRecords != null && 
           _lastCacheTime != null &&
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  // 更新缓存
  void _updateCache(List<PurchaseRecord> records, Map<String, dynamic> statistics) {
    _cachedRecords = List.from(records);
    _cachedStatistics = Map.from(statistics);
    _lastCacheTime = DateTime.now();
    print('采购数据缓存已更新: ${records.length} 条记录');
  }
  
  // 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _cachedStatistics = null;
    _lastCacheTime = null;
    _purchasesNeedRefresh = true; // 标记需要刷新
    print('采购数据缓存已清除，标记需要刷新');
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }



  // 从DatabaseProvider获取数据库连接（保持向后兼容）
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag) return;
    
    try {
      print('PurchaseProvider开始初始化...');
      
      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;
      
      // 兼容处理，支持DatabaseProvider的不同接口
      String dbType = 'sqlite';
      if (dbProvider.dbType != null) {
        dbType = dbProvider.dbType;
      } else if (dbProvider.dataSourceType != null) {
        dbType = dbProvider.dataSourceType;
      }
      
      if (dbType == 'mysql') {
        final mysqlConnection = dbProvider.mysqlConnection;
        if (mysqlConnection != null) {
          _mysqlConnection = mysqlConnection;
          _dataSourceType = 'mysql';
          
          // 创建MySQL数据源
          setMySqlDataSource(mysqlConnection);
          
          _isInitializedFlag = true;
          print('✅ PurchaseProvider MySQL数据源设置成功');
        } else {
          print('警告：MySQL连接为null，尝试SQLite');
          final database = await dbProvider.sqliteDatabase;
          if (database != null) {
            _database = database;
            _dataSourceType = 'sqlite';
            
            // 创建SQLite数据源
            setSqliteDataSource(database);
            
            _isInitializedFlag = true;
            print('PurchaseProvider 回退到SQLite数据源设置成功');
          } else {
            print('警告：SQLite数据库实例为null，延迟初始化...');
            // 延迟重试
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isInitializedFlag) {
                initializeFromDatabase(dbProvider);
              }
            });
            return;
          }
        }
      } else {
        // 异步获取SQLite数据库实例
        try {
          final database = await dbProvider.sqliteDatabase;
          if (database != null) {
            _database = database;
            _dataSourceType = 'sqlite';
            
            // 创建SQLite数据源
            setSqliteDataSource(database);
            
            _isInitializedFlag = true;
            print('✅ PurchaseProvider SQLite数据源设置成功');
          } else {
            print('警告：SQLite数据库实例为null，延迟初始化...');
            // 延迟重试
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!_isInitializedFlag) {
                initializeFromDatabase(dbProvider);
              }
            });
            return;
          }
        } catch (e) {
          print('获取SQLite数据库失败: $e');
          // 尝试通过其他方式获取
          if (dbProvider.database != null) {
            _database = dbProvider.database;
            _dataSourceType = 'sqlite';
            
            // 创建SQLite数据源
            setSqliteDataSource(dbProvider.database);
            
            _isInitializedFlag = true;
            print('通过备用方式获取SQLite数据库: ${_database != null ? "成功" : "失败"}');
          } else {
            print('警告：所有数据库获取方式都失败');
            return;
          }
        }
      }
      
      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);
      
      print('PurchaseProvider初始化完成');
    } catch (e) {
      print('PurchaseProvider初始化失败: $e');
      // 设置默认值，但不标记为已初始化
      _dataSourceType = 'sqlite';
      _isInitializedFlag = false;
    }
    
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 监听数据库状态变化
  void _onDatabaseStateChanged() {
    if (_dataSourceType == 'mysql') {
      // 由于我们无法直接获取DatabaseProvider实例，这里暂时跳过状态同步
      // 实际使用时，可以通过依赖注入或其他方式获取DatabaseProvider
      print('PurchaseProvider: 数据库状态变化通知');
    }
  }



  // 清除错误状态
  void _clearError() {
    _lastError = null;
    notifyListeners();
  }

  // 设置错误状态
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
    notifyListeners();
  }

  // 检查并确保连接可用
  Future<bool> _ensureConnection() async {
    if (_dataSourceType != 'mysql') return true;
    
    if (_currentMysqlConnection == null) return false;
    
    try {
      // 测试连接
      await _currentMysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      _isConnected = true;
      _clearError();
      return true;
    } catch (e) {
      print('PurchaseProvider: 连接检查失败: $e');
      _setError('数据库连接失败: $e');
      return false;
    }
  }

  // 自动重连
  Future<bool> _autoReconnect() async {
    if (_isReconnecting) return false;
    
    _isReconnecting = true;
    notifyListeners();
    
    try {
      print('PurchaseProvider: 尝试自动重连...');
      
      // 等待一段时间后重试
      await Future.delayed(const Duration(seconds: 3));
      
      // 重新检查连接
      final success = await _ensureConnection();
      
      if (success) {
        print('PurchaseProvider: 自动重连成功');
        _isReconnecting = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('重连失败');
      }
    } catch (e) {
      print('PurchaseProvider: 自动重连失败: $e');
      _isReconnecting = false;
      notifyListeners();
      return false;
    }
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

  // =================== 采购记录相关方法 ===================
  
  // 获取所有采购记录（带缓存）
  Future<List<PurchaseRecord>> getAllPurchaseRecords() async {
    if (!initialized) {
      return _cachedRecords ?? []; // 优雅降级而不是抛出异常
    }
    
    if (_dbWrapper == null) return _cachedRecords ?? [];
    
    return await _dbWrapper!.wrapOperation('getAllPurchaseRecords', () async {
      try {
        // 优先检查缓存（像财务管理一样）
        if (_isCacheValid()) {
          print('使用缓存的采购记录数据: ${_cachedRecords!.length} 条');
          return _cachedRecords!;
        }
        
        print('🔄 从数据库获取最新采购记录...');
        List<PurchaseRecord> records = [];

        // 检查是否需要权限过滤
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          // 使用数据源模式（带权限过滤）
          records = await _currentDataSource.getAllPurchases(doctorFilter: doctorFilter);
          print('✅ 权限过滤查询成功，获取到 ${records.length} 条采购记录（医生：$doctorFilter）');
        } else {
          // 使用数据源模式（统一接口）
          records = await _currentDataSource.getAllPurchases();
          print('✅ 数据源模式查询成功，获取到 ${records.length} 条采购记录');
        }

        // 以下传统模式代码已移除，现在统一使用数据源模式
        /*
        if (_dataSourceType == 'sqlite') {
        // 传统模式代码已移除，现在统一使用数据源模式
        */

        // 更新缓存
        _updateCache(records, {});
        print('✅ 采购记录缓存已更新');
        return records;
      } catch (e) {
        print('❌ 获取采购记录失败: $e');
        
        // 优雅降级：如果有缓存就返回缓存，否则返回空列表（像财务管理一样）
        if (_isCacheValid()) {
          print('使用缓存的采购记录数据，查询失败: $e');
          return _cachedRecords!;
        }
        
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 智能获取采购记录（优先使用缓存）
  Future<List<PurchaseRecord>> getPurchaseRecordsWithCache() async {
    // 如果缓存有效且连接正常，直接返回缓存
    if (_isCacheValid() && _isConnected && !_purchasesNeedRefresh) {
      print('使用缓存的采购记录数据: ${_cachedRecords!.length} 条');
      return _cachedRecords!;
    }
    
    try {
      print('🔄 缓存无效或需要刷新，从数据库获取最新数据...');
      // 尝试从数据库获取最新数据
      final records = await getAllPurchaseRecords();
      
      // 更新缓存并清除刷新标志
      _updateCache(records, {});
      _purchasesNeedRefresh = false;
      
      return records;
    } catch (e) {
      print('❌ 获取最新数据失败: $e');
      // 如果获取失败但有缓存，返回缓存数据
      if (_cachedRecords != null) {
        print('使用缓存的采购记录数据，连接异常: $e');
        return _cachedRecords!;
      }
      rethrow;
    }
  }

  // 根据ID获取采购记录
  Future<PurchaseRecord?> getPurchaseRecordById(int id) async {
    if (!initialized) {
      return null;
    }

    try {
      PurchaseRecord? record;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return null;
        
        final result = await db.rawQuery(
          'SELECT * FROM purchase_records WHERE id = ?',
          [id]
        );
        if (result.isNotEmpty) {
          record = PurchaseRecord.fromMap(result.first, dataSource: 'sqlite');
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) return null;
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          return null;
        }
        
        final results = await conn.query(
          'SELECT * FROM purchase_records WHERE id = ?',
          [id]
        );
        
        if (results.isNotEmpty) {
          final row = results.first;
          final map = <String, dynamic>{};
          for (var field in row.fields.keys) {
            var value = row[field];
            if (value is Blob) {
              // 备注字段不进行转码，直接取值
              if (field == 'notes') {
                map[field] = value.toString();
              } else {
                map[field] = String.fromCharCodes(value.toBytes());
              }
            } else {
              map[field] = value;
            }
          }
          record = PurchaseRecord.fromMap(map, dataSource: 'mysql');
        }
      }

      return record;
    } catch (e) {
      print('获取采购记录失败: $e');
      return null;
    }
  }

  // 添加采购记录
  Future<int> addPurchaseRecord(PurchaseRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return -1;
    
    return await _dbWrapper!.wrapOperation('addPurchaseRecord', () async {
      try {
        int id = 0;

        // 优先使用数据源模式（推荐）
        if (_currentDataSource != null) {
          id = await _currentDataSource!.createPurchase(record);
          print('✅ 数据源模式添加成功，ID: $id');
        } else if (_dataSourceType == 'sqlite') {
          final db = _database;
          if (db == null) throw Exception('SQLite数据库未初始化');
          
          id = await db.insert('purchase_records', record.toMap());
        } else if (_dataSourceType == 'mysql') {
          final conn = _currentMysqlConnection;
          if (conn == null) throw Exception('MySQL连接未初始化');
          
          // 测试连接是否有效
          final isConnected = await _testMySqlConnection();
          if (!isConnected) {
            throw Exception('MySQL连接已断开，请重新连接数据库');
          }
          
          final results = await conn.query(
            '''INSERT INTO purchase_records 
               (purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              record.purchaseDate.toIso8601String(),
              record.totalQuantity,
              record.totalAmount,
              record.supplier,
              record.notes,
              record.doctor,
              record.createdAt.toIso8601String(),
              record.updatedAt.toIso8601String(),
            ]
          );
          id = results.insertId ?? 0;
        }

        if (id > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markPurchasesNeedRefresh();
          print('✅ 采购记录添加成功，已清除缓存并标记刷新');
        }

        return id;
      } catch (e) {
        print('添加采购记录失败: $e');
        rethrow;
      }
    });
  }

  // 更新采购记录
  Future<int> updatePurchaseRecord(PurchaseRecord record) async {
    if (!initialized || record.id == null) {
      throw Exception('数据库未初始化或记录ID为空');
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('updatePurchaseRecord', () async {
      try {
        int count = 0;

        // 优先使用数据源模式（推荐）
        if (_currentDataSource != null) {
          final success = await _currentDataSource!.updatePurchase(record);
          count = success ? 1 : 0;
          print('✅ 数据源模式更新${success ? "成功" : "失败"}');
        } else if (_dataSourceType == 'sqlite') {
          final db = _database;
          if (db == null) throw Exception('SQLite数据库未初始化');
          
          count = await db.update(
            'purchase_records',
            {
              'purchase_date': record.purchaseDate.toIso8601String(),
              'total_quantity': record.totalQuantity,
              'total_amount': record.totalAmount,
              'supplier': record.supplier,
              'notes': record.notes,
              'doctor': record.doctor,
            },
            where: 'id = ?',
            whereArgs: [record.id],
          );
        } else if (_dataSourceType == 'mysql') {
          final conn = _currentMysqlConnection;
          if (conn == null) throw Exception('MySQL连接未初始化');
          
          // 测试连接是否有效
          final isConnected = await _testMySqlConnection();
          if (!isConnected) {
            throw Exception('MySQL连接已断开，请重新连接数据库');
          }
          
          final results = await conn.query(
            '''UPDATE purchase_records SET 
               purchase_date = ?, total_quantity = ?, total_amount = ?,
               supplier = ?, notes = ?, doctor = ? WHERE id = ?''',
            [
              record.purchaseDate.toIso8601String(),
              record.totalQuantity,
              record.totalAmount,
              record.supplier,
              record.notes,
              record.doctor,
              record.id,
            ]
          );
          count = results.affectedRows ?? 0;
        }

        if (count > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markPurchasesNeedRefresh();
          print('✅ 采购记录更新成功，已清除缓存并标记刷新');
        }

        return count;
      } catch (e) {
        print('更新采购记录失败: $e');
        rethrow;
      }
    });
  }

  // 删除采购记录
  Future<int> deletePurchaseRecord(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      int count = 0;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        // 先删除相关的采购项目
        await db.delete(
          'purchase_items',
          where: 'purchase_record_id = ?',
          whereArgs: [recordId],
        );
        
        // 再删除采购记录
        count = await db.delete(
          'purchase_records',
          where: 'id = ?',
          whereArgs: [recordId],
        );
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          throw Exception('MySQL连接已断开，请重新连接数据库');
        }
        
        // 先删除相关的采购项目
        await conn.query(
          'DELETE FROM purchase_items WHERE purchase_record_id = ?',
          [recordId]
        );
        
        // 再删除采购记录
        final results = await conn.query(
          'DELETE FROM purchase_records WHERE id = ?',
          [recordId]
        );
        count = results.affectedRows ?? 0;
      }

      if (count > 0) {
        // 清除缓存并标记需要刷新
        clearCache();
        markPurchasesNeedRefresh();
        print('✅ 采购记录删除成功，已清除缓存并标记刷新');
      }

      return count;
    } catch (e) {
      print('删除采购记录失败: $e');
      rethrow;
    }
  }

  // =================== 采购项目明细相关方法 ===================
  
  // 根据采购记录ID获取项目明细
  Future<List<PurchaseItem>> getPurchaseItemsByRecordId(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      List<PurchaseItem> items = [];

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        final result = await db.rawQuery(
          'SELECT * FROM purchase_items WHERE purchase_record_id = ? ORDER BY id',
          [recordId]
        );
        items = result.map((e) => PurchaseItem.fromMap(e, dataSource: 'sqlite')).toList();
        print('✅ SQLite查询成功，获取到 ${items.length} 个采购项目');
      } else if (_dataSourceType == 'mysql') {
        // ✅ 增强MySQL连接检查
        MySqlConnection? conn = _currentMysqlConnection;
        
        if (conn == null) {
          print('❌ MySQL连接无效或已断开');
          throw Exception('MySQL连接已断开，请重新连接数据库');
        }
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          throw Exception('MySQL连接已断开，请重新连接数据库');
        }
        
        try {
          final results = await conn.query(
            'SELECT * FROM purchase_items WHERE purchase_record_id = ? ORDER BY id',
            [recordId]
          );
          
          for (var row in results) {
            final map = <String, dynamic>{};
            for (var field in row.fields.keys) {
              var value = row[field];
              if (value is Blob) {
                map[field] = String.fromCharCodes(value.toBytes());
              } else {
                map[field] = value;
              }
            }
            items.add(PurchaseItem.fromMap(map, dataSource: 'mysql'));
          }
          
          print('✅ MySQL查询成功，获取到 ${items.length} 个采购项目');
        } catch (e) {
          if (e.toString().contains('socket') || e.toString().contains('closed')) {
            print('❌ MySQL连接异常: $e');
            // 标记连接无效
            _mysqlConnection = null;
            throw Exception('数据库连接异常，请检查网络连接或重新连接数据库');
          } else {
            rethrow;
          }
        }
      }

      return items;
    } catch (e) {
      print('获取采购项目明细失败: $e');
      rethrow;
    }
  }

  // 添加采购项目明细
  Future<int> addPurchaseItem(PurchaseItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      int id = 0;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        id = await db.insert('purchase_items', item.toMap());
        print('✅ SQLite采购项目添加成功，ID: $id');
      } else if (_dataSourceType == 'mysql') {
        // ✅ 增强MySQL连接检查和重连机制
        MySqlConnection? conn = _mysqlConnection;
        
        // 检查连接是否有效
        if (conn == null) {
          print('MySQL连接无效或已断开，尝试重新连接...');
          throw Exception('MySQL连接已断开，请重新连接数据库');
        }
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          throw Exception('MySQL连接已断开，请重新连接数据库');
        }
        
        try {
          final results = await conn.query(
            '''INSERT INTO purchase_items 
               (purchase_record_id, material_id, material_name, quantity, unit_price, total_price, unit, created_at, updated_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              item.purchaseRecordId,
              item.materialId,
              item.materialName,
              item.quantity,
              item.unitPrice,
              item.totalPrice,
              item.unit,
              item.createdAt.toIso8601String(),
              item.updatedAt.toIso8601String(),
            ]
          );
          id = results.insertId ?? 0;
          
          print('✅ 采购项目添加成功，ID: $id');
        } catch (e) {
          if (e.toString().contains('socket') || e.toString().contains('closed')) {
            print('❌ MySQL连接异常: $e');
            // 标记连接无效
            _mysqlConnection = null;
            throw Exception('数据库连接异常，请检查网络连接或重新连接数据库');
          } else {
            rethrow;
          }
        }
      }

      if (id > 0) {
        markPurchasesNeedRefresh();
        print('✅ 采购项目添加成功，已标记需要刷新');
      } else {
        print('❌ 采购项目添加失败，返回ID: $id');
      }

      return id;
    } catch (e) {
      print('❌ 添加采购项目明细失败: $e');
      rethrow;
    }
  }

  // 更新采购项目明细
  Future<int> updatePurchaseItem(PurchaseItem item) async {
    if (!initialized || item.id == null) {
      throw Exception('数据库未初始化或项目ID为空');
    }

    try {
      int count = 0;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        count = await db.update(
          'purchase_items',
          item.toMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          throw Exception('MySQL连接已断开，请重新连接数据库');
        }
        
        final results = await conn.query(
          '''UPDATE purchase_items SET 
             purchase_record_id = ?, material_id = ?, material_name = ?, quantity = ?,
             unit_price = ?, total_price = ?, unit = ?, updated_at = ? WHERE id = ?''',
          [
            item.purchaseRecordId,
            item.materialId,
            item.materialName,
            item.quantity,
            item.unitPrice,
            item.totalPrice,
            item.unit,
            item.updatedAt.toIso8601String(),
            item.id,
          ]
        );
        count = results.affectedRows ?? 0;
      }

      if (count > 0) {
        markPurchasesNeedRefresh();
      }

      return count;
    } catch (e) {
      print('更新采购项目明细失败: $e');
      rethrow;
    }
  }

  // 删除采购项目明细
  Future<int> deletePurchaseItem(int itemId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      int count = 0;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        count = await db.delete(
          'purchase_items',
          where: 'id = ?',
          whereArgs: [itemId],
        );
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          throw Exception('MySQL连接已断开，请重新连接数据库');
        }
        
        final results = await conn.query(
          'DELETE FROM purchase_items WHERE id = ?',
          [itemId]
        );
        count = results.affectedRows ?? 0;
      }

      if (count > 0) {
        markPurchasesNeedRefresh();
      }

      return count;
    } catch (e) {
      print('删除采购项目明细失败: $e');
      rethrow;
    }
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

    try {
      Map<String, dynamic> stats = {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalQuantity': 0,
        'supplierCount': 0,
      };

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return stats;
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        String query = '''
          SELECT 
            COUNT(*) as total_records,
            SUM(total_amount) as total_amount,
            SUM(total_quantity) as total_quantity,
            COUNT(DISTINCT supplier) as supplier_count
          FROM purchase_records
        ''';
        List<dynamic> queryArgs = [];
        
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          query += ' WHERE doctor = ?';
          queryArgs.add(doctorFilter);
        }
        
        final result = await db.rawQuery(query, queryArgs);
        
        if (result.isNotEmpty) {
          stats['totalRecords'] = int.tryParse(result.first['total_records'].toString()) ?? 0;
          stats['totalAmount'] = (result.first['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalQuantity'] = int.tryParse(result.first['total_quantity'].toString()) ?? 0;
          stats['supplierCount'] = result.first['supplier_count'] ?? 0;
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) return stats;
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          return stats;
        }
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        String query = '''
          SELECT 
            COUNT(*) as total_records,
            SUM(total_amount) as total_amount,
            SUM(total_quantity) as total_quantity,
            COUNT(DISTINCT supplier) as supplier_count
          FROM purchase_records
        ''';
        List<dynamic> queryArgs = [];
        
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          query += ' WHERE doctor = ?';
          queryArgs.add(doctorFilter);
        }
        
        final results = await conn.query(query, queryArgs);
        
        if (results.isNotEmpty) {
          final row = results.first;
          stats['totalRecords'] = int.tryParse(row['total_records'].toString()) ?? 0;
          stats['totalAmount'] = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalQuantity'] = int.tryParse(row['total_quantity'].toString()) ?? 0;
          stats['supplierCount'] = int.tryParse(row['supplier_count'].toString()) ?? 0;
        }
      }

      return stats;
    } catch (e) {
      print('获取采购统计信息失败: $e');
      return {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalQuantity': 0,
        'supplierCount': 0,
      };
    }
  }

  // 根据日期范围获取采购统计
  Future<Map<String, dynamic>> getPurchaseStatisticsByDateRange(DateTime startDate, DateTime endDate) async {
    if (!initialized) {
      return {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalQuantity': 0,
      };
    }

    try {
      Map<String, dynamic> stats = {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalQuantity': 0,
      };

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return stats;
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        String query = '''
          SELECT 
            COUNT(*) as total_records,
            SUM(total_amount) as total_amount,
            SUM(total_quantity) as total_quantity
          FROM purchase_records 
          WHERE purchase_date BETWEEN ? AND ?
        ''';
        List<dynamic> queryArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
        
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          query += ' AND doctor = ?';
          queryArgs.add(doctorFilter);
        }
        
        final result = await db.rawQuery(query, queryArgs);
        
        if (result.isNotEmpty) {
          stats['totalRecords'] = result.first['total_records'] ?? 0;
          stats['totalAmount'] = (result.first['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalQuantity'] = result.first['total_quantity'] ?? 0;
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) return stats;
        
        // 测试连接是否有效
        final isConnected = await _testMySqlConnection();
        if (!isConnected) {
          return stats;
        }
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        String query = '''
          SELECT 
            COUNT(*) as total_records,
            SUM(total_amount) as total_amount,
            SUM(total_quantity) as total_quantity
          FROM purchase_records 
          WHERE purchase_date BETWEEN ? AND ?
        ''';
        List<dynamic> queryArgs = [startDate.toIso8601String(), endDate.toIso8601String()];
        
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          query += ' AND doctor = ?';
          queryArgs.add(doctorFilter);
        }
        
        final results = await conn.query(query, queryArgs);
        
        if (results.isNotEmpty) {
          final row = results.first;
          stats['totalRecords'] = int.tryParse(row['total_records'].toString()) ?? 0;
          stats['totalAmount'] = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalQuantity'] = int.tryParse(row['total_quantity'].toString()) ?? 0;
        }
      }

      return stats;
    } catch (e) {
      print('获取日期范围采购统计失败: $e');
      return {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalQuantity': 0,
      };
    }
  }

  // =================== 权限控制相关方法 ===================
  
  /// 获取医生过滤条件（用于数据访问权限控制）
  String? _getDoctorFilter() {
    if (_userProvider == null || _userProvider!.currentUser == null) {
      return null;
    }
    
    return _userProvider!.buildDoctorFilter(_userProvider!.currentUser);
  }

  /// 采购管理需要数据过滤 - 普通用户只能查看自己医生的数据
  bool _shouldFilterByDoctor() {
    if (_userProvider == null || _userProvider!.currentUser == null) {
      return false;
    }
    
    final currentUser = _userProvider!.currentUser!;
    
    // 管理员不需要数据过滤
    if (currentUser.role == 'admin') {
      return false;
    }
    
    // 采购管理：有医生字段的用户需要数据过滤
    return currentUser.doctor != null && currentUser.doctor!.isNotEmpty;
  }
}
import 'package:flutter/foundation.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:dentist_app/models/financial_record.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/utils/database_operation_wrapper.dart';
import 'package:dentist_app/data_sources/financial_data_source.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class FinancialProvider extends ChangeNotifier {
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
  SqliteFinancialDataSource? _sqliteDataSource;
  MySqlFinancialDataSource? _mysqlDataSource;
  
  // 初始化标志
  bool _isInitializedFlag = false;
  
  // 数据列表
  List<FinancialRecord> _financialRecords = [];
  List<FinancialItem> _financialItems = [];
  
  // 缓存机制
  List<FinancialRecord>? _cachedRecords;
  Map<int, List<FinancialItem>>? _cachedItemsMap;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 30); // 缓存30分钟有效
  
  // 刷新标志
  bool _financialsNeedRefresh = false;
  
  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;
  
  // Getters
  bool get initialized => _database != null || _currentMysqlConnection != null;
  bool get financialsNeedRefresh => _financialsNeedRefresh;
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
    _sqliteDataSource = SqliteFinancialDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlFinancialDataSource.withConnectionGetter(() => _currentMysqlConnection);
  }

  // 设置用户提供者（用于权限控制）
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  FinancialDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL财务数据源未初始化');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite财务数据源未初始化');
      }
      return _sqliteDataSource!;
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
  void _updateCache(List<FinancialRecord> records, Map<int, List<FinancialItem>> itemsMap) {
    _cachedRecords = List.from(records);
    _cachedItemsMap = Map.from(itemsMap);
    _lastCacheTime = DateTime.now();
    print('财务数据缓存已更新: ${records.length} 条记录, ${itemsMap.length} 个明细项');
  }
  
  // 更新缓存（供外部调用，用于后台加载过程中实时更新）
  void updateCacheManually(List<FinancialRecord> records, Map<int, List<FinancialItem>> itemsMap) {
    _cachedRecords = List.from(records);
    _cachedItemsMap = Map.from(itemsMap);
    _lastCacheTime = DateTime.now();
    // 不打印重复日志，因为_updateCache已经打印过了
  }
  
  // 检查是否有缓存
  bool get hasCache => _cachedRecords != null && _cachedRecords!.isNotEmpty;
  
  // 获取缓存的记录
  List<FinancialRecord> get cachedRecords => _cachedRecords ?? [];
  
  // 获取缓存的明细项映射
  Map<int, List<FinancialItem>> get cachedItemsMap => _cachedItemsMap ?? {};
  
  // 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _cachedItemsMap = null;
    _lastCacheTime = null;
    _financialsNeedRefresh = true; // 标记需要刷新
    print('财务数据缓存已清除，标记需要刷新');
    notifyListeners();
  }

  // 检查并清理无效的财务记录（patient_id为0或null）
  Future<Map<String, int>> checkAndCleanInvalidRecords() async {
    Map<String, int> result = {
      'total': 0,
      'invalid': 0,
      'cleaned': 0,
    };

    try {
      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        // 获取总记录数
        final totalCount = await db.rawQuery('SELECT COUNT(*) as count FROM financial_records');
        result['total'] = totalCount.first['count'] as int;
        
        // 获取无效记录数
        final invalidCount = await db.rawQuery('SELECT COUNT(*) as count FROM financial_records WHERE patient_id IS NULL OR patient_id = 0');
        result['invalid'] = invalidCount.first['count'] as int;
        
        if (result['invalid']! > 0) {
          // 删除无效记录
          final deleted = await db.delete(
            'financial_records',
            where: 'patient_id IS NULL OR patient_id = 0',
          );
          result['cleaned'] = deleted;
          print('✅ SQLite清理完成，删除 $deleted 条无效财务记录');
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        
        try {
          // 获取总记录数
          final totalResults = await conn.query('SELECT COUNT(*) as count FROM financial_records');
          result['total'] = int.tryParse(totalResults.first['count'].toString()) ?? 0;
          
          // 获取无效记录数
          final invalidResults = await conn.query('SELECT COUNT(*) as count FROM financial_records WHERE patient_id IS NULL OR patient_id = 0');
          result['invalid'] = int.tryParse(invalidResults.first['count'].toString()) ?? 0;
          
          if (result['invalid']! > 0) {
            // 删除无效记录
            final deletedResults = await conn.query('DELETE FROM financial_records WHERE patient_id IS NULL OR patient_id = 0');
            result['cleaned'] = deletedResults.affectedRows ?? 0;
            print('✅ MySQL清理完成，删除 ${result["cleaned"]} 条无效财务记录');
          }
        } catch (e) {
          if (e.toString().contains('SocketException') || 
              e.toString().contains('Cannot write to socket') ||
              e.toString().contains('Connection reset')) {
            await _autoReconnect();
            return await checkAndCleanInvalidRecords();
          }
          rethrow;
        }
      }
      
      // 清理缓存
      clearCache();
      
    } catch (e) {
      print('❌ 清理无效财务记录时出错: $e');
      rethrow;
    }
    
    return result;
  }

  // 获取无效财务记录的详细信息
  Future<List<Map<String, dynamic>>> getInvalidRecordsInfo() async {
    List<Map<String, dynamic>> invalidRecords = [];

    try {
      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        invalidRecords = await db.rawQuery('''
          SELECT fr.*, 'SQLite' as source, COALESCE(p.name, '未知患者') as patient_name 
          FROM financial_records fr 
          LEFT JOIN patients p ON fr.patient_id = p.id 
          WHERE fr.patient_id IS NULL OR fr.patient_id = 0
          ORDER BY fr.created_at DESC
        ''');
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        
        try {
          final results = await conn.query('''
            SELECT fr.*, 'MySQL' as source, COALESCE(p.name, '未知患者') as patient_name 
            FROM financial_records fr 
            LEFT JOIN patients p ON fr.patient_id = p.id 
            WHERE fr.patient_id IS NULL OR fr.patient_id = 0
            ORDER BY fr.created_at DESC
          ''');
          
          invalidRecords = results.map((row) => {
            'id': int.tryParse(row['id'].toString()) ?? 0,
            'patient_id': int.tryParse(row['patient_id'].toString()) ?? 0,
            'patient_name': _convertBlobToString(row['patient_name']),
            'total_quantity': int.tryParse(row['total_quantity'].toString()) ?? 0,
            'notes': row['notes']?.toString(),
            'created_at': _convertBlobToString(row['created_at']) ?? DateTimeFormatter.nowDbString(),
            'updated_at': _convertBlobToString(row['updated_at']) ?? DateTimeFormatter.nowDbString(),
            'source': 'MySQL',
          }).toList();
        } catch (e) {
          if (e.toString().contains('SocketException') || 
              e.toString().contains('Cannot write to socket') ||
              e.toString().contains('Connection reset')) {
            await _autoReconnect();
            return await getInvalidRecordsInfo();
          }
          rethrow;
        }
      }
    } catch (e) {
      print('❌ 获取无效财务记录信息时出错: $e');
    }
    
    return invalidRecords;
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

  // 从DatabaseProvider获取数据库连接
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag) return;
    
    print('FinancialProvider开始初始化...');
    
    try {
      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;
      
      // 兼容处理，支持DatabaseProvider的不同接口
      String dbType = 'sqlite';
      if (dbProvider.dbType != null) {
        dbType = dbProvider.dbType;
      } else if (dbProvider.dataSourceType != null) {
        dbType = dbProvider.dataSourceType;
      }
      
      print('检测到数据源类型: $dbType');
      
      if (dbType == 'mysql') {
        print('使用MySQL连接...');
        _mysqlConnection = dbProvider.mysqlConnection;
        _dataSourceType = 'mysql';
        
        // 创建MySQL数据源
        if (_mysqlConnection != null) {
          setMySqlDataSource(_mysqlConnection!);
          print('✅ MySQL财务数据源创建成功');
        } else {
          throw Exception('MySQL连接为null，无法创建数据源');
        }
      } else {
        print('使用SQLite连接...');
        // 获取 SQLite 数据库实例
        try {
          _database = await dbProvider.sqliteDatabase;
          print('获取到的SQLite数据库实例: $_database');
        } catch (e) {
          print('获取SQLite数据库失败: $e');
          // 尝试通过其他方式获取
          if (dbProvider.database != null) {
            _database = dbProvider.database;
            print('通过备用方式获取SQLite数据库: $_database');
          }
        }
        _dataSourceType = 'sqlite';
        
        // 创建SQLite数据源
        if (_database != null) {
          setSqliteDataSource(_database!);
          print('✅ SQLite财务数据源创建成功');
        } else {
          throw Exception('SQLite数据库为null，无法创建数据源');
        }
      }
      
      // 初始化数据库操作包装器
      _dbWrapper = DatabaseOperationWrapper(dbProvider);
      
      _isInitializedFlag = true;
      print('FinancialProvider初始化完成: _isInitializedFlag = $_isInitializedFlag, _dataSourceType = $_dataSourceType');
      // 延迟通知以避免在build阶段调用setState
      Future.microtask(() => notifyListeners());
    } catch (e) {
      print('FinancialProvider初始化失败: $e');
      // 设置默认值
      _dataSourceType = 'sqlite';
      _isInitializedFlag = true; // 标记为已初始化，避免重复尝试
      // 延迟通知以避免在build阶段调用setState
      Future.microtask(() => notifyListeners());
    }
  }

  // 监听数据库状态变化
  void _onDatabaseStateChanged() {
    if (_dataSourceType == 'mysql') {
      // 由于我们无法直接获取DatabaseProvider实例，这里暂时跳过状态同步
      // 实际使用时，可以通过依赖注入或其他方式获取DatabaseProvider
      print('FinancialProvider: 数据库状态变化通知');
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
      print('FinancialProvider: 连接检查失败: $e');
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
      print('FinancialProvider: 尝试自动重连...');
      
      // 等待一段时间后重试
      await Future.delayed(const Duration(seconds: 3));
      
      // 重新检查连接
      final success = await _ensureConnection();
      
      if (success) {
        print('FinancialProvider: 自动重连成功');
        _isReconnecting = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('重连失败');
      }
    } catch (e) {
      print('FinancialProvider: 自动重连失败: $e');
      _isReconnecting = false;
      notifyListeners();
      return false;
    }
  }
  
  // 确保财务记录表存在（内部方法，不需要包装）
  Future<void> ensureFinancialRecordsTableExists() async {
    if (!initialized) return;
    
    try {
        if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return;
        
        // 创建财务记录表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS financial_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            total_quantity INTEGER DEFAULT 0,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients(id)
          )
        ''');
        
        // 创建财务项目明细表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS financial_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            financial_record_id INTEGER NOT NULL,
            item_name TEXT NOT NULL,
            item_price REAL NOT NULL,
            processing_fee REAL DEFAULT 0.0,
            quantity INTEGER DEFAULT 1,
            total_price REAL NOT NULL,
            charge_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (financial_record_id) REFERENCES financial_records(id)
          )
        ''');
        
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) return;
        
        // 创建财务记录表
        await conn.query('''
          CREATE TABLE IF NOT EXISTS financial_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            patient_id INT NOT NULL,
            total_quantity INT DEFAULT 0,
            notes TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients(id)
          )
        ''');
        
        // 创建财务项目明细表
        await conn.query('''
          CREATE TABLE IF NOT EXISTS financial_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            financial_record_id INT NOT NULL,
            item_name VARCHAR(255) NOT NULL,
            item_price DECIMAL(10,2) NOT NULL,
            processing_fee DECIMAL(10,2) DEFAULT 0.0,
            quantity INT DEFAULT 1,
            total_price DECIMAL(10,2) NOT NULL,
            charge_date DATETIME NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            FOREIGN KEY (financial_record_id) REFERENCES financial_records(id)
          )
        ''');
        
      }
    } catch (e) {
      print('创建财务记录表失败: $e');
      throw e;
    }
  }
  
  // 构造函数
  FinancialProvider({
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
  void markFinancialsNeedRefresh() {
    _financialsNeedRefresh = true;
    notifyListeners();
  }
  
  // 清除刷新标志
  void clearFinancialsNeedRefresh() {
    _financialsNeedRefresh = false;
  }

  /// 转换 Blob 类型为 String
  String? _convertBlobToString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Blob) {
      try {
        return String.fromCharCodes(value.toBytes());
      } catch (e) {
        print('Blob转换错误: $e');
        return value.toString();
      }
    }
    return value.toString();
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
        print('🔄 从数据库获取最新财务记录...');
        
        // 优先检查缓存，避免不必要的数据库访问
        if (_isCacheValid()) {
          print('使用缓存的财务记录数据');
          return _cachedRecords!;
        }
        
        // 确保财务记录表存在
        await ensureFinancialRecordsTableExists();
        
        List<FinancialRecord> records = [];

        // 检查是否需要权限过滤
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          // 需要权限过滤，使用自定义查询
          records = await _getFilteredFinancialRecords(doctorFilter);
          print('✅ 权限过滤查询成功，获取到 ${records.length} 条财务记录（医生: $doctorFilter）');
        } else {
          // 使用数据源模式（统一接口）
          records = await _currentDataSource.getAllFinancialRecords();
          print('✅ 数据源模式查询成功，获取到 ${records.length} 条财务记录');
        }

        // 以下代码保留作为参考，但不再使用
        /*
        if (_dataSourceType == 'sqlite') {
        // 传统模式代码已移除，现在统一使用数据源模式
        */

        // 更新缓存
        _updateCache(records, {});
        print('✅ 财务记录缓存已更新');
        return records;
      } catch (e) {
        print('❌ 获取财务记录失败: $e');
        
        // 如果有缓存数据，返回缓存
        if (_isCacheValid()) {
          print('使用缓存的财务记录数据，查询失败: $e');
          return _cachedRecords!;
        }
        
        rethrow;
      }
    });
  }

  // 智能获取财务记录（优先使用缓存）
  Future<List<FinancialRecord>> getFinancialRecordsWithCache() async {
    if (_dbWrapper == null) return _cachedRecords ?? [];
    
    return await _dbWrapper!.wrapOperation('getFinancialRecordsWithCache', () async {
      try {
        // 优先检查缓存（像患者管理一样）
        if (_isCacheValid()) {
          print('使用缓存的财务记录数据: ${_cachedRecords!.length} 条');
          return _cachedRecords!;
        }
        
        // 尝试从数据库获取最新数据
        final records = await getAllFinancialRecords();
        return records;
      } catch (e) {
        print('获取财务记录失败: $e');
        // 优雅降级：如果有缓存就返回缓存，否则返回空列表（像患者管理一样）
        if (_cachedRecords != null) {
          print('使用缓存的财务记录数据，连接异常: $e');
          return _cachedRecords!;
        }
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 获取财务记录总数
  Future<int> getFinancialRecordsCount() async {
    if (!initialized) {
      return 0;
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('getFinancialRecordsCount', () async {
      try {
        int count = 0;

        if (_dataSourceType == 'sqlite') {
          final db = _database;
          if (db == null) return 0;
          
          // 构建查询条件
          List<String> conditions = ['fr.patient_id IS NOT NULL'];
          List<dynamic> queryArgs = [];
          
          // 权限过滤：基于医生字段
          final doctorFilter = _getDoctorFilter();
          if (doctorFilter != null && _shouldFilterByDoctor()) {
            conditions.add('p.doctor = ?');
            queryArgs.add(doctorFilter);
          }
          
          final result = await db.rawQuery('''
            SELECT COUNT(*) as count 
            FROM financial_records fr 
            LEFT JOIN patients p ON fr.patient_id = p.id 
            WHERE ${conditions.join(' AND ')}
          ''', queryArgs);
          if (result.isNotEmpty) {
            count = result.first['count'] as int;
          }
        } else if (_dataSourceType == 'mysql') {
          final conn = _currentMysqlConnection;
          if (conn == null) return 0;
          
          // 构建查询条件
          List<String> conditions = ['fr.patient_id IS NOT NULL'];
          List<dynamic> queryArgs = [];
          
          // 权限过滤：基于医生字段
          final doctorFilter = _getDoctorFilter();
          if (doctorFilter != null && _shouldFilterByDoctor()) {
            conditions.add('p.doctor = ?');
            queryArgs.add(doctorFilter);
          }
          
          final results = await conn.query('''
            SELECT COUNT(*) as count 
            FROM financial_records fr 
            LEFT JOIN patients p ON fr.patient_id = p.id 
            WHERE ${conditions.join(' AND ')}
          ''', queryArgs);
          if (results.isNotEmpty) {
            count = results.first['count'] as int;
          }
        }

        return count;
      } catch (e) {
        print('获取财务记录总数失败: $e');
        return 0;
      }
    });
  }

  // 分页获取财务记录
  Future<List<FinancialRecord>> getPaginatedFinancialRecords(int page, int pageSize) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      print('🔄 从数据库分页获取财务记录，页码: $page, 每页大小: $pageSize');
      
      // 确保财务记录表存在
      await ensureFinancialRecordsTableExists();
      
      // 检查MySQL连接状态
      if (_dataSourceType == 'mysql') {
        final connectionOk = await _ensureConnection();
        if (!connectionOk) {
          // 尝试自动重连
          final reconnected = await _autoReconnect();
          if (!reconnected) {
            throw Exception('数据库连接失败，请检查网络连接');
          }
        }
      }
      
      List<FinancialRecord> records = [];
      final offset = (page - 1) * pageSize;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        // 构建查询条件
        List<String> conditions = ['fr.patient_id IS NOT NULL'];
        List<dynamic> queryArgs = [];
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }
        
        // 添加分页参数
        queryArgs.addAll([pageSize, offset]);
        
        // 分页查询，通过JOIN获取患者姓名
        final result = await db.rawQuery('''
          SELECT 
            fr.id as id,
            fr.patient_id as patient_id,
            fr.total_quantity as total_quantity,
            fr.notes as notes,
            fr.created_at as created_at,
            fr.updated_at as updated_at,
            COALESCE(p.name, '未知患者') as patient_name 
          FROM financial_records fr 
          LEFT JOIN patients p ON fr.patient_id = p.id 
          WHERE ${conditions.join(' AND ')}
          ORDER BY fr.updated_at DESC
          LIMIT ? OFFSET ?
        ''', queryArgs);
        
        records = result.map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite')).toList();
        print('✅ SQLite分页查询成功，获取到 ${records.length} 条记录');
        
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        
        try {
          // 构建查询条件
          List<String> conditions = ['fr.patient_id IS NOT NULL'];
          List<dynamic> queryArgs = [];
          
          // 权限过滤：基于医生字段
          final doctorFilter = _getDoctorFilter();
          if (doctorFilter != null && _shouldFilterByDoctor()) {
            conditions.add('p.doctor = ?');
            queryArgs.add(doctorFilter);
          }
          
          // 添加分页参数
          queryArgs.addAll([pageSize, offset]);
          
          // 分页查询，通过JOIN获取患者姓名
          final results = await conn.query('''
            SELECT fr.*, COALESCE(p.name, '未知患者') as patient_name 
            FROM financial_records fr 
            LEFT JOIN patients p ON fr.patient_id = p.id 
            WHERE ${conditions.join(' AND ')}
            ORDER BY fr.updated_at DESC
            LIMIT ? OFFSET ?
          ''', queryArgs);
          
          records = results.map((row) => FinancialRecord.fromMap({
            'id': int.tryParse(row['id'].toString()) ?? 0,
            'patient_id': int.tryParse(row['patient_id'].toString()) ?? 0,
            'total_quantity': int.tryParse(row['total_quantity'].toString()) ?? 0,
            'notes': row['notes']?.toString(),
            'created_at': _convertBlobToString(row['created_at']) ?? DateTimeFormatter.nowDbString(),
            'updated_at': _convertBlobToString(row['updated_at']) ?? DateTimeFormatter.nowDbString(),
            'patient_name': _convertBlobToString(row['patient_name']),
          }, dataSource: 'mysql')).toList();
          
          print('✅ MySQL分页查询成功，获取到 ${records.length} 条记录');
          
        } catch (e) {
          // 检查是否是连接错误
          if (e.toString().contains('SocketException') || 
              e.toString().contains('Cannot write to socket') ||
              e.toString().contains('Connection reset')) {
            print('检测到连接错误，尝试重连: $e');
            _setError('数据库连接已断开，正在尝试重连...');
            
            // 尝试重连
            final reconnected = await _autoReconnect();
            if (reconnected) {
              // 重连成功，重新执行查询
              return await getPaginatedFinancialRecords(page, pageSize);
            } else {
              throw Exception('数据库连接失败，请检查网络连接');
            }
          }
          rethrow;
        }
      }

      return records;
    } catch (e) {
      print('❌ 分页获取财务记录失败: $e');
      rethrow;
    }
  }

  // 根据患者ID获取财务记录
  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(int patientId) async {
    // 如果patientId为0或无效，直接返回空列表
    if (patientId == 0) {
      print('⚠️ 无效的patientId: $patientId，返回空列表');
      return [];
    }

    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 确保财务记录表存在
      await ensureFinancialRecordsTableExists();
      
      List<FinancialRecord> records = [];

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');
        
        // 通过JOIN查询获取患者姓名
        final result = await db.rawQuery('''
          SELECT fr.*, COALESCE(p.name, '未知患者') as patient_name 
          FROM financial_records fr 
          LEFT JOIN patients p ON fr.patient_id = p.id 
          WHERE fr.patient_id = ? 
          ORDER BY fr.updated_at DESC
        ''', [patientId]);
        records = result.map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite')).toList();
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');
        
        // 通过JOIN查询获取患者姓名
        final results = await conn.query('''
          SELECT fr.*, p.name as patient_name 
          FROM financial_records fr 
          LEFT JOIN patients p ON fr.patient_id = p.id 
          WHERE fr.patient_id = ? 
          ORDER BY fr.updated_at DESC
        ''', [patientId]);
        
        return results.map((row) => FinancialRecord.fromMap({
          'id': row['id'],
          'patient_id': row['patient_id'] ?? 0,
          'total_quantity': row['total_quantity'] ?? 0,
          'notes': row['notes']?.toString(), // 备注字段直接取值，不进行转码
          'created_at': _convertBlobToString(row['created_at']) ?? DateTimeFormatter.nowDbString(),
          'updated_at': _convertBlobToString(row['updated_at']) ?? DateTimeFormatter.nowDbString(),
          'patient_name': _convertBlobToString(row['patient_name']), // 添加患者姓名字段
        }, dataSource: 'mysql')).toList();
      }

      return records;
    } catch (e) {
      print('获取患者财务记录失败: $e');
      rethrow;
    }
  }

  // 添加财务记录
  Future<int> addFinancialRecord(FinancialRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return -1;
    
    return await _dbWrapper!.wrapOperation('addFinancialRecord', () async {
      try {
        // 确保财务记录表存在
        await ensureFinancialRecordsTableExists();
        
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createFinancialRecord(record);
        print('✅ 数据源模式添加成功，ID: $id');

        if (id > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markFinancialsNeedRefresh();
          print('✅ 财务记录添加成功，已清除缓存并标记刷新');
        }

        return id;
      } catch (e) {
        print('添加财务记录失败: $e');
        rethrow;
      }
    });
  }

  // 更新财务记录
  Future<int> updateFinancialRecord(FinancialRecord record) async {
    if (!initialized || record.id == null) {
      throw Exception('数据库未初始化或记录ID为空');
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('updateFinancialRecord', () async {
      try {
        // 确保财务记录表存在
        await ensureFinancialRecordsTableExists();
        
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updateFinancialRecord(record);
        final count = success ? 1 : 0;
        print('✅ 数据源模式更新${success ? "成功" : "失败"}');

        if (count > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markFinancialsNeedRefresh();
          print('✅ 财务记录更新成功，已清除缓存并标记刷新');
        }

        return count;
      } catch (e) {
        print('更新财务记录失败: $e');
        rethrow;
      }
    });
  }

  // 删除财务记录
  Future<int> deleteFinancialRecord(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('deleteFinancialRecord', () async {
      try {
        // 确保财务记录表存在
        await ensureFinancialRecordsTableExists();
        
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deleteFinancialRecord(recordId);
        final count = success ? 1 : 0;

        if (count > 0) {
          // 清除缓存并标记需要刷新
          clearCache();
          markFinancialsNeedRefresh();
          print('✅ 财务记录删除成功，已清除缓存并标记刷新');
        }

        return count;
      } catch (e) {
        print('删除财务记录失败: $e');
        rethrow;
      }
    });
  }

  // =================== 财务项目明细相关方法 ===================
  
  // 根据财务记录ID获取项目明细
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getFinancialItemsByRecordId', () async {
      try {
        // 确保财务记录表存在
        await ensureFinancialRecordsTableExists();
        
        // 使用数据源模式（统一接口）
        return await _currentDataSource.getFinancialItemsByRecordId(recordId);
      } catch (e) {
        print('获取财务项目明细失败: $e');
        rethrow;
      }
    });
  }

  // 添加财务项目明细
  Future<int> addFinancialItem(FinancialItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return -1;
    
    return await _dbWrapper!.wrapOperation('addFinancialItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createFinancialItem(item);

        if (id > 0) {
          markFinancialsNeedRefresh();
        }

        return id;
      } catch (e) {
        print('添加财务项目明细失败: $e');
        rethrow;
      }
    });
  }

  // 更新财务项目明细
  Future<int> updateFinancialItem(FinancialItem item) async {
    if (!initialized || item.id == null) {
      throw Exception('数据库未初始化或项目ID为空');
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('updateFinancialItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updateFinancialItem(item);
        final count = success ? 1 : 0;

        if (count > 0) {
          markFinancialsNeedRefresh();
        }

        return count;
      } catch (e) {
        print('更新财务项目明细失败: $e');
        rethrow;
      }
    });
  }

  // 删除财务项目明细
  Future<int> deleteFinancialItem(int itemId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }
    
    if (_dbWrapper == null) return 0;
    
    return await _dbWrapper!.wrapOperation('deleteFinancialItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deleteFinancialItem(itemId);
        final count = success ? 1 : 0;

        if (count > 0) {
          markFinancialsNeedRefresh();
        }

        return count;
      } catch (e) {
        print('删除财务项目明细失败: $e');
        rethrow;
      }
    });
  }

  // =================== 统计方法 ===================
  
  // 获取患者总消费额
  Future<double> getPatientTotalCost(int patientId) async {
    if (!initialized) {
      return 0.0;
    }

    try {
      double totalCost = 0.0;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return 0.0;
        
        // 构建查询条件
        List<String> conditions = ['fr.patient_id = ?'];
        List<dynamic> queryArgs = [patientId];
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }
        
        // 根据实际的数据库表结构，需要通过 financial_items 表计算总消费
        final result = await db.rawQuery('''
          SELECT SUM(fi.total_price) as total 
          FROM financial_records fr 
          JOIN financial_items fi ON fr.id = fi.financial_record_id 
          LEFT JOIN patients p ON fr.patient_id = p.id
          WHERE ${conditions.join(' AND ')}
        ''', queryArgs);
        if (result.isNotEmpty && result.first['total'] != null) {
          totalCost = (result.first['total'] as num).toDouble();
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) return 0.0;
        
        // 构建查询条件
        List<String> conditions = ['fr.patient_id = ?'];
        List<dynamic> queryArgs = [patientId];
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }
        
        // 根据实际的数据库表结构，需要通过 financial_items 表计算总消费
        final results = await conn.query('''
          SELECT SUM(fi.total_price) as total 
          FROM financial_records fr 
          JOIN financial_items fi ON fr.id = fi.financial_record_id 
          LEFT JOIN patients p ON fr.patient_id = p.id
          WHERE ${conditions.join(' AND ')}
        ''', queryArgs);
        if (results.isNotEmpty && results.first['total'] != null) {
          totalCost = (results.first['total'] as num).toDouble();
        }
      }

      return totalCost;
    } catch (e) {
      print('获取患者总消费额失败: $e');
      return 0.0;
    }
  }

  // 获取所有财务记录的统计信息
  Future<Map<String, dynamic>> getFinancialStatistics() async {
    if (!initialized) {
      return {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalPaid': 0.0,
        'totalOutstanding': 0.0,
      };
    }

    try {
      Map<String, dynamic> stats = {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalPaid': 0.0,
        'totalOutstanding': 0.0,
      };

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return stats;
        
        // 构建查询条件
        List<String> conditions = [];
        List<dynamic> queryArgs = [];
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }
        
        String whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
        
        // 根据实际的数据库表结构，需要通过 financial_items 表计算统计信息
        final result = await db.rawQuery('''
          SELECT 
            COUNT(DISTINCT fr.id) as total_records,
            SUM(fi.total_price) as total_amount,
            SUM(fi.total_price) as total_paid,
            0.0 as total_outstanding
          FROM financial_records fr 
          LEFT JOIN financial_items fi ON fr.id = fi.financial_record_id
          LEFT JOIN patients p ON fr.patient_id = p.id
          $whereClause
        ''', queryArgs);
        
        if (result.isNotEmpty) {
          stats['totalRecords'] = result.first['total_records'] ?? 0;
          stats['totalAmount'] = (result.first['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalPaid'] = (result.first['total_paid'] as num?)?.toDouble() ?? 0.0;
          stats['totalOutstanding'] = (result.first['total_outstanding'] as num?)?.toDouble() ?? 0.0;
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) return stats;
        
        // 构建查询条件
        List<String> conditions = [];
        List<dynamic> queryArgs = [];
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }
        
        String whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
        
        // 根据实际的数据库表结构，需要通过 financial_items 表计算统计信息
        final results = await conn.query('''
          SELECT 
            COUNT(DISTINCT fr.id) as total_records,
            SUM(fi.total_price) as total_amount,
            SUM(fi.total_price) as total_paid,
            0.0 as total_outstanding
          FROM financial_records fr 
          LEFT JOIN financial_items fi ON fr.id = fi.financial_record_id
          LEFT JOIN patients p ON fr.patient_id = p.id
          $whereClause
        ''', queryArgs);
        
        if (results.isNotEmpty) {
          final row = results.first;
          stats['totalRecords'] = row['total_records'] ?? 0;
          stats['totalAmount'] = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalPaid'] = (row['total_paid'] as num?)?.toDouble() ?? 0.0;
          stats['totalOutstanding'] = (row['total_outstanding'] as num?)?.toDouble() ?? 0.0;
        }
      }

      return stats;
    } catch (e) {
      print('获取财务统计信息失败: $e');
      return {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalPaid': 0.0,
        'totalOutstanding': 0.0,
      };
    }
  }

  // =================== 权限过滤相关方法 ===================
  
  /// 获取医生过滤条件（用于数据访问权限控制）
  String? _getDoctorFilter() {
    if (_userProvider == null || _userProvider!.currentUser == null) {
      return null;
    }
    
    return _userProvider!.buildDoctorFilter(_userProvider!.currentUser);
  }

  /// 财务管理需要数据过滤 - 普通用户只能查看自己医生的数据
  bool _shouldFilterByDoctor() {
    if (_userProvider == null || _userProvider!.currentUser == null) {
      return false;
    }
    
    final currentUser = _userProvider!.currentUser!;
    
    // 管理员不需要数据过滤
    if (currentUser.role == 'admin') {
      return false;
    }
    
    // 财务管理：有医生字段的用户需要数据过滤
    return currentUser.doctor != null && currentUser.doctor!.isNotEmpty;
  }

  /// 获取过滤后的财务记录（基于医生字段）
  Future<List<FinancialRecord>> _getFilteredFinancialRecords(String doctorFilter) async {
    List<FinancialRecord> records = [];
    
    if (_dataSourceType == 'sqlite') {
      final db = _database;
      if (db == null) throw Exception('SQLite数据库未初始化');
      
      final result = await db.rawQuery('''
        SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
               COALESCE(p.name, '未知患者') as patient_name,
               p.name_pinyin as patient_name_pinyin,
               p.name_initials as patient_name_initials
        FROM financial_records fr 
        LEFT JOIN patients p ON fr.patient_id = p.id 
        WHERE p.doctor = ?
        ORDER BY fr.created_at DESC
      ''', [doctorFilter]);
      
      records = result.map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite')).toList();
      
    } else if (_dataSourceType == 'mysql') {
      final conn = _currentMysqlConnection;
      if (conn == null) throw Exception('MySQL连接未初始化');
      
      final results = await conn.query('''
        SELECT fr.*, COALESCE(p.name, '未知患者') as patient_name,
               p.name_pinyin as patient_name_pinyin,
               p.name_initials as patient_name_initials
        FROM financial_records fr 
        LEFT JOIN patients p ON fr.patient_id = p.id 
        WHERE p.doctor = ?
        ORDER BY fr.created_at DESC
      ''', [doctorFilter]);
      
      records = results.map((row) => FinancialRecord.fromMap({
        'id': int.tryParse(row['id'].toString()) ?? 0,
        'patient_id': int.tryParse(row['patient_id'].toString()) ?? 0,
        'total_quantity': int.tryParse(row['total_quantity'].toString()) ?? 0,
        'notes': row['notes']?.toString(),
        'created_at': _convertBlobToString(row['created_at']) ?? DateTimeFormatter.nowDbString(),
        'updated_at': _convertBlobToString(row['updated_at']) ?? DateTimeFormatter.nowDbString(),
        'patient_name': _convertBlobToString(row['patient_name']),
        'patient_name_pinyin': _convertBlobToString(row['patient_name_pinyin']),
        'patient_name_initials': _convertBlobToString(row['patient_name_initials']),
      }, dataSource: 'mysql')).toList();
    }
    
    return records;
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
    print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 开始获取财务统计数据');
    
    if (!initialized) return [];
    
    if (_dbWrapper == null) return [];
    
    return await _dbWrapper!.wrapOperation('getAllFinancialItemsWithDetailsFiltered', () async {
      try {
        // 构建查询条件
        List<String> conditions = [];
        List<dynamic> whereArgs = [];
        
        // 权限过滤：基于医生字段
        final doctorFilter = _getDoctorFilter();
        if (doctorFilter != null && _shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          whereArgs.add(doctorFilter);
          print('✅ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 应用医生过滤: $doctorFilter');
        } else {
          print('⚠️ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 无权限过滤（管理员或未设置）');
        }
        
        // 日期范围过滤
        if (startDate != null) {
          conditions.add('fi.charge_date >= ?');
          whereArgs.add(DateTimeFormatter.toDbString(startDate));
        }
        if (endDate != null) {
          conditions.add('fi.charge_date <= ?');
          whereArgs.add(DateTimeFormatter.toDbString(endDate));
        }
        
        // 患者姓名过滤
        if (patientName != null && patientName.isNotEmpty) {
          conditions.add('p.name LIKE ?');
          whereArgs.add('%$patientName%');
        }
        
        // 项目名称过滤
        if (itemName != null && itemName.isNotEmpty) {
          conditions.add('fi.item_name LIKE ?');
          whereArgs.add('%$itemName%');
        }
        
        // 价格范围过滤
        if (priceMin != null) {
          conditions.add('fi.item_price >= ?');
          whereArgs.add(priceMin);
        }
        if (priceMax != null) {
          conditions.add('fi.item_price <= ?');
          whereArgs.add(priceMax);
        }
        
        // 加工费范围过滤
        if (processingMin != null) {
          conditions.add('fi.processing_fee >= ?');
          whereArgs.add(processingMin);
        }
        if (processingMax != null) {
          conditions.add('fi.processing_fee <= ?');
          whereArgs.add(processingMax);
        }
        
        // 构建WHERE子句
        String whereClause = conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
        
        // 构建ORDER BY子句
        String orderBy = 'fi.$sortBy $sortOrder';
        
        List<Map<String, dynamic>> results = [];
        
        if (_dataSourceType == 'sqlite') {
          final db = _database;
          if (db == null) throw Exception('SQLite数据库未初始化');
          
          final query = '''
            SELECT 
              fi.*,
              fr.patient_id,
              p.name as patient_name,
              p.doctor as patient_doctor
            FROM financial_items fi
            JOIN financial_records fr ON fi.financial_record_id = fr.id
            LEFT JOIN patients p ON fr.patient_id = p.id
            $whereClause
            ORDER BY $orderBy
          ''';
          
          print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - SQLite查询: $query');
          print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 参数: $whereArgs');
          
          final queryResults = await db.rawQuery(query, whereArgs);
          print('✅ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - SQLite查询成功，获取到 ${queryResults.length} 条记录');
          
          results = queryResults.map((row) => {
            'item': FinancialItem.fromMap({
              'id': row['id'],
              'financial_record_id': row['financial_record_id'],
              'item_name': row['item_name'],
              'item_price': row['item_price'],
              'processing_fee': row['processing_fee'],
              'quantity': row['quantity'],
              'total_price': row['total_price'],
              'charge_date': row['charge_date'],
              'created_at': row['created_at'],
              'updated_at': row['updated_at'],
            }),
            'patient_id': row['patient_id'],
            'patient_name': row['patient_name'],
            'patient_doctor': row['patient_doctor'],
          }).toList();
          
        } else if (_dataSourceType == 'mysql') {
          final conn = _currentMysqlConnection;
          if (conn == null) throw Exception('MySQL连接未初始化');
          
          final query = '''
            SELECT 
              fi.*,
              fr.patient_id,
              p.name as patient_name,
              p.doctor as patient_doctor
            FROM financial_items fi
            JOIN financial_records fr ON fi.financial_record_id = fr.id
            LEFT JOIN patients p ON fr.patient_id = p.id
            $whereClause
            ORDER BY $orderBy
          ''';
          
          print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - MySQL查询: $query');
          print('🔍 FinancialProvider.getAllFinancialItemsWithDetailsFiltered - 参数: $whereArgs');
          
          final queryResults = await conn.query(query, whereArgs);
          print('✅ FinancialProvider.getAllFinancialItemsWithDetailsFiltered - MySQL查询成功，获取到 ${queryResults.length} 条记录');
          
          results = queryResults.map((row) => {
            'item': FinancialItem.fromMap({
              'id': row['id'],
              'financial_record_id': row['financial_record_id'],
              'item_name': _convertBlobToString(row['item_name']) ?? '',
              'item_price': (row['item_price'] as num?)?.toDouble() ?? 0.0,
              'processing_fee': (row['processing_fee'] as num?)?.toDouble() ?? 0.0,
              'quantity': row['quantity'] ?? 1,
              'total_price': (row['total_price'] as num?)?.toDouble() ?? 0.0,
              'charge_date': _convertBlobToString(row['charge_date']) ?? DateTimeFormatter.nowDbString(),
              'created_at': _convertBlobToString(row['created_at']) ?? DateTimeFormatter.nowDbString(),
              'updated_at': _convertBlobToString(row['updated_at']) ?? DateTimeFormatter.nowDbString(),
            }),
            'patient_id': row['patient_id'],
            'patient_name': _convertBlobToString(row['patient_name']),
            'patient_doctor': _convertBlobToString(row['patient_doctor']),
          }).toList();
        }
        
        return results;
      } catch (e) {
        print('❌ 获取财务项目明细失败: $e');
        rethrow;
      }
    });
  }
}
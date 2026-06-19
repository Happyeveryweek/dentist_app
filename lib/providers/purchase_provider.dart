import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/database_provider.dart';
import '../utils/mysql_connection_helper.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import '../models/patient.dart';
import '../models/appointment.dart';
// 随访记录相关导入已移除
import '../models/user.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../models/material.dart' as material_models;
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../models/patient_material.dart';
import '../models/material_image.dart';
import '../utils/mysql_sync_connection_helper.dart';
import '../providers/settings_provider.dart';
import '../providers/user_provider.dart';
import '../utils/pinyin_util.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import '../data_sources/purchase_data_source.dart';
import '../utils/purchase_migration.dart';
import '../features/purchases/services/purchase_mysql_connection_service.dart';
import '../features/purchases/services/purchase_sync_service.dart';

/// 采购管理提供者
/// 负责处理所有与采购相关的数据库操作
class PurchaseProvider extends ChangeNotifier {
  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;

  // 数据源类型
  String _dataSourceType = 'sqlite';

  // 模块数据源配置
  Map<String, String>? _moduleDataSources;

  // 标志：是否使用了临时覆盖的模块数据源配置（降级时）
  bool _isUsingTemporaryModuleDataSources = false;

  // 当前用户信息
  User? _currentUser;

  // 刷新标志
  bool _purchasesNeedRefresh = false;

  // 缓存机制（类似安卓端）
  List<PurchaseRecord>? _cachedRecords;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration =
      Duration(minutes: 20); // 采购数据缓存20分钟

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 用户权限提供者引用
  UserProvider? _userProvider;

  // 数据源具体实现
  SqlitePurchaseDataSource? _sqliteDataSource;
  MySqlPurchaseDataSource? _mysqlDataSource;

  // 同步服务
  late final PurchaseMysqlConnectionService _mysqlConnectionService;
  late final PurchaseSyncService _syncService;

  // 连接状态
  bool _isConnected = true;
  String? _lastError;

  // Getters
  bool get initialized => _database != null || _mysqlConnection != null;
  String get dataSourceType => _effectiveDataSourceType;
  bool get purchasesNeedRefresh => _purchasesNeedRefresh;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  User? get currentUser => _currentUser;

  // 缓存相关getters
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;

  // 获取有效的数据源类型（考虑模块化配置）
  String get _effectiveDataSourceType {
    if (_moduleDataSources != null &&
        _moduleDataSources!.containsKey('purchase')) {
      return _moduleDataSources!['purchase']!;
    }
    return _dataSourceType;
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqlitePurchaseDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlConnection = connection;
    _mysqlDataSource = MySqlPurchaseDataSource.withConnectionGetter(
      () async {
        final conn = await _currentMysqlConnection;
        return conn;
      },
      reconnectCallback: () async {
        // 重连回调：尝试重新初始化MySQL连接
        if (_databaseProvider != null) {
          try {
            await _databaseProvider.initializeMySQL();
            print('✅ PurchaseProvider: MySQL重连成功');
          } catch (e) {
            print('❌ PurchaseProvider: MySQL重连失败: $e');
          }
        }
      },
    );
  }

  // 设置用户权限提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;

    // 清除缓存，强制重新加载数据以应用权限过滤
    clearCache();

    print('✅ PurchaseProvider已设置UserProvider引用，权限过滤已启用');
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  PurchaseDataSource get _currentDataSource {
    final effectiveType = _effectiveDataSourceType;

    if (effectiveType == 'mysql') {
      // 如果要求使用MySQL但未初始化，尝试降级到SQLite
      if (_mysqlDataSource == null) {
        if (_sqliteDataSource != null) {
          print('⚠️ MySQL采购数据源未初始化，自动降级到SQLite');
          return _sqliteDataSource!;
        }
        throw Exception('MySQL采购数据源未初始化 - 模块配置要求使用MySQL但数据源未设置');
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
  Future<MySqlConnection?> get _currentMysqlConnection =>
      _mysqlConnectionService.getCurrentConnection();

  // 验证MySQL连接是否有效
  Future<bool> _validateConnection(MySqlConnection connection) =>
      _mysqlConnectionService.validateConnection(connection);

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
  MySqlConnection? get _syncMysqlConnection =>
      _mysqlConnectionService.getSyncConnection();

  // 测试MySQL连接是否有效
  Future<bool> _testMySqlConnection() async {
    try {
      final ok = await _mysqlConnectionService.testCurrentConnection();
      if (!ok) {
        _setError('MySQL连接测试失败');
        return false;
      }
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

  // 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedRecords != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  // 更新缓存
  void _updateCache(List<PurchaseRecord> records) {
    _cachedRecords = List.from(records);
    _lastCacheTime = DateTime.now();
  }

  // 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _lastCacheTime = null;
    _purchasesNeedRefresh = true; // 标记需要刷新
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 分页：获取采购记录总数
  Future<int> getPurchaseRecordsCount({
    String? searchQuery,
  }) async {
    if (!initialized) {
      throw Exception(
          '数据库未初始化 - SQLite: ${_database != null}, MySQL: ${_mysqlConnection != null}');
    }

    try {
      // 获取权限过滤条件
      final doctorFilter = _getDoctorFilter();

      // 使用数据源模式（统一接口）
      final count = await _currentDataSource.getPurchasesCount(
        searchQuery: searchQuery,
        doctorFilter: doctorFilter,
      );
      return count;
    } catch (e) {
      print('getPurchaseRecordsCount 出错: $e');
      return 0;
    }
  }

  // 分页：获取采购记录
  Future<List<PurchaseRecord>> getPurchaseRecords({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  }) async {
    if (!initialized) {
      throw Exception(
          '数据库未初始化 - SQLite: ${_database != null}, MySQL: ${_mysqlConnection != null}');
    }

    try {
      // 获取权限过滤条件
      final doctorFilter = _getDoctorFilter();

      // 使用数据源模式（统一接口）
      List<PurchaseRecord> records =
          await _currentDataSource.getPaginatedPurchases(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
        doctorFilter: doctorFilter,
      );
      return records;
    } catch (e) {
      print('getPurchaseRecords 出错: $e');
      return [];
    }
  }

  Future<List<PurchaseRecord>> searchPurchaseRecords(String keyword) async {
    if (!initialized) {
      return [];
    }

    try {
      final doctorFilter = _getDoctorFilter();
      return await _currentDataSource.searchPurchases(
        keyword,
        doctorFilter: doctorFilter,
      );
    } catch (e) {
      print('searchPurchaseRecords 出错: $e');
      return [];
    }
  }

  // 构造函数
  PurchaseProvider({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
    User? currentUser,
    Map<String, String>? moduleDataSources,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
    _currentUser = currentUser;
    _moduleDataSources = moduleDataSources;

    _mysqlConnectionService = PurchaseMysqlConnectionService(
      getDatabaseProvider: () => _databaseProvider is DatabaseProvider
          ? _databaseProvider as DatabaseProvider
          : null,
      getCachedConnection: () => _mysqlConnection,
      setCachedConnection: (connection) {
        _mysqlConnection = connection;
      },
      getEffectiveDataSourceType: () => _effectiveDataSourceType,
    );
    _syncService = PurchaseSyncService(
      getSyncMysqlConnection: () => _syncMysqlConnection,
      getEffectiveDataSourceType: () => _effectiveDataSourceType,
    );
  }

  // 设置数据库连接
  Future<void> setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
    Map<String, String>? moduleDataSources,
  }) async {
    print('PurchaseProvider.setDatabaseConnection - 开始设置数据库连接');
    print('PurchaseProvider.setDatabaseConnection - 当前数据源类型: $_dataSourceType');
    print('PurchaseProvider.setDatabaseConnection - 新的数据源类型: $dataSourceType');
    print(
        'PurchaseProvider.setDatabaseConnection - 当前SQLite数据库: ${_database != null ? "已连接" : "未连接"}');
    print(
        'PurchaseProvider.setDatabaseConnection - 当前MySQL连接: ${_mysqlConnection != null ? "已连接" : "未连接"}');
    print(
        'PurchaseProvider.setDatabaseConnection - 新的SQLite数据库: ${database != null ? "已提供" : "未提供"}');
    print(
        'PurchaseProvider.setDatabaseConnection - 新的MySQL连接: ${mysqlConnection != null ? "已提供" : "未提供"}');

    if (database != null) {
      _database = database;
      print('PurchaseProvider.setDatabaseConnection - SQLite数据库连接已设置');
    }
    if (mysqlConnection != null) {
      _mysqlConnection = mysqlConnection;
      print('PurchaseProvider.setDatabaseConnection - MySQL连接已设置');
    }
    if (dataSourceType != null) {
      _dataSourceType = dataSourceType;
      print(
          'PurchaseProvider.setDatabaseConnection - 数据源类型已设置为: $_dataSourceType');
    }
    if (currentUser != null) {
      _currentUser = currentUser;
      print('PurchaseProvider.setDatabaseConnection - 当前用户已设置');
    }
    if (moduleDataSources != null) {
      _moduleDataSources = moduleDataSources;
      print(
          'PurchaseProvider.setDatabaseConnection - 模块数据源配置已设置: $_moduleDataSources');
    }

    print('PurchaseProvider.setDatabaseConnection - 设置完成后的状态:');
    print('PurchaseProvider.setDatabaseConnection - 数据源类型: $_dataSourceType');
    print(
        'PurchaseProvider.setDatabaseConnection - SQLite数据库: ${_database != null ? "已连接" : "未连接"}');
    print(
        'PurchaseProvider.setDatabaseConnection - 模块数据源配置: $_moduleDataSources');
    print('PurchaseProvider.setDatabaseConnection - 初始化状态: $initialized');
  }

  // 标记刷新
  void markPurchasesNeedRefresh() {
    _purchasesNeedRefresh = true;
    notifyListeners();
  }

  // 重置刷新标志
  void resetPurchasesRefreshFlag() {
    _purchasesNeedRefresh = false;
  }

  // 更新模块数据源配置
  void updateModuleDataSources(Map<String, String> moduleDataSources) {
    _moduleDataSources = moduleDataSources;
    _isUsingTemporaryModuleDataSources = true; // 标记为使用了临时覆盖
    print(
        'PurchaseProvider.updateModuleDataSources - 模块数据源配置已更新: $_moduleDataSources');
    print('⏸️ PurchaseProvider.updateModuleDataSources - 已设置临时覆盖标志');

    // 检查当前需要的数据源是否已初始化
    final requiredType = _effectiveDataSourceType;
    print(
        'PurchaseProvider.updateModuleDataSources - 当前需要的数据源类型: $requiredType');

    if (requiredType == 'mysql' && _mysqlDataSource == null) {
      print('⚠️ 警告：模块配置要求使用MySQL，但MySQL数据源未初始化');
      print('⚠️ MySQL连接状态: ${_mysqlConnection != null ? "已连接" : "未连接"}');

      // 尝试从DatabaseProvider获取MySQL连接并初始化
      if (_databaseProvider != null) {
        try {
          final mysqlConnection = _databaseProvider.mysqlConnection;
          if (mysqlConnection != null) {
            _mysqlConnection = mysqlConnection;
            setMySqlDataSource(mysqlConnection);
            print('✅ 已重新初始化MySQL数据源');
          } else {
            print('❌ 无法获取MySQL连接');
          }
        } catch (e) {
          print('❌ 获取MySQL连接失败: $e');
        }
      }
    } else if (requiredType == 'sqlite' && _sqliteDataSource == null) {
      print('⚠️ 警告：模块配置要求使用SQLite，但SQLite数据源未初始化');
      print('⚠️ SQLite连接状态: ${_database != null ? "已连接" : "未连接"}');

      // 尝试从DatabaseProvider获取SQLite连接并初始化
      if (_databaseProvider != null) {
        try {
          final database = _databaseProvider.database;
          if (database != null) {
            _database = database;
            setSqliteDataSource(database);
            print('✅ 已重新初始化SQLite数据源');
          } else {
            print('❌ 无法获取SQLite数据库');
          }
        } catch (e) {
          print('❌ 获取SQLite数据库失败: $e');
        }
      }
    }

    // 通知所有监听者配置已更新
    notifyListeners();
  }

  // 从DatabaseProvider初始化（支持模块化配置）
  Future<void> initializeFromDatabase(dynamic dbProvider,
      {Map<String, String>? moduleDataSources,
      String? dataSourceMode,
      UserProvider? userProvider}) async {
    try {
      // 确定要使用的数据源类型
      String dbType = 'sqlite';

      // 如果是模块化模式且有模块配置，优先使用模块配置
      if (dataSourceMode == 'modular' &&
          moduleDataSources != null &&
          moduleDataSources.containsKey('purchase')) {
        dbType = moduleDataSources['purchase']!;
      } else {
        // 否则使用全局配置
        try {
          if (dbProvider.dataSourceType != null) {
            dbType = dbProvider.dataSourceType;
          }
        } catch (e) {
          // 使用默认值
        }
      }

      // 检查是否需要重新初始化
      if (_isInitialized && _lastInitializedDataSource == dbType) {
        if (dbType == 'mysql' && _mysqlDataSource == null) {
          print('⚠️ PurchaseProvider检测到MySQL数据源未就绪，继续尝试初始化');
        } else if (dbType == 'sqlite' && _sqliteDataSource == null) {
          print('⚠️ PurchaseProvider检测到SQLite数据源未就绪，继续尝试初始化');
        } else {
          // 已经初始化过相同的数据源且数据源对象可用，跳过
          return;
        }
      }

      print('PurchaseProvider开始从DatabaseProvider初始化...');

      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;

      // 仅在没有使用临时覆盖时更新模块配置
      // 这样可以避免ChangeNotifierProxyProvider的update覆盖降级时的临时配置
      if (!_isUsingTemporaryModuleDataSources) {
        _moduleDataSources = moduleDataSources;
      } else {
        print('⏸️ initializeFromDatabase：已使用临时模块数据源配置，跳过覆盖');
      }

      // 保存用户权限提供者引用
      if (userProvider != null) {
        _userProvider = userProvider;
        print('✅ PurchaseProvider已设置UserProvider引用');
      }

      // 输出使用的数据源类型
      if (dataSourceMode == 'modular' &&
          moduleDataSources != null &&
          moduleDataSources.containsKey('purchase')) {
        print('PurchaseProvider使用模块化配置: purchase -> $dbType');
      } else {
        // 否则使用全局配置
        try {
          if (dbProvider.dataSourceType != null) {
            dbType = dbProvider.dataSourceType;
          }
        } catch (e) {
          print('获取dataSourceType失败，使用默认值: $e');
        }
        print('PurchaseProvider使用全局配置: $dbType');
      }

      // 设置数据源类型
      _dataSourceType = dbType;

      // 根据确定的数据源类型初始化对应的数据源
      if (dbType == 'sqlite') {
        // 初始化SQLite数据源
        try {
          if (dbProvider.database != null) {
            _database = dbProvider.database;

            // 执行数据库迁移，添加doctor字段
            await _migratePurchaseRecordsTable();

            setSqliteDataSource(dbProvider.database);
          }
        } catch (e) {
          print('获取SQLite数据库失败: $e');
        }
      } else if (dbType == 'mysql') {
        // 初始化MySQL数据源
        try {
          final mysqlConnection = dbProvider.mysqlConnection;
          if (mysqlConnection != null) {
            _mysqlConnection = mysqlConnection;

            // 执行数据库迁移，添加doctor字段
            await _migratePurchaseRecordsTable();

            setMySqlDataSource(mysqlConnection);
          } else {
            print('⚠️ MySQL连接为null，自动降级到SQLite');
            _dataSourceType = 'sqlite';

            // 降级到SQLite
            if (dbProvider.database != null) {
              _database = dbProvider.database;
              await _migratePurchaseRecordsTable();
              setSqliteDataSource(dbProvider.database);
              print('✅ PurchaseProvider已降级到SQLite数据源');
            } else {
              print('❌ SQLite数据库也不可用');
            }
          }
        } catch (e) {
          print('获取MySQL连接失败: $e');
          // 尝试降级到SQLite
          _dataSourceType = 'sqlite';
          if (dbProvider.database != null) {
            _database = dbProvider.database;
            try {
              await _migratePurchaseRecordsTable();
              setSqliteDataSource(dbProvider.database);
              print('✅ PurchaseProvider已降级到SQLite数据源');
            } catch (fallbackError) {
              print('❌ 降级到SQLite也失败: $fallbackError');
            }
          }
        }
      }

      // 标记初始化完成
      _isInitialized = true;
      _lastInitializedDataSource = _dataSourceType;

      print('PurchaseProvider初始化完成，数据源类型: $dbType');
    } catch (e) {
      print('PurchaseProvider初始化失败: $e');
      _dataSourceType = 'sqlite';
    }

    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // =================== 数据库迁移方法 ===================

  // 初始化状态跟踪
  bool _isInitialized = false;
  String? _lastInitializedDataSource;

  // 迁移状态跟踪 - 按数据源类型分别跟踪
  static bool _sqliteMigrationCompleted = false;
  static bool _mysqlMigrationCompleted = false;

  /// 迁移采购记录表，添加doctor字段（仅在需要时执行）
  Future<void> _migratePurchaseRecordsTable() async {
    final effectiveDataSourceType = _effectiveDataSourceType;

    // 根据数据源类型检查是否已完成迁移
    if (effectiveDataSourceType == 'sqlite' && _sqliteMigrationCompleted) {
      return;
    }
    if (effectiveDataSourceType == 'mysql' && _mysqlMigrationCompleted) {
      return;
    }

    try {
      if (effectiveDataSourceType == 'sqlite' && _database != null) {
        await PurchaseMigration.addDoctorFieldToSQLite(_database!);
        _sqliteMigrationCompleted = true;
      } else if (effectiveDataSourceType == 'mysql' &&
          _mysqlConnection != null) {
        await PurchaseMigration.addDoctorFieldToMySQL(_mysqlConnection!);
        _mysqlMigrationCompleted = true;
      }
    } catch (e) {
      print('❌ 采购记录表迁移失败: $e');
      // 迁移失败不应该阻止应用启动，只记录错误
    }
  }

  // =================== 采购相关方法 ===================

  // 添加采购记录
  Future<int> addPurchaseRecord(PurchaseRecord record) async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    print(
        'PurchaseProvider.addPurchaseRecord - 使用数据源类型: $effectiveDataSourceType');
    print('PurchaseProvider.addPurchaseRecord - 初始化状态: $initialized');
    print(
        'PurchaseProvider.addPurchaseRecord - SQLite数据库: ${_database != null ? "已连接" : "未连接"}');
    print(
        'PurchaseProvider.addPurchaseRecord - MySQL连接: ${_mysqlConnection != null ? "已连接" : "未连接"}');
    print('PurchaseProvider.addPurchaseRecord - 模块数据源配置: $_moduleDataSources');

    if (!initialized) {
      throw Exception(
          '数据库未初始化 - SQLite: ${_database != null}, MySQL: ${_mysqlConnection != null}');
    }

    try {
      // 使用数据源模式（统一接口）
      final recordId = await _currentDataSource.createPurchase(record);
      // 清除缓存并标记需要刷新
      clearCache();
      markPurchasesNeedRefresh();

      // 如果当前使用的是SQLite数据源，需要同步到MySQL
      if (_syncService.needsSync) {
        final recordMap = record.toMap();
        recordMap['id'] = recordId;
        _syncService.syncPurchaseRecordToMySQL(recordMap, recordId);
      }

      return recordId;
    } catch (e) {
      print('添加采购记录时出错: $e');
      throw Exception('添加采购记录失败: $e');
    }
  }

  // =================== 权限过滤方法 ===================

  // 获取医生过滤条件（用于数据库层面过滤）
  String? _getDoctorFilter() {
    try {
      // 如果没有用户权限提供者或当前用户是管理员，不进行过滤
      if (_userProvider == null || _userProvider!.currentUser == null) {
        return null;
      }

      final currentUser = _userProvider!.currentUser!;
      if (currentUser.isAdmin) {
        return null; // 管理员不过滤
      }

      // 获取当前用户的医生字段
      final doctorName = currentUser.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回一个不存在的值，确保查询结果为空
        return '__NO_DOCTOR__';
      }

      return doctorName;
    } catch (e) {
      print('❌ 获取医生过滤条件失败: $e');
      // 出错时返回安全的过滤条件
      return '__NO_DOCTOR__';
    }
  }

  // 应用权限过滤（基于医生字段过滤采购记录）- 保留作为备用方法
  Future<List<PurchaseRecord>> _applyPermissionFilter(
      List<PurchaseRecord> records) async {
    try {
      // 如果没有用户权限提供者或当前用户是管理员，不进行过滤
      if (_userProvider == null || _userProvider!.currentUser == null) {
        return records;
      }

      final currentUser = _userProvider!.currentUser!;
      if (currentUser.isAdmin) {
        return records;
      }

      // 获取当前用户的医生字段
      final doctorName = currentUser.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回空列表
        print('当前用户没有医生字段，返回空采购记录列表');
        return [];
      }

      // 过滤采购记录：只显示医生字段匹配的记录
      List<PurchaseRecord> filteredRecords = [];

      for (final record in records) {
        // 检查医生字段是否匹配
        if (record.doctor == doctorName) {
          filteredRecords.add(record);
        }
      }

      return filteredRecords;
    } catch (e) {
      print('应用采购记录权限过滤失败: $e');
      // 出错时返回空列表，确保安全
      return [];
    }
  }

  // 获取所有采购记录（纯数据源模式，支持权限过滤）
  Future<List<PurchaseRecord>> getAllPurchaseRecords() async {
    if (!initialized) {
      return _cachedRecords ?? []; // 优雅降级而不是抛出异常
    }

    try {
      // 优先检查缓存
      if (_isCacheValid() && !_purchasesNeedRefresh) {
        print('使用缓存的采购记录数据: ${_cachedRecords!.length} 条');
        return _cachedRecords!;
      }

      print('🔄 从数据库获取最新采购记录...');

      // 获取权限过滤条件
      final doctorFilter = _getDoctorFilter();

      // 使用数据源模式（统一接口）
      List<PurchaseRecord> records =
          await _currentDataSource.getAllPurchases(doctorFilter: doctorFilter);
      // 更新缓存
      _updateCache(records);
      _purchasesNeedRefresh = false; // 清除刷新标志
      print('✅ 采购记录缓存已更新');

      return records;
    } catch (e) {
      print('❌ 获取采购记录失败: $e');

      // 优雅降级：如果有缓存就返回缓存，否则返回空列表
      if (_isCacheValid()) {
        print('使用缓存的采购记录数据，查询失败: $e');
        return _cachedRecords!;
      }

      return []; // 返回空列表而不是抛出异常
    }
  }

  // 获取采购记录详情
  Future<PurchaseRecord?> getPurchaseRecordById(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final record = await _currentDataSource.getPurchaseById(id);
      return record;
    } catch (e) {
      print('获取采购记录详情时出错: $e');
      return null;
    }
  }

  // 更新采购记录
  Future<bool> updatePurchaseRecord(PurchaseRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.updatePurchase(record);
      if (success) {
        // 清除缓存并标记需要刷新
        clearCache();
        markPurchasesNeedRefresh();

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync && record.id != null) {
          final recordMap = record.toMap();
          _syncService.syncPurchaseRecordToMySQL(recordMap, record.id!);
        }
      }
      return success;
    } catch (e) {
      print('更新采购记录时出错: $e');
      return false;
    }
  }

  // 删除采购记录
  Future<bool> deletePurchaseRecord(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.deletePurchase(id);
      if (success) {
        // 清除缓存并标记需要刷新
        clearCache();
        markPurchasesNeedRefresh();

        // 如果当前使用的是SQLite数据源，需要同步删除到MySQL
        if (_syncService.needsSync) {
          _syncService.syncDeletePurchaseRecordToMySQL(id);
        }
      }
      return success;
    } catch (e) {
      print('删除采购记录时出错: $e');
      return false;
    }
  }

  // 添加采购项目
  Future<int?> addPurchaseItem(PurchaseItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 确保采购项目表存在
      await ensurePurchaseItemsTableExists();

      // 使用数据源模式（统一接口）
      final id = await _currentDataSource.createPurchaseItem(item);
      markPurchasesNeedRefresh();

      // 如果当前使用的是SQLite数据源，需要同步到MySQL
      if (_syncService.needsSync && id != null) {
        final itemMap = item.toMap();
        itemMap['id'] = id;
        _syncService.syncPurchaseItemToMySQL(itemMap, id);
      }

      return id;
    } catch (e) {
      print('添加采购项目时出错: $e');
      throw Exception('添加采购项目失败: $e');
    }
  }

  // 删除采购项目
  Future<bool> deletePurchaseItem(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.deletePurchaseItem(id);
      if (success) {
        markPurchasesNeedRefresh();

        // 如果当前使用的是SQLite数据源，需要同步删除到MySQL
        if (_syncService.needsSync) {
          _syncService.syncDeletePurchaseItemToMySQL(id);
        }
      }
      return success;
    } catch (e) {
      print('删除采购项目时出错: $e');
      return false;
    }
  }

  // 获取采购记录的所有项目
  // 获取采购记录的所有项目
  Future<List<PurchaseItem>> getPurchaseItemsByRecordId(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 确保采购项目表存在
      await ensurePurchaseItemsTableExists();

      // 使用数据源模式（统一接口）
      final items =
          await _currentDataSource.getPurchaseItemsByRecordId(recordId);
      return items;
    } catch (e) {
      print('获取采购项目时出错: $e');
      return [];
    }
  }

  // 创建采购项目表
  Future<void> createPurchaseItemsTable() async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    print(
        'PurchaseProvider.createPurchaseItemsTable - 使用数据源类型: $effectiveDataSourceType');

    await _currentDataSource.ensureTablesExist();
  }

  // 确保采购项目表存在
  Future<void> ensurePurchaseItemsTableExists() async {
    final effectiveDataSourceType = _effectiveDataSourceType;
    print(
        'PurchaseProvider.ensurePurchaseItemsTableExists - 使用数据源类型: $effectiveDataSourceType');

    try {
      await _currentDataSource.ensureTablesExist();
    } catch (e) {
      print('检查purchase_items表时出错: $e');
    }
  }

  // 更新采购项目
  Future<bool> updatePurchaseItem(PurchaseItem item) async {
    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.updatePurchaseItem(item);
      if (success) {
        markPurchasesNeedRefresh();

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync && item.id != null) {
          final itemMap = item.toMap();
          _syncService.syncPurchaseItemToMySQL(itemMap, item.id!);
        }
      }
      return success;
    } catch (e) {
      print('更新采购项目时出错: $e');
      return false;
    }
  }

  // =================== SQLite→MySQL 同步方法 ===================

  /// 尝试建立MySQL连接的辅助方法
  Future<MySqlConnection?> _tryEstablishMySQLConnection() async {
    final conn = await MySqlConnectionHelper.establishConnection();
    if (conn != null) {
      _mysqlConnection = conn;
    }
    return conn;
  }
}

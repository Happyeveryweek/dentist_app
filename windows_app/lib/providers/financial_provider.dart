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

import '../providers/patient_provider.dart';
import '../utils/datetime_formatter.dart';
import '../providers/user_provider.dart';
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
import '../providers/settings_provider.dart';
import '../utils/pinyin_util.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import '../data_sources/financial_data_source.dart';
import '../features/financial/services/financial_mysql_connection_service.dart';
import '../features/financial/services/financial_query_service.dart';
import '../features/financial/services/financial_sync_service.dart';
import '../features/financial/services/financial_permission_service.dart';
import '../features/financial/services/financial_data_source_initializer.dart';
import '../features/financial/helpers/financial_cache_helper.dart';

/// 财务管理提供者
/// 负责处理所有与财务相关的数据库操作
class FinancialProvider extends ChangeNotifier {
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
  bool _financialsNeedRefresh = false;

  // 缓存助手
  final FinancialCacheHelper _cacheHelper = FinancialCacheHelper();

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 患者提供者引用（用于获取患者信息）
  PatientProvider? _patientProvider;

  // 用户权限提供者引用
  UserProvider? _userProvider;

  // 连接状态
  bool _isConnected = true;
  String? _lastError;

  // 查询服务
  late final FinancialQueryService _queryService;
  late final FinancialMysqlConnectionService _mysqlConnectionService;
  late final FinancialSyncService _syncService;
  late final FinancialPermissionService _permissionService;
  late final FinancialDataSourceInitializer _dataSourceInitializer;

  // Getters
  bool get initialized => _database != null || _mysqlConnection != null;
  bool get financialsNeedRefresh => _financialsNeedRefresh;
  String get dataSourceType => _dataSourceType;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  // 缓存相关getters
  bool get hasValidCache => _cacheHelper.hasValidCache;
  DateTime? get lastCacheTime => _cacheHelper.lastCacheTime;
  int get cachedRecordsCount => _cacheHelper.cachedRecordsCount;

  // 获取有效的数据源类型（考虑模块化配置）
  String get _effectiveDataSourceType =>
      _dataSourceInitializer.effectiveDataSourceType;

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _dataSourceInitializer.setSqliteDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _dataSourceInitializer.setMySqlDataSource(
      connection: connection,
      databaseProvider: _databaseProvider,
    );
  }

  // 设置患者提供者
  void setPatientProvider(PatientProvider patientProvider) {
    _patientProvider = patientProvider;

    // 更新权限服务的患者提供者引用
    _permissionService = FinancialPermissionService(
      patientProvider: _patientProvider,
      userProvider: _userProvider,
    );

    // 清除缓存，强制重新加载数据以应用权限过滤
    _cacheHelper.clearCache();
    _financialsNeedRefresh = true;

    print('✅ FinancialProvider已设置PatientProvider引用');
  }

  // 设置用户权限提供者
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;

    // 更新权限服务的用户提供者引用
    _permissionService = FinancialPermissionService(
      patientProvider: _patientProvider,
      userProvider: _userProvider,
    );

    // 清除缓存，强制重新加载数据以应用权限过滤
    _cacheHelper.clearCache();
    _financialsNeedRefresh = true;

    print('✅ FinancialProvider已设置UserProvider引用，权限过滤已启用');
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  FinancialDataSource get _currentDataSource =>
      _dataSourceInitializer.getCurrentDataSource();

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

  // 确保MySQL连接有效
  Future<void> _ensureMySQLConnection() async {
    try {
      // 使用_currentMysqlConnection getter，它会自动从DatabaseProvider获取最新连接并验证
      final conn = await _currentMysqlConnection;
      if (conn == null) {
        throw Exception('MySQL连接不可用');
      }

      _isConnected = true;
      _clearError();
    } catch (e) {
      print('❌ FinancialProvider MySQL连接验证失败: $e');
      _setError('MySQL连接失败: $e');
      rethrow;
    }
  }

  // 清除缓存
  void clearCache() {
    _cacheHelper.clearCache();
    _financialsNeedRefresh = true; // 标记需要刷新
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 处理数据变更后的缓存清理和同步
  void _handleAfterDataChange({bool clearCache = true}) {
    if (clearCache) {
      this.clearCache();
    }
    markFinancialsNeedRefresh();
  }

  // 同步财务记录到MySQL
  void _syncFinancialRecordToMySQL(
      Map<String, dynamic> recordMap, int recordId) {
    if (_syncService.needsSync) {
      _syncService.syncFinancialRecordToMySQL(recordMap, recordId);
    }
  }

  // 同步财务项目到MySQL
  void _syncFinancialItemToMySQL(Map<String, dynamic> itemMap, int itemId) {
    if (_syncService.needsSync) {
      _syncService.syncFinancialItemToMySQL(itemMap, itemId);
    }
  }

  // 同步删除财务记录到MySQL
  void _syncDeleteFinancialRecordToMySQL(int id) {
    if (_syncService.needsSync) {
      _syncService.syncDeleteFinancialRecordToMySQL(id);
    }
  }

  // 同步删除财务项目到MySQL
  void _syncDeleteFinancialItemToMySQL(int id) {
    if (_syncService.needsSync) {
      _syncService.syncDeleteFinancialItemToMySQL(id);
    }
  }

  // 构造函数
  FinancialProvider({
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

    _queryService = FinancialQueryService(
      getCurrentDataSource: () => _currentDataSource,
      getDoctorFilter: () => _permissionService.getDoctorFilter(),
      isInitialized: () => initialized,
    );
    _mysqlConnectionService = FinancialMysqlConnectionService(
      getDatabaseProvider: () => _databaseProvider is DatabaseProvider
          ? _databaseProvider as DatabaseProvider
          : null,
      getCachedConnection: () => _mysqlConnection,
      setCachedConnection: (connection) {
        _mysqlConnection = connection;
      },
      getEffectiveDataSourceType: () => _effectiveDataSourceType,
    );
    _syncService = FinancialSyncService(
      getSyncMysqlConnection: () => _syncMysqlConnection,
      getEffectiveDataSourceType: () => _effectiveDataSourceType,
    );
    _permissionService = FinancialPermissionService(
      patientProvider: _patientProvider,
      userProvider: _userProvider,
    );
    _dataSourceInitializer = FinancialDataSourceInitializer();

    // 不再自动检查表是否存在，表结构检测由SettingsProvider统一管理
  }

  // 设置数据库连接
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
    Map<String, String>? moduleDataSources,
  }) {
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) _currentUser = currentUser;
    if (moduleDataSources != null) _moduleDataSources = moduleDataSources;

    // 不再自动检查表是否存在，表结构检测由SettingsProvider统一管理
  }

  // 标记刷新
  void markFinancialsNeedRefresh() {
    _financialsNeedRefresh = true;
    notifyListeners();
  }

  // 从DatabaseProvider初始化（支持模块化配置）
  Future<void> initializeFromDatabase(dynamic dbProvider,
      {Map<String, String>? moduleDataSources,
      String? dataSourceMode,
      PatientProvider? patientProvider,
      UserProvider? userProvider}) async {
    try {
      print('FinancialProvider开始从DatabaseProvider初始化...');

      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;

      // 仅在没有使用临时覆盖时更新模块配置
      // 这样可以避免ChangeNotifierProxyProvider的update覆盖降级时的临时配置
      if (!_isUsingTemporaryModuleDataSources) {
        _moduleDataSources = moduleDataSources;
      } else {
        print('⏸️ initializeFromDatabase：已使用临时模块数据源配置，跳过覆盖');
      }

      // 保存患者提供者和用户权限提供者引用
      if (patientProvider != null) {
        _patientProvider = patientProvider;
        print('✅ FinancialProvider已设置PatientProvider引用');
      }

      if (userProvider != null) {
        _userProvider = userProvider;
        print('✅ FinancialProvider已设置UserProvider引用');
      }

      // 使用数据源初始化服务
      await _dataSourceInitializer.initialize(
        databaseProvider: dbProvider,
        moduleDataSources: _moduleDataSources,
        dataSourceMode: dataSourceMode,
      );

      // 更新本地数据源类型
      _dataSourceType = _dataSourceInitializer.effectiveDataSourceType;

      // 更新本地数据库连接字段
      if (_dataSourceType == 'sqlite') {
        _database = dbProvider.database;
      } else if (_dataSourceType == 'mysql') {
        _mysqlConnection = dbProvider.mysqlConnection;
      }

      print('FinancialProvider初始化完成，数据源类型: $_dataSourceType');
    } catch (e) {
      print('FinancialProvider初始化失败: $e');
      _dataSourceType = 'sqlite';
    }

    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 更新模块数据源配置
  void updateModuleDataSources(Map<String, String> moduleDataSources) {
    _moduleDataSources = moduleDataSources;
    _isUsingTemporaryModuleDataSources = true; // 标记为使用了临时覆盖
    print(
        'FinancialProvider.updateModuleDataSources - 模块数据源配置已更新: $_moduleDataSources');
    print('⏸️ FinancialProvider.updateModuleDataSources - 已设置临时覆盖标志');

    // 使用数据源初始化服务更新模块配置
    _dataSourceInitializer.updateModuleDataSources(moduleDataSources);

    // 更新本地数据源类型
    _dataSourceType = _dataSourceInitializer.effectiveDataSourceType;

    // 检查当前需要的数据源是否已初始化
    final requiredType = _effectiveDataSourceType;
    print(
        'FinancialProvider.updateModuleDataSources - 当前需要的数据源类型: $requiredType');

    if (requiredType == 'mysql' &&
        _dataSourceInitializer.mysqlDataSource == null) {
      print('⚠️ 警告：模块配置要求使用MySQL，但MySQL数据源未初始化');
      print('⚠️ MySQL连接状态: ${_mysqlConnection != null ? "已连接" : "未连接"}');

      // 尝试从DatabaseProvider获取MySQL连接并初始化
      if (_databaseProvider != null) {
        try {
          final mysqlConnection = _databaseProvider.mysqlConnection;
          if (mysqlConnection != null) {
            _mysqlConnection = mysqlConnection;
            _dataSourceInitializer.setMySqlDataSource(
              connection: mysqlConnection,
              databaseProvider: _databaseProvider,
            );
            print('✅ 已重新初始化MySQL数据源');
          } else {
            print('❌ 无法获取MySQL连接');
          }
        } catch (e) {
          print('❌ 获取MySQL连接失败: $e');
        }
      }
    } else if (requiredType == 'sqlite' &&
        _dataSourceInitializer.sqliteDataSource == null) {
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

  // 重置刷新标志
  void resetFinancialsRefreshFlag() {
    _financialsNeedRefresh = false;
  }

  // =================== 新的数据源模式方法 ===================

  // =================== 权限过滤方法 ===================

  // 获取所有财务记录（纯数据源模式，支持权限过滤）
  Future<List<FinancialRecord>> getAllFinancialRecordsNew() async {
    if (!initialized) {
      return _cacheHelper.cachedRecords ?? []; // 优雅降级而不是抛出异常
    }

    try {
      // 优先检查缓存
      if (_cacheHelper.hasValidCache && !_financialsNeedRefresh) {
        print('使用缓存的财务记录数据: ${_cacheHelper.cachedRecords!.length} 条');
        return _cacheHelper.cachedRecords!;
      }

      print('🔄 从数据库获取最新财务记录...');

      // 使用数据源模式（统一接口）
      List<FinancialRecord> records =
          await _currentDataSource.getAllFinancialRecords();
      // 应用权限过滤
      records = await _permissionService.applyPermissionFilter(records);

      // 更新缓存
      _cacheHelper.updateCache(records);
      _financialsNeedRefresh = false; // 清除刷新标志
      print('✅ 财务记录缓存已更新');

      return records;
    } catch (e) {
      print('❌ 获取财务记录失败: $e');

      // 优雅降级：如果有缓存就返回缓存，否则返回空列表
      if (_cacheHelper.hasValidCache) {
        print('使用缓存的财务记录数据，查询失败: $e');
        return _cacheHelper.cachedRecords!;
      }

      return []; // 返回空列表而不是抛出异常
    }
  }

  // 分页：获取财务记录总数
  Future<int> getFinancialRecordsCount({
    String? searchQuery,
  }) async {
    if (!initialized) {
      throw Exception(
          '数据库未初始化 - SQLite: ${_database != null}, MySQL: ${_mysqlConnection != null}');
    }

    try {
      // 使用数据源模式（统一接口）
      final count = await _currentDataSource.getFinancialRecordsCount(
          searchQuery: searchQuery);
      return count;
    } catch (e) {
      print('getFinancialRecordsCount 出错: $e');
      return 0;
    }
  }

  // 分页：获取财务记录
  Future<List<FinancialRecord>> getFinancialRecords({
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
      // 使用数据源模式（统一接口）
      List<FinancialRecord> records =
          await _currentDataSource.getPaginatedFinancialRecords(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
      );
      // 应用权限过滤
      records = await _permissionService.applyPermissionFilter(records);

      return records;
    } catch (e) {
      print('getFinancialRecords 出错: $e');
      return [];
    }
  }

  // 添加财务记录
  Future<int> addFinancialRecord(FinancialRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 调试日志
      print(
          '📝 addFinancialRecord: 当前_moduleDataSources = $_moduleDataSources');
      print(
          '📝 addFinancialRecord: 当前_effectiveDataSourceType = $_effectiveDataSourceType');
      print(
          '📝 addFinancialRecord: 当前_sqliteDataSource = ${_dataSourceInitializer.sqliteDataSource != null ? "已初始化" : "未初始化"}');
      print(
          '📝 addFinancialRecord: 当前_mysqlDataSource = ${_dataSourceInitializer.mysqlDataSource != null ? "已初始化" : "未初始化"}');

      // 使用数据源模式（统一接口）
      final recordId = await _currentDataSource.createFinancialRecord(record);

      // 处理数据变更后的缓存清理和同步
      _handleAfterDataChange(clearCache: true);

      // 同步到MySQL
      final recordMap = record.toMap();
      recordMap['id'] = recordId;
      _syncFinancialRecordToMySQL(recordMap, recordId);

      return recordId;
    } catch (e) {
      print('添加财务记录时出错: $e');
      throw Exception('添加财务记录失败: $e');
    }
  }

  // 更新财务记录
  Future<bool> updateFinancialRecord(FinancialRecord record) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.updateFinancialRecord(record);
      if (success) {
        // 更新不触发整页刷新，避免界面闪烁
        _cacheHelper.clearCache();
        _financialsNeedRefresh = false;

        // 同步到MySQL
        if (record.id != null) {
          _syncFinancialRecordToMySQL(record.toMap(), record.id!);
        }
      }
      return success;
    } catch (e) {
      print('更新财务记录时出错: $e');
      return false;
    }
  }

  // 删除财务记录
  Future<bool> deleteFinancialRecord(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.deleteFinancialRecord(id);
      if (success) {
        // 处理数据变更后的缓存清理和同步
        _handleAfterDataChange(clearCache: true);

        // 同步删除到MySQL
        _syncDeleteFinancialRecordToMySQL(id);
      }
      return success;
    } catch (e) {
      print('删除财务记录时出错: $e');
      return false;
    }
  }

  // 获取财务项目
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final items =
          await _currentDataSource.getFinancialItemsByRecordId(recordId);
      return items;
    } catch (e) {
      print('获取财务项目时出错: $e');
      return [];
    }
  }

  // 添加财务项目
  Future<int> addFinancialItem(FinancialItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 调试日志
      print('📝 addFinancialItem: 当前_moduleDataSources = $_moduleDataSources');
      print(
          '📝 addFinancialItem: 当前_effectiveDataSourceType = $_effectiveDataSourceType');
      print(
          '📝 addFinancialItem: 当前_sqliteDataSource = ${_dataSourceInitializer.sqliteDataSource != null ? "已初始化" : "未初始化"}');
      print(
          '📝 addFinancialItem: 当前_mysqlDataSource = ${_dataSourceInitializer.mysqlDataSource != null ? "已初始化" : "未初始化"}');

      // 使用数据源模式（统一接口）
      final id = await _currentDataSource.createFinancialItem(item);

      // 处理数据变更后的缓存清理和同步（财务项目不清理缓存，只标记刷新）
      _handleAfterDataChange(clearCache: false);

      // 同步到MySQL
      final itemMap = item.toMap();
      itemMap['id'] = id;
      _syncFinancialItemToMySQL(itemMap, id);

      return id;
    } catch (e) {
      print('添加财务项目时出错: $e');
      throw Exception('添加财务项目失败: $e');
    }
  }

  // 更新财务项目
  Future<bool> updateFinancialItem(FinancialItem item) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.updateFinancialItem(item);
      if (success) {
        // 更新不触发整页刷新，避免界面闪烁
        _cacheHelper.clearCache();
        _financialsNeedRefresh = false;

        // 同步到MySQL
        if (item.id != null) {
          _syncFinancialItemToMySQL(item.toMap(), item.id!);
        }
      }
      return success;
    } catch (e) {
      print('更新财务项目时出错: $e');
      return false;
    }
  }

  // 删除财务项目
  Future<bool> deleteFinancialItem(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final success = await _currentDataSource.deleteFinancialItem(id);
      if (success) {
        // 处理数据变更后的缓存清理和同步（财务项目不清理缓存，只标记刷新）
        _handleAfterDataChange(clearCache: false);

        // 同步删除到MySQL
        _syncDeleteFinancialItemToMySQL(id);
      }
      return success;
    } catch (e) {
      print('删除财务项目时出错: $e');
      return false;
    }
  }

  Future<bool> deleteFinancialItemAndCleanupRecord({
    required int itemId,
    required int recordId,
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      final deleteItemSuccess = await _currentDataSource.deleteFinancialItem(
        itemId,
      );
      if (!deleteItemSuccess) {
        return false;
      }

      final remainingItems =
          await _currentDataSource.getFinancialItemsByRecordId(recordId);
      if (remainingItems.isEmpty) {
        final deleteRecordSuccess =
            await _currentDataSource.deleteFinancialRecord(recordId);
        if (!deleteRecordSuccess) {
          return false;
        }

        _syncDeleteFinancialRecordToMySQL(recordId);
      }

      _handleAfterDataChange(clearCache: false);
      _syncDeleteFinancialItemToMySQL(itemId);
      return true;
    } catch (e) {
      print('删除财务项目并清理空记录时出错: $e');
      return false;
    }
  }

  // 获取财务统计信息
  Future<Map<String, dynamic>> getFinancialStatistics() async {
    if (!initialized) {
      return {
        'totalReceivable': 0.0,
        'totalReceived': 0.0,
        'totalPending': 0.0,
      };
    }

    try {
      // 使用数据源模式（统一接口）
      final stats = await _currentDataSource.getFinancialStatistics();
      return stats;
    } catch (e) {
      print('获取财务统计信息时出错: $e');
      return {
        'totalReceivable': 0.0,
        'totalReceived': 0.0,
        'totalPending': 0.0,
      };
    }
  }

  // =================== 兼容性方法（保持向后兼容） ===================

  // 确保必要的表存在
  Future<void> _ensureTablesExist() async {
    if (!initialized) return;

    try {
      await ensureFinancialRecordsTableExists();
    } catch (e) {
      print('确保财务表存在时出错: $e');
    }
  }

  // 确保财务记录表存在
  Future<void> ensureFinancialRecordsTableExists() async {
    await _currentDataSource.ensureTablesExist();
  }

  // 安全获取notes字段内容
  String _safeGetNotes(dynamic notes) {
    if (notes == null) return '';
    if (notes is String) return notes;
    if (notes is List<int>) {
      try {
        return utf8.decode(notes);
      } catch (e) {
        print('解码notes字段失败: $e');
        return '';
      }
    }
    return notes.toString();
  }

  // =================== 向后兼容的方法 ===================

  // 获取所有财务记录（向后兼容）
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    if (!initialized) {
      return _cacheHelper.cachedRecords ?? [];
    }

    try {
      // 优先检查缓存
      if (_cacheHelper.hasValidCache && !_financialsNeedRefresh) {
        print('使用缓存的财务记录数据: ${_cacheHelper.cachedRecords!.length} 条');
        return _cacheHelper.cachedRecords!;
      }

      print('🔄 从数据库获取最新财务记录...');

      // 使用数据源模式（统一接口）
      final records = await _currentDataSource.getAllFinancialRecords();
      // 更新缓存
      _cacheHelper.updateCache(records);
      _financialsNeedRefresh = false;
      print('✅ 财务记录缓存已更新');

      return records;
    } catch (e) {
      print('❌ 获取财务记录失败: $e');

      // 优雅降级：如果有缓存就返回缓存，否则返回空列表
      if (_cacheHelper.hasValidCache) {
        print('使用缓存的财务记录数据，查询失败: $e');
        return _cacheHelper.cachedRecords!;
      }

      return [];
    }
  }

  // 获取财务项目（向后兼容）
  Future<List<FinancialItem>> getFinancialItems(int recordId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 使用数据源模式（统一接口）
      final items =
          await _currentDataSource.getFinancialItemsByRecordId(recordId);
      return items;
    } catch (e) {
      print('获取财务项目时出错: $e');
      return [];
    }
  }

  // 患者维度分页聚合（用于"按患者显示"Route B）
  Future<Map<String, dynamic>> getPatientAggregatesPage({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    List<int>? patientIds,
    DateTime? startDate,
    DateTime? endDate,
  }) =>
      _queryService.getPatientAggregatesPage(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        patientIds: patientIds,
        startDate: startDate,
        endDate: endDate,
      );

  // 获取某患者"最近更新"的代表财务记录
  Future<FinancialRecord?> getLatestRecordForPatient(int patientId) =>
      _queryService.getLatestRecordForPatient(patientId);

  // 其他向后兼容方法
  Future<void> updatePatientFinancialSummary(int patientId) async {
    // 该方法保留给旧调用点使用，但现在改为触发一次静默刷新，
    // 让列表页在不显示整页 loading 的情况下重新拉取最新数据。
    _financialsNeedRefresh = true;
    notifyListeners();
  }

  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(int patientId) =>
      _queryService.getFinancialRecordsByPatientId(patientId);

  Future<FinancialRecord?> getFinancialRecordById(int id) =>
      _queryService.getFinancialRecordById(id);

  // 获取收费项总数和分页收费项等方法
  Future<int> getFinancialItemsCount({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
  }) =>
      _queryService.getFinancialItemsCount(
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        patientIds: patientIds,
        chargeItemQuery: chargeItemQuery,
        receivableMin: receivableMin,
        receivableMax: receivableMax,
        receivedMin: receivedMin,
        receivedMax: receivedMax,
        processingMin: processingMin,
        processingMax: processingMax,
      );

  Future<List<Map<String, dynamic>>> getFinancialItemsWithDetails({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
  }) =>
      _queryService.getFinancialItemsWithDetails(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        patientIds: patientIds,
        chargeItemQuery: chargeItemQuery,
        receivableMin: receivableMin,
        receivableMax: receivableMax,
        receivedMin: receivedMin,
        receivedMax: receivedMax,
        processingMin: processingMin,
        processingMax: processingMax,
      );

  Future<List<Map<String, dynamic>>> getAllFinancialItemsWithDetailsFiltered({
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
  }) =>
      _queryService.getAllFinancialItemsWithDetailsFiltered(
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        patientIds: patientIds,
        chargeItemQuery: chargeItemQuery,
        receivableMin: receivableMin,
        receivableMax: receivableMax,
        receivedMin: receivedMin,
        receivedMax: receivedMax,
        processingMin: processingMin,
        processingMax: processingMax,
      );

  // =================== SQLite→MySQL 同步方法 ===================
}

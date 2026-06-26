import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../models/user.dart';
import '../models/database_models.dart' show DatabaseHelper;
import '../utils/database_operation_wrapper.dart';
import '../data_sources/user_data_source.dart';
import '../data_sources/sqlite_user_data_source.dart';
import '../data_sources/mysql_user_data_source.dart';
import '../features/users/services/user_cache_service.dart';
import '../features/users/services/user_initialization_service.dart';
import '../features/users/services/user_session_service.dart';
import '../features/users/services/user_authentication_service.dart';
import '../features/users/services/user_statistics_service.dart';
import '../features/users/services/user_data_repair_service.dart';
import '../features/users/services/user_connection_service.dart';
import '../features/users/services/user_crud_service.dart';
import '../features/users/services/user_validation_service.dart';
import '../features/users/services/user_permission_service.dart';
import '../features/users/services/user_current_permission_service.dart';
import '../utils/app_logger.dart';

class UserProvider extends ChangeNotifier {
  // 数据库连接
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _dataSourceType = 'sqlite';

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;

  // 用户缓存/权限服务
  final UserCacheService _cacheService = UserCacheService();
  final UserInitializationService _initializationService =
      UserInitializationService();
  final UserConnectionService _connectionService = UserConnectionService();
  UserAuthenticationService? _authenticationService;
  UserStatisticsService? _statisticsService;
  UserDataRepairService? _dataRepairService;
  UserValidationService? _validationService;
  UserPermissionService? _permissionService;
  UserCurrentPermissionService? _currentPermissionService;
  UserCrudService? _crudService;

  // 数据源具体实现
  SqliteUserDataSource? _sqliteDataSource;
  MySqlUserDataSource? _mysqlDataSource;

  // 初始化标志
  bool _isInitializedFlag = false;

  // 当前用户信息
  User? _currentUser;

  // 刷新标志
  bool _usersNeedRefresh = false;

  // 用户列表缓存
  List<User> _users = [];

  // 错误信息
  String? _error;

  // Getters
  bool get initialized => _database != null || _currentMysqlConnection != null;
  bool get usersNeedRefresh => _usersNeedRefresh;
  User? get currentUser => _currentUser;
  List<User> get users => _users;
  String? get error => _error;
  bool get isConnected => _connectionService.isConnected;
  bool get isReconnecting => _connectionService.isReconnecting;
  String? get lastError => _connectionService.lastError;

  // 缓存相关方法
  bool get hasValidCache => _cacheService.hasValidCache;
  DateTime? get lastCacheTime => _cacheService.lastCacheTime;
  int get cachedUsersCount => _cacheService.cachedUsersCount;

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
    _sqliteDataSource = SqliteUserDataSource(database);
    _refreshUserServices();
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlUserDataSource.withConnectionGetter(
      () => _currentMysqlConnection,
    );
    _refreshUserServices();
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  UserDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      final dataSource = _mysqlDataSource;
      if (dataSource == null) {
        throw Exception('MySQL用户数据源未初始化');
      }
      return dataSource;
    } else {
      final dataSource = _sqliteDataSource;
      if (dataSource == null) {
        throw Exception('SQLite用户数据源未初始化');
      }
      return dataSource;
    }
  }

  void _refreshUserServices() {
    if (_sqliteDataSource == null && _mysqlDataSource == null) {
      return;
    }

    _connectionService.setConnections(
      mysqlConnection: _mysqlConnection,
      database: _database,
      dataSourceType: _dataSourceType,
      databaseProvider: _databaseProvider,
    );

    _permissionService = UserPermissionService(
      dataSource: _currentDataSource,
      cacheService: _cacheService,
    );
    _currentPermissionService = UserCurrentPermissionService(
      permissionService: _permissionService,
      currentUserGetter: () => _currentUser,
      getUserById: getUserById,
    );

    _authenticationService = UserAuthenticationService(
      dataSource: _currentDataSource,
      dbWrapper: _dbWrapper,
      isInitialized: () => _isInitializedFlag,
      getDataSourceType: () => _dataSourceType,
      notifyListeners: () => notifyListeners(),
      primeCurrentUserPermissions: (user) async {
        final service = _currentPermissionService;
        if (service != null) {
          await service.primeCurrentUserPermissions(user);
        }
      },
      authenticateWithLocalSqlite: _authenticateWithLocalSqliteFallback,
    );

    _statisticsService = UserStatisticsService(
      connectionService: _connectionService,
    );

    _dataRepairService = UserDataRepairService(
      connectionService: _connectionService,
      database: _database,
      dataSourceType: _dataSourceType,
      refreshUsers: forceRefreshUsers,
    );

    _validationService = UserValidationService(
      connectionService: _connectionService,
      database: _database,
      dataSourceType: _dataSourceType,
    );

    _crudService = UserCrudService(
      isInitialized: () => _isInitializedFlag,
      dbWrapper: _dbWrapper,
      currentDataSource: () => _currentDataSource,
      sqliteDatabase: () => _database,
      mysqlConnection: () => _currentMysqlConnection,
      dataSourceType: () => _dataSourceType,
      cacheService: _cacheService,
      setUsers: (users) => _users = users,
      setError: (error) => _error = error,
      clearCache: clearCache,
      markUsersNeedRefresh: markUsersNeedRefresh,
    );
  }

  // 清除缓存
  void clearCache() {
    _cacheService.clearCache();
    _usersNeedRefresh = true; // 标记需要刷新
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 构造函数
  UserProvider({
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

  // 设置数据库连接
  void setDatabaseConnection({
    Database? database,
    MySqlConnection? mysqlConnection,
    String? dataSourceType,
    User? currentUser,
  }) {
    if (database != null) _database = database;
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (currentUser != null) _currentUser = currentUser;
    _connectionService.setConnections(
      mysqlConnection: _mysqlConnection,
      database: _database,
      dataSourceType: _dataSourceType,
      databaseProvider: _databaseProvider,
    );
    _connectionService.resetConnectionState();
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

  // 从DatabaseProvider获取数据库连接（保持向后兼容）
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag) return;

    try {
      AppLogger.info('UserProvider开始初始化...');

      // 保存DatabaseProvider引用
      _databaseProvider = dbProvider;

      final result = await _initializationService.initializeFromDatabase(
        dbProvider: dbProvider,
      );
      _database = result.database;
      _mysqlConnection = result.mysqlConnection;
      _dataSourceType = result.dataSourceType;
      final conn = _mysqlConnection;
      final db = _database;
      if (_dataSourceType == 'mysql' && conn != null) {
        setMySqlDataSource(conn);
      } else if (db != null) {
        setSqliteDataSource(db);
      }
      _isInitializedFlag = result.initialized;

      // 初始化数据库操作包装器
      try {
        _dbWrapper = DatabaseOperationWrapper(dbProvider);
      } catch (e) {
        AppLogger.info('数据库操作包装器初始化失败: $e');
        // 不抛出异常，继续执行
      }

      _refreshUserServices();

      AppLogger.info('UserProvider初始化完成');
    } catch (e) {
      AppLogger.info('UserProvider初始化失败: $e');
      _isInitializedFlag = false;
    }

    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 标记刷新
  void markUsersNeedRefresh() {
    _usersNeedRefresh = true;
    notifyListeners();
  }

  // 重置刷新标志
  void resetUsersRefreshFlag() {
    _usersNeedRefresh = false;
  }

  // 强制刷新用户数据缓存
  Future<void> forceRefreshUsers() async {
    AppLogger.info('强制刷新用户数据缓存');
    clearCache();
    // 通知监听器
    notifyListeners();
  }

  // 获取所有用户（带缓存）
  Future<List<User>> getAllUsers() async {
    final crudService = _crudService;
    if (crudService == null) return _cacheService.getCachedUsers() ?? [];
    return await crudService.getAllUsers();
  }

  // 根据ID获取用户
  Future<User?> getUserById(int id) async {
    final crudService = _crudService;
    if (crudService == null) return null;
    return await crudService.getUserById(id);
  }

  // 创建用户
  Future<int> addUser(User user) async {
    final crudService = _crudService;
    if (crudService == null) return -1;
    return await crudService.addUser(user);
  }

  // 更新用户
  Future<bool> updateUser(User user) async {
    final crudService = _crudService;
    if (crudService == null) return false;
    return await crudService.updateUser(user);
  }

  // 删除用户
  Future<bool> deleteUser(int userId) async {
    final crudService = _crudService;
    if (crudService == null) return false;
    return await crudService.deleteUser(userId);
  }

  // 用户登录
  Future<bool> login(String username, String password) async {
    return await UserSessionService.login(username, password, authenticateUser);
  }

  // 用户认证
  Future<User?> authenticateUser(String username, String password) async {
    final service = _authenticationService;
    if (service == null) return null;
    final user = await service.authenticateUser(
      username,
      password,
    );
    if (user != null) {
      _currentUser = user;
    }
    return user;
  }

  Future<User?> _authenticateWithLocalSqliteFallback(
    String username,
    String password,
  ) async {
    try {
      final sqliteDataSource =
          _sqliteDataSource ?? await _loadLocalSqliteDataSource();
      if (sqliteDataSource == null) {
        AppLogger.info('离线认证失败：本地SQLite数据源不可用');
        return null;
      }

      final user = await sqliteDataSource.authenticateUser(username, password);
      if (user != null) {
        _sqliteDataSource = sqliteDataSource;
        _dataSourceType = 'sqlite';
        _currentUser = user;
        AppLogger.info('离线SQLite认证成功，已切换到本地数据源');
      }
      return user;
    } catch (e) {
      AppLogger.info('离线SQLite认证异常: $e');
      return null;
    }
  }

  Future<SqliteUserDataSource?> _loadLocalSqliteDataSource() async {
    try {
      final database = await DatabaseHelper().database;
      _database = database;
      return SqliteUserDataSource(database);
    } catch (e) {
      AppLogger.info('加载本地SQLite数据源失败: $e');
      return null;
    }
  }

  // 用户登出
  void logout() {
    UserSessionService.logout(
      _currentUser,
      clearPermissionsCache,
      notifyListeners,
    );
    _currentUser = null;
  }

  // 搜索用户
  List<User> searchUsers(String query, List<User> users) {
    if (query.isEmpty) return users;

    return users.where((user) {
      return user.username.toLowerCase().contains(query.toLowerCase()) ||
          (user.email?.toLowerCase().contains(query.toLowerCase()) ?? false);
    }).toList();
  }

  // 检查用户名是否存在
  Future<bool> isUsernameExists(String username, {int? excludeId}) async {
    final service = _validationService;
    if (service == null) return false;
    return await service.isUsernameExists(
      username,
      excludeId: excludeId,
    );
  }

  // 检查邮箱是否存在
  Future<bool> isEmailExists(String email, {int? excludeId}) async {
    final service = _validationService;
    if (service == null) return false;
    return await service.isEmailExists(email, excludeId: excludeId);
  }

  // 获取用户统计信息
  Future<Map<String, dynamic>> getUserStatistics() async {
    final service = _statisticsService;
    if (service == null) {
      return {
        'totalUsers': 0,
        'adminCount': 0,
        'doctorCount': 0,
        'userCount': 0,
      };
    }

    return await service.getUserStatistics();
  }

  // ==================== 权限相关方法 ====================

  /// 获取用户权限配置
  Future<Map<String, bool>?> getUserPermissions(int userId) async {
    if (!initialized) {
      AppLogger.info('UserProvider未初始化，无法获取用户权限');
      return null;
    }

    final service = _permissionService;
    if (service == null) return null;

    return await service.getUserPermissions(userId);
  }

  /// 检查用户是否有特定模块的权限
  Future<bool> hasModulePermission(int userId, String module) async {
    final service = _permissionService;
    if (service == null) return false;
    return await service.hasModulePermission(
      userId,
      module,
      getUserById,
    );
  }

  /// 更新用户权限配置
  Future<bool> updateUserPermissions(
    int userId,
    Map<String, bool> permissions,
  ) async {
    if (!initialized) {
      AppLogger.info('UserProvider未初始化，无法更新用户权限');
      return false;
    }

    final service = _permissionService;
    if (service == null) return false;

    return await service.updateUserPermissions(userId, permissions);
  }

  /// 清除权限缓存
  void clearPermissionsCache([int? userId]) {
    _cacheService.clearPermissionsCache(userId);
  }

  /// 加载当前用户权限（登录成功后调用）
  Future<void> loadCurrentUserPermissions() async {
    final service = _currentPermissionService;
    if (service == null) return;
    await service.loadCurrentUserPermissions();
  }

  /// 刷新当前用户权限（强制重新加载）
  Future<void> refreshCurrentUserPermissions() async {
    final service = _currentPermissionService;
    if (service == null) return;
    await service.refreshCurrentUserPermissions();
  }

  /// 检查当前用户是否有特定模块的权限
  Future<bool> hasCurrentUserModulePermission(String module) async {
    final service = _currentPermissionService;
    if (service == null) return false;
    return await service.hasCurrentUserModulePermission(
      module,
    );
  }

  /// 获取当前用户权限配置
  Future<Map<String, bool>?> getCurrentUserPermissions() async {
    final service = _currentPermissionService;
    if (service == null) return null;
    return await service.getCurrentUserPermissions();
  }

  /// 构建医生过滤条件（用于数据访问权限控制）
  String? buildDoctorFilter(User? user) {
    final service = _permissionService;
    if (service == null) return null;
    return service.buildDoctorFilter(user);
  }

  /// Android端不需要数据查看过滤 - 权限控制只在编辑/删除时生效
  bool shouldFilterByDoctor(User? user) {
    final service = _permissionService;
    if (service == null) return false;
    return service.shouldFilterByDoctor(user);
  }

  /// 修复数据库中的无效角色值
  Future<void> fixInvalidRoles() async {
    final service = _dataRepairService;
    if (service == null) return;
    await service.fixInvalidRoles();
  }
}

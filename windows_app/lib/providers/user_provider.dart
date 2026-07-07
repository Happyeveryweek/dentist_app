import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mysql1/mysql1.dart';
import 'package:crypto/crypto.dart';

import '../models/user.dart';
import '../data_sources/user_data_source.dart';
import '../features/users/services/user_sync_service.dart';
import '../features/users/helpers/user_cache_helper.dart';
import '../features/users/services/user_permission_service.dart';
import '../features/users/services/user_data_source_initializer.dart';
import '../utils/log_manager.dart';

/// 用户管理提供者
/// 负责处理所有与用户相关的数据库操作
class UserProvider extends ChangeNotifier {
  // 当前用户信息
  User? _currentUser;

  // 刷新标志
  bool _usersNeedRefresh = false;

  // 缓存管理辅助类
  final UserCacheHelper _cacheHelper = UserCacheHelper();

  // 同步服务（懒加载，??= 返回非空值）
  UserSyncService? _syncServiceInstance;
  UserSyncService get _syncService => _syncServiceInstance ??= UserSyncService(
        getSyncMysqlConnection: () => _syncMysqlConnection,
        getEffectiveDataSourceType: () =>
            _dataSourceInitializerGetter.effectiveDataSourceType,
      );

  // 数据源初始化服务 getter（懒加载）
  UserDataSourceInitializer? _dataSourceInitializer;
  UserDataSourceInitializer get _dataSourceInitializerGetter =>
      _dataSourceInitializer ??= UserDataSourceInitializer();

  // 权限服务 getter（懒加载）
  UserPermissionService? _permissionService;
  UserPermissionService get _permissionServiceGetter =>
      _permissionService ??= UserPermissionService(
        dataSource: _currentDataSource,
        cacheHelper: _cacheHelper,
      );

  // 连接状态
  bool _isConnected = true;
  String? _lastError;

  // Getters
  bool get initialized =>
      _dataSourceInitializerGetter.database != null ||
      _dataSourceInitializerGetter.mysqlConnection != null;
  String get dataSourceType =>
      _dataSourceInitializerGetter.effectiveDataSourceType;
  bool get usersNeedRefresh => _usersNeedRefresh;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;

  // 缓存相关getters
  bool get hasValidCache => _cacheHelper.hasValidCache;
  DateTime? get lastCacheTime => _cacheHelper.lastCacheTime;
  int get cachedUsersCount => _cacheHelper.cachedUsersCount;

  // 获取当前数据源（必须可用，否则抛出异常）
  UserDataSource get _currentDataSource {
    return _dataSourceInitializerGetter.currentDataSource;
  }

  // 获取用于同步的MySQL连接
  MySqlConnection? get _syncMysqlConnection {
    return _dataSourceInitializerGetter.syncMysqlConnection;
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

  // 更新缓存
  void _updateCache(List<User> users) {
    _cacheHelper.updateCache(users);
  }

  // 清除缓存
  void clearCache() {
    _cacheHelper.clearCache();
    _usersNeedRefresh = true; // 标记需要刷新
    // 清除错误状态
    _clearError();

    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 清除权限缓存
  void clearPermissionsCache() {
    _cacheHelper.clearPermissionsCache();

    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 智能初始化（支持模块化配置）

  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
  }) async {
    try {
      await _dataSourceInitializerGetter.initializeFromDatabase(
        dbProvider,
        moduleDataSources: moduleDataSources,
        dataSourceMode: dataSourceMode,
      );

      // 清除缓存，强制重新加载数据
      clearCache();
    } catch (e) {
      LogManager.e('UserProvider', '❌ UserProvider初始化失败', error: e);
      _setError('用户数据源初始化失败: $e');
      rethrow;
    }
  }

  // 构造函数
  UserProvider({
    User? currentUser,
  }) {
    _currentUser = currentUser;
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

  // =================== 用户相关方法 ===================

  // 获取所有用户（使用缓存机制和数据源架构）
  Future<List<User>> getAllUsers({bool forceRefresh = false}) async {
    try {
      // 如果强制刷新或缓存无效，从数据源获取数据
      if (forceRefresh || !_cacheHelper.isCacheValid()) {
        LogManager.w(
            'UserProvider', '${forceRefresh ? "强制刷新" : "缓存失效"}，从数据源获取用户数据');

        // 从数据源获取数据
        final users = await _currentDataSource.getAllUsers();

        // 更新缓存
        _updateCache(users);

        // 重置刷新标志
        _usersNeedRefresh = false;

        return users;
      }

      // 使用缓存数据
      final cached = _cacheHelper.cachedUsers;
      if (cached != null) {
        return List.from(cached);
      }
      return [];
    } catch (e) {
      LogManager.e('UserProvider', '获取用户数据失败', error: e);
      _setError('获取用户数据失败: $e');

      // 如果有缓存数据，返回缓存（优雅降级）
      final cached = _cacheHelper.cachedUsers;
      if (cached != null) {
        LogManager.w('UserProvider',
            '使用缓存数据作为降级方案: ${cached.length} 条记录');
        return List.from(cached);
      }

      return [];
    }
  }

  // 根据ID获取用户（使用数据源架构）
  Future<User?> getUserById(int id) async {
    try {
      return await _currentDataSource.getUserById(id);
    } catch (e) {
      LogManager.e('UserProvider', '根据ID获取用户失败', error: e);
      _setError('获取用户失败: $e');
      return null;
    }
  }

  // 根据用户名获取用户（使用数据源架构）
  Future<User?> getUserByUsername(String username) async {
    try {
      return await _currentDataSource.getUserByUsername(username);
    } catch (e) {
      LogManager.e('UserProvider', '根据用户名获取用户失败', error: e);
      _setError('获取用户失败: $e');
      return null;
    }
  }

  // 用户登录验证（使用数据源架构）
  Future<User?> loginUser(String username, String password) async {
    try {
      // 对密码进行MD5加密
      final bytes = utf8.encode(password);
      final digest = md5.convert(bytes);
      final hashedPassword = digest.toString();

      final user =
          await _currentDataSource.authenticateUser(username, hashedPassword);
      if (user != null) {
        // 设置当前用户并加载权限
        await loadUserPermissions(user);
        LogManager.i('UserProvider', '用户登录成功');
      }
      return user;
    } catch (e) {
      LogManager.e('UserProvider', '用户登录失败', error: e);
      _setError('用户登录失败: $e');
      return null;
    }
  }

  // 用户注册
  Future<bool> registerUser(User user, String password) async {
    if (!initialized) return false;

    try {
      // 检查用户名是否已存在
      final existingUser = await getUserByUsername(user.username);
      if (existingUser != null) {
        return false; // 用户名已存在
      }

      // 对密码进行MD5加密
      final bytes = utf8.encode(password);
      final digest = md5.convert(bytes);
      final hashedPassword = digest.toString();

      final success = await _currentDataSource.registerUser(
        user.username,
        user.email,
        hashedPassword,
        user.role,
      );

      if (success) {
        markUsersNeedRefresh();
        return true;
      }
    } catch (e) {
      LogManager.e('UserProvider', '用户注册失败', error: e);
    }
    return false;
  }

  // 添加用户 - 兼容原有接口（调用新的数据源方法）
  Future<void> addUser(String username, String password, String role,
      {String? email,
      String? doctor,
      String? avatar,
      String? modulePermissions,
      List<int>? imageData}) async {
    try {
      // 使用SHA-256加密密码，与原有代码保持一致
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();

      // 构建User对象
      final user = User(
        username: username,
        password: hashedPassword,
        role: role,
        email: email,
        doctor: doctor,
        avatar: avatar,
        modulePermissions: modulePermissions,
        imageData: imageData,
      );

      // 调用新的数据源方法
      await createUser(user);
    } catch (e) {
      LogManager.e('UserProvider', '添加用户时出错', error: e);
      rethrow;
    }
  }

  // 更新用户信息 - 兼容原有接口（调用新的数据源方法）
  Future<void> updateUser(
      int id, String username, String? password, String role,
      {String? email,
      String? doctor,
      String? avatar,
      String? modulePermissions,
      List<int>? imageData}) async {
    try {
      // 获取现有用户数据以保留未修改的字段
      final existingUser = await getUserById(id);
      if (existingUser == null) {
        throw Exception('用户不存在');
      }

      // 使用SHA-256加密新密码（如果提供）
      String finalPassword = existingUser.password;
      if (password != null && password.isNotEmpty) {
        var bytes = utf8.encode(password);
        var digest = sha256.convert(bytes);
        finalPassword = digest.toString();
      }

      // 构建更新后的User对象
      final updatedUser = existingUser.copyWith(
        username: username,
        password: finalPassword,
        role: role,
        email: email ?? existingUser.email,
        doctor: doctor ?? existingUser.doctor,
        avatar: avatar ?? existingUser.avatar,
        modulePermissions: modulePermissions ?? existingUser.modulePermissions,
        imageData: imageData ?? existingUser.imageData,
      );

      // 调用新的数据源方法
      await updateUserData(updatedUser);
    } catch (e) {
      LogManager.e('UserProvider', '更新用户信息时出错', error: e);
      rethrow;
    }
  }

  // 更新用户密码
  Future<int> updateUserPassword(int userId, String newPassword) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 使用MD5加密密码，确保与登录验证一致
    var bytes = utf8.encode(newPassword);
    var digest = md5.convert(bytes);
    String hashedPassword = digest.toString();

    LogManager.w('UserProvider', '更新用户密码，使用MD5加密: $hashedPassword');

    try {
      final count =
          await _currentDataSource.updateUserPassword(userId, hashedPassword);
      LogManager.i('UserProvider', '更新用户密码成功，影响行数: $count');

      // 清除缓存并标记需要刷新
      clearCache();
      return count;
    } catch (e) {
      LogManager.e('UserProvider', '更新用户密码时出错', error: e);
      throw Exception('更新用户密码失败: $e');
    }
  }

  // 删除用户 - 兼容原有接口（调用新的数据源方法）
  Future<int> deleteUser(int userId) async {
    try {
      final success = await deleteUserData(userId);
      return success ? 1 : 0;
    } catch (e) {
      LogManager.e('UserProvider', '删除用户时出错', error: e);
      throw Exception('删除用户失败: $e');
    }
  }

  // 搜索用户（使用数据源架构）
  Future<List<User>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    try {
      return await _currentDataSource.getPaginatedUsers(
        searchQuery: query,
        pageSize: 100, // 搜索时返回更多结果
        sortBy: 'created_at',
        sortOrder: 'DESC',
      );
    } catch (e) {
      LogManager.e('UserProvider', '搜索用户失败', error: e);
      _setError('搜索用户失败: $e');
      return [];
    }
  }

  // 获取当前用户
  User? get currentUser => _currentUser;

  // 获取当前用户 - 兼容原有接口
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    // 从数据库中获取当前登录用户信息
    return _currentUser;
  }

  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  // 用户登出
  void logoutUser() {
    _currentUser = null;
    notifyListeners();
  }

  // 检查用户权限
  bool hasPermission(String permission) {
    final user = _currentUser;
    if (user == null) return false;

    // 管理员拥有所有权限
    if (user.role == 'admin') return true;

    // 根据角色检查具体权限
    switch (permission) {
      case 'manage_patients':
        return ['admin', 'doctor', 'nurse'].contains(user.role);
      case 'manage_appointments':
        return ['admin', 'doctor', 'nurse', 'receptionist'].contains(user.role);
      case 'manage_financials':
        return ['admin', 'accountant'].contains(user.role);
      case 'manage_materials':
        return ['admin', 'nurse', 'inventory_manager'].contains(user.role);
      case 'manage_users':
        return ['admin'].contains(user.role);
      default:
        return false;
    }
  }

  // 获取用户角色列表
  List<String> getAvailableRoles() {
    return [
      'admin',
      'doctor',
      'nurse',
      'receptionist',
      'accountant',
      'inventory_manager'
    ];
  }

  // 获取角色显示名称
  String getRoleDisplayName(String role) {
    switch (role) {
      case 'admin':
        return '管理员';
      case 'doctor':
        return '医生';
      case 'nurse':
        return '护士';
      case 'receptionist':
        return '前台';
      case 'accountant':
        return '会计';
      case 'inventory_manager':
        return '库存管理员';
      default:
        return role;
    }
  }

  // =================== 新增数据源架构方法 ===================

  // 分页获取用户
  Future<List<User>> getPaginatedUsers({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  }) async {
    try {
      return await _currentDataSource.getPaginatedUsers(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
      );
    } catch (e) {
      LogManager.e('UserProvider', '分页获取用户失败', error: e);
      _setError('分页获取用户失败: $e');
      return [];
    }
  }

  // 获取用户总数
  Future<int> getUsersCount({String? searchQuery}) async {
    try {
      return await _currentDataSource.getUsersCount(searchQuery: searchQuery);
    } catch (e) {
      LogManager.e('UserProvider', '获取用户总数失败', error: e);
      _setError('获取用户总数失败: $e');
      return 0;
    }
  }

  // 获取用户统计信息
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      return await _currentDataSource.getUserStatistics();
    } catch (e) {
      LogManager.e('UserProvider', '获取用户统计信息失败', error: e);
      _setError('获取用户统计信息失败: $e');
      return {
        'totalUsers': 0,
        'roleStatistics': <String, int>{},
      };
    }
  }

  // 创建用户（使用数据源架构）
  Future<int> createUser(User user) async {
    try {
      final id = await _currentDataSource.createUser(user);
      if (id > 0) {
        clearCache(); // 清除缓存

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync) {
          LogManager.i('UserProvider',
              'UserProvider: SQLite用户创建成功，开始同步到MySQL: 用户ID=$id');
          _syncService.syncUserToMySQL(user.copyWith(id: id), isUpdate: false);
        }

        notifyListeners();
      }
      return id;
    } catch (e) {
      LogManager.e('UserProvider', '创建用户失败', error: e);
      _setError('创建用户失败: $e');
      return 0;
    }
  }

  // 更新用户（使用数据源架构）
  Future<bool> updateUserData(User user) async {
    try {
      final success = await _currentDataSource.updateUser(user);
      if (success) {
        clearCache(); // 清除缓存

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync) {
          LogManager.i('UserProvider',
              'UserProvider: SQLite用户更新成功，开始同步到MySQL: 用户ID=${user.id}');
          _syncService.syncUserToMySQL(user, isUpdate: true);
        }

        notifyListeners();
      }
      return success;
    } catch (e) {
      LogManager.e('UserProvider', '更新用户失败', error: e);
      _setError('更新用户失败: $e');
      return false;
    }
  }

  // 删除用户（使用数据源架构）
  Future<bool> deleteUserData(int id) async {
    try {
      final success = await _currentDataSource.deleteUser(id);
      if (success) {
        clearCache(); // 清除缓存

        // 如果当前使用的是SQLite数据源，需要同步到MySQL
        if (_syncService.needsSync) {
          LogManager.i('UserProvider',
              'UserProvider: SQLite用户删除成功，开始同步删除到MySQL: 用户ID=$id');
          _syncService.syncDeleteUserToMySQL(id);
        }

        notifyListeners();
      }
      return success;
    } catch (e) {
      LogManager.e('UserProvider', '删除用户失败', error: e);
      _setError('删除用户失败: $e');
      return false;
    }
  }

  // 模块数据源配置更新（向后兼容）
  void updateModuleDataSources(Map<String, String>? moduleDataSources) {
    _dataSourceInitializerGetter.updateModuleDataSources(moduleDataSources);
  }

  // =================== 权限管理方法 ===================

  // 获取用户权限配置
  Future<Map<String, bool>> getUserPermissions(int userId) async {
    return await _permissionServiceGetter.getUserPermissions(userId);
  }

  // 检查特定模块权限
  Future<bool> hasModulePermission(int userId, String module) async {
    return await _permissionServiceGetter.hasModulePermission(userId, module);
  }

  // 检查当前用户的模块权限
  bool hasCurrentUserModulePermission(String module) {
    final user = _currentUser;
    if (user == null) return false;
    return user.hasModulePermission(module);
  }

  // 更新用户权限配置
  Future<bool> updateUserPermissions(
      int userId, Map<String, bool> permissions) async {
    final success = await _permissionServiceGetter.updateUserPermissions(
        userId, permissions);

    if (success) {
      // 如果是当前用户，重新加载用户信息
      if (_currentUser?.id == userId) {
        final updatedUser = await getUserById(userId);
        if (updatedUser != null) {
          _currentUser = updatedUser;
        }
      }

      notifyListeners();
    }

    return success;
  }

  // 获取当前用户权限
  Map<String, bool> getCurrentUserPermissions() {
    final user = _currentUser;
    if (user == null) {
      return {'dashboard': true};
    }
    return user.permissionMap;
  }

  // 获取当前用户允许的模块列表
  List<String> getCurrentUserAllowedModules() {
    final user = _currentUser;
    if (user == null) {
      return ['dashboard'];
    }
    return user.allowedModules;
  }

  // 加载用户权限（登录时调用）
  Future<void> loadUserPermissions(User user) async {
    try {
      _currentUser = user;

      // 如果不是管理员，预加载权限到缓存
      final userId = user.id;
      if (!user.isAdmin && userId != null) {
        await getUserPermissions(userId);
      }

      notifyListeners();
      LogManager.i('UserProvider', '用户权限加载完成');
    } catch (e) {
      LogManager.e('UserProvider', '加载用户权限失败', error: e);
      _setError('加载用户权限失败: $e');

      // 即使权限加载失败，也要设置用户（使用默认权限）
      _currentUser = user;
      notifyListeners();
    }
  }

  // 刷新当前用户权限（权限变更后调用）
  Future<void> refreshCurrentUserPermissions() async {
    final user = _currentUser;
    if (user == null) {
      LogManager.w('UserProvider', '没有当前用户，无法刷新权限');
      return;
    }

    try {
      // 清除权限缓存
      clearPermissionsCache();

      // 重新加载用户信息（包含最新的权限配置）
      final userId = user.id;
      if (userId != null) {
        final updatedUser = await getUserById(userId);
        if (updatedUser != null) {
          await loadUserPermissions(updatedUser);
          LogManager.i('UserProvider', '当前用户权限刷新成功');
        }
      }
    } catch (e) {
      LogManager.e('UserProvider', '刷新当前用户权限失败', error: e);
      _setError('刷新当前用户权限失败: $e');
    }
  }

  // 确保权限数据在用户会话期间保持有效
  Future<void> ensurePermissionsValid() async {
    await _permissionServiceGetter.ensurePermissionsValid(_currentUser);
  }

  // =================== 数据过滤辅助方法 ===================

  // 构建医生过滤条件
  String buildDoctorFilter(String baseQuery, {String? tableAlias}) {
    try {
      final user = _currentUser;
      // 管理员不需要过滤
      if (user == null || user.isAdmin) {
        return baseQuery;
      }

      // 获取当前用户的医生字段值
      final doctorName = user.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回空结果
        return '$baseQuery AND 1 = 0';
      }

      // 构建过滤条件
      final doctorColumn = tableAlias != null ? '$tableAlias.doctor' : 'doctor';

      // 检查查询是否已包含WHERE子句
      final hasWhere = baseQuery.toUpperCase().contains('WHERE');
      final connector = hasWhere ? ' AND' : ' WHERE';

      return '$baseQuery$connector $doctorColumn = \'$doctorName\'';
    } catch (e) {
      LogManager.e('UserProvider', '构建医生过滤条件失败', error: e);
      // 出错时返回原查询，但添加安全过滤
      return '$baseQuery AND 1 = 0';
    }
  }

  // 判断是否需要数据过滤
  bool shouldFilterByDoctor() {
    final user = _currentUser;
    // 管理员不需要过滤
    if (user == null || user.isAdmin) {
      return false;
    }

    // 有医生字段的用户需要过滤
    return user.doctor?.isNotEmpty ?? false;
  }

  // 获取当前用户的医生过滤值
  String? getCurrentUserDoctorFilter() {
    final user = _currentUser;
    if (user == null || user.isAdmin) {
      return null;
    }

    return user.doctor;
  }

  // 验证权限并处理错误
  Future<bool> validatePermissionAccess(String module) async {
    try {
      final user = _currentUser;
      if (user == null) {
        _setError('用户未登录');
        return false;
      }

      final hasPermission = user.hasModulePermission(module);
      if (!hasPermission) {
        _setError('权限不足：无法访问$module模块');
        return false;
      }

      return true;
    } catch (e) {
      LogManager.e('UserProvider', '权限验证失败', error: e);
      _setError('权限验证失败: $e');
      return false;
    }
  }

  // 权限变更时的缓存清理机制
  void onPermissionChanged(int userId) {
    _permissionServiceGetter.onPermissionChanged(userId, _currentUser);

    // 如果是当前用户，清除所有缓存并重新加载
    if (_currentUser?.id == userId) {
      clearCache();
      clearPermissionsCache();

      // 重新加载当前用户信息
      if (_currentUser != null) {
        refreshCurrentUserPermissions();
      }
    }
  }

  // 初始化权限缓存（登录后调用）
  Future<void> initializePermissionsCache() async {
    await _permissionServiceGetter.initializePermissionsCache(_currentUser);
  }

  // 构建患者关联的医生过滤条件（用于预约、财务等模块）
  String buildPatientDoctorFilter(String baseQuery,
      {String? patientTableAlias, String? joinCondition}) {
    try {
      final user = _currentUser;
      // 管理员不需要过滤
      if (user == null || user.isAdmin) {
        return baseQuery;
      }

      // 获取当前用户的医生字段值
      final doctorName = user.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回空结果
        return '$baseQuery AND 1 = 0';
      }

      // 构建患者表的医生过滤条件
      final patientAlias = patientTableAlias ?? 'p';
      final doctorColumn = '$patientAlias.doctor';

      // 如果需要JOIN患者表
      String filteredQuery = baseQuery;
      if (joinCondition != null &&
          !baseQuery.toUpperCase().contains('JOIN patients')) {
        // 添加患者表JOIN
        filteredQuery =
            '$baseQuery JOIN patients $patientAlias ON $joinCondition';
      }

      // 检查查询是否已包含WHERE子句
      final hasWhere = filteredQuery.toUpperCase().contains('WHERE');
      final connector = hasWhere ? ' AND' : ' WHERE';

      return '$filteredQuery$connector $doctorColumn = \'$doctorName\'';
    } catch (e) {
      LogManager.e('UserProvider', '构建患者医生过滤条件失败', error: e);
      // 出错时返回原查询，但添加安全过滤
      return '$baseQuery AND 1 = 0';
    }
  }
}

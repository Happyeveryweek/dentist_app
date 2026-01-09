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
import '../utils/datetime_formatter.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
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
import '../providers/settings_provider.dart';
import '../utils/pinyin_util.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import '../data_sources/user_data_source.dart';
import '../utils/mysql_sync_connection_helper.dart';

/// 用户管理提供者
/// 负责处理所有与用户相关的数据库操作
class UserProvider extends ChangeNotifier {
  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;
  
  // 数据源类型
  String _dataSourceType = 'sqlite';
  
  // 模块数据源配置
  Map<String, String>? _moduleDataSources;
  
  // 当前用户信息
  User? _currentUser;
  
  // 刷新标志
  bool _usersNeedRefresh = false;
  
  // 缓存机制（类似采购管理）
  List<User>? _cachedUsers;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20); // 用户数据缓存20分钟
  
  // 权限缓存机制
  Map<int, Map<String, bool>>? _cachedPermissions;
  DateTime? _lastPermissionsCacheTime;
  static const Duration _permissionsCacheValidDuration = Duration(minutes: 20); // 权限缓存20分钟
  
  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;
  
  // 数据源具体实现
  SqliteUserDataSource? _sqliteDataSource;
  MySqlUserDataSource? _mysqlDataSource;
  
  // 连接状态
  bool _isConnected = true;
  String? _lastError;
  
  // Getters
  bool get initialized => _database != null || _mysqlConnection != null;
  bool get usersNeedRefresh => _usersNeedRefresh;
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  
  // 缓存相关getters
  bool get hasValidCache => _isCacheValid();
  
  // 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedUsers != null && 
           _lastCacheTime != null &&
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  // 检查权限缓存是否有效
  bool _isPermissionsCacheValid() {
    return _cachedPermissions != null && 
           _lastPermissionsCacheTime != null &&
           DateTime.now().difference(_lastPermissionsCacheTime!) < _permissionsCacheValidDuration;
  }
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedUsersCount => _cachedUsers?.length ?? 0;
  
  // 获取有效的数据源类型（考虑模块化配置）
  String get _effectiveDataSourceType {
    if (_moduleDataSources != null && _moduleDataSources!.containsKey('users')) {
      return _moduleDataSources!['users']!;
    }
    return _dataSourceType;
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqliteUserDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlConnection = connection;
    _mysqlDataSource = MySqlUserDataSource.withConnectionGetter(
      () async {
        final conn = await _currentMysqlConnection;
        return conn;
      },
      reconnectCallback: () async {
        if (_databaseProvider != null) {
          try {
            await _databaseProvider.initializeMySQL();
            print('✅ UserProvider: MySQL重连成功');
          } catch (e) {
            print('❌ UserProvider: MySQL重连失败: $e');
          }
        }
      },
    );
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  UserDataSource get _currentDataSource {
    final effectiveType = _effectiveDataSourceType;
                    if (effectiveType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL用户数据源未初始化 - 模块配置要求使用MySQL但数据源未设置');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite用户数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  // 获取最新的MySQL连接（防止连接过期）
  MySqlConnection? get _currentMysqlConnection {
    if (_effectiveDataSourceType != 'mysql' || _databaseProvider == null) {
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

  // 测试MySQL连接是否有效
  Future<bool> _testMySqlConnection() async {
    if (_currentMysqlConnection == null) return false;
    
    try {
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

  // 更新缓存
  void _updateCache(List<User> users) {
    _cachedUsers = List.from(users);
    _lastCacheTime = DateTime.now();
      }
  
  // 清除缓存
  void clearCache() {
    _cachedUsers = null;
    _lastCacheTime = null;
    _usersNeedRefresh = true; // 标记需要刷新
        // 清除错误状态
    _clearError();
    
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }
  
  // 清除权限缓存
  void clearPermissionsCache() {
    _cachedPermissions = null;
    _lastPermissionsCacheTime = null;
    print('权限缓存已清除');
    
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }
  
  // 更新权限缓存
  void _updatePermissionsCache(int userId, Map<String, bool> permissions) {
    _cachedPermissions ??= {};
    _cachedPermissions![userId] = Map.from(permissions);
    _lastPermissionsCacheTime = DateTime.now();
    print('用户权限缓存已更新: 用户ID $userId, ${permissions.length} 个权限');
  }

  // 智能初始化（支持模块化配置）
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
  }) async {
    try {
      print('🔧 UserProvider.initializeFromDatabase 开始初始化');
      print('🔧 UserProvider - 数据源模式: $dataSourceMode');
      print('🔧 UserProvider - 模块配置: $moduleDataSources');
      print('🔧 UserProvider - 全局数据源类型: ${dbProvider?.dataSourceType}');
      
      // 保存数据库提供者引用
      _databaseProvider = dbProvider;
      
      // 保存模块配置
      _moduleDataSources = moduleDataSources;
      
      // 确定要使用的数据源类型
      String dbType = 'sqlite';
      
      // 如果是模块化模式且有用户模块配置，优先使用模块配置
      if (dataSourceMode == 'modular' && 
          moduleDataSources != null && 
          moduleDataSources.containsKey('users')) {
        dbType = moduleDataSources['users']!;
        print('🔧 UserProvider使用模块化配置: users -> $dbType');
      } else {
        // 否则使用全局配置
        dbType = dbProvider?.dataSourceType ?? 'sqlite';
        print('🔧 UserProvider使用全局配置: $dbType');
      }
      
      // 更新数据源类型
      _dataSourceType = dbType;
      
      // 一次性初始化正确的数据源
      if (dbType == 'sqlite') {
        final database = dbProvider?.database;
        if (database != null) {
          _database = database;
          setSqliteDataSource(database);
                  } else {
          throw Exception('SQLite数据库连接不可用');
        }
      } else if (dbType == 'mysql') {
        final mysqlConnection = dbProvider?.mysqlConnection;
        if (mysqlConnection != null) {
          _mysqlConnection = mysqlConnection;
          setMySqlDataSource(mysqlConnection);
          
          // 测试MySQL连接
          final isConnected = await _testMySqlConnection();
          if (isConnected) {
                      } else {
            print('⚠️ UserProvider MySQL连接测试失败，但继续使用');
          }
        } else {
          throw Exception('MySQL数据库连接不可用');
        }
      }
      
      // 清除缓存，强制重新加载数据
      clearCache();
      
          } catch (e) {
      print('❌ UserProvider初始化失败: $e');
      _setError('用户数据源初始化失败: $e');
      rethrow;
    }
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

    // 兜底：当请求使用 MySQL 但连接未就绪时，自动回退到 SQLite
    if (dataSourceType != null) {
      if (dataSourceType == 'mysql') {
        // 若未提供有效的 MySQL 连接，则回退
        if (_mysqlConnection == null) {
          _dataSourceType = 'sqlite';
        } else {
          _dataSourceType = 'mysql';
        }
      } else {
        _dataSourceType = dataSourceType;
      }
    }

    if (currentUser != null) _currentUser = currentUser;
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
      if (forceRefresh || !_isCacheValid()) {
        print('${forceRefresh ? "强制刷新" : "缓存失效"}，从数据源获取用户数据');
        
        // 从数据源获取数据
        final users = await _currentDataSource.getAllUsers();
        
        // 更新缓存
        _updateCache(users);
        
        // 重置刷新标志
        _usersNeedRefresh = false;
        
                return users;
      }

      // 使用缓存数据
            return List.from(_cachedUsers!);
      
    } catch (e) {
      print('获取用户数据失败: $e');
      _setError('获取用户数据失败: $e');
      
      // 如果有缓存数据，返回缓存（优雅降级）
      if (_cachedUsers != null) {
        print('使用缓存数据作为降级方案: ${_cachedUsers!.length} 条记录');
        return List.from(_cachedUsers!);
      }
      
      return [];
    }
  }
  
  // 根据ID获取用户（使用数据源架构）
  Future<User?> getUserById(int id) async {
    try {
      return await _currentDataSource.getUserById(id);
    } catch (e) {
      print('根据ID获取用户失败: $e');
      _setError('获取用户失败: $e');
      return null;
    }
  }
  
  // 根据用户名获取用户（使用数据源架构）
  Future<User?> getUserByUsername(String username) async {
    try {
      return await _currentDataSource.getUserByUsername(username);
    } catch (e) {
      print('根据用户名获取用户失败: $e');
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
      
      final user = await _currentDataSource.authenticateUser(username, hashedPassword);
      if (user != null) {
        // 设置当前用户并加载权限
        await loadUserPermissions(user);
        print('用户登录成功: ${user.username}');
      }
      return user;
    } catch (e) {
      print('用户登录失败: $e');
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
      
      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return false;
        
        final id = await db.insert('users', {
          'username': user.username,
          'email': user.email ?? '',
          'password': hashedPassword,
          'role': user.role,
          'created_at': DateTimeFormatter.nowDbString(),
        });
        
        if (id > 0) {
          markUsersNeedRefresh();
          return true;
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _mysqlConnection;
        if (conn == null) return false;
        
        final result = await conn.query(
          '''INSERT INTO users (username, email, password, role, created_at) 
             VALUES (?, ?, ?, ?, NOW())''',
          [user.username, user.email ?? '', hashedPassword, user.role],
        );
        
        if (result.insertId != null) {
          markUsersNeedRefresh();
          return true;
        }
      }
    } catch (e) {
      print('用户注册失败: $e');
    }
    return false;
  }

  // 添加用户 - 兼容原有接口（调用新的数据源方法）
  Future<void> addUser(String username, String password, String role,
      {String? email, String? doctor, String? avatar, String? modulePermissions, List<int>? imageData}) async {
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
      print('添加用户时出错: $e');
      rethrow;
    }
  }

  // 更新用户信息 - 兼容原有接口（调用新的数据源方法）
  Future<void> updateUser(
      int id, String username, String? password, String role,
      {String? email, String? doctor, String? avatar, String? modulePermissions, List<int>? imageData}) async {
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
      print('更新用户信息时出错: $e');
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

    print('更新用户密码，使用MD5加密: $hashedPassword');

    if (_dataSourceType == 'sqlite') {
      try {
        // 更新密码
        Map<String, dynamic> passwordMap = {
          'password': hashedPassword,
        };

        int count = await _database!.update(
          'users',
          passwordMap,
          where: 'id = ?',
          whereArgs: [userId],
        );
        print('SQLite更新用户密码成功，影响行数: $count');
        
        // 清除缓存并标记需要刷新
        clearCache();
        print('用户密码更新成功，已清除缓存');
        return count;
      } catch (e) {
        print('更新用户密码时出错: $e');
        throw Exception('更新用户密码失败: $e');
      }
    } else {
      // MySQL更新密码
      try {
        Results results = await _mysqlConnection!.query(
          'UPDATE users SET password = ? WHERE id = ?',
          [hashedPassword, userId],
        );
        print('MySQL更新用户密码成功，影响行数: ${results.affectedRows}');
        
        // 清除缓存并标记需要刷新
        clearCache();
        print('用户密码更新成功，已清除缓存');
        return results.affectedRows ?? 0;
      } catch (e) {
        print('MySQL更新用户密码时出错: $e');
        throw Exception('更新用户密码失败: $e');
      }
    }
  }
  
  // 删除用户 - 兼容原有接口（调用新的数据源方法）
  Future<int> deleteUser(int userId) async {
    try {
      final success = await deleteUserData(userId);
      return success ? 1 : 0;
    } catch (e) {
      print('删除用户时出错: $e');
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
      print('搜索用户失败: $e');
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
    if (_currentUser == null) return false;
    
    // 管理员拥有所有权限
    if (_currentUser!.role == 'admin') return true;
    
    // 根据角色检查具体权限
    switch (permission) {
      case 'manage_patients':
        return ['admin', 'doctor', 'nurse'].contains(_currentUser!.role);
      case 'manage_appointments':
        return ['admin', 'doctor', 'nurse', 'receptionist'].contains(_currentUser!.role);
      case 'manage_financials':
        return ['admin', 'accountant'].contains(_currentUser!.role);
      case 'manage_materials':
        return ['admin', 'nurse', 'inventory_manager'].contains(_currentUser!.role);
      case 'manage_users':
        return ['admin'].contains(_currentUser!.role);
      default:
        return false;
    }
  }
  
  // 获取用户角色列表
  List<String> getAvailableRoles() {
    return ['admin', 'doctor', 'nurse', 'receptionist', 'accountant', 'inventory_manager'];
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
      print('分页获取用户失败: $e');
      _setError('分页获取用户失败: $e');
      return [];
    }
  }
  
  // 获取用户总数
  Future<int> getUsersCount({String? searchQuery}) async {
    try {
      return await _currentDataSource.getUsersCount(searchQuery: searchQuery);
    } catch (e) {
      print('获取用户总数失败: $e');
      _setError('获取用户总数失败: $e');
      return 0;
    }
  }
  
  // 获取用户统计信息
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      return await _currentDataSource.getUserStatistics();
    } catch (e) {
      print('获取用户统计信息失败: $e');
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
        if (_effectiveDataSourceType == 'sqlite') {
          print('UserProvider: SQLite用户创建成功，开始同步到MySQL: 用户ID=$id');
          _trySyncUserToMySQL(user.copyWith(id: id), isUpdate: false);
        }
        
        notifyListeners();
      }
      return id;
    } catch (e) {
      print('创建用户失败: $e');
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
        if (_effectiveDataSourceType == 'sqlite') {
          print('UserProvider: SQLite用户更新成功，开始同步到MySQL: 用户ID=${user.id}');
          _trySyncUserToMySQL(user, isUpdate: true);
        }
        
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('更新用户失败: $e');
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
        if (_effectiveDataSourceType == 'sqlite') {
          print('UserProvider: SQLite用户删除成功，开始同步删除到MySQL: 用户ID=$id');
          _trySyncDeleteUserToMySQL(id);
        }
        
        notifyListeners();
      }
      return success;
    } catch (e) {
      print('删除用户失败: $e');
      _setError('删除用户失败: $e');
      return false;
    }
  }

  // 模块数据源配置更新（向后兼容）
  void updateModuleDataSources(Map<String, String>? moduleDataSources) {
    _moduleDataSources = moduleDataSources;
    print('UserProvider模块数据源配置已更新: $moduleDataSources');
    
    // 如果有模块配置且当前是模块化模式，重新初始化数据源
    if (moduleDataSources != null && 
        moduleDataSources.containsKey('users') && 
        _databaseProvider != null) {
      
      final newDataSourceType = moduleDataSources['users']!;
      if (newDataSourceType != _dataSourceType) {
        print('用户模块数据源类型变更: $_dataSourceType -> $newDataSourceType');
        
        // 重新初始化数据源
        initializeFromDatabase(
          _databaseProvider,
          moduleDataSources: moduleDataSources,
          dataSourceMode: 'modular',
        );
      }
    }
  }

  // =================== 权限管理方法 ===================
  
  // 获取用户权限配置
  Future<Map<String, bool>> getUserPermissions(int userId) async {
    try {
      // 检查缓存
      if (_isPermissionsCacheValid() && _cachedPermissions!.containsKey(userId)) {
        print('权限缓存命中，用户ID: $userId');
        return Map.from(_cachedPermissions![userId]!);
      }
      
      // 从数据源获取权限
      final permissions = await _currentDataSource.getUserPermissions(userId);
      
      // 更新缓存
      _updatePermissionsCache(userId, permissions);
      
      return permissions;
    } catch (e) {
      print('获取用户权限失败: $e');
      _setError('获取用户权限失败: $e');
      
      // 返回默认权限
      return {'dashboard': true};
    }
  }
  
  // 检查特定模块权限
  Future<bool> hasModulePermission(int userId, String module) async {
    try {
      final permissions = await getUserPermissions(userId);
      return permissions[module] == true;
    } catch (e) {
      print('检查模块权限失败: $e');
      // 仪表盘默认允许访问
      return module == 'dashboard';
    }
  }
  
  // 检查当前用户的模块权限
  bool hasCurrentUserModulePermission(String module) {
    if (_currentUser == null) return false;
    return _currentUser!.hasModulePermission(module);
  }
  
  // 更新用户权限配置
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions) async {
    try {
      final success = await _currentDataSource.updateUserPermissions(userId, permissions);
      
      if (success) {
        // 清除权限缓存
        clearPermissionsCache();
        
        // 如果是当前用户，重新加载用户信息
        if (_currentUser?.id == userId) {
          final updatedUser = await getUserById(userId);
          if (updatedUser != null) {
            _currentUser = updatedUser;
          }
        }
        
        notifyListeners();
        print('用户权限更新成功: 用户ID $userId');
      }
      
      return success;
    } catch (e) {
      print('更新用户权限失败: $e');
      _setError('更新用户权限失败: $e');
      return false;
    }
  }
  
  // 获取当前用户权限
  Map<String, bool> getCurrentUserPermissions() {
    if (_currentUser == null) {
      return {'dashboard': true};
    }
    return _currentUser!.permissionMap;
  }
  
  // 获取当前用户允许的模块列表
  List<String> getCurrentUserAllowedModules() {
    if (_currentUser == null) {
      return ['dashboard'];
    }
    return _currentUser!.allowedModules;
  }
  
  // 加载用户权限（登录时调用）
  Future<void> loadUserPermissions(User user) async {
    try {
      _currentUser = user;
      
      // 如果不是管理员，预加载权限到缓存
      if (!user.isAdmin && user.id != null) {
        await getUserPermissions(user.id!);
      }
      
      notifyListeners();
      print('用户权限加载完成: ${user.username}');
    } catch (e) {
      print('加载用户权限失败: $e');
      _setError('加载用户权限失败: $e');
      
      // 即使权限加载失败，也要设置用户（使用默认权限）
      _currentUser = user;
      notifyListeners();
    }
  }
  
  // 刷新当前用户权限（权限变更后调用）
  Future<void> refreshCurrentUserPermissions() async {
    if (_currentUser == null) {
      print('没有当前用户，无法刷新权限');
      return;
    }
    
    try {
      // 清除权限缓存
      clearPermissionsCache();
      
      // 重新加载用户信息（包含最新的权限配置）
      if (_currentUser!.id != null) {
        final updatedUser = await getUserById(_currentUser!.id!);
        if (updatedUser != null) {
          await loadUserPermissions(updatedUser);
          print('当前用户权限刷新成功: ${updatedUser.username}');
        }
      }
    } catch (e) {
      print('刷新当前用户权限失败: $e');
      _setError('刷新用户权限失败: $e');
    }
  }
  
  // 确保权限数据在用户会话期间保持有效
  Future<void> ensurePermissionsValid() async {
    if (_currentUser == null) return;
    
    try {
      // 检查权限缓存是否过期
      if (!_isPermissionsCacheValid() && !_currentUser!.isAdmin && _currentUser!.id != null) {
        print('权限缓存已过期，重新加载权限');
        await getUserPermissions(_currentUser!.id!);
      }
    } catch (e) {
      print('确保权限有效性失败: $e');
      // 不抛出异常，使用现有权限继续运行
    }
  }
  
  // =================== 数据过滤辅助方法 ===================
  
  // 构建医生过滤条件
  String buildDoctorFilter(String baseQuery, {String? tableAlias}) {
    try {
      // 管理员不需要过滤
      if (_currentUser == null || _currentUser!.isAdmin) {
        return baseQuery;
      }
      
      // 获取当前用户的医生字段值
      final doctorName = _currentUser!.doctor;
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
      print('构建医生过滤条件失败: $e');
      // 出错时返回原查询，但添加安全过滤
      return '$baseQuery AND 1 = 0';
    }
  }
  
  // 判断是否需要数据过滤
  bool shouldFilterByDoctor() {
    // 管理员不需要过滤
    if (_currentUser == null || _currentUser!.isAdmin) {
      return false;
    }
    
    // 有医生字段的用户需要过滤
    return _currentUser!.doctor != null && _currentUser!.doctor!.isNotEmpty;
  }
  
  // 获取当前用户的医生过滤值
  String? getCurrentUserDoctorFilter() {
    if (_currentUser == null || _currentUser!.isAdmin) {
      return null;
    }
    
    return _currentUser!.doctor;
  }
  
  // 验证权限并处理错误
  Future<bool> validatePermissionAccess(String module) async {
    try {
      if (_currentUser == null) {
        _setError('用户未登录');
        return false;
      }
      
      final hasPermission = _currentUser!.hasModulePermission(module);
      if (!hasPermission) {
        _setError('权限不足：无法访问$module模块');
        return false;
      }
      
      return true;
    } catch (e) {
      print('权限验证失败: $e');
      _setError('权限验证失败: $e');
      return false;
    }
  }
  
  // 权限变更时的缓存清理机制
  void onPermissionChanged(int userId) {
    try {
      // 清除指定用户的权限缓存
      if (_cachedPermissions != null) {
        _cachedPermissions!.remove(userId);
      }
      
      // 如果是当前用户，清除所有缓存并重新加载
      if (_currentUser?.id == userId) {
        clearCache();
        clearPermissionsCache();
        
        // 重新加载当前用户信息
        if (_currentUser != null) {
          refreshCurrentUserPermissions();
        }
      }
      
      print('权限变更缓存清理完成: 用户ID $userId');
    } catch (e) {
      print('权限变更缓存清理失败: $e');
    }
  }
  
  // 初始化权限缓存（登录后调用）
  Future<void> initializePermissionsCache() async {
    if (_currentUser == null) return;
    
    try {
      // 确保权限数据及时更新
      await ensurePermissionsValid();
      print('权限缓存初始化完成');
    } catch (e) {
      print('权限缓存初始化失败: $e');
    }
  }
  
  // 构建患者关联的医生过滤条件（用于预约、财务等模块）
  String buildPatientDoctorFilter(String baseQuery, {String? patientTableAlias, String? joinCondition}) {
    try {
      // 管理员不需要过滤
      if (_currentUser == null || _currentUser!.isAdmin) {
        return baseQuery;
      }
      
      // 获取当前用户的医生字段值
      final doctorName = _currentUser!.doctor;
      if (doctorName == null || doctorName.isEmpty) {
        // 如果没有医生字段，返回空结果
        return '$baseQuery AND 1 = 0';
      }
      
      // 构建患者表的医生过滤条件
      final patientAlias = patientTableAlias ?? 'p';
      final doctorColumn = '$patientAlias.doctor';
      
      // 如果需要JOIN患者表
      String filteredQuery = baseQuery;
      if (joinCondition != null && !baseQuery.toUpperCase().contains('JOIN patients')) {
        // 添加患者表JOIN
        filteredQuery = '$baseQuery JOIN patients $patientAlias ON $joinCondition';
      }
      
      // 检查查询是否已包含WHERE子句
      final hasWhere = filteredQuery.toUpperCase().contains('WHERE');
      final connector = hasWhere ? ' AND' : ' WHERE';
      
      return '$filteredQuery$connector $doctorColumn = \'$doctorName\'';
    } catch (e) {
      print('构建患者医生过滤条件失败: $e');
      // 出错时返回原查询，但添加安全过滤
      return '$baseQuery AND 1 = 0';
    }
  }

  // =================== MySQL同步方法 ===================
  
  /// 尝试将SQLite中的用户同步到MySQL（非阻塞操作）
  Future<void> _trySyncUserToMySQL(User user, {required bool isUpdate}) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过用户同步(id=${user.id})');
          return;
        }

        // 处理图片数据
        Uint8List? imageBlob;
        if (user.imageData != null && user.imageData!.isNotEmpty) {
          imageBlob = Uint8List.fromList(user.imageData!);
        }

        if (isUpdate) {
          // 更新操作
          try {
            final result = await conn.query('''
              UPDATE users SET
                username = ?, password = ?, role = ?, doctor = ?,
                email = ?, avatar = ?, module_permissions = ?,
                image_data = ?, created_at = ?, updated_at = NOW()
              WHERE id = ?
            ''', [
              user.username,
              user.password,
              user.role,
              user.doctor,
              user.email,
              user.avatar,
              user.modulePermissions,
              imageBlob,
              DateTimeFormatter.toDbString(user.created_at),
              user.id,
            ]);
            print('成功更新MySQL用户(id=${user.id})，影响行数: ${result.affectedRows}');
          } catch (e) {
            print('更新MySQL用户(id=${user.id})时出错: $e');
          }
        } else {
          // 插入操作
          try {
            // 先检查是否已存在
            final existResult = await conn.query(
              'SELECT id FROM users WHERE id = ? LIMIT 1',
              [user.id],
            );

            if (existResult.isNotEmpty) {
              // 已存在，执行更新
              final result = await conn.query('''
                UPDATE users SET
                  username = ?, password = ?, role = ?, doctor = ?,
                  email = ?, avatar = ?, module_permissions = ?,
                  image_data = ?, created_at = ?, updated_at = NOW()
                WHERE id = ?
              ''', [
                user.username,
                user.password,
                user.role,
                user.doctor,
                user.email,
                user.avatar,
                user.modulePermissions,
                imageBlob,
                DateTimeFormatter.toDbString(user.created_at),
                user.id,
              ]);
              print('MySQL中已存在用户，执行更新(id=${user.id})，影响行数: ${result.affectedRows}');
            } else {
              // 不存在，执行插入
              final result = await conn.query('''
                INSERT INTO users 
                (id, username, password, role, doctor, email, avatar, module_permissions, image_data, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
              ''', [
                user.id,
                user.username,
                user.password,
                user.role,
                user.doctor,
                user.email,
                user.avatar,
                user.modulePermissions,
                imageBlob,
                DateTimeFormatter.toDbString(user.created_at),
              ]);
              print('成功插入MySQL用户(id=${user.id})，插入ID: ${result.insertId}');
            }
          } catch (e) {
            print('同步MySQL用户(id=${user.id})时出错: $e');
          }
        }
      } catch (e) {
        print('用户同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除用户（非阻塞操作）
  Future<void> _trySyncDeleteUserToMySQL(int id) async {
    Future.microtask(() async {
      try {
        // 使用专门的同步连接getter，动态获取最新的MySQL连接
        final conn = _syncMysqlConnection;

        if (conn == null) {
          print('MySQL连接不可用，跳过用户删除同步(id=$id)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM users WHERE id = ?',
            [id],
          );
          print('成功从MySQL删除用户(id=$id)，影响行数: ${result.affectedRows}');
        } catch (e) {
          print('从MySQL删除用户(id=$id)时出错: $e');
        }
      } catch (e) {
        print('用户删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }

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

      // 如果没有整体 json 配置，回退到单项配置键（兼容旧版保存方式）
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
          print('从 SharedPreferences 单独键(mysqlHost/mysqlPort/...) 读取 MySQL 配置');
        }
      }

      if (settings != null) {
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

        // 强制使用 utf8mb4 字符集以避免中文/特殊字符乱码
        try {
          await conn.query("SET NAMES 'utf8mb4'");
          await conn.query("SET character_set_connection = 'utf8mb4'");
          await conn.query("SET character_set_results = 'utf8mb4'");
        } catch (e) {
          print('设置MySQL会话字符集失败: $e');
        }

        return conn;
      }
    } catch (e) {
      print('尝试建立MySQL连接失败: $e');
    }
    return null;
  }
}

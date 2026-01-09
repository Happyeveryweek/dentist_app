import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/user.dart';
import '../providers/database_provider.dart';
import '../utils/database_operation_wrapper.dart';
import '../data_sources/user_data_source.dart';
import '../utils/datetime_formatter.dart';

class UserProvider extends ChangeNotifier {
  // 数据库连接
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _dataSourceType = 'sqlite';
  
  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;
  
  // 数据库操作包装器
  DatabaseOperationWrapper? _dbWrapper;
  
  // 数据源具体实现
  SqliteUserDataSource? _sqliteDataSource;
  MySqlUserDataSource? _mysqlDataSource;
  
  // 初始化标志
  bool _isInitializedFlag = false;
  
  // 当前用户信息
  User? _currentUser;
  
  // 缓存数据
  List<User>? _cachedUsers;
  
  // 缓存机制
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 10); // 用户数据缓存10分钟
  
  // 刷新标志
  bool _usersNeedRefresh = false;
  
  // 用户列表缓存
  List<User> _users = [];
  
  // 错误信息
  String? _error;
  
  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;
  
  // 权限相关缓存
  Map<int, Map<String, bool>> _permissionsCache = {};
  Map<int, DateTime> _permissionsCacheTime = {};
  static const Duration _permissionsCacheValidDuration = Duration(minutes: 20); // 权限缓存20分钟

  // Getters
  bool get initialized => _database != null || _currentMysqlConnection != null;
  bool get usersNeedRefresh => _usersNeedRefresh;
  User? get currentUser => _currentUser;
  List<User> get users => _users;
  String? get error => _error;
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
    _sqliteDataSource = SqliteUserDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlUserDataSource.withConnectionGetter(() => _currentMysqlConnection);
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  UserDataSource get _currentDataSource {
    if (_dataSourceType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL用户数据源未初始化');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite用户数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }


  
  // 缓存相关方法
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedUsersCount => _cachedUsers?.length ?? 0;
  
  // 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedUsers != null && 
           _lastCacheTime != null &&
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  // 更新缓存
  void _updateCache(List<User> users) {
    _cachedUsers = List.from(users);
    _lastCacheTime = DateTime.now();
    print('用户数据缓存已更新: ${users.length} 条记录');
  }
  
  // 清除缓存
  void clearCache() {
    _cachedUsers = null;
    _lastCacheTime = null;
    _usersNeedRefresh = true; // 标记需要刷新
    print('用户数据缓存已清除，标记需要刷新');
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

  // 从DatabaseProvider获取数据库连接（保持向后兼容）
  Future<void> initializeFromDatabase(dynamic dbProvider) async {
    if (_isInitializedFlag) return;
    
    try {
      print('UserProvider开始初始化...');
      
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
          print('✅ UserProvider MySQL数据源设置成功');
        } else {
          print('警告：MySQL连接为null，尝试SQLite');
          final database = await dbProvider.sqliteDatabase;
          if (database != null) {
            _database = database;
            _dataSourceType = 'sqlite';
            
            // 创建SQLite数据源
            setSqliteDataSource(database);
            
            _isInitializedFlag = true;
            print('UserProvider 回退到SQLite数据源设置成功');
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
            print('✅ UserProvider SQLite数据源设置成功');
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
      
      print('UserProvider初始化完成');
    } catch (e) {
      print('UserProvider初始化失败: $e');
      // 设置默认值，但不标记为已初始化
      _dataSourceType = 'sqlite';
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
    print('强制刷新用户数据缓存');
    clearCache();
    // 通知监听器
    notifyListeners();
  }

  // 获取所有用户（带缓存）
  Future<List<User>> getAllUsers() async {
    if (!initialized) {
      return _cachedUsers ?? []; // 优雅降级而不是抛出异常
    }
    
    if (_dbWrapper == null) return _cachedUsers ?? [];
    
    return await _dbWrapper!.wrapOperation('getAllUsers', () async {
      try {
        // 优先检查缓存
        if (_isCacheValid()) {
          return _cachedUsers!;
        }
        
        print('🔄 从数据库获取最新用户数据...');
        List<User> users = [];

        // 使用数据源模式（统一接口）
        users = await _currentDataSource.getAllUsers();
        print('✅ 数据源模式查询成功，获取到 ${users.length} 个用户');

        // 更新缓存
        _updateCache(users);
        _users = users;
        _error = null;
        print('✅ 用户数据缓存已更新');
        return users;
      } catch (e) {
        print('❌ 获取用户数据失败: $e');
        
        // 优雅降级：如果有缓存就返回缓存，否则返回空列表
        if (_isCacheValid()) {
          return _cachedUsers!;
        }
        
        _error = '获取用户列表失败: $e';
        return []; // 返回空列表而不是抛出异常
      }
    });
  }

  // 根据ID获取用户
  Future<User?> getUserById(int id) async {
    if (!initialized) {
      return null;
    }

    try {
      User? user;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return null;
        
        final result = await db.rawQuery(
          'SELECT * FROM users WHERE id = ?',
          [id]
        );
        if (result.isNotEmpty) {
          user = User.fromMap(result.first);
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) return null;
        
        final results = await conn.query(
          'SELECT * FROM users WHERE id = ?',
          [id]
        );
        
        if (results.isNotEmpty) {
          final row = results.first;
          final map = <String, dynamic>{};
          for (var field in row.fields.keys) {
            var value = row[field];
            // 直接使用原始值，不进行任何转换
            map[field] = value;
          }
          user = User.fromMap(map);
        }
      }

      return user;
    } catch (e) {
      print('获取用户失败: $e');
      return null;
    }
  }

  // 创建用户
  Future<int> addUser(User user) async {
    if (!initialized) {
      print('UserProvider未初始化，无法创建用户');
      return -1; // 返回-1表示失败而不是抛出异常
    }
    
    if (_dbWrapper == null) return -1;
    
    return await _dbWrapper!.wrapOperation('addUser', () async {
      try {
      // 对密码进行MD5加密，与windows端保持一致
      final bytes = utf8.encode(user.password);
      final digest = md5.convert(bytes);
      final hashedPassword = digest.toString();
      
      print('创建用户 - 用户名: ${user.username}, 原始密码: ${user.password}, 加密后: $hashedPassword');

      int id = 0;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) {
          print('SQLite数据库未初始化，无法创建用户');
          return -1; // 返回-1表示失败而不是抛出异常
        }
        
        // 创建用户数据，使用加密后的密码
        final userData = user.toMap();
        userData['password'] = hashedPassword;
        
        // 处理图片数据 - SQLite支持直接存储Uint8List
        if (userData['image_data'] != null && userData['image_data'] is List<int>) {
          userData['image_data'] = Uint8List.fromList(userData['image_data']);
        }
        
        id = await db.insert('users', userData);
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) {
          print('MySQL连接未初始化，无法创建用户');
          return -1; // 返回-1表示失败而不是抛出异常
        }
        
        // 处理图片数据 - MySQL需要转换为Blob
        dynamic imageBlob;
        if (user.imageData != null && user.imageData!.isNotEmpty) {
          imageBlob = Uint8List.fromList(user.imageData!);
        }
        
        final results = await conn.query(
          '''INSERT INTO users 
             (username, email, password, role, created_at, doctor, avatar, image_data)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            user.username,
            user.email,
            hashedPassword, // 使用加密后的密码
            user.role,
            DateTimeFormatter.toDbString(user.created_at),
            user.doctor,
            user.avatar,
            imageBlob,
          ]
        );
        id = results.insertId ?? 0;
      }

      if (id > 0) {
        print('用户创建成功，ID: $id');
        // 清除缓存并标记需要刷新
        clearCache();
        markUsersNeedRefresh();
      }

      return id;
      } catch (e) {
        print('创建用户失败: $e');
        return -1; // 返回-1表示失败而不是重新抛出异常
      }
    });
  }

  // 更新用户
  Future<bool> updateUser(User user) async {
    if (!initialized) {
      print('UserProvider未初始化，无法更新用户');
      return false; // 返回false表示失败而不是抛出异常
    }
    
    if (_dbWrapper == null) return false;
    
    return await _dbWrapper!.wrapOperation('updateUser', () async {
      try {
      // 对密码进行MD5加密，与windows端保持一致
      final bytes = utf8.encode(user.password);
      final digest = md5.convert(bytes);
      final hashedPassword = digest.toString();
      
      print('更新用户 - 用户名: ${user.username}, 原始密码: ${user.password}, 加密后: $hashedPassword');

      bool success = false;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) {
          print('SQLite数据库未初始化，无法更新用户');
          return false; // 返回false表示失败而不是抛出异常
        }
        
        // 创建更新数据，使用加密后的密码
        final updateData = user.toMap();
        updateData['password'] = hashedPassword;
        
        // 处理图片数据 - SQLite支持直接存储Uint8List
        if (updateData['image_data'] != null && updateData['image_data'] is List<int>) {
          updateData['image_data'] = Uint8List.fromList(updateData['image_data']);
        }
        
        final count = await db.update(
          'users', 
          updateData, 
          where: 'id = ?', 
          whereArgs: [user.id]
        );
        success = count > 0;
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) {
          print('MySQL连接未初始化，无法更新用户');
          return false; // 返回false表示失败而不是抛出异常
        }
        
        // 处理图片数据 - MySQL需要转换为Blob
        dynamic imageBlob;
        if (user.imageData != null && user.imageData!.isNotEmpty) {
          imageBlob = Uint8List.fromList(user.imageData!);
        }
        
        final results = await conn.query(
          '''UPDATE users SET 
             username = ?, email = ?, password = ?, role = ?, 
             doctor = ?, avatar = ?, image_data = ?
             WHERE id = ?''',
          [
            user.username,
            user.email,
            hashedPassword, // 使用加密后的密码
            user.role,
            user.doctor,
            user.avatar,
            imageBlob,
            user.id,
          ]
        );
        success = results.affectedRows != null && results.affectedRows! > 0;
      }
      
      if (success) {
        print('用户更新成功');
        // 清除缓存并标记需要刷新
        clearCache();
        markUsersNeedRefresh();
        return true;
      }
      return false;
      } catch (e) {
        _error = '更新用户失败: $e';
        notifyListeners();
        return false;
      }
    });
  }

  // 删除用户
  Future<bool> deleteUser(int userId) async {
    if (!initialized) {
      print('UserProvider未初始化，无法删除用户');
      return false;
    }

    try {
      bool success = false;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) {
          print('SQLite数据库未初始化，无法删除用户');
          return false;
        }
        
        // 检查数据库是否仍然可用
        if (!db.isOpen) {
          print('SQLite数据库连接已关闭，无法删除用户');
          return false;
        }
        
        // 直接删除用户记录，因为表中没有is_active字段
        final count = await db.delete(
          'users', 
          where: 'id = ?', 
          whereArgs: [userId]
        );
        success = count > 0;
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) {
          print('MySQL连接未初始化，无法删除用户');
          return false;
        }
        
        // 检查MySQL连接是否仍然有效
        try {
          // 尝试执行一个简单的查询来测试连接
          await conn.query('SELECT 1');
        } catch (e) {
          print('MySQL连接已断开，尝试重新连接...');
          // 这里可以尝试重新连接，但为了简单起见，我们返回失败
          return false;
        }
        
        // 直接删除用户记录，因为表中没有is_active字段
        final results = await conn.query(
          'DELETE FROM users WHERE id = ?',
          [userId]
        );
        success = results.affectedRows != null && results.affectedRows! > 0;
      }
      
      if (success) {
        print('用户删除成功');
        // 清除缓存并标记需要刷新
        clearCache();
        markUsersNeedRefresh();
        return true;
      }
      return false;
    } catch (e) {
      _error = '删除用户失败: $e';
      print('删除用户失败: $e');
      notifyListeners();
      return false;
    }
  }

  // 用户登录
  Future<bool> login(String username, String password) async {
    print('开始用户登录 - 用户名: $username');
    
    try {
      final user = await authenticateUser(username, password);
      if (user != null) {
        print('登录成功，用户: ${user.username}');
        _currentUser = user;
        notifyListeners();
        return true;
      } else {
        print('登录失败，用户认证返回null');
        return false;
      }
    } catch (e) {
      print('登录失败: $e');
      return false;
    }
  }

  // 用户认证
  Future<User?> authenticateUser(String username, String password) async {
    if (!initialized) {
      print('UserProvider未初始化，无法进行用户认证');
      return null;
    }

    if (_dbWrapper == null) return null;
    
    return await _dbWrapper!.wrapOperation('authenticateUser', () async {
      try {
        print('用户认证 - 用户名: $username, 原始密码: $password');
        print('用户认证 - 当前数据源类型: $_dataSourceType');
        print('用户认证 - MySQL连接状态: ${_mysqlConnection != null}');
        print('用户认证 - SQLite数据库状态: ${_database != null}');

        // 使用数据源模式（统一接口）
        final user = await _currentDataSource.authenticateUser(username, password);

        if (user != null) {
          print('用户认证成功: ${user.username}');
          _currentUser = user;
          
          // 登录成功后自动加载用户权限
          try {
            await loadCurrentUserPermissions();
            print('用户权限加载成功: ${user.username}');
          } catch (e) {
            print('用户权限加载失败: $e');
            // 权限加载失败不影响登录，但记录错误
          }
          
          notifyListeners();
        } else {
          print('用户认证失败: 用户名或密码错误');
        }

        return user;
      } catch (e) {
        print('用户认证失败: $e');
        return null;
      }
    });
  }

  // 用户登出
  void logout() {
    // 清除当前用户权限缓存
    if (_currentUser != null && _currentUser!.id != null) {
      clearPermissionsCache(_currentUser!.id!);
    }
    
    _currentUser = null;
    notifyListeners();
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
    if (!initialized) {
      return false;
    }

    try {
      bool exists = false;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return false;
        
        final result = await db.rawQuery(
          excludeId != null 
            ? 'SELECT 1 FROM users WHERE username = ? AND id != ?'
            : 'SELECT 1 FROM users WHERE username = ?',
          excludeId != null ? [username, excludeId] : [username]
        );
        exists = result.isNotEmpty;
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) return false;
        
        final results = await conn.query(
          excludeId != null 
            ? 'SELECT 1 FROM users WHERE username = ? AND id != ?'
            : 'SELECT 1 FROM users WHERE username = ?',
          excludeId != null ? [username, excludeId] : [username]
        );
        exists = results.isNotEmpty;
      }

      return exists;
    } catch (e) {
      print('检查用户名是否存在失败: $e');
      return false;
    }
  }

  // 检查邮箱是否存在
  Future<bool> isEmailExists(String email, {int? excludeId}) async {
    if (!initialized || email.isEmpty) {
      return false;
    }

    try {
      bool exists = false;

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return false;
        
        final result = await db.rawQuery(
          excludeId != null 
            ? 'SELECT 1 FROM users WHERE email = ? AND id != ?'
            : 'SELECT 1 FROM users WHERE email = ?',
          excludeId != null ? [email, excludeId] : [email]
        );
        exists = result.isNotEmpty;
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) return false;
        
        final results = await conn.query(
          excludeId != null 
            ? 'SELECT 1 FROM users WHERE email = ? AND id != ?'
            : 'SELECT 1 FROM users WHERE email = ?',
          excludeId != null ? [email, excludeId] : [email]
        );
        exists = results.isNotEmpty;
      }

      return exists;
    } catch (e) {
      print('检查邮箱是否存在失败: $e');
      return false;
    }
  }

  // 获取用户统计信息
  Future<Map<String, dynamic>> getUserStatistics() async {
    if (!initialized) {
      return {
        'totalUsers': 0,
        'adminCount': 0,
        'doctorCount': 0,
        'userCount': 0,
      };
    }

    try {
      Map<String, dynamic> stats = {
        'totalUsers': 0,
        'adminCount': 0,
        'doctorCount': 0,
        'userCount': 0,
      };

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return stats;
        
        // 检查数据库是否仍然可用
        if (!db.isOpen) {
          print('SQLite数据库连接已关闭，返回默认统计信息');
          return stats;
        }
        
        final result = await db.rawQuery('''
          SELECT 
            COUNT(*) as total_users,
            COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count,
            COUNT(CASE WHEN role = 'doctor' THEN 1 END) as doctor_count,
            COUNT(CASE WHEN role = 'user' THEN 1 END) as user_count
          FROM users
        ''');
        
        if (result.isNotEmpty) {
          stats['totalUsers'] = result.first['total_users'] ?? 0;
          stats['adminCount'] = result.first['admin_count'] ?? 0;
          stats['doctorCount'] = result.first['doctor_count'] ?? 0;
          stats['userCount'] = result.first['user_count'] ?? 0;
        }
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) return stats;
        
        // 检查MySQL连接是否仍然有效
        try {
          // 尝试执行一个简单的查询来测试连接
          await conn.query('SELECT 1');
        } catch (e) {
          print('MySQL连接已断开，返回默认统计信息');
          return stats;
        }
        
        final results = await conn.query('''
          SELECT 
            COUNT(*) as total_users,
            COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count,
            COUNT(CASE WHEN role = 'doctor' THEN 1 END) as doctor_count,
            COUNT(CASE WHEN role = 'user' THEN 1 END) as user_count
          FROM users
        ''');
        
        if (results.isNotEmpty) {
          final row = results.first;
          stats['totalUsers'] = row['total_users'] ?? 0;
          stats['adminCount'] = row['admin_count'] ?? 0;
          stats['doctorCount'] = row['doctor_count'] ?? 0;
          stats['userCount'] = row['user_count'] ?? 0;
        }
      }

      return stats;
    } catch (e) {
      print('获取用户统计信息失败: $e');
      return {
        'totalUsers': 0,
        'adminCount': 0,
        'doctorCount': 0,
        'userCount': 0,
      };
    }
  }

  // ==================== 权限相关方法 ====================
  
  /// 获取用户权限配置
  Future<Map<String, bool>?> getUserPermissions(int userId) async {
    if (!initialized) {
      print('UserProvider未初始化，无法获取用户权限');
      return null;
    }
    
    // 检查缓存
    if (_isPermissionsCacheValid(userId)) {
      print('使用缓存的权限数据，用户ID: $userId');
      return _permissionsCache[userId];
    }
    
    if (_dbWrapper == null) return null;
    
    return await _dbWrapper!.wrapOperation('getUserPermissions', () async {
      try {
        final permissions = await _currentDataSource.getUserPermissions(userId);
        
        if (permissions != null) {
          // 更新缓存
          _permissionsCache[userId] = permissions;
          _permissionsCacheTime[userId] = DateTime.now();
          print('权限数据已缓存，用户ID: $userId');
        }
        
        return permissions;
      } catch (e) {
        print('获取用户权限失败: $e');
        return null;
      }
    });
  }
  
  /// 检查用户是否有特定模块的权限
  Future<bool> hasModulePermission(int userId, String module) async {
    // 管理员拥有所有权限
    final user = await getUserById(userId);
    if (user?.role == 'admin') {
      return true;
    }
    
    // 仪表盘对所有用户可见
    if (module == 'dashboard') {
      return true;
    }
    
    final permissions = await getUserPermissions(userId);
    if (permissions == null) {
      return false; // 如果没有权限配置，默认无权限
    }
    
    return permissions[module] == true;
  }
  
  /// 更新用户权限配置
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions) async {
    if (!initialized) {
      print('UserProvider未初始化，无法更新用户权限');
      return false;
    }
    
    if (_dbWrapper == null) return false;
    
    return await _dbWrapper!.wrapOperation('updateUserPermissions', () async {
      try {
        final success = await _currentDataSource.updateUserPermissions(userId, permissions);
        
        if (success) {
          // 清除该用户的权限缓存
          _permissionsCache.remove(userId);
          _permissionsCacheTime.remove(userId);
          print('用户权限更新成功，已清除缓存，用户ID: $userId');
        }
        
        return success;
      } catch (e) {
        print('更新用户权限失败: $e');
        return false;
      }
    });
  }
  
  /// 检查权限缓存是否有效
  bool _isPermissionsCacheValid(int userId) {
    final cacheTime = _permissionsCacheTime[userId];
    if (cacheTime == null || !_permissionsCache.containsKey(userId)) {
      return false;
    }
    
    return DateTime.now().difference(cacheTime) < _permissionsCacheValidDuration;
  }
  
  /// 清除权限缓存
  void clearPermissionsCache([int? userId]) {
    if (userId != null) {
      _permissionsCache.remove(userId);
      _permissionsCacheTime.remove(userId);
      print('已清除用户权限缓存，用户ID: $userId');
    } else {
      _permissionsCache.clear();
      _permissionsCacheTime.clear();
      print('已清除所有用户权限缓存');
    }
  }
  
  /// 加载当前用户权限（登录成功后调用）
  Future<void> loadCurrentUserPermissions() async {
    if (_currentUser == null || _currentUser!.id == null) {
      print('当前用户为空或ID无效，无法加载权限');
      return;
    }
    
    try {
      // 预加载当前用户的权限到缓存中
      final permissions = await getUserPermissions(_currentUser!.id!);
      if (permissions != null) {
        print('当前用户权限加载成功，用户ID: ${_currentUser!.id}');
        print('权限配置: $permissions');
      } else {
        print('当前用户无权限配置，用户ID: ${_currentUser!.id}');
      }
    } catch (e) {
      print('加载当前用户权限失败: $e');
      // 重新抛出异常，让调用者处理
      rethrow;
    }
  }
  
  /// 刷新当前用户权限（强制重新加载）
  Future<void> refreshCurrentUserPermissions() async {
    if (_currentUser == null || _currentUser!.id == null) {
      print('当前用户为空或ID无效，无法刷新权限');
      return;
    }
    
    try {
      // 清除当前用户的权限缓存
      clearPermissionsCache(_currentUser!.id!);
      
      // 重新加载权限
      await loadCurrentUserPermissions();
      
      print('当前用户权限刷新成功，用户ID: ${_currentUser!.id}');
    } catch (e) {
      print('刷新当前用户权限失败: $e');
      rethrow;
    }
  }
  
  /// 检查当前用户是否有特定模块的权限
  Future<bool> hasCurrentUserModulePermission(String module) async {
    if (_currentUser == null || _currentUser!.id == null) {
      print('当前用户为空或ID无效，无法检查权限');
      return false;
    }
    
    return await hasModulePermission(_currentUser!.id!, module);
  }
  
  /// 获取当前用户权限配置
  Future<Map<String, bool>?> getCurrentUserPermissions() async {
    if (_currentUser == null || _currentUser!.id == null) {
      print('当前用户为空或ID无效，无法获取权限');
      return null;
    }
    
    return await getUserPermissions(_currentUser!.id!);
  }
  
  /// 构建医生过滤条件（用于数据访问权限控制）
  String? buildDoctorFilter(User? user) {
    if (user == null) return null;
    
    // 管理员不受数据过滤限制
    if (user.role == 'admin') {
      return null;
    }
    
    // 普通用户只能查看自己医生字段匹配的数据
    if (user.doctor != null && user.doctor!.isNotEmpty) {
      return user.doctor!;
    }
    
    return null;
  }
  
  /// Android端不需要数据查看过滤 - 权限控制只在编辑/删除时生效
  bool shouldFilterByDoctor(User? user) {
    // Android端：所有用户都能查看所有数据，权限控制只在操作时生效
    return false;
  }

  /// 修复数据库中的无效角色值
  Future<void> fixInvalidRoles() async {
    try {
      print('开始修复数据库中的无效角色值...');
      
      if (_dataSourceType == 'mysql') {
        // MySQL修复
        if (_currentMysqlConnection != null) {
          // 检查MySQL连接是否仍然有效
          try {
            await _currentMysqlConnection!.query('SELECT 1');
          } catch (e) {
            print('MySQL连接已断开，跳过角色修复');
            return;
          }
          
          // 将assistant角色更新为doctor角色
          await _currentMysqlConnection!.query('''
            UPDATE users 
            SET role = 'doctor' 
            WHERE role = 'assistant'
          ''');
          print('MySQL数据库角色修复完成');
        }
      } else {
        // SQLite修复
        final db = _database;
        if (db != null) {
          // 检查数据库是否仍然可用
          if (!db.isOpen) {
            print('SQLite数据库连接已关闭，跳过角色修复');
            return;
          }
          
          // 将assistant角色更新为doctor角色
          await db.update(
            'users',
            {'role': 'doctor'},
            where: 'role = ?',
            whereArgs: ['assistant'],
          );
          print('SQLite数据库角色修复完成');
        }
      }
      
      // 刷新用户列表
      await getAllUsers();
    } catch (e) {
      print('修复角色值失败: $e');
    }
  }
}

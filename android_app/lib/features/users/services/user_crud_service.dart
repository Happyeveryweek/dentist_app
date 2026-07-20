import 'package:flutter/foundation.dart';
import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

import '../../../data_sources/user_data_source.dart';
import '../../../models/user.dart';
import '../../../utils/database_operation_wrapper.dart';
import '../../../utils/datetime_formatter.dart';
import 'user_cache_service.dart';
import '../../../utils/app_logger.dart';
import 'password_service.dart';
import 'user_permission_service.dart';

/// 用户增删改查服务
class UserCrudService {
  final bool Function() _isInitialized;
  final DatabaseOperationWrapper? _dbWrapper;
  final UserDataSource Function() _currentDataSource;
  final Database? Function() _sqliteDatabase;
  final MySqlConnection? Function() _mysqlConnection;
  final String Function() _dataSourceType;
  final UserCacheService _cacheService;
  final void Function(List<User>) _setUsers;
  final void Function(String?) _setError;
  final VoidCallback _clearCache;
  final VoidCallback _markUsersNeedRefresh;
  final PasswordService _passwordService;
  final User? Function() _currentUser;

  UserCrudService({
    required bool Function() isInitialized,
    required DatabaseOperationWrapper? dbWrapper,
    required UserDataSource Function() currentDataSource,
    required Database? Function() sqliteDatabase,
    required MySqlConnection? Function() mysqlConnection,
    required String Function() dataSourceType,
    required UserCacheService cacheService,
    required void Function(List<User>) setUsers,
    required void Function(String?) setError,
    required VoidCallback clearCache,
    required VoidCallback markUsersNeedRefresh,
    PasswordService? passwordService,
    required User? Function() currentUser,
  }) : _isInitialized = isInitialized,
       _dbWrapper = dbWrapper,
       _currentDataSource = currentDataSource,
       _sqliteDatabase = sqliteDatabase,
       _mysqlConnection = mysqlConnection,
       _dataSourceType = dataSourceType,
       _cacheService = cacheService,
       _setUsers = setUsers,
       _setError = setError,
       _clearCache = clearCache,
       _markUsersNeedRefresh = markUsersNeedRefresh,
       _passwordService = passwordService ?? PasswordService(),
       _currentUser = currentUser;

  bool get _canManageUsers =>
      UserPermissionService.canManageUsers(_currentUser());

  Future<List<User>> getAllUsers() async {
    if (!_canManageUsers) return [];
    if (!_isInitialized()) {
      return _cacheService.getCachedUsers() ?? [];
    }

    if (_dbWrapper == null) return _cacheService.getCachedUsers() ?? [];

    final dbWrapper = _dbWrapper;

    return await dbWrapper.wrapOperation('getAllUsers', () async {
      try {
        final cachedUsers = _cacheService.getCachedUsers();
        if (cachedUsers != null) {
          return cachedUsers;
        }

        AppLogger.info('🔄 从数据库获取最新用户数据...');
        final users = await _currentDataSource().getAllUsers();

        _cacheService.updateCache(users);
        _setUsers(users);
        _setError(null);
        return users;
      } catch (e) {
        AppLogger.info('❌ 获取用户数据失败: $e');

        final cachedUsers = _cacheService.getCachedUsers();
        if (cachedUsers != null) {
          return cachedUsers;
        }

        _setError('获取用户列表失败: $e');
        return [];
      }
    });
  }

  Future<User?> getUserById(int id) async {
    if (!_canManageUsers) return null;
    if (!_isInitialized()) {
      return null;
    }

    try {
      if (_dataSourceType() == 'sqlite') {
        final db = _sqliteDatabase();
        if (db == null) return null;

        final result = await db.rawQuery('SELECT * FROM users WHERE id = ?', [
          id,
        ]);
        if (result.isNotEmpty) {
          return User.fromMap(result.first);
        }
      } else if (_dataSourceType() == 'mysql') {
        final conn = _mysqlConnection();
        if (conn == null) return null;

        final results = await conn.query('SELECT * FROM users WHERE id = ?', [
          id,
        ]);
        if (results.isNotEmpty) {
          final row = results.first;
          final map = <String, dynamic>{};
          for (var field in row.fields.keys) {
            map[field] = row[field];
          }
          return User.fromMap(map);
        }
      }

      return null;
    } catch (e) {
      AppLogger.info('获取用户失败: $e');
      return null;
    }
  }

  Future<int> addUser(User user) async {
    if (!_canManageUsers) return -1;
    if (!_isInitialized()) {
      AppLogger.info('UserProvider未初始化，无法创建用户');
      return -1;
    }

    final dbWrapper = _dbWrapper;
    if (dbWrapper == null) return -1;

    return await dbWrapper.wrapOperation('addUser', () async {
      try {
        final hashedPassword = _passwordService.hashPassword(user.password);

        int id = 0;

        if (_dataSourceType() == 'sqlite') {
          final db = _sqliteDatabase();
          if (db == null) {
            AppLogger.info('SQLite数据库未初始化，无法创建用户');
            return -1;
          }

          final userData = user.toMap();
          userData['password'] = hashedPassword;

          if (userData['image_data'] != null &&
              userData['image_data'] is List<int>) {
            userData['image_data'] = Uint8List.fromList(userData['image_data']);
          }

          id = await db.insert('users', userData);
        } else if (_dataSourceType() == 'mysql') {
          final conn = _mysqlConnection();
          if (conn == null) {
            AppLogger.info('MySQL连接未初始化，无法创建用户');
            return -1;
          }

          final imageData = user.imageData;
          dynamic imageBlob;
          if (imageData != null && imageData.isNotEmpty) {
            imageBlob = Uint8List.fromList(imageData);
          }

          final results = await conn.query(
            '''INSERT INTO users 
               (username, email, password, role, created_at, doctor, avatar, image_data)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
            [
              user.username,
              user.email,
              hashedPassword,
              user.role,
              DateTimeFormatter.toDbString(user.createdAt),
              user.doctor,
              user.avatar,
              imageBlob,
            ],
          );
          id = results.insertId ?? 0;
        }

        if (id > 0) {
          AppLogger.info('用户创建成功，ID: $id');
          _clearCache();
          _markUsersNeedRefresh();
        }

        return id;
      } catch (e) {
        AppLogger.info('创建用户失败: $e');
        return -1;
      }
    });
  }

  Future<bool> updateUser(User user) async {
    if (!_canManageUsers) return false;
    if (!_isInitialized()) {
      AppLogger.info('UserProvider未初始化，无法更新用户');
      return false;
    }

    final dbWrapper = _dbWrapper;
    if (dbWrapper == null) return false;

    return await dbWrapper.wrapOperation('updateUser', () async {
      try {
        bool success = false;

        if (_dataSourceType() == 'sqlite') {
          final db = _sqliteDatabase();
          if (db == null) {
            AppLogger.info('SQLite数据库未初始化，无法更新用户');
            return false;
          }

          final updateData = user.toMap();
          if (user.password.isEmpty) {
            updateData.remove('password');
          } else {
            updateData['password'] = _passwordService.hashPassword(
              user.password,
            );
          }

          if (updateData['image_data'] != null &&
              updateData['image_data'] is List<int>) {
            updateData['image_data'] = Uint8List.fromList(
              updateData['image_data'],
            );
          }

          final count = await db.update(
            'users',
            updateData,
            where: 'id = ?',
            whereArgs: [user.id],
          );
          success = count > 0;
        } else if (_dataSourceType() == 'mysql') {
          final conn = _mysqlConnection();
          if (conn == null) {
            AppLogger.info('MySQL连接未初始化，无法更新用户');
            return false;
          }

          final updateImageData = user.imageData;
          dynamic imageBlob;
          if (updateImageData != null && updateImageData.isNotEmpty) {
            imageBlob = Uint8List.fromList(updateImageData);
          }

          final passwordClause = user.password.isEmpty ? '' : ', password = ?';
          final values = <dynamic>[
            user.username,
            user.email,
            user.role,
            user.doctor,
            user.avatar,
            imageBlob,
            if (user.password.isNotEmpty)
              _passwordService.hashPassword(user.password),
            user.id,
          ];
          final results = await conn.query('''UPDATE users SET
               username = ?, email = ?, role = ?, doctor = ?, avatar = ?, image_data = ?$passwordClause
               WHERE id = ?''', values);
          success = (results.affectedRows ?? 0) > 0;
        }

        if (success) {
          AppLogger.info('用户更新成功');
          _clearCache();
          _markUsersNeedRefresh();
          return true;
        }
        return false;
      } catch (e) {
        _setError('更新用户失败: $e');
        return false;
      }
    });
  }

  Future<bool> deleteUser(int userId) async {
    if (!_canManageUsers) return false;
    if (!_isInitialized()) {
      AppLogger.info('UserProvider未初始化，无法删除用户');
      return false;
    }

    try {
      bool success = false;

      if (_dataSourceType() == 'sqlite') {
        final db = _sqliteDatabase();
        if (db == null) {
          AppLogger.info('SQLite数据库未初始化，无法删除用户');
          return false;
        }

        if (!db.isOpen) {
          AppLogger.info('SQLite数据库连接已关闭，无法删除用户');
          return false;
        }

        final count = await db.delete(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );
        success = count > 0;
      } else if (_dataSourceType() == 'mysql') {
        final conn = _mysqlConnection();
        if (conn == null) {
          AppLogger.info('MySQL连接未初始化，无法删除用户');
          return false;
        }

        try {
          await conn.query('SELECT 1');
        } catch (e) {
          AppLogger.info('MySQL连接已断开，尝试重新连接...');
          return false;
        }

        final results = await conn.query('DELETE FROM users WHERE id = ?', [
          userId,
        ]);
        success = (results.affectedRows ?? 0) > 0;
      }

      if (success) {
        AppLogger.info('用户删除成功');
        _clearCache();
        _markUsersNeedRefresh();
        return true;
      }
      return false;
    } catch (e) {
      _setError('删除用户失败: $e');
      AppLogger.info('删除用户失败: $e');
      return false;
    }
  }
}

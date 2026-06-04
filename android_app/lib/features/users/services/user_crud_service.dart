import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

import '../../../data_sources/user_data_source.dart';
import '../../../models/user.dart';
import '../../../utils/database_operation_wrapper.dart';
import '../../../utils/datetime_formatter.dart';
import 'user_cache_service.dart';

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
  })  : _isInitialized = isInitialized,
        _dbWrapper = dbWrapper,
        _currentDataSource = currentDataSource,
        _sqliteDatabase = sqliteDatabase,
        _mysqlConnection = mysqlConnection,
        _dataSourceType = dataSourceType,
        _cacheService = cacheService,
        _setUsers = setUsers,
        _setError = setError,
        _clearCache = clearCache,
        _markUsersNeedRefresh = markUsersNeedRefresh;

  Future<List<User>> getAllUsers() async {
    if (!_isInitialized()) {
      return _cacheService.getCachedUsers() ?? [];
    }

    if (_dbWrapper == null) return _cacheService.getCachedUsers() ?? [];

    final dbWrapper = _dbWrapper;
    if (dbWrapper == null) return _cacheService.getCachedUsers() ?? [];

    return await dbWrapper.wrapOperation('getAllUsers', () async {
      try {
        final cachedUsers = _cacheService.getCachedUsers();
        if (cachedUsers != null) {
          return cachedUsers;
        }

        print('🔄 从数据库获取最新用户数据...');
        final users = await _currentDataSource().getAllUsers();

        _cacheService.updateCache(users);
        _setUsers(users);
        _setError(null);
        return users;
      } catch (e) {
        print('❌ 获取用户数据失败: $e');

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
    if (!_isInitialized()) {
      return null;
    }

    try {
      if (_dataSourceType() == 'sqlite') {
        final db = _sqliteDatabase();
        if (db == null) return null;

        final result = await db.rawQuery('SELECT * FROM users WHERE id = ?', [id]);
        if (result.isNotEmpty) {
          return User.fromMap(result.first);
        }
      } else if (_dataSourceType() == 'mysql') {
        final conn = _mysqlConnection();
        if (conn == null) return null;

        final results = await conn.query('SELECT * FROM users WHERE id = ?', [id]);
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
      print('获取用户失败: $e');
      return null;
    }
  }

  Future<int> addUser(User user) async {
    if (!_isInitialized()) {
      print('UserProvider未初始化，无法创建用户');
      return -1;
    }

    final dbWrapper = _dbWrapper;
    if (dbWrapper == null) return -1;

    return await dbWrapper.wrapOperation('addUser', () async {
      try {
        final bytes = utf8.encode(user.password);
        final digest = md5.convert(bytes);
        final hashedPassword = digest.toString();

        print('创建用户 - 用户名: ${user.username}, 原始密码: ${user.password}, 加密后: $hashedPassword');

        int id = 0;

        if (_dataSourceType() == 'sqlite') {
          final db = _sqliteDatabase();
          if (db == null) {
            print('SQLite数据库未初始化，无法创建用户');
            return -1;
          }

          final userData = user.toMap();
          userData['password'] = hashedPassword;

          if (userData['image_data'] != null && userData['image_data'] is List<int>) {
            userData['image_data'] = Uint8List.fromList(userData['image_data']);
          }

          id = await db.insert('users', userData);
        } else if (_dataSourceType() == 'mysql') {
          final conn = _mysqlConnection();
          if (conn == null) {
            print('MySQL连接未初始化，无法创建用户');
            return -1;
          }

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
              hashedPassword,
              user.role,
              DateTimeFormatter.toDbString(user.created_at),
              user.doctor,
              user.avatar,
              imageBlob,
            ],
          );
          id = results.insertId ?? 0;
        }

        if (id > 0) {
          print('用户创建成功，ID: $id');
          _clearCache();
          _markUsersNeedRefresh();
        }

        return id;
      } catch (e) {
        print('创建用户失败: $e');
        return -1;
      }
    });
  }

  Future<bool> updateUser(User user) async {
    if (!_isInitialized()) {
      print('UserProvider未初始化，无法更新用户');
      return false;
    }

    final dbWrapper = _dbWrapper;
    if (dbWrapper == null) return false;

    return await dbWrapper.wrapOperation('updateUser', () async {
      try {
        final bytes = utf8.encode(user.password);
        final digest = md5.convert(bytes);
        final hashedPassword = digest.toString();

        print('更新用户 - 用户名: ${user.username}, 原始密码: ${user.password}, 加密后: $hashedPassword');

        bool success = false;

        if (_dataSourceType() == 'sqlite') {
          final db = _sqliteDatabase();
          if (db == null) {
            print('SQLite数据库未初始化，无法更新用户');
            return false;
          }

          final updateData = user.toMap();
          updateData['password'] = hashedPassword;

          if (updateData['image_data'] != null && updateData['image_data'] is List<int>) {
            updateData['image_data'] = Uint8List.fromList(updateData['image_data']);
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
            print('MySQL连接未初始化，无法更新用户');
            return false;
          }

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
              hashedPassword,
              user.role,
              user.doctor,
              user.avatar,
              imageBlob,
              user.id,
            ],
          );
          success = results.affectedRows != null && results.affectedRows! > 0;
        }

        if (success) {
          print('用户更新成功');
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
    if (!_isInitialized()) {
      print('UserProvider未初始化，无法删除用户');
      return false;
    }

    try {
      bool success = false;

      if (_dataSourceType() == 'sqlite') {
        final db = _sqliteDatabase();
        if (db == null) {
          print('SQLite数据库未初始化，无法删除用户');
          return false;
        }

        if (!db.isOpen) {
          print('SQLite数据库连接已关闭，无法删除用户');
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
          print('MySQL连接未初始化，无法删除用户');
          return false;
        }

        try {
          await conn.query('SELECT 1');
        } catch (e) {
          print('MySQL连接已断开，尝试重新连接...');
          return false;
        }

        final results = await conn.query(
          'DELETE FROM users WHERE id = ?',
          [userId],
        );
        success = results.affectedRows != null && results.affectedRows! > 0;
      }

      if (success) {
        print('用户删除成功');
        _clearCache();
        _markUsersNeedRefresh();
        return true;
      }
      return false;
    } catch (e) {
      _setError('删除用户失败: $e');
      print('删除用户失败: $e');
      return false;
    }
  }
}

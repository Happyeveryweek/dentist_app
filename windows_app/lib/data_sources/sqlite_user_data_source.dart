import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../utils/log_manager.dart';
import 'user_data_source.dart';
import 'package:flutter/foundation.dart';

/// SQLite 用户数据源实现
class SqliteUserDataSource implements UserDataSource {
  final Database _database;

  SqliteUserDataSource(this._database);

  @override
  Future<List<User>> getAllUsers() async {
    final result = await _database
        .rawQuery('SELECT * FROM users ORDER BY created_at DESC');
    return result.map((e) => User.fromMap(e)).toList();
  }

  @override
  Future<User?> getUserById(int id) async {
    final result = await _database.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  @override
  Future<User?> getUserByUsername(String username) async {
    final result = await _database.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  @override
  Future<int> createUser(User user) async {
    final userMap = user.toMap();

    // 验证权限配置JSON格式
    if (userMap['module_permissions'] != null) {
      try {
        json.decode(userMap['module_permissions']);
      } catch (e) {
        LogManager.w('SqliteUserDataSource', '权限配置JSON格式错误', error: e);
        userMap['module_permissions'] = null;
      }
    }

    // 处理图片数据 - SQLite支持直接存储Uint8List
    if (userMap['image_data'] != null && userMap['image_data'] is List<int>) {
      userMap['image_data'] = Uint8List.fromList(userMap['image_data']);
    }

    return await _database.insert('users', userMap);
  }

  @override
  Future<bool> updateUser(User user) async {
    final userMap = user.toMap();

    // 验证权限配置JSON格式
    if (userMap['module_permissions'] != null) {
      try {
        json.decode(userMap['module_permissions']);
      } catch (e) {
        LogManager.w('SqliteUserDataSource', '权限配置JSON格式错误', error: e);
        userMap['module_permissions'] = null;
      }
    }

    // 处理图片数据 - SQLite支持直接存储Uint8List
    if (userMap['image_data'] != null && userMap['image_data'] is List<int>) {
      userMap['image_data'] = Uint8List.fromList(userMap['image_data']);
    }

    final count = await _database.update(
      'users',
      userMap,
      where: 'id = ?',
      whereArgs: [user.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteUser(int id) async {
    final count = await _database.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<User?> authenticateUser(String username, String password) async {
    final result = await _database.query(
      'users',
      where: 'username = ? AND password = ?',
      whereArgs: [username, password],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  @override
  Future<int> getUsersCount({String? searchQuery}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause = ' WHERE username LIKE ? OR email LIKE ? OR role LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%'];
    }

    final result = await _database.rawQuery(
        'SELECT COUNT(*) FROM users$whereClause', whereArgs);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<User>> getPaginatedUsers({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  }) async {
    final offset = (page - 1) * pageSize;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause = ' WHERE username LIKE ? OR email LIKE ? OR role LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%'];
    }

    final sql =
        'SELECT * FROM users$whereClause ORDER BY $sortBy $sortOrder LIMIT $pageSize OFFSET $offset';
    final result = await _database.rawQuery(sql, whereArgs);
    return result.map((e) => User.fromMap(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getUserStatistics() async {
    final totalResult =
        await _database.rawQuery('SELECT COUNT(*) as total FROM users');
    final total = Sqflite.firstIntValue(totalResult) ?? 0;

    final roleResult = await _database.rawQuery('''
      SELECT role, COUNT(*) as count 
      FROM users 
      GROUP BY role
    ''');

    final roleStats = <String, int>{};
    for (final row in roleResult) {
      roleStats[row['role'] as String] = row['count'] as int;
    }

    return {
      'totalUsers': total,
      'roleStatistics': roleStats,
    };
  }

  @override
  Future<Map<String, bool>> getUserPermissions(int userId) async {
    final result = await _database.query(
      'users',
      columns: ['module_permissions', 'role'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (result.isEmpty) {
      return {};
    }

    final row = result.first;
    final role = row['role'] as String?;
    final permissionsJson = row['module_permissions'] as String?;

    // 管理员拥有所有权限
    if (role == 'admin') {
      return {
        'dashboard': true,
        'patients': true,
        'appointments': true,
        'financial': true,
        'materials': true,
        'purchase': true,
        'users': true,
        'settings': true,
      };
    }

    // 解析权限配置
    if (permissionsJson != null && permissionsJson.isNotEmpty) {
      try {
        final Map<String, dynamic> permissions = json.decode(permissionsJson);
        final Map<String, bool> result = {
          'dashboard': true, // 仪表盘始终可见
        };

        permissions.forEach((module, hasPermission) {
          result[module] = hasPermission == true;
        });

        return result;
      } catch (e) {
        LogManager.w('SqliteUserDataSource', '权限配置JSON解析错误', error: e);
      }
    }

    // 默认权限：仅仪表盘
    return {'dashboard': true};
  }

  @override
  Future<bool> updateUserPermissions(
      int userId, Map<String, bool> permissions) async {
    try {
      // 检查用户是否存在且不是管理员
      final userResult = await _database.query(
        'users',
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (userResult.isEmpty) {
        LogManager.w('SqliteUserDataSource', '用户不存在: $userId');
        return false;
      }

      final role = userResult.first['role'] as String?;
      if (role == 'admin') {
        LogManager.w('SqliteUserDataSource', '不能修改管理员权限');
        return false;
      }

      // 确保仪表盘权限始终为true
      final updatedPermissions = Map<String, bool>.from(permissions);
      updatedPermissions['dashboard'] = true;

      // 转换为JSON字符串
      final permissionsJson = json.encode(updatedPermissions);

      // 更新数据库
      final count = await _database.update(
        'users',
        {'module_permissions': permissionsJson},
        where: 'id = ?',
        whereArgs: [userId],
      );

      return count > 0;
    } catch (e) {
      LogManager.e('SqliteUserDataSource', '更新用户权限失败', error: e);
      return false;
    }
  }

  @override
  Future<bool> registerUser(String username, String? email,
      String hashedPassword, String role) async {
    final id = await _database.insert('users', {
      'username': username,
      'email': email ?? '',
      'password': hashedPassword,
      'role': role,
      'created_at': DateTime.now().toIso8601String(),
    });
    return id > 0;
  }

  @override
  Future<int> updateUserPassword(int userId, String hashedPassword) async {
    return await _database.update(
      'users',
      {'password': hashedPassword},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }
}

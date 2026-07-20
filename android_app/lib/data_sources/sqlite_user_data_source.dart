import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/user.dart';
import 'user_data_source.dart';
import '../utils/app_logger.dart';

class SqliteUserDataSource implements UserDataSource {
  final Database _database;

  SqliteUserDataSource(this._database);

  Database get database => _database;

  @override
  Future<List<User>> getAllUsers() async {
    final result = await _database.rawQuery(
      'SELECT * FROM users ORDER BY username',
    );
    return result.map((e) => User.fromMap(e)).toList();
  }

  @override
  Future<User?> getUserById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM users WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  @override
  Future<User?> getUserByUsername(String username) async {
    final result = await _database.rawQuery(
      'SELECT * FROM users WHERE username = ?',
      [username],
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  @override
  Future<int> createUser(User user) async {
    final userData = user.toMap();

    if (userData['module_permissions'] != null) {
      userData['module_permissions'] =
          userData['module_permissions'].toString();
    }

    if (userData['image_data'] != null && userData['image_data'] is List<int>) {
      userData['image_data'] = Uint8List.fromList(userData['image_data']);
    }

    return await _database.insert('users', userData);
  }

  @override
  Future<bool> updateUser(User user) async {
    final updateData = user.toMap();

    if (updateData['module_permissions'] != null) {
      updateData['module_permissions'] =
          updateData['module_permissions'].toString();
    }

    if (updateData['image_data'] != null &&
        updateData['image_data'] is List<int>) {
      updateData['image_data'] = Uint8List.fromList(updateData['image_data']);
    }

    final count = await _database.update(
      'users',
      updateData,
      where: 'id = ?',
      whereArgs: [user.id],
    );
    return count > 0;
  }

  @override
  Future<bool> updateUserPassword(int id, String passwordHash) async {
    final count = await _database.update(
      'users',
      {'password': passwordHash},
      where: 'id = ?',
      whereArgs: [id],
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
  Future<List<User>> searchUsers(String keyword) async {
    final result = await _database.rawQuery(
      '''
      SELECT * FROM users
      WHERE username LIKE ? OR email LIKE ?
      ORDER BY username
    ''',
      ['%$keyword%', '%$keyword%'],
    );
    return result.map((e) => User.fromMap(e)).toList();
  }

  @override
  Future<int> getUsersCount() async {
    final result = await _database.rawQuery(
      'SELECT COUNT(*) as count FROM users',
    );
    final row = result.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<bool> isUsernameExists(String username, {int? excludeId}) async {
    final result = await _database.rawQuery(
      excludeId != null
          ? 'SELECT 1 FROM users WHERE username = ? AND id != ?'
          : 'SELECT 1 FROM users WHERE username = ?',
      excludeId != null ? [username, excludeId] : [username],
    );
    return result.isNotEmpty;
  }

  @override
  Future<bool> isEmailExists(String email, {int? excludeId}) async {
    if (email.isEmpty) return false;

    final result = await _database.rawQuery(
      excludeId != null
          ? 'SELECT 1 FROM users WHERE email = ? AND id != ?'
          : 'SELECT 1 FROM users WHERE email = ?',
      excludeId != null ? [email, excludeId] : [email],
    );
    return result.isNotEmpty;
  }

  @override
  Future<Map<String, dynamic>> getUserStatistics() async {
    final result = await _database.rawQuery('''
      SELECT
        COUNT(*) as total_users,
        COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count,
        COUNT(CASE WHEN role = 'doctor' THEN 1 END) as doctor_count,
        COUNT(CASE WHEN role = 'user' THEN 1 END) as user_count
      FROM users
    ''');

    if (result.isNotEmpty) {
      return {
        'totalUsers': result.first['total_users'] ?? 0,
        'adminCount': result.first['admin_count'] ?? 0,
        'doctorCount': result.first['doctor_count'] ?? 0,
        'userCount': result.first['user_count'] ?? 0,
      };
    }

    return {'totalUsers': 0, 'adminCount': 0, 'doctorCount': 0, 'userCount': 0};
  }

  @override
  Future<Map<String, bool>?> getUserPermissions(int userId) async {
    try {
      final result = await _database.rawQuery(
        'SELECT module_permissions FROM users WHERE id = ?',
        [userId],
      );

      if (result.isEmpty) return null;

      final permissionsJson = result.first['module_permissions'] as String?;
      if (permissionsJson == null || permissionsJson.isEmpty) return null;

      final permissions = jsonDecode(permissionsJson) as Map<String, dynamic>;
      return permissions.map((key, value) => MapEntry(key, value == true));
    } catch (e) {
      AppLogger.info('获取用户权限失败: $e');
      return null;
    }
  }

  @override
  Future<bool> updateUserPermissions(
    int userId,
    Map<String, bool> permissions,
  ) async {
    try {
      final permissionsJson = jsonEncode(permissions);
      final count = await _database.update(
        'users',
        {'module_permissions': permissionsJson},
        where: 'id = ?',
        whereArgs: [userId],
      );
      return count > 0;
    } catch (e) {
      AppLogger.info('更新用户权限失败: $e');
      return false;
    }
  }
}

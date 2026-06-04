import 'package:crypto/crypto.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/user.dart';
import '../utils/datetime_formatter.dart';
import 'user_data_source.dart';

class MySqlUserDataSource implements UserDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlUserDataSource.withConnectionGetter(this._getConnection);

  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];

      if (field == 'created_at' || field == 'updated_at') {
        if (value is DateTime) {
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        if (field == 'image_data') {
          try {
            final bytes = value.toBytes();
            map[field] = bytes.isNotEmpty ? bytes : null;
          } catch (e) {
            print('图片Blob转换失败: $e');
            map[field] = null;
          }
        } else if (field == 'username' || field == 'email' || field == 'role' || field == 'doctor' || field == 'avatar') {
          try {
            final bytes = value.toBytes();
            if (bytes.isNotEmpty) {
              final stringValue = utf8.decode(bytes, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            print('Blob转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else if (value is Uint8List) {
        if (field == 'image_data') {
          map[field] = value.isNotEmpty ? value : null;
        } else if (field == 'username' || field == 'email' || field == 'role' || field == 'doctor' || field == 'avatar') {
          try {
            if (value.isNotEmpty) {
              final stringValue = utf8.decode(value, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            print('Uint8List转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else {
        map[field] = value;
      }
    }
    return map;
  }

  @override
  Future<List<User>> getAllUsers() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query('SELECT * FROM users ORDER BY username');
    return results.map((row) => User.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<User?> getUserById(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      'SELECT * FROM users WHERE id = ?',
      [id],
    );

    if (results.isEmpty) return null;
    return User.fromMap(_convertMySqlRow(results.first));
  }

  @override
  Future<int> createUser(User user) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final bytes = utf8.encode(user.password);
    final digest = sha256.convert(bytes);
    final hashedPassword = digest.toString();

    print('创建用户 - 用户名: ${user.username}, 原始密码: ${user.password}, SHA-256加密后: $hashedPassword');

    final userData = user.toMap();
    userData['password'] = hashedPassword;

    if (userData['module_permissions'] != null) {
      userData['module_permissions'] = userData['module_permissions'].toString();
    }

    if (userData['image_data'] != null && userData['image_data'] is List<int>) {
      userData['image_data'] = Uint8List.fromList(userData['image_data']);
    }

    final columns = userData.keys.join(', ');
    final placeholders = List.filled(userData.length, '?').join(', ');
    final values = userData.values.toList();

    final result = await connection.query(
      'INSERT INTO users ($columns) VALUES ($placeholders)',
      values,
    );

    return result.insertId ?? 0;
  }

  @override
  Future<bool> updateUser(User user) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final bytes = utf8.encode(user.password);
    final digest = sha256.convert(bytes);
    final hashedPassword = digest.toString();

    print('更新用户 - 用户名: ${user.username}, 原始密码: ${user.password}, SHA-256加密后: $hashedPassword');

    final userData = user.toMap();
    userData['password'] = hashedPassword;

    if (userData['module_permissions'] != null) {
      userData['module_permissions'] = userData['module_permissions'].toString();
    }

    if (userData['image_data'] != null && userData['image_data'] is List<int>) {
      userData['image_data'] = Uint8List.fromList(userData['image_data']);
    }

    final updateColumns = userData.keys.where((key) => key != 'id').toList();
    final setClause = updateColumns.map((key) => '$key = ?').join(', ');
    final values = updateColumns.map((key) => userData[key]).toList();
    values.add(user.id);

    final result = await connection.query(
      'UPDATE users SET $setClause WHERE id = ?',
      values,
    );

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteUser(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      'DELETE FROM users WHERE id = ?',
      [id],
    );

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<User>> searchUsers(String keyword) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      'SELECT * FROM users WHERE username LIKE ? OR email LIKE ? ORDER BY username',
      ['%$keyword%', '%$keyword%'],
    );

    return results.map((row) => User.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<int> getUsersCount() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query('SELECT COUNT(*) as count FROM users');
    if (results.isEmpty) return 0;

    final row = results.first;
    final count = row['count'];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    if (count is String) return int.tryParse(count) ?? 0;
    return 0;
  }

  @override
  Future<User?> authenticateUser(String username, String password) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    print('用户认证 - 用户名: $username, 原始密码: $password');
    final bytes = utf8.encode(password);

    final md5Hash = md5.convert(bytes).toString();
    final sha256Hash = sha256.convert(bytes).toString();

    print('尝试MD5加密密码: $md5Hash');
    print('尝试SHA-256加密密码: $sha256Hash');

    var results = await connection.query(
      'SELECT * FROM users WHERE username = ? AND password = ?',
      [username, sha256Hash],
    );

    if (results.isEmpty) {
      print('SHA-256密码认证失败，尝试MD5密码');
      results = await connection.query(
        'SELECT * FROM users WHERE username = ? AND password = ?',
        [username, md5Hash],
      );
    }

    if (results.isEmpty) {
      print('MD5密码认证失败，尝试明文密码');
      results = await connection.query(
        'SELECT * FROM users WHERE username = ? AND password = ?',
        [username, password],
      );
    }

    print('MySQL查询结果: ${results.length} 行');
    if (results.isNotEmpty) {
      final user = User.fromMap(_convertMySqlRow(results.first));
      print('MySQL认证成功，用户: ${user.username}');
      final currentPassword = results.first['password'];

      if (currentPassword == password) {
        print('检测到明文密码，自动更新为SHA-256密码');
        await connection.query(
          'UPDATE users SET password = ? WHERE id = ?',
          [sha256Hash, user.id],
        );
        print('密码已更新为SHA-256格式');
      } else if (currentPassword == md5Hash) {
        print('检测到MD5密码，自动更新为SHA-256密码');
        await connection.query(
          'UPDATE users SET password = ? WHERE id = ?',
          [sha256Hash, user.id],
        );
        print('密码已更新为SHA-256格式');
      }

      return user;
    }

    print('用户认证失败: 用户名或密码错误');
    return null;
  }

  @override
  Future<bool> isUsernameExists(String username, {int? excludeId}) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      excludeId != null
          ? 'SELECT 1 FROM users WHERE username = ? AND id != ?'
          : 'SELECT 1 FROM users WHERE username = ?',
      excludeId != null ? [username, excludeId] : [username],
    );

    return results.isNotEmpty;
  }

  @override
  Future<bool> isEmailExists(String email, {int? excludeId}) async {
    if (email.isEmpty) return false;

    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      excludeId != null
          ? 'SELECT 1 FROM users WHERE email = ? AND id != ?'
          : 'SELECT 1 FROM users WHERE email = ?',
      excludeId != null ? [email, excludeId] : [email],
    );

    return results.isNotEmpty;
  }

  @override
  Future<Map<String, dynamic>> getUserStatistics() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query('''
      SELECT
        COUNT(*) as total_users,
        COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count,
        COUNT(CASE WHEN role = 'doctor' THEN 1 END) as doctor_count,
        COUNT(CASE WHEN role = 'user' THEN 1 END) as user_count
      FROM users
    ''');

    if (results.isNotEmpty) {
      final row = results.first;
      return {
        'totalUsers': row['total_users'] ?? 0,
        'adminCount': row['admin_count'] ?? 0,
        'doctorCount': row['doctor_count'] ?? 0,
        'userCount': row['user_count'] ?? 0,
      };
    }

    return {
      'totalUsers': 0,
      'adminCount': 0,
      'doctorCount': 0,
      'userCount': 0,
    };
  }

  @override
  Future<Map<String, bool>?> getUserPermissions(int userId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      'SELECT module_permissions FROM users WHERE id = ?',
      [userId],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    final permissionsJson = row['module_permissions']?.toString();
    if (permissionsJson == null || permissionsJson.isEmpty) return null;

    try {
      final permissions = jsonDecode(permissionsJson) as Map<String, dynamic>;
      return permissions.map((key, value) => MapEntry(key, value == true));
    } catch (e) {
      print('解析用户权限失败: $e');
      return null;
    }
  }

  @override
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    try {
      final permissionsJson = jsonEncode(permissions);
      final result = await connection.query(
        'UPDATE users SET module_permissions = ? WHERE id = ?',
        [permissionsJson, userId],
      );

      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      print('更新用户权限失败: $e');
      return false;
    }
  }
}

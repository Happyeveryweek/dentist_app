import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql1/mysql1.dart';
import '../models/user.dart';
import 'base_mysql_data_source.dart';
import 'user_data_source.dart';

/// MySQL用户数据源实现
class MySqlUserDataSource extends BaseMySqlDataSource implements UserDataSource {
  MySqlUserDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );

  @override
  Future<List<User>> getAllUsers() async {
    final result = await executeQuery(
      'SELECT * FROM users ORDER BY created_at DESC'
    );
    
    final users = <User>[];
    for (final row in result) {
      final userMap = convertRowToMap(row);
      users.add(User.fromMap(userMap));
    }
    return users;
  }

  @override
  Future<User?> getUserById(int id) async {
    final result = await executeQuery(
      'SELECT * FROM users WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    
    final userMap = convertRowToMap(result.first);
    return User.fromMap(userMap);
  }

  @override
  Future<User?> getUserByUsername(String username) async {
    final result = await executeQuery(
      'SELECT * FROM users WHERE username = ?',
      [username],
    );
    if (result.isEmpty) return null;
    
    final userMap = convertRowToMap(result.first);
    return User.fromMap(userMap);
  }

  @override
  Future<int> createUser(User user) async {
    // 处理权限配置的JSON转换
    String? permissionsJson;
    if (user.modulePermissions != null && user.modulePermissions!.isNotEmpty) {
      try {
        // 验证JSON格式
        json.decode(user.modulePermissions!);
        permissionsJson = user.modulePermissions;
      } catch (e) {
        print('权限配置JSON格式错误: $e');
        permissionsJson = null;
      }
    }
    
    // 处理图片数据 - MySQL需要转换为Blob
    dynamic imageBlob;
    if (user.imageData != null && user.imageData!.isNotEmpty) {
      imageBlob = Uint8List.fromList(user.imageData!);
    }
    
    final result = await executeQuery('''
      INSERT INTO users (username, password, role, email, doctor, avatar, module_permissions, image_data, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''', [
      user.username,
      user.password,
      user.role,
      user.email,
      user.doctor,
      user.avatar,
      permissionsJson,
      imageBlob,
    ]);
    
    return result.insertId ?? 0;
  }

  @override
  Future<bool> updateUser(User user) async {
    // 处理权限配置的JSON转换
    String? permissionsJson;
    if (user.modulePermissions != null && user.modulePermissions!.isNotEmpty) {
      try {
        // 验证JSON格式
        json.decode(user.modulePermissions!);
        permissionsJson = user.modulePermissions;
      } catch (e) {
        print('权限配置JSON格式错误: $e');
        permissionsJson = null;
      }
    }
    
    // 处理图片数据 - MySQL需要转换为Blob
    dynamic imageBlob;
    if (user.imageData != null && user.imageData!.isNotEmpty) {
      imageBlob = Uint8List.fromList(user.imageData!);
    }
    
    final result = await executeQuery('''
      UPDATE users 
      SET username = ?, password = ?, role = ?, email = ?, doctor = ?, avatar = ?, module_permissions = ?, image_data = ?, updated_at = NOW()
      WHERE id = ?
    ''', [
      user.username,
      user.password,
      user.role,
      user.email,
      user.doctor,
      user.avatar,
      permissionsJson,
      imageBlob,
      user.id,
    ]);
    
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteUser(int id) async {
    final result = await executeQuery('DELETE FROM users WHERE id = ?', [id]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<User?> authenticateUser(String username, String password) async {
    final result = await executeQuery(
      'SELECT * FROM users WHERE username = ? AND password = ?',
      [username, password],
    );
    if (result.isEmpty) return null;
    
    final userMap = convertRowToMap(result.first);
    return User.fromMap(userMap);
  }

  @override
  Future<int> getUsersCount({String? searchQuery}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause = ' WHERE username LIKE ? OR email LIKE ? OR role LIKE ?';
      whereArgs = ['%$searchQuery%', '%$searchQuery%', '%$searchQuery%'];
    }
    
    final result = await executeQuery('SELECT COUNT(*) as count FROM users$whereClause', whereArgs);
    final row = result.first;
    final dynamic v = row['count'] ?? row[0];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    return 0;
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
    
    final sql = 'SELECT * FROM users$whereClause ORDER BY $sortBy $sortOrder LIMIT $offset, $pageSize';
    final result = await executeQuery(sql, whereArgs);
    
    final users = <User>[];
    for (final row in result) {
      final userMap = convertRowToMap(row);
      users.add(User.fromMap(userMap));
    }
    return users;
  }

  @override
  Future<Map<String, dynamic>> getUserStatistics() async {
    final totalResult = await executeQuery('SELECT COUNT(*) as total FROM users');
    final totalRow = totalResult.first;
    final int total = (totalRow['total'] is BigInt) ? (totalRow['total'] as BigInt).toInt() : (totalRow['total'] ?? 0);
    
    final roleResult = await executeQuery('''
      SELECT role, COUNT(*) as count 
      FROM users 
      GROUP BY role
    ''');
    
    final roleStats = <String, int>{};
    for (final row in roleResult) {
      final role = row['role']?.toString() ?? '';
      final count = (row['count'] is BigInt) ? (row['count'] as BigInt).toInt() : (row['count'] ?? 0);
      roleStats[role] = count;
    }
    
    return {
      'totalUsers': total,
      'roleStatistics': roleStats,
    };
  }

  @override
  Future<Map<String, bool>> getUserPermissions(int userId) async {
    final result = await executeQuery(
      'SELECT module_permissions, role FROM users WHERE id = ?',
      [userId],
    );
    
    if (result.isEmpty) {
      return {};
    }
    
    final row = result.first;
    final role = row['role']?.toString();
    final permissionsData = row['module_permissions'];
    
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
    if (permissionsData != null) {
      try {
        String permissionsJson;
        
        // 处理不同的数据类型
        if (permissionsData is String) {
          permissionsJson = permissionsData;
        } else {
          permissionsJson = json.encode(permissionsData);
        }
        
        if (permissionsJson.isNotEmpty) {
          final Map<String, dynamic> permissions = json.decode(permissionsJson);
          final Map<String, bool> result = {
            'dashboard': true, // 仪表盘始终可见
          };
          
          permissions.forEach((module, hasPermission) {
            result[module] = hasPermission == true;
          });
          
          return result;
        }
      } catch (e) {
        print('权限配置JSON解析错误: $e');
      }
    }
    
    // 默认权限：仅仪表盘
    return {'dashboard': true};
  }

  @override
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions) async {
    try {
      // 检查用户是否存在且不是管理员
      final userResult = await executeQuery(
        'SELECT role FROM users WHERE id = ?',
        [userId],
      );
      
      if (userResult.isEmpty) {
        print('用户不存在: $userId');
        return false;
      }
      
      final role = userResult.first['role']?.toString();
      if (role == 'admin') {
        print('不能修改管理员权限');
        return false;
      }
      
      // 确保仪表盘权限始终为true
      final updatedPermissions = Map<String, bool>.from(permissions);
      updatedPermissions['dashboard'] = true;
      
      // 转换为JSON字符串
      final permissionsJson = json.encode(updatedPermissions);
      
      // 更新数据库
      final result = await executeQuery(
        'UPDATE users SET module_permissions = ? WHERE id = ?',
        [permissionsJson, userId],
      );
      
      return (result.affectedRows ?? 0) > 0;
    } catch (e) {
      print('更新用户权限失败: $e');
      return false;
    }
  }

  @override
  Future<bool> registerUser(String username, String? email, String hashedPassword, String role) async {
    final result = await executeQuery(
      '''INSERT INTO users (username, email, password, role, created_at) 
         VALUES (?, ?, ?, ?, NOW())''',
      [username, email ?? '', hashedPassword, role],
    );
    return result.insertId != null;
  }

  @override
  Future<int> updateUserPassword(int userId, String hashedPassword) async {
    final result = await executeQuery(
      'UPDATE users SET password = ? WHERE id = ?',
      [hashedPassword, userId],
    );
    return result.affectedRows ?? 0;
  }
}

import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'base_mysql_data_source.dart';

// 抽象用户数据源接口
abstract class UserDataSource {
  Future<List<User>> getAllUsers();
  Future<User?> getUserById(int id);
  Future<User?> getUserByUsername(String username);
  Future<int> createUser(User user);
  Future<bool> updateUser(User user);
  Future<bool> deleteUser(int id);
  
  // 认证相关方法
  Future<User?> authenticateUser(String username, String password);
  
  // 分页查询方法
  Future<int> getUsersCount({String? searchQuery});
  Future<List<User>> getPaginatedUsers({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  });
  
  // 统计方法
  Future<Map<String, dynamic>> getUserStatistics();
  
  // 权限相关方法
  Future<Map<String, bool>> getUserPermissions(int userId);
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions);
}

// SQLite用户数据源实现
class SqliteUserDataSource implements UserDataSource {
  final Database _database;

  SqliteUserDataSource(this._database);

  @override
  Future<List<User>> getAllUsers() async {
    final result = await _database.rawQuery(
      'SELECT * FROM users ORDER BY created_at DESC'
    );
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
        print('权限配置JSON格式错误: $e');
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
        print('权限配置JSON格式错误: $e');
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
    
    final result = await _database.rawQuery('SELECT COUNT(*) FROM users$whereClause', whereArgs);
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
    
    final sql = 'SELECT * FROM users$whereClause ORDER BY $sortBy $sortOrder LIMIT $pageSize OFFSET $offset';
    final result = await _database.rawQuery(sql, whereArgs);
    return result.map((e) => User.fromMap(e)).toList();
  }

  @override
  Future<Map<String, dynamic>> getUserStatistics() async {
    final totalResult = await _database.rawQuery('SELECT COUNT(*) as total FROM users');
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
      final userResult = await _database.query(
        'users',
        columns: ['role'],
        where: 'id = ?',
        whereArgs: [userId],
        limit: 1,
      );
      
      if (userResult.isEmpty) {
        print('用户不存在: $userId');
        return false;
      }
      
      final role = userResult.first['role'] as String?;
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
      final count = await _database.update(
        'users',
        {'module_permissions': permissionsJson},
        where: 'id = ?',
        whereArgs: [userId],
      );
      
      return count > 0;
    } catch (e) {
      print('更新用户权限失败: $e');
      return false;
    }
  }
}

// MySQL用户数据源实现
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
}


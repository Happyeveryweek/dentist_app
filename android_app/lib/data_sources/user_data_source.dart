import '../models/user.dart';

// 抽象用户数据源接口
abstract class UserDataSource {
  Future<List<User>> getAllUsers();
  Future<User?> getUserById(int id);
  Future<int> createUser(User user);
  Future<bool> updateUser(User user);
  Future<bool> deleteUser(int id);
  Future<List<User>> searchUsers(String keyword);
  Future<int> getUsersCount();
  Future<User?> authenticateUser(String username, String password);
  Future<bool> isUsernameExists(String username, {int? excludeId});
  Future<bool> isEmailExists(String email, {int? excludeId});
  Future<Map<String, dynamic>> getUserStatistics();
  
  // 权限相关方法
  Future<Map<String, bool>?> getUserPermissions(int userId);
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions);
}

/*

// SQLite用户数据源实现
class SqliteUserDataSource implements UserDataSource {
  final Database _database;

  SqliteUserDataSource(this._database);

  // 提供database getter以保持向后兼容
  Database get database => _database;

  @override
  Future<List<User>> getAllUsers() async {
    final result = await _database.rawQuery(
      'SELECT * FROM users ORDER BY username'
    );
    return result.map((e) => User.fromMap(e)).toList();
  }

  @override
  Future<User?> getUserById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM users WHERE id = ?', [id]
    );
    if (result.isEmpty) return null;
    return User.fromMap(result.first);
  }

  @override
  Future<int> createUser(User user) async {
    // 对密码进行SHA-256加密，与windows端保持一致
    final bytes = utf8.encode(user.password);
    final digest = sha256.convert(bytes);
    final hashedPassword = digest.toString();
    
    print('创建用户 - 用户名: ${user.username}, 原始密码: ${user.password}, SHA-256加密后: $hashedPassword');

    // 创建用户数据，使用加密后的密码
    final userData = user.toMap();
    userData['password'] = hashedPassword;
    
    // 确保权限字段正确处理
    if (userData['module_permissions'] != null) {
      // SQLite使用TEXT存储JSON字符串
      userData['module_permissions'] = userData['module_permissions'].toString();
    }
    
    // 处理图片数据 - SQLite支持直接存储Uint8List
    if (userData['image_data'] != null && userData['image_data'] is List<int>) {
      userData['image_data'] = Uint8List.fromList(userData['image_data']);
    }
    
    return await _database.insert('users', userData);
  }

  @override
  Future<bool> updateUser(User user) async {
    // 对密码进行SHA-256加密，与windows端保持一致
    final bytes = utf8.encode(user.password);
    final digest = sha256.convert(bytes);
    final hashedPassword = digest.toString();
    
    print('更新用户 - 用户名: ${user.username}, 原始密码: ${user.password}, SHA-256加密后: $hashedPassword');

    // 创建更新数据，使用加密后的密码
    final updateData = user.toMap();
    updateData['password'] = hashedPassword;
    
    // 确保权限字段正确处理
    if (updateData['module_permissions'] != null) {
      // SQLite使用TEXT存储JSON字符串
      updateData['module_permissions'] = updateData['module_permissions'].toString();
    }
    
    // 处理图片数据 - SQLite支持直接存储Uint8List
    if (updateData['image_data'] != null && updateData['image_data'] is List<int>) {
      updateData['image_data'] = Uint8List.fromList(updateData['image_data']);
    }
    
    final count = await _database.update(
      'users', 
      updateData, 
      where: 'id = ?', 
      whereArgs: [user.id]
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
    final result = await _database.rawQuery('''
      SELECT * FROM users 
      WHERE username LIKE ? OR email LIKE ?
      ORDER BY username
    ''', ['%$keyword%', '%$keyword%']);
    return result.map((e) => User.fromMap(e)).toList();
  }

  @override
  Future<int> getUsersCount() async {
    final result = await _database.rawQuery('SELECT COUNT(*) as count FROM users');
    final row = result.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<User?> authenticateUser(String username, String password) async {
    print('用户认证 - 用户名: $username, 原始密码: $password');

    final bytes = utf8.encode(password);
    
    // 计算MD5和SHA-256哈希值
    final md5Hash = md5.convert(bytes).toString();
    final sha256Hash = sha256.convert(bytes).toString();
    
    print('尝试MD5加密密码: $md5Hash');
    print('尝试SHA-256加密密码: $sha256Hash');
    
    // 首先尝试SHA-256加密后的密码（Windows端使用的格式）
    var result = await _database.rawQuery(
      'SELECT * FROM users WHERE username = ? AND password = ?',
      [username, sha256Hash]
    );
    
    // 如果SHA-256密码失败，尝试MD5加密后的密码
    if (result.isEmpty) {
      print('SHA-256密码认证失败，尝试MD5密码');
      result = await _database.rawQuery(
        'SELECT * FROM users WHERE username = ? AND password = ?',
        [username, md5Hash]
      );
    }
    
    // 如果MD5密码也失败，尝试明文密码（兼容旧数据）
    if (result.isEmpty) {
      print('MD5密码认证失败，尝试明文密码');
      result = await _database.rawQuery(
        'SELECT * FROM users WHERE username = ? AND password = ?',
        [username, password]
      );
    }
    
    print('SQLite查询结果: ${result.length} 行');
    if (result.isNotEmpty) {
      final user = User.fromMap(result.first);
      print('SQLite认证成功，用户: ${user.username}');
      
      final currentPassword = result.first['password'] as String;
      
      // 如果使用明文密码登录成功，自动更新为SHA-256密码
      if (currentPassword == password) {
        print('检测到明文密码，自动更新为SHA-256密码');
        await _database.update(
          'users',
          {'password': sha256Hash},
          where: 'id = ?',
          whereArgs: [user.id]
        );
        print('密码已更新为SHA-256格式');
      }
      // 如果使用MD5密码登录成功，自动更新为SHA-256密码
      else if (currentPassword == md5Hash) {
        print('检测到MD5密码，自动更新为SHA-256密码');
        await _database.update(
          'users',
          {'password': sha256Hash},
          where: 'id = ?',
          whereArgs: [user.id]
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
    final result = await _database.rawQuery(
      excludeId != null 
        ? 'SELECT 1 FROM users WHERE username = ? AND id != ?'
        : 'SELECT 1 FROM users WHERE username = ?',
      excludeId != null ? [username, excludeId] : [username]
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
      excludeId != null ? [email, excludeId] : [email]
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
    
    return {
      'totalUsers': 0,
      'adminCount': 0,
      'doctorCount': 0,
      'userCount': 0,
    };
  }

  @override
  Future<Map<String, bool>?> getUserPermissions(int userId) async {
    try {
      final result = await _database.rawQuery(
        'SELECT module_permissions FROM users WHERE id = ?', 
        [userId]
      );
      
      if (result.isEmpty) return null;
      
      final permissionsJson = result.first['module_permissions'] as String?;
      if (permissionsJson == null || permissionsJson.isEmpty) return null;
      
      final permissions = jsonDecode(permissionsJson) as Map<String, dynamic>;
      return permissions.map((key, value) => MapEntry(key, value == true));
    } catch (e) {
      print('获取用户权限失败: $e');
      return null;
    }
  }

  @override
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions) async {
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
      print('更新用户权限失败: $e');
      return false;
    }
  }
}

// MySQL用户数据源实现（使用动态连接获取）
class MySqlUserDataSource implements UserDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlUserDataSource.withConnectionGetter(this._getConnection);

  // 辅助方法：处理MySQL行数据转换
  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];
      
      // 处理日期字段 - 使用统一格式
      if (field == 'created_at' || field == 'updated_at') {
        if (value is DateTime) {
          // 如果MySQL返回的是UTC时间，转换为本地时间
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        // 处理Blob字段
        if (field == 'image_data') {
          // 图片数据保留为二进制
          try {
            final bytes = value.toBytes();
            map[field] = bytes.isNotEmpty ? bytes : null;
          } catch (e) {
            print('图片Blob转换失败: $e');
            map[field] = null;
          }
        } else if (field == 'username' || field == 'email' || field == 'role' || field == 'doctor' || field == 'avatar') {
          // 文本字段转换为字符串
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
        // 处理Uint8List类型
        if (field == 'image_data') {
          // 图片数据保留为二进制
          map[field] = value.isNotEmpty ? value : null;
        } else if (field == 'username' || field == 'email' || field == 'role' || field == 'doctor' || field == 'avatar') {
          // 文本字段转换为字符串
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
    
    final row = results.first;
    return User.fromMap(_convertMySqlRow(row));
  }

  @override
  Future<int> createUser(User user) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    // 对密码进行SHA-256加密，与windows端保持一致
    final bytes = utf8.encode(user.password);
    final digest = sha256.convert(bytes);
    final hashedPassword = digest.toString();
    
    print('创建用户 - 用户名: ${user.username}, 原始密码: ${user.password}, SHA-256加密后: $hashedPassword');

    // 处理权限字段
    String? permissionsJson;
    if (user.modulePermissions != null && user.modulePermissions!.isNotEmpty) {
      permissionsJson = user.modulePermissions;
    }
    
    // 处理图片数据 - MySQL需要转换为Blob
    dynamic imageBlob;
    if (user.imageData != null && user.imageData!.isNotEmpty) {
      imageBlob = Uint8List.fromList(user.imageData!);
    }

    final result = await connection.query(
      '''INSERT INTO users 
         (username, email, password, role, created_at, doctor, avatar, module_permissions, image_data)
         VALUES (?, ?, ?, ?, NOW(), ?, ?, ?, ?)''',
      [
        user.username,
        user.email,
        hashedPassword, // 使用加密后的密码
        user.role,
        user.doctor,
        user.avatar,
        permissionsJson,
        imageBlob,
      ]
    );
    
    return result.insertId!;
  }

  @override
  Future<bool> updateUser(User user) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    // 对密码进行SHA-256加密，与windows端保持一致
    final bytes = utf8.encode(user.password);
    final digest = sha256.convert(bytes);
    final hashedPassword = digest.toString();
    
    print('更新用户 - 用户名: ${user.username}, 原始密码: ${user.password}, SHA-256加密后: $hashedPassword');

    // 处理权限字段
    String? permissionsJson;
    if (user.modulePermissions != null && user.modulePermissions!.isNotEmpty) {
      permissionsJson = user.modulePermissions;
    }
    
    // 处理图片数据 - MySQL需要转换为Blob
    dynamic imageBlob;
    if (user.imageData != null && user.imageData!.isNotEmpty) {
      imageBlob = Uint8List.fromList(user.imageData!);
    }

    final result = await connection.query(
      '''UPDATE users SET 
         username = ?, email = ?, password = ?, role = ?, 
         doctor = ?, avatar = ?, module_permissions = ?, image_data = ?
         WHERE id = ?''',
      [
        user.username,
        user.email,
        hashedPassword, // 使用加密后的密码
        user.role,
        user.doctor,
        user.avatar,
        permissionsJson,
        imageBlob,
        user.id,
      ]
    );
    
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deleteUser(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final result = await connection.query('DELETE FROM users WHERE id = ?', [id]);
    return result.affectedRows! > 0;
  }

  @override
  Future<List<User>> searchUsers(String keyword) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('''
      SELECT * FROM users 
      WHERE username LIKE ? OR email LIKE ?
      ORDER BY username
    ''', ['%$keyword%', '%$keyword%']);
    
    return results.map((row) => User.fromMap(_convertMySqlRow(row))).toList();
  }

  @override
  Future<int> getUsersCount() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    final results = await connection.query('SELECT COUNT(*) as count FROM users');
    final row = results.first;
    return (row['count'] as int?) ?? 0;
  }

  @override
  Future<User?> authenticateUser(String username, String password) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    print('用户认证 - 用户名: $username, 原始密码: $password');

    final bytes = utf8.encode(password);
    
    // 计算MD5和SHA-256哈希值
    final md5Hash = md5.convert(bytes).toString();
    final sha256Hash = sha256.convert(bytes).toString();
    
    print('尝试MD5加密密码: $md5Hash');
    print('尝试SHA-256加密密码: $sha256Hash');
    
    // 首先尝试SHA-256加密后的密码（Windows端使用的格式）
    var results = await connection.query(
      'SELECT * FROM users WHERE username = ? AND password = ?',
      [username, sha256Hash]
    );
    
    // 如果SHA-256密码失败，尝试MD5加密后的密码
    if (results.isEmpty) {
      print('SHA-256密码认证失败，尝试MD5密码');
      results = await connection.query(
        'SELECT * FROM users WHERE username = ? AND password = ?',
        [username, md5Hash]
      );
    }
    
    // 如果MD5密码也失败，尝试明文密码
    if (results.isEmpty) {
      print('MD5密码认证失败，尝试明文密码');
      results = await connection.query(
        'SELECT * FROM users WHERE username = ? AND password = ?',
        [username, password]
      );
    }
    
    print('MySQL查询结果: ${results.length} 行');
    if (results.isNotEmpty) {
      final row = results.first;
      final user = User.fromMap(_convertMySqlRow(row));
      print('MySQL认证成功，用户: ${user.username}');
      
      // 获取当前密码值
      String currentPassword;
      final passwordData = row['password'];
      if (passwordData is String) {
        currentPassword = passwordData;
      } else if (passwordData is Blob) {
        final bytes = passwordData.toBytes();
        currentPassword = utf8.decode(bytes, allowMalformed: true);
      } else if (passwordData is Uint8List) {
        currentPassword = utf8.decode(passwordData, allowMalformed: true);
      } else {
        currentPassword = passwordData.toString();
      }
      
      // 如果使用明文密码登录成功，自动更新为SHA-256密码
      if (currentPassword == password) {
        print('检测到明文密码，自动更新为SHA-256密码');
        await connection.query(
          'UPDATE users SET password = ? WHERE id = ?',
          [sha256Hash, user.id]
        );
        print('密码已更新为SHA-256格式');
      }
      // 如果使用MD5密码登录成功，自动更新为SHA-256密码
      else if (currentPassword == md5Hash) {
        print('检测到MD5密码，自动更新为SHA-256密码');
        await connection.query(
          'UPDATE users SET password = ? WHERE id = ?',
          [sha256Hash, user.id]
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
      excludeId != null ? [username, excludeId] : [username]
    );
    return results.isNotEmpty;
  }

  @override
  Future<bool> isEmailExists(String email, {int? excludeId}) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    
    if (email.isEmpty) return false;
    
    final results = await connection.query(
      excludeId != null 
        ? 'SELECT 1 FROM users WHERE email = ? AND id != ?'
        : 'SELECT 1 FROM users WHERE email = ?',
      excludeId != null ? [email, excludeId] : [email]
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
    
    try {
      final results = await connection.query(
        'SELECT module_permissions FROM users WHERE id = ?', 
        [userId]
      );
      
      if (results.isEmpty) return null;
      
      final row = results.first;
      final permissionsData = row['module_permissions'];
      
      if (permissionsData == null) return null;
      
      // 处理MySQL JSON类型数据
      String permissionsJson;
      if (permissionsData is String) {
        permissionsJson = permissionsData;
      } else if (permissionsData is Blob) {
        final bytes = permissionsData.toBytes();
        permissionsJson = utf8.decode(bytes, allowMalformed: true);
      } else if (permissionsData is Uint8List) {
        permissionsJson = utf8.decode(permissionsData, allowMalformed: true);
      } else {
        permissionsJson = permissionsData.toString();
      }
      
      if (permissionsJson.isEmpty) return null;
      
      final permissions = jsonDecode(permissionsJson) as Map<String, dynamic>;
      return permissions.map((key, value) => MapEntry(key, value == true));
    } catch (e) {
      print('获取用户权限失败: $e');
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
      return result.affectedRows! > 0;
    } catch (e) {
      print('更新用户权限失败: $e');
      return false;
    }
  }
}
*/

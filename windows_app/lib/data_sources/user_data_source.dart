import '../models/user.dart';

export 'sqlite_user_data_source.dart';
export 'mysql_user_data_source.dart';

/// 抽象用户数据源接口
/// 定义了所有用户管理、认证及权限相关的底层数据库操作协议
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

  // 注册与密码管理
  Future<bool> registerUser(
      String username, String? email, String hashedPassword, String role);
  Future<int> updateUserPassword(int userId, String hashedPassword);
}

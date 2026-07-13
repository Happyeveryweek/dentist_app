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

import '../../../models/user.dart';
import '../../../utils/app_logger.dart';

/// 用户会话服务
class UserSessionService {
  /// 用户登录
  static Future<bool> login(
    String username,
    String password,
    Future<User?> Function(String, String) authenticateUser,
  ) async {
    AppLogger.info('开始用户登录 - 用户名: $username');

    try {
      final user = await authenticateUser(username, password);
      if (user != null) {
        AppLogger.info('登录成功，用户: ${user.username}');
        return true;
      } else {
        AppLogger.info('登录失败，用户认证返回null');
        return false;
      }
    } catch (e) {
      AppLogger.info('登录失败: $e');
      return false;
    }
  }

  /// 用户登出
  static void logout(
    User? currentUser,
    void Function(int?) clearPermissionsCache,
    void Function() notifyListeners,
  ) {
    final userId = currentUser?.id;
    if (userId != null) {
      clearPermissionsCache(userId);
    }

    notifyListeners();
  }
}

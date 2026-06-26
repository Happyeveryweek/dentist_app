import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../../../providers/user_provider.dart';
import '../../../utils/log_manager.dart';

/// 用户验证服务
/// 负责密码加密、邮箱验证等业务逻辑
class UserValidationService {
  /// 加密密码
  static String hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 检查邮箱是否已存在
  ///
  /// [userProvider] 用户数据提供者
  /// [email] 要检查的邮箱
  /// [excludeUserId] 排除的用户ID（用于编辑时排除自己）
  ///
  /// 返回 true 表示邮箱已存在，false 表示邮箱可用
  static Future<bool> checkEmailExists(
    UserProvider userProvider,
    String email,
    int? excludeUserId,
  ) async {
    try {
      // 获取所有用户
      final users = await userProvider.getAllUsers();

      // 检查是否有相同邮箱的用户（排除当前编辑的用户）
      for (var user in users) {
        if (user.email == email && user.id != excludeUserId) {
          return true; // 邮箱已存在
        }
      }

      return false; // 邮箱不存在
    } catch (e) {
      LogManager.e('UserValidationService', '检查邮箱是否存在时出错', error: e);
      return false; // 出错时默认返回不存在
    }
  }

  /// 检查用户名是否已存在
  static Future<bool> checkUsernameExists(
    UserProvider userProvider,
    String username,
    int? excludeUserId,
  ) async {
    try {
      final users = await userProvider.getAllUsers();

      for (var user in users) {
        if (user.username == username && user.id != excludeUserId) {
          return true;
        }
      }

      return false;
    } catch (e) {
      LogManager.e('UserValidationService', '检查用户名是否存在时出错', error: e);
      return false;
    }
  }
}

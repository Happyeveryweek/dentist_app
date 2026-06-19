import 'package:shared_preferences/shared_preferences.dart';

/// 凭证存储助手
/// 负责保存和加载用户登录凭证
class CredentialStorageHelper {
  /// 加载保存的登录凭证
  static Future<CredentialData?> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('saved_username');
      final savedPassword = prefs.getString('saved_password');
      final rememberPassword = prefs.getBool('remember_password') ?? false;
      
      if (rememberPassword && savedUsername != null && savedPassword != null) {
        return CredentialData(
          username: savedUsername,
          password: savedPassword,
          rememberPassword: true,
        );
      }
    } catch (e) {
      print('加载保存的登录信息失败: $e');
    }
    return null;
  }

  /// 保存登录凭证
  static Future<void> saveCredentials(
    String username,
    String password,
    bool rememberPassword,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (rememberPassword) {
        await prefs.setString('saved_username', username);
        await prefs.setString('saved_password', password);
        await prefs.setBool('remember_password', true);
      } else {
        await prefs.remove('saved_username');
        await prefs.remove('saved_password');
        await prefs.setBool('remember_password', false);
      }
    } catch (e) {
      print('保存登录信息失败: $e');
    }
  }
}

/// 凭证数据
class CredentialData {
  final String username;
  final String password;
  final bool rememberPassword;

  CredentialData({
    required this.username,
    required this.password,
    required this.rememberPassword,
  });
}

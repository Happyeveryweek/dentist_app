import 'package:shared_preferences/shared_preferences.dart';

/// 登录凭证管理服务
class LoginCredentialsService {
  /// 加载保存的登录信息
  static Future<LoginCredentials> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString('saved_username');
      final savedPassword = prefs.getString('saved_password');
      final rememberPassword = prefs.getBool('remember_password') ?? false;

      if (rememberPassword && savedUsername != null && savedPassword != null) {
        return LoginCredentials(
          username: savedUsername,
          password: savedPassword,
          rememberPassword: true,
        );
      } else {
        // 返回默认的用户名和密码
        return LoginCredentials(
          username: 'admin',
          password: '123456',
          rememberPassword: false,
        );
      }
    } catch (e) {
      print('加载保存的登录信息失败: $e');
      // 返回默认的用户名和密码
      return LoginCredentials(
        username: 'admin',
        password: '123456',
        rememberPassword: false,
      );
    }
  }

  /// 保存登录信息
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

/// 登录凭证数据类
class LoginCredentials {
  final String username;
  final String password;
  final bool rememberPassword;

  LoginCredentials({
    required this.username,
    required this.password,
    required this.rememberPassword,
  });
}

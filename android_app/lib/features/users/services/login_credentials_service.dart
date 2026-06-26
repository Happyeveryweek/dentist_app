import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/app_logger.dart';

/// 登录凭证管理服务
///
class LoginCredentialsService {
  static const String _savedUsernameKey = 'saved_username';
  static const String _savedPasswordKey = 'saved_password';
  static const String _rememberPasswordKey = 'remember_password';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// 加载保存的登录信息
  ///
  static Future<LoginCredentials> loadSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUsername = prefs.getString(_savedUsernameKey) ?? '';
      final rememberPassword = prefs.getBool(_rememberPasswordKey) ?? false;
      final savedPassword = await _secureStorage.read(key: _savedPasswordKey);

      if (rememberPassword && savedUsername.isNotEmpty) {
        return LoginCredentials(
          username: savedUsername,
          password: savedPassword ?? '',
          rememberPassword: true,
        );
      }

      return LoginCredentials.empty();
    } catch (e) {
      AppLogger.error('加载保存的登录信息失败', e);
      return LoginCredentials.empty();
    }
  }

  /// 保存登录信息
  ///
  static Future<void> saveCredentials(
    String username,
    String password,
    bool rememberPassword,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (rememberPassword) {
        await prefs.setString(_savedUsernameKey, username);
        await prefs.setBool(_rememberPasswordKey, true);
        await _secureStorage.write(key: _savedPasswordKey, value: password);
      } else {
        await prefs.remove(_savedUsernameKey);
        await prefs.setBool(_rememberPasswordKey, false);
        await _secureStorage.delete(key: _savedPasswordKey);
      }
    } catch (e) {
      AppLogger.error('保存登录信息失败', e);
    }
  }

  static Future<void> clearSavedCredentials() async {
    await saveCredentials('', '', false);
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

  factory LoginCredentials.empty() {
    return LoginCredentials(
      username: '',
      password: '',
      rememberPassword: false,
    );
  }
}

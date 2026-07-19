import '../../../data_sources/user_data_source.dart';
import '../../../models/user.dart';
import 'password_service.dart';

/// 用户认证与历史密码格式升级入口。
class UserAuthenticationService {
  UserAuthenticationService({PasswordService? passwordService})
      : _passwordService = passwordService ?? PasswordService();

  final PasswordService _passwordService;

  Future<User?> authenticate({
    required UserDataSource dataSource,
    required String username,
    required String password,
  }) async {
    final user = await dataSource.getUserByUsername(username);
    if (user == null) return null;

    final verification =
        _passwordService.verifyPassword(password, user.password);
    if (!verification.isValid) return null;

    final userId = user.id;
    if (verification.needsUpgrade && userId != null) {
      await dataSource.updateUserPassword(
        userId,
        _passwordService.hashPassword(password),
      );
    }
    return user;
  }
}

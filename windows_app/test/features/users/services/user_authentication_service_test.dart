import 'package:crypto/crypto.dart';
import 'package:dentist_app_windows/data_sources/user_data_source.dart';
import 'package:dentist_app_windows/features/users/services/user_authentication_service.dart';
import 'package:dentist_app_windows/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUserDataSource implements UserDataSource {
  _FakeUserDataSource(this.user);

  User? user;
  String? upgradedPassword;

  @override
  Future<User?> getUserByUsername(String username) async =>
      user?.username == username ? user : null;

  @override
  Future<int> updateUserPassword(int userId, String hashedPassword) async {
    upgradedPassword = hashedPassword;
    return 1;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final authenticationService = UserAuthenticationService();

  test('默认管理员仅能使用自身保存的密码登录', () async {
    final source = _FakeUserDataSource(User(
      id: 1,
      username: 'admin',
      password: '123456',
      role: 'admin',
    ));

    expect(
      await authenticationService.authenticate(
        dataSource: source,
        username: 'admin',
        password: '123456',
      ),
      isNotNull,
    );
    expect(source.upgradedPassword, isNotNull);
  });

  test('固定默认密码不能绕过普通账户认证', () async {
    final source = _FakeUserDataSource(User(
      id: 2,
      username: 'doctor-a',
      password: 'different-password',
      role: 'doctor',
    ));

    expect(
      await authenticationService.authenticate(
        dataSource: source,
        username: 'doctor-a',
        password: '123456',
      ),
      isNull,
    );
    expect(source.upgradedPassword, isNull);
  });

  test('历史 MD5 密码登录后升级保存格式', () async {
    final source = _FakeUserDataSource(User(
      id: 3,
      username: 'legacy',
      password: md5.convert('legacy-password'.codeUnits).toString(),
      role: 'doctor',
    ));

    final user = await authenticationService.authenticate(
      dataSource: source,
      username: 'legacy',
      password: 'legacy-password',
    );

    expect(user, isNotNull);
    expect(source.upgradedPassword, startsWith(r'pbkdf2_sha256$'));
  });
}

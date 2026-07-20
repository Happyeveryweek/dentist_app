import 'package:crypto/crypto.dart';
import 'package:dentist_app/data_sources/user_data_source.dart';
import 'package:dentist_app/features/users/services/password_service.dart';
import 'package:dentist_app/features/users/services/user_authentication_service.dart';
import 'package:dentist_app/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = PasswordService();

  test('同一密码每次生成独立存储值且均可验证', () {
    final first = service.hashPassword('123456');
    final second = service.hashPassword('123456');

    expect(first, isNot(second));
    expect(service.verifyPassword('123456', first).isValid, isTrue);
    expect(service.verifyPassword('123456', second).isValid, isTrue);
    expect(service.verifyPassword('wrong-password', first).isValid, isFalse);
  });

  test('历史 SHA-256、MD5 和明文验证成功后需要升级', () {
    const password = 'legacy-password';
    final sha256Password = sha256.convert(password.codeUnits).toString();
    final md5Password = md5.convert(password.codeUnits).toString();

    for (final storedPassword in [sha256Password, md5Password, password]) {
      final result = service.verifyPassword(password, storedPassword);
      expect(result.isValid, isTrue);
      expect(result.needsUpgrade, isTrue);
    }
  });

  test('畸形 PBKDF2 格式安全失败', () {
    for (final storedPassword in [
      r'pbkdf2_sha256$0$c2FsdA==$aGFzaA==',
      r'pbkdf2_sha256$100000$not-base64$also-not-base64',
      r'pbkdf2_sha256$1000001$c2FsdA==$aGFzaA==',
    ]) {
      expect(service.verifyPassword('123456', storedPassword).isValid, isFalse);
    }
  });

  test('认证仅匹配账户保存的密码，并升级历史格式', () async {
    final dataSource = _FakeUserDataSource(
      User(
        id: 1,
        username: 'staff',
        password: md5.convert('staff-password'.codeUnits).toString(),
        role: 'user',
      ),
    );
    final authenticationService = UserAuthenticationService(
      dataSource: dataSource,
      dbWrapper: null,
      isInitialized: () => true,
      getDataSourceType: () => 'sqlite',
      notifyListeners: () {},
      primeCurrentUserPermissions: (_) async {},
      authenticateWithLocalSqlite: (_, __) async => null,
      passwordService: service,
    );

    expect(
      await authenticationService.authenticateWithDataSource(
        dataSource,
        'staff',
        '123456',
      ),
      isNull,
    );

    final user = await authenticationService.authenticateWithDataSource(
      dataSource,
      'staff',
      'staff-password',
    );
    expect(user, isNotNull);
    expect(dataSource.updatedPassword, startsWith('pbkdf2_sha256\$'));
    expect(
      service
          .verifyPassword('staff-password', dataSource.updatedPassword!)
          .isValid,
      isTrue,
    );
  });
}

class _FakeUserDataSource implements UserDataSource {
  _FakeUserDataSource(this.user);

  final User user;
  String? updatedPassword;

  @override
  Future<User?> getUserByUsername(String username) async =>
      username == user.username ? user : null;

  @override
  Future<bool> updateUserPassword(int id, String passwordHash) async {
    updatedPassword = passwordHash;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

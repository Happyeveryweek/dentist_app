import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:dentist_app_windows/features/users/services/password_service.dart';
import 'package:dentist_app_windows/features/users/services/user_validation_service.dart';
import 'package:dentist_app_windows/models/user.dart';
import 'package:dentist_app_windows/providers/user_provider.dart';

class _FakeUserProvider extends UserProvider {
  final List<User> _users;

  _FakeUserProvider(this._users);

  @override
  Future<List<User>> getAllUsers({bool forceRefresh = false}) async => _users;
}

void main() {
  group('用户管理-密码加密', () {
    final passwordService = PasswordService();

    test('相同密码生成不同哈希且都能验证', () {
      final hash1 = passwordService.hashPassword('123456');
      final hash2 = passwordService.hashPassword('123456');

      expect(hash1, isNot(equals(hash2)));
      expect(passwordService.verifyPassword('123456', hash1).isValid, isTrue);
      expect(passwordService.verifyPassword('123456', hash2).isValid, isTrue);
    });

    test('错误密码验证失败', () {
      final hash = passwordService.hashPassword('correct-password');

      expect(
        passwordService.verifyPassword('wrong-password', hash).isValid,
        isFalse,
      );
    });

    test('历史 MD5 和 SHA-256 密码可验证并标记升级', () {
      final md5Hash = md5.convert('legacy-password'.codeUnits).toString();
      final sha256Hash = sha256.convert('legacy-password'.codeUnits).toString();

      for (final hash in [md5Hash, sha256Hash]) {
        final result = passwordService.verifyPassword('legacy-password', hash);
        expect(result.isValid, isTrue);
        expect(result.needsUpgrade, isTrue);
        expect(
          passwordService.verifyPassword('wrong-password', hash).isValid,
          isFalse,
        );
      }
    });

    test('历史明文只匹配自身并标记升级', () {
      final result =
          passwordService.verifyPassword('legacy-password', 'legacy-password');

      expect(result.isValid, isTrue);
      expect(result.needsUpgrade, isTrue);
      expect(
        passwordService
            .verifyPassword('other-password', 'legacy-password')
            .isValid,
        isFalse,
      );
    });

    test('123456 不能通过其他账户的密码验证', () {
      final hash = passwordService.hashPassword('another-password');

      expect(passwordService.verifyPassword('123456', hash).isValid, isFalse);
    });

    test('畸形版本密码串安全失败', () {
      for (final hash in [
        r'pbkdf2_sha256$invalid$salt$hash',
        r'pbkdf2_sha256$0$c2FsdA==$aGFzaA==',
        r'pbkdf2_sha256$100000$not-base64$not-base64',
      ]) {
        expect(
          passwordService.verifyPassword('123456', hash).isValid,
          isFalse,
        );
      }
    });
  });

  group('用户管理-邮箱唯一性校验', () {
    test('邮箱被其他用户占用时返回true', () {
      final provider = _FakeUserProvider([
        User(
          id: 1,
          username: 'admin',
          email: 'admin@example.com',
          password: 'pwd',
          role: 'admin',
        ),
      ]);

      expect(
        UserValidationService.checkEmailExists(
            provider, 'admin@example.com', 2),
        completion(isTrue),
      );
    });

    test('校验当前用户自身邮箱时返回false', () {
      final provider = _FakeUserProvider([
        User(
          id: 1,
          username: 'admin',
          email: 'admin@example.com',
          password: 'pwd',
          role: 'admin',
        ),
      ]);

      expect(
        UserValidationService.checkEmailExists(
            provider, 'admin@example.com', 1),
        completion(isFalse),
      );
    });

    test('邮箱不存在时返回false', () {
      final provider = _FakeUserProvider([
        User(
          id: 1,
          username: 'admin',
          email: 'admin@example.com',
          password: 'pwd',
          role: 'admin',
        ),
      ]);

      expect(
        UserValidationService.checkEmailExists(
            provider, 'other@example.com', null),
        completion(isFalse),
      );
    });
  });

  group('用户管理-用户名唯一性校验', () {
    test('用户名被其他用户占用时返回true', () {
      final provider = _FakeUserProvider([
        User(
          id: 1,
          username: 'admin',
          email: 'admin@example.com',
          password: 'pwd',
          role: 'admin',
        ),
      ]);

      expect(
        UserValidationService.checkUsernameExists(provider, 'admin', 2),
        completion(isTrue),
      );
    });

    test('校验当前用户自身用户名时返回false', () {
      final provider = _FakeUserProvider([
        User(
          id: 1,
          username: 'admin',
          email: 'admin@example.com',
          password: 'pwd',
          role: 'admin',
        ),
      ]);

      expect(
        UserValidationService.checkUsernameExists(provider, 'admin', 1),
        completion(isFalse),
      );
    });
  });
}

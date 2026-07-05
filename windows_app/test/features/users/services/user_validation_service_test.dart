import 'package:flutter_test/flutter_test.dart';
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
    test('相同密码生成一致的SHA256哈希', () {
      final hash1 = UserValidationService.hashPassword('123456');
      final hash2 = UserValidationService.hashPassword('123456');
      expect(hash1, hash2);
      expect(hash1.length, 64);
      expect(hash1, isNot(equals('123456')));
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

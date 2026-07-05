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
  group('UserValidationService', () {
    test('hashPassword returns consistent sha256 hex', () {
      final hash1 = UserValidationService.hashPassword('123456');
      final hash2 = UserValidationService.hashPassword('123456');
      expect(hash1, hash2);
      expect(hash1.length, 64);
      expect(hash1, isNot(equals('123456')));
    });

    test('checkEmailExists returns true when email used by another user', () {
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

    test('checkEmailExists returns false when checking self', () {
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

    test('checkEmailExists returns false when email not found', () {
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

    test('checkUsernameExists returns true when username used by another user',
        () {
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

    test('checkUsernameExists returns false when checking self', () {
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

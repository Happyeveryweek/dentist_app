import 'package:dentist_app/models/user.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('退出登录立即清空唯一当前用户状态', () {
    final provider = UserProvider(
      currentUser: User(
        id: 1,
        username: 'doctor-a',
        password: 'password',
        role: 'doctor',
        doctor: '医生甲',
      ),
    );
    var notifications = 0;
    provider.addListener(() => notifications++);
    final previousRevision = provider.sessionRevision;

    provider.logout();

    expect(provider.currentUser, isNull);
    expect(provider.sessionRevision, previousRevision + 1);
    expect(notifications, greaterThan(0));
  });
}

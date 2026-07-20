import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app_windows/models/user_role.dart';

void main() {
  test('可创建角色具有唯一稳定值与显示信息', () {
    expect(
      UserRole.values.map((role) => role.value),
      ['admin', 'doctor', 'assistant', 'receptionist'],
    );
    expect(
      UserRole.values.map((role) => role.displayName),
      ['管理员', '医生', '助理', '前台'],
    );
  });

  test('assistant 默认不具备业务操作权限', () {
    expect(UserRole.assistant.operationPermissions, isEmpty);
    expect(
      UserRole.assistant.modulePermissions,
      UserRole.defaultModulePermissions,
    );
  });

  test('未知角色不会获得权限', () {
    expect(UserRole.fromValue('nurse'), isNull);
  });
}

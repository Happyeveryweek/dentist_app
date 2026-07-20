import 'package:dentist_app/models/schemas/sqlite_schema.dart';
import 'package:dentist_app/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('管理员模块权限使用统一权限键', () {
    final user = User(
      username: 'admin',
      password: 'password',
      role: UserRole.admin,
    );

    expect(user.allowedModules, ModulePermission.all);
    expect(user.hasModulePermission(ModulePermission.settings), isTrue);
  });

  test('新建患者表不再包含固定医生默认值', () {
    final doctorDefinition =
        SQLitePatientsTableSchema().columnDefinitions['doctor'];

    expect(doctorDefinition, 'VARCHAR(100)');
    expect(doctorDefinition, isNot(contains('申向歌')));
  });
}

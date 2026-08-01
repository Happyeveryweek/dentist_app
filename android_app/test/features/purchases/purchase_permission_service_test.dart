import 'package:dentist_app/features/purchases/services/purchase_permission_service.dart';
import 'package:dentist_app/models/user.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('用户提供者在采购权限服务初始化后绑定时仍可访问采购数据', () {
    final permissionService = PurchasePermissionService();
    final userProvider = UserProvider(
      currentUser: User(
        id: 1,
        username: 'admin',
        email: null,
        password: 'password',
        role: UserRole.admin,
      ),
    );

    expect(permissionService.hasAccess(), isFalse);

    permissionService.setUserProvider(userProvider);

    expect(permissionService.hasAccess(), isTrue);
  });
}

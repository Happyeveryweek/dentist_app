import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app_windows/features/users/services/user_permission_service.dart';
import 'package:dentist_app_windows/features/users/helpers/user_cache_helper.dart';
import 'package:dentist_app_windows/data_sources/user_data_source.dart';
import 'package:dentist_app_windows/models/user.dart';

class _FakeUserDataSource implements UserDataSource {
  final Map<int, Map<String, bool>> _permissions;

  _FakeUserDataSource(this._permissions);

  @override
  Future<List<User>> getAllUsers() async => [];

  @override
  Future<User?> getUserById(int id) async => null;

  @override
  Future<User?> getUserByUsername(String username) async => null;

  @override
  Future<int> createUser(User user) async => 0;

  @override
  Future<bool> updateUser(User user) async => true;

  @override
  Future<bool> deleteUser(int id) async => true;

  @override
  Future<User?> authenticateUser(String username, String password) async => null;

  @override
  Future<int> getUsersCount({String? searchQuery}) async => 0;

  @override
  Future<List<User>> getPaginatedUsers({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'created_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  }) async => [];

  @override
  Future<Map<String, dynamic>> getUserStatistics() async => {};

  @override
  Future<Map<String, bool>> getUserPermissions(int userId) async {
    return _permissions[userId] ?? {'dashboard': true};
  }

  @override
  Future<bool> updateUserPermissions(
    int userId,
    Map<String, bool> permissions,
  ) async {
    _permissions[userId] = Map.from(permissions);
    return true;
  }

  @override
  Future<bool> registerUser(
    String username,
    String? email,
    String hashedPassword,
    String role,
  ) async => true;

  @override
  Future<int> updateUserPassword(int userId, String hashedPassword) async => 0;
}

void main() {
  group('用户管理-权限查询', () {
    test('缓存为空时从数据源读取用户权限', () async {
      final dataSource = _FakeUserDataSource({
        1: {'dashboard': true, 'patients': true},
      });
      final service = UserPermissionService(
        dataSource: dataSource,
        cacheHelper: UserCacheHelper(),
      );

      final permissions = await service.getUserPermissions(1);
      expect(permissions['dashboard'], true);
      expect(permissions['patients'], true);
    });

    test('查询模块权限返回正确布尔值', () async {
      final dataSource = _FakeUserDataSource({
        1: {'dashboard': true, 'patients': false},
      });
      final service = UserPermissionService(
        dataSource: dataSource,
        cacheHelper: UserCacheHelper(),
      );

      expect(await service.hasModulePermission(1, 'dashboard'), true);
      expect(await service.hasModulePermission(1, 'patients'), false);
    });

    test('未知用户默认拥有dashboard权限', () async {
      final dataSource = _FakeUserDataSource({});
      final service = UserPermissionService(
        dataSource: dataSource,
        cacheHelper: UserCacheHelper(),
      );

      final permissions = await service.getUserPermissions(999);
      expect(permissions['dashboard'], true);
    });
  });

  group('用户管理-权限缓存', () {
    test('更新用户权限后清除缓存', () async {
      final dataSource = _FakeUserDataSource({});
      final cacheHelper = UserCacheHelper();
      final service = UserPermissionService(
        dataSource: dataSource,
        cacheHelper: cacheHelper,
      );

      // 预热缓存
      await service.getUserPermissions(1);
      expect(cacheHelper.isPermissionsCacheValid(), true);

      await service.updateUserPermissions(1, {'dashboard': true});
      expect(cacheHelper.isPermissionsCacheValid(), false);
    });

    test('权限变更事件清除对应用户缓存', () async {
      final dataSource = _FakeUserDataSource({
        1: {'dashboard': true},
      });
      final cacheHelper = UserCacheHelper();
      final service = UserPermissionService(
        dataSource: dataSource,
        cacheHelper: cacheHelper,
      );

      await service.getUserPermissions(1);
      service.onPermissionChanged(1, null);
      expect(cacheHelper.cachedPermissions?.containsKey(1), false);
    });
  });
}

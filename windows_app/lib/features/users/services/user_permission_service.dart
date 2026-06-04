import '../../../models/user.dart';
import '../../../data_sources/user_data_source.dart';
import '../helpers/user_cache_helper.dart';

/// 用户权限管理服务
/// 负责权限查询、更新和缓存管理
class UserPermissionService {
  final UserDataSource dataSource;
  final UserCacheHelper cacheHelper;

  UserPermissionService({
    required this.dataSource,
    required this.cacheHelper,
  });

  // 获取用户权限配置
  Future<Map<String, bool>> getUserPermissions(int userId) async {
    try {
      // 检查缓存
      if (cacheHelper.isPermissionsCacheValid() &&
          cacheHelper.cachedPermissions!.containsKey(userId)) {
        print('权限缓存命中，用户ID: $userId');
        return Map.from(cacheHelper.cachedPermissions![userId]!);
      }

      // 从数据源获取权限
      final permissions = await dataSource.getUserPermissions(userId);

      // 更新缓存
      cacheHelper.updatePermissionsCache(userId, permissions);

      return permissions;
    } catch (e) {
      print('获取用户权限失败: $e');

      // 返回默认权限
      return {'dashboard': true};
    }
  }

  // 检查特定模块权限
  Future<bool> hasModulePermission(int userId, String module) async {
    try {
      final permissions = await getUserPermissions(userId);
      return permissions[module] == true;
    } catch (e) {
      print('检查模块权限失败: $e');
      // 仪表盘默认允许访问
      return module == 'dashboard';
    }
  }

  // 更新用户权限配置
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions) async {
    try {
      final success = await dataSource.updateUserPermissions(userId, permissions);

      if (success) {
        // 清除权限缓存
        cacheHelper.clearPermissionsCache();
        print('用户权限更新成功: 用户ID $userId');
      }

      return success;
    } catch (e) {
      print('更新用户权限失败: $e');
      return false;
    }
  }

  // 确保权限数据在用户会话期间保持有效
  Future<void> ensurePermissionsValid(User? currentUser) async {
    if (currentUser == null) return;

    try {
      // 检查权限缓存是否过期
      if (!cacheHelper.isPermissionsCacheValid() &&
          !currentUser.isAdmin &&
          currentUser.id != null) {
        print('权限缓存已过期，重新加载权限');
        await getUserPermissions(currentUser.id!);
      }
    } catch (e) {
      print('确保权限有效性失败: $e');
      // 不抛出异常，使用现有权限继续运行
    }
  }

  // 权限变更时的缓存清理机制
  void onPermissionChanged(int userId, User? currentUser) {
    try {
      // 清除指定用户的权限缓存
      cacheHelper.clearUserPermissionsCache(userId);

      print('权限变更缓存清理完成: 用户ID $userId');
    } catch (e) {
      print('权限变更缓存清理失败: $e');
    }
  }

  // 初始化权限缓存（登录后调用）
  Future<void> initializePermissionsCache(User? currentUser) async {
    if (currentUser == null) return;

    try {
      // 确保权限数据及时更新
      await ensurePermissionsValid(currentUser);
      print('权限缓存初始化完成');
    } catch (e) {
      print('权限缓存初始化失败: $e');
    }
  }
}

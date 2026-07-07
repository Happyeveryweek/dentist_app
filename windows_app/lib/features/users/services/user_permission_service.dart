import '../../../models/user.dart';
import '../../../data_sources/user_data_source.dart';
import '../helpers/user_cache_helper.dart';
import '../../../utils/log_manager.dart';

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
      final cachedPermissions = cacheHelper.cachedPermissions;
      if (cacheHelper.isPermissionsCacheValid() &&
          cachedPermissions != null) {
        final userPermissions = cachedPermissions[userId];
        if (userPermissions != null) {
          return Map.from(userPermissions);
        }
      }

      // 从数据源获取权限
      final permissions = await dataSource.getUserPermissions(userId);

      // 更新缓存
      cacheHelper.updatePermissionsCache(userId, permissions);

      return permissions;
    } catch (e) {
      LogManager.e('UserPermissionService', '获取用户权限失败', error: e);

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
      LogManager.e('UserPermissionService', '检查模块权限失败', error: e);
      // 仪表盘默认允许访问
      return module == 'dashboard';
    }
  }

  // 更新用户权限配置
  Future<bool> updateUserPermissions(
      int userId, Map<String, bool> permissions) async {
    try {
      final success =
          await dataSource.updateUserPermissions(userId, permissions);

      if (success) {
        // 清除权限缓存
        cacheHelper.clearPermissionsCache();
      }

      return success;
    } catch (e) {
      LogManager.e('UserPermissionService', '更新用户权限失败', error: e);
      return false;
    }
  }

  // 确保权限数据在用户会话期间保持有效
  Future<void> ensurePermissionsValid(User? currentUser) async {
    if (currentUser == null) return;

    try {
      // 检查权限缓存是否过期
      final userId = currentUser.id;
      if (!cacheHelper.isPermissionsCacheValid() &&
          !currentUser.isAdmin &&
          userId != null) {
        await getUserPermissions(userId);
      }
    } catch (e) {
      LogManager.e('UserPermissionService', '确保权限有效性失败', error: e);
      // 不抛出异常，使用现有权限继续运行
    }
  }

  // 权限变更时的缓存清理机制
  void onPermissionChanged(int userId, User? currentUser) {
    try {
      // 清除指定用户的权限缓存
      cacheHelper.clearUserPermissionsCache(userId);
    } catch (e) {
      LogManager.e('UserPermissionService', '权限变更缓存清理失败', error: e);
    }
  }

  // 初始化权限缓存（登录后调用）
  Future<void> initializePermissionsCache(User? currentUser) async {
    if (currentUser == null) return;

    try {
      // 确保权限数据及时更新
      await ensurePermissionsValid(currentUser);
    } catch (e) {
      LogManager.e('UserPermissionService', '权限缓存初始化失败', error: e);
    }
  }
}

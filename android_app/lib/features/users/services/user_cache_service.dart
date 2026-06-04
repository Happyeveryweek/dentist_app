import '../../../models/user.dart';
import 'user_list_cache_service.dart';
import 'user_permission_cache_service.dart';

/// 用户缓存管理服务
/// 职责：用户列表缓存、权限缓存管理
class UserCacheService {
  final UserListCacheService _userListCacheService = UserListCacheService();
  final UserPermissionCacheService _permissionCacheService = UserPermissionCacheService();

  // Getters
  bool get hasValidCache => _userListCacheService.hasValidCache;
  DateTime? get lastCacheTime => _userListCacheService.lastCacheTime;
  int get cachedUsersCount => _userListCacheService.cachedUsersCount;

  // 更新用户列表缓存
  void updateCache(List<User> users) {
    _userListCacheService.updateCache(users);
  }

  // 获取缓存的用户列表
  List<User>? getCachedUsers() {
    return _userListCacheService.getCachedUsers();
  }

  // 清除用户列表缓存
  void clearCache() {
    _userListCacheService.clearCache();
  }

  // 检查权限缓存是否有效
  bool isPermissionsCacheValid(int userId) {
    return _permissionCacheService.isPermissionsCacheValid(userId);
  }

  // 获取缓存的权限
  Map<String, bool>? getPermissionsCache(int userId) {
    return _permissionCacheService.getPermissionsCache(userId);
  }

  // 更新权限缓存
  void updatePermissionsCache(int userId, Map<String, bool> permissions) {
    _permissionCacheService.updatePermissionsCache(userId, permissions);
  }

  // 清除权限缓存
  void clearPermissionsCache([int? userId]) {
    _permissionCacheService.clearPermissionsCache(userId);
  }
}

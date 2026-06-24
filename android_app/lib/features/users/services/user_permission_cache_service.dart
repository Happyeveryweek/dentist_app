import '../../../utils/app_logger.dart';

/// 用户权限缓存服务
class UserPermissionCacheService {
  final Map<int, Map<String, bool>> _permissionsCache = {};
  final Map<int, DateTime> _permissionsCacheTime = {};
  static const Duration _permissionsCacheValidDuration = Duration(minutes: 20);

  bool isPermissionsCacheValid(int userId) {
    final cacheTime = _permissionsCacheTime[userId];
    if (cacheTime == null || !_permissionsCache.containsKey(userId)) {
      return false;
    }

    return DateTime.now().difference(cacheTime) <
        _permissionsCacheValidDuration;
  }

  Map<String, bool>? getPermissionsCache(int userId) {
    if (isPermissionsCacheValid(userId)) {
      AppLogger.info('使用缓存的权限数据，用户ID: $userId');
      return _permissionsCache[userId];
    }
    return null;
  }

  void updatePermissionsCache(int userId, Map<String, bool> permissions) {
    _permissionsCache[userId] = permissions;
    _permissionsCacheTime[userId] = DateTime.now();
    AppLogger.info('权限数据已缓存，用户ID: $userId');
  }

  void clearPermissionsCache([int? userId]) {
    if (userId != null) {
      _permissionsCache.remove(userId);
      _permissionsCacheTime.remove(userId);
      AppLogger.info('已清除用户权限缓存，用户ID: $userId');
    } else {
      _permissionsCache.clear();
      _permissionsCacheTime.clear();
      AppLogger.info('已清除所有用户权限缓存');
    }
  }
}

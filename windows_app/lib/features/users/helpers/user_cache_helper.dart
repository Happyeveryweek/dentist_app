import '../../../models/user.dart';

/// 用户缓存管理辅助类
/// 负责用户数据和权限的缓存管理
class UserCacheHelper {
  // 用户缓存
  List<User>? _cachedUsers;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 20);

  // 权限缓存
  Map<int, Map<String, bool>>? _cachedPermissions;
  DateTime? _lastPermissionsCacheTime;
  static const Duration _permissionsCacheValidDuration = Duration(minutes: 20);

  // 检查用户缓存是否有效
  bool isCacheValid() {
    final cacheTime = _lastCacheTime;
    return _cachedUsers != null &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheValidDuration;
  }

  // 检查权限缓存是否有效
  bool isPermissionsCacheValid() {
    final cacheTime = _lastPermissionsCacheTime;
    return _cachedPermissions != null &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) <
            _permissionsCacheValidDuration;
  }

  // 更新用户缓存
  void updateCache(List<User> users) {
    _cachedUsers = List.from(users);
    _lastCacheTime = DateTime.now();
  }

  // 清除用户缓存
  void clearCache() {
    _cachedUsers = null;
    _lastCacheTime = null;
  }

  // 更新权限缓存
  void updatePermissionsCache(int userId, Map<String, bool> permissions) {
    final cached = _cachedPermissions ??= {};
    cached[userId] = Map.from(permissions);
    _lastPermissionsCacheTime = DateTime.now();
  }

  // 清除权限缓存
  void clearPermissionsCache() {
    _cachedPermissions = null;
    _lastPermissionsCacheTime = null;
  }

  // 清除指定用户的权限缓存
  void clearUserPermissionsCache(int userId) {
    final cached = _cachedPermissions;
    cached?.remove(userId);
  }

  // Getters
  bool get hasValidCache => isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedUsersCount => _cachedUsers?.length ?? 0;
  List<User>? get cachedUsers => _cachedUsers;
  Map<int, Map<String, bool>>? get cachedPermissions => _cachedPermissions;
}

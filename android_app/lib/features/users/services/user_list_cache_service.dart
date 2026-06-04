import '../../../models/user.dart';

/// 用户列表缓存服务
class UserListCacheService {
  List<User>? _cachedUsers;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedUsersCount => _cachedUsers?.length ?? 0;

  bool _isCacheValid() {
    return _cachedUsers != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  void updateCache(List<User> users) {
    _cachedUsers = List.from(users);
    _lastCacheTime = DateTime.now();
    print('用户数据缓存已更新: ${users.length} 条记录');
  }

  List<User>? getCachedUsers() {
    if (_isCacheValid()) {
      return _cachedUsers;
    }
    return null;
  }

  void clearCache() {
    _cachedUsers = null;
    _lastCacheTime = null;
    print('用户数据缓存已清除');
  }
}

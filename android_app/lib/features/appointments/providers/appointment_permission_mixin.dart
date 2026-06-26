import '../../../providers/user_provider.dart';

/// 预约权限和过滤管理 mixin
/// 提供权限检查和医生过滤功能
mixin AppointmentPermissionMixin {
  // UserProvider引用（用于权限检查）
  UserProvider? _userProvider;

  // 设置UserProvider引用
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  // 获取医生过滤条件
  String? getDoctorFilter() {
    final provider = _userProvider;
    if (provider == null) return null;
    final currentUser = provider.currentUser;
    if (currentUser == null) {
      return null;
    }

    return provider.buildDoctorFilter(currentUser);
  }

  // 检查是否需要数据过滤
  bool shouldFilterByDoctor() {
    final provider = _userProvider;
    if (provider == null) return false;
    final currentUser = provider.currentUser;
    if (currentUser == null) {
      return false;
    }

    return provider.shouldFilterByDoctor(currentUser);
  }

  // 获取 UserProvider（供子类使用）
  UserProvider? get userProvider => _userProvider;
  set userProvider(UserProvider? value) => _userProvider = value;
}

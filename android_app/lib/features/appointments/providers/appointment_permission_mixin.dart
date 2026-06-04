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
    if (_userProvider?.currentUser == null) {
      return null;
    }

    return _userProvider!.buildDoctorFilter(_userProvider!.currentUser);
  }

  // 检查是否需要数据过滤
  bool shouldFilterByDoctor() {
    if (_userProvider?.currentUser == null) {
      return false;
    }

    return _userProvider!.shouldFilterByDoctor(_userProvider!.currentUser);
  }

  // 获取 UserProvider（供子类使用）
  UserProvider? get userProvider => _userProvider;
  set userProvider(UserProvider? value) => _userProvider = value;
}

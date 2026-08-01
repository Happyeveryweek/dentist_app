import 'package:dentist_app/providers/user_provider.dart';

/// 采购数据权限服务
/// 职责：医生过滤条件获取、权限判断
class PurchasePermissionService {
  UserProvider? _userProvider;

  PurchasePermissionService({UserProvider? userProvider})
    : _userProvider = userProvider;

  /// 初始化时用户提供者可能尚未完成绑定，允许后续补绑定同一个实例。
  void setUserProvider(UserProvider userProvider) {
    _userProvider = userProvider;
  }

  /// 获取医生过滤条件（用于数据访问权限控制）
  String? getDoctorFilter() {
    final userProvider = _userProvider;
    final currentUser = userProvider?.currentUser;
    if (userProvider == null || currentUser == null) {
      return null;
    }

    return userProvider.buildDoctorFilter(currentUser);
  }

  /// 采购管理需要数据过滤 - 普通用户只能查看自己医生的数据
  bool shouldFilterByDoctor() {
    final currentUser = _userProvider?.currentUser;
    return currentUser?.role == 'doctor' &&
        currentUser?.doctor?.isNotEmpty == true;
  }

  bool hasAccess() {
    final user = _userProvider?.currentUser;
    return user?.role == 'admin' || shouldFilterByDoctor();
  }
}

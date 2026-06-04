import 'package:dentist_app/providers/user_provider.dart';

/// 采购数据权限服务
/// 职责：医生过滤条件获取、权限判断
class PurchasePermissionService {
  final UserProvider? _userProvider;
  
  PurchasePermissionService({UserProvider? userProvider}) 
      : _userProvider = userProvider;
  
  /// 获取医生过滤条件（用于数据访问权限控制）
  String? getDoctorFilter() {
    if (_userProvider == null || _userProvider!.currentUser == null) {
      return null;
    }
    
    return _userProvider!.buildDoctorFilter(_userProvider!.currentUser);
  }
  
  /// 采购管理需要数据过滤 - 普通用户只能查看自己医生的数据
  bool shouldFilterByDoctor() {
    if (_userProvider == null || _userProvider!.currentUser == null) {
      return false;
    }
    
    final currentUser = _userProvider!.currentUser!;
    
    // 管理员不需要数据过滤
    if (currentUser.role == 'admin') {
      return false;
    }
    
    // 采购管理：有医生字段的用户需要数据过滤
    return currentUser.doctor != null && currentUser.doctor!.isNotEmpty;
  }
}

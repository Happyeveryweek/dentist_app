import '../../../models/user.dart';
import '../../../data_sources/user_data_source.dart';
import 'user_cache_service.dart';
import '../../../utils/app_logger.dart';

/// 用户权限控制服务
/// 职责：权限获取、权限检查、权限更新、医生过滤条件
class UserPermissionService {
  final UserDataSource _dataSource;
  final UserCacheService _cacheService;

  UserPermissionService({
    required UserDataSource dataSource,
    required UserCacheService cacheService,
  }) : _dataSource = dataSource,
       _cacheService = cacheService;

  static const _doctorModules = {
    'patients',
    'appointments',
    'financial',
    'purchase',
  };

  static bool canAccessModule(User? user, String module) {
    if (user == null) return false;
    if (module == 'dashboard' || module == 'settings') {
      return user.role != 'user';
    }
    if (user.role == 'admin') return true;
    return user.role == 'doctor' && _doctorModules.contains(module);
  }

  static bool canManageUsers(User? user) => user?.role == 'admin';

  static bool canAccessDoctorData(User? user, String? recordDoctor) {
    if (user?.role == 'admin') return true;
    final doctor = user?.doctor;
    return user?.role == 'doctor' &&
        doctor != null &&
        doctor.isNotEmpty &&
        doctor == recordDoctor;
  }

  /// 获取用户权限配置
  Future<Map<String, bool>?> getUserPermissions(int userId) async {
    // 检查缓存
    final cachedPermissions = _cacheService.getPermissionsCache(userId);
    if (cachedPermissions != null) {
      return cachedPermissions;
    }

    try {
      final permissions = await _dataSource.getUserPermissions(userId);

      if (permissions != null) {
        // 更新缓存
        _cacheService.updatePermissionsCache(userId, permissions);
      }

      return permissions;
    } catch (e) {
      AppLogger.info('获取用户权限失败: $e');
      return null;
    }
  }

  /// 检查用户是否有特定模块的权限
  Future<bool> hasModulePermission(
    int userId,
    String module,
    Future<User?> Function(int) getUserById,
  ) async {
    final user = await getUserById(userId);
    return canAccessModule(user, module);
  }

  /// 更新用户权限配置
  Future<bool> updateUserPermissions(
    int userId,
    Map<String, bool> permissions,
  ) async {
    try {
      final success = await _dataSource.updateUserPermissions(
        userId,
        permissions,
      );

      if (success) {
        // 清除该用户的权限缓存
        _cacheService.clearPermissionsCache(userId);
        AppLogger.info('用户权限更新成功，已清除缓存，用户ID: $userId');
      }

      return success;
    } catch (e) {
      AppLogger.info('更新用户权限失败: $e');
      return false;
    }
  }

  /// 清除用户权限缓存
  void clearPermissionsCache(int userId) {
    _cacheService.clearPermissionsCache(userId);
  }

  /// 构建医生过滤条件（用于数据访问权限控制）
  String? buildDoctorFilter(User? user) {
    if (user == null) return null;

    final doctor = user.doctor;
    if (user.role == 'doctor' && doctor != null && doctor.isNotEmpty) {
      return doctor;
    }

    return null;
  }

  bool shouldFilterByDoctor(User? user) {
    return user?.role == 'doctor' && user?.doctor?.isNotEmpty == true;
  }
}

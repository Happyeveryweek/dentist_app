import '../../../models/user.dart';
import 'user_permission_service.dart';
import '../../../utils/app_logger.dart';

/// 当前用户权限服务
class UserCurrentPermissionService {
  final UserPermissionService? _permissionService;
  final User? Function() _currentUserGetter;
  final Future<User?> Function(int) _getUserById;

  UserCurrentPermissionService({
    required UserPermissionService? permissionService,
    required User? Function() currentUserGetter,
    required Future<User?> Function(int) getUserById,
  }) : _permissionService = permissionService,
       _currentUserGetter = currentUserGetter,
       _getUserById = getUserById;

  Future<void> primeCurrentUserPermissions(User currentUser) async {
    if (currentUser.id == null) {
      AppLogger.info('当前用户为空或ID无效，无法加载权限');
      return;
    }

    try {
      if (_permissionService == null) return;
      final permissions = await _permissionService.getUserPermissions(
        currentUser.id!,
      );
      if (permissions != null) {
        AppLogger.info('当前用户权限加载成功，用户ID: ${currentUser.id}');
        AppLogger.info('权限配置: $permissions');
      } else {
        AppLogger.info('当前用户无权限配置，用户ID: ${currentUser.id}');
      }
    } catch (e) {
      AppLogger.info('加载当前用户权限失败: $e');
      rethrow;
    }
  }

  Future<void> loadCurrentUserPermissions() async {
    final currentUser = _currentUserGetter();
    if (currentUser == null || currentUser.id == null) {
      AppLogger.info('当前用户为空或ID无效，无法加载权限');
      return;
    }

    await primeCurrentUserPermissions(currentUser);
  }

  Future<void> refreshCurrentUserPermissions() async {
    final currentUser = _currentUserGetter();
    if (currentUser == null || currentUser.id == null) {
      AppLogger.info('当前用户为空或ID无效，无法刷新权限');
      return;
    }

    try {
      if (_permissionService == null) return;
      _permissionService.clearPermissionsCache(currentUser.id!);
      await primeCurrentUserPermissions(currentUser);
      AppLogger.info('当前用户权限刷新成功，用户ID: ${currentUser.id}');
    } catch (e) {
      AppLogger.info('刷新当前用户权限失败: $e');
      rethrow;
    }
  }

  Future<bool> hasCurrentUserModulePermission(String module) async {
    final currentUser = _currentUserGetter();
    if (currentUser == null || currentUser.id == null) {
      return false;
    }

    if (_permissionService == null) return false;
    return await _permissionService.hasModulePermission(
      currentUser.id!,
      module,
      _getUserById,
    );
  }

  Future<Map<String, bool>?> getCurrentUserPermissions() async {
    final currentUser = _currentUserGetter();
    if (currentUser == null || currentUser.id == null) {
      return null;
    }

    if (_permissionService == null) return null;
    return await _permissionService.getUserPermissions(currentUser.id!);
  }
}

import '../../../models/user.dart';
import '../../../data_sources/user_data_source.dart';
import 'user_cache_service.dart';

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
      print('获取用户权限失败: $e');
      return null;
    }
  }

  /// 检查用户是否有特定模块的权限
  Future<bool> hasModulePermission(int userId, String module, Future<User?> Function(int) getUserById) async {
    // 管理员拥有所有权限
    final user = await getUserById(userId);
    if (user?.role == 'admin') {
      return true;
    }
    
    // 仪表盘对所有用户可见
    if (module == 'dashboard') {
      return true;
    }
    
    final permissions = await getUserPermissions(userId);
    if (permissions == null) {
      return false; // 如果没有权限配置，默认无权限
    }
    
    return permissions[module] == true;
  }

  /// 更新用户权限配置
  Future<bool> updateUserPermissions(int userId, Map<String, bool> permissions) async {
    try {
      final success = await _dataSource.updateUserPermissions(userId, permissions);
      
      if (success) {
        // 清除该用户的权限缓存
        _cacheService.clearPermissionsCache(userId);
        print('用户权限更新成功，已清除缓存，用户ID: $userId');
      }
      
      return success;
    } catch (e) {
      print('更新用户权限失败: $e');
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
    
    // 管理员不受数据过滤限制
    if (user.role == 'admin') {
      return null;
    }
    
    // 普通用户只能查看自己医生字段匹配的数据
    if (user.doctor != null && user.doctor!.isNotEmpty) {
      return user.doctor!;
    }
    
    return null;
  }

  /// Android端不需要数据查看过滤 - 权限控制只在编辑/删除时生效
  bool shouldFilterByDoctor(User? user) {
    // Android端：所有用户都能查看所有数据，权限控制只在操作时生效
    return false;
  }
}

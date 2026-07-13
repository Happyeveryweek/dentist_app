import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../theme/theme_context_extensions.dart';

/// 权限工具类
/// 提供通用的权限检查方法和UI组件
class PermissionUtils {
  /// 检查当前用户是否可以编辑（通用权限）
  static bool canEdit(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    // 管理员可以编辑
    if (currentUser?.isAdmin == true) {
      return true;
    }

    // 普通用户不能编辑
    return false;
  }

  /// 检查当前用户是否可以编辑特定医生的数据
  static bool canEditDoctor(BuildContext context, String? doctorName) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    // 管理员可以编辑所有数据
    if (currentUser?.isAdmin == true) {
      return true;
    }

    // 普通用户只能编辑自己医生的数据
    if (currentUser?.doctor != null && currentUser?.doctor == doctorName) {
      return true;
    }

    return false;
  }

  /// 检查当前用户是否可以删除（通用权限）
  static bool canDelete(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    // 管理员可以删除
    if (currentUser?.isAdmin == true) {
      return true;
    }

    // 普通用户不能删除
    return false;
  }

  /// 检查当前用户是否可以删除特定医生的数据
  static bool canDeleteDoctor(BuildContext context, String? doctorName) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    // 管理员可以删除所有数据
    if (currentUser?.isAdmin == true) {
      return true;
    }

    // 普通用户只能删除自己医生的数据
    if (currentUser?.doctor != null && currentUser?.doctor == doctorName) {
      return true;
    }

    return false;
  }

  /// 检查当前用户是否可以创建
  static bool canCreate(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    // 所有登录用户都可以创建（管理员和普通用户）
    return currentUser != null;
  }

  /// 检查当前用户是否有特定模块权限
  static bool hasModulePermission(BuildContext context, String module) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    if (currentUser == null) return false;

    // 管理员有所有权限
    if (currentUser.isAdmin) return true;

    // 检查模块权限
    return currentUser.hasModulePermission(module);
  }

  /// 显示权限不足提示
  static void showPermissionDeniedDialog(BuildContext context,
      {String? message}) {
    final tokens = context.tokens;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: tokens.warning),
            const SizedBox(width: 8),
            const Text('权限不足'),
          ],
        ),
        content: Text(message ?? '您没有执行此操作的权限，请联系管理员。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 显示权限不足的SnackBar
  static void showPermissionDeniedSnackBar(BuildContext context,
      {String? message}) {
    final tokens = context.tokens;
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.warning, color: colors.onPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message ?? '权限不足，无法执行此操作'),
            ),
          ],
        ),
        backgroundColor: tokens.warning,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

/// 权限包装组件
/// 根据权限控制子组件的显示和行为
class PermissionWrapper extends StatelessWidget {
  final Widget child;
  final bool requireEdit;
  final bool requireDelete;
  final bool requireCreate;
  final String? requiredModule;
  final Widget? fallback;
  final VoidCallback? onPermissionDenied;
  final bool showPermissionDeniedMessage;

  const PermissionWrapper({
    Key? key,
    required this.child,
    this.requireEdit = false,
    this.requireDelete = false,
    this.requireCreate = false,
    this.requiredModule,
    this.fallback,
    this.onPermissionDenied,
    this.showPermissionDeniedMessage = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool hasPermission = true;

    // 检查编辑权限
    if (requireEdit && !PermissionUtils.canEdit(context)) {
      hasPermission = false;
    }

    // 检查删除权限
    if (requireDelete && !PermissionUtils.canDelete(context)) {
      hasPermission = false;
    }

    // 检查创建权限
    if (requireCreate && !PermissionUtils.canCreate(context)) {
      hasPermission = false;
    }

    // 检查模块权限
    final module = requiredModule;
    if (module != null &&
        !PermissionUtils.hasModulePermission(context, module)) {
      hasPermission = false;
    }

    if (!hasPermission) {
      final onDenied = onPermissionDenied;
      if (onDenied != null) {
        onDenied();
      }

      if (showPermissionDeniedMessage) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          PermissionUtils.showPermissionDeniedSnackBar(context);
        });
      }

      return fallback ?? const SizedBox.shrink();
    }

    return child;
  }
}

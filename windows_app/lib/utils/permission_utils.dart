import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';

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

  /// 检查当前用户是否可以查看
  static bool canView(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;

    // 所有登录用户都可以查看
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('权限不足'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message ?? '权限不足，无法执行此操作'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
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

/// 权限按钮组件
/// 根据权限自动禁用按钮并提供视觉反馈
class PermissionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool requireEdit;
  final bool requireDelete;
  final bool requireCreate;
  final String? requiredModule;
  final String? permissionDeniedMessage;
  final ButtonStyle? style;
  final ButtonStyle? disabledStyle;

  const PermissionButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.requireEdit = false,
    this.requireDelete = false,
    this.requireCreate = false,
    this.requiredModule,
    this.permissionDeniedMessage,
    this.style,
    this.disabledStyle,
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

    return ElevatedButton(
      onPressed: hasPermission
          ? onPressed
          : () {
              PermissionUtils.showPermissionDeniedSnackBar(
                context,
                message: permissionDeniedMessage,
              );
            },
      style: hasPermission ? style : (disabledStyle ?? _getDisabledStyle()),
      child: hasPermission ? child : _getDisabledChild(),
    );
  }

  ButtonStyle _getDisabledStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.grey[300],
      foregroundColor: Colors.grey[600],
      elevation: 0,
    );
  }

  Widget _getDisabledChild() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, size: 16),
        const SizedBox(width: 4),
        if (child is Text) Text((child as Text).data ?? '') else child,
      ],
    );
  }
}

/// 权限图标按钮组件
class PermissionIconButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final bool requireEdit;
  final bool requireDelete;
  final bool requireCreate;
  final String? requiredModule;
  final String? permissionDeniedMessage;
  final String? tooltip;

  const PermissionIconButton({
    Key? key,
    required this.icon,
    this.onPressed,
    this.requireEdit = false,
    this.requireDelete = false,
    this.requireCreate = false,
    this.requiredModule,
    this.permissionDeniedMessage,
    this.tooltip,
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

    return IconButton(
      icon: hasPermission ? icon : const Icon(Icons.lock, color: Colors.grey),
      onPressed: hasPermission
          ? onPressed
          : () {
              PermissionUtils.showPermissionDeniedSnackBar(
                context,
                message: permissionDeniedMessage,
              );
            },
      tooltip: hasPermission ? tooltip : '权限不足',
      color: hasPermission ? null : Colors.grey,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../models/user.dart';
import '../theme/app_theme.dart';

/// 权限工具类 - 提供通用的权限检查方法
class PermissionUtils {
  /// 检查当前用户是否可以创建新记录
  static Future<bool> canCreate(BuildContext context, String module) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null) return false;
    
    // 管理员拥有所有权限
    if (currentUser.role == 'admin') return true;
    
    // 检查模块权限
    return await userProvider.hasCurrentUserModulePermission(module);
  }
  
  /// 检查当前用户是否可以编辑记录
  static Future<bool> canEdit(BuildContext context, String module) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null) return false;
    
    // 管理员拥有所有权限
    if (currentUser.role == 'admin') return true;
    
    // 检查模块权限
    return await userProvider.hasCurrentUserModulePermission(module);
  }
  
  /// 检查当前用户是否可以删除记录
  static Future<bool> canDelete(BuildContext context, String module) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null) return false;
    
    // 管理员拥有所有权限
    if (currentUser.role == 'admin') return true;
    
    // 检查模块权限
    return await userProvider.hasCurrentUserModulePermission(module);
  }
  
  /// 检查当前用户是否可以编辑特定医生的记录
  static Future<bool> canEditDoctor(BuildContext context, String? recordDoctor) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null) return false;
    
    // 管理员拥有所有权限
    if (currentUser.role == 'admin') return true;
    
    // 普通用户只能编辑自己医生字段的记录
    if (recordDoctor == null || recordDoctor.isEmpty) {
      // 如果记录没有医生字段，允许编辑（向后兼容）
      return true;
    }
    
    // 检查医生字段是否匹配
    return currentUser.doctor == recordDoctor;
  }
  
  /// 检查当前用户是否可以删除特定医生的记录
  static Future<bool> canDeleteDoctor(BuildContext context, String? recordDoctor) async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final currentUser = userProvider.currentUser;
    
    if (currentUser == null) return false;
    
    // 管理员拥有所有权限
    if (currentUser.role == 'admin') return true;
    
    // 普通用户只能删除自己医生字段的记录
    if (recordDoctor == null || recordDoctor.isEmpty) {
      // 如果记录没有医生字段，允许删除（向后兼容）
      return true;
    }
    
    // 检查医生字段是否匹配
    return currentUser.doctor == recordDoctor;
  }
  
  /// 显示权限不足的提示
  static void showPermissionDeniedMessage(BuildContext context, {String? customMessage}) {
    final message = customMessage ?? '您没有权限执行此操作';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.lock, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// 权限包装组件 - 根据权限控制子组件的显示和交互
class PermissionWrapper extends StatefulWidget {
  final Widget child;
  final String module;
  final String action; // 'create', 'edit', 'delete'
  final String? recordDoctor; // 记录关联的医生（用于基于医生的权限检查）
  final VoidCallback? onPermissionDenied;
  final bool hideWhenDenied; // 权限不足时是否隐藏组件
  final Widget? deniedWidget; // 权限不足时显示的替代组件
  
  const PermissionWrapper({
    super.key,
    required this.child,
    required this.module,
    required this.action,
    this.recordDoctor,
    this.onPermissionDenied,
    this.hideWhenDenied = false,
    this.deniedWidget,
  });
  
  @override
  State<PermissionWrapper> createState() => _PermissionWrapperState();
}

class _PermissionWrapperState extends State<PermissionWrapper> {
  bool _hasPermission = false;
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }
  
  @override
  void didUpdateWidget(PermissionWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module != widget.module ||
        oldWidget.action != widget.action ||
        oldWidget.recordDoctor != widget.recordDoctor) {
      _checkPermission();
    }
  }
  
  Future<void> _checkPermission() async {
    setState(() {
      _isLoading = true;
    });
    
    bool hasPermission = false;
    
    try {
      switch (widget.action) {
        case 'create':
          hasPermission = await PermissionUtils.canCreate(context, widget.module);
          break;
        case 'edit':
          if (widget.recordDoctor != null) {
            hasPermission = await PermissionUtils.canEditDoctor(context, widget.recordDoctor);
          } else {
            hasPermission = await PermissionUtils.canEdit(context, widget.module);
          }
          break;
        case 'delete':
          if (widget.recordDoctor != null) {
            hasPermission = await PermissionUtils.canDeleteDoctor(context, widget.recordDoctor);
          } else {
            hasPermission = await PermissionUtils.canDelete(context, widget.module);
          }
          break;
        default:
          hasPermission = false;
      }
    } catch (e) {
      print('权限检查失败: $e');
      hasPermission = false;
    }
    
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // 加载中显示原组件但禁用交互
      return IgnorePointer(
        child: Opacity(
          opacity: 0.6,
          child: widget.child,
        ),
      );
    }
    
    if (!_hasPermission) {
      if (widget.hideWhenDenied) {
        return const SizedBox.shrink();
      }
      
      if (widget.deniedWidget != null) {
        return widget.deniedWidget!;
      }
      
      // 显示禁用状态的组件
      return GestureDetector(
        onTap: () {
          if (widget.onPermissionDenied != null) {
            widget.onPermissionDenied!();
          } else {
            PermissionUtils.showPermissionDeniedMessage(context);
          }
        },
        child: Opacity(
          opacity: 0.5,
          child: IgnorePointer(
            child: widget.child,
          ),
        ),
      );
    }
    
    return widget.child;
  }
}

/// 权限按钮组件 - 带有权限检查的按钮
class PermissionButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final String module;
  final String action;
  final String? recordDoctor;
  final String? permissionDeniedMessage;
  
  const PermissionButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.module,
    required this.action,
    this.recordDoctor,
    this.permissionDeniedMessage,
  });
  
  @override
  Widget build(BuildContext context) {
    return PermissionWrapper(
      module: module,
      action: action,
      recordDoctor: recordDoctor,
      onPermissionDenied: () {
        PermissionUtils.showPermissionDeniedMessage(
          context,
          customMessage: permissionDeniedMessage,
        );
      },
      child: GestureDetector(
        onTap: onPressed,
        child: child,
      ),
    );
  }
}
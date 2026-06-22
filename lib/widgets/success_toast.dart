import 'package:flutter/material.dart';

/// Toast 类型枚举
enum AppToastType {
  success,
  error,
  info,
  delete,
}

/// 统一的 Toast 组件
/// 通过 type 参数区分不同类型的提示
class AppToast extends StatelessWidget {
  final String message;
  final AppToastType type;
  final Duration duration;
  final VoidCallback? onDismiss;

  const AppToast({
    super.key,
    required this.message,
    this.type = AppToastType.success,
    this.duration = const Duration(seconds: 2),
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getToastConfig(type);
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: config.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            config.icon,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
        ],
      ),
    );
  }

  _ToastConfig _getToastConfig(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return _ToastConfig(
          color: Colors.green.shade600,
          icon: Icons.check_circle_outline,
        );
      case AppToastType.error:
        return _ToastConfig(
          color: Colors.red.shade500,
          icon: Icons.error_outline,
        );
      case AppToastType.info:
        return _ToastConfig(
          color: Colors.blue.shade600,
          icon: Icons.info_outline,
        );
      case AppToastType.delete:
        return _ToastConfig(
          color: Colors.orange.shade600,
          icon: Icons.delete_outline,
        );
    }
  }
}

class _ToastConfig {
  final Color color;
  final IconData icon;

  const _ToastConfig({
    required this.color,
    required this.icon,
  });
}

/// 统一的 Toast 管理器
/// 使用 SnackBar 在页面底部显示提示，支持多种类型
class AppToastManager {
  static void show(
    BuildContext context, {
    required String message,
    AppToastType type = AppToastType.success,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onDismiss,
  }) {
    final config = _getToastConfig(type);
    
    // 移除之前的提示（如果存在）
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    // 显示新的提示
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              config.icon,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (onDismiss != null)
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onDismiss?.call();
                },
                icon: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
          ],
        ),
        backgroundColor: config.color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message: message,
      type: AppToastType.success,
      duration: duration,
      onDismiss: onDismiss,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message: message,
      type: AppToastType.error,
      duration: duration,
      onDismiss: onDismiss,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message: message,
      type: AppToastType.info,
      duration: duration,
      onDismiss: onDismiss,
    );
  }

  static void showDelete(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
    VoidCallback? onDismiss,
  }) {
    show(
      context,
      message: message,
      type: AppToastType.delete,
      duration: duration,
      onDismiss: onDismiss,
    );
  }

  static _ToastConfig _getToastConfig(AppToastType type) {
    switch (type) {
      case AppToastType.success:
        return _ToastConfig(
          color: Colors.green.shade600,
          icon: Icons.check_circle_outline,
        );
      case AppToastType.error:
        return _ToastConfig(
          color: Colors.red.shade500,
          icon: Icons.error_outline,
        );
      case AppToastType.info:
        return _ToastConfig(
          color: Colors.blue.shade600,
          icon: Icons.info_outline,
        );
      case AppToastType.delete:
        return _ToastConfig(
          color: Colors.orange.shade600,
          icon: Icons.delete_outline,
        );
    }
  }
}






/// 公共删除确认框组件
/// 现代化设计风格，简洁美观
class DeleteConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? itemName;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String confirmText;
  final String cancelText;

  const DeleteConfirmDialog({
    super.key,
    this.title = '确认删除',
    required this.message,
    this.itemName,
    this.onConfirm,
    this.onCancel,
    this.confirmText = '删除',
    this.cancelText = '取消',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 340,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部区域
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: Column(
                children: [
                  // 图标
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade500,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade300.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 标题
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // 描述文本
                  Text(
                    itemName != null ? message.replaceAll('{itemName}', itemName!) : message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 警告提示
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.shade100,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade500,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '此操作不可撤销',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 分割线
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade200,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            
            // 按钮区域
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onCancel ?? () => Navigator.of(context).pop(false),
                          child: Center(
                            child: Text(
                              cancelText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 确认按钮
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.red.shade400,
                            Colors.red.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade300.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onConfirm ?? () => Navigator.of(context).pop(true),
                          child: Center(
                            child: Text(
                              confirmText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 删除确认框管理器
/// 提供便捷的显示方法
class DeleteConfirmDialogManager {
  /// 显示删除确认框
  /// 返回 true 表示用户确认删除，false 表示取消
  static Future<bool> show(
    BuildContext context, {
    String title = '确认删除',
    required String message,
    String? itemName,
    String confirmText = '删除',
    String cancelText = '取消',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => DeleteConfirmDialog(
        title: title,
        message: message,
        itemName: itemName,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
    return result ?? false;
  }

  /// 显示通用的删除确认框
  /// 适用于大多数删除场景
  static Future<bool> showGeneric(
    BuildContext context, {
    required String itemType,
    String? itemName,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除{itemName}吗？此操作不可撤销。',
      itemName: itemName ?? itemType,
    );
  }

  /// 显示用户删除确认框
  static Future<bool> showUserDelete(
    BuildContext context, {
    required String username,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除用户"$username"吗？此操作不可撤销。',
    );
  }

  /// 显示患者删除确认框
  static Future<bool> showPatientDelete(
    BuildContext context, {
    required String patientName,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除患者"$patientName"吗？此操作不可撤销。',
    );
  }

  /// 显示材料删除确认框
  static Future<bool> showMaterialDelete(
    BuildContext context, {
    required String materialName,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除材料"$materialName"吗？此操作不可撤销。',
    );
  }

  /// 显示预约删除确认框
  static Future<bool> showAppointmentDelete(
    BuildContext context, {
    required String appointmentInfo,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除预约"$appointmentInfo"吗？此操作不可撤销。',
    );
  }

  /// 显示财务记录删除确认框
  static Future<bool> showFinancialRecordDelete(
    BuildContext context, {
    required String patientName,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除患者"$patientName"的财务记录吗？此操作不可撤销。',
    );
  }

  /// 显示采购记录删除确认框
  static Future<bool> showPurchaseRecordDelete(
    BuildContext context, {
    required String purchaseInfo,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除采购记录"$purchaseInfo"吗？此操作不可撤销。',
    );
  }
}

/// 通用错误对话框（与应用风格保持一致）
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;

  const ErrorDialog({
    super.key,
    this.title = '错误',
    required this.message,
    this.buttonText = '知道了',
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Text(
            buttonText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class ErrorDialogManager {
  static Future<void> show(BuildContext context, {String title = '错误', required String message, String buttonText = '知道了'}) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => ErrorDialog(title: title, message: message, buttonText: buttonText),
    );
  }
}

/// 退出登录确认框组件
/// 现代化设计风格，简洁美观
class LogoutConfirmDialog extends StatelessWidget {
  final String? username;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String confirmText;
  final String cancelText;

  const LogoutConfirmDialog({
    super.key,
    this.username,
    this.onConfirm,
    this.onCancel,
    this.confirmText = '退出登录',
    this.cancelText = '取消',
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 320,
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              spreadRadius: 0,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部区域
            Container(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
              child: Column(
                children: [
                  // 图标
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.red.shade400,
                          Colors.red.shade500,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade300.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 标题
                  Text(
                    '退出登录',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // 描述文本
                  Text(
                    '确认要退出登录吗？',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  
                  // 用户名显示（如果有的话）
                  if (username != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blue.shade100,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade500,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            username!,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // 分割线
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.grey.shade200,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            
            // 按钮区域
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // 取消按钮
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onCancel ?? () => Navigator.of(context).pop(false),
                          child: Center(
                            child: Text(
                              cancelText,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // 确认按钮
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.red.shade400,
                            Colors.red.shade500,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade300.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onConfirm ?? () => Navigator.of(context).pop(true),
                          child: Center(
                            child: Text(
                              confirmText,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 退出登录确认框管理器
/// 提供便捷的显示方法
class LogoutConfirmDialogManager {
  /// 显示退出登录确认框
  /// 返回 true 表示用户确认退出，false 表示取消
  static Future<bool> show(
    BuildContext context, {
    String? username,
    String confirmText = '退出登录',
    String cancelText = '取消',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => LogoutConfirmDialog(
        username: username,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
    return result ?? false;
  }

  /// 显示带用户名的退出登录确认框
  static Future<bool> showWithUsername(
    BuildContext context, {
    required String username,
    String confirmText = '退出登录',
    String cancelText = '取消',
  }) async {
    return show(
      context,
      username: username,
      confirmText: confirmText,
      cancelText: cancelText,
    );
  }
}

/// 内联成功提示组件
/// 用于在对话框或页面内部显示短暂的成功提示
/// 显示在指定位置，不使用SnackBar
class InlineSuccessMessage extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback? onDismiss;
  final bool isDelete; // 是否是删除操作

  const InlineSuccessMessage({
    super.key,
    required this.message,
    this.duration = const Duration(seconds: 2),
    this.onDismiss,
    this.isDelete = false,
  });

  @override
  State<InlineSuccessMessage> createState() => _InlineSuccessMessageState();
}

class _InlineSuccessMessageState extends State<InlineSuccessMessage> {
  @override
  void initState() {
    super.initState();
    // 自动消失
    Future.delayed(widget.duration, () {
      if (mounted) {
        widget.onDismiss?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDelete ? Colors.orange.shade600 : Colors.green.shade600,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isDelete ? Icons.delete_outline : Icons.check_circle,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
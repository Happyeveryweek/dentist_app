import 'package:flutter/material.dart';

/// 公共删除确认框组件
/// 使用统一的样式设计，支持自定义标题、内容和操作
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
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.delete_forever, color: Colors.red.shade600, size: 24),
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red.shade600, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                itemName != null ? message.replaceAll('{itemName}', itemName!) : message,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          child: Text(
            cancelText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: onConfirm ?? () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          child: Text(
            confirmText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
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

  /// 显示采购项目删除确认框
  static Future<bool> showPurchaseItemDelete(
    BuildContext context, {
    required String itemName,
  }) async {
    return show(
      context,
      title: '确认删除',
      message: '您确定要删除采购项目"$itemName"吗？此操作不可撤销。',
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
  }) async {
    return show(context, username: username);
  }
}

/// 现代化删除确认弹出框组件
/// 设计风格：美观、现代化、简约、时尚
class ModernDeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? itemName;
  final String? itemType;
  final VoidCallback? onConfirm;
  final VoidCallback? onCancel;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final Color? accentColor;

  const ModernDeleteDialog({
    super.key,
    this.title = '确认删除',
    required this.message,
    this.itemName,
    this.itemType,
    this.onConfirm,
    this.onCancel,
    this.confirmText = '删除',
    this.cancelText = '取消',
    this.icon,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveAccentColor = accentColor ?? Colors.red.shade500;
    final effectiveIcon = icon ?? Icons.delete_forever_rounded;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部装饰条
            Container(
              height: 6,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    effectiveAccentColor,
                    effectiveAccentColor.withOpacity(0.7),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
            ),
            
            // 主要内容
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // 图标
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: effectiveAccentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: effectiveAccentColor.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      effectiveIcon,
                      color: effectiveAccentColor,
                      size: 36,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // 标题
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // 项目信息（如果有的话）
                  if (itemName != null || itemType != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: effectiveAccentColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: effectiveAccentColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: effectiveAccentColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (itemType != null)
                                  Text(
                                    itemType!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: effectiveAccentColor.withOpacity(0.7),
                                    ),
                                  ),
                                if (itemName != null)
                                  Text(
                                    itemName!,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade800,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  
                  // 描述文本
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // 操作按钮
                  Row(
                    children: [
                      // 取消按钮
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: onCancel ?? () => Navigator.of(context).pop(),
                              child: Center(
                                child: Text(
                                  cancelText,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // 确认删除按钮
                      Expanded(
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                effectiveAccentColor,
                                effectiveAccentColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: effectiveAccentColor.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: onConfirm ?? () => Navigator.of(context).pop(true),
                              child: Center(
                                child: Text(
                                  confirmText,
                                  style: const TextStyle(
                                    fontSize: 16,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 现代化删除确认弹出框管理器
/// 提供便捷的显示方法和预设配置
class ModernDeleteDialogManager {
  /// 显示删除确认弹出框
  /// 返回 true 表示用户确认删除，false 表示取消
  static Future<bool> show(
    BuildContext context, {
    String title = '确认删除',
    required String message,
    String? itemName,
    String? itemType,
    String confirmText = '删除',
    String cancelText = '取消',
    IconData? icon,
    Color? accentColor,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => ModernDeleteDialog(
        title: title,
        message: message,
        itemName: itemName,
        itemType: itemType,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        accentColor: accentColor,
      ),
    );
    return result ?? false;
  }

  /// 显示患者删除确认弹出框
  static Future<bool> showPatientDelete(
    BuildContext context, {
    required String patientName,
  }) async {
    return show(
      context,
      title: '删除患者',
      message: '您确定要删除这名患者吗？\n删除后将无法恢复相关数据。',
      itemName: patientName,
      itemType: '患者信息',
      icon: Icons.person_remove_rounded,
      accentColor: Colors.red.shade500,
    );
  }

  /// 显示预约删除确认弹出框
  static Future<bool> showAppointmentDelete(
    BuildContext context, {
    required String appointmentInfo,
  }) async {
    return show(
      context,
      title: '删除预约',
      message: '您确定要删除这个预约吗？\n删除后将无法恢复预约记录。',
      itemName: appointmentInfo,
      itemType: '预约记录',
      icon: Icons.event_busy_rounded,
      accentColor: Colors.orange.shade500,
    );
  }

  /// 显示财务记录删除确认弹出框
  static Future<bool> showFinancialDelete(
    BuildContext context, {
    required String financialInfo,
  }) async {
    return show(
      context,
      title: '删除财务记录',
      message: '您确定要删除这条财务记录吗？\n删除后将无法恢复财务数据。',
      itemName: financialInfo,
      itemType: '财务记录',
      icon: Icons.account_balance_wallet_rounded,
      accentColor: Colors.green.shade500,
    );
  }

  /// 显示采购记录删除确认弹出框
  static Future<bool> showPurchaseDelete(
    BuildContext context, {
    required String purchaseInfo,
  }) async {
    return show(
      context,
      title: '删除采购记录',
      message: '您确定要删除这条采购记录吗？\n删除后将无法恢复采购数据。',
      itemName: purchaseInfo,
      itemType: '采购记录',
      icon: Icons.shopping_cart_rounded,
      accentColor: Colors.blue.shade500,
    );
  }

  /// 显示用户删除确认弹出框
  static Future<bool> showUserDelete(
    BuildContext context, {
    required String username,
  }) async {
    return show(
      context,
      title: '删除用户',
      message: '您确定要删除这个用户吗？\n删除后将无法恢复用户数据。',
      itemName: username,
      itemType: '用户账户',
      icon: Icons.person_off_rounded,
      accentColor: Colors.purple.shade500,
    );
  }

  /// 显示通用删除确认弹出框
  static Future<bool> showGeneric(
    BuildContext context, {
    required String itemType,
    String? itemName,
    String? customMessage,
    Color? accentColor,
  }) async {
    final message = customMessage ?? 
        '您确定要删除这个$itemType吗？\n删除后将无法恢复相关数据。';
    
    return show(
      context,
      title: '删除$itemType',
      message: message,
      itemName: itemName,
      itemType: itemType,
      accentColor: accentColor,
    );
  }
}

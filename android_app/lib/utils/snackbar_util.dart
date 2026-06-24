import 'package:flutter/material.dart';

/// SnackBar 工具类
/// 提供统一的 SnackBar 显示方法
class SnackBarUtil {
  /// 显示 SnackBar
  ///
  /// [context] - BuildContext
  /// [message] - 显示的消息
  /// [isSuccess] - 是否为成功消息（默认为 true）
  /// [duration] - 显示时长（默认为 3 秒）
  static void show(
    BuildContext context,
    String message, {
    bool isSuccess = true,
    int duration = 3,
  }) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
      duration: Duration(seconds: duration),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

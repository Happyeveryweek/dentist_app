import 'package:flutter/material.dart';

/// 加载对话框组件
class LoadingDialog {
  /// 显示加载对话框
  static void show(BuildContext context, {String message = '加载中...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(message, style: const TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 隐藏加载对话框
  static void hide(BuildContext context) {
    Navigator.of(context).pop();
  }
}

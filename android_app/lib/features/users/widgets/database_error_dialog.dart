import 'package:flutter/material.dart';

/// 数据库错误对话框组件
class DatabaseErrorDialog extends StatelessWidget {
  final VoidCallback onRetryMySQL;
  final VoidCallback onSwitchToSQLite;

  const DatabaseErrorDialog({
    super.key,
    required this.onRetryMySQL,
    required this.onSwitchToSQLite,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('数据库连接失败'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('无法连接到MySQL数据库，可能的原因：'),
          SizedBox(height: 8),
          Text('• 网络连接不稳定'),
          Text('• MySQL服务器未启动'),
          Text('• 数据库配置错误'),
          SizedBox(height: 12),
          Text('您可以选择：'),
          Text('• 重试MySQL连接'),
          Text('• 切换到SQLite本地数据库'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onRetryMySQL();
          },
          child: const Text('重试MySQL'),
        ),
        ElevatedButton(
          onPressed: () => onSwitchToSQLite(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
          ),
          child: const Text('切换到SQLite'),
        ),
      ],
    );
  }

  /// 显示对话框
  static void show(
    BuildContext context, {
    required VoidCallback onRetryMySQL,
    required VoidCallback onSwitchToSQLite,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DatabaseErrorDialog(
          onRetryMySQL: onRetryMySQL,
          onSwitchToSQLite: onSwitchToSQLite,
        );
      },
    );
  }
}

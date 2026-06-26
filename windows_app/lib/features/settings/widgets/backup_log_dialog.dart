import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_theme.dart';
import '../../../models/backup_log.dart';
import '../../../widgets/success_toast.dart';

/// 备份日志对话框
class BackupLogDialog extends StatelessWidget {
  /// 显示备份日志对话框
  static Future<void> show(BuildContext context) async {
    // 获取备份日志
    final logs = await BackupLog.getLogs();

    if (!context.mounted) return;

    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无备份日志记录')),
      );
      return;
    }

    // 按时间倒序排序
    logs.sort((a, b) => b.backupDate.compareTo(a.backupDate));

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => BackupLogDialog(logs: logs),
    );
  }

  final List<BackupLog> logs;

  const BackupLogDialog({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('备份日志'),
      content: SizedBox(
        width: 600,
        height: 400,
        child: ListView.builder(
          itemCount: logs.length,
          itemBuilder: (context, index) {
            final log = logs[index];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    log.success ? Icons.check_circle : Icons.error,
                    color: log.success
                        ? AppTheme.successColor
                        : AppTheme.errorColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('yyyy-MM-dd HH:mm:ss')
                              .format(log.backupDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        if (log.success)
                          Text('备份路径: ${log.backupPath}')
                        else
                          Text(
                            '错误信息: ${log.errorMessage ?? "未知错误"}',
                            style: const TextStyle(color: AppTheme.errorColor),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorColor,
          ),
          onPressed: () async {
            // 显示确认对话框
            final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认清空'),
                    content: const Text('确定要清空所有备份日志记录吗？此操作不可恢复。'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('确定清空'),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (confirmed && context.mounted) {
              final success = await BackupLog.clearAllLogs();
              if (success && context.mounted) {
                Navigator.pop(context); // 关闭日志对话框
                // 使用公用成功提示组件
                AppToastManager.showSuccess(context, message: '备份日志已清空');
              }
            }
          },
          child: const Text('清空日志'),
        ),
        const SizedBox(width: 8),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

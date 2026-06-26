import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/success_toast.dart';
import '../widgets/database_check_widgets.dart';

/// 结构检测日志对话框
class StructureLogDialog extends StatefulWidget {
  /// 显示结构检测日志对话框
  static Future<void> show(BuildContext context) async {
    if (!context.mounted) return;

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在加载日志...'),
          ],
        ),
      ),
    );

    // 获取数据库提供者和设置提供者
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // 确保SettingsProvider能够访问到数据库实例
    if (dbProvider.initialized) {
      settingsProvider.setDatabaseConnection(
        database: dbProvider.database,
        mysqlConnection: dbProvider.mysqlConnection,
      );
    }

    // 获取结构检测日志
    final logs = await settingsProvider.getDatabaseStructureLogs(limit: 100);

    // 关闭加载对话框
    if (context.mounted) {
      Navigator.of(context).pop();
    }

    // 显示日志列表
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => StructureLogDialog(logs: logs),
      );
    }
  }

  final List<dynamic> logs;

  const StructureLogDialog({super.key, required this.logs});

  @override
  State<StructureLogDialog> createState() => _StructureLogDialogState();
}

class _StructureLogDialogState extends State<StructureLogDialog> {
  Future<void> _refreshLogs() async {
    if (!mounted) return;

    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('正在加载日志...'),
          ],
        ),
      ),
    );

    // 获取数据库提供者和设置提供者
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    // 确保SettingsProvider能够访问到数据库实例
    if (dbProvider.initialized) {
      settingsProvider.setDatabaseConnection(
        database: dbProvider.database,
        mysqlConnection: dbProvider.mysqlConnection,
      );
    }

    // 获取结构检测日志
    final logs = await settingsProvider.getDatabaseStructureLogs(limit: 100);

    // 关闭加载对话框
    if (mounted) {
      Navigator.of(context).pop();
    }

    // 关闭当前对话框并重新显示
    if (mounted) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder: (context) => StructureLogDialog(logs: logs),
      );
    }
  }

  Future<void> _clearAllLogs() async {
    try {
      final confirmed = await DeleteConfirmDialogManager.show(
        context,
        title: '确认清空',
        message: '确定要清空所有检测日志吗？此操作不可恢复。',
        confirmText: '清空',
      );

      if (confirmed == true) {
        if (!mounted) return;
        final settingsProvider =
            Provider.of<SettingsProvider>(context, listen: false);
        final dbProvider =
            Provider.of<DatabaseProvider>(context, listen: false);

        // 确保SettingsProvider能够访问到数据库实例
        if (dbProvider.initialized) {
          settingsProvider.setDatabaseConnection(
            database: dbProvider.database,
            mysqlConnection: dbProvider.mysqlConnection,
          );
        }

        final success = await settingsProvider.clearAllDatabaseStructureLogs();

        if (success) {
          if (!mounted) return;
          // 使用公用成功提示组件
          AppToastManager.showSuccess(context, message: '所有日志已清空');
          _refreshLogs();
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('清空日志失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清空失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('数据库结构检测日志'),
      content: SizedBox(
        width: 600,
        height: 500,
        child: Column(
          children: [
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('共 ${widget.logs.length} 条记录'),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('刷新'),
                      onPressed: _refreshLogs,
                    ),
                    if (widget.logs.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('清空'),
                        onPressed: _clearAllLogs,
                      ),
                  ],
                ),
              ],
            ),
            const Divider(),
            // 日志列表
            Expanded(
              child: widget.logs.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.info_outline,
                              size: 48, color: Colors.blue),
                          SizedBox(height: 16),
                          Text('暂无检测日志'),
                          SizedBox(height: 8),
                          Text('执行数据库结构检测后将在此显示记录'),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.logs.length,
                      itemBuilder: (context, index) {
                        final log = widget.logs[index];
                        return DatabaseCheckWidgets.buildLogItem(context, log,
                            () {
                          Navigator.of(context).pop();
                          DatabaseCheckWidgets.showLogDetails(
                              context, log, () => _refreshLogs());
                        });
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

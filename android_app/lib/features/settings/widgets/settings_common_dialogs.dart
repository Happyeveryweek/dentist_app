import 'package:flutter/material.dart';

import 'package:dentist_app/theme/app_theme.dart';

class SettingsCommonDialogs {
  static void showSuccessDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
    );
  }

  static Future<bool?> showDatabaseSwitchConfirmDialog(
    BuildContext context,
    String dbType,
  ) async {
    final isSqlite = dbType == 'sqlite';
    final typeName = isSqlite ? 'SQLite' : 'MySQL';
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.42),
      builder:
          (context) => Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.lightText.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isSqlite ? Icons.storage_rounded : Icons.cloud_outlined,
                        color: AppTheme.primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('切换到 $typeName', style: AppTheme.titleStyle),
                          const SizedBox(height: 4),
                          Text(
                            isSqlite ? '使用当前设备的本地数据库' : '使用远程 MySQL 数据库',
                            style: AppTheme.bodyStyle,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isSqlite
                              ? '确认后立即切换，本地数据库中的数据将用于当前业务。'
                              : '请先填写连接信息并测试连接，保存配置后才能正式生效。',
                          style: AppTheme.bodyStyle.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('取消'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('确认切换'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
    );
  }

  static Future<bool?> showConfirmDatabaseDialog(
    BuildContext context,
    String fileName,
    String filePath,
  ) async {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('确认选择数据库'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('确定要使用以下数据库文件吗？'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '文件名: $fileName',
                        style: const TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '路径: $filePath',
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('确认'),
              ),
            ],
          ),
    );
  }
}

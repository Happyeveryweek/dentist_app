import 'dart:io';
import 'package:flutter/material.dart';

import '../../../providers/settings_provider.dart';
import '../../../utils/app_paths.dart';

/// 数据存储位置辅助类
/// 提供获取和打开数据存储位置的功能
class DataStorageLocationHelper {
  /// 获取数据存储位置
  static String getDataStorageLocation(SettingsProvider settingsProvider) {
    // 如果配置了SQLite数据源且有自定义数据库路径
    if (settingsProvider.dataSourceType == 'sqlite' &&
        settingsProvider.customSqliteDbPath.isNotEmpty) {
      return settingsProvider.customSqliteDbPath;
    }

    // 如果配置了MySQL数据源
    if (settingsProvider.dataSourceType == 'mysql' &&
        settingsProvider.isMySQLSettingsComplete()) {
      final mysqlSettings = settingsProvider.getCompleteMySQLSettings();
      return 'MySQL: ${mysqlSettings['host']}:${mysqlSettings['port']}/${mysqlSettings['database']}';
    }

    // 默认返回本地数据目录
    return '默认位置: ${AppPaths.dataDirectory}';
  }

  /// 打开数据存储位置
  static Future<void> openDataStorageLocation(
    BuildContext context,
    SettingsProvider settingsProvider,
  ) async {
    try {
      String pathToOpen;

      // 如果配置了SQLite数据源且有自定义数据库路径
      if (settingsProvider.dataSourceType == 'sqlite' &&
          settingsProvider.customSqliteDbPath.isNotEmpty) {
        // 获取数据库文件的目录
        final dbFile = File(settingsProvider.customSqliteDbPath);
        pathToOpen = dbFile.parent.path;

        // 检查文件是否存在
        if (!await dbFile.exists()) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('数据库文件不存在: ${settingsProvider.customSqliteDbPath}'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
      } else if (settingsProvider.dataSourceType == 'mysql') {
        // MySQL是远程数据库，无法直接打开，显示提示
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MySQL是远程数据库，无法直接打开文件位置'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      } else {
        // 默认打开本地数据目录
        pathToOpen = AppPaths.dataDirectory;
      }

      await Process.run('explorer', [pathToOpen]);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开目录: $e')),
      );
    }
  }
}

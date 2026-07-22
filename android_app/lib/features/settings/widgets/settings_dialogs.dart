import 'package:flutter/material.dart';

import 'settings_common_dialogs.dart';
import 'sqlite_config_dialogs.dart';

/// 设置页对话框入口
/// 仅保留对外稳定 API，具体实现拆分到各自职责文件。
class SettingsDialogs {
  static void showSuccessDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    SettingsCommonDialogs.showSuccessDialog(context, title, message);
  }

  static Future<void> showSqliteActivatedDialog(BuildContext context) {
    return SqliteConfigDialogs.showSqliteActivatedDialog(context);
  }

  static Future<void> showSqliteConfigSavedDialog(
    BuildContext context,
    String fileName,
    String filePath,
  ) {
    return SqliteConfigDialogs.showSqliteConfigSavedDialog(
      context,
      fileName,
      filePath,
    );
  }

  static Future<bool?> showMySqlConfigSavedDialog(
    BuildContext context,
    String effectiveHost,
  ) {
    return SqliteConfigDialogs.showMySqlConfigSavedDialog(
      context,
      effectiveHost,
    );
  }

  static Future<bool?> showDatabaseSwitchConfirmDialog(
    BuildContext context,
    String dbType,
  ) {
    return SettingsCommonDialogs.showDatabaseSwitchConfirmDialog(
      context,
      dbType,
    );
  }

  static Future<bool?> showConfirmDatabaseDialog(
    BuildContext context,
    String fileName,
    String filePath,
  ) {
    return SettingsCommonDialogs.showConfirmDatabaseDialog(
      context,
      fileName,
      filePath,
    );
  }
}

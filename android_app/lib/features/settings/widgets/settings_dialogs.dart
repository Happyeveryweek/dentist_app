import 'package:flutter/material.dart';

import 'settings_backup_restore_dialogs.dart';
import 'settings_common_dialogs.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/providers/database_provider.dart';
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

  static Future<void> showBackupDialog(
    BuildContext context, {
    required DatabaseConfig dbConfig,
    required String dbPath,
    required String dbType,
    required Function(VoidCallback) setState,
    required Function(String, {bool isSuccess}) showSnackBar,
    required bool Function() mounted,
  }) {
    return SettingsBackupRestoreDialogs.showBackupDialog(
      context,
      dbConfig: dbConfig,
      dbPath: dbPath,
      dbType: dbType,
      setState: setState,
      showSnackBar: showSnackBar,
      mounted: mounted,
    );
  }

  static Future<void> showRestoreDialog(
    BuildContext context, {
    required DatabaseProvider? dbProvider,
    required DatabaseConfig dbConfig,
    required String dbPath,
    required String dbType,
    required Future<bool> Function() requestStoragePermission,
    required Function(VoidCallback) setState,
    required Function(String, {bool isSuccess}) showSnackBar,
    required bool Function() mounted,
  }) {
    return SettingsBackupRestoreDialogs.showRestoreDialog(
      context,
      dbProvider: dbProvider,
      dbConfig: dbConfig,
      dbPath: dbPath,
      dbType: dbType,
      requestStoragePermission: requestStoragePermission,
      setState: setState,
      showSnackBar: showSnackBar,
      mounted: mounted,
    );
  }

  static Future<void> showExportDialog(
    BuildContext context, {
    required DatabaseConfig dbConfig,
    required String dbPath,
    required String dbType,
    required Function(VoidCallback) setState,
    required Function(String, {bool isSuccess}) showSnackBar,
    required bool Function() mounted,
  }) {
    return SettingsBackupRestoreDialogs.showExportDialog(
      context,
      dbConfig: dbConfig,
      dbPath: dbPath,
      dbType: dbType,
      setState: setState,
      showSnackBar: showSnackBar,
      mounted: mounted,
    );
  }
}

import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:dentist_app/features/settings/services/backup_restore_service.dart';
import 'package:dentist_app/features/settings/services/excel_export_service.dart';
import 'package:dentist_app/features/settings/widgets/settings_common_dialogs.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/providers/app_state.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/utils/app_paths.dart';

class SettingsBackupRestoreDialogs {
  static Future<void> showBackupDialog(
    BuildContext context, {
    required DatabaseConfig dbConfig,
    required String dbPath,
    required String dbType,
    required Function(VoidCallback) setState,
    required Function(String, {bool isSuccess}) showSnackBar,
    required bool Function() mounted,
  }) async {
    final defaultFilename = BackupRestoreService.generateBackupFilename();
    final filenameController = TextEditingController(text: defaultFilename);
    String? selectedDir;

    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.backup, color: AppTheme.primaryColor),
                    SizedBox(width: 10),
                    Text('备份数据库'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('请选择备份保存位置和文件名:'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedDir ?? '未选择文件夹',
                                style: TextStyle(
                                  color:
                                      selectedDir == null
                                          ? Colors.grey
                                          : Colors.black,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<String>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('选择保存位置'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.download,
                                              color: Colors.blue,
                                            ),
                                            title: const Text('下载文件夹'),
                                            onTap: () async {
                                              final dir = Directory(
                                                AppPaths.downloadsDirectoryPath,
                                              );
                                              if (await dir.exists()) {
                                                if (!context.mounted) return;
                                                Navigator.pop(
                                                  context,
                                                  dir.path,
                                                );
                                              } else {
                                                showSnackBar(
                                                  '找不到下载文件夹',
                                                  isSuccess: false,
                                                );
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.folder,
                                              color: Colors.orange,
                                            ),
                                            title: const Text('文档文件夹'),
                                            onTap: () async {
                                              final dir =
                                                  await getApplicationDocumentsDirectory();
                                              if (!context.mounted) return;
                                              Navigator.pop(context, dir.path);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.folder_open,
                                              color: Colors.green,
                                            ),
                                            title: const Text('浏览其他文件夹'),
                                            onTap: () async {
                                              Navigator.pop(context, 'browse');
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            );

                            if (result == 'browse') {
                              final String? customDir =
                                  await getDirectoryPath();
                              if (customDir != null && customDir.isNotEmpty) {
                                setState(() => selectedDir = customDir);
                              }
                            } else if (result != null) {
                              setState(() => selectedDir = result);
                            }
                          },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('选择文件夹'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: filenameController,
                        decoration: const InputDecoration(
                          labelText: '备份文件名',
                          hintText: '输入备份文件名 (包含.db扩展名)',
                          border: OutlineInputBorder(),
                          suffixText: '.db',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed:
                        selectedDir == null
                            ? null
                            : () async {
                              final dir = selectedDir;
                              if (dir == null) return;
                              Navigator.pop(context);

                              var filename = filenameController.text.trim();
                              if (!filename.toLowerCase().endsWith('.db')) {
                                filename += '.db';
                              }

                              final backupPath = path.join(dir, filename);

                              if (!mounted()) return;
                              setState(() {});

                              try {
                                final success =
                                    await BackupRestoreService.backupDatabase(
                                      backupPath,
                                      dbPath,
                                      dbType,
                                    );

                                if (!mounted()) return;
                                setState(() {});

                                if (success) {
                                  showSnackBar(
                                    '数据库已成功备份到: $backupPath',
                                    isSuccess: true,
                                  );
                                } else {
                                  showSnackBar('数据库备份失败', isSuccess: false);
                                }
                              } catch (e) {
                                if (mounted()) {
                                  setState(() {});
                                  showSnackBar('备份失败: $e', isSuccess: false);
                                }
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: const Text('开始备份'),
                  ),
                ],
              );
            },
          ),
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
  }) async {
    if (dbType != 'sqlite') {
      showSnackBar('当前数据库类型为 $dbType，仅支持还原到SQLite数据库', isSuccess: false);
      return;
    }

    final permissionGranted = await requestStoragePermission();
    if (!permissionGranted) {
      showSnackBar('需要存储权限才能访问备份文件', isSuccess: false);
      return;
    }

    if (!mounted()) return;
    setState(() {});

    try {
      final backupPath = await BackupRestoreService.selectBackupFile();
      if (!mounted()) return;
      setState(() {});

      if (backupPath != null) {
        if (!context.mounted) return;
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('确认恢复'),
                content: Text('确定要从以下文件恢复数据库吗？\n\n$backupPath\n\n这将覆盖当前的所有数据！'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('取消'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('确认恢复'),
                  ),
                ],
              ),
        );

        if (confirm == true) {
          if (!mounted()) return;
          setState(() {});

          final bool success =
              await BackupRestoreService.restoreDatabaseFromBackup(
                backupPath,
                dbPath,
                dbType,
              );

          if (!mounted()) return;
          setState(() {});

          if (success) {
            if (!context.mounted) return;
            await showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('恢复成功'),
                    content: const Text('数据库已成功恢复。应用将重新启动以加载恢复的数据。'),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          final appState = Provider.of<AppState>(
                            context,
                            listen: false,
                          );
                          appState.resetState();
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
            );
          } else {
            showSnackBar('恢复数据库失败，请检查备份文件是否有效', isSuccess: false);
          }
        }
      }
    } catch (e) {
      if (mounted()) {
        setState(() {});
        showSnackBar('恢复失败: $e', isSuccess: false);
      }
    }
  }

  static Future<void> showExportDialog(
    BuildContext context, {
    required DatabaseConfig dbConfig,
    required String dbPath,
    required String dbType,
    required Function(VoidCallback) setState,
    required Function(String, {bool isSuccess}) showSnackBar,
    required bool Function() mounted,
  }) async {
    final defaultFilename = BackupRestoreService.generateExcelFilename();
    final filenameController = TextEditingController(text: defaultFilename);
    String? selectedDir;

    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.file_download, color: Colors.green.shade600),
                    const SizedBox(width: 10),
                    const Text('导出患者数据到Excel'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('请选择Excel保存位置和文件名:'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder, color: Colors.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                selectedDir ?? '未选择文件夹',
                                style: TextStyle(
                                  color:
                                      selectedDir == null
                                          ? Colors.grey
                                          : Colors.black,
                                  fontSize: 13,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final result = await showDialog<String>(
                              context: context,
                              builder:
                                  (context) => AlertDialog(
                                    title: const Text('选择保存位置'),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(
                                              Icons.download,
                                              color: Colors.blue,
                                            ),
                                            title: const Text('下载文件夹'),
                                            onTap: () async {
                                              final dir = Directory(
                                                AppPaths.downloadsDirectoryPath,
                                              );
                                              if (await dir.exists()) {
                                                if (!context.mounted) return;
                                                Navigator.pop(
                                                  context,
                                                  dir.path,
                                                );
                                              } else {
                                                showSnackBar(
                                                  '找不到下载文件夹',
                                                  isSuccess: false,
                                                );
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.folder,
                                              color: Colors.orange,
                                            ),
                                            title: const Text('文档文件夹'),
                                            onTap: () async {
                                              final dir =
                                                  await getApplicationDocumentsDirectory();
                                              if (!context.mounted) return;
                                              Navigator.pop(context, dir.path);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.folder_open,
                                              color: Colors.green,
                                            ),
                                            title: const Text('浏览其他文件夹'),
                                            onTap: () async {
                                              Navigator.pop(context, 'browse');
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            );

                            if (result == 'browse') {
                              final String? customDir =
                                  await getDirectoryPath();
                              if (customDir != null && customDir.isNotEmpty) {
                                setState(() => selectedDir = customDir);
                              }
                            } else if (result != null) {
                              setState(() => selectedDir = result);
                            }
                          },
                          icon: const Icon(Icons.folder_open),
                          label: const Text('选择文件夹'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: filenameController,
                        decoration: const InputDecoration(
                          labelText: 'Excel文件名',
                          hintText: '输入文件名 (包含.xlsx扩展名)',
                          border: OutlineInputBorder(),
                          suffixText: '.xlsx',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed:
                        selectedDir == null
                            ? null
                            : () async {
                              final dir = selectedDir;
                              if (dir == null) return;
                              Navigator.pop(context);

                              var filename = filenameController.text.trim();
                              if (!filename.toLowerCase().endsWith('.xlsx')) {
                                filename += '.xlsx';
                              }

                              final exportPath = path.join(dir, filename);

                              if (!mounted()) return;
                              setState(() {});

                              try {
                                final patients =
                                    await Provider.of<PatientProvider>(
                                      context,
                                      listen: false,
                                    ).getAllPatients();
                                if (patients.isEmpty) {
                                  throw Exception('没有患者数据可导出');
                                }

                                final List<Map<String, dynamic>> patientsData =
                                    patients
                                        .map((patient) => patient.toMap())
                                        .toList();

                                final excelPath =
                                    await ExcelExportService.exportPatientsToExcel(
                                      exportPath,
                                      patientsData,
                                    );

                                if (!mounted()) return;
                                setState(() {});

                                if (!context.mounted) return;
                                SettingsCommonDialogs.showSuccessDialog(
                                  context,
                                  '患者信息导出成功！',
                                  '文件已保存到:\n$excelPath',
                                );
                              } catch (e) {
                                if (mounted()) {
                                  setState(() {});
                                  showSnackBar('导出失败: $e', isSuccess: false);
                                }
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                    ),
                    child: const Text('导出Excel'),
                  ),
                ],
              );
            },
          ),
    );
  }
}

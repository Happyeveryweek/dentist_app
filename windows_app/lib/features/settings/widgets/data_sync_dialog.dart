import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'dart:io';

import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../widgets/success_toast.dart';

class DataSyncDialog extends StatefulWidget {
  const DataSyncDialog({Key? key}) : super(key: key);

  @override
  State<DataSyncDialog> createState() => _DataSyncDialogState();
}

class _DataSyncDialogState extends State<DataSyncDialog> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  String _backupPath = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadBackupPath();
  }

  Future<void> _loadBackupPath() async {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    await settingsProvider.init();
    setState(() {
      _backupPath = settingsProvider.backupPath;
    });
  }

  Future<void> _selectBackupDirectory() async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择备份目录',
      );

      if (selectedDirectory != null) {
        setState(() {
          _backupPath = selectedDirectory;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '选择目录时出错: $e';
      });
    }
  }

  Future<void> _backupDatabase() async {
    if (_backupPath.isEmpty) {
      setState(() {
        _errorMessage = '请先选择备份目录';
      });
      return;
    }

    setState(() {
      _isBackingUp = true;
      _errorMessage = '';
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      // 保存备份路径到设置
      await settingsProvider.setBackupPath(_backupPath);

      // 执行备份
      await dbProvider.backupDatabase();

      if (!mounted) return;
      // 使用公用成功提示组件
      AppToastManager.showSuccess(context, message: '数据库备份成功');
    } catch (e) {
      setState(() {
        _errorMessage = '备份失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  Future<void> _restoreDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3', 'sql'],
        dialogTitle: '选择备份文件',
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final selectedFile = result.files.single.path;
      if (selectedFile == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取文件路径')),
        );
        return;
      }
      String filePath = selectedFile;

      // 检查文件是否存在
      if (!await File(filePath).exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('选择的文件不存在')),
        );
        return;
      }

      if (!mounted) return;
      // 确认是否恢复
      final confirmRestore = await showDialog<bool>(
        context: context,
        builder: (context) {
          final tokens = context.tokens;
          return AlertDialog(
            title: const Text('恢复备份'),
            content: Text('确定要从备份文件 $filePath 恢复数据库吗？这将覆盖当前数据。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(backgroundColor: tokens.error),
                child: const Text('恢复'),
              ),
            ],
          );
        },
      );

      if (confirmRestore == true) {
        setState(() {
          _isRestoring = true;
        });

        try {
          if (!mounted) return;
          final dbProvider =
              Provider.of<DatabaseProvider>(context, listen: false);
          await dbProvider.restoreDatabase(filePath);

          if (!mounted) return;
          // 使用公用成功提示组件
          AppToastManager.showSuccess(context, message: '数据库已成功从备份文件恢复');
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('恢复失败: $e'), backgroundColor: context.tokens.error),
          );
        } finally {
          setState(() {
            _isRestoring = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = '恢复失败: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.backup,
                  color: tokens.primaryAccent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                const Text(
                  '数据库备份与还原',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: tokens.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(color: tokens.error),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            // 备份目录选择
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: tokens.divider),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _backupPath.isEmpty ? '未选择备份目录' : _backupPath,
                      style: TextStyle(
                        color: _backupPath.isEmpty
                            ? tokens.textMuted
                            : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _selectBackupDirectory,
                  icon: const Icon(Icons.folder_open),
                  label: const Text('选择目录'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // 操作按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isBackingUp ? null : _backupDatabase,
                  icon: _isBackingUp
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('备份'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isRestoring ? null : _restoreDatabase,
                  icon: _isRestoring
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore),
                  label: const Text('还原'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tokens.error,
                    foregroundColor: tokens.cardBackground,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

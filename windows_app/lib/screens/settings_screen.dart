import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../providers/settings_provider.dart';
import '../providers/database_provider.dart';
import '../providers/material_provider.dart';
import '../screens/data_source_screen.dart'; // 数据源配置页面
import '../widgets/dental_icons.dart';
import '../config/app_defaults.dart';

import '../features/settings/widgets/settings_header_card.dart';
import '../features/settings/widgets/settings_section_header.dart';
import '../features/settings/widgets/setting_item.dart';
import '../features/settings/widgets/backup_info_display.dart';
import '../features/settings/widgets/auto_backup_settings.dart';
import '../features/settings/widgets/data_source_selection_dialog.dart';
import '../features/settings/widgets/edit_app_name_dialog.dart';
import '../features/settings/widgets/theme_section.dart';
import '../features/settings/widgets/about_section.dart';
import '../features/settings/widgets/backup_path_inputs.dart';
import '../features/settings/widgets/backup_action_buttons.dart';
import '../features/settings/widgets/structure_check_result_dialog.dart';
import '../features/settings/widgets/reset_app_data_dialog.dart';
import '../features/settings/helpers/data_storage_location_helper.dart';
import '../features/settings/services/backup_restore_service.dart';
import '../features/settings/services/database_structure_check_service.dart';
import '../features/settings/services/app_reset_service.dart';
import '../features/settings/widgets/backup_log_dialog.dart';
import '../features/settings/widgets/patient_sync_log_dialog.dart';
import '../features/settings/widgets/structure_log_dialog.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  bool _isCheckingStructure = false;

  final TextEditingController _backupPathController = TextEditingController();
  final TextEditingController _backupPath2Controller = TextEditingController();

  late BackupRestoreService _backupRestoreService;
  late DatabaseStructureCheckService _databaseStructureCheckService;
  late AppResetService _appResetService;

  @override
  void initState() {
    super.initState();
    // 初始化备份路径显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      _backupPathController.text = settingsProvider.backupPath;
      _backupPath2Controller.text = settingsProvider.backupPath2;
    });

    // 初始化服务
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final materialProvider =
        Provider.of<MaterialProvider>(context, listen: false);

    _backupRestoreService = BackupRestoreService(
      dbProvider: dbProvider,
      settingsProvider: settingsProvider,
    );
    _databaseStructureCheckService = DatabaseStructureCheckService(
      dbProvider: dbProvider,
      settingsProvider: settingsProvider,
      materialProvider: materialProvider,
    );
    _appResetService = AppResetService(
      dbProvider: dbProvider,
      settingsProvider: settingsProvider,
    );
  }

  @override
  void dispose() {
    _backupPathController.dispose();
    _backupPath2Controller.dispose();
    super.dispose();
  }

  // 选择备份目录
  Future<void> _selectBackupDirectory(bool isSecondPath) async {
    try {
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择备份目录${isSecondPath ? '2' : '1'}',
      );

      if (selectedDirectory == null) {
        return;
      }

      // 验证目录是否存在
      final directory = Directory(selectedDirectory);
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法创建目录: $e')),
          );
          return;
        }
      }

      // 更新文本框和设置
      setState(() {
        if (isSecondPath) {
          _backupPath2Controller.text = selectedDirectory;
        } else {
          _backupPathController.text = selectedDirectory;
        }
      });

      // 更新设置
      if (!mounted) return;
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      if (isSecondPath) {
        settingsProvider.setBackupPath2(selectedDirectory);
      } else {
        settingsProvider.setBackupPath(selectedDirectory);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择目录时出错: $e')),
      );
    }
  }

  // 执行备份操作
  Future<void> _performBackup() async {
    setState(() {
      _isBackingUp = true;
    });

    try {
      final path1 = _backupPathController.text;
      final path2 = _backupPath2Controller.text;

      // 如果两个路径都为空，提示用户至少设置一个
      if (path1.isEmpty && path2.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('未设置备份路径'),
            content: const Text('请至少设置一个备份目录后再执行备份，或在下方输入框手动输入备份路径。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        return;
      }

      final result = await _backupRestoreService.performBackup(
        path1: path1,
        path2: path2,
      );

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据库备份成功到: ${result.successPaths.join(", ")}'),
            backgroundColor: context.tokens.success,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('备份失败: ${result.errorMessage}'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('备份失败: $e'),
          backgroundColor: context.tokens.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
        });
      }
    }
  }

  // 显示备份文件选择对话框 - 使用file_picker
  Future<void> _selectBackupFile() async {
    try {
      final filePath = await _backupRestoreService.selectBackupFile();
      if (filePath == null) {
        // 用户取消了选择
        return;
      }

      // 验证文件
      final validationError =
          await _backupRestoreService.validateBackupFile(filePath);
      if (validationError != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(validationError),
            backgroundColor: context.tokens.error,
          ),
        );
        return;
      }

      if (!mounted) return;
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final isMySQL = settingsProvider.dataSourceType == 'mysql';

      // 确认是否恢复
      final confirmRestore = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('恢复备份'),
          content: Text(isMySQL
              ? '确定要从SQL文件 $filePath 恢复MySQL数据库吗？这将覆盖当前数据。'
              : '确定要从备份文件 $filePath 恢复SQLite数据库吗？这将覆盖当前数据库文件。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.tokens.error),
              child: const Text('恢复'),
            ),
          ],
        ),
      );

      if (confirmRestore == true) {
        setState(() {
          _isRestoring = true;
        });

        try {
          final result = await _backupRestoreService.performRestore(filePath);

          if (!mounted) return;

          if (result.success) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    isMySQL ? 'MySQL数据库已成功从SQL文件恢复' : 'SQLite数据库已成功从备份文件恢复'),
                backgroundColor: context.tokens.success,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('恢复失败: ${result.errorMessage}'),
                  backgroundColor: context.tokens.error),
            );
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('恢复失败: $e'),
                backgroundColor: context.tokens.error),
          );
        } finally {
          setState(() {
            _isRestoring = false;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择文件时出错: $e')),
      );
    }
  }

  // 打开数据源设置页面
  void _openDataSourceSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DataSourceScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: tokens.pageBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: tokens.cardBackground,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '系统设置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: tokens.cardBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout: 2 columns for screens wider than 900px
          if (constraints.maxWidth >= 900) {
            return _buildTwoColumnLayout();
          } else {
            return _buildSingleColumnLayout();
          }
        },
      ),
    );
  }

  // 构建单列布局
  Widget _buildSingleColumnLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SettingsHeaderCard(),
          const SizedBox(height: 16),
          const ThemeSection(),
          _buildDataManagementSection(),
          AboutSection(
            onEditAppName: () async {
              final result = await EditAppNameDialog.show(context);
              if (result != null && result.isNotEmpty) {
                if (!mounted) return;
                final settingsProvider =
                    Provider.of<SettingsProvider>(context, listen: false);
                await settingsProvider.setAppName(result);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('应用名称已更新为：$result'),
                    backgroundColor: context.tokens.success,
                  ),
                );
              }
            },
            onOpenDataStorageLocation: () {
              final settingsProvider =
                  Provider.of<SettingsProvider>(context, listen: false);
              DataStorageLocationHelper.openDataStorageLocation(
                  context, settingsProvider);
            },
            onResetAppData: _resetAppData,
            getDataStorageLocation: (settingsProvider) =>
                DataStorageLocationHelper.getDataStorageLocation(
                    settingsProvider),
          ),
        ],
      ),
    );
  }

  // 构建双列布局
  Widget _buildTwoColumnLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SettingsHeaderCard(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Theme & About
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    const ThemeSection(),
                    // No extra spacing needed as ThemeSection has bottom margin
                    AboutSection(
                      onEditAppName: () async {
                        final result = await EditAppNameDialog.show(context);
                        if (result != null && result.isNotEmpty) {
                          if (!mounted) return;
                          final settingsProvider =
                              Provider.of<SettingsProvider>(context,
                                  listen: false);
                          await settingsProvider.setAppName(result);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('应用名称已更新为：$result'),
                              backgroundColor: context.tokens.success,
                            ),
                          );
                        }
                      },
                      onOpenDataStorageLocation: () {
                        final settingsProvider = Provider.of<SettingsProvider>(
                            context,
                            listen: false);
                        DataStorageLocationHelper.openDataStorageLocation(
                            context, settingsProvider);
                      },
                      onResetAppData: _resetAppData,
                      getDataStorageLocation: (settingsProvider) =>
                          DataStorageLocationHelper.getDataStorageLocation(
                              settingsProvider),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              // Right Column: Data Management
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    _buildDataManagementSection(),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建数据管理部分
  Widget _buildDataManagementSection() {
    return Column(
      children: [
        SettingsSectionHeader(
          title: '数据管理',
          icon: Icons.storage,
          color: context.tokens.secondaryAccent,
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: context.tokens.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: context.tokens.elevatedShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SettingItem(
                  icon: Icons.storage,
                  title: '数据源配置',
                  subtitle: '配置SQLite或MySQL作为数据源',
                  trailing: DentalGradientButton(
                    text: '配置',
                    icon: Icons.settings,
                    onPressed: _openDataSourceSettings,
                    isOutlined: true,
                  ),
                ),
                const Divider(height: 20),
                // 数据库结构检测
                SettingItem(
                  icon: Icons.architecture,
                  title: '数据库结构检测',
                  subtitle: '检测并更新数据库表结构和字段',
                  trailing: _isCheckingStructure
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.tokens.primaryAccent
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                context.tokens.primaryAccent),
                            strokeWidth: 2,
                          ),
                        )
                      : DentalGradientButton(
                          text: '检测',
                          icon: Icons.search,
                          onPressed: _checkDatabaseStructure,
                          isOutlined: true,
                        ),
                ),
                const Divider(height: 16),
                // 数据库结构检测日志查看
                SettingItem(
                  icon: Icons.architecture,
                  title: '结构检测日志',
                  subtitle: '查看数据库结构检测记录',
                  trailing: DentalGradientButton(
                    text: '查看',
                    icon: Icons.visibility,
                    onPressed: _showStructureCheckLogs,
                    isOutlined: true,
                  ),
                ),
                const Divider(height: 16),
                SettingItem(
                  icon: Icons.sync_alt,
                  title: '患者同步日志',
                  subtitle: '查看 SQLite 患者同步 MySQL 的结果',
                  trailing: DentalGradientButton(
                    text: '查看',
                    icon: Icons.visibility,
                    onPressed: _showPatientSyncLogs,
                    isOutlined: true,
                  ),
                ),

                const Divider(height: 20),
                // 备份目录设置
                _buildBackupSettings(),
                // 自动备份设置
                const AutoBackupSettings(),
                // 备份日志查看
                SettingItem(
                  icon: Icons.history,
                  title: '备份日志',
                  subtitle: '查看历史备份记录',
                  trailing: DentalGradientButton(
                    text: '查看',
                    icon: Icons.visibility,
                    onPressed: _showBackupLogs,
                    isOutlined: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 构建备份设置
  Widget _buildBackupSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingsSectionHeader(
          title: '备份设置',
          icon: Icons.backup,
          color: context.tokens.secondaryAccent,
        ),
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.mutedBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.tokens.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 备份数据源信息显示
              const BackupInfoDisplay(),

              // 数据备份和恢复备份功能
              BackupActionButtons(
                isBackingUp: _isBackingUp,
                isRestoring: _isRestoring,
                onBackup: _performBackup,
                onRestore: _selectBackupFile,
              ),

              const Divider(height: 20),

              // 备份目录设置
              BackupPathInputs(
                backupPathController: _backupPathController,
                backupPath2Controller: _backupPath2Controller,
                onSelectDirectory: _selectBackupDirectory,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 显示备份日志对话框
  void _showBackupLogs() async {
    await BackupLogDialog.show(context);
  }

  void _showPatientSyncLogs() async {
    await PatientSyncLogDialog.show(context);
  }

  // 检测数据库结构
  Future<void> _checkDatabaseStructure() async {
    // 显示数据源选择弹窗
    final selectedDataSource = await _showDataSourceSelectionDialog();
    if (selectedDataSource == null) return;

    setState(() {
      _isCheckingStructure = true;
    });

    try {
      final result =
          await _databaseStructureCheckService.checkDatabaseStructure(
        selectedDataSource,
      );

      if (!mounted) return;

      if (result.success) {
        // 显示检测结果
        StructureCheckResultDialog.show(context, result.checkResult);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('数据库结构检测失败: ${result.errorMessage}'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('数据库结构检测失败: $e'),
          backgroundColor: context.tokens.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingStructure = false;
        });
      }
    }
  }

  // 显示数据源选择对话框
  Future<String?> _showDataSourceSelectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => const DataSourceSelectionDialog(),
    );
  }

  // 重置应用数据
  Future<void> _resetAppData() async {
    try {
      final confirmed = await ResetAppDataDialog.show(context);

      if (confirmed == true) {
        if (!mounted) return;
        // 显示进度对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('正在重置应用配置...'),
              ],
            ),
          ),
        );

        try {
          final result = await _appResetService.resetAppData();

          if (!mounted) return;

          // 关闭进度对话框
          Navigator.of(context).pop();

          if (result.success) {
            // 显示成功对话框
            await _showResetSuccessDialog();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('重置失败: ${result.errorMessage}'),
                backgroundColor: context.tokens.error,
              ),
            );
          }
        } catch (e) {
          if (!mounted) return;

          // 关闭进度对话框
          Navigator.of(context).pop();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('重置失败: $e'),
              backgroundColor: context.tokens.error,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('重置操作出错: $e'),
          backgroundColor: context.tokens.error,
        ),
      );
    }
  }

  // 显示重置成功对话框
  Future<void> _showResetSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: context.tokens.success),
            const SizedBox(width: 12),
            const Text('重置完成'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '应用配置已成功重置到初始状态！',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.tokens.infoContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: context.tokens.info.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: context.tokens.info, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '重置内容：',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '✓ 应用名称：$defaultAppName\n'
                    '✓ 数据源：SQLite（默认）\n'
                    '✓ 备份设置：已清空\n'
                    '✓ MySQL连接：已清空\n'
                    '✓ 主题：浅色模式',
                    style: TextStyle(
                      fontSize: 13,
                      color: context.tokens.info,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.tokens.warningContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: context.tokens.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.restart_alt,
                      color: context.tokens.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '请重启应用以使配置生效',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.tokens.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // 可以在这里添加退出应用的逻辑
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.tokens.primaryAccent,
              foregroundColor: context.tokens.cardBackground,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 显示结构检测日志
  void _showStructureCheckLogs() async {
    await StructureLogDialog.show(context);
  }
}

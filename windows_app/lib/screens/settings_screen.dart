import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:mysql1/mysql1.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/database_provider.dart';
import '../screens/data_source_screen.dart'; // 数据源配置页面
import '../widgets/data_sync_dialog.dart'; // 导入数据同步对话框组件
import '../models/backup_log.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isBackingUp = false;
  bool _isRestoring = false;
  final TextEditingController _backupPathController = TextEditingController();
  final TextEditingController _backupPath2Controller = TextEditingController();

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

  // 显示备份文件选择对话框 - 使用file_picker
  Future<void> _selectBackupFile() async {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final isMySQL = dbProvider.dataSourceType == 'mysql';

      // 根据数据源类型选择不同的文件扩展名
      final allowedExtensions = isMySQL ? ['sql'] : ['db', 'sqlite', 'sqlite3'];
      final dialogTitle = isMySQL ? '选择MySQL备份文件(.sql)' : '选择SQLite备份文件(.db)';

      // 使用FilePicker选择备份文件
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        dialogTitle: dialogTitle,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消了选择
        return;
      }

      final String filePath = result.files.single.path!;

      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件不存在')),
        );
        return;
      }

      // 验证文件类型
      if (isMySQL && !filePath.toLowerCase().endsWith('.sql')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请选择.sql格式的MySQL备份文件'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      } else if (!isMySQL &&
          !filePath.toLowerCase().endsWith('.db') &&
          !filePath.toLowerCase().endsWith('.sqlite') &&
          !filePath.toLowerCase().endsWith('.sqlite3')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请选择.db/.sqlite/.sqlite3格式的SQLite备份文件'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
          if (isMySQL) {
            // MySQL 恢复使用 mysql.exe
            await dbProvider.restoreFromMySQLDump(filePath);
          } else {
            // SQLite 恢复使用原有方法
            await dbProvider.restoreDatabase(filePath);
          }

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(isMySQL ? 'MySQL数据库已成功从SQL文件恢复' : 'SQLite数据库已成功从备份文件恢复'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('恢复失败: $e'), backgroundColor: Colors.red),
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

  // 打开数据同步对话框
  void _openDataSyncDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return const DataSyncDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('系统设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 外观设置部分
          _buildSectionHeader('外观设置', Icons.palette, AppTheme.primaryColor),
          _buildThemeSection(context),

          // 数据管理部分
          _buildSectionHeader('数据管理', Icons.storage, AppTheme.secondaryColor),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingItem(
                    icon: Icons.storage,
                    title: '数据源配置',
                    subtitle: '配置SQLite或MySQL作为数据源',
                    trailing: OutlinedButton.icon(
                      icon: const Icon(Icons.settings),
                      label: const Text('配置'),
                      onPressed: _openDataSourceSettings,
                    ),
                  ),
                  const Divider(),
                  // 备份设置项
                  _buildSettingItem(
                    icon: Icons.backup,
                    title: '数据备份',
                    subtitle: dbProvider.dataSourceType == 'mysql'
                        ? '将MySQL数据库导出为SQL文件'
                        : '将SQLite数据库文件直接复制备份',
                    trailing: _isBackingUp
                        ? const CircularProgressIndicator()
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.save),
                            label: const Text('备份'),
                            onPressed: () async {
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
                                      content: const Text(
                                          '请至少设置一个备份目录后再执行备份，或在下方输入框手动输入备份路径。'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('确定'),
                                        ),
                                      ],
                                    ),
                                  );
                                  return;
                                }

                                final dbProvider =
                                    Provider.of<DatabaseProvider>(context,
                                        listen: false);
                                final settingsProvider =
                                    Provider.of<SettingsProvider>(context,
                                        listen: false);

                                bool backupSuccess = false;
                                String errorMessage = '';
                                List<String> successPaths = [];

                                // 执行备份到第一个目录
                                if (path1.isNotEmpty) {
                                  try {
                                    // 确保目录存在
                                    Directory directory = Directory(path1);
                                    if (!directory.existsSync()) {
                                      try {
                                        directory.createSync(recursive: true);
                                      } catch (e) {
                                        throw Exception('无法创建目录: $e');
                                      }
                                    }

                                    await settingsProvider.setBackupPath(path1);
                                    final backupPath =
                                        await dbProvider.backupDatabase();
                                    backupSuccess = true;
                                    successPaths.add(backupPath);
                                  } catch (e) {
                                    errorMessage = '备份到目录1失败: $e';
                                    print(errorMessage);
                                  }
                                } else {
                                  // 备份目录1为空，记录日志
                                  await BackupLog.addLog(BackupLog(
                                    backupDate: DateTime.now(),
                                    backupPath: '未设置备份目录1',
                                    success: false,
                                    errorMessage: '备份目录1为空，跳过备份',
                                  ));
                                }

                                // 执行备份到第二个目录
                                if (path2.isNotEmpty) {
                                  try {
                                    // 确保目录存在
                                    Directory directory = Directory(path2);
                                    if (!directory.existsSync()) {
                                      try {
                                        directory.createSync(recursive: true);
                                      } catch (e) {
                                        throw Exception('无法创建目录: $e');
                                      }
                                    }

                                    await settingsProvider.setBackupPath(path2);
                                    final backupPath =
                                        await dbProvider.backupDatabase();
                                    backupSuccess = true;
                                    successPaths.add(backupPath);
                                  } catch (e) {
                                    if (errorMessage.isNotEmpty) {
                                      errorMessage += '\n';
                                    }
                                    errorMessage += '备份到目录2失败: $e';
                                    print(errorMessage);
                                  }
                                } else {
                                  // 备份目录2为空，记录日志
                                  await BackupLog.addLog(BackupLog(
                                    backupDate: DateTime.now(),
                                    backupPath: '未设置备份目录2',
                                    success: false,
                                    errorMessage: '备份目录2为空，跳过备份',
                                  ));
                                }

                                // 恢复到第一个备份路径（如果有）
                                if (path1.isNotEmpty) {
                                  await settingsProvider.setBackupPath(path1);
                                } else if (path2.isNotEmpty) {
                                  await settingsProvider.setBackupPath(path2);
                                }

                                // 根据备份结果显示不同的提示
                                if (!backupSuccess) {
                                  throw Exception(errorMessage.isEmpty
                                      ? '备份失败'
                                      : errorMessage);
                                }

                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        '数据库备份成功到: ${successPaths.join(", ")}'),
                                    backgroundColor: AppTheme.successColor,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('备份失败: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isBackingUp = false;
                                  });
                                }
                              }
                            },
                          ),
                  ),
                  const SizedBox(height: 16),
                  // 备份目录设置
                  _buildBackupSettings(),
                  // 自动备份设置
                  _buildAutoBackupSettings(),
                  // 备份日志查看
                  _buildSettingItem(
                    icon: Icons.history,
                    title: '备份日志',
                    subtitle: '查看历史备份记录',
                    trailing: OutlinedButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('查看'),
                      onPressed: _showBackupLogs,
                    ),
                  ),
                  const Divider(),
                  // 恢复备份项
                  _buildSettingItem(
                    icon: Icons.restore,
                    title: '恢复备份',
                    subtitle: dbProvider.dataSourceType == 'mysql'
                        ? '从SQL文件恢复MySQL数据库'
                        : '从.db文件恢复SQLite数据库',
                    trailing: _isRestoring
                        ? const CircularProgressIndicator()
                        : OutlinedButton.icon(
                            icon: const Icon(Icons.file_open),
                            label: const Text('选择文件'),
                            onPressed: _selectBackupFile,
                          ),
                  ),
                ],
              ),
            ),
          ),

          // 数据同步功能 - 隐藏UI但保留底层逻辑
          // _buildSectionHeader('数据同步'),
          // Card(
          //   margin: const EdgeInsets.only(bottom: 16),
          //   shape: RoundedRectangleBorder(
          //     borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          //   ),
          //   child: Padding(
          //     padding: const EdgeInsets.all(16),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         _buildSettingItem(
          //           icon: Icons.sync,
          //           title: '患者数据同步',
          //           subtitle: '在SQLite和MySQL之间同步患者数据',
          //           trailing: OutlinedButton.icon(
          //             icon: const Icon(Icons.sync),
          //             label: const Text('同步'),
          //             onPressed: () => _openDataSyncDialog(context),
          //           ),
          //         ),
          //       ],
          //     ),
          //   ),
          // ),

          // 关于部分
          _buildSectionHeader('关于', Icons.info_outline, AppTheme.accentColor),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: '应用版本',
                    subtitle: 'v1.0.0',
                  ),
                  const Divider(),
                  _buildSettingItem(
                    icon: Icons.code,
                    title: '开发者',
                    subtitle: 'Dr. Dentist Software 牙医软件团队',
                  ),
                  const Divider(),
                  _buildSettingItem(
                    icon: Icons.copyright,
                    title: '版权信息',
                    subtitle: '© ${DateTime.now().year} 牙医诊所管理系统 版权所有',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建主题选择部分
  Widget _buildThemeSection(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('主题设置', Icons.palette, AppTheme.primaryColor),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildThemeCard(
                  ExtendedThemeMode.light,
                  '浅色模式',
                  Icons.brightness_5,
                  settingsProvider.extendedThemeMode == ExtendedThemeMode.light,
                ),
                _buildThemeCard(
                  ExtendedThemeMode.grey,
                  '灰色模式',
                  Icons.brightness_4,
                  settingsProvider.extendedThemeMode == ExtendedThemeMode.grey,
                ),
                _buildThemeCard(
                  ExtendedThemeMode.purple,
                  '紫色模式',
                  Icons.color_lens,
                  settingsProvider.extendedThemeMode ==
                      ExtendedThemeMode.purple,
                  cardColor: AppTheme.purpleCardBackground,
                  textColor: AppTheme.purplePrimaryText,
                  iconColor: AppTheme.purpleColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingItem(
              icon: Icons.format_size,
              title: '字体大小',
              trailing: DropdownButton<double>(
                value: settingsProvider.fontSize,
                underline: Container(),
                items: const [
                  DropdownMenuItem(value: 0.8, child: Text('小')),
                  DropdownMenuItem(value: 1.0, child: Text('中')),
                  DropdownMenuItem(value: 1.2, child: Text('大')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      settingsProvider.setFontSize(value);
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建主题卡片
  Widget _buildThemeCard(
    ExtendedThemeMode mode,
    String title,
    IconData icon,
    bool isSelected, {
    Color? cardColor,
    Color? textColor,
    Color? iconColor,
  }) {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color defaultCardColor;
    Color defaultTextColor;

    switch (mode) {
      case ExtendedThemeMode.light:
        defaultCardColor = Colors.white;
        defaultTextColor = Colors.black87;
        break;
      case ExtendedThemeMode.grey:
        defaultCardColor = const Color(0xFFEEEEEE);
        defaultTextColor = Colors.black87;
        break;
      case ExtendedThemeMode.purple:
        defaultCardColor = AppTheme.purpleCardBackground;
        defaultTextColor = AppTheme.purplePrimaryText;
        break;
      default:
        defaultCardColor = isDarkMode ? const Color(0xFF303030) : Colors.white;
        defaultTextColor = isDarkMode ? Colors.white : Colors.black87;
        break;
    }

    return GestureDetector(
      onTap: () {
        settingsProvider.setExtendedThemeMode(mode);
      },
      child: Container(
        width: 110,
        height: 90,
        decoration: BoxDecoration(
          color: cardColor ?? defaultCardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : iconColor ?? Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: textColor ?? defaultTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建设置项
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // 构建分区标题
  Widget _buildSectionHeader(String title, IconData? icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Row(
        children: [
          if (icon != null) Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  // 构建备份设置UI
  Widget _buildBackupSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('备份设置', Icons.backup, AppTheme.secondaryColor),
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 备份目录1
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('备份目录 1:'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _backupPathController,
                                decoration: InputDecoration(
                                  hintText: '请输入备份目录或留空',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  isDense: true,
                                  suffixIcon: settingsProvider
                                          .backupPath.isNotEmpty
                                      ? IconButton(
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: () async {
                                            await settingsProvider
                                                .setBackupPath('');
                                            _backupPathController.text = '';
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) async {
                                  await settingsProvider.setBackupPath(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _selectBackupDirectory(false),
                              icon: const Icon(Icons.folder_open),
                              label: const Text('浏览'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // 备份目录2
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('备份目录 2:'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _backupPath2Controller,
                                decoration: InputDecoration(
                                  hintText: '请输入备份目录或留空',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  isDense: true,
                                  suffixIcon: settingsProvider
                                          .backupPath2.isNotEmpty
                                      ? IconButton(
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: () async {
                                            await settingsProvider
                                                .setBackupPath2('');
                                            _backupPath2Controller.text = '';
                                          },
                                        )
                                      : null,
                                ),
                                onChanged: (value) async {
                                  await settingsProvider.setBackupPath2(value);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => _selectBackupDirectory(true),
                              icon: const Icon(Icons.folder_open),
                              label: const Text('浏览'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建自动备份设置UI
  Widget _buildAutoBackupSettings() {
    final settingsProvider = Provider.of<SettingsProvider>(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSettingItem(
          icon: Icons.schedule,
          title: '自动备份',
          subtitle: settingsProvider.autoBackup
              ? '每${settingsProvider.backupInterval}天自动备份一次'
              : '自动备份已关闭',
          trailing: Switch(
            value: settingsProvider.autoBackup,
            activeColor: AppTheme.primaryColor,
            onChanged: (value) async {
              await settingsProvider.setAutoBackup(value);
            },
          ),
        ),

        // 显示上次备份时间（无论是否启用自动备份）
        if (settingsProvider.lastBackupDate != null)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 4, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.history,
                    size: 16, color: AppTheme.secondaryText),
                const SizedBox(width: 8),
                Text(
                  '上次备份: ${DateFormat('yyyy-MM-dd HH:mm').format(settingsProvider.lastBackupDate!)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),

        // 仅当自动备份开启时显示备份间隔设置
        if (settingsProvider.autoBackup)
          Padding(
            padding: const EdgeInsets.only(left: 36, top: 8, bottom: 16),
            child: Row(
              children: [
                const Text('备份间隔: '),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: settingsProvider.backupInterval,
                  items: [1, 3, 5, 7, 14, 30].map((days) {
                    return DropdownMenuItem<int>(
                      value: days,
                      child: Text('$days 天'),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value != null) {
                      await settingsProvider.setBackupInterval(value);
                    }
                  },
                ),
              ],
            ),
          ),

        const Divider(),
      ],
    );
  }

  // 显示备份日志对话框
  void _showBackupLogs() async {
    // 获取备份日志
    final logs = await BackupLog.getLogs();

    if (!mounted) return;

    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('暂无备份日志记录')),
      );
      return;
    }

    // 按时间倒序排序
    logs.sort((a, b) => b.backupDate.compareTo(a.backupDate));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('备份日志'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return ListTile(
                leading: Icon(
                  log.success ? Icons.check_circle : Icons.error,
                  color:
                      log.success ? AppTheme.successColor : AppTheme.errorColor,
                ),
                title: Text(
                  '${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.backupDate)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.success)
                      Text('备份路径: ${log.backupPath}')
                    else
                      Text('错误信息: ${log.errorMessage ?? "未知错误"}',
                          style: const TextStyle(color: AppTheme.errorColor)),
                  ],
                ),
                isThreeLine: !log.success,
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('备份日志已清空')),
                  );
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
      ),
    );
  }
}

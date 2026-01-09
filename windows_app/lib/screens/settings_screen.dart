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
import '../providers/material_provider.dart';
import '../screens/data_source_screen.dart'; // 数据源配置页面
import '../widgets/data_sync_dialog.dart'; // 导入数据同步对话框组件
import '../models/backup_log.dart';
import '../models/database_structure_log.dart';
import '../widgets/dental_icons.dart';
import '../widgets/success_toast.dart';

import '../utils/datetime_formatter.dart';
import '../utils/app_paths.dart';
import 'app_info_screen.dart';

// 删除确认对话框管理器
class DeleteConfirmDialogManager {
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = '删除',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }
}

// 删除成功提示管理器
class DeleteSuccessToastManager {
  static void show(BuildContext context, {required String message}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}


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
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final isMySQL = settingsProvider.dataSourceType == 'mysql';

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
            final mysqlSettings = settingsProvider.getCompleteMySQLSettings();
            
            // 先验证还原策略
            final isValid = await settingsProvider.validateRestoreStrategy(
              filePath: filePath,
              targetDataSource: 'mysql',
            );
            
            if (!isValid) {
              throw Exception('还原策略验证失败');
            }
            
            // 创建还原前备份
            final preBackup = await settingsProvider.createPreRestoreBackup();
            if (preBackup != null) {
              print('已创建还原前备份: $preBackup');
            }
            
            // 执行还原
            await dbProvider.restoreFromMySQLDump(
              filePath, 
              mysqlSettings: mysqlSettings,
              onLogOperation: (message) => print(message),
            );
            
            // 还原后清理
            await settingsProvider.cleanupAfterRestore(
              success: true,
              restorePath: filePath,
              preRestoreBackupPath: preBackup,
            );
            
            // 记录还原操作
            await settingsProvider.logRestoreOperation(
              operation: 'MySQL还原完成',
              filePath: filePath,
              success: true,
              preRestoreBackupPath: preBackup,
            );
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
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: DentalColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.settings_rounded,
                color: Colors.white,
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
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            // 页面标题卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.settings,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '系统配置中心',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '个性化设置与系统管理',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // 数据管理部分
            _buildSectionHeader('数据管理', Icons.storage, AppTheme.secondaryColor),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                      trailing: DentalGradientButton(
                        text: '配置',
                        icon: Icons.settings,
                        onPressed: _openDataSourceSettings,
                        isOutlined: true,
                      ),
                    ),
                    const Divider(height: 20),
                    // 数据库结构检测
                    _buildSettingItem(
                      icon: Icons.architecture,
                      title: '数据库结构检测',
                      subtitle: '检测并更新数据库表结构和字段',
                      trailing: _isCheckingStructure
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
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
                    _buildSettingItem(
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

                    const Divider(height: 20),
                    // 备份目录设置
                    _buildBackupSettings(),
                    // 自动备份设置
                    _buildAutoBackupSettings(),
                    // 备份日志查看
                    _buildSettingItem(
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

            // 关于部分
            _buildSectionHeader('关于', Icons.info_outline, AppTheme.accentColor),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                      trailing: DentalGradientButton(
                        text: '详细信息',
                        icon: Icons.info,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const AppInfoScreen(),
                            ),
                          );
                        },
                        isOutlined: true,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildSettingItem(
                      icon: Icons.code,
                      title: '开发者',
                      subtitle: 'Dr. Dentist Software 牙医软件团队',
                    ),
                    const Divider(height: 20),
                    _buildSettingItem(
                      icon: Icons.copyright,
                      title: '版权信息',
                      subtitle: '© ${DateTime.now().year} 牙医诊所管理系统 版权所有',
                    ),
                    const Divider(height: 20),
                    _buildSettingItem(
                      icon: Icons.folder_open,
                      title: '数据存储位置',
                      subtitle: _getDataStorageLocation(settingsProvider),
                      trailing: DentalGradientButton(
                        text: '打开',
                        icon: Icons.folder_open,
                        onPressed: () => _openDataStorageLocation(settingsProvider),
                        isOutlined: true,
                      ),
                    ),
                    const Divider(height: 20),
                    _buildSettingItem(
                      icon: Icons.refresh,
                      title: '重置应用数据',
                      subtitle: '清除所有配置和数据，恢复到初始状态',
                      trailing: DentalGradientButton(
                        text: '重置',
                        icon: Icons.refresh,
                        onPressed: _resetAppData,
                        isOutlined: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建主题选择部分
  Widget _buildThemeSection(BuildContext context) {
    final settingsProvider = Provider.of<SettingsProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('主题设置', Icons.palette, AppTheme.primaryColor),
            const SizedBox(height: 20),
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
              ],
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
        width: 120,
        height: 100,
        decoration: BoxDecoration(
          color: cardColor ?? defaultCardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected 
                  ? AppTheme.primaryColor.withOpacity(0.3)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isSelected ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppTheme.primaryColor
                  : iconColor ?? AppTheme.primaryColor,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: textColor ?? defaultTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // 构建分区标题
  Widget _buildSectionHeader(String title, IconData? icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 10),
          ],
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
        Container(
          margin: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 备份数据源信息显示
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '当前备份数据源',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            settingsProvider.backupDataSource == 'mysql'
                                ? 'MySQL 远程数据库 (SQL导出备份)'
                                : 'SQLite 本地数据库 (文件复制备份)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: settingsProvider.backupDataSource == 'mysql' 
                            ? Colors.green.withOpacity(0.2) 
                            : Colors.blue.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: settingsProvider.backupDataSource == 'mysql' 
                              ? Colors.green.shade600 
                              : Colors.blue.shade600,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        settingsProvider.backupDataSource == 'mysql' ? 'MySQL' : 'SQLite',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: settingsProvider.backupDataSource == 'mysql' 
                              ? Colors.green.shade700 
                              : Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // 数据备份和恢复备份功能 - 放在同一行，各占一半空间
              Row(
                children: [
                  // 数据备份功能 - 左侧
                  Expanded(
                    child: _buildSettingItem(
                      icon: Icons.backup,
                      title: '数据备份',
                      subtitle: settingsProvider.backupDataSource == 'mysql'
                          ? '将MySQL数据库导出为SQL文件'
                          : '将SQLite数据库文件直接复制备份',
                      trailing: _isBackingUp
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                strokeWidth: 2,
                              ),
                            )
                          : DentalGradientButton(
                              text: '备份',
                              icon: Icons.save,
                              onPressed: () async {
                                setState(() {
                                  _isBackingUp = true;
                                });

                                try {
                                  final path1 = _backupPathController.text;
                                  final path2 = _backupPath2Controller.text;

                                  print('开始执行备份操作');
                                  print('备份目录1: $path1');
                                  print('备份目录2: $path2');

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
                                      print('开始备份到目录1: $path1');
                                      
                                      // 确保目录存在
                                      Directory directory = Directory(path1);
                                      if (!directory.existsSync()) {
                                        try {
                                          directory.createSync(recursive: true);
                                          print('创建目录1: $path1');
                                        } catch (e) {
                                          throw Exception('无法创建目录: $e');
                                        }
                                      }

                                      await settingsProvider.setBackupPath(path1);
                                      print('已设置备份路径1: $path1');
                                      
                                      // 先验证备份路径
                                      final isValid = await settingsProvider.validateBackupPath(path1);
                                      if (!isValid) {
                                        throw Exception('备份路径无效: $path1');
                                      }
                                      print('备份路径1验证通过');
                                      
                                      // 执行备份
                                      final backupPath = await dbProvider.backupDatabase(
                                        backupPath: path1,
                                        onLogSuccess: (path) => settingsProvider.logBackupSuccess(path),
                                        onLogFailure: (error) => settingsProvider.logBackupFailure(error),
                                        backupDataSource: settingsProvider.backupDataSource, // 使用备份数据源设置
                                      );
                                      
                                      print('备份到目录1成功: $backupPath');
                                      
                                      // 更新备份日期
                                      await settingsProvider.updateLastBackupDate(DateTime.now());
                                      backupSuccess = true;
                                      successPaths.add(backupPath);
                                    } catch (e) {
                                      print('备份到目录1失败: $e');
                                      errorMessage = '备份到目录1失败: $e';
                                      print(errorMessage);
                                    }
                                  } else {
                                    print('备份目录1为空，跳过备份');
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
                                      print('开始备份到目录2: $path2');
                                      
                                      // 确保目录存在
                                      Directory directory = Directory(path2);
                                      if (!directory.existsSync()) {
                                        try {
                                          directory.createSync(recursive: true);
                                          print('创建目录2: $path2');
                                        } catch (e) {
                                          throw Exception('无法创建目录: $e');
                                        }
                                      }

                                      await settingsProvider.setBackupPath(path2);
                                      print('已设置备份路径2: $path2');
                                      
                                      // 先验证备份路径
                                      final isValid = await settingsProvider.validateBackupPath(path2);
                                      if (!isValid) {
                                        throw Exception('备份路径无效: $path2');
                                      }
                                      print('备份路径2验证通过');
                                      
                                      // 执行备份到第二个目录
                                      final backupPath2 = await dbProvider.backupDatabase(
                                        backupPath: path2,
                                        onLogSuccess: (path) => settingsProvider.logBackupSuccess(path),
                                        onLogFailure: (error) => settingsProvider.logBackupFailure(error),
                                        backupDataSource: settingsProvider.backupDataSource, // 使用备份数据源设置
                                      );
                                      
                                      print('备份到目录2成功: $backupPath2');
                                      
                                      // 更新备份日期
                                      await settingsProvider.updateLastBackupDate(DateTime.now());
                                      
                                      backupSuccess = true;
                                      successPaths.add(backupPath2);
                                    } catch (e) {
                                      print('备份到目录2失败: $e');
                                      if (errorMessage.isNotEmpty) {
                                        errorMessage += '\n';
                                      }
                                      errorMessage += '备份到目录2失败: $e';
                                      print(errorMessage);
                                    }
                                  } else {
                                    print('备份目录2为空，跳过备份');
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
                                    print('备份失败，错误信息: $errorMessage');
                                    throw Exception(errorMessage.isEmpty
                                        ? '备份失败'
                                        : errorMessage);
                                  }

                                  print('备份完成，成功路径: ${successPaths.join(", ")}');
                                  
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
                  ),
                  
                  const SizedBox(width: 16), // 两个功能之间的间距
                  
                  // 恢复备份功能 - 右侧
                  Expanded(
                    child: _buildSettingItem(
                      icon: Icons.restore,
                      title: '恢复备份',
                      subtitle: settingsProvider.dataSourceType == 'mysql'
                          ? '从SQL文件恢复MySQL数据库'
                          : '从.db文件恢复SQLite数据库',
                      trailing: _isRestoring
                          ? Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                                strokeWidth: 2,
                              ),
                            )
                          : DentalGradientButton(
                              text: '选择文件',
                              icon: Icons.file_open,
                              onPressed: _selectBackupFile,
                            ),
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 20),
              
              // 备份目录设置
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 备份目录1
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder, color: AppTheme.secondaryColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '备份目录 1:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _backupPathController,
                                decoration: InputDecoration(
                                  hintText: '请输入备份目录或留空',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppTheme.secondaryColor, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  suffixIcon: settingsProvider
                                          .backupPath.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
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
                            const SizedBox(width: 12),
                            DentalGradientButton(
                              text: '浏览',
                              icon: Icons.folder_open,
                              onPressed: () => _selectBackupDirectory(false),
                              isOutlined: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  // 备份目录2
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.folder, color: AppTheme.secondaryColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '备份目录 2:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _backupPath2Controller,
                                decoration: InputDecoration(
                                  hintText: '请输入备份目录或留空',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppTheme.secondaryColor, width: 2),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  suffixIcon: settingsProvider
                                          .backupPath2.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear, size: 18),
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
                            const SizedBox(width: 12),
                            DentalGradientButton(
                              text: '浏览',
                              icon: Icons.folder_open,
                              onPressed: () => _selectBackupDirectory(true),
                              isOutlined: true,
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
                  // 使用公用成功提示组件
                  SuccessToastManager.show(context, message: '备份日志已清空');
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

  // 检测数据库结构
  Future<void> _checkDatabaseStructure() async {
    // 显示数据源选择弹窗
    final selectedDataSource = await _showDataSourceSelectionDialog();
    if (selectedDataSource == null) return;

    setState(() {
      _isCheckingStructure = true;
    });

    try {
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 根据选择的数据源设置连接
      if (selectedDataSource == 'sqlite') {
        print('=== 开始SQLite检测，设置数据库连接 ===');
        print('dbProvider.database状态: ${dbProvider.database}');
        print('settingsProvider.database状态: ${settingsProvider.database}');

        // 确保SQLite连接可用
        if (dbProvider.database == null) {
          print('dbProvider.database为null，调用ensureSQLiteDatabase()...');
          await dbProvider.ensureSQLiteDatabase();
          print('ensureSQLiteDatabase()调用完成');
        } else {
          print('dbProvider.database已存在');
        }

        print('设置SQLite连接到settingsProvider...');
        settingsProvider.setDatabaseConnection(database: dbProvider.database);
        print('设置完成');

        print('设置MaterialProvider连接...');
        await materialProvider.setDatabaseConnection(
          database: dbProvider.database,
          dataSourceType: 'sqlite',
        );
        print('MaterialProvider连接设置完成');
      } else if (selectedDataSource == 'mysql') {
        print('=== 开始MySQL检测，设置数据库连接 ===');
        print('dbProvider.database状态: ${dbProvider.database}');
        print('dbProvider.mysqlConnection状态: ${dbProvider.mysqlConnection}');
        print('settingsProvider.database状态: ${settingsProvider.database}');
        print('settingsProvider.mysqlConnection状态: ${settingsProvider.mysqlConnection}');

        // 确保SQLite连接可用（用于保存日志）
        if (dbProvider.database == null) {
          print('dbProvider.database为null，调用ensureSQLiteDatabase()...');
          await dbProvider.ensureSQLiteDatabase();
          print('ensureSQLiteDatabase()调用完成');
        } else {
          print('dbProvider.database已存在');
        }

        // 确保MySQL连接可用
        if (dbProvider.mysqlConnection == null) {
          print('dbProvider.mysqlConnection为null，初始化MySQL连接...');
          final mysqlSettings = settingsProvider.getCompleteMySQLSettings();
          print('MySQL设置: $mysqlSettings');
          if (!settingsProvider.isMySQLSettingsComplete()) {
            throw Exception('MySQL设置不完整，请先在数据源配置中设置MySQL连接参数');
          }
          await dbProvider.initializeMySQLConnection(mysqlSettings);
          print('MySQL连接初始化完成');
        } else {
          print('dbProvider.mysqlConnection已存在');
        }

        // 一次性设置所有连接
        print('一次性设置所有数据库连接...');
        settingsProvider.setDatabaseConnection(
          database: dbProvider.database,
          mysqlConnection: dbProvider.mysqlConnection,
        );
        print('设置完成');

        print('设置MaterialProvider连接...');
        await materialProvider.setDatabaseConnection(
          mysqlConnection: dbProvider.mysqlConnection,
          dataSourceType: 'mysql',
        );
        print('MaterialProvider连接设置完成');
      }
      
      // 使用SettingsProvider的数据库结构检测和更新方法
      final result = await settingsProvider.detectAndUpdateDatabaseStructure(
        targetDataSource: selectedDataSource,
      );

      if (!mounted) return;

      // 显示检测结果
      _showStructureCheckResult(result);

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('数据库结构检测失败: $e'),
          backgroundColor: Colors.red,
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
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.storage, color: AppTheme.primaryColor),
            const SizedBox(width: 12),
            const Text('选择检测数据源'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '请选择要检测的数据库类型：',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            
            // SQLite选项
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                icon: Icon(Icons.storage, color: Colors.blue.shade700),
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SQLite 本地数据库',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '检测本地SQLite数据库表结构',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade50,
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.blue.shade200),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop('sqlite'),
              ),
            ),
            
            // MySQL选项
            Container(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: Icon(Icons.cloud, color: Colors.green.shade700),
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MySQL 远程数据库',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      settingsProvider.isMySQLSettingsComplete()
                          ? '检测MySQL远程数据库表结构'
                          : '需要先配置MySQL连接参数',
                      style: TextStyle(
                        fontSize: 12,
                        color: settingsProvider.isMySQLSettingsComplete()
                            ? Colors.green.shade600
                            : Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: settingsProvider.isMySQLSettingsComplete()
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  foregroundColor: settingsProvider.isMySQLSettingsComplete()
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                  padding: const EdgeInsets.all(16),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: settingsProvider.isMySQLSettingsComplete()
                          ? Colors.green.shade200
                          : Colors.grey.shade300,
                    ),
                  ),
                ),
                onPressed: settingsProvider.isMySQLSettingsComplete()
                    ? () => Navigator.of(context).pop('mysql')
                    : null,
              ),
            ),
            
            if (!settingsProvider.isMySQLSettingsComplete()) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '请先在"数据源配置"中设置MySQL连接参数',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  // 显示结构检测结果
  void _showStructureCheckResult(Map<String, dynamic> result) {
    // 判断检测结果状态
    final hasErrors = (result['errors'] as List).isNotEmpty;
    final hasChanges = (result['structureChanges'] as int) > 0;
    final isSuccess = !hasErrors && !hasChanges; // 无错误且无变化才是完全成功
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : (hasErrors ? Icons.error : Icons.info),
              color: isSuccess ? Colors.green : (hasErrors ? Colors.red : Colors.orange),
            ),
            const SizedBox(width: 8),
            const Text('数据库结构检测结果'),
          ],
        ),
        content: SizedBox(
          width: 700,
          height: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 检测状态卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isSuccess ? Colors.green.shade50 : (hasErrors ? Colors.red.shade50 : Colors.orange.shade50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSuccess ? Colors.green.shade200 : (hasErrors ? Colors.red.shade200 : Colors.orange.shade200),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle : (hasErrors ? Icons.error : Icons.info),
                        size: 56,
                        color: isSuccess ? Colors.green.shade600 : (hasErrors ? Colors.red.shade600 : Colors.orange.shade600),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isSuccess ? '数据库结构完整' : (hasErrors ? '检测发现问题' : '结构已更新'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSuccess ? Colors.green.shade800 : (hasErrors ? Colors.red.shade800 : Colors.orange.shade800),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${result['dataSourceType'].toUpperCase()} 数据库',
                        style: TextStyle(
                          fontSize: 16,
                          color: isSuccess ? Colors.green.shade700 : (hasErrors ? Colors.red.shade700 : Colors.orange.shade700),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '检测时间: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTimeFormatter.fromDbString(result['detectionTime']))}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 检测统计
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics_outlined, size: 24, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Text(
                            '检测统计',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              '系统表',
                              '${result['requiredTables']}',
                              Icons.table_chart,
                              Colors.blue,
                              '个必需表',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '缺失表',
                              '${result['missingTables']}',
                              Icons.table_rows_outlined,
                              Colors.orange,
                              '个缺失',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              '结构变化',
                              '${result['structureChanges']}',
                              Icons.update,
                              Colors.green,
                              '项更新',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 表检测汇总
                _buildTableSummary(result),
                
                const SizedBox(height: 20),
                
                // 详细变化信息
                if (hasChanges || hasErrors) ...[
                  _buildDetailedChanges(result),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 构建统计卡片
  Widget _buildStatCard(String label, String value, IconData icon, Color color, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  // 构建表检测汇总
  Widget _buildTableSummary(Map<String, dynamic> result) {
    final details = result['details'] as Map<String, dynamic>;
    final systemTables = details['systemTables'] as List? ?? [];
    final detectedTables = details['detectedTables'] as List? ?? [];
    final missingTables = details['missingTableNames'] as List? ?? [];
    final createdTables = details['tablesCreated'] as List? ?? [];
    final updatedTables = details['tablesUpdated'] as List? ?? [];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_view, size: 24, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(
                '表检测汇总',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 系统表状态
          _buildSummaryItem(
            '系统必需表',
            '${systemTables.length} 个',
            Icons.table_chart,
            Colors.blue,
            systemTables.join(', '),
          ),
          
          const SizedBox(height: 12),
          
          // 检测到的表
          if (detectedTables.isNotEmpty)
            _buildSummaryItem(
              '检测到的表',
              '${detectedTables.length} 个',
              Icons.check_circle,
              Colors.green,
              detectedTables.join(', '),
            ),
          
          const SizedBox(height: 12),
          
          // 缺失的表
          if (missingTables.isNotEmpty)
            _buildSummaryItem(
              '缺失的表',
              '${missingTables.length} 个',
              Icons.error,
              Colors.red,
              missingTables.join(', '),
            ),
          
          const SizedBox(height: 12),
          
          // 新创建的表
          if (createdTables.isNotEmpty)
            _buildSummaryItem(
              '新创建的表',
              '${createdTables.length} 个',
              Icons.add_circle,
              Colors.green,
              createdTables.join(', '),
            ),
          
          const SizedBox(height: 12),
          
          // 更新的表
          if (updatedTables.isNotEmpty)
            _buildSummaryItem(
              '结构更新的表',
              '${updatedTables.length} 个',
              Icons.update,
              Colors.orange,
              updatedTables.join(', '),
            ),
        ],
      ),
    );
  }

  // 构建汇总项
  Widget _buildSummaryItem(String title, String count, IconData icon, Color color, String details) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: color,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              details,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建详细变化信息
  Widget _buildDetailedChanges(Map<String, dynamic> result) {
    final details = result['details'] as Map<String, dynamic>;
    final errors = result['errors'] as List;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, size: 24, color: Colors.grey.shade700),
              const SizedBox(width: 12),
              Text(
                '详细变化记录',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 新增字段
          if (details['columnsAdded'] != null && (details['columnsAdded'] as List).isNotEmpty) ...[
            _buildChangeSection(
              '新增字段',
              Icons.add_box,
              Colors.green,
              (details['columnsAdded'] as List).map((column) => 
                '${column['table']}.${column['column']} (${column['type']})'
              ).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // 修改字段
          if (details['columnsModified'] != null && (details['columnsModified'] as List).isNotEmpty) ...[
            _buildChangeSection(
              '修改字段',
              Icons.edit,
              Colors.orange,
              (details['columnsModified'] as List).map((column) => 
                '${column['table']}.${column['column']} (${column['oldType']} → ${column['newType']})'
              ).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // 操作日志
          if (details['structureChanges'] != null && (details['structureChanges'] as List).isNotEmpty) ...[
            _buildChangeSection(
              '操作日志',
              Icons.history,
              Colors.blue,
              (details['structureChanges'] as List).cast<String>(),
            ),
            const SizedBox(height: 16),
          ],
          
          // 错误信息
          if (errors.isNotEmpty) ...[
            _buildChangeSection(
              '错误信息',
              Icons.error_outline,
              Colors.red,
              errors.cast<String>(),
            ),
          ],
        ],
      ),
    );
  }

  // 构建变化部分
  Widget _buildChangeSection(String title, IconData icon, Color color, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${items.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            )).toList(),
          ),
        ),
      ],
    );
  }



  // 显示数据库结构检测日志
  void _showStructureCheckLogs() async {
    try {
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
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 确保SettingsProvider能够访问到数据库实例
      if (dbProvider.initialized) {
        print('设置SettingsProvider数据库连接用于显示日志...');
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

      // 显示日志列表
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
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
                      Text('共 ${logs.length} 条记录'),
                      Row(
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.refresh),
                            label: const Text('刷新'),
                            onPressed: () {
                              Navigator.of(context).pop();
                              _showStructureCheckLogs();
                            },
                          ),
                          if (logs.isNotEmpty) TextButton.icon(
                            icon: const Icon(Icons.delete_sweep),
                            label: const Text('清空'),
                            onPressed: () => _clearAllStructureLogs(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  // 日志列表
                  Expanded(
                    child: logs.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline, size: 48, color: Colors.blue),
                                SizedBox(height: 16),
                                Text('暂无检测日志'),
                                SizedBox(height: 8),
                                Text('执行数据库结构检测后将在此显示记录'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: logs.length,
                            itemBuilder: (context, index) {
                              final log = logs[index];
                              return _buildLogItem(context, log, () {
                                Navigator.of(context).pop();
                                _showStructureCheckLogs();
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
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // 关闭加载对话框
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('显示日志信息失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 构建日志项 - 卡片式显示
  Widget _buildLogItem(BuildContext context, DatabaseStructureLog log, VoidCallback onRefresh) {
    // 判断检测结果状态
    final hasErrors = log.errors.isNotEmpty;
    final hasChanges = log.structureChanges > 0;
    final isSuccess = !hasErrors && !hasChanges; // 无错误且无变化才是完全成功
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (isSuccess) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
      statusText = '结构完整';
    } else if (hasErrors) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
      statusText = '发现问题';
    } else {
      statusColor = Colors.orange;
      statusIcon = Icons.info;
      statusText = '已更新';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showLogDetails(context, log, onRefresh),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部信息
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.summary.isNotEmpty ? log.summary : '数据库结构检测',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                log.dataSourceType.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey.shade400),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 统计信息
              Row(
                children: [
                  _buildLogStatChip('必需表', log.requiredTables, Icons.table_chart, Colors.blue),
                  const SizedBox(width: 8),
                  _buildLogStatChip('缺失表', log.missingTables, Icons.table_rows_outlined, Colors.orange),
                  const SizedBox(width: 8),
                  _buildLogStatChip('变更', log.structureChanges, Icons.update, Colors.green),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // 时间信息
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(log.detectionTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '点击查看详情',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 构建日志统计芯片
  Widget _buildLogStatChip(String label, int value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 显示日志详情
  void _showLogDetails(BuildContext context, DatabaseStructureLog log, VoidCallback onRefresh) {
    // 判断检测结果状态
    final hasErrors = log.errors.isNotEmpty;
    final hasChanges = log.structureChanges > 0;
    final isSuccess = !hasErrors && !hasChanges;
    
    Color statusColor = isSuccess ? Colors.green : (hasErrors ? Colors.red : Colors.orange);
    IconData statusIcon = isSuccess ? Icons.check_circle : (hasErrors ? Icons.error : Icons.info);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(statusIcon, color: statusColor),
            const SizedBox(width: 8),
            const Text('检测日志详情'),
          ],
        ),
        content: SizedBox(
          width: 600,
          height: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 状态卡片
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(statusIcon, size: 40, color: statusColor),
                      const SizedBox(height: 8),
                      Text(
                        log.summary.isNotEmpty ? log.summary : '数据库结构检测',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${log.dataSourceType.toUpperCase()} - ${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.detectionTime)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 统计信息
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '检测统计',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _buildDetailStatItem('必需表', log.requiredTables, Icons.table_chart, Colors.blue)),
                          Expanded(child: _buildDetailStatItem('缺失表', log.missingTables, Icons.table_rows_outlined, Colors.orange)),
                          Expanded(child: _buildDetailStatItem('结构变更', log.structureChanges, Icons.update, Colors.green)),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // 详细信息
                if (log.details.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '详细信息',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // 检测到的表
                        if (log.details['detectedTables'] != null && (log.details['detectedTables'] as List).isNotEmpty) ...[
                          _buildDetailInfoItem(
                            '检测到的表',
                            (log.details['detectedTables'] as List).join(', '),
                            Icons.check_circle,
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // 缺失的表
                        if (log.details['missingTableNames'] != null && (log.details['missingTableNames'] as List).isNotEmpty) ...[
                          _buildDetailInfoItem(
                            '缺失的表',
                            (log.details['missingTableNames'] as List).join(', '),
                            Icons.error,
                            Colors.red,
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // 新创建的表
                        if (log.details['tablesCreated'] != null && (log.details['tablesCreated'] as List).isNotEmpty) ...[
                          _buildDetailInfoItem(
                            '新创建的表',
                            (log.details['tablesCreated'] as List).join(', '),
                            Icons.add_circle,
                            Colors.green,
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // 更新的表
                        if (log.details['tablesUpdated'] != null && (log.details['tablesUpdated'] as List).isNotEmpty) ...[
                          _buildDetailInfoItem(
                            '结构更新的表',
                            (log.details['tablesUpdated'] as List).join(', '),
                            Icons.update,
                            Colors.orange,
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // 新增的字段
                        if (log.details['columnsAdded'] != null && (log.details['columnsAdded'] as List).isNotEmpty) ...[
                          _buildDetailInfoItem(
                            '新增字段',
                            (log.details['columnsAdded'] as List).map((column) => 
                              '${column['table']}.${column['column']} (${column['type']})'
                            ).join(', '),
                            Icons.add_box,
                            Colors.green,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // 错误信息
                if (log.errors.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red.shade700),
                            const SizedBox(width: 8),
                            Text(
                              '错误信息',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...log.errors.map((error) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('• ', style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  error,
                                  style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.delete),
            label: const Text('删除'),
            onPressed: () {
              Navigator.of(context).pop();
              _deleteStructureLog(context, log.id!, onRefresh);
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  // 构建详细统计项
  Widget _buildDetailStatItem(String label, int value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  // 构建详细信息项
  Widget _buildDetailInfoItem(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }



  // 删除单条日志
  void _deleteStructureLog(BuildContext context, int logId, VoidCallback onRefresh) async {
    try {
      final confirmed = await DeleteConfirmDialogManager.show(
        context,
        title: '确认删除',
        message: '确定要删除这条检测日志吗？',
      );

      if (confirmed == true) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
        
        // 确保SettingsProvider能够访问到数据库实例
        if (dbProvider.initialized) {
          print('设置SettingsProvider数据库连接用于删除日志...');
          settingsProvider.setDatabaseConnection(
            database: dbProvider.database,
            mysqlConnection: dbProvider.mysqlConnection,
          );
        }
        
        final success = await settingsProvider.deleteDatabaseStructureLog(logId);
        
        if (success) {
          // 使用公用删除成功提示组件
          DeleteSuccessToastManager.show(context, message: '日志删除成功');
          onRefresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('日志删除失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 重置应用数据
  Future<void> _resetAppData() async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 头部 - 橙色背景
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade400, Colors.red.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        '重置应用数据',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 内容区域
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '此操作将清除所有应用数据，包括：',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // 数据项列表
                      _buildResetDataItem('数据库文件', Icons.storage),
                      _buildResetDataItem('配置信息', Icons.settings),
                      _buildResetDataItem('备份日志', Icons.history),
                      _buildResetDataItem('缓存文件', Icons.folder_delete),
                      
                      const SizedBox(height: 20),
                      
                      // 警告提示
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: Colors.red.shade600,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '此操作不可恢复，请谨慎操作！',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // 安全提示
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: Colors.blue.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '建议在重置前先进行数据备份。',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // 底部按钮
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: Colors.grey.shade400),
                          ),
                          child: const Text(
                            '取消',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            '确认重置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (confirmed == true) {
        // 显示进度对话框
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('正在重置应用数据...'),
              ],
            ),
          ),
        );

        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
        
        // 1. 清除SharedPreferences
        await settingsProvider.clearAllSettings();
        
        // 2. 关闭数据库连接
        await dbProvider.closeDatabase();
        
        // 3. 删除数据目录
        try {
          final dataDir = Directory(AppPaths.dataDirectory);
          if (await dataDir.exists()) {
            await dataDir.delete(recursive: true);
          }
        } catch (e) {
          print('删除数据目录失败: $e');
        }
        
        // 4. 重新初始化
        await AppPaths.initialize();
        await AppPaths.initializeAllDirectories();
        
        if (!mounted) return;
        
        // 关闭进度对话框
        Navigator.of(context).pop();
        
        // 显示成功消息
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('应用数据已重置，请重启应用以完成重置'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        
        // 建议重启应用
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('重置完成'),
            content: const Text('应用数据已成功重置。建议您重启应用以确保所有更改生效。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      
      // 关闭可能的进度对话框
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('重置失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 获取数据存储位置
  String _getDataStorageLocation(SettingsProvider settingsProvider) {
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

  // 打开数据存储位置
  Future<void> _openDataStorageLocation(SettingsProvider settingsProvider) async {
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
          if (!mounted) return;
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
        if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开目录: $e')),
      );
    }
  }

  // 清空所有日志
  void _clearAllStructureLogs(BuildContext context) async {
    try {
      final confirmed = await DeleteConfirmDialogManager.show(
        context,
        title: '确认清空',
        message: '确定要清空所有检测日志吗？此操作不可恢复。',
        confirmText: '清空',
      );

      if (confirmed == true) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
        
        // 确保SettingsProvider能够访问到数据库实例
        if (dbProvider.initialized) {
          print('设置SettingsProvider数据库连接用于删除日志...');
          settingsProvider.setDatabaseConnection(
            database: dbProvider.database,
            mysqlConnection: dbProvider.mysqlConnection,
          );
        }
        
        final success = await settingsProvider.clearAllDatabaseStructureLogs();
        
        if (success) {
          // 使用公用成功提示组件
          SuccessToastManager.show(context, message: '所有日志已清空');
          Navigator.of(context).pop();
          _showStructureCheckLogs();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('清空日志失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('清空失败: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // 构建重置数据项
  Widget _buildResetDataItem(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.red.shade600,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }


}

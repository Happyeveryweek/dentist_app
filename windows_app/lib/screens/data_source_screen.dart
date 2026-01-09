import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/database_provider.dart';
import '../providers/purchase_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/material_provider.dart';
import '../widgets/dental_icons.dart';
import '../widgets/success_toast.dart';

class DataSourceScreen extends StatefulWidget {
  const DataSourceScreen({Key? key}) : super(key: key);

  @override
  State<DataSourceScreen> createState() => _DataSourceScreenState();
}

class _DataSourceScreenState extends State<DataSourceScreen> {
  // 数据源类型
  String _selectedDataSource = 'sqlite'; // sqlite 或 mysql
  
  // 数据源切换模式：'global' 或 'modular'
  String _dataSourceMode = 'global';

  // SQLite 文件路径
  String _sqliteDbPath = '';

  // MySQL连接参数
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '3306');
  final _databaseController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // 模块数据源配置
  Map<String, String> _moduleDataSources = {
    'patients': 'sqlite',      // 患者管理
    'appointments': 'sqlite',  // 预约管理
    'financial': 'sqlite',     // 财务管理
    'materials': 'sqlite',     // 材料管理
    'purchase': 'sqlite',      // 采购管理
    'users': 'sqlite',         // 用户管理
  };

  // 备份数据源设置
  String _backupDataSource = 'sqlite';

  // 原始设置备份（用于取消时恢复）
  Map<String, String> _originalModuleDataSources = {};
  String _originalDataSource = 'sqlite';
  String _originalDataSourceMode = 'global';
  String _originalBackupDataSource = 'sqlite';
  
  // 各个部分的编辑状态
  bool _isDataSourceTypeEditing = false;
  bool _isBackupDataSourceEditing = false;
  bool _isSqliteEditing = false;
  
  // SQLite原始路径（用于取消时恢复）
  String _originalSqliteDbPath = '';

  final _formKey = GlobalKey<FormState>();
  bool _isTestingConnection = false;
  bool _isSavingSettings = false;
  bool _connectionTested = false;
  bool _connectionSuccess = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    // 初始化数据源类型和MySQL连接参数
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);

      setState(() {
        // 1. 加载数据源模式配置
        _dataSourceMode = settingsProvider.dataSourceMode ?? 'global';
        
        // 2. 根据模式加载相应的数据源配置
        if (_dataSourceMode == 'global') {
          // 全局模式：所有模块使用相同的数据源
          _selectedDataSource = settingsProvider.dataSourceType ?? 'mysql'; // 全局模式默认MySQL
          
          // 同步所有模块的数据源
          for (String key in _moduleDataSources.keys) {
            _moduleDataSources[key] = _selectedDataSource;
          }
        } else {
          // 模块化模式：每个模块使用独立的数据源
          _selectedDataSource = settingsProvider.dataSourceType ?? 'sqlite'; // 模块化模式默认SQLite
          
          // 加载模块数据源配置
          final moduleDataSources = settingsProvider.moduleDataSources;
          if (moduleDataSources.isNotEmpty) {
            // 使用保存的模块配置
            _moduleDataSources = Map<String, String>.from(moduleDataSources);
          } else {
            // 如果没有保存的配置，设置默认值为sqlite
            _moduleDataSources = {
              'patients': 'sqlite',      // 患者管理
              'appointments': 'sqlite',  // 预约管理
              'financial': 'sqlite',     // 财务管理
              'materials': 'sqlite',     // 材料管理
              'purchase': 'sqlite',      // 采购管理
              'users': 'sqlite',         // 用户管理
            };
          }
        }
        
        // 3. 加载其他配置
        _sqliteDbPath = settingsProvider.sqliteDbPath ?? '';
        _hostController.text = settingsProvider.mysqlHost ?? '';
        _portController.text = settingsProvider.mysqlPort ?? '3306';
        _databaseController.text = settingsProvider.mysqlDatabase ?? '';
        _usernameController.text = settingsProvider.mysqlUsername ?? '';
        _passwordController.text = settingsProvider.mysqlPassword ?? '';
        _backupDataSource = settingsProvider.backupDataSource ?? 'sqlite';
        
        // 4. 保存原始设置
        _originalModuleDataSources = Map<String, String>.from(_moduleDataSources);
        _originalDataSource = _selectedDataSource;
        _originalDataSourceMode = _dataSourceMode;
        _originalBackupDataSource = _backupDataSource;
        _originalSqliteDbPath = _sqliteDbPath;
        
        print('初始化完成 - 模式: $_dataSourceMode, 数据源: $_selectedDataSource, 模块配置: $_moduleDataSources');
      });

      // 如果已经配置过MySQL，就默认为已测试通过
      if (_selectedDataSource == 'mysql' &&
          _hostController.text.isNotEmpty &&
          _databaseController.text.isNotEmpty) {
        _connectionTested = true;
        _connectionSuccess = true;
      }
      
      // 5. 更新所有Provider的模块数据源配置
      _updateAllProvidersModuleDataSources();
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: const Icon(
                Icons.storage_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '数据源配置',
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
            _buildPageHeader(),
            const SizedBox(height: 24),
            
            // 第一区域：数据源配置
            _buildDataSourceConfigurationSection(),
            const SizedBox(height: 24),
            
            // 第二区域：数据源类型切换
            _buildDataSourceTypeSwitchSection(),
            const SizedBox(height: 24),
            
            // 第三区域：备份数据源设置
            _buildBackupDataSourceSection(),
            const SizedBox(height: 24),
            
                         // 移除主保存按钮，只保留各模块的独立按钮
          ],
        ),
      ),
    );
  }

  // 获取模块显示名称
  String _getModuleDisplayName(String moduleKey) {
    switch (moduleKey) {
      case 'patients':
        return '患者管理';
      case 'appointments':
        return '预约管理';
      case 'financial':
        return '财务管理';
      case 'materials':
        return '材料管理';
      case 'purchase':
        return '采购管理';
      case 'users':
        return '用户管理';
      default:
        return moduleKey;
    }
  }

  // 构建数据源状态显示
  Widget _buildDataSourceStatusDisplay() {
    if (_dataSourceMode == 'global') {
      // 全局配置模式
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _selectedDataSource == 'sqlite' 
                ? Icons.storage_rounded 
                : Icons.cloud_done_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '全局配置',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                _selectedDataSource == 'sqlite' ? 'SQLite' : 'MySQL',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
              ),
              Text(
                '所有模块使用相同数据源',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 8,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // 模块化配置模式
      // 统计各数据源的模块数量
      final sqliteModules = _moduleDataSources.values.where((ds) => ds == 'sqlite').length;
      final mysqlModules = _moduleDataSources.values.where((ds) => ds == 'mysql').length;
      
      // 获取具体的模块名称
      final sqliteModuleNames = _moduleDataSources.entries
          .where((entry) => entry.value == 'sqlite')
          .map((entry) => _getModuleDisplayName(entry.key))
          .toList();
      final mysqlModuleNames = _moduleDataSources.entries
          .where((entry) => entry.value == 'mysql')
          .map((entry) => _getModuleDisplayName(entry.key))
          .toList();
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.grid_view_rounded,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '模块化配置',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (sqliteModules > 0)
                Text(
                  'SQLite: ${sqliteModuleNames.join(', ')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              if (mysqlModules > 0)
                Text(
                  'MySQL: ${mysqlModuleNames.join(', ')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      );
    }
  }

  // 构建页面标题
  Widget _buildPageHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.storage_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '数据源配置中心',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '配置SQLite本地数据库或MySQL远程数据库连接',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: _buildDataSourceStatusDisplay(),
          ),
        ],
      ),
    );
  }

  // 构建数据源配置区域
  Widget _buildDataSourceConfigurationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('数据源配置', Icons.settings_rounded, AppTheme.primaryColor),
        Container(
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
                // SQLite配置
                _buildSqliteConfiguration(),
                const Divider(height: 32, thickness: 1),
                // MySQL配置
                _buildMySQLConfiguration(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 构建数据源类型切换区域
  Widget _buildDataSourceTypeSwitchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('数据源类型切换', Icons.swap_horiz_rounded, AppTheme.secondaryColor),
        Container(
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
            padding: const EdgeInsets.all(20), // 从24减少到20
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题行，包含编辑/保存/取消按钮
                _buildDataSourceTypeSwitchHeader(),
                const SizedBox(height: 20), // 从24减少到20
                
                // 切换模式选择
                _buildDataSourceModeSelection(),
                const SizedBox(height: 20), // 从24减少到20
                
                // 根据选择的模式显示不同的内容
                if (_dataSourceMode == 'global') ...[
                  _buildGlobalDataSourceSwitch(),
                ] else ...[
                  _buildModularDataSourceSwitch(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 构建数据源类型切换标题行
  Widget _buildDataSourceTypeSwitchHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.swap_horiz_rounded,
            color: AppTheme.secondaryColor,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          '数据源切换配置',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const Spacer(),
        // 编辑/保存/取消按钮 - 改为蓝色
        if (!_isDataSourceTypeEditing) ...[
          ElevatedButton.icon(
            onPressed: () {
              print('点击编辑按钮，当前编辑状态: $_isDataSourceTypeEditing');
              setState(() {
                _isDataSourceTypeEditing = true;
              });
              print('编辑状态已设置为: $_isDataSourceTypeEditing');
            },
            icon: const Icon(Icons.edit_rounded),
            label: const Text('编辑'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor, // 改为蓝色
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ] else ...[
          TextButton.icon(
            onPressed: _cancelDataSourceTypeChanges,
            icon: const Icon(Icons.close_rounded),
            label: const Text('取消'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _saveDataSourceTypeSettings,
            icon: const Icon(Icons.save_rounded),
            label: const Text('保存'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor, // 改为蓝色
              foregroundColor: Colors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 构建数据源切换模式选择
  Widget _buildDataSourceModeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: AppTheme.secondaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '选择数据源切换模式',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 并排的切换模式选择 - 更紧凑的设计
        Row(
          children: [
            // 全局数据源切换
            Expanded(
              child: _buildCompactModeOption(
                'global',
                '全局数据源切换',
                '所有模块使用相同的数据源类型',
                Icons.public_rounded,
                Colors.blue,
                _dataSourceMode == 'global',
                _isDataSourceTypeEditing ? () {
                  setState(() {
                    _dataSourceMode = 'global';
                    // 当切换到全局模式时，所有模块使用相同的数据源
                    for (String key in _moduleDataSources.keys) {
                      _moduleDataSources[key] = _selectedDataSource;
                    }
                    print('切换到全局模式，所有模块使用数据源: $_selectedDataSource');
                  });
                } : null,
              ),
            ),
            const SizedBox(width: 12), // 从16减少到12
            // 模块化数据源切换
            Expanded(
              child: _buildCompactModeOption(
                'modular',
                '模块化数据源切换',
                '为不同模块设置不同的数据源',
                Icons.grid_view_rounded,
                Colors.green,
                _dataSourceMode == 'modular',
                _isDataSourceTypeEditing ? () {
                  print('点击模块化模式按钮，当前编辑状态: $_isDataSourceTypeEditing');
                  setState(() {
                    _dataSourceMode = 'modular';
                    print('切换到模块化模式，当前模块配置: $_moduleDataSources');
                    // 切换到模块化模式时，重新加载保存的模块配置
                    _reloadModuleDataSources();
                  });
                  print('切换完成，当前模式: $_dataSourceMode');
                } : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 构建紧凑的模式选项
  Widget _buildCompactModeOption(
    String value,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16), // 从20减少到16
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12), // 从16减少到12
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10), // 从12减少到10
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10), // 从12减少到10
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 24, // 从28减少到24
              ),
            ),
            const SizedBox(height: 12), // 从16减少到12
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14, // 从16减少到14
                color: isSelected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6), // 从8减少到6
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11, // 从12减少到11
                color: isSelected ? color.withOpacity(0.8) : Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8), // 从12减少到8
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), // 从12,6减少到10,4
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10), // 从12减少到10
                ),
                child: const Text(
                  '已选择',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10, // 从11减少到10
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建全局数据源切换
  Widget _buildGlobalDataSourceSwitch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.public_rounded,
                color: Colors.blue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '全局数据源选择',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 并排显示SQLite和MySQL选项 - 更紧凑的设计
        Row(
          children: [
            // SQLite选项
            Expanded(
              child: _buildCompactDataSourceOption(
                'sqlite',
                'SQLite (本地数据库)',
                '数据存储在本地设备上，无需网络连接，适合单机使用',
                '快速、轻量、无需配置服务器',
                Icons.storage_rounded,
                Colors.blue,
                _selectedDataSource == 'sqlite',
                _isDataSourceTypeEditing ? (value) {
                  setState(() {
                    _selectedDataSource = value!;
                    // 当选择全局模式时，同步更新所有模块
                    if (_dataSourceMode == 'global') {
                      for (String key in _moduleDataSources.keys) {
                        _moduleDataSources[key] = value;
                      }
                    }
                  });
                } : null,
              ),
            ),
            const SizedBox(width: 12), // 从16减少到12
            // MySQL选项
            Expanded(
              child: _buildCompactDataSourceOption(
                'mysql',
                'MySQL (远程数据库)',
                '数据存储在远程服务器上，可多设备共享数据',
                '支持多用户、数据同步、备份恢复',
                Icons.cloud_done_rounded,
                Colors.green,
                _selectedDataSource == 'mysql',
                _isDataSourceTypeEditing ? (value) {
                  setState(() {
                    _selectedDataSource = value!;
                    // 当选择全局模式时，同步更新所有模块
                    if (_dataSourceMode == 'global') {
                      for (String key in _moduleDataSources.keys) {
                        _moduleDataSources[key] = value;
                      }
                    }
                  });
                } : null,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '全局切换将影响所有模块的数据源类型。当前已选择 $_dataSourceMode 模式。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建紧凑的数据源选项
  Widget _buildCompactDataSourceOption(
    String value,
    String title,
    String subtitle,
    String description,
    IconData icon,
    Color color,
    bool isSelected,
    Function(String?)? onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6), // 从8减少到6
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12), // 从16减少到12
        border: Border.all(
          color: isSelected ? color.withOpacity(0.3) : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          unselectedWidgetColor: AppTheme.secondaryText,
        ),
        child: RadioListTile<String>(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // 从8减少到6
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6), // 从8减少到6
                ),
                child: Icon(icon, color: color, size: 18), // 从20减少到18
              ),
              const SizedBox(width: 10), // 从12减少到10
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14, // 从16减少到14
                      ),
                    ),
                    const SizedBox(height: 3), // 从4减少到3
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12, // 从14减少到12
                      ),
                    ),
                    const SizedBox(height: 3), // 从4减少到3
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10, // 从12减少到10
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          value: value,
          groupValue: _selectedDataSource,
          onChanged: onChanged,
          activeColor: color,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), // 从16,16减少到12,12
        ),
      ),
    );
  }

  // 构建模块化数据源切换
  Widget _buildModularDataSourceSwitch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                color: Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '模块数据源配置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // 6个模块占用一行空间
        Row(
          children: [
            Expanded(
              child: _buildModuleDataSourceCard(
                'patients',
                '患者管理',
                Icons.people_rounded,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'appointments',
                '预约管理',
                Icons.calendar_today_rounded,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'financial',
                '财务管理',
                Icons.account_balance_wallet_rounded,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'materials',
                '材料管理',
                Icons.inventory_2_rounded,
                Colors.purple,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'purchase',
                '采购管理',
                Icons.shopping_cart_rounded,
                Colors.teal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModuleDataSourceCard(
                'users',
                '用户管理',
                Icons.manage_accounts_rounded,
                Colors.indigo,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '模块自定义设置允许您为不同的功能模块选择最适合的数据源。例如：患者数据使用SQLite本地存储，财务数据使用MySQL远程存储。',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建模块数据源卡片
  Widget _buildModuleDataSourceCard(String moduleKey, String moduleName, IconData icon, Color color) {
    // 根据当前模式决定显示的数据源
    final currentDataSource = _dataSourceMode == 'global' 
        ? _selectedDataSource  // 全局模式：显示全局选择的数据源
        : (_moduleDataSources[moduleKey] ?? 'sqlite');  // 模块化模式：显示模块配置的数据源
    
    // 添加调试信息
    print('构建模块卡片: $moduleKey, 当前数据源: $currentDataSource, 模式: $_dataSourceMode, 模块配置: $_moduleDataSources');
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 模块图标和名称
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  moduleName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          
          // 当前数据源显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: currentDataSource == 'sqlite' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentDataSource == 'sqlite' ? Colors.blue.withOpacity(0.3) : Colors.green.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  currentDataSource == 'sqlite' ? Icons.storage_rounded : Icons.cloud_done_rounded,
                  size: 10,
                  color: currentDataSource == 'sqlite' ? Colors.blue : Colors.green,
                ),
                const SizedBox(width: 3),
                Text(
                  currentDataSource == 'sqlite' ? 'SQLite' : 'MySQL',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: currentDataSource == 'sqlite' ? Colors.blue : Colors.green,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          
          // 切换按钮
          Row(
            children: [
              Expanded(
                child: _buildModuleDataSourceToggleButton(
                  moduleKey,
                  'sqlite',
                  'SQLite',
                  Icons.storage_rounded,
                  Colors.blue,
                  currentDataSource == 'sqlite',
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildModuleDataSourceToggleButton(
                  moduleKey,
                  'mysql',
                  'MySQL',
                  Icons.cloud_done_rounded,
                  Colors.green,
                  currentDataSource == 'mysql',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 构建模块数据源切换按钮
  Widget _buildModuleDataSourceToggleButton(
    String moduleKey,
    String dataSource,
    String label,
    IconData icon,
    Color color,
    bool isSelected,
  ) {
    // 在全局模式下，按钮不可用
    final isEnabled = _isDataSourceTypeEditing && _dataSourceMode == 'modular';
    
    // 在全局模式下，如果当前选择的数据源与按钮匹配，则显示为选中状态
    final shouldShowAsSelected = _dataSourceMode == 'global' 
        ? (_selectedDataSource == dataSource) 
        : isSelected;
    
    // 添加调试信息
    print('构建模块按钮: $moduleKey, 数据源: $dataSource, 启用状态: $isEnabled, 模式: $_dataSourceMode, 编辑状态: $_isDataSourceTypeEditing');
    
    return GestureDetector(
      onTap: isEnabled ? () {
        print('点击模块按钮: $moduleKey, 设置数据源为: $dataSource');
        setState(() {
          _moduleDataSources[moduleKey] = dataSource;
        });
        print('模块配置已更新: $_moduleDataSources');
      } : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        decoration: BoxDecoration(
          color: shouldShowAsSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: shouldShowAsSelected ? color : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: shouldShowAsSelected ? Colors.white : (isEnabled ? color : Colors.grey.shade400),
              size: 12,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                color: shouldShowAsSelected ? Colors.white : (isEnabled ? color : Colors.grey.shade400),
                fontSize: 8,
                fontWeight: shouldShowAsSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }



  // 构建备份数据源设置区域
  Widget _buildBackupDataSourceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('备份数据源设置', Icons.backup_rounded, AppTheme.accentColor),
        Container(
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
            child: _buildBackupDataSourceConfiguration(),
          ),
        ),
      ],
    );
  }



  // 构建分区标题
  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // 其他方法将在下一步实现...
  Widget _buildSqliteConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.storage_rounded,
                color: Colors.blue.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'SQLite 配置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            // 添加编辑/保存/取消按钮
            if (!_isSqliteEditing) ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isSqliteEditing = true;
                    // 保存原始路径用于取消时恢复
                    _originalSqliteDbPath = _sqliteDbPath;
                  });
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('编辑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isSqliteEditing = false;
                    // 恢复到原始路径
                    _sqliteDbPath = _originalSqliteDbPath;
                  });
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('取消'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saveSqliteSettings,
                icon: const Icon(Icons.save_rounded),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.blue.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              _sqliteDbPath.isEmpty ? '使用默认数据库文件' : '已选择数据库文件',
                              style: TextStyle(
                                color: _sqliteDbPath.isEmpty ? Colors.grey.shade600 : AppTheme.successColor,
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            if (_sqliteDbPath.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppTheme.successColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 14,
                                      color: AppTheme.successColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '已配置',
                                      style: TextStyle(
                                        color: AppTheme.successColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: _sqliteDbPath.isNotEmpty ? BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.successColor.withOpacity(0.2),
                              width: 1,
                            ),
                          ) : null,
                          child: Text(
                            _sqliteDbPath.isEmpty ? '系统将使用默认位置的数据库文件' : _sqliteDbPath,
                            style: TextStyle(
                              color: _sqliteDbPath.isEmpty ? Colors.grey.shade500 : AppTheme.successColor,
                              fontSize: 12,
                              fontWeight: _sqliteDbPath.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  if (_isSqliteEditing)
                    ElevatedButton.icon(
                      onPressed: _selectSqliteDatabase,
                      icon: const Icon(Icons.folder_open_rounded),
                      label: const Text('选择文件'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 16,
                    color: Colors.amber.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '如不选择，将使用默认位置的数据库文件',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.amber.shade700,
                      fontStyle: FontStyle.italic,
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

  Widget _buildMySQLConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.cloud_done_rounded,
                color: Colors.green.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'MySQL 配置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            // 添加编辑/保存/取消按钮
            if (!_isEditing) ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = true;
                    _connectionTested = false;
                    _connectionSuccess = false;
                  });
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('编辑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    // 恢复到原始设置
                    _hostController.text = Provider.of<SettingsProvider>(context, listen: false).mysqlHost ?? '';
                    _portController.text = Provider.of<SettingsProvider>(context, listen: false).mysqlPort ?? '3306';
                    _databaseController.text = Provider.of<SettingsProvider>(context, listen: false).mysqlDatabase ?? '';
                    _usernameController.text = Provider.of<SettingsProvider>(context, listen: false).mysqlUsername ?? '';
                    _passwordController.text = Provider.of<SettingsProvider>(context, listen: false).mysqlPassword ?? '';
                  });
                },
                icon: const Icon(Icons.close_rounded),
                label: const Text('取消'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saveMySQLSettings,
                icon: const Icon(Icons.save_rounded),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        if (!_isEditing) ...[
          // 显示当前MySQL连接信息（只读模式）
          _buildMySQLReadOnlyMode(),
        ] else ...[
          // 编辑模式下的表单
          _buildMySQLEditMode(),
        ],
      ],
    );
  }

  // 构建MySQL只读模式
  Widget _buildMySQLReadOnlyMode() {
    return Container(
      padding: const EdgeInsets.all(16), // 从20减少到16
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 所有5个配置项放在一排
          Row(
            children: [
              // 主机地址
              Expanded(
                child: _buildCompactSettingItem(
                  icon: Icons.computer_rounded,
                  title: '主机地址',
                  value: _hostController.text.isEmpty ? '未设置' : _hostController.text,
                  iconColor: Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              // 端口
              Expanded(
                child: _buildCompactSettingItem(
                  icon: Icons.settings_ethernet_rounded,
                  title: '端口',
                  value: _portController.text.isEmpty ? '未设置' : _portController.text,
                  iconColor: Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              // 数据库名称
              Expanded(
                child: _buildCompactSettingItem(
                  icon: Icons.account_tree_rounded,
                  title: '数据库名称',
                  value: _databaseController.text.isEmpty ? '未设置' : _databaseController.text,
                  iconColor: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              // 用户名
              Expanded(
                child: _buildCompactSettingItem(
                  icon: Icons.person_rounded,
                  title: '用户名',
                  value: _usernameController.text.isEmpty ? '未设置' : _usernameController.text,
                  iconColor: Colors.orange,
                ),
              ),
              const SizedBox(width: 8),
              // 密码
              Expanded(
                child: _buildCompactSettingItem(
                  icon: Icons.lock_rounded,
                  title: '密码',
                  value: _passwordController.text.isEmpty ? '未设置' : '••••••',
                  iconColor: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 信息提示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  '点击上方的"编辑"按钮可以修改MySQL连接配置',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建MySQL编辑模式
  Widget _buildMySQLEditMode() {
    return Container(
      padding: const EdgeInsets.all(16), // 从20减少到16
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // 所有5个输入框放在一排
            Row(
              children: [
                // 主机地址
                Expanded(
                  child: _buildCompactFormField(
                    controller: _hostController,
                    labelText: '主机地址',
                    hintText: 'localhost 或 IP地址',
                    icon: Icons.computer_rounded,
                    iconColor: Colors.blue,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入主机地址';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 端口
                Expanded(
                  child: _buildCompactFormField(
                    controller: _portController,
                    labelText: '端口',
                    hintText: '3306',
                    icon: Icons.settings_ethernet_rounded,
                    iconColor: Colors.teal,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入端口号';
                      }
                      if (int.tryParse(value) == null) {
                        return '端口号必须是数字';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 数据库名称
                Expanded(
                  child: _buildCompactFormField(
                    controller: _databaseController,
                    labelText: '数据库名称',
                    hintText: '输入数据库名称',
                    icon: Icons.account_tree_rounded,
                    iconColor: Colors.purple,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入数据库名称';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 用户名
                Expanded(
                  child: _buildCompactFormField(
                    controller: _usernameController,
                    labelText: '用户名',
                    hintText: '输入数据库用户名',
                    icon: Icons.person_rounded,
                    iconColor: Colors.orange,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // 密码
                Expanded(
                  child: _buildCompactFormField(
                    controller: _passwordController,
                    labelText: '密码',
                    hintText: '输入数据库密码',
                    icon: Icons.lock_rounded,
                    iconColor: Colors.red,
                    obscureText: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '请先测试连接确保配置正确，然后再保存设置',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 连接测试成功提示
            if (_connectionTested && _connectionSuccess)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '连接测试成功',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            // 测试连接按钮
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isTestingConnection ? null : _testMySQLConnection,
                  icon: _isTestingConnection
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link_rounded),
                  label: const Text('测试连接'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 选择SQLite数据库文件
  Future<void> _selectSqliteDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        dialogTitle: '选择SQLite数据库文件',
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      String filePath = result.files.single.path!;

      // 检查文件是否存在
      if (!await File(filePath).exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('选择的文件不存在')));
        return;
      }

      setState(() {
        _sqliteDbPath = filePath;
      });

      if (!mounted) return;
      // 使用公用成功提示组件
      SuccessToastManager.show(
        context, 
        message: '已选择数据库文件: ${path.basename(filePath)}'
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('选择文件时出错: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  // 测试MySQL连接
  Future<void> _testMySQLConnection() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionTested = true;
      _connectionSuccess = false;
    });

    try {
      // 获取数据库提供者
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 测试连接
      bool success = await dbProvider.testMySQLConnection(
        host: _hostController.text,
        port: int.parse(_portController.text),
        database: _databaseController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      setState(() {
        _connectionSuccess = success;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('连接成功！'),
            backgroundColor: Theme.of(context).scaffoldBackgroundColor ==
                    AppTheme.purpleBackground
                ? AppTheme.purpleColor
                : AppTheme.successColor,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('连接失败，请检查连接参数'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接错误: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  // 构建设置项
  Widget _buildEnhancedSettingItem({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: value == '未设置' ? Colors.grey.shade500 : Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建增强的表单字段
  Widget _buildEnhancedFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // 构建紧凑设置项
  Widget _buildCompactSettingItem({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: value == '未设置' ? Colors.grey.shade500 : Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建紧凑表单字段
  Widget _buildCompactFormField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData icon,
    required Color iconColor,
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: iconColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildBackupDataSourceConfiguration() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.backup_rounded,
                color: AppTheme.accentColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '备份数据源设置',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            // 添加编辑/保存/取消按钮
            if (!_isBackupDataSourceEditing) ...[
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isBackupDataSourceEditing = true;
                  });
                },
                icon: const Icon(Icons.edit_rounded),
                label: const Text('编辑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ] else ...[
              TextButton.icon(
                onPressed: _cancelBackupDataSourceChanges,
                icon: const Icon(Icons.close_rounded),
                label: const Text('取消'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _saveBackupDataSourceSettingsOnly,
                icon: const Icon(Icons.save_rounded),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        // 紧凑的备份数据源选择和信息显示
        _buildCompactBackupDataSourceContent(),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: Colors.blue.shade600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '备份数据源设置决定了备份管理功能将备份哪个数据源的数据',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.blue.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 构建紧凑的备份数据源内容
  Widget _buildCompactBackupDataSourceContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 紧凑的备份数据源选择
          _buildCompactBackupDataSourceSelection(),
          const SizedBox(height: 16),
          // 紧凑的备份数据源信息显示
          _buildCompactBackupDataSourceInfo(),
        ],
      ),
    );
  }

  // 构建紧凑的备份数据源选择
  Widget _buildCompactBackupDataSourceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.radio_button_checked_rounded,
              size: 16,
              color: AppTheme.accentColor,
            ),
            const SizedBox(width: 8),
            Text(
              '选择备份数据源',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppTheme.accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildCompactBackupDataSourceOption(
                'sqlite',
                'SQLite 本地数据库',
                Icons.storage_rounded,
                Colors.blue,
                _backupDataSource == 'sqlite',
                _isBackupDataSourceEditing ? () {
                  setState(() {
                    _backupDataSource = 'sqlite';
                  });
                } : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildCompactBackupDataSourceOption(
                'mysql',
                'MySQL 远程数据库',
                Icons.cloud_done_rounded,
                Colors.green,
                _backupDataSource == 'mysql',
                _isBackupDataSourceEditing ? () {
                  setState(() {
                    _backupDataSource = 'mysql';
                  });
                } : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 构建紧凑的备份数据源选项
  Widget _buildCompactBackupDataSourceOption(
    String value,
    String title,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback? onTap,
  ) {
    final isEditable = onTap != null;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.2) : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey.shade600,
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isSelected ? color : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '已选择',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 构建紧凑的备份数据源信息显示
  Widget _buildCompactBackupDataSourceInfo() {
    if (_backupDataSource == 'sqlite') {
      return _buildCompactSQLiteBackupInfo();
    } else {
      return _buildCompactMySQLBackupInfo();
    }
  }

  // 构建紧凑的SQLite备份信息
  Widget _buildCompactSQLiteBackupInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.storage_rounded,
                color: Colors.blue.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'SQLite 备份信息',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactBackupInfoItem(
            '备份类型',
            '数据库文件复制',
            Icons.file_copy_rounded,
            Colors.blue,
          ),
          const SizedBox(height: 4),
          _buildCompactBackupInfoItem(
            '备份位置',
            _sqliteDbPath.isEmpty ? '默认数据库位置' : _sqliteDbPath,
            Icons.folder_rounded,
            Colors.green,
          ),
          const SizedBox(height: 4),
          _buildCompactBackupInfoItem(
            '备份格式',
            '.db 文件',
            Icons.description_rounded,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  // 构建紧凑的MySQL备份信息
  Widget _buildCompactMySQLBackupInfo() {
    final hasMySQLConfig = _hostController.text.isNotEmpty && 
                          _databaseController.text.isNotEmpty &&
                          _usernameController.text.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasMySQLConfig ? Colors.green.withOpacity(0.05) : Colors.orange.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasMySQLConfig ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasMySQLConfig ? Icons.check_circle_rounded : Icons.warning_rounded,
                color: hasMySQLConfig ? Colors.green.shade700 : Colors.orange.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'MySQL 备份信息',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: hasMySQLConfig ? Colors.green.shade700 : Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildCompactBackupInfoItem(
            '备份类型',
            'SQL导出备份',
            Icons.code_rounded,
            Colors.green,
          ),
          const SizedBox(height: 4),
          _buildCompactBackupInfoItem(
            '备份位置',
            hasMySQLConfig ? '${_hostController.text}:${_portController.text}/${_databaseController.text}' : 'MySQL配置不完整',
            Icons.cloud_rounded,
            hasMySQLConfig ? Colors.green : Colors.orange,
          ),
          const SizedBox(height: 4),
          _buildCompactBackupInfoItem(
            '备份格式',
            '.sql 文件',
            Icons.description_rounded,
            Colors.blue,
          ),
          if (!hasMySQLConfig) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange.shade700,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'MySQL配置不完整，无法执行备份操作',
                      style: TextStyle(
                        color: Colors.orange.shade700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 构建紧凑的备份信息项
  Widget _buildCompactBackupInfoItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(
            icon,
            color: color,
            size: 12,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }













  // 保存所有设置方法（保留原有方法以兼容）
  Future<void> _saveSettings() async {
    setState(() {
      _isSavingSettings = true;
    });

    try {
      // 验证表单
      if (_selectedDataSource == 'mysql' &&
          !_formKey.currentState!.validate()) {
        setState(() {
          _isSavingSettings = false;
        });
        return;
      }

      // 保存设置到SettingsProvider
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      // 保存全局数据源类型
      await settingsProvider.setDataSourceType(_selectedDataSource);

      // 保存SQLite数据库路径
      if (_selectedDataSource == 'sqlite') {
        await settingsProvider.setSqliteDbPath(_sqliteDbPath);
      }

      // 保存MySQL设置
      if (_selectedDataSource == 'mysql') {
        await settingsProvider.setMySQLHost(_hostController.text);
        await settingsProvider.setMySQLPort(_portController.text);
        await settingsProvider.setMySQLDatabase(_databaseController.text);
        await settingsProvider.setMySQLUsername(_usernameController.text);
        await settingsProvider.setMySQLPassword(_passwordController.text);
      }

      // 保存模块数据源配置
      await _saveModuleDataSourceSettings(settingsProvider);

      // 保存备份数据源设置
      await _saveBackupDataSourceSettings(settingsProvider);

      // 应用设置到数据库提供者
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 切换数据源
      if (_selectedDataSource == 'sqlite') {
        // 使用自定义SQLite路径
        await dbProvider.setDataSourceType(
          _selectedDataSource,
          customSqlitePath: _sqliteDbPath.isNotEmpty ? _sqliteDbPath : null,
        );
      } else if (_selectedDataSource == 'mysql') {
        // 使用MySQL设置
        Map<String, dynamic> mysqlSettings = {
          'host': _hostController.text,
          'port': int.tryParse(_portController.text) ?? 3306,
          'database': _databaseController.text,
          'username': _usernameController.text,
          'password': _passwordController.text,
        };

        await dbProvider.setDataSourceType(
          _selectedDataSource,
          mysqlSettings: mysqlSettings,
        );
      }

      if (!mounted) return;

      // 使用公用成功提示组件
      SuccessToastManager.show(
        context, 
        message: '所有设置已保存，将在应用重启后完全生效'
      );

      // 更新原始设置备份
      _originalModuleDataSources = Map<String, String>.from(_moduleDataSources);
      _originalDataSource = _selectedDataSource;
      _originalDataSourceMode = _dataSourceMode;
      _originalBackupDataSource = _backupDataSource;

      // 关闭编辑模式
      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存设置失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSavingSettings = false;
      });
    }
  }



  // 保存模块数据源设置
  Future<void> _saveModuleDataSourceSettings(SettingsProvider settingsProvider) async {
    try {
      // 保存数据源模式
      await settingsProvider.setDataSourceMode(_dataSourceMode);
      
      // 保存模块数据源配置
      await settingsProvider.setAllModuleDataSources(_moduleDataSources);
      print('模块数据源配置保存成功: $_moduleDataSources');
      
        // 通知所有相关的Provider更新模块数据源配置
  _updateAllProvidersModuleDataSources();
  
} catch (e) {
  print('保存模块数据源设置失败: $e');
  // 不抛出异常，避免影响主流程
}
}

  // 更新所有Provider的模块数据源配置
  void _updateAllProvidersModuleDataSources() {
    try {
      // 更新PurchaseProvider的模块数据源配置
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      purchaseProvider.updateModuleDataSources(_moduleDataSources);
      print('已更新PurchaseProvider的模块数据源配置');
      
      // 更新FinancialProvider的模块数据源配置
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      financialProvider.updateModuleDataSources(_moduleDataSources);
      print('已更新FinancialProvider的模块数据源配置');
      
      // 更新MaterialProvider的模块数据源配置
      final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
      materialProvider.updateModuleDataSources(_moduleDataSources);
      print('已更新MaterialProvider的模块数据源配置');
      
      // 可以在这里添加其他Provider的更新
      // 例如：PatientProvider, AppointmentProvider等
      
    } catch (e) {
      print('更新Provider模块数据源配置失败: $e');
    }
  }

  // 保存备份数据源设置
  Future<void> _saveBackupDataSourceSettings(SettingsProvider settingsProvider) async {
    try {
      // 保存备份数据源设置
      await settingsProvider.setBackupDataSource(_backupDataSource);
      print('备份数据源配置保存成功: $_backupDataSource');
      
    } catch (e) {
      print('保存备份数据源设置失败: $e');
      // 不抛出异常，避免影响主流程
    }
  }





  // 取消数据源类型切换更改
  void _cancelDataSourceTypeChanges() {
    setState(() {
      _isDataSourceTypeEditing = false;
      // 恢复到原始设置
      _dataSourceMode = _originalDataSourceMode;
      _selectedDataSource = _originalDataSource;
      _moduleDataSources = Map<String, String>.from(_originalModuleDataSources);
      
      // 如果恢复到模块化模式，需要重新从配置文件加载模块配置
      if (_dataSourceMode == 'modular') {
        // 重新加载模块配置，确保显示的是保存的配置
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _reloadModuleDataSources();
        });
      }
    });
  }

  // 保存数据源类型切换设置
  Future<void> _saveDataSourceTypeSettings() async {
    try {
      // 保存设置到SettingsProvider
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      // 保存数据源模式
      await settingsProvider.setDataSourceMode(_dataSourceMode);
      
      // 保存全局数据源类型
      await settingsProvider.setDataSourceType(_selectedDataSource);

      // 保存SQLite数据库路径
      if (_selectedDataSource == 'sqlite') {
        await settingsProvider.setSqliteDbPath(_sqliteDbPath);
      }

      // 保存MySQL设置
      if (_selectedDataSource == 'mysql') {
        await settingsProvider.setMySQLHost(_hostController.text);
        await settingsProvider.setMySQLPort(_portController.text);
        await settingsProvider.setMySQLDatabase(_databaseController.text);
        await settingsProvider.setMySQLUsername(_usernameController.text);
        await settingsProvider.setMySQLPassword(_passwordController.text);
      }

      // 保存模块数据源配置
      await _saveModuleDataSourceSettings(settingsProvider);

      // 应用设置到数据库提供者
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 切换数据源
      if (_selectedDataSource == 'sqlite') {
        // 使用自定义SQLite路径
        await dbProvider.setDataSourceType(
          _selectedDataSource,
          customSqlitePath: _sqliteDbPath.isNotEmpty ? _sqliteDbPath : null,
        );
      } else if (_selectedDataSource == 'mysql') {
        // 使用MySQL设置
        Map<String, dynamic> mysqlSettings = {
          'host': _hostController.text,
          'port': int.tryParse(_portController.text) ?? 3306,
          'database': _databaseController.text,
          'username': _usernameController.text,
          'password': _passwordController.text,
        };

        await dbProvider.setDataSourceType(
          _selectedDataSource,
          mysqlSettings: mysqlSettings,
        );
      }

      // 更新原始设置备份
      _originalModuleDataSources = Map<String, String>.from(_moduleDataSources);
      _originalDataSourceMode = _dataSourceMode;
      _originalDataSource = _selectedDataSource;

      setState(() {
        _isDataSourceTypeEditing = false;
      });

      if (!mounted) return;

      // 使用公用成功提示组件
      SuccessToastManager.show(
        context, 
        message: '数据源类型切换设置已保存'
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存设置失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 取消备份数据源设置更改
  void _cancelBackupDataSourceChanges() {
    setState(() {
      _isBackupDataSourceEditing = false;
      // 恢复到原始设置
      _backupDataSource = _originalBackupDataSource;
    });
  }

  // 仅保存备份数据源设置
  Future<void> _saveBackupDataSourceSettingsOnly() async {
    try {
      // 保存设置到SettingsProvider
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      // 保存全局数据源类型
      await settingsProvider.setDataSourceType(_selectedDataSource);

      // 保存SQLite数据库路径
      if (_selectedDataSource == 'sqlite') {
        await settingsProvider.setSqliteDbPath(_sqliteDbPath);
      }

      // 保存MySQL设置
      if (_selectedDataSource == 'mysql') {
        await settingsProvider.setMySQLHost(_hostController.text);
        await settingsProvider.setMySQLPort(_portController.text);
        await settingsProvider.setMySQLDatabase(_databaseController.text);
        await settingsProvider.setMySQLUsername(_usernameController.text);
        await settingsProvider.setMySQLPassword(_passwordController.text);
      }

      // 保存备份数据源设置
      await _saveBackupDataSourceSettings(settingsProvider);

      // 应用设置到数据库提供者
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 切换数据源
      if (_selectedDataSource == 'sqlite') {
        // 使用自定义SQLite路径
        await dbProvider.setDataSourceType(
          _selectedDataSource,
          customSqlitePath: _sqliteDbPath.isNotEmpty ? _sqliteDbPath : null,
        );
      } else if (_selectedDataSource == 'mysql') {
        // 使用MySQL设置
        Map<String, dynamic> mysqlSettings = {
          'host': _hostController.text,
          'port': int.tryParse(_portController.text) ?? 3306,
          'database': _databaseController.text,
          'username': _usernameController.text,
          'password': _passwordController.text,
        };

        await dbProvider.setDataSourceType(
          _selectedDataSource,
          mysqlSettings: mysqlSettings,
        );
      }

      // 更新原始设置备份
      _originalBackupDataSource = _backupDataSource;
      _originalDataSource = _selectedDataSource;

      setState(() {
        _isBackupDataSourceEditing = false;
      });

      if (!mounted) return;

      // 使用公用成功提示组件
      SuccessToastManager.show(
        context, 
        message: '备份数据源设置已保存'
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of( context).showSnackBar(
        SnackBar(
          content: Text('保存设置失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 保存MySQL设置
  Future<void> _saveMySQLSettings() async {
    setState(() {
      _isSavingSettings = true;
    });

    try {
      // 验证表单
      if (!_formKey.currentState!.validate()) {
        setState(() {
          _isSavingSettings = false;
        });
        return;
      }

      // 保存设置到SettingsProvider
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );

      // 保存MySQL设置
      await settingsProvider.setMySQLHost(_hostController.text);
      await settingsProvider.setMySQLPort(_portController.text);
      await settingsProvider.setMySQLDatabase(_databaseController.text);
      await settingsProvider.setMySQLUsername(_usernameController.text);
      await settingsProvider.setMySQLPassword(_passwordController.text);

      // 应用设置到数据库提供者
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 如果当前选择的是MySQL，则应用MySQL设置
      if (_selectedDataSource == 'mysql') {
        Map<String, dynamic> mysqlSettings = {
          'host': _hostController.text,
          'port': int.tryParse(_portController.text) ?? 3306,
          'database': _databaseController.text,
          'username': _usernameController.text,
          'password': _passwordController.text,
        };

        await dbProvider.setDataSourceType(
          _selectedDataSource,
          mysqlSettings: mysqlSettings,
        );
      }

      if (!mounted) return;

      // 使用公用成功提示组件
      SuccessToastManager.show(
        context, 
        message: 'MySQL配置已保存'
      );

      // 关闭编辑模式
      setState(() {
        _isEditing = false;
        _connectionTested = false;
        _connectionSuccess = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存MySQL设置失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSavingSettings = false;
      });
    }
  }

  // 重新加载模块配置
  void _reloadModuleDataSources() {
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    
    // 不要重新加载数据源模式，保持当前选择
    // _dataSourceMode 已经在调用此方法之前设置好了
    
    if (_dataSourceMode == 'global') {
      // 全局模式：所有模块使用相同的数据源
      _selectedDataSource = settingsProvider.dataSourceType ?? 'mysql';
      for (String key in _moduleDataSources.keys) {
        _moduleDataSources[key] = _selectedDataSource;
      }
      print('重新加载全局模式配置: 模式=$_dataSourceMode, 数据源=$_selectedDataSource');
    } else {
      // 模块化模式：加载每个模块的独立配置
      final moduleDataSources = settingsProvider.moduleDataSources;
      print('重新加载模块化配置: $moduleDataSources');
      
      if (moduleDataSources.isNotEmpty) {
        // 使用保存的模块配置
        setState(() {
          _moduleDataSources = Map<String, String>.from(moduleDataSources);
          print('重新加载后的模块配置: $_moduleDataSources');
        });
      } else {
        // 如果没有保存的配置，使用默认的sqlite配置
        final defaultConfig = {
          'patients': 'sqlite',      // 患者管理
          'appointments': 'sqlite',  // 预约管理
          'financial': 'sqlite',     // 财务管理
          'materials': 'sqlite',     // 材料管理
          'purchase': 'sqlite',      // 采购管理
          'users': 'sqlite',         // 用户管理
        };
        setState(() {
          _moduleDataSources = Map<String, String>.from(defaultConfig);
          print('使用默认模块配置: $_moduleDataSources');
        });
      }
    }
  }

  // 保存SQLite设置
  Future<void> _saveSqliteSettings() async {
    setState(() {
      _isSavingSettings = true;
    });

    try {
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      final databaseProvider = Provider.of<DatabaseProvider>(
        context,
        listen: false,
      );

      // 保存SQLite数据库路径
      await settingsProvider.setSqliteDbPath(_sqliteDbPath);

      // 保存原始设置
      _originalSqliteDbPath = _sqliteDbPath;

      // 如果当前选择的是SQLite，则应用设置
      if (_selectedDataSource == 'sqlite') {
        await databaseProvider.setDataSourceType(
          _selectedDataSource,
          customSqlitePath: _sqliteDbPath.isNotEmpty ? _sqliteDbPath : null,
        );
      }

      if (!mounted) return;

      // 使用公用成功提示组件
      SuccessToastManager.show(
        context, 
        message: 'SQLite配置已保存'
      );

      // 关闭编辑模式
      setState(() {
        _isSqliteEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存SQLite设置失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isSavingSettings = false;
      });
    }
  }
}
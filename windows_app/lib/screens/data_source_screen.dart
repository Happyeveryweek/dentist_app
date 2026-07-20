import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:path/path.dart' as path;

import '../providers/settings_provider.dart';
import '../providers/database_provider.dart';
import '../config/app_defaults.dart';
import '../widgets/success_toast.dart';
import '../features/settings/widgets/data_source_page_header.dart';
import '../features/settings/widgets/data_source_configuration_section.dart';
import '../features/settings/widgets/data_source_type_switch_section.dart';
import '../features/settings/widgets/backup_data_source_section.dart';
import '../features/settings/services/data_source_config_service.dart';
import '../features/settings/services/data_source_connection_service.dart';
import '../features/settings/services/data_source_provider_sync_service.dart';
import '../features/settings/helpers/data_source_state_helper.dart';

const List<String> _dataSourceModuleKeys = [
  'patients',
  'appointments',
  'financial',
  'materials',
  'purchase',
  'users',
  'medical',
];

class DataSourceScreen extends StatefulWidget {
  const DataSourceScreen({Key? key}) : super(key: key);

  @override
  State<DataSourceScreen> createState() => _DataSourceScreenState();
}

class _DataSourceScreenState extends State<DataSourceScreen> {
  late DataSourceConfigService _configService;
  late DataSourceConnectionService _connectionService;
  late DataSourceProviderSyncService _providerSyncService;

  // 数据源类型
  String _selectedDataSource = 'sqlite'; // sqlite 或 mysql

  // 数据源切换模式：'global' 或 'modular'
  String _dataSourceMode = 'global';

  // SQLite 文件路径
  String _sqliteDbPath = '';

  // MySQL连接参数
  final _hostController = TextEditingController();
  final _portController = TextEditingController(
    text: '${MySqlConnectionPolicy.defaultPort}',
  );
  final _databaseController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  // 模块数据源配置
  Map<String, String> _moduleDataSources = _buildDefaultModuleDataSources();

  // 备份数据源设置
  String _backupDataSource = 'sqlite';

  // 原始设置备份（用于取消时恢复）
  late DataSourceStateBackup _originalBackup;

  // 各个部分的编辑状态
  bool _isDataSourceTypeEditing = false;
  bool _isBackupDataSourceEditing = false;
  bool _isSqliteEditing = false;

  final _formKey = GlobalKey<FormState>();
  bool _isTestingConnection = false;
  bool _connectionTested = false;
  bool _connectionSuccess = false;
  bool _isEditing = false;

  static Map<String, String> _buildDefaultModuleDataSources(
      [String dataSource = 'sqlite']) {
    return {
      for (final module in _dataSourceModuleKeys) module: dataSource,
    };
  }

  void _applyGlobalDataSourceToModules() {
    for (final key in _moduleDataSources.keys) {
      _moduleDataSources[key] = _selectedDataSource;
    }
  }

  void _restoreMySQLControllers(SettingsProvider settingsProvider) {
    _hostController.text = settingsProvider.mysqlHost;
    _portController.text = settingsProvider.mysqlPort;
    _databaseController.text = settingsProvider.mysqlDatabase;
    _usernameController.text = settingsProvider.mysqlUsername;
    _passwordController.text = settingsProvider.mysqlPassword;
  }

  void _snapshotOriginalBackup() {
    _originalBackup = DataSourceStateHelper.createBackup(
      moduleDataSources: _moduleDataSources,
      dataSource: _selectedDataSource,
      dataSourceMode: _dataSourceMode,
      backupDataSource: _backupDataSource,
      sqliteDbPath: _sqliteDbPath,
    );
  }

  void _syncProvidersModuleDataSources() {
    _providerSyncService
        .updateAllProvidersModuleDataSources(_moduleDataSources);
  }

  void _loadSettingsFromProvider(SettingsProvider settingsProvider) {
    _dataSourceMode = settingsProvider.dataSourceMode;
    _selectedDataSource = _dataSourceMode == 'global'
        ? settingsProvider.dataSourceType
        : (settingsProvider.dataSourceType == 'mysql' ? 'mysql' : 'sqlite');

    if (_dataSourceMode == 'global') {
      _applyGlobalDataSourceToModules();
    } else {
      final moduleDataSources = settingsProvider.moduleDataSources;
      _moduleDataSources = moduleDataSources.isNotEmpty
          ? Map<String, String>.from(moduleDataSources)
          : _buildDefaultModuleDataSources();
    }

    _sqliteDbPath = settingsProvider.sqliteDbPath;
    _backupDataSource = settingsProvider.backupDataSource;
    _restoreMySQLControllers(settingsProvider);
    _snapshotOriginalBackup();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settingsProvider =
          Provider.of<SettingsProvider>(context, listen: false);
      final databaseProvider =
          Provider.of<DatabaseProvider>(context, listen: false);

      setState(() {
        _configService = DataSourceConfigService(
          settingsProvider: settingsProvider,
          databaseProvider: databaseProvider,
        );
        _connectionService = DataSourceConnectionService(
          databaseProvider: databaseProvider,
        );
        _providerSyncService = DataSourceProviderSyncService(context: context);
        _loadSettingsFromProvider(settingsProvider);
      });

      // 如果已经配置过MySQL，就默认为已测试通过
      if (_selectedDataSource == 'mysql' &&
          _hostController.text.isNotEmpty &&
          _databaseController.text.isNotEmpty) {
        _connectionTested = true;
        _connectionSuccess = true;
      }

      _syncProvidersModuleDataSources();
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
      backgroundColor: context.tokens.pageBackground,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.storage_rounded,
                color: context.tokens.cardBackground,
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
        backgroundColor: context.tokens.cardBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            // 页面标题卡片
            DataSourcePageHeader(
              dataSourceMode: _dataSourceMode,
              selectedDataSource: _selectedDataSource,
              moduleDataSources: _moduleDataSources,
              getModuleDisplayName: _getModuleDisplayName,
            ),
            const SizedBox(height: 24),

            // 第一区域：数据源配置
            DataSourceConfigurationSection(
              sqliteDbPath: _sqliteDbPath,
              hostController: _hostController,
              portController: _portController,
              databaseController: _databaseController,
              usernameController: _usernameController,
              passwordController: _passwordController,
              isSqliteEditing: _isSqliteEditing,
              isEditing: _isEditing,
              connectionTested: _connectionTested,
              connectionSuccess: _connectionSuccess,
              isTestingConnection: _isTestingConnection,
              onSelectSqliteDatabase: _selectSqliteDatabase,
              onTestMySQLConnection: _testMySQLConnection,
              onSaveSqliteSettings: _saveSqliteSettings,
              onSaveMySQLSettings: _saveMySQLSettings,
              onSetSqliteEditing: () {
                setState(() {
                  _isSqliteEditing = true;
                  _snapshotOriginalBackup();
                });
              },
              onSetEditing: () {
                setState(() {
                  _isEditing = true;
                  _connectionTested = false;
                  _connectionSuccess = false;
                });
              },
              onCancelSqliteEdit: () {
                setState(() {
                  _isSqliteEditing = false;
                  final restore =
                      DataSourceStateHelper.restoreFromBackup(_originalBackup);
                  _sqliteDbPath = restore.sqliteDbPath;
                });
              },
              onCancelMySQLEdit: () {
                setState(() {
                  _isEditing = false;
                  _restoreMySQLControllers(
                    Provider.of<SettingsProvider>(context, listen: false),
                  );
                });
              },
              formKey: _formKey,
            ),
            const SizedBox(height: 24),

            // 第二区域：数据源类型切换
            DataSourceTypeSwitchSection(
              dataSourceMode: _dataSourceMode,
              selectedDataSource: _selectedDataSource,
              moduleDataSources: _moduleDataSources,
              isDataSourceTypeEditing: _isDataSourceTypeEditing,
              onSetDataSourceTypeEditing: () {
                setState(() {
                  _isDataSourceTypeEditing = true;
                });
              },
              onCancelDataSourceTypeChanges: _cancelDataSourceTypeChanges,
              onSaveDataSourceTypeSettings: _saveDataSourceTypeSettings,
              onSetDataSourceMode: (mode) {
                setState(() {
                  _dataSourceMode = mode;
                  if (mode == 'global') {
                    _applyGlobalDataSourceToModules();
                  }
                });
              },
              onSetSelectedDataSource: (dataSource) {
                setState(() {
                  _selectedDataSource = dataSource;
                  if (_dataSourceMode == 'global') {
                    _applyGlobalDataSourceToModules();
                  }
                });
              },
              onSetModuleDataSource: (moduleKey, dataSource) {
                setState(() {
                  _moduleDataSources[moduleKey] = dataSource;
                });
              },
              onReloadModuleDataSources: _reloadModuleDataSources,
              getModuleDisplayName: _getModuleDisplayName,
            ),
            const SizedBox(height: 24),

            // 第三区域：备份数据源设置
            BackupDataSourceSection(
              backupDataSource: _backupDataSource,
              isBackupDataSourceEditing: _isBackupDataSourceEditing,
              sqliteDbPath: _sqliteDbPath,
              hostController: _hostController,
              portController: _portController,
              databaseController: _databaseController,
              onCancelBackupDataSourceChanges: _cancelBackupDataSourceChanges,
              onSaveBackupDataSourceSettingsOnly:
                  _saveBackupDataSourceSettingsOnly,
              onSetBackupDataSourceEditing: () {
                setState(() {
                  _isBackupDataSourceEditing = true;
                });
              },
              onSetBackupDataSource: (dataSource) {
                setState(() {
                  _backupDataSource = dataSource;
                });
              },
            ),
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
      case 'medical':
        return '病历管理';
      default:
        return moduleKey;
    }
  }

  // 选择SQLite数据库文件
  Future<void> _selectSqliteDatabase() async {
    try {
      final filePath = await _connectionService.selectSqliteDatabase();

      if (filePath == null) {
        return;
      }

      setState(() {
        _sqliteDbPath = filePath;
      });

      if (!mounted) return;
      // 使用公用成功提示组件
      AppToastManager.showSuccess(context,
          message: '已选择数据库文件: ${path.basename(filePath)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('选择文件时出错: $e'),
        backgroundColor: context.tokens.error,
      ));
    }
  }

  // 测试MySQL连接
  Future<void> _testMySQLConnection() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() {
      _isTestingConnection = true;
      _connectionTested = true;
      _connectionSuccess = false;
    });

    try {
      // 使用连接服务测试连接
      bool success = await _connectionService.testMySQLConnection(
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
            backgroundColor: context.tokens.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('连接失败，请检查连接参数'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('连接错误: $e'),
          backgroundColor: context.tokens.error,
        ),
      );
    } finally {
      setState(() {
        _isTestingConnection = false;
      });
    }
  }

  // 构建紧凑的备份数据源内容

  // 取消数据源类型切换更改
  void _cancelDataSourceTypeChanges() {
    setState(() {
      _isDataSourceTypeEditing = false;
      // 恢复到原始设置
      final restore = DataSourceStateHelper.restoreFromBackup(_originalBackup);
      _dataSourceMode = restore.dataSourceMode;
      _selectedDataSource = restore.dataSource;
      _moduleDataSources = restore.moduleDataSources;

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
      // 使用配置服务保存完整配置
      await _configService.saveDataSourceTypeConfig(
        dataSourceMode: _dataSourceMode,
        selectedDataSource: _selectedDataSource,
        sqliteDbPath: _sqliteDbPath,
        host: _hostController.text,
        port: _portController.text,
        database: _databaseController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        moduleDataSources: _moduleDataSources,
      );

      // 更新所有Provider的模块数据源配置
      _syncProvidersModuleDataSources();

      // 更新原始设置备份
      _snapshotOriginalBackup();

      setState(() {
        _isDataSourceTypeEditing = false;
      });

      if (!mounted) return;

      // 使用公用成功提示组件
      AppToastManager.showSuccess(context, message: '数据源类型切换设置已保存');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存设置失败: $e'),
          backgroundColor: context.tokens.error,
        ),
      );
    }
  }

  // 取消备份数据源设置更改
  void _cancelBackupDataSourceChanges() {
    setState(() {
      _isBackupDataSourceEditing = false;
      // 恢复到原始设置
      final restore = DataSourceStateHelper.restoreFromBackup(_originalBackup);
      _backupDataSource = restore.backupDataSource;
    });
  }

  // 仅保存备份数据源设置
  Future<void> _saveBackupDataSourceSettingsOnly() async {
    try {
      // 使用配置服务保存完整配置
      await _configService.saveBackupDataSourceConfig(
        selectedDataSource: _selectedDataSource,
        sqliteDbPath: _sqliteDbPath,
        host: _hostController.text,
        port: _portController.text,
        database: _databaseController.text,
        username: _usernameController.text,
        password: _passwordController.text,
        backupDataSource: _backupDataSource,
      );

      // 更新原始设置备份
      _snapshotOriginalBackup();

      setState(() {
        _isBackupDataSourceEditing = false;
      });

      if (!mounted) return;

      // 使用公用成功提示组件
      AppToastManager.showSuccess(context, message: '备份数据源设置已保存');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存设置失败: $e'),
          backgroundColor: context.tokens.error,
        ),
      );
    }
  }

  // 保存MySQL设置
  Future<void> _saveMySQLSettings() async {
    try {
      // 验证表单
      if (_formKey.currentState?.validate() != true) {
        return;
      }

      // 使用配置服务保存并应用MySQL配置
      await _configService.saveAndApplyMySQLConfig(
        dataSourceType: _selectedDataSource,
        host: _hostController.text,
        port: _portController.text,
        database: _databaseController.text,
        username: _usernameController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;

      // 使用公用成功提示组件
      AppToastManager.showSuccess(context, message: 'MySQL配置已保存');

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
          backgroundColor: context.tokens.error,
        ),
      );
    }
  }

  // 重新加载模块配置
  void _reloadModuleDataSources() {
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    // 不要重新加载数据源模式，保持当前选择
    // _dataSourceMode 已经在调用此方法之前设置好了

    if (_dataSourceMode == 'global') {
      // 全局模式：所有模块使用相同的数据源
      _selectedDataSource = settingsProvider.dataSourceType;
      _applyGlobalDataSourceToModules();
    } else {
      // 模块化模式：加载每个模块的独立配置
      final moduleDataSources = settingsProvider.moduleDataSources;

      if (moduleDataSources.isNotEmpty) {
        // 使用保存的模块配置
        setState(() {
          _moduleDataSources = Map<String, String>.from(moduleDataSources);
        });
      } else {
        // 如果没有保存的配置，使用默认的sqlite配置
        setState(() {
          _moduleDataSources = _buildDefaultModuleDataSources();
        });
      }
    }
  }

  // 保存SQLite设置
  Future<void> _saveSqliteSettings() async {
    try {
      // 使用配置服务保存并应用SQLite配置
      await _configService.saveAndApplySqliteConfig(
        dataSourceType: _selectedDataSource,
        sqliteDbPath: _sqliteDbPath,
      );

      // 更新原始设置备份
      _snapshotOriginalBackup();

      if (!mounted) return;

      // 使用公用成功提示组件
      AppToastManager.showSuccess(context, message: 'SQLite配置已保存');

      // 关闭编辑模式
      setState(() {
        _isSqliteEditing = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存SQLite设置失败: $e'),
          backgroundColor: context.tokens.error,
        ),
      );
    }
  }
}

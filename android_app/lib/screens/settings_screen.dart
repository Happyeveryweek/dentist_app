import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/app_state.dart';
import 'package:dentist_app/providers/settings_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/utils/database_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:mysql1/mysql1.dart';
import 'package:dentist_app/utils/config_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/datetime_formatter.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import '../utils/snackbar_util.dart';
import 'sync_logs_screen.dart';
import '../models/sync_config.dart';
import '../utils/schema_validator.dart';
import '../models/database_models.dart';
import '../utils/toast_util.dart';
import '../features/settings/widgets/database_source_section.dart';
import '../features/settings/widgets/backup_restore_section.dart';
import '../features/settings/widgets/sync_config_section.dart';
import '../features/settings/widgets/system_settings_section.dart';
import '../features/settings/widgets/settings_dialogs.dart';
import '../features/settings/widgets/settings_header.dart';
import '../features/settings/widgets/sqlite_config_dialogs.dart';
import '../features/settings/services/permission_service.dart';
import '../features/settings/services/mysql_config_service.dart';
import '../features/settings/services/database_switch_service.dart';
import '../features/settings/services/backup_restore_service.dart';
import '../features/settings/services/excel_export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  String _selectedDbType = 'sqlite';
  String _dbPath = '';
  bool _isLoading = false;
  bool _mysqlTestSuccess = false;
  String _loadingText = '';
  bool _isEditingMysql = false;

  // 数据库提供者
  DatabaseProvider? dbProvider;

  // 移除测试数据库路径变量

  // MySQL配置控制器
  final TextEditingController _hostController = TextEditingController(
    text: 'localhost',
  );
  final TextEditingController _portController = TextEditingController(
    text: '3306',
  );
  final TextEditingController _databaseController = TextEditingController(
    text: 'dental_clinic',
  );
  final TextEditingController _usernameController = TextEditingController(
    text: 'root',
  );
  final TextEditingController _passwordController = TextEditingController();

  // 数据库配置对象
  late DatabaseConfig _dbConfig;
  bool _showMysqlConfig = false;

  // Tab控制器
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // 初始化_dbConfig以防止late错误
    _dbConfig = DatabaseConfig(
      dbType: 'sqlite',
      sqlite: SqliteConfig(path: ''),
      mysql: MySqlConfig(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 获取数据库提供者
      dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      if (dbProvider != null) {
        _loadSettings();
      }
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _loadingText = '加载配置...';
    });

    try {
      // 使用数据库切换服务加载配置
      _dbConfig = await DatabaseSwitchService.initDatabaseConfig();

      print(
        '已加载数据库配置: 类型=${_dbConfig.dbType}, SQLite路径=${_dbConfig.sqlite.path}',
      );

      // 检查组件是否仍然挂载
      if (!mounted) return;

      // 更新UI状态
      setState(() {
        _selectedDbType = _dbConfig.dbType;
        _dbPath = _dbConfig.dbType == 'sqlite' 
            ? _dbConfig.sqlite.path 
            : '${_dbConfig.mysql.host}:${_dbConfig.mysql.port}/${_dbConfig.mysql.database}';
        _showMysqlConfig = _selectedDbType == 'mysql';
        _isEditingMysql = false; // 加载时重置编辑模式

        // 设置MySQL控制器值
        _hostController.text = _dbConfig.mysql.host;
        _portController.text = _dbConfig.mysql.port;
        _databaseController.text = _dbConfig.mysql.database;
        _usernameController.text = _dbConfig.mysql.username;
        _passwordController.text = _dbConfig.mysql.password;
      });

      // 检查组件是否仍然挂载
      if (!mounted) return;

      // 从数据库提供者获取当前路径
      if (dbProvider == null) return;
      final providerDbType = dbProvider!.dbType;
      final providerDbPath = dbProvider!.dbPath;
      print('从Provider获取数据库信息: 类型=$providerDbType, 路径=$providerDbPath');

      setState(() {
        _selectedDbType = providerDbType;
        // 优先使用Provider的实际路径
        if (providerDbPath.isNotEmpty) {
          _dbPath = providerDbPath;
          print('已更新显示路径: $_dbPath (来自Provider)');
        } else {
          print('Provider路径为空，保持当前路径: $_dbPath');
        }
        _isLoading = false;
      });
    } catch (e) {
      print('加载设置错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // 确保至少有一个默认值
          if (_dbPath.isEmpty) {
            _dbPath = "未设置数据库路径";
          }
        });
      }
    }
  }

  // 检查是否使用的是缓存路径
  bool _isUsingCachePath(String dbPath) {
    return dbPath.contains('/cache/') || dbPath.endsWith('.bin');
  }

  Future<void> _switchDatabaseType(String dbType) async {
    // 如果选择的类型与当前类型相同，无需操作
    if (dbType == _selectedDbType) return;

    // 显示确认对话框
    final bool? confirmed = await SettingsDialogs.showDatabaseSwitchConfirmDialog(context, dbType);

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (dbType == 'sqlite') {
        // SQLite切换，确认后立即生效
        if (dbProvider == null) return;
        // 使用数据库切换服务更新配置
        _dbConfig = await DatabaseSwitchService.switchDatabaseType('sqlite', _dbConfig);

        // 更新UI状态
        setState(() {
          _selectedDbType = 'sqlite';
          _dbPath = _dbConfig.sqlite.path;
          _showMysqlConfig = false;
          _isEditingMysql = false; // 重置编辑模式
        });

        // 显示成功提示
        if (mounted) {
          await SqliteConfigDialogs.showSqliteActivatedDialog(context);
        }
      } else if (dbType == 'mysql') {
        // 对于MySQL，只显示配置界面，不立即切换
        setState(() {
          _showMysqlConfig = true;
          _selectedDbType = 'mysql'; // 更新UI选中状态
          _isEditingMysql = true; // 进入编辑模式，提示用户需要配置
          _mysqlTestSuccess = false; // 重置连接测试状态
        });

        // 从已保存的配置中加载MySQL设置
        _hostController.text = _dbConfig.mysql.host;
        _portController.text = _dbConfig.mysql.port;
        _databaseController.text = _dbConfig.mysql.database;
        _usernameController.text = _dbConfig.mysql.username;
        _passwordController.text = _dbConfig.mysql.password;

        // 显示提示信息
        _showSnackBar('请配置MySQL连接信息并保存后生效', isSuccess: true, duration: 4);
      }
    } catch (e) {
      _showSnackBar('切换数据库类型失败: $e', isSuccess: false);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectCustomDbPath() async {
    try {
      // 首先请求存储权限
      bool permissionGranted = await _requestStoragePermission();
      if (!permissionGranted) {
        if (mounted) {
          _showSnackBar('需要存储权限才能选择数据库文件', isSuccess: false);
        }
        return;
      }

      // 使用服务选择自定义数据库路径
      final filePath = await DatabaseSwitchService.selectCustomDbPath();

      if (filePath != null) {
        // 检查文件是否存在
        final fileObj = File(filePath);
        if (!(await fileObj.exists())) {
          if (!mounted) return;
          _showSnackBar('所选文件不存在', isSuccess: false);
          return;
        }

        // 更新配置
        _dbConfig = await DatabaseSwitchService.switchDatabaseType('sqlite', _dbConfig, path: filePath);

        // 切换数据库
        if (dbProvider == null) return;

        setState(() {
          _dbPath = filePath;
        });

        // 显示成功提示
        if (!mounted) return;
        final fileName = path.basename(filePath);
        await SqliteConfigDialogs.showSqliteConfigSavedDialog(context, fileName, filePath);
      }
    } catch (e) {
      print('选择自定义数据库路径错误: $e');

      // 显示错误提示
      if (!mounted) return;
      _showSnackBar('设置自定义数据库路径失败', isSuccess: false);
    }
  }

  // 先选择目录，再选择数据库文件
  Future<void> _selectCustomDbPathAlternative() async {
    try {
      // 首先请求存储权限
      bool permissionGranted = await _requestStoragePermission();
      if (!permissionGranted) {
        if (mounted) {
          _showSnackBar('需要存储权限才能选择数据库文件', isSuccess: false);
        }
        return;
      }

      // Step 1: 先选择目录
      setState(() {
        _isLoading = true;
        _loadingText = '请选择数据库文件所在目录...';
      });

      // 使用服务选择自定义数据库路径
      final filePath = await DatabaseSwitchService.selectCustomDbPathAlternative();

      if (filePath == null) {
        // 用户取消了选择
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      print('选择的文件: $filePath');
      final fileName = path.basename(filePath);

      // 显示确认对话框
      final bool? confirmed = await SettingsDialogs.showConfirmDatabaseDialog(context, fileName, filePath);

      if (confirmed != true) {
        return;
      }

      // 更新配置但不立即切换数据库，避免大型数据库加载导致的卡顿
      setState(() {
        _isLoading = true;
        _loadingText = '正在保存配置...';
      });

      try {
        // 只更新配置，不立即切换数据库
        _dbConfig.dbType = 'sqlite';
        _dbConfig.sqlite.path = filePath;
        await _dbConfig.saveConfig();
        print('配置已保存: $filePath');

        // 更新状态
        if (mounted) {
          setState(() {
            _selectedDbType = 'sqlite';
            _dbPath = filePath; // 立即更新本地路径变量
            _isLoading = false;
            _showMysqlConfig = false; // 隐藏MySQL配置区域
          });

          // 显示成功提示并询问是否立即加载数据库
          if (mounted) {
            final shouldLoadNow = await SqliteConfigDialogs.showSqliteConfigSavedDialogWithLoadOption(context, fileName, filePath);

            if (shouldLoadNow == true) {
              // 用户选择立即加载数据库
              setState(() {
                _isLoading = true;
                _loadingText = '正在加载数据库...';
              });

              try {
                // 切换数据库
                if (dbProvider == null) return;
                _dbConfig = await DatabaseSwitchService.switchDatabaseType('sqlite', _dbConfig, path: filePath);
                print('数据库已切换');

                // 更新状态和通知监听器
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });

                  // 强制数据库提供者通知所有监听器数据源已更改
                  dbProvider!.forceDataChanged(navigateToDashboard: true);
                  _showSnackBar('数据库已切换: $fileName', isSuccess: true);
                }
              } catch (e) {
                print('切换数据库失败: $e');
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  _showSnackBar('切换数据库失败: $e', isSuccess: false);
                }
              }
            } else {
              // 用户选择稍后加载，仅显示提示
              _showSnackBar('数据库配置已更新，重启应用后生效', isSuccess: true);
            }
          }
        }
      } catch (e) {
        print('保存数据库配置失败: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('保存配置失败: $e', isSuccess: false);
        }
      }
    } catch (e) {
      print('选择数据库路径错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showSnackBar('选择数据库路径失败: $e', isSuccess: false);
      }
    }
  }

  // 请求存储权限方法
  Future<bool> _requestStoragePermission() async {
    final bool granted = await PermissionService.requestStoragePermission();
    if (!granted && mounted) {
      PermissionService.showPermissionSettingsDialog(
        context,
        () => openAppSettings(),
      );
    }
    return granted;
  }

  // 移除加载测试数据库方法

  Future<void> _testMySqlConnection() async {
    try {
      setState(() {
        _isLoading = true;
        _mysqlTestSuccess = false;
      });

      final host = _hostController.text.trim();
      final port = int.tryParse(_portController.text.trim()) ?? 3306;
      final database = _databaseController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // 检查所有必填字段
      if (host.isEmpty || database.isEmpty || username.isEmpty) {
        _showSnackBar('请填写所有必填字段', isSuccess: false);
        return;
      }

      // 先检查网络连通性
      final networkOk = await _testNetworkConnection(host, port.toString());
      if (!networkOk) {
        // 网络测试已显示错误消息
        return;
      }

      // 使用服务测试MySQL连接
      final success = await MysqlConfigService.testMySqlConnection(
        host: host,
        port: port.toString(),
        database: database,
        username: username,
        password: password,
      );

      if (!mounted) return;

      if (success) {
        _showSnackBar('MySQL连接测试成功', isSuccess: true);
        setState(() {
          _mysqlTestSuccess = true;
          _isLoading = false;
        });
      } else {
        _showSnackBar('MySQL连接测试失败', isSuccess: false);
        setState(() {
          _mysqlTestSuccess = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('MySQL连接测试失败: $e');

      if (!mounted) return;

      String errorMessage = e.toString();

      if (errorMessage.contains('Connection refused')) {
        _showSnackBar(
          '连接被拒绝，请检查MySQL服务是否运行且端口正确',
          isSuccess: false,
          duration: 4,
        );
      } else if (errorMessage.contains('Access denied')) {
        _showSnackBar('访问被拒绝，请检查用户名和密码', isSuccess: false, duration: 4);
      } else if (errorMessage.contains('Unknown database')) {
        _showSnackBar('数据库不存在，请检查数据库名称', isSuccess: false, duration: 4);
      } else {
        _showSnackBar(
          'MySQL连接测试失败: ${e.toString().split(':').last.trim()}',
          isSuccess: false,
          duration: 4,
        );
      }

      setState(() {
        _mysqlTestSuccess = false;
        _isLoading = false;
      });
    }
  }

  // 显示提示消息
  void _showSnackBar(
    String message, {
    bool isSuccess = true,
    int duration = 3,
  }) {
    if (!mounted) return;
    SnackBarUtil.show(context, message, isSuccess: isSuccess, duration: duration);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: Column(
        children: [
          _buildSettingsHeader(),
          Expanded(
            child: _isLoading
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        '加载设置...',
                        style: TextStyle(color: AppTheme.secondaryText),
                      ),
                    ],
                  ),
                )
                : TabBarView(
                  controller: _tabController,
                  children: [
                    DatabaseSourceSection(
                      selectedDbType: _selectedDbType,
                      showMysqlConfig: _showMysqlConfig,
                      isEditingMysql: _isEditingMysql,
                      mysqlTestSuccess: _mysqlTestSuccess,
                      dbConfig: _dbConfig,
                      hostController: _hostController,
                      portController: _portController,
                      databaseController: _databaseController,
                      usernameController: _usernameController,
                      passwordController: _passwordController,
                      onSwitchToSqlite: () => _switchDatabaseType('sqlite'),
                      onSwitchToMysql: () => _switchDatabaseType('mysql'),
                      onToggleMysqlEdit: () {
                        setState(() {
                          _isEditingMysql = !_isEditingMysql;
                        });
                      },
                      onTestNetwork: () => _testNetworkConnection(_hostController.text, _portController.text),
                      onTestConnection: _testMySqlConnection,
                      onSaveMysql: _mysqlTestSuccess ? _saveMySQLConfig : null,
                      onSelectCustomDbPath: _selectCustomDbPath,
                    ),
                    BackupRestoreSection(
                      isLoading: _isLoading,
                      loadingText: _loadingText,
                      onBackup: _showBackupDialog,
                      onRestore: _restoreDatabaseFromBackup,
                      onExportExcel: _showExcelExportDialog,
                    ),
                    const SyncConfigSection(),
                    SystemSettingsSection(
                      onLogout: _showLogoutDialog,
                    ),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsHeader() {
    return SettingsHeader(
      tabController: _tabController,
      onLogout: _showLogoutDialog,
      onHelp: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('关于设置'),
            content: const SingleChildScrollView(
              child: Text(
                '在此页面，您可以配置系统的数据源和其他系统设置。\n\n'
                '数据源：您可以选择使用SQLite本地数据库或MySQL远程数据库。\n\n'
                '备份与恢复：提供数据备份和恢复功能，保护您的重要数据。\n\n'
                '系统设置：配置其它系统参数和用户偏好设置。',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('了解'),
              ),
            ],
          ),
        );
      },
    );
  }

  // 获取用于显示的数据库路径
  String _getDisplayDbPath() {
    // 首先检查当前选择的数据库类型
    if (_selectedDbType == 'mysql') {
      // 如果是MySQL，显示连接信息而不是文件路径
      return '${_dbConfig.mysql.host}:${_dbConfig.mysql.port}/${_dbConfig.mysql.database}';
    }

    // 对于SQLite，优先从数据库提供者获取当前实际使用的路径
    try {
      if (dbProvider != null && 
          dbProvider!.isInitialized && 
          dbProvider!.dbType == 'sqlite' && 
          dbProvider!.dbPath.isNotEmpty) {
        print('从Provider获取SQLite显示路径: ${dbProvider!.dbPath}');
        return dbProvider!.dbPath;
      }
    } catch (e) {
      print('从数据库提供者获取路径错误: $e');
    }

    // 其次使用_dbPath实例变量（这是用户最新选择的路径）
    if (_selectedDbType == 'sqlite' && _dbPath.isNotEmpty && !_dbPath.contains(':')) {
      print('使用本地SQLite路径变量: $_dbPath');
      return _dbPath;
    }

    // 最后检查配置文件中的SQLite路径
    try {
      if (_selectedDbType == 'sqlite' && _dbConfig.sqlite.path.isNotEmpty) {
        print('从配置获取SQLite显示路径: ${_dbConfig.sqlite.path}');
        return _dbConfig.sqlite.path;
      }
    } catch (e) {
      print('从配置获取显示数据库路径错误: $e');
    }

    return "未设置数据库路径";
  }



  // 新增：显示备份对话框方法
  void _showBackupDialog() async {
    await SettingsDialogs.showBackupDialog(
      context,
      dbConfig: _dbConfig,
      dbPath: _dbPath,
      dbType: _selectedDbType,
      setState: (callback) {
        callback();
      },
      showSnackBar: (message, {bool isSuccess = true}) {
        setState(() {
          _isLoading = false;
          _loadingText = '';
        });
        _showSnackBar(message, isSuccess: isSuccess);
      },
      mounted: () => this.mounted,
    );
  }

  // 文件选择目录方法
  Future<String?> _selectOutputDirectory() async {
    try {
      // 先确保有存储权限
      final bool permissionGranted = await _requestStoragePermission();
      if (!permissionGranted) {
        if (mounted) {
          _showSnackBar('需要存储权限才能选择文件夹', isSuccess: false);
        }
        return null;
      }

      // 使用服务选择输出目录
      final directoryPath = await BackupRestoreService.selectOutputDirectory();
      return directoryPath;
    } catch (e) {
      print('选择目录错误: $e');
      return null;
    }
  }


  // 测试网络连接
  Future<bool> _testNetworkConnection(String host, String port) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final success = await MysqlConfigService.testNetworkConnection(host, port);

      if (!mounted) return false;

      setState(() {
        _isLoading = false;
      });

      final effectiveHost = MysqlConfigService.getEffectiveHost(host);
      final isConverted = MysqlConfigService.isHostConverted(host, effectiveHost);

      if (success) {
        if (isConverted) {
          _showSnackBar(
            '网络连接正常，已将 $host 转换为 $effectiveHost 连接成功',
            isSuccess: true,
          );
        } else {
          _showSnackBar('网络连接正常，可以连接到 $host:$port', isSuccess: true);
        }

        // 如果使用了转换，更新输入框内容
        if (isConverted) {
          _hostController.text = effectiveHost;
        }

        return true;
      } else {
        if (isConverted) {
          _showSnackBar(
            '无法连接到 $effectiveHost:$port (转换自 $host)，请检查网络或主机是否可达',
            isSuccess: false,
          );
        } else {
          _showSnackBar('无法连接到 $host:$port，请检查网络或主机是否可达', isSuccess: false);
        }

        return false;
      }
    } catch (e) {
      print('网络测试错误: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return false;
    }
  }

  // 保存MySQL配置
  Future<void> _saveMySQLConfig() async {
    if (!_mysqlTestSuccess) {
      _showSnackBar('请先测试连接并确保连接成功', isSuccess: false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 获取输入值
      final host = _hostController.text.trim(); // 这可能已经在测试连接时被转换为10.0.2.2
      final port = _portController.text.trim();
      final database = _databaseController.text.trim();
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      // 获取应用状态管理器
      final appState = Provider.of<AppState>(context, listen: false);

      // 检查Android平台上的localhost
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        print('Android平台检测到localhost，自动转换为10.0.2.2');
        effectiveHost = '10.0.2.2';
        _hostController.text = effectiveHost; // 更新输入框
      }

      // 确认使用的主机名和端口
      print('保存配置使用的主机名和端口: $effectiveHost:$port');

      // 更新配置
      _dbConfig.dbType = 'mysql';
      _dbConfig.mysql.host = effectiveHost; // 使用可能转换后的主机名
      _dbConfig.mysql.port = port;
      _dbConfig.mysql.database = database;
      _dbConfig.mysql.username = username;
      _dbConfig.mysql.password = password;

      // 打印配置信息用于调试
      print('配置已准备保存: $_dbConfig');

      // 保存配置到文件
      await _dbConfig.saveConfig();
      print('配置已成功保存到配置文件');

      // 设置UI为MySQL模式，但不切换数据库连接
      setState(() {
        _selectedDbType = 'mysql';
        _isLoading = false;
        _isEditingMysql = false; // 保存后退出编辑模式
      });

      // 显示现代化的重启应用提示对话框
      if (!mounted) return;

      final shouldRestart = await SettingsDialogs.showMySqlConfigSavedDialog(context, effectiveHost);

      if (shouldRestart == true) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.exitApp();
      } else {
        _showSnackBar(
          '配置已保存，请重启应用以应用MySQL配置',
          isSuccess: true,
          duration: 5,
        );
      }
    } catch (e) {
      print('保存MySQL配置错误: $e');

      if (!mounted) return;
      String errorMessage = e.toString();
      if (errorMessage.contains('Exception:')) {
        errorMessage = errorMessage.split('Exception:').last.trim();
      }
      _showSnackBar('保存配置失败: $errorMessage', isSuccess: false);

      setState(() {
        _isLoading = false;
      });
    }
  }


  // 从备份恢复数据库
  void _restoreDatabaseFromBackup() async {
    await SettingsDialogs.showRestoreDialog(
      context,
      dbProvider: dbProvider,
      dbConfig: _dbConfig,
      dbPath: _dbPath,
      dbType: _selectedDbType,
      requestStoragePermission: _requestStoragePermission,
      setState: (callback) {
        callback();
      },
      showSnackBar: (message, {bool isSuccess = true}) {
        setState(() {
          _isLoading = false;
          _loadingText = '';
        });
        _showSnackBar(message, isSuccess: isSuccess);
      },
      mounted: () => this.mounted,
    );
  }

  // 新增：显示Excel导出对话框方法
  void _showExcelExportDialog() async {
    await SettingsDialogs.showExportDialog(
      context,
      dbConfig: _dbConfig,
      dbPath: _dbPath,
      dbType: _selectedDbType,
      setState: (callback) {
        callback();
      },
      showSnackBar: (message, {bool isSuccess = true}) {
        setState(() {
          _isLoading = false;
          _loadingText = '';
        });
        _showSnackBar(message, isSuccess: isSuccess);
      },
      mounted: () => this.mounted,
    );
  }


  // 显示退出登录对话框
  void _showLogoutDialog() {
    // 获取当前用户信息
    final appState = Provider.of<AppState>(context, listen: false);
    final currentUser = appState.currentUser;
    
    // 使用公共组件显示退出登录对话框
    LogoutConfirmDialogManager.show(
      context,
      username: currentUser?.username,
    ).then((confirmed) {
      if (confirmed == true) {
        _performLogout();
      }
    });
  }

  // 执行退出登录
  void _performLogout() async {
    try {
      // 获取应用状态管理器
      final appState = Provider.of<AppState>(context, listen: false);
      
      // 清除登录状态
      appState.logout();
      
      // 显示退出成功消息
      if (mounted) {
        _showSnackBar('已成功退出登录', isSuccess: true);
      }
      
      // 延迟一下再跳转，让用户看到成功消息
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 导航到登录页面
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/login',
          (route) => false, // 清除所有路由历史
        );
      }
    } catch (e) {
      print('退出登录错误: $e');
      if (mounted) {
        _showSnackBar('退出登录失败: $e', isSuccess: false);
      }
    }
  }


}
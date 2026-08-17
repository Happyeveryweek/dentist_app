import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/app_state.dart';
import 'package:dentist_app/providers/appointments_provider.dart';
import 'package:dentist_app/providers/financial_provider.dart';
import 'package:dentist_app/providers/medical_record_provider.dart';
import 'package:dentist_app/providers/patient_image_provider.dart';
import 'package:dentist_app/providers/patient_provider.dart';
import 'package:dentist_app/providers/purchase_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import '../utils/snackbar_util.dart';
import '../features/settings/widgets/database_source_section.dart';
import '../features/settings/widgets/sync_config_section.dart';
import '../features/settings/widgets/system_settings_section.dart';
import '../features/settings/widgets/settings_dialogs.dart';
import '../features/settings/widgets/settings_header.dart';
import '../features/settings/widgets/sqlite_config_dialogs.dart';
import '../features/settings/services/permission_service.dart';
import '../features/settings/services/mysql_config_service.dart';
import '../features/settings/services/database_switch_service.dart';
import '../utils/app_logger.dart';

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
  bool _isEditingMysql = false;
  bool _isTestingMysql = false;

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
  DatabaseConfig _dbConfig = DatabaseConfig(
    dbType: 'sqlite',
    sqlite: SqliteConfig(path: ''),
    mysql: MySqlConfig(),
  );
  bool _showMysqlConfig = false;

  // Tab控制器
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

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
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 使用数据库切换服务加载配置
      _dbConfig = await DatabaseSwitchService.initDatabaseConfig();

      AppLogger.info(
        '已加载数据库配置: 类型=${_dbConfig.dbType}, SQLite路径=${_dbConfig.sqlite.path}',
      );

      // 检查组件是否仍然挂载
      if (!mounted) return;

      // 更新UI状态
      setState(() {
        _selectedDbType = _dbConfig.dbType;
        _dbPath =
            _dbConfig.dbType == 'sqlite'
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
      final provider = dbProvider;
      if (provider == null) return;
      final providerDbType = provider.dbType;
      final providerDbPath = provider.dbPath;
      AppLogger.info(
        '从Provider获取数据库信息: 类型=$providerDbType, 路径=$providerDbPath',
      );

      setState(() {
        _selectedDbType = providerDbType;
        // 优先使用Provider的实际路径
        if (providerDbPath.isNotEmpty) {
          _dbPath = providerDbPath;
          AppLogger.info('已更新显示路径: $_dbPath (来自Provider)');
        } else {
          AppLogger.info('Provider路径为空，保持当前路径: $_dbPath');
        }
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.info('加载设置错误: $e');
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

  Future<void> _switchDatabaseType(String dbType) async {
    // 如果选择的类型与当前类型相同，无需操作
    if (dbType == _selectedDbType) return;

    // 显示确认对话框
    final bool? confirmed =
        await SettingsDialogs.showDatabaseSwitchConfirmDialog(context, dbType);

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (dbType == 'sqlite') {
        // SQLite切换，确认后立即生效
        if (dbProvider == null) return;
        // 使用数据库切换服务更新配置
        _dbConfig = await DatabaseSwitchService.switchDatabaseType(
          'sqlite',
          _dbConfig,
        );

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
        _dbConfig = await DatabaseSwitchService.switchDatabaseType(
          'sqlite',
          _dbConfig,
          path: filePath,
        );

        // 切换数据库
        if (dbProvider == null) return;

        setState(() {
          _dbPath = filePath;
        });

        // 显示成功提示
        if (!mounted) return;
        final fileName = path.basename(filePath);
        await SqliteConfigDialogs.showSqliteConfigSavedDialog(
          context,
          fileName,
          filePath,
        );
      }
    } catch (e) {
      AppLogger.info('选择自定义数据库路径错误: $e');

      // 显示错误提示
      if (!mounted) return;
      _showSnackBar('设置自定义数据库路径失败', isSuccess: false);
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
    setState(() {
      _isTestingMysql = true;
      _mysqlTestSuccess = false;
    });

    try {
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

      // 测试按钮统一检查网络连通性和 MySQL 连接
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
        });
      } else {
        _showSnackBar('MySQL连接测试失败', isSuccess: false);
        setState(() {
          _mysqlTestSuccess = false;
        });
      }
    } catch (e) {
      AppLogger.info('MySQL连接测试失败: $e');

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
      });
    } finally {
      if (mounted) {
        setState(() {
          _isTestingMysql = false;
        });
      }
    }
  }

  // 显示提示消息
  void _showSnackBar(
    String message, {
    bool isSuccess = true,
    int duration = 3,
  }) {
    if (!mounted) return;
    SnackBarUtil.show(
      context,
      message,
      isSuccess: isSuccess,
      duration: duration,
    );
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
            child:
                _isLoading
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
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
                          isTestingMysql: _isTestingMysql,
                          dbConfig: _dbConfig,
                          hostController: _hostController,
                          portController: _portController,
                          databaseController: _databaseController,
                          usernameController: _usernameController,
                          passwordController: _passwordController,
                          onSwitchToSqlite: () => _switchDatabaseType('sqlite'),
                          onSwitchToMysql: () => _switchDatabaseType('mysql'),
                          onToggleMysqlEdit: _toggleMysqlEdit,
                          onTestConnection: _testMySqlConnection,
                          onSaveMysql:
                              _mysqlTestSuccess ? _saveMySQLConfig : null,
                          onSelectCustomDbPath: _selectCustomDbPath,
                        ),
                        const SyncConfigSection(),
                        SystemSettingsSection(onLogout: _showLogoutDialog),
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
    );
  }

  void _toggleMysqlEdit() {
    if (_isEditingMysql) {
      _hostController.text = _dbConfig.mysql.host;
      _portController.text = _dbConfig.mysql.port;
      _databaseController.text = _dbConfig.mysql.database;
      _usernameController.text = _dbConfig.mysql.username;
      _passwordController.text = _dbConfig.mysql.password;
      _mysqlTestSuccess = false;
    } else {
      _mysqlTestSuccess = false;
    }

    setState(() {
      _isEditingMysql = !_isEditingMysql;
    });
  }

  // 测试网络连接，作为 MySQL 连接测试的前置检查。
  Future<bool> _testNetworkConnection(String host, String port) async {
    try {
      final success = await MysqlConfigService.testNetworkConnection(
        host,
        port,
      );

      if (!mounted) return false;

      final effectiveHost = MysqlConfigService.getEffectiveHost(host);
      final isConverted = MysqlConfigService.isHostConverted(
        host,
        effectiveHost,
      );

      if (success) {
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
      AppLogger.info('网络测试错误: $e');
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

      // 检查Android平台上的localhost
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        AppLogger.info('Android平台检测到localhost，自动转换为10.0.2.2');
        effectiveHost = '10.0.2.2';
        _hostController.text = effectiveHost; // 更新输入框
      }

      // 确认使用的主机名和端口
      AppLogger.info('保存配置使用的主机名和端口: $effectiveHost:$port');

      // 更新配置
      _dbConfig.dbType = 'mysql';
      _dbConfig.mysql.host = effectiveHost; // 使用可能转换后的主机名
      _dbConfig.mysql.port = port;
      _dbConfig.mysql.database = database;
      _dbConfig.mysql.username = username;
      _dbConfig.mysql.password = password;

      // 打印配置信息用于调试
      AppLogger.info('配置已准备保存: $_dbConfig');

      // 保存配置到文件
      await _dbConfig.saveConfig();
      AppLogger.info('配置已成功保存到配置文件');

      // 设置UI为MySQL模式，但不切换数据库连接
      setState(() {
        _selectedDbType = 'mysql';
        _isLoading = false;
        _isEditingMysql = false; // 保存后退出编辑模式
      });

      // 显示现代化的重启应用提示对话框
      if (!mounted) return;

      final shouldRestart = await SettingsDialogs.showMySqlConfigSavedDialog(
        context,
        effectiveHost,
      );

      if (!mounted) return;
      if (shouldRestart == true) {
        final appState = Provider.of<AppState>(context, listen: false);
        appState.exitApp();
      } else {
        _showSnackBar('配置已保存，请重启应用以应用MySQL配置', isSuccess: true, duration: 5);
      }
    } catch (e) {
      AppLogger.info('保存MySQL配置错误: $e');

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

  // 显示退出登录对话框
  void _showLogoutDialog() {
    // 获取当前用户信息
    final currentUser =
        Provider.of<UserProvider>(context, listen: false).currentUser;

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
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final patientProvider = Provider.of<PatientProvider>(
        context,
        listen: false,
      );
      final appointmentsProvider = Provider.of<AppointmentsProvider>(
        context,
        listen: false,
      );
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );
      final purchaseProvider = Provider.of<PurchaseProvider>(
        context,
        listen: false,
      );
      final patientImageProvider = Provider.of<PatientImageProvider>(
        context,
        listen: false,
      );
      final medicalRecordProvider = Provider.of<MedicalRecordProvider>(
        context,
        listen: false,
      );

      userProvider.logout();
      await patientProvider.forceRefreshPatients();
      appointmentsProvider.clearCache();
      financialProvider.clearCache();
      purchaseProvider.clearCache();
      patientImageProvider.clearAllCache();
      medicalRecordProvider.clearAllCache();

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
      AppLogger.info('退出登录错误: $e');
      if (mounted) {
        _showSnackBar('退出登录失败: $e', isSuccess: false);
      }
    }
  }
}

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
import 'package:dentist_app/utils/database_utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as path;
import 'package:mysql1/mysql1.dart';
import 'package:dentist_app/utils/config_utils.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

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
  late DatabaseProvider dbProvider;

  // 测试数据库路径
  String _testDbPath = '';

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
    _tabController = TabController(length: 3, vsync: this);

    // 初始化_dbConfig以防止late错误
    _dbConfig = DatabaseConfig(
      dbType: 'sqlite',
      sqlite: SqliteConfig(path: ''),
      mysql: MySqlConfig(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 获取数据库提供者
      dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      _loadSettings();
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
      // 加载数据库配置
      _dbConfig = await DatabaseConfig.loadConfig();
      print(
        '已加载数据库配置: 类型=${_dbConfig.dbType}, SQLite路径=${_dbConfig.sqlite.path}',
      );

      // 检查组件是否仍然挂载
      if (!mounted) return;

      // 更新UI状态
      setState(() {
        _selectedDbType = _dbConfig.dbType;
        _dbPath = _dbConfig.dbType == 'sqlite' ? _dbConfig.sqlite.path : '';
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
      final providerDbType = dbProvider.dbType;
      final providerDbPath = dbProvider.dbPath;
      print('从Provider获取数据库信息: 类型=$providerDbType, 路径=$providerDbPath');

      setState(() {
        _selectedDbType = providerDbType;
        // 只有当Provider的路径不为空且不是缓存路径时才更新
        if (providerDbPath.isNotEmpty && !_isUsingCachePath(providerDbPath)) {
          _dbPath = providerDbPath;
          print('已更新显示路径: $_dbPath');
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

    setState(() {
      _isLoading = true;
    });

    try {
      if (dbType == 'sqlite') {
        // SQLite是默认类型，直接切换
        await dbProvider.switchDatabaseType('sqlite');

        // 更新UI状态
        setState(() {
          _selectedDbType = 'sqlite';
          _showMysqlConfig = false;
          _isEditingMysql = false; // 重置编辑模式
        });

        // 更新配置
        _dbConfig.dbType = 'sqlite';
        await _dbConfig.saveConfig();

        _showSnackBar('已切换到SQLite数据库', isSuccess: true);
      } else if (dbType == 'mysql') {
        // 对于MySQL，显示配置界面并更新选中状态
        setState(() {
          _showMysqlConfig = true;
          _selectedDbType = 'mysql'; // 立即更新UI选中状态
          _isEditingMysql = false; // 默认不进入编辑模式
          _mysqlTestSuccess = false; // 重置连接测试状态
        });

        // 从已保存的配置中加载MySQL设置
        _hostController.text = _dbConfig.mysql.host;
        _portController.text = _dbConfig.mysql.port;
        _databaseController.text = _dbConfig.mysql.database;
        _usernameController.text = _dbConfig.mysql.username;
        _passwordController.text = _dbConfig.mysql.password;
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

      // 获取应用文档目录作为默认目录
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbDir = path.join(documentsDir.path, 'databases');

      // 确保目录存在
      final dirObj = Directory(dbDir);
      if (!await dirObj.exists()) {
        await dirObj.create(recursive: true);
      }

      // 使用file_selector打开文件选择器
      const XTypeGroup sqliteGroup = XTypeGroup(
        label: 'SQLite数据库',
        extensions: ['db', 'sqlite', 'sqlite3'],
        mimeTypes: [
          'application/octet-stream',
          'application/x-sqlite3',
          'application/vnd.sqlite3',
        ],
        uniformTypeIdentifiers: ['public.database', 'public.data'],
      );

      // 使用初始目录打开文件选择器（注意：某些平台可能不支持初始目录参数）
      final file = await openFile(
        acceptedTypeGroups: [sqliteGroup],
        initialDirectory: dbDir,
      );

      if (file != null) {
        final path = file.path;

        // 检查文件是否存在
        final fileObj = File(path);
        if (!(await fileObj.exists())) {
          if (!mounted) return;
          _showSnackBar('所选文件不存在', isSuccess: false);
          return;
        }

        // 更新配置
        _dbConfig.dbType = 'sqlite';
        _dbConfig.sqlite.path = path;
        await _dbConfig.saveConfig();

        // 切换数据库
        await dbProvider.switchDatabaseType('sqlite', path: path);

        setState(() {
          _dbPath = path;
        });

        // 显示成功提示
        if (!mounted) return;
        _showSnackBar('自定义数据库路径已设置', isSuccess: true);
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

      // 获取目录路径
      final String? directoryPath = await getDirectoryPath();

      if (directoryPath == null) {
        // 用户取消了目录选择
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      print('选择的目录: $directoryPath');

      // 确认目录存在
      final selectedDir = Directory(directoryPath);
      if (!await selectedDir.exists()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar('所选目录不存在', isSuccess: false);
        }
        return;
      }

      // Step 2: 从目录中列出并选择数据库文件
      final List<FileSystemEntity> entities = await selectedDir.list().toList();
      final List<File> dbFiles =
          entities.whereType<File>().where((file) {
            final extension = path.extension(file.path).toLowerCase();
            return extension == '.db' ||
                extension == '.sqlite' ||
                extension == '.sqlite3';
          }).toList();

      // 如果目录中没有数据库文件，提示用户
      if (dbFiles.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showSnackBar(
            '所选目录中没有找到数据库文件(.db, .sqlite或.sqlite3)',
            isSuccess: false,
          );
        }
        return;
      }

      // 隐藏加载指示器
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // 显示文件选择对话框
      final File? selectedFile = await showDialog<File>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('选择数据库文件'),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.4, // 最大高度为屏幕高度的40%
                  maxWidth: double.maxFinite,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, // 根据内容自适应高度
                    children:
                        dbFiles.map((file) {
                          final fileName = path.basename(file.path);
                          return ListTile(
                            leading: const Icon(
                              Icons.storage,
                              color: Colors.blue,
                            ),
                            title: Text(fileName),
                            onTap: () => Navigator.of(context).pop(file),
                          );
                        }).toList(),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
      );

      if (selectedFile == null) {
        // 用户取消了文件选择
        return;
      }

      // 获取选择的文件路径和文件名
      final filePath = selectedFile.path;
      final fileName = path.basename(filePath);
      print('选择的文件: $filePath');

      // 显示确认对话框
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('确认选择数据库'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('确定要使用以下数据库文件吗？'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '文件名: $fileName',
                          style: const TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '路径: $filePath',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('确认'),
                ),
              ],
            ),
      );

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
            final shouldLoadNow = await showDialog<bool>(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('数据库配置已更新'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('数据库路径已更新为: $fileName'),
                        const SizedBox(height: 12),
                        const Text(
                          '您可以选择立即加载新数据库，或稍后重启应用时自动加载。',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.amber.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.amber.shade800,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  '注意: 加载大型数据库可能需要一些时间。',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7A5800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('稍后加载'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                        ),
                        child: const Text('立即加载'),
                      ),
                    ],
                  ),
            );

            if (shouldLoadNow == true) {
              // 用户选择立即加载数据库
              setState(() {
                _isLoading = true;
                _loadingText = '正在加载数据库...';
              });

              try {
                // 切换数据库
                await dbProvider.switchDatabaseType('sqlite', path: filePath);
                print('数据库已切换');

                // 更新状态和通知监听器
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });

                  // 强制数据库提供者通知所有监听器数据源已更改
                  dbProvider.forceDataChanged(navigateToDashboard: true);
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
    try {
      if (Platform.isAndroid) {
        // 判断Android版本
        if (await Permission.manageExternalStorage.isGranted) {
          return true; // 已有权限
        }

        // 请求管理外部存储权限（Android 11+）
        PermissionStatus manageStatus =
            await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) {
          return true;
        }

        // 尝试请求普通存储权限
        Map<Permission, PermissionStatus> statuses =
            await [Permission.storage].request();

        if (statuses[Permission.storage]!.isGranted) {
          return true;
        } else {
          // 显示设置对话框提示用户手动授权
          if (mounted) {
            showDialog(
              context: context,
              builder:
                  (BuildContext context) => AlertDialog(
                    title: const Text('需要存储权限'),
                    content: const Text('请前往设置中授予应用存储权限，以便选择和读取数据库文件。'),
                    actions: [
                      TextButton(
                        child: const Text('取消'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      TextButton(
                        child: const Text('去设置'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          openAppSettings();
                        },
                      ),
                    ],
                  ),
            );
          }
          return false;
        }
      } else if (Platform.isIOS) {
        // iOS请求权限
        PermissionStatus status = await Permission.photos.request();
        return status.isGranted;
      } else {
        // 其他平台默认允许
        return true;
      }
    } catch (e) {
      print('请求权限出错: $e');
      return false;
    }
  }

  // 加载测试数据库
  Future<void> _loadTestDatabase() async {
    try {
      // 显示确认对话框
      final confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('加载测试数据库'),
              content: const Text('这将复制测试数据库到应用文档目录并切换到测试数据库。确定要继续吗？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('确定'),
                ),
              ],
            ),
      );

      if (confirm != true) return;

      // 显示加载进度对话框
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('正在加载测试数据库...'),
              ],
            ),
          );
        },
      );

      // 复制测试数据库
      final testDbPath = await DatabaseUtils.copyTestDatabaseToDocuments();

      // 关闭进度对话框
      if (!mounted) return;
      Navigator.of(context).pop();

      if (testDbPath.isNotEmpty) {
        // 更新配置
        _dbConfig.dbType = 'sqlite';
        _dbConfig.sqlite.path = testDbPath;
        await _dbConfig.saveConfig();

        // 切换数据库
        await dbProvider.switchDatabaseType('sqlite', path: testDbPath);

        setState(() {
          _selectedDbType = 'sqlite';
          _dbPath = testDbPath; // 立即更新本地路径变量
          _showMysqlConfig = false;
        });

        // 强制数据库提供者通知所有监听器数据源已更改
        dbProvider.forceDataChanged(navigateToDashboard: true);
        print('测试数据库路径已更新: $_dbPath');

        // 显示成功提示
        if (!mounted) return;
        _showSnackBar('测试数据库已加载', isSuccess: true);
      } else {
        // 显示错误提示
        if (!mounted) return;
        _showSnackBar('加载测试数据库失败', isSuccess: false);
      }
    } catch (e) {
      print('加载测试数据库错误: $e');

      // 关闭可能存在的进度对话框
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // 显示错误提示
      _showSnackBar('加载测试数据库失败: ${e.toString()}', isSuccess: false);
    }
  }

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

      // 如果是Android模拟器使用的localhost，转换为10.0.2.2
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        effectiveHost = '10.0.2.2';
        print('Android模拟器检测到，将localhost转换为10.0.2.2');
      }

      print('测试MySQL连接: $effectiveHost:$port/$database (用户: $username)');

      // 使用mysql1包测试连接
      final settings = ConnectionSettings(
        host: effectiveHost,
        port: port,
        user: username,
        password: password,
        db: database,
      );

      final conn = await MySqlConnection.connect(settings);

      // 测试简单查询
      final results = await conn.query('SELECT 1 as test');
      await conn.close();

      final value = results.first['test'];
      print('连接成功，查询结果: $value');

      if (!mounted) return;

      _showSnackBar('MySQL连接测试成功', isSuccess: true);
      setState(() {
        _mysqlTestSuccess = true;
        _isLoading = false;
      });
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

    final snackBar = SnackBar(
      content: Row(
        children: [
          Icon(
            isSuccess ? Icons.check_circle : Icons.error,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: isSuccess ? Colors.green.shade700 : Colors.red.shade700,
      duration: Duration(seconds: duration),
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('系统设置'),
        centerTitle: true,
        backgroundColor: AppTheme.cardBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              // 帮助说明
              showDialog(
                context: context,
                builder:
                    (context) => AlertDialog(
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
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.secondaryText,
          tabs: const [
            Tab(icon: Icon(Icons.storage), text: '数据源'),
            Tab(icon: Icon(Icons.backup), text: '备份恢复'),
            Tab(icon: Icon(Icons.settings), text: '系统设置'),
          ],
        ),
      ),
      body:
          _isLoading
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
                  _buildDatabaseSourceTab(),
                  _buildBackupRestoreTab(),
                  _buildSystemSettingsTab(),
                ],
              ),
    );
  }

  // 获取用于显示的数据库路径
  String _getDisplayDbPath() {
    // 首先优先使用_dbPath实例变量（这是用户最新选择的路径）
    if (_dbPath.isNotEmpty) {
      return _dbPath;
    }

    // 其次检查数据库提供者的当前路径
    try {
      if (dbProvider.isInitialized && dbProvider.dbPath.isNotEmpty) {
        return dbProvider.dbPath;
      }
    } catch (e) {
      print('从数据库提供者获取路径错误: $e');
    }

    // 最后检查配置文件中的路径
    try {
      if (_dbConfig.dbType == 'sqlite' && _dbConfig.sqlite.path.isNotEmpty) {
        return _dbConfig.sqlite.path;
      }
    } catch (e) {
      print('从配置获取显示数据库路径错误: $e');
    }

    return "未设置数据库路径";
  }

  // 构建数据源tab
  Widget _buildDatabaseSourceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '选择数据源类型',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDatabaseTypeOption(
                          title: 'SQLite',
                          subtitle: '本地数据库',
                          icon: Icons.storage,
                          isSelected: _selectedDbType == 'sqlite',
                          onTap: () => _switchDatabaseType('sqlite'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildDatabaseTypeOption(
                          title: 'MySQL',
                          subtitle: '远程数据库',
                          icon: Icons.cloud,
                          isSelected: _selectedDbType == 'mysql',
                          onTap: () => _switchDatabaseType('mysql'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // MySQL配置区域
          if (_showMysqlConfig)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'MySQL配置',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            children: [
                              // 编辑按钮
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _isEditingMysql = !_isEditingMysql;
                                  });
                                },
                                icon: Icon(
                                  _isEditingMysql
                                      ? Icons.lock_open
                                      : Icons.edit,
                                  size: 16,
                                ),
                                label: Text(_isEditingMysql ? '完成编辑' : '编辑配置'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _isEditingMysql
                                          ? Colors.green
                                          : AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // 根据编辑状态显示不同的UI
                      _isEditingMysql
                          ? _buildMySQLEditForm()
                          : _buildMySQLConfigDetails(),
                    ],
                  ),
                ),
              ),
            ),

          // 当前数据库信息
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '当前数据库信息',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedDbType == 'sqlite')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SQLite数据库配置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // 显示当前数据库文件路径
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.folder_open,
                                      color: AppTheme.primaryColor,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '当前数据库路径:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Color(0xFF555555),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    _getDisplayDbPath(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '数据库类型: SQLite 3 (本地文件数据库)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _selectCustomDbPathAlternative,
                                  icon: const Icon(Icons.folder_open),
                                  label: const Text('选择数据库文件'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _loadTestDatabase,
                                  icon: const Icon(Icons.science),
                                  label: const Text('加载测试数据库'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Text('数据库类型: MySQL'),
                              const Spacer(),
                              // 显示编辑状态标签
                              if (_isEditingMysql)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    '编辑中',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.link,
                                color: AppTheme.secondaryColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '连接信息: ${_dbConfig.mysql.host}:${_dbConfig.mysql.port}/${_dbConfig.mysql.database}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 重写备份和恢复选项卡
  Widget _buildBackupRestoreTab() {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 数据库备份卡片 - 美化版
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.save,
                              color: AppTheme.primaryColor,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '数据库备份',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '备份将保存为.db文件，可以方便地进行恢复，建议定期备份以防数据丢失。',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (_dbConfig.dbType != 'sqlite') {
                                _showSnackBar(
                                  '内置备份功能仅支持SQLite数据库类型。MySQL数据库请使用专业数据库工具如MySQL Workbench进行备份。',
                                  isSuccess: false,
                                );
                                return;
                              }

                              // 请求存储权限
                              final bool permissionGranted =
                                  await _requestStoragePermission();
                              if (!permissionGranted) {
                                _showSnackBar(
                                  '需要存储权限才能备份数据库',
                                  isSuccess: false,
                                );
                                return;
                              }

                              // 显示备份选项对话框
                              _showBackupDialog();
                            },
                            icon: const Icon(Icons.backup, size: 20),
                            label: const Text(
                              '备份数据库',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 数据库恢复卡片 - 美化版
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.settings_backup_restore,
                              color: Colors.amber.shade700,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              '数据库恢复',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.amber.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.amber.shade800,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  '警告：恢复操作将覆盖当前所有数据！请确保选择正确的备份文件。',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Color(0xFF7A5800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _restoreDatabaseFromBackup,
                            icon: const Icon(Icons.restore, size: 20),
                            label: const Text(
                              '从备份恢复',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Excel导出卡片 - 美化版
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.table_chart,
                              color: Colors.green.shade600,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Excel导出',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            '将患者信息导出为Excel表格文件，方便进行数据分析和统计报表生成。',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              // 请求存储权限
                              final bool permissionGranted =
                                  await _requestStoragePermission();
                              if (!permissionGranted) {
                                _showSnackBar(
                                  '需要存储权限才能导出Excel文件',
                                  isSuccess: false,
                                );
                                return;
                              }

                              // 显示Excel导出对话框
                              _showExcelExportDialog();
                            },
                            icon: const Icon(Icons.file_download, size: 20),
                            label: const Text(
                              '导出为Excel',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 加载指示器
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _loadingText.isNotEmpty ? _loadingText : '请稍候...',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 新增：显示备份对话框方法
  void _showBackupDialog() async {
    // 生成默认文件名，格式：dentist_backup_年月日_时分秒.db
    final now = DateTime.now();
    final defaultFilename =
        'dentist_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.db';

    // 文件名控制器
    final filenameController = TextEditingController(text: defaultFilename);

    // 保存的目录
    String? selectedDir;

    // 显示备份选项对话框
    await showDialog<void>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.backup, color: AppTheme.primaryColor),
                    const SizedBox(width: 10),
                    const Text('备份数据库'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('请选择备份保存位置和文件名:'),
                      const SizedBox(height: 16),

                      // 显示选择的目录
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

                      // 选择目录按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // 弹出文件夹选择对话框
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
                                                '/storage/emulated/0/Download',
                                              );
                                              if (await dir.exists()) {
                                                Navigator.pop(
                                                  context,
                                                  dir.path,
                                                );
                                              } else {
                                                _showSnackBar(
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
                                              Navigator.pop(context, dir.path);
                                            },
                                          ),
                                          // 添加浏览其他文件夹选项
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

                      // 自定义文件名输入框
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
                              Navigator.pop(context);

                              // 获取文件名并确保其有.db扩展名
                              String filename = filenameController.text.trim();
                              if (!filename.toLowerCase().endsWith('.db')) {
                                filename += '.db';
                              }

                              // 构建完整的备份路径
                              final backupPath = path.join(
                                selectedDir!,
                                filename,
                              );

                              // 显示加载指示器 - 使用SettingsScreen的setState，而非StatefulBuilder的setState
                              if (this.mounted) {
                                this.setState(() {
                                  _isLoading = true;
                                  _loadingText = '正在备份数据库...';
                                });
                              } else {
                                return; // 如果SettingsScreen不再挂载，直接返回
                              }

                              try {
                                // 获取数据库提供者
                                final dbProvider =
                                    Provider.of<DatabaseProvider>(
                                      this.context,
                                      listen: false,
                                    );

                                // 执行备份
                                final success = await dbProvider.backupDatabase(
                                  backupPath,
                                );

                                // 隐藏加载指示器 - 使用SettingsScreen的setState
                                if (this.mounted) {
                                  this.setState(() {
                                    _isLoading = false;
                                    _loadingText = '';
                                  });

                                  // 显示结果
                                  if (success) {
                                    _showSnackBar(
                                      '数据库已成功备份到: $backupPath',
                                      isSuccess: true,
                                    );
                                  } else {
                                    _showSnackBar('数据库备份失败', isSuccess: false);
                                  }
                                }
                              } catch (e) {
                                print('备份数据库错误: $e');

                                // 隐藏加载指示器并显示错误
                                if (this.mounted) {
                                  this.setState(() {
                                    _isLoading = false;
                                    _loadingText = '';
                                  });
                                  _showSnackBar('备份失败: $e', isSuccess: false);
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

      // 在移动设备上使用下载目录
      if (Platform.isAndroid || Platform.isIOS) {
        // 在Android/iOS上默认使用下载目录
        Directory? directory;

        if (Platform.isAndroid) {
          // 获取下载目录
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            // 备选方案：使用外部存储目录
            final dirs = await getExternalStorageDirectories();
            if (dirs != null && dirs.isNotEmpty) {
              directory = dirs.first;
            } else {
              // 使用应用文档目录
              directory = await getApplicationDocumentsDirectory();
            }
          }
        } else {
          // iOS使用文档目录
          directory = await getApplicationDocumentsDirectory();
        }

        return directory.path;
      }
      // 在桌面平台上使用文件选择器
      else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        // 使用file_selector库的getDirectoryPath方法
        final String? directoryPath = await getDirectoryPath(
          confirmButtonText: '选择此文件夹',
        );
        return directoryPath;
      }

      // 默认返回应用文档目录
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    } catch (e) {
      print('选择目录错误: $e');
      return null;
    }
  }

  // 构建系统设置tab
  Widget _buildSystemSettingsTab() {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '通知设置',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SwitchListTile(
                        title: const Text('预约提醒'),
                        subtitle: const Text('开启后将在预约时间前提醒'),
                        value: settingsProvider.appointmentReminder,
                        onChanged: (value) {
                          settingsProvider.updateAppointmentReminder(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 构建数据库类型选项
  Widget _buildDatabaseTypeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.primaryColor.withOpacity(0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : Colors.grey,
              size: 36,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected ? AppTheme.primaryColor : Colors.black,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppTheme.primaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 测试网络连接
  Future<bool> _testNetworkConnection(String host, String port) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // 如果是Android模拟器使用的localhost，转换为10.0.2.2
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        effectiveHost = '10.0.2.2';
        print('Android模拟器检测到，网络测试将localhost转换为10.0.2.2');
      }

      print('测试与 $effectiveHost:$port 的网络连接...');

      // 使用Socket尝试连接
      try {
        final socket = await Socket.connect(
          effectiveHost,
          int.parse(port),
          timeout: const Duration(seconds: 5),
        );

        // 如果能连接成功，关闭Socket
        await socket.close();
        print('网络连接测试成功：可以连接到 $effectiveHost:$port');

        if (!mounted) return false;

        setState(() {
          _isLoading = false;
        });

        // 如果使用了转换后的地址，在消息中提示用户
        if (effectiveHost != host) {
          _showSnackBar(
            '网络连接正常，已将 $host 转换为 $effectiveHost 连接成功',
            isSuccess: true,
          );
        } else {
          _showSnackBar('网络连接正常，可以连接到 $host:$port', isSuccess: true);
        }

        // 如果使用了转换，更新输入框内容
        if (effectiveHost != host) {
          _hostController.text = effectiveHost;
        }

        return true;
      } catch (e) {
        print('网络连接测试失败: $e');

        // 向用户显示连接错误
        if (!mounted) return false;
        if (effectiveHost != host) {
          _showSnackBar(
            '无法连接到 $effectiveHost:$port (转换自 $host)，请检查网络或主机是否可达',
            isSuccess: false,
          );
        } else {
          _showSnackBar('无法连接到 $host:$port，请检查网络或主机是否可达', isSuccess: false);
        }

        setState(() {
          _isLoading = false;
        });
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

      // 显示重启应用的提示对话框
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Text('MySQL配置已保存'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('MySQL连接配置已成功保存，但需要重启应用才能生效。'),
                  const SizedBox(height: 16),
                  if (effectiveHost != host)
                    Text(
                      '注意: localhost已自动转换为$effectiveHost以支持Android设备连接',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showSnackBar(
                      '配置已保存，请重启应用以应用MySQL配置',
                      isSuccess: true,
                      duration: 5,
                    );
                  },
                  child: const Text('稍后重启'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // 使用退出应用功能
                    Navigator.of(context).pop();
                    appState.exitApp();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('立即重启'),
                ),
              ],
            ),
      );
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

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
    );
  }

  // 从备份恢复数据库
  void _restoreDatabaseFromBackup() async {
    // 首先检查数据库类型
    if (dbProvider.dbType != 'sqlite') {
      _showSnackBar(
        '当前数据库类型为 ${dbProvider.dbType}，仅支持还原到SQLite数据库',
        isSuccess: false,
      );
      return;
    }

    final bool permissionGranted = await _requestStoragePermission();
    if (!permissionGranted) {
      _showSnackBar('需要存储权限才能访问备份文件', isSuccess: false);
      return;
    }

    // 确保挂载检查
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadingText = '选择备份文件...';
      });
    } else {
      return; // 如果不再挂载，直接返回
    }

    try {
      // 使用file_selector选择.db文件
      const XTypeGroup sqliteGroup = XTypeGroup(
        label: '数据库备份文件',
        extensions: ['db', 'sqlite', 'sqlite3'],
        mimeTypes: [
          'application/octet-stream',
          'application/x-sqlite3',
          'application/vnd.sqlite3',
        ],
        uniformTypeIdentifiers: ['public.database', 'public.data'],
      );

      final XFile? file = await openFile(acceptedTypeGroups: [sqliteGroup]);

      // 检查挂载状态
      if (!mounted) return;

      setState(() => _isLoading = false);

      if (file != null) {
        final String backupPath = file.path;

        // 显示确认对话框
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
          // 再次检查挂载状态
          if (mounted) {
            setState(() {
              _isLoading = true;
              _loadingText = '正在恢复数据库...';
            });
          } else {
            return;
          }

          final bool success = await dbProvider.restoreDatabaseFromBackup(
            backupPath,
          );

          // 完成后检查挂载状态
          if (!mounted) return;

          setState(() => _isLoading = false);

          if (success) {
            // 提示成功并重新加载应用
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
                          // 重置状态并重新加载
                          final appState = Provider.of<AppState>(
                            context,
                            listen: false,
                          );
                          appState.resetState();
                          Phoenix.rebirth(context);
                        },
                        child: const Text('确定'),
                      ),
                    ],
                  ),
            );
          } else {
            // 提示失败
            _showSnackBar('恢复数据库失败，请检查备份文件是否有效', isSuccess: false);
          }
        }
      }
    } catch (e) {
      print('恢复数据库出错: $e');
      // 错误处理时检查挂载状态
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('恢复失败: $e', isSuccess: false);
      }
    }
  }

  // 新增：显示Excel导出对话框方法
  void _showExcelExportDialog() async {
    // 生成默认文件名，格式：患者信息_年月日_时分秒.xlsx
    final now = DateTime.now();
    final defaultFilename =
        '患者信息_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}.xlsx';

    // 文件名控制器
    final filenameController = TextEditingController(text: defaultFilename);

    // 保存的目录
    String? selectedDir;

    // 显示导出选项对话框
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

                      // 显示选择的目录
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

                      // 选择目录按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // 弹出文件夹选择对话框
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
                                                '/storage/emulated/0/Download',
                                              );
                                              if (await dir.exists()) {
                                                Navigator.pop(
                                                  context,
                                                  dir.path,
                                                );
                                              } else {
                                                _showSnackBar(
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
                                              Navigator.pop(context, dir.path);
                                            },
                                          ),
                                          // 添加浏览其他文件夹选项
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

                      // 自定义文件名输入框
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
                              Navigator.pop(context);

                              // 获取文件名并确保其有.xlsx扩展名
                              String filename = filenameController.text.trim();
                              if (!filename.toLowerCase().endsWith('.xlsx')) {
                                filename += '.xlsx';
                              }

                              // 构建完整的导出路径
                              final exportPath = path.join(
                                selectedDir!,
                                filename,
                              );

                              // 显示加载指示器 - 确保使用SettingsScreen的setState
                              if (this.mounted) {
                                this.setState(() {
                                  _isLoading = true;
                                  _loadingText = '正在导出Excel...';
                                });
                              } else {
                                return; // 如果SettingsScreen不再挂载，直接返回
                              }

                              try {
                                // 获取数据库提供者
                                final dbProvider =
                                    Provider.of<DatabaseProvider>(
                                      this.context,
                                      listen: false,
                                    );

                                // 执行Excel导出
                                final excelPath = await dbProvider
                                    .exportPatientsToExcel(exportPath);

                                // 隐藏加载指示器 - 使用SettingsScreen的setState
                                if (this.mounted) {
                                  this.setState(() {
                                    _isLoading = false;
                                    _loadingText = '';
                                  });

                                  // 显示成功消息
                                  _showSuccessDialog(
                                    '患者信息导出成功！',
                                    '文件已保存到:\n$excelPath',
                                  );
                                }
                              } catch (e) {
                                print('导出Excel错误: $e');

                                // 隐藏加载指示器并显示错误
                                if (this.mounted) {
                                  this.setState(() {
                                    _isLoading = false;
                                    _loadingText = '';
                                  });
                                  _showSnackBar('导出失败: $e', isSuccess: false);
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

  // 构建MySQL配置编辑表单
  Widget _buildMySQLEditForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _hostController,
          decoration: const InputDecoration(
            labelText: '主机名/IP地址',
            hintText: '例如: localhost或10.0.2.2',
            prefixIcon: Icon(Icons.computer),
          ),
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _portController,
          decoration: const InputDecoration(
            labelText: '端口',
            hintText: '默认: 3306',
            prefixIcon: Icon(Icons.settings_ethernet),
          ),
          keyboardType: TextInputType.number,
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _databaseController,
          decoration: const InputDecoration(
            labelText: '数据库名称',
            hintText: '例如: dental_clinic',
            prefixIcon: Icon(Icons.storage),
          ),
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _usernameController,
          decoration: const InputDecoration(
            labelText: '用户名',
            hintText: '例如: root',
            prefixIcon: Icon(Icons.person),
          ),
          enabled: true,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(
            labelText: '密码',
            hintText: '******',
            prefixIcon: Icon(Icons.lock),
          ),
          obscureText: true,
          enabled: true,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  final host = _hostController.text;
                  final port = _portController.text;
                  _testNetworkConnection(host, port);
                },
                icon: const Icon(Icons.network_check, size: 14),
                label: const Text('测网络'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _testMySqlConnection,
                icon: const Icon(Icons.link, size: 14),
                label: const Text('测连接'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _mysqlTestSuccess ? _saveMySQLConfig : null,
                icon: const Icon(Icons.save, size: 14),
                label: const Text('保存'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  disabledBackgroundColor: Colors.grey.shade400,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 构建MySQL配置详情（只读模式）
  Widget _buildMySQLConfigDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildConfigItem(
                '主机名/IP地址',
                _hostController.text,
                Icons.computer,
                Colors.blue,
              ),
              const Divider(),
              _buildConfigItem(
                '端口',
                _portController.text,
                Icons.settings_ethernet,
                Colors.orange,
              ),
              const Divider(),
              _buildConfigItem(
                '数据库名称',
                _databaseController.text,
                Icons.storage,
                Colors.green,
              ),
              const Divider(),
              _buildConfigItem(
                '用户名',
                _usernameController.text,
                Icons.person,
                Colors.purple,
              ),
              const Divider(),
              _buildConfigItem('密码', '••••••••', Icons.lock, Colors.red),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '提示: 点击"编辑配置"按钮可以修改MySQL连接设置',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isEditingMysql = true;
                  });
                },
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('编辑配置'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 构建配置项展示
  Widget _buildConfigItem(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

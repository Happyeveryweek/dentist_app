import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../theme/app_theme.dart';
import '../providers/settings_provider.dart';
import '../providers/database_provider.dart';

class DataSourceScreen extends StatefulWidget {
  const DataSourceScreen({Key? key}) : super(key: key);

  @override
  State<DataSourceScreen> createState() => _DataSourceScreenState();
}

class _DataSourceScreenState extends State<DataSourceScreen> {
  // 数据源类型
  String _selectedDataSource = 'sqlite'; // sqlite 或 mysql

  // SQLite 文件路径
  String _sqliteDbPath = '';

  // MySQL连接参数
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '3306');
  final _databaseController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

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
        _selectedDataSource = settingsProvider.dataSourceType ?? 'sqlite';
        _sqliteDbPath = settingsProvider.sqliteDbPath ?? '';
        _hostController.text = settingsProvider.mysqlHost ?? '';
        _portController.text = settingsProvider.mysqlPort ?? '3306';
        _databaseController.text = settingsProvider.mysqlDatabase ?? '';
        _usernameController.text = settingsProvider.mysqlUsername ?? '';
        _passwordController.text = settingsProvider.mysqlPassword ?? '';
      });

      // 如果已经配置过MySQL，就默认为已测试通过
      if (_selectedDataSource == 'mysql' &&
          _hostController.text.isNotEmpty &&
          _databaseController.text.isNotEmpty) {
        _connectionTested = true;
        _connectionSuccess = true;
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
    super.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已选择数据库文件: ${path.basename(filePath)}'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor ==
                AppTheme.purpleBackground
            ? AppTheme.purpleColor // 紫色主题使用主色调
            : null, // 其他主题使用默认颜色
      ));
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
                ? AppTheme.purpleColor // 紫色主题使用主色调
                : AppTheme.successColor, // 其他主题使用成功色
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

  // 保存设置
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

      // 保存数据源类型
      settingsProvider.setDataSourceType(_selectedDataSource);

      // 保存SQLite数据库路径
      if (_selectedDataSource == 'sqlite') {
        settingsProvider.setSqliteDbPath(_sqliteDbPath);
      }

      // 保存MySQL设置
      if (_selectedDataSource == 'mysql') {
        settingsProvider.setMySQLHost(_hostController.text);
        settingsProvider.setMySQLPort(_portController.text);
        settingsProvider.setMySQLDatabase(_databaseController.text);
        settingsProvider.setMySQLUsername(_usernameController.text);
        settingsProvider.setMySQLPassword(_passwordController.text);
      }

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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('数据源设置已保存，将在应用重启后完全生效'),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor ==
                  AppTheme.purpleBackground
              ? AppTheme.purpleColor // 紫色主题使用主色调
              : AppTheme.successColor, // 其他主题使用成功色
        ),
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据源配置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 数据源选择部分
          _buildSectionHeader('数据源类型'),
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
                  _buildRadioTile(
                    title: 'SQLite (本地)',
                    subtitle: '数据存储在本地设备上，无需网络连接',
                    value: 'sqlite',
                    groupValue: _selectedDataSource,
                    onChanged: (value) {
                      setState(() {
                        _selectedDataSource = value!;
                      });
                    },
                  ),
                  if (_selectedDataSource == 'sqlite') ...[
                    const Divider(),
                    _buildSqliteSettings(),
                  ],
                  const Divider(),
                  _buildRadioTile(
                    title: 'MySQL (远程)',
                    subtitle: '数据存储在远程服务器上，可多设备共享数据',
                    value: 'mysql',
                    groupValue: _selectedDataSource,
                    onChanged: (value) {
                      setState(() {
                        _selectedDataSource = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),

          // MySQL连接设置部分
          if (_selectedDataSource == 'mysql') ...[
            _buildSectionHeader('MySQL 连接设置'),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isEditing) ...[
                        // 显示当前MySQL连接信息（只读模式）
                        _buildSettingItem(
                          icon: Icons.computer,
                          title: '主机地址',
                          value: _hostController.text.isEmpty
                              ? '未设置'
                              : _hostController.text,
                        ),
                        const Divider(),
                        _buildSettingItem(
                          icon: Icons.account_tree,
                          title: '数据库名称',
                          value: _databaseController.text.isEmpty
                              ? '未设置'
                              : _databaseController.text,
                        ),
                        const Divider(),
                        _buildSettingItem(
                          icon: Icons.person,
                          title: '用户名',
                          value: _usernameController.text.isEmpty
                              ? '未设置'
                              : _usernameController.text,
                        ),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                  _connectionTested = false;
                                  _connectionSuccess = false;
                                });
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('编辑连接信息'),
                            ),
                          ],
                        ),
                      ] else ...[
                        // 编辑模式下的表单
                        TextFormField(
                          controller: _hostController,
                          decoration: const InputDecoration(
                            labelText: '主机地址',
                            hintText: 'localhost 或 IP地址',
                            prefixIcon: Icon(Icons.computer),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入主机地址';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _portController,
                          decoration: const InputDecoration(
                            labelText: '端口',
                            hintText: '3306',
                            prefixIcon: Icon(Icons.settings_ethernet),
                          ),
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
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _databaseController,
                          decoration: const InputDecoration(
                            labelText: '数据库名称',
                            hintText: '输入数据库名称',
                            prefixIcon: Icon(Icons.account_tree),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入数据库名称';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: '用户名',
                            hintText: '输入数据库用户名',
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入用户名';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: '密码',
                            hintText: '输入数据库密码',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (_connectionTested && _connectionSuccess)
                              const Padding(
                                padding: EdgeInsets.only(right: 16.0),
                                child: Icon(Icons.check_circle,
                                    color: AppTheme.successColor),
                              ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = false;
                                });
                              },
                              child: const Text('取消'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isTestingConnection
                                  ? null
                                  : _testMySQLConnection,
                              icon: _isTestingConnection
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.link),
                              label: const Text('测试连接'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed:
                                  (_connectionSuccess && !_isSavingSettings)
                                      ? _saveSettings
                                      : null,
                              icon: _isSavingSettings
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('保存'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],

          // SQLite数据源下的保存按钮
          if (_selectedDataSource == 'sqlite')
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isSavingSettings ? null : _saveSettings,
                    icon: _isSavingSettings
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('保存设置'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ),

          // 数据源说明
          Padding(
            padding: const EdgeInsets.only(top: 32, bottom: 16),
            child: Text(
              '数据源说明',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ListTile(
                    leading:
                        Icon(Icons.info_outline, color: AppTheme.primaryColor),
                    title: Text('SQLite数据源'),
                    subtitle: Text('数据存储在本地设备上，适合单设备使用。无需网络连接，操作简单。'),
                  ),
                  const Divider(),
                  const ListTile(
                    leading:
                        Icon(Icons.info_outline, color: AppTheme.primaryColor),
                    title: Text('MySQL数据源'),
                    subtitle:
                        Text('数据存储在远程服务器上，适合多设备共享数据。需要网络连接，可能需要专业人员配置服务器。'),
                  ),
                  const Divider(),
                  const ListTile(
                    leading:
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    title: Text('注意事项'),
                    subtitle: Text('切换数据源前请确保已备份重要数据，以防数据丢失。不同数据源间的数据不会自动同步。'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建SQLite设置部分
  Widget _buildSqliteSettings() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SQLite数据库文件',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.dividerColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _sqliteDbPath.isEmpty ? '使用默认数据库文件' : _sqliteDbPath,
                    style: TextStyle(
                      color: _sqliteDbPath.isEmpty
                          ? Colors.grey
                          : Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _selectSqliteDatabase,
                icon: const Icon(Icons.folder_open),
                label: const Text('选择文件'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '如不选择，将使用默认位置的数据库文件',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ],
      ),
    );
  }

  // 构建设置项
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  value,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建分区标题
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  // 构建单选按钮
  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required Function(String?) onChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        unselectedWidgetColor: AppTheme.secondaryText,
      ),
      child: RadioListTile<String>(
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(subtitle),
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        activeColor: AppTheme.primaryColor,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

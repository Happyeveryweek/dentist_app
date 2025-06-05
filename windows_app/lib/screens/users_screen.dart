import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import '../providers/database_provider.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  final List<String> _availableRoles = [
    'admin',
    'doctor',
    'assistant',
    'receptionist'
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  // 加载所有用户
  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      final users = await dbProvider.getAllUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '加载用户数据时出错: $e';
      });
    }
  }

  // 加密密码
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  // 显示添加/编辑用户对话框
  Future<void> _showAddEditUserDialog([User? user]) async {
    final isEditing = user != null;
    final titleText = isEditing ? '编辑用户' : '添加用户';
    final buttonText = isEditing ? '保存' : '添加';

    final _formKey = GlobalKey<FormState>();
    final _usernameController =
        TextEditingController(text: isEditing ? user.username : '');
    final _passwordController = TextEditingController();
    final _emailController =
        TextEditingController(text: isEditing ? user.email ?? '' : '');
    final _doctorNameController = TextEditingController(
        text: isEditing && user.role == 'doctor' ? user.doctor ?? '' : '');
    String _selectedRole = isEditing ? user.role : 'assistant';
    String? _emailErrorMessage;

    // 创建一个StatefulBuilder以在对话框内更新状态
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(builder: (context, setState) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final isPurpleTheme = Theme.of(context).scaffoldBackgroundColor ==
            AppTheme.purpleBackground;

        final accentColor = isPurpleTheme
            ? AppTheme.purpleColor
            : isDarkMode
                ? AppTheme.primaryColor
                : AppTheme.primaryColor;

        final textColor = isPurpleTheme
            ? AppTheme.purplePrimaryText
            : isDarkMode
                ? AppTheme.darkPrimaryText
                : null;

        return AlertDialog(
          title: Text(titleText, style: TextStyle(color: textColor)),
          content: Container(
            width: 400,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      hintText: '请输入用户名',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      return null;
                    },
                    readOnly: isEditing, // 编辑模式下不允许修改用户名
                  ),
                  const SizedBox(height: 16),
                  if (!isEditing)
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密码',
                        hintText: '请输入密码',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入密码';
                        }
                        if (value.length < 6) {
                          return '密码长度不能少于6位';
                        }
                        return null;
                      },
                    ),
                  if (!isEditing) const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: '邮箱',
                      hintText: '请输入邮箱地址',
                      errorText: _emailErrorMessage,
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        if (!emailRegex.hasMatch(value)) {
                          return '请输入有效的邮箱地址';
                        }
                      }
                      return _emailErrorMessage;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: '角色',
                    ),
                    items: _availableRoles.map((role) {
                      String displayText = '';
                      switch (role) {
                        case 'admin':
                          displayText = '管理员';
                          break;
                        case 'doctor':
                          displayText = '医生';
                          break;
                        case 'assistant':
                          displayText = '助理';
                          break;
                        case 'receptionist':
                          displayText = '前台';
                          break;
                        default:
                          displayText = role;
                      }
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(displayText),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedRole = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // 添加医生姓名字段，仅当角色是医生时显示
                  if (_selectedRole == 'doctor')
                    TextFormField(
                      controller: _doctorNameController,
                      decoration: const InputDecoration(
                        labelText: '医生姓名',
                        hintText: '请输入医生姓名',
                      ),
                      validator: (value) {
                        if (_selectedRole == 'doctor' &&
                            (value == null || value.isEmpty)) {
                          return '请输入医生姓名';
                        }
                        return null;
                      },
                    ),
                  if (_selectedRole == 'doctor') const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                // 先清除之前的错误
                setState(() {
                  _emailErrorMessage = null;
                });

                if (_formKey.currentState!.validate()) {
                  try {
                    final dbProvider =
                        Provider.of<DatabaseProvider>(context, listen: false);

                    // 添加前检查邮箱是否已存在
                    if (_emailController.text.isNotEmpty) {
                      bool isEmailExists = await _checkEmailExists(dbProvider,
                          _emailController.text, isEditing ? user!.id : null);

                      if (isEmailExists) {
                        setState(() {
                          _emailErrorMessage = '该邮箱已被使用';
                        });
                        return; // 如果邮箱已存在，不继续处理
                      }
                    }

                    if (isEditing) {
                      // 更新用户 - 使用新的接口
                      await dbProvider.updateUser(
                        user.id!,
                        _usernameController.text,
                        null, // 不更新密码
                        _selectedRole,
                        email: _emailController.text.isNotEmpty
                            ? _emailController.text
                            : null,
                        doctor: _selectedRole == 'doctor' &&
                                _doctorNameController.text.isNotEmpty
                            ? _doctorNameController.text
                            : null,
                      );
                    } else {
                      // 添加新用户 - 使用新的接口
                      await dbProvider.addUser(
                        _usernameController.text,
                        _passwordController.text,
                        _selectedRole,
                        email: _emailController.text.isNotEmpty
                            ? _emailController.text
                            : null,
                        doctor: _selectedRole == 'doctor' &&
                                _doctorNameController.text.isNotEmpty
                            ? _doctorNameController.text
                            : null,
                      );
                    }

                    if (!mounted) return;
                    Navigator.of(context).pop();
                    _loadUsers(); // 重新加载用户列表

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? '用户信息已更新' : '用户添加成功'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isEditing ? '更新用户失败: $e' : '添加用户失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
              ),
              child: Text(buttonText),
            ),
          ],
        );
      }),
    );
  }

  // 检查邮箱是否已存在
  Future<bool> _checkEmailExists(
      DatabaseProvider dbProvider, String email, int? excludeUserId) async {
    try {
      // 获取所有用户
      final users = await dbProvider.getAllUsers();

      // 检查是否有相同邮箱的用户（排除当前编辑的用户）
      for (var user in users) {
        if (user.email == email && user.id != excludeUserId) {
          return true; // 邮箱已存在
        }
      }

      return false; // 邮箱不存在
    } catch (e) {
      print('检查邮箱是否存在时出错: $e');
      return false; // 出错时默认返回不存在
    }
  }

  // 显示重置密码对话框
  Future<void> _showResetPasswordDialog(User user) async {
    final _formKey = GlobalKey<FormState>();
    final _passwordController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final isPurpleTheme = Theme.of(context).scaffoldBackgroundColor ==
            AppTheme.purpleBackground;

        final accentColor = isPurpleTheme
            ? AppTheme.purpleColor
            : isDarkMode
                ? AppTheme.primaryColor
                : AppTheme.primaryColor;

        final textColor = isPurpleTheme
            ? AppTheme.purplePrimaryText
            : isDarkMode
                ? AppTheme.darkPrimaryText
                : null;

        return AlertDialog(
          title:
              Text('修改${user.username}的密码', style: TextStyle(color: textColor)),
          content: Form(
            key: _formKey,
            child: TextFormField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: '新密码',
                hintText: '请输入新密码',
              ),
              obscureText: true,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return '请输入新密码';
                }
                if (value.length < 6) {
                  return '密码长度不能少于6位';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: accentColor,
              ),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    final dbProvider =
                        Provider.of<DatabaseProvider>(context, listen: false);

                    // 使用专用的密码更新方法，而不是通用的updateUser方法
                    await dbProvider.updateUserPassword(
                      user.id!,
                      _passwordController.text,
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('密码修改成功'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('密码修改失败: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
              ),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  // 删除用户确认对话框
  Future<void> _showDeleteConfirmationDialog(User user) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('您确定要删除用户"${user.username}"吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final dbProvider =
                    Provider.of<DatabaseProvider>(context, listen: false);
                await dbProvider.deleteUser(user.id!);

                if (!mounted) return;
                Navigator.of(context).pop();
                _loadUsers(); // 重新加载用户列表

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('用户已删除'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('删除用户失败: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('用户管理'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
            tooltip: '刷新',
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddEditUserDialog(),
            tooltip: '添加用户',
          ),
        ],
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadUsers,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              color: Colors.grey,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              '没有用户数据',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showAddEditUserDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
              ),
              child: const Text('添加用户'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '系统用户',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              AppTheme.primaryColor.withOpacity(0.2),
                          child: Icon(
                            user.role == 'admin'
                                ? Icons.admin_panel_settings
                                : user.role == 'doctor'
                                    ? Icons.local_hospital
                                    : user.role == 'receptionist'
                                        ? Icons.person_outline
                                        : Icons.person,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                        title: Text(user.username),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('角色: ${user.roleDisplay}'),
                            if (user.email != null && user.email!.isNotEmpty)
                              Text('邮箱: ${user.email}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.lock),
                              tooltip: '修改密码',
                              onPressed: () => _showResetPasswordDialog(user),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              tooltip: '编辑',
                              onPressed: () => _showAddEditUserDialog(user),
                            ),
                            if (user.role !=
                                'admin') // 使用直接比较role而不是user.isAdmin
                              IconButton(
                                icon: const Icon(Icons.delete),
                                tooltip: '删除',
                                onPressed: () =>
                                    _showDeleteConfirmationDialog(user),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

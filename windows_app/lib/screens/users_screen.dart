import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../widgets/dental_icons.dart';
import '../widgets/success_toast.dart';
import '../utils/image_compressor.dart';

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
    _loadUsers(forceRefresh: true);
  }

  // 加载所有用户
  Future<void> _loadUsers({bool forceRefresh = true}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      
      // 使用强制刷新参数，确保获取最新数据
      final users = await userProvider.getAllUsers(forceRefresh: forceRefresh);
      setState(() {
        _users = users;
        _isLoading = false;
      });
      
      print('用户数据加载完成: ${users.length} 个用户 (强制刷新: $forceRefresh)');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '加载用户数据时出错: $e';
      });
      print('加载用户数据失败: $e');
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
        text: isEditing ? user.doctor ?? '' : '');
    String _selectedRole = isEditing ? user.role : 'assistant';
    String? _emailErrorMessage;
    List<int>? _uploadedImageData = isEditing ? user.imageData : null; // 上传的头像数据
    String? _avatarFileName = isEditing ? user.avatar : null; // 头像文件名
    
    // 权限配置状态
    Map<String, bool> _modulePermissions = isEditing && user != null 
        ? user.permissionMap 
        : {
            'dashboard': true,
            'patients': false,
            'appointments': false,
            'financial': false,
            'materials': false,
            'purchase': false,
            'medical_records': false,
          };
    
    // 展开状态
    bool _isPermissionExpanded = false;

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
          title: Row(
            children: [
              Icon(
                isEditing ? Icons.edit : Icons.person_add,
                color: accentColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(titleText, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Container(
            width: 450,
            constraints: const BoxConstraints(maxHeight: 600),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildModernFormField(
                      controller: _usernameController,
                      label: '用户名',
                      hint: '请输入用户名',
                      icon: Icons.person,
                      readOnly: isEditing,
                    ),
                    const SizedBox(height: 20),
                    if (!isEditing)
                      _buildModernFormField(
                        controller: _passwordController,
                        label: '密码',
                        hint: '请输入密码',
                        icon: Icons.lock,
                        isPassword: true,
                      ),
                    if (!isEditing) const SizedBox(height: 20),
                    _buildModernFormField(
                      controller: _emailController,
                      label: '邮箱',
                      hint: '请输入邮箱地址',
                      icon: Icons.email,
                      keyboardType: TextInputType.emailAddress,
                      errorText: _emailErrorMessage,
                    ),
                    const SizedBox(height: 20),
                    _buildModernRoleSelector(
                      selectedRole: _selectedRole,
                      onRoleChanged: (value) {
                        setState(() {
                          _selectedRole = value!;
                          // 如果切换到管理员角色，清空权限配置（管理员拥有所有权限）
                          // 如果从管理员切换到其他角色，重置为默认权限
                          if (value == 'admin') {
                            _modulePermissions.clear();
                          } else if (_selectedRole == 'admin' && value != 'admin') {
                            _modulePermissions = {
                              'dashboard': true,
                              'patients': false,
                              'appointments': false,
                              'financial': false,
                              'materials': false,
                              'purchase': false,
                              'medical_records': false,
                            };
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildModernFormField(
                      controller: _doctorNameController,
                      label: '医生姓名',
                      hint: '请输入医生姓名（选填）',
                      icon: Icons.medical_services,
                    ),
                    const SizedBox(height: 20),
                    // 头像上传
                    _buildAvatarUploadSection(
                      selectedAvatar: null,
                      uploadedImageData: _uploadedImageData,
                      isExpanded: false,
                      onToggleExpanded: () {},
                      onAvatarSelected: (avatarId) {},
                      onImageUploaded: (imageData, fileName) {
                        setState(() {
                          _uploadedImageData = imageData;
                          _avatarFileName = fileName;
                        });
                      },
                      onImageRemoved: () {
                        setState(() {
                          // 使用空列表表示删除图片
                          _uploadedImageData = [];
                          _avatarFileName = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    
                    // 可折叠的权限配置面板（仅对非管理员用户显示）
                    if (_selectedRole != 'admin') ...[
                      _buildCollapsiblePermissionPanel(
                        permissions: _modulePermissions,
                        isExpanded: _isPermissionExpanded,
                        onToggleExpanded: () {
                          setState(() {
                            _isPermissionExpanded = !_isPermissionExpanded;
                          });
                        },
                        onPermissionChanged: (module, hasPermission) {
                          setState(() {
                            _modulePermissions[module] = hasPermission;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            DentalGradientButton(
              text: '取消',
              onPressed: () => Navigator.of(context).pop(),
              isOutlined: true,
            ),
            const SizedBox(width: 12),
            DentalGradientButton(
              text: buttonText,
              onPressed: () async {
                // 先清除之前的错误
                setState(() {
                  _emailErrorMessage = null;
                });

                if (_formKey.currentState!.validate()) {
                  try {
                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);

                    // 添加前检查邮箱是否已存在
                    if (_emailController.text.isNotEmpty) {
                      bool isEmailExists = await _checkEmailExists(userProvider,
                          _emailController.text, isEditing ? user!.id : null);

                      if (isEmailExists) {
                        setState(() {
                          _emailErrorMessage = '该邮箱已被使用';
                        });
                        return; // 如果邮箱已存在，不继续处理
                      }
                    }

                    // 准备权限配置JSON字符串
                    String? permissionsJson;
                    if (_selectedRole != 'admin' && _modulePermissions.isNotEmpty) {
                      // 验证至少选择一个模块（除了仪表盘）
                      bool hasAnyPermission = _modulePermissions.entries
                          .where((entry) => entry.key != 'dashboard')
                          .any((entry) => entry.value == true);
                      
                      if (!hasAnyPermission) {
                        SuccessToastManager.showError(
                          context,
                          message: '请至少选择一个功能模块权限',
                        );
                        return;
                      }
                      
                      permissionsJson = jsonEncode(_modulePermissions);
                    }

                    if (isEditing) {
                      // 更新用户 - 使用新的接口
                      await userProvider.updateUser(
                        user.id!,
                        _usernameController.text,
                        null, // 不更新密码
                        _selectedRole,
                        email: _emailController.text.isNotEmpty
                            ? _emailController.text
                            : null,
                        doctor: _doctorNameController.text.isNotEmpty
                            ? _doctorNameController.text
                            : null,
                        avatar: _avatarFileName, // 保存图片文件名
                        modulePermissions: permissionsJson, // 权限配置
                        imageData: _uploadedImageData, // 上传的头像图片数据
                      );
                    } else {
                      // 添加新用户 - 使用新的接口
                      await userProvider.addUser(
                        _usernameController.text,
                        _passwordController.text,
                        _selectedRole,
                        email: _emailController.text.isNotEmpty
                            ? _emailController.text
                            : null,
                        doctor: _doctorNameController.text.isNotEmpty
                            ? _doctorNameController.text
                            : null,
                        avatar: _avatarFileName, // 保存图片文件名
                        modulePermissions: permissionsJson, // 权限配置
                        imageData: _uploadedImageData, // 上传的头像图片数据
                      );
                    }

                    if (!mounted) return;
                    Navigator.of(context).pop();
                    
                    // 强制刷新用户列表
                    await _loadUsers(forceRefresh: true);

                    // 使用公用成功提示组件
                    SuccessToastManager.show(
                      context, 
                      message: isEditing ? '用户信息已更新' : '用户添加成功'
                    );
                  } catch (e) {
                    if (!mounted) return;
                    SuccessToastManager.showError(
                      context,
                      message: isEditing ? '更新用户失败: $e' : '添加用户失败: $e',
                    );
                  }
                }
              },
            ),
          ],
        );
      }),
    );
  }

  // 构建现代化表单字段
  Widget _buildModernFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
    String? errorText,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: AppTheme.primaryColor),
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
            borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppTheme.errorColor),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorText: errorText,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return '请输入$label';
          }
          if (isPassword && value.length < 6) {
            return '密码长度不能少于6位';
          }
          if (keyboardType == TextInputType.emailAddress && value.isNotEmpty) {
            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
            if (!emailRegex.hasMatch(value)) {
              return '请输入有效的邮箱地址';
            }
          }
          return null;
        },
      ),
    );
  }

  // 构建现代化角色选择器
  Widget _buildModernRoleSelector({
    required String selectedRole,
    required Function(String?) onRoleChanged,
  }) {
    final roleInfo = {
      'admin': {'name': '管理员', 'icon': Icons.admin_panel_settings, 'color': AppTheme.errorColor},
      'doctor': {'name': '医生', 'icon': Icons.medical_services, 'color': AppTheme.successColor},
      'assistant': {'name': '助理', 'icon': Icons.assistant, 'color': AppTheme.warningColor},
      'receptionist': {'name': '前台', 'icon': Icons.person_outline, 'color': AppTheme.infoColor},
    };

    final currentRole = roleInfo[selectedRole];
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedRole,
            isExpanded: true,
            icon: Icon(Icons.keyboard_arrow_down, color: AppTheme.primaryColor),
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(12),
            elevation: 8,
            onChanged: onRoleChanged,
            selectedItemBuilder: (context) {
              return _availableRoles.map<Widget>((role) {
                final info = roleInfo[role]!;
                return Row(
                  children: [
                    Icon(Icons.work, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '角色',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          Text(
                            info['name'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList();
            },
            items: _availableRoles.map((role) {
              final info = roleInfo[role]!;
              return DropdownMenuItem<String>(
                value: role,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  decoration: BoxDecoration(
                    color: selectedRole == role 
                        ? (info['color'] as Color).withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (info['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          info['icon'] as IconData,
                          color: info['color'] as Color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        info['name'] as String,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: selectedRole == role ? FontWeight.bold : FontWeight.w500,
                          color: selectedRole == role 
                              ? (info['color'] as Color)
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

      // 检查邮箱是否已存在
    Future<bool> _checkEmailExists(
        UserProvider userProvider, String email, int? excludeUserId) async {
      try {
        // 获取所有用户
        final users = await userProvider.getAllUsers();

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
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Text('修改${user.username}的密码', 
                style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: _formKey,
            child: _buildModernFormField(
              controller: _passwordController,
              label: '新密码',
              hint: '请输入新密码',
              icon: Icons.lock,
              isPassword: true,
            ),
          ),
          actions: [
            DentalGradientButton(
              text: '取消',
              onPressed: () => Navigator.of(context).pop(),
              isOutlined: true,
            ),
            const SizedBox(width: 12),
            DentalGradientButton(
              text: '保存',
              onPressed: () async {
                if (_formKey.currentState!.validate()) {
                  try {
                    final userProvider =
                        Provider.of<UserProvider>(context, listen: false);

                    // 使用专用的密码更新方法，而不是通用的updateUser方法
                    await userProvider.updateUserPassword(
                      user.id!,
                      _passwordController.text,
                    );

                    if (!mounted) return;
                    Navigator.of(context).pop();

                    SuccessToastManager.show(
                      context,
                      message: '密码修改成功',
                    );
                  } catch (e) {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    SuccessToastManager.showError(
                      context,
                      message: '密码修改失败: $e',
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 删除用户确认对话框
  Future<void> _showDeleteConfirmationDialog(User user) async {
    final confirmed = await DeleteConfirmDialogManager.showUserDelete(
      context,
      username: user.username,
    );

    if (confirmed) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.deleteUser(user.id!);

        if (!mounted) return;
        
        // 强制刷新用户列表
        await _loadUsers(forceRefresh: true);

        // 使用公用删除成功提示组件
        DeleteSuccessToastManager.show(context, message: '用户已删除');
      } catch (e) {
        if (!mounted) return;
        SuccessToastManager.showError(
          context,
          message: '删除用户失败: $e',
        );
      }
    }
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
              child: Icon(
                Icons.people_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '用户管理',
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
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: DentalColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.info.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: DentalColors.info,
              ),
              onPressed: () async {
                // 强制刷新数据
                await _loadUsers(forceRefresh: true);
                if (!mounted) return;
                SuccessToastManager.show(context, message: '刷新数据成功');
              },
              tooltip: '刷新数据',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.person_add_rounded, color: Colors.white),
              onPressed: () => _showAddEditUserDialog(),
              tooltip: '添加用户',
            ),
          ),
        ],
      ),
      body: _buildUserList(),
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '加载中...',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.errorColor,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                '加载失败',
                style: TextStyle(
                  color: AppTheme.errorColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: TextStyle(color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              DentalGradientButton(
                text: '重试',
                icon: Icons.refresh,
                onPressed: () => _loadUsers(forceRefresh: true),
              ),
            ],
          ),
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                color: Colors.grey.shade400,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                '暂无用户数据',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '点击下方按钮添加第一个用户',
                style: TextStyle(color: Colors.grey.shade500),
              ),
              const SizedBox(height: 24),
              DentalGradientButton(
                text: '添加用户',
                icon: Icons.person_add,
                onPressed: () => _showAddEditUserDialog(),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 页面标题和统计信息
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
                  Icons.people,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '系统用户管理',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '共 ${_users.length} 个用户账户',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${_users.where((u) => u.role == 'admin').length} 管理员',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 用户列表
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 3.5, // 恢复原来的紧凑布局
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建头像上传区域
  Widget _buildAvatarUploadSection({
    required String? selectedAvatar,
    required List<int>? uploadedImageData,
    required bool isExpanded,
    required VoidCallback onToggleExpanded,
    required Function(String) onAvatarSelected,
    required Function(List<int>, String) onImageUploaded,
    required VoidCallback onImageRemoved,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_circle, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 12),
              const Text(
                '头像设置',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 头像预览
          if (uploadedImageData != null && uploadedImageData.isNotEmpty) ...[
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryColor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    Uint8List.fromList(uploadedImageData),
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        child: Icon(
                          Icons.error_outline,
                          size: 40,
                          color: Colors.grey.shade400,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // 上传按钮
          Row(
            children: [
              Expanded(
                child: DentalGradientButton(
                  text: (uploadedImageData != null && uploadedImageData.isNotEmpty) 
                      ? '更换头像' 
                      : '上传头像',
                  icon: Icons.upload_file,
                  onPressed: () async {
                    await _pickAndUploadImage(onImageUploaded);
                  },
                ),
              ),
              if (uploadedImageData != null && uploadedImageData.isNotEmpty) ...[
                const SizedBox(width: 12),
                DentalGradientButton(
                  text: '删除',
                  icon: Icons.delete,
                  onPressed: onImageRemoved,
                  gradient: AppTheme.dangerGradient,
                ),
              ],
            ],
          ),
          
          if (uploadedImageData == null || uploadedImageData.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '未上传头像时将使用默认头像',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ],
      ),
    );
  }



  // 选择并上传图片
  Future<void> _pickAndUploadImage(
    Function(List<int>, String) onImageUploaded,
  ) async {
    try {
      print('开始选择图片...');
      
      // 使用file_picker选择图片
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // 确保获取字节数据
      );

      print('文件选择结果: ${result != null ? "有文件" : "无文件"}');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        print('选中文件: ${file.name}, 路径: ${file.path}');
        
        // 获取字节数据
        Uint8List? bytes;
        
        // 优先使用bytes属性
        if (file.bytes != null) {
          bytes = file.bytes!;
          print('从bytes属性获取数据: ${bytes.length} 字节');
        } 
        // 如果bytes为空，尝试从路径读取
        else if (file.path != null) {
          try {
            final imageFile = File(file.path!);
            bytes = await imageFile.readAsBytes();
            print('从文件路径读取数据: ${bytes.length} 字节');
          } catch (e) {
            print('从文件路径读取失败: $e');
          }
        }
        
        if (bytes == null) {
          print('无法获取图片数据');
          if (!mounted) return;
          SuccessToastManager.showError(
            context,
            message: '无法读取图片数据，请重试',
          );
          return;
        }
        
        print('开始验证图片格式...');
        // 验证图片格式
        if (!ImageCompressor.isValidImageFormat(bytes)) {
          print('图片格式验证失败');
          if (!mounted) return;
          SuccessToastManager.showError(
            context,
            message: '不支持的图片格式，请选择JPG、PNG等常见格式',
          );
          return;
        }
        
        print('图片格式验证通过');
        
        // 获取原始图片信息
        final dimensions = ImageCompressor.getImageDimensions(bytes);
        if (dimensions != null) {
          print('原始图片尺寸: ${dimensions['width']}x${dimensions['height']}');
        }
        
        print('开始压缩图片...');
        // 压缩图片
        final compressedBytes = await ImageCompressor.compressAvatar(bytes);
        
        if (compressedBytes == null) {
          print('图片压缩失败');
          if (!mounted) return;
          SuccessToastManager.showError(
            context,
            message: '图片处理失败，请重试',
          );
          return;
        }
        
        print('图片压缩成功: ${compressedBytes.length} 字节');
        
        // 检查压缩后的大小
        if (compressedBytes.length > 500 * 1024) { // 超过500KB
          print('压缩后图片仍然过大: ${compressedBytes.length} 字节');
          if (!mounted) return;
          SuccessToastManager.showError(
            context,
            message: '图片过大，请选择较小的图片',
          );
          return;
        }
        
        print('调用回调函数更新图片数据...');
        // 回调上传的图片数据和文件名
        final fileName = file.name;
        print('图片文件名: $fileName');
        onImageUploaded(compressedBytes, fileName);
        
        print('头像上传完成');
        if (!mounted) return;
        SuccessToastManager.show(
          context,
          message: '头像上传成功',
        );
      } else {
        print('用户取消了文件选择');
      }
    } catch (e, stackTrace) {
      print('选择图片失败: $e');
      print('堆栈跟踪: $stackTrace');
      if (!mounted) return;
      SuccessToastManager.showError(
        context,
        message: '选择图片失败: $e',
      );
    }
  }

  // 构建可折叠的权限配置面板
  Widget _buildCollapsiblePermissionPanel({
    required Map<String, bool> permissions,
    required bool isExpanded,
    required VoidCallback onToggleExpanded,
    required Function(String, bool) onPermissionChanged,
  }) {
    // 计算已选择的权限
    final selectedPermissions = permissions.entries
        .where((entry) => entry.value == true && entry.key != 'dashboard')
        .map((entry) => _getModuleName(entry.key))
        .toList();
    
    final permissionSummary = selectedPermissions.isEmpty 
        ? '未选择任何模块' 
        : selectedPermissions.join('、');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        color: Colors.white,
      ),
      child: Column(
        children: [
          // 头部 - 可点击展开/折叠
          InkWell(
            onTap: onToggleExpanded,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.security, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    '模块权限配置',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      permissionSummary,
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedPermissions.isEmpty 
                            ? Colors.grey.shade500 
                            : AppTheme.primaryColor,
                        fontWeight: selectedPermissions.isEmpty 
                            ? FontWeight.normal 
                            : FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          // 展开的内容
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16),
              child: _buildPermissionConfigPanel(
                permissions: permissions,
                onPermissionChanged: onPermissionChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // 获取模块中文名称
  String _getModuleName(String moduleKey) {
    final moduleNames = {
      'patients': '患者管理',
      'appointments': '预约管理',
      'financial': '财务管理',
      'materials': '材料管理',
      'purchase': '采购管理',
      'medical_records': '病历管理',
    };
    return moduleNames[moduleKey] ?? moduleKey;
  }

  // 构建权限配置面板
  Widget _buildPermissionConfigPanel({
    required Map<String, bool> permissions,
    required Function(String, bool) onPermissionChanged,
  }) {
    final moduleInfo = {
      'patients': {'name': '患者管理', 'icon': Icons.people, 'color': AppTheme.successColor},
      'appointments': {'name': '预约管理', 'icon': Icons.calendar_today, 'color': AppTheme.infoColor},
      'financial': {'name': '财务管理', 'icon': Icons.account_balance_wallet, 'color': AppTheme.warningColor},
      'materials': {'name': '材料管理', 'icon': Icons.inventory, 'color': AppTheme.primaryColor},
      'purchase': {'name': '采购管理', 'icon': Icons.shopping_cart, 'color': AppTheme.errorColor},
      'medical_records': {'name': '病历管理', 'icon': Icons.medical_services, 'color': Colors.teal},
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择用户可以访问的功能模块（仪表盘默认对所有用户可见）',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 12),
        
        // 权限复选框列表
        ...moduleInfo.entries.map((entry) {
          final module = entry.key;
          final info = entry.value;
          final hasPermission = permissions[module] ?? false;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: hasPermission 
                  ? (info['color'] as Color).withOpacity(0.05)
                  : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasPermission 
                    ? (info['color'] as Color).withOpacity(0.3)
                    : Colors.grey.shade200,
              ),
            ),
            child: CheckboxListTile(
              value: hasPermission,
              onChanged: (value) => onPermissionChanged(module, value ?? false),
              title: Row(
                children: [
                  Icon(
                    info['icon'] as IconData,
                    color: hasPermission 
                        ? (info['color'] as Color)
                        : Colors.grey.shade500,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    info['name'] as String,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasPermission ? FontWeight.w600 : FontWeight.normal,
                      color: hasPermission 
                          ? (info['color'] as Color)
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              activeColor: info['color'] as Color,
              checkColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              dense: true,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildUserCard(User user) {
    final roleColors = {
      'admin': AppTheme.dangerGradient,
      'doctor': AppTheme.successGradient,
      'assistant': AppTheme.warningGradient,
      'receptionist': AppTheme.infoGradient,
    };

    final roleIcons = {
      'admin': Icons.admin_panel_settings,
      'doctor': Icons.medical_services,
      'assistant': Icons.assistant,
      'receptionist': Icons.person_outline,
    };

    final roleNames = {
      'admin': '管理员',
      'doctor': '医生',
      'assistant': '助理',
      'receptionist': '前台',
    };

    return Container(
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
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 左侧：用户头像和信息
            Expanded(
              child: Row(
                children: [
                  // 用户头像 - 直接复制编辑预览的结构
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryColor, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: user.imageData != null && user.imageData!.isNotEmpty
                          ? Image.memory(
                              Uint8List.fromList(user.imageData!),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade200,
                                  child: Icon(
                                    Icons.error_outline,
                                    size: 20,
                                    color: Colors.grey.shade400,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade100,
                              child: user.role == 'doctor' || user.role == 'admin'
                                  ? Image.asset(
                                      'assets/icons/doctor.png',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.asset(
                                      'assets/icons/nurse.png',
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // 用户信息
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              user.username,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: roleColors[user.role] ?? AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                user.roleDisplay,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (user.email != null && user.email!.isNotEmpty) ...[
                              Icon(Icons.email, size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user.email!,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        
                        // 显示权限信息（仅对非管理员用户）
                        if (user.role != 'admin') ...[
                          const SizedBox(height: 4),
                          _buildPermissionTags(user),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 右侧：操作按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.lock, color: AppTheme.primaryColor, size: 16),
                    tooltip: '修改密码',
                    onPressed: () => _showResetPasswordDialog(user),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(Icons.edit, color: AppTheme.successColor, size: 16),
                    tooltip: '编辑',
                    onPressed: () => _showAddEditUserDialog(user),
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ),
                if (user.role != 'admin') ...[
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.infoColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.security, color: AppTheme.infoColor, size: 16),
                      tooltip: '权限配置',
                      onPressed: () => _showPermissionPreviewDialog(user),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ],
                if (user.role != 'admin') ...[
                  const SizedBox(width: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.delete, color: AppTheme.errorColor, size: 16),
                      tooltip: '删除',
                      onPressed: () => _showDeleteConfirmationDialog(user),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 构建权限标签
  Widget _buildPermissionTags(User user) {
    final moduleInfo = {
      'patients': {'name': '患者', 'color': AppTheme.successColor},
      'appointments': {'name': '预约', 'color': AppTheme.infoColor},
      'financial': {'name': '财务', 'color': AppTheme.warningColor},
      'materials': {'name': '材料', 'color': AppTheme.primaryColor},
      'purchase': {'name': '采购', 'color': AppTheme.errorColor},
      'medical_records': {'name': '病历', 'color': Colors.teal},
    };

    final allowedModules = user.allowedModules
        .where((module) => module != 'dashboard') // 排除仪表盘
        .toList();

    if (allowedModules.isEmpty) {
      return Row(
        children: [
          Icon(Icons.info_outline, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text(
            '仅可访问仪表盘',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: allowedModules.take(3).map((module) {
        final info = moduleInfo[module];
        if (info == null) return const SizedBox.shrink();
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: (info['color'] as Color).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: (info['color'] as Color).withOpacity(0.3),
              width: 0.5,
            ),
          ),
          child: Text(
            info['name'] as String,
            style: TextStyle(
              color: info['color'] as Color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }).toList()
        ..addAll(allowedModules.length > 3 ? [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${allowedModules.length - 3}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ] : []),
    );
  }

  // 显示权限预览对话框
  Future<void> _showPermissionPreviewDialog(User user) async {
    final moduleInfo = {
      'dashboard': {'name': '仪表盘', 'icon': Icons.dashboard, 'color': AppTheme.primaryColor},
      'patients': {'name': '患者管理', 'icon': Icons.people, 'color': AppTheme.successColor},
      'appointments': {'name': '预约管理', 'icon': Icons.calendar_today, 'color': AppTheme.infoColor},
      'financial': {'name': '财务管理', 'icon': Icons.account_balance_wallet, 'color': AppTheme.warningColor},
      'materials': {'name': '材料管理', 'icon': Icons.inventory, 'color': AppTheme.primaryColor},
      'purchase': {'name': '采购管理', 'icon': Icons.shopping_cart, 'color': AppTheme.errorColor},
      'medical_records': {'name': '病历管理', 'icon': Icons.medical_services, 'color': Colors.teal},
    };

    await showDialog(
      context: context,
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
          title: Row(
            children: [
              Icon(Icons.security, color: accentColor, size: 24),
              const SizedBox(width: 12),
              Text(
                '${user.username} 的权限配置',
                style: TextStyle(
                  color: textColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Container(
            width: 400,
            constraints: const BoxConstraints(maxHeight: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前用户可以访问以下功能模块：',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                
                // 权限列表
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: moduleInfo.entries.map((entry) {
                      final module = entry.key;
                      final info = entry.value;
                      final hasPermission = user.hasModulePermission(module);
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: hasPermission 
                              ? (info['color'] as Color).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: hasPermission 
                                ? (info['color'] as Color).withOpacity(0.3)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              info['icon'] as IconData,
                              color: hasPermission 
                                  ? (info['color'] as Color)
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                info['name'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: hasPermission ? FontWeight.w600 : FontWeight.normal,
                                  color: hasPermission 
                                      ? (info['color'] as Color)
                                      : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Icon(
                              hasPermission ? Icons.check_circle : Icons.cancel,
                              color: hasPermission 
                                  ? AppTheme.successColor
                                  : Colors.grey.shade400,
                              size: 20,
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            DentalGradientButton(
              text: '编辑权限',
              icon: Icons.edit,
              onPressed: () {
                Navigator.of(context).pop();
                _showAddEditUserDialog(user);
              },
            ),
            const SizedBox(width: 12),
            DentalGradientButton(
              text: '关闭',
              onPressed: () => Navigator.of(context).pop(),
              isOutlined: true,
            ),
          ],
        );
      },
    );
  }
}

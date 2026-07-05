import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';

import '../../../models/user.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/success_toast.dart';
import '../services/user_validation_service.dart';
import '../services/user_avatar_service.dart';
import 'user_form_field.dart';
import 'role_selector.dart';
import 'permission_panel.dart';
import 'avatar_upload_section.dart';

/// 用户表单对话框
/// 用于添加和编辑用户信息
class UserFormDialog extends StatefulWidget {
  final User? user;
  final List<String> availableRoles;
  const UserFormDialog({
    Key? key,
    this.user,
    required this.availableRoles,
  }) : super(key: key);

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  late final bool _isEditing;
  late final String _titleText;
  late final String _buttonText;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _emailController;
  late final TextEditingController _doctorNameController;

  late String _selectedRole;
  String? _usernameErrorMessage;
  String? _emailErrorMessage;
  List<int>? _uploadedImageData;
  String? _avatarFileName;
  late Map<String, bool> _modulePermissions;
  bool _isPermissionExpanded = false;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _isEditing = user != null;
    _titleText = _isEditing ? '编辑用户' : '添加用户';
    _buttonText = _isEditing ? '保存' : '添加';

    _usernameController = TextEditingController(
      text: user?.username ?? '',
    );
    _passwordController = TextEditingController();
    _emailController = TextEditingController(
      text: user?.email ?? '',
    );
    _doctorNameController = TextEditingController(
      text: user?.doctor ?? '',
    );
    _selectedRole = user?.role ?? 'assistant';
    _uploadedImageData = user?.imageData;
    _avatarFileName = user?.avatar;
    _modulePermissions = _isEditing && user != null
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
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _doctorNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _usernameErrorMessage = null;
      _emailErrorMessage = null;
    });

    if (_formKey.currentState?.validate() == true) {
      try {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        final editingUser = widget.user;

        if (_usernameController.text.isNotEmpty) {
          bool isUsernameExists =
              await UserValidationService.checkUsernameExists(
            userProvider,
            _usernameController.text,
            editingUser?.id,
          );

          if (isUsernameExists) {
            setState(() {
              _usernameErrorMessage = '该用户名已被使用';
            });
            return;
          }
        }

        // 添加前检查邮箱是否已存在
        if (_emailController.text.isNotEmpty) {
          bool isEmailExists = await UserValidationService.checkEmailExists(
            userProvider,
            _emailController.text,
            editingUser?.id,
          );

          if (isEmailExists) {
            setState(() {
              _emailErrorMessage = '该邮箱已被使用';
            });
            return;
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
            if (!mounted) return;
            AppToastManager.showError(
              context,
              message: '请至少选择一个功能模块权限',
            );
            return;
          }

          permissionsJson = jsonEncode(_modulePermissions);
        }

        if (_isEditing && editingUser != null) {
          // 更新用户
          final userId = editingUser.id;
          if (userId == null) {
            if (!mounted) return;
            AppToastManager.showError(context, message: '用户 ID 为空');
            return;
          }
          await userProvider.updateUser(
            userId,
            _usernameController.text,
            null, // 不更新密码
            _selectedRole,
            email:
                _emailController.text.isNotEmpty ? _emailController.text : null,
            doctor: _doctorNameController.text.isNotEmpty
                ? _doctorNameController.text
                : null,
            avatar: _avatarFileName,
            modulePermissions: permissionsJson,
            imageData: _uploadedImageData,
          );
        } else {
          // 添加新用户
          await userProvider.addUser(
            _usernameController.text,
            _passwordController.text,
            _selectedRole,
            email:
                _emailController.text.isNotEmpty ? _emailController.text : null,
            doctor: _doctorNameController.text.isNotEmpty
                ? _doctorNameController.text
                : null,
            avatar: _avatarFileName,
            modulePermissions: permissionsJson,
            imageData: _uploadedImageData,
          );
        }

        if (!mounted) return;
        Navigator.of(context).pop(true);

        AppToastManager.showSuccess(
          context,
          message: _isEditing ? '用户信息已更新' : '用户添加成功',
        );
      } catch (e) {
        if (!mounted) return;
        AppToastManager.showError(
          context,
          message: _isEditing ? '更新用户失败: $e' : '添加用户失败: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.tokens.primaryAccent;

    const Color? textColor = null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _isEditing ? Icons.edit : Icons.person_add,
            color: accentColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            _titleText,
            style: const TextStyle(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
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
                UserFormField(
                  controller: _usernameController,
                  label: '用户名',
                  hint: '请输入用户名',
                  icon: Icons.person,
                  errorText: _usernameErrorMessage,
                ),
                const SizedBox(height: 20),
                if (!_isEditing)
                  UserFormField(
                    controller: _passwordController,
                    label: '密码',
                    hint: '请输入密码',
                    icon: Icons.lock,
                    isPassword: true,
                  ),
                if (!_isEditing) const SizedBox(height: 20),
                UserFormField(
                  controller: _emailController,
                  label: '邮箱',
                  hint: '请输入邮箱地址',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailErrorMessage,
                ),
                const SizedBox(height: 20),
                RoleSelector(
                  selectedRole: _selectedRole,
                  availableRoles: widget.availableRoles,
                  onRoleChanged: (value) {
                    setState(() {
                      _selectedRole = value ?? _selectedRole;
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
                UserFormField(
                  controller: _doctorNameController,
                  label: '医生姓名',
                  hint: '请输入医生姓名（选填）',
                  icon: Icons.medical_services,
                ),
                const SizedBox(height: 20),
                AvatarUploadSection(
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
                      _uploadedImageData = [];
                      _avatarFileName = null;
                    });
                  },
                  onPickImage: () {
                    UserAvatarService.pickAndUploadImage(
                      context,
                      (imageData, fileName) {
                        setState(() {
                          _uploadedImageData = imageData;
                          _avatarFileName = fileName;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                if (_selectedRole != 'admin') ...[
                  PermissionPanel(
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
          text: _buttonText,
          onPressed: _handleSubmit,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../../../models/user.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/image_compressor.dart';
import '../../../widgets/toast_manager.dart';
import '../../../utils/app_logger.dart';

/// 用户对话框
class UserDialog extends StatefulWidget {
  final User? user; // 如果是编辑模式，传入现有用户

  const UserDialog({super.key, this.user});

  @override
  State<UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _doctorController = TextEditingController();

  String _selectedRole = 'user';
  bool _isLoading = false;
  bool _isEditMode = false;

  // 头像相关
  List<int>? _uploadedImageData;
  String? _avatarFileName;

  final List<String> _roles = ['user', 'doctor', 'admin'];

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _doctorController.dispose();
    super.dispose();
  }

  /// 初始化表单
  void _initializeForm() {
    if (widget.user != null) {
      // 编辑模式
      _isEditMode = true;
      _usernameController.text = widget.user!.username;
      _emailController.text = widget.user!.email ?? '';

      // 确保角色值在有效范围内
      final userRole = widget.user!.role;
      if (_roles.contains(userRole)) {
        _selectedRole = userRole;
      } else {
        // 如果角色不在预定义列表中，使用默认值并记录日志
        AppLogger.info('警告：用户角色 "$userRole" 不在预定义列表中，使用默认值 "user"');
        _selectedRole = 'user';
      }

      _doctorController.text = widget.user!.doctor ?? '';

      // 编辑模式下密码字段可以为空
      _passwordController.text = '';
      _confirmPasswordController.text = '';

      // 加载现有的头像数据
      if (widget.user!.imageData != null &&
          widget.user!.imageData!.isNotEmpty) {
        _uploadedImageData = widget.user!.imageData;
        _avatarFileName = widget.user!.avatar;
      }
    } else {
      // 新增模式
      _isEditMode = false;
      _selectedRole = 'user';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            _buildHeader(),

            // 表单内容
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 头像上传
                      _buildAvatarUploadSection(),

                      const SizedBox(height: 24),

                      // 基本信息
                      _buildBasicInfoSection(),

                      const SizedBox(height: 24),

                      // 角色选择
                      _buildRoleSection(),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),

            // 操作按钮
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// 构建标题栏
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isEditMode ? Icons.edit : Icons.add,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            _isEditMode ? '编辑用户' : '新增用户',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建基本信息部分
  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '基本信息',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        _buildUsernameField(),
        const SizedBox(height: 16),
        _buildEmailField(),
        const SizedBox(height: 16),
        _buildPasswordField(),
        const SizedBox(height: 16),
        _buildConfirmPasswordField(),
      ],
    );
  }

  /// 构建用户名字段
  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: const InputDecoration(
        labelText: '用户名 *',
        hintText: '请输入用户名',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.person, size: 18),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入用户名';
        }
        if (value.length < 3) {
          return '用户名至少3个字符';
        }
        return null;
      },
    );
  }

  /// 构建邮箱字段
  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: '邮箱 *',
        hintText: '请输入邮箱地址',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.email, size: 18),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请输入邮箱地址';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return '请输入有效的邮箱地址';
        }
        return null;
      },
    );
  }

  /// 构建密码字段
  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: _isEditMode ? '新密码' : '密码 *',
        hintText: _isEditMode ? '留空则不修改密码' : '请输入密码',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      ),
      obscureText: true,
      validator: (value) {
        if (!_isEditMode && (value == null || value.isEmpty)) {
          return '请输入密码';
        }
        if (value != null && value.isNotEmpty && value.length < 6) {
          return '密码至少6个字符';
        }
        return null;
      },
    );
  }

  /// 构建确认密码字段
  Widget _buildConfirmPasswordField() {
    return TextFormField(
      controller: _confirmPasswordController,
      decoration: InputDecoration(
        labelText: _isEditMode ? '确认新密码' : '确认密码 *',
        hintText: _isEditMode ? '留空则不修改密码' : '请再次输入密码',
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.lock_outline, size: 18),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        isDense: true,
      ),
      obscureText: true,
      validator: (value) {
        if (!_isEditMode && (value == null || value.isEmpty)) {
          return '请确认密码';
        }
        if (value != null &&
            value.isNotEmpty &&
            value != _passwordController.text) {
          return '两次输入的密码不一致';
        }
        return null;
      },
    );
  }

  /// 构建角色选择部分
  Widget _buildRoleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRoleDropdown(),
        const SizedBox(height: 16),
        _buildDoctorSection(),
      ],
    );
  }

  /// 构建角色下拉选择
  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedRole,
      decoration: const InputDecoration(
        labelText: '角色 *',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.security, size: 18),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      items:
          _roles.map((role) {
            return DropdownMenuItem(
              value: role,
              child: Text(_getRoleDisplayName(role)),
            );
          }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedRole = value!;
        });
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请选择用户角色';
        }
        return null;
      },
    );
  }

  /// 构建医生姓名字段
  Widget _buildDoctorSection() {
    return TextFormField(
      controller: _doctorController,
      decoration: const InputDecoration(
        labelText: '医生姓名 *',
        hintText: '请输入医生姓名',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.medical_services, size: 18),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return '请输入医生姓名';
        }
        return null;
      },
    );
  }

  /// 构建头像上传部分
  Widget _buildAvatarUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '用户头像',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // 头像预览和上传按钮
        Row(
          children: [
            // 头像预览
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child:
                  _uploadedImageData != null && _uploadedImageData!.isNotEmpty
                      ? CircleAvatar(
                        backgroundImage: MemoryImage(
                          Uint8List.fromList(_uploadedImageData!),
                        ),
                      )
                      : CircleAvatar(
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _getDefaultAvatarImage(_selectedRole),
                        child:
                            _getDefaultAvatarImage(_selectedRole) == null
                                ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey[400],
                                )
                                : null,
                      ),
            ),
            const SizedBox(width: 16),

            // 上传和删除按钮
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickAndCompressImage,
                  icon: const Icon(Icons.image, size: 18),
                  label: const Text('选择图片'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_uploadedImageData != null &&
                    _uploadedImageData!.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _uploadedImageData = null;
                        _avatarFileName = null;
                      });
                    },
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('删除图片'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// 选择并压缩图片
  Future<void> _pickAndCompressImage() async {
    try {
      AppLogger.info('开始选择图片...');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // 确保获取字节数据
      );

      AppLogger.info('文件选择结果: ${result != null ? "有文件" : "无文件"}');

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        AppLogger.info('选中文件: ${file.name}, 路径: ${file.path}');

        // 获取字节数据
        Uint8List? bytes;

        // 优先使用bytes属性
        if (file.bytes != null) {
          bytes = file.bytes!;
          AppLogger.info('从bytes属性获取数据: ${bytes.length} 字节');
        }
        // 如果bytes为空，尝试从路径读取
        else if (file.path != null) {
          try {
            final imageFile = File(file.path!);
            bytes = await imageFile.readAsBytes();
            AppLogger.info('从文件路径读取数据: ${bytes.length} 字节');
          } catch (e) {
            AppLogger.info('从文件路径读取失败: $e');
          }
        }

        if (bytes == null) {
          AppLogger.info('无法获取图片数据');
          if (!mounted) return;
          SuccessToastManager.showError(context, message: '无法读取图片数据，请重试');
          return;
        }

        AppLogger.info('开始验证图片格式...');
        // 验证图片格式
        if (!ImageCompressor.isValidImageFormat(bytes)) {
          AppLogger.info('图片格式验证失败');
          if (!mounted) return;
          SuccessToastManager.showError(
            context,
            message: '不支持的图片格式，请选择JPG、PNG等常见格式',
          );
          return;
        }

        AppLogger.info('图片格式验证通过');

        // 获取原始图片信息
        final dimensions = ImageCompressor.getImageDimensions(bytes);
        if (dimensions != null) {
          AppLogger.info('原始图片尺寸: ${dimensions['width']}x${dimensions['height']}');
        }

        AppLogger.info('开始压缩图片...');
        // 压缩图片
        final compressedBytes = await ImageCompressor.compressAvatar(bytes);

        if (compressedBytes == null) {
          AppLogger.info('图片压缩失败');
          if (!mounted) return;
          SuccessToastManager.showError(context, message: '图片处理失败，请重试');
          return;
        }

        AppLogger.info('图片压缩成功: ${compressedBytes.length} 字节');

        // 检查压缩后的大小
        if (compressedBytes.length > 500 * 1024) {
          // 超过500KB
          AppLogger.info('压缩后图片仍然过大: ${compressedBytes.length} 字节');
          if (!mounted) return;
          SuccessToastManager.showError(context, message: '图片过大，请选择较小的图片');
          return;
        }

        AppLogger.info('调用setState更新图片数据...');
        setState(() {
          _uploadedImageData = compressedBytes;
          _avatarFileName = file.name;
        });

        AppLogger.info('头像上传完成');
        if (!mounted) return;
        SuccessToastManager.show(context, message: '头像上传成功');
      } else {
        AppLogger.info('用户取消了文件选择');
      }
    } catch (e, stackTrace) {
      AppLogger.info('选择图片失败: $e');
      AppLogger.info('堆栈跟踪: $stackTrace');
      if (!mounted) return;
      SuccessToastManager.showError(context, message: '选择图片失败: $e');
    }
  }

  /// 构建操作按钮
  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
        border: Border(top: BorderSide(color: Colors.grey[300]!, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveUser,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                    : Text(
                      _isEditMode ? '更新' : '保存',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  /// 获取角色显示名称
  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return '管理员';
      case 'doctor':
        return '医生';
      case 'user':
        return '普通用户';
      default:
        return '未知';
    }
  }

  /// 保存用户
  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<UserProvider>(context, listen: false);

      // 检查用户名是否已存在
      final exists = await provider.isUsernameExists(
        _usernameController.text,
        excludeId: widget.user?.id,
      );

      if (exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('用户名已存在，请使用其他用户名'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 检查邮箱是否已存在
      final emailExists = await provider.isEmailExists(
        _emailController.text,
        excludeId: widget.user?.id,
      );

      if (emailExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('邮箱已存在，请使用其他邮箱'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final user = User(
        id: widget.user?.id,
        username: _usernameController.text,
        email: _emailController.text,
        password:
            _passwordController.text.isNotEmpty ? _passwordController.text : '',
        role: _selectedRole,
        doctor:
            _doctorController.text.trim().isNotEmpty
                ? _doctorController.text.trim()
                : null,
        avatar: _avatarFileName ?? 'avatar_1', // 使用上传的文件名或默认头像
        imageData: _uploadedImageData, // 传递头像图片数据
      );

      if (_isEditMode) {
        // 更新模式
        await provider.updateUser(user);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('用户更新成功'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // 新增模式
        final id = await provider.addUser(user);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('用户创建成功，ID: $id'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true); // 返回true表示操作成功
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 获取默认头像图片
  ImageProvider<Object>? _getDefaultAvatarImage(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'doctor':
        return const AssetImage('assets/icons/doctor.png');
      case 'user':
        return const AssetImage('assets/icons/nurse.png');
      default:
        return null;
    }
  }
}

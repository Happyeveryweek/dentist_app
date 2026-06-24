import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../models/user.dart';
import '../widgets/app_card.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/features/users/widgets/user_dialog.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';

class UserDetailScreen extends StatelessWidget {
  final User user;

  const UserDetailScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('用户详情: ${user.username}'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _editUser(context),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _deleteUser(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 新的用户头部
            _buildNewUserHeader(context),
            const SizedBox(height: 24),

            // 详细信息卡片
            _buildDetailsExpansionCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildNewUserHeader(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _getRoleColor(user.role),
            backgroundImage:
                user.imageData != null && user.imageData!.isNotEmpty
                    ? MemoryImage(Uint8List.fromList(user.imageData!))
                    : _getDefaultAvatarImage(user.role),
            child:
                user.imageData != null && user.imageData!.isNotEmpty
                    ? null
                    : (_getDefaultAvatarImage(user.role) != null
                        ? null
                        : Text(
                          user.username.isNotEmpty
                              ? user.username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        )),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getRoleColor(
                      user.role,
                    ).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getRoleDisplayName(user.role),
                    style: TextStyle(
                      color: _getRoleColor(user.role),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsExpansionCard(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ExpansionTile(
            initiallyExpanded: true,
            leading: Icon(
              Icons.info_outline,
              color: Theme.of(context).primaryColor,
            ),
            title: const Text(
              '基本信息',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            children: [
              _buildInfoRow(context, Icons.person_pin, '用户ID:', '#${user.id}'),
              _buildInfoRow(context, Icons.person, '用户名:', user.username),
              _buildInfoRow(context, Icons.email, '邮箱:', user.email ?? '未设置'),
              if (user.doctor?.isNotEmpty == true)
                _buildInfoRow(
                  context,
                  Icons.medical_services,
                  '医生信息:',
                  user.doctor!,
                ),
              if (user.avatar?.isNotEmpty == true)
                _buildInfoRow(context, Icons.face, '头像:', user.avatar!),
            ],
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ExpansionTile(
            leading: Icon(
              Icons.verified_user_outlined,
              color: Theme.of(context).primaryColor,
            ),
            title: const Text(
              '角色和权限',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            children: [
              _buildInfoRow(
                context,
                Icons.verified_user,
                '角色:',
                _getRoleDisplayName(user.role),
              ),
              _buildInfoRow(
                context,
                Icons.description,
                '角色描述:',
                _getRoleDescription(user.role),
              ),
            ],
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ExpansionTile(
            leading: Icon(
              Icons.history_outlined,
              color: Theme.of(context).primaryColor,
            ),
            title: const Text(
              '时间信息',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            children: [
              _buildInfoRow(
                context,
                Icons.calendar_today,
                '创建时间:',
                DateFormat('yyyy-MM-dd HH:mm').format(user.createdAt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).primaryColor, size: 20),
          const SizedBox(width: 16),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'doctor':
        return Colors.blue;
      case 'nurse':
        return Colors.green;
      case 'receptionist':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _getRoleDisplayName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return '管理员';
      case 'doctor':
        return '医生';
      case 'nurse':
        return '护士';
      case 'receptionist':
        return '前台';
      default:
        return '未知';
    }
  }

  String _getRoleDescription(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return '拥有系统所有权限，可以管理用户、查看所有数据';
      case 'doctor':
        return '可以查看和管理患者信息、预约记录等';
      case 'nurse':
        return '可以查看患者信息、协助医生工作';
      case 'receptionist':
        return '可以查看基本信息、协助前台工作';
      default:
        return '权限受限';
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

  void _editUser(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UserDialog(user: user),
    ).then((result) {
      if (result == true) {
        // 返回并传递需要刷新的信号
        if (context.mounted) {
          Navigator.pop(context, true);
        }
      }
    });
  }

  void _deleteUser(BuildContext context) async {
    final confirmed = await ModernDeleteDialogManager.showUserDelete(
      context,
      username: user.username,
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      _confirmDeleteUser(context);
    }
  }

  Future<void> _confirmDeleteUser(BuildContext context) async {
    try {
      final provider = Provider.of<UserProvider>(context, listen: false);
      await provider.deleteUser(user.id!);

      if (!context.mounted) return;
      DeleteSuccessToastManager.show(context, message: '用户删除成功');
      // 返回并传递需要刷新的信号
      Navigator.pop(context, true);
    } catch (e) {
      if (context.mounted) {
        SuccessToastManager.showError(context, message: '删除失败: $e');
      }
    }
  }
}

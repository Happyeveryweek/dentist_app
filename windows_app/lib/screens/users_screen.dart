import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../widgets/dental_icons.dart';
import '../widgets/success_toast.dart';
import '../widgets/mysql_connection_warning.dart';
import '../features/users/widgets/user_card.dart';
import '../features/users/widgets/reset_password_dialog.dart';
import '../features/users/widgets/user_list_empty_state.dart';
import '../features/users/widgets/user_list_loading_state.dart';
import '../features/users/widgets/user_list_error_state.dart';
import '../features/users/widgets/user_list_header.dart';
import '../features/users/widgets/user_form_dialog.dart';
import '../features/users/widgets/permission_preview_dialog.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.usersNeedRefresh) {
      _loadUsers(forceRefresh: true);
      userProvider.resetUsersRefreshFlag();
    }
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

  // 显示添加/编辑用户对话框
  Future<void> _showAddEditUserDialog([User? user]) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => UserFormDialog(
        user: user,
        availableRoles: _availableRoles,
      ),
    );

    if (result == true && mounted) {
      await _loadUsers(forceRefresh: true);
    }
  }

  // 显示重置密码对话框
  Future<void> _showResetPasswordDialog(User user) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ResetPasswordDialog(user: user),
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
        AppToastManager.showDelete(context, message: '用户已删除');
      } catch (e) {
        if (!mounted) return;
        AppToastManager.showError(
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
                AppToastManager.showSuccess(context, message: '刷新数据成功');
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
      body: Column(
        children: [
          // MySQL连接状态检查
          const MySQLConnectionWarning(moduleName: '用户管理'),

          Expanded(
            child: _buildUserList(),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList() {
    if (_isLoading) {
      return const UserListLoadingState();
    }

    if (_hasError) {
      return UserListErrorState(
        errorMessage: _errorMessage,
        onRetry: () => _loadUsers(forceRefresh: true),
      );
    }

    if (_users.isEmpty) {
      return UserListEmptyState(
        onAddUser: () => _showAddEditUserDialog(),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 页面标题和统计信息
          UserListHeader(
            userCount: _users.length,
            adminCount: _users.where((u) => u.role == 'admin').length,
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
                return UserCard(
                  user: user,
                  onResetPassword: () => _showResetPasswordDialog(user),
                  onEdit: () => _showAddEditUserDialog(user),
                  onPermissionPreview: () => _showPermissionPreviewDialog(user),
                  onDelete: () => _showDeleteConfirmationDialog(user),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 显示权限预览对话框
  Future<void> _showPermissionPreviewDialog(User user) async {
    await showDialog(
      context: context,
      builder: (context) => PermissionPreviewDialog(
        user: user,
        onEditPermission: () => _showAddEditUserDialog(user),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../models/user.dart';
import '../models/user_role.dart';
import '../providers/user_provider.dart';
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
import '../utils/log_manager.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({Key? key}) : super(key: key);

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen>
    with AutomaticKeepAliveClientMixin<UsersScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  final List<String> _availableRoles =
      UserRole.values.map((role) => role.value).toList();

  @override
  void initState() {
    super.initState();
    _loadUsers(forceRefresh: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.usersNeedRefresh) {
      _loadUsers(forceRefresh: true, showLoading: false);
      userProvider.resetUsersRefreshFlag();
    }
  }

  // 加载所有用户
  Future<void> _loadUsers({
    bool forceRefresh = true,
    bool showLoading = true,
  }) async {
    final shouldShowLoading = showLoading && _users.isEmpty;
    if (shouldShowLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
      });
    } else if (_hasError || _errorMessage.isNotEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = '';
      });
    }

    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);

      // 使用强制刷新参数，确保获取最新数据
      final users = await userProvider.getAllUsers(forceRefresh: forceRefresh);
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
        _hasError = false;
        _errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '加载用户数据时出错: $e';
      });
      LogManager.e('UsersScreen', '加载用户数据失败', error: e);
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
        final userId = user.id;
        if (userId == null) {
          if (!mounted) return;
          AppToastManager.showError(context, message: '无法删除无 ID 的用户');
          return;
        }
        if (!mounted) return;
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        await userProvider.deleteUser(userId);

        // 强制刷新用户列表
        await _loadUsers(forceRefresh: true);

        if (!mounted) return;
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
    super.build(context);
    return Scaffold(
      backgroundColor: context.colors.surface,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.people_rounded,
                color: context.tokens.cardBackground,
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
        backgroundColor: context.tokens.cardBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: context.tokens.infoContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.tokens.info.withValues(alpha: 0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.refresh_rounded,
                color: context.tokens.info,
              ),
              onPressed: () async {
                // 强制刷新数据
                await _loadUsers(forceRefresh: true, showLoading: false);
                if (!context.mounted) return;
                AppToastManager.showSuccess(context, message: '刷新数据成功');
              },
              tooltip: '刷新数据',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              gradient: context.tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.person_add_rounded,
                  color: context.tokens.cardBackground),
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
        onRetry: () => _loadUsers(forceRefresh: true, showLoading: true),
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
            adminCount: _users.where((u) => u.isAdmin).length,
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

  @override
  bool get wantKeepAlive => true;
}

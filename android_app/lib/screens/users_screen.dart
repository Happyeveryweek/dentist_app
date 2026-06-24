import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/models/user.dart';
import 'package:dentist_app/screens/user_detail_screen.dart';
import 'package:dentist_app/features/users/widgets/user_dialog.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import '../widgets/app_card.dart';

/// 用户管理主页面
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User> _users = [];
  List<User> _filteredUsers = [];
  bool _isLoading = false;
  String _searchQuery = '';
  Map<String, dynamic> _statistics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 统计信息卡片
          _buildStatisticsCard(),

          // 搜索栏
          _buildSearchBar(),

          // 用户列表 - 添加下拉刷新
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: () async {
                        await _loadData();
                        if (context.mounted) {
                          SuccessToastManager.show(context, message: '刷新成功');
                        }
                      },
                      child: _buildUsersList(),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUserDialog(context),
        backgroundColor: Theme.of(context).primaryColor,
        heroTag: 'users_add_button',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 构建统计信息卡片
  Widget _buildStatisticsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '总用户',
                    '${_statistics['totalUsers'] ?? 0}',
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '管理员',
                    '${_statistics['adminCount'] ?? 0}',
                    Icons.admin_panel_settings,
                    Colors.red,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '医生',
                    '${_statistics['doctorCount'] ?? 0}',
                    Icons.medical_services,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '普通用户',
                    '${_statistics['userCount'] ?? 0}',
                    Icons.person,
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 构建统计项目
  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  /// 构建搜索栏
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: '搜索用户名或邮箱...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterUsers();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建用户列表
  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('暂无用户', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  /// 构建用户卡片 - 重新设计以适应头像功能
  Widget _buildUserCard(User user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => _showUserDetails(context, user),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 顶部：头像 + 用户名 + 操作按钮
              Row(
                children: [
                  // 用户头像 - 更大的显示
                  CircleAvatar(
                    radius: 32,
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
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )),
                  ),
                  const SizedBox(width: 16),
                  // 用户名和邮箱
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email ?? '无邮箱',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // 操作按钮
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _editUser(user),
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        tooltip: '编辑',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _deleteUser(user),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: '删除',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 分割线
              Divider(height: 1, color: Colors.grey[300]),
              const SizedBox(height: 12),
              // 底部：角色标签和其他信息
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // 角色标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _getRoleColor(
                        user.role,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _getRoleColor(
                          user.role,
                        ).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      _getRoleDisplayName(user.role),
                      style: TextStyle(
                        color: _getRoleColor(user.role),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 医生信息标签
                  if (user.doctor?.isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green[300]!, width: 1),
                      ),
                      child: Text(
                        '医生: ${user.doctor}',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  // 创建时间
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('yyyy-MM-dd').format(user.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 获取角色颜色
  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.red;
      case 'doctor':
        return Colors.green;
      case 'user':
        return Colors.blue;
      default:
        return Colors.grey;
    }
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

  /// 加载数据
  Future<void> _loadData({bool isRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<UserProvider>(context, listen: false);

      // 如果是刷新操作，强制清除缓存
      if (isRefresh) {
        provider.forceRefreshUsers();
      }

      // 先修复数据库中的无效角色值
      await provider.fixInvalidRoles();

      // 加载用户列表
      final users = await provider.getAllUsers();

      // 加载统计信息
      final stats = await provider.getUserStatistics();

      if (mounted) {
        setState(() {
          _users = users;
          _filteredUsers = users;
          _statistics = stats;
          _isLoading = false;
        });

        // 只在手动刷新时显示成功提示
        if (isRefresh) {
          SuccessToastManager.show(context, message: '数据已刷新');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        SuccessToastManager.showError(context, message: '加载数据失败: $e');
      }
    }
  }

  /// 过滤用户
  void _filterUsers() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredUsers = _users;
      });
    } else {
      setState(() {
        _filteredUsers =
            _users.where((user) {
              return user.username.toLowerCase().contains(
                    _searchQuery.toLowerCase(),
                  ) ||
                  (user.email?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false);
            }).toList();
      });
    }
  }

  /// 显示添加用户对话框
  void _showAddUserDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => const UserDialog()).then(
      (result) {
        if (result == true) {
          if (!context.mounted) return;
          // 强制刷新数据，确保获取最新数据
          final provider = Provider.of<UserProvider>(context, listen: false);
          provider.forceRefreshUsers();
          _loadData(); // 刷新数据
        }
      },
    );
  }

  /// 编辑用户
  void _editUser(User user) {
    showDialog(
      context: context,
      builder: (context) => UserDialog(user: user),
    ).then((result) {
      if (result == true) {
        if (!mounted) return;
        // 强制刷新数据，确保获取最新数据
        final provider = Provider.of<UserProvider>(context, listen: false);
        provider.forceRefreshUsers();
        _loadData(); // 刷新数据
      }
    });
  }

  /// 删除用户
  void _deleteUser(User user) async {
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showUserDelete(
      context,
      username: user.username,
    );

    if (confirmed == true) {
      _confirmDeleteUser(user);
    }
  }

  /// 确认删除用户
  Future<void> _confirmDeleteUser(User user) async {
    try {
      final provider = Provider.of<UserProvider>(context, listen: false);
      await provider.deleteUser(user.id!);

      if (mounted) {
        // 使用公共组件的删除成功提示
        DeleteSuccessToastManager.show(context, message: '用户删除成功');
        // 强制刷新数据，确保获取最新数据
        final provider = Provider.of<UserProvider>(context, listen: false);
        provider.forceRefreshUsers();
        _loadData(); // 重新加载数据
      }
    } catch (e) {
      if (mounted) {
        // 使用公共组件的错误提示
        SuccessToastManager.showError(context, message: '删除失败: $e');
      }
    }
  }

  /// 显示用户详情
  void _showUserDetails(BuildContext context, User user) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => UserDetailScreen(user: user)),
    );

    if (result == true) {
      if (!context.mounted) return;
      // 强制刷新数据，确保获取最新数据
      final provider = Provider.of<UserProvider>(context, listen: false);
      provider.forceRefreshUsers();
      _loadData(); // 如果有变更，则刷新数据
    }
  }
}

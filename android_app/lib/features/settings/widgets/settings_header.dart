import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

/// 设置页面头部组件
/// 包含标题、退出登录按钮、帮助按钮和 TabBar
class SettingsHeader extends StatelessWidget {
  final TabController? tabController;
  final VoidCallback onLogout;

  const SettingsHeader({super.key, this.tabController, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '系统设置',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: onLogout,
                    tooltip: '退出登录',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: Colors.orange.shade100),
          const SizedBox(height: 12),
          TabBar(
            controller: tabController,
            indicatorColor: Colors.orange.shade600,
            labelColor: Colors.orange.shade600,
            unselectedLabelColor: AppTheme.secondaryText,
            tabs: const [
              Tab(icon: Icon(Icons.storage), text: '数据源'),
              Tab(icon: Icon(Icons.sync), text: '同步配置'),
              Tab(icon: Icon(Icons.settings), text: '系统设置'),
            ],
          ),
        ],
      ),
    );
  }
}

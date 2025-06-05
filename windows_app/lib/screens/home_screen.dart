import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../providers/settings_provider.dart';
import '../widgets/theme_switcher.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'appointments_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';
import '../providers/database_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 页面列表
  final List<Widget> _allPages = [
    const DashboardScreen(),
    const PatientsScreen(),
    const AppointmentsScreen(),
    const UsersScreen(),
    const SettingsScreen(),
  ];

  // 导航项 - 使用Font Awesome图标
  final List<NavigationItem> _allNavItems = [
    NavigationItem(
      icon: FontAwesomeIcons.gaugeHigh,
      selectedIcon: FontAwesomeIcons.gaugeHigh,
      label: '仪表盘',
      color: const Color(0xFF3498db),
    ),
    NavigationItem(
      icon: FontAwesomeIcons.userGroup,
      selectedIcon: FontAwesomeIcons.userGroup,
      label: '患者管理',
      color: const Color(0xFF2ecc71),
    ),
    NavigationItem(
      icon: FontAwesomeIcons.calendarCheck,
      selectedIcon: FontAwesomeIcons.calendarCheck,
      label: '预约管理',
      color: const Color(0xFFe74c3c),
    ),
    NavigationItem(
      icon: FontAwesomeIcons.usersCog,
      selectedIcon: FontAwesomeIcons.usersCog,
      label: '用户管理',
      color: const Color(0xFF9b59b6),
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: FontAwesomeIcons.gear,
      selectedIcon: FontAwesomeIcons.gear,
      label: '系统设置',
      color: const Color(0xFF9b59b6),
      requiredRole: 'admin',
    ),
  ];

  List<NavigationItem> _visibleNavItems = [];
  List<Widget> _visiblePages = [];
  bool _isUserAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    try {
      final user = await dbProvider.getCurrentUser();
      if (user != null) {
        setState(() {
          _isUserAdmin = user.role == 'admin';
          _updateVisibleItems();
        });
      }
    } catch (e) {
      print('获取用户角色失败: $e');
      setState(() {
        _isUserAdmin = false;
        _updateVisibleItems();
      });
    }
  }

  void _updateVisibleItems() {
    if (_isUserAdmin) {
      // 管理员可以看到所有菜单
      _visibleNavItems = _allNavItems;
      _visiblePages = _allPages;
    } else {
      // 非管理员只能看到前三个菜单
      _visibleNavItems = _allNavItems
          .where((item) => item.requiredRole == null || item.requiredRole == '')
          .toList();

      // 获取对应的页面
      _visiblePages = [];
      for (var i = 0; i < _allNavItems.length; i++) {
        if (_allNavItems[i].requiredRole == null ||
            _allNavItems[i].requiredRole == '') {
          _visiblePages.add(_allPages[i]);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    // 确保当前索引在可见项范围内
    int currentIndex = appState.activePageIndex;
    if (currentIndex >= _visibleNavItems.length) {
      currentIndex = 0;
      appState.activePageIndex = 0;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getPageTitle(currentIndex)),
        elevation: 0,
        actions: [
          // 添加主题切换按钮
          const ThemeSwitcher(),
        ],
      ),
      body: Row(
        children: [
          // 美化侧边导航栏 - 使用与内容区域对比更明显的颜色
          Container(
            width: 220, // 保持宽度
            decoration: BoxDecoration(
              color: isPurpleTheme
                  ? AppTheme.purpleBackground
                  : const Color(0xFFEBEFF5), // 根据主题设置背景色
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  spreadRadius: 0,
                  offset: const Offset(1, 0),
                ),
              ],
              border: Border(
                right: BorderSide(
                  color: Colors.grey.withOpacity(0.15),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // 应用标志区域
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 28.0),
                  child: Column(
                    children: [
                      Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: isPurpleTheme
                              ? AppTheme.purpleCardBackground
                              : Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.07),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Center(
                          child: FaIcon(
                            FontAwesomeIcons.tooth,
                            color: isPurpleTheme
                                ? AppTheme.purpleColor
                                : AppTheme.primaryColor,
                            size: 26,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '牙医诊所管理',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: isPurpleTheme
                              ? AppTheme.purplePrimaryText
                              : const Color(0xFF2c3e50),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'DENTAL CLINIC',
                        style: TextStyle(
                          fontSize: 11,
                          color: isPurpleTheme
                              ? AppTheme.purpleLightText
                              : AppTheme.lightText,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Divider(
                      color: isPurpleTheme
                          ? AppTheme.purpleDividerColor
                          : Colors.grey.withOpacity(0.2),
                      height: 1),
                ),
                const SizedBox(height: 20),

                // 导航按钮列表
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _visibleNavItems.length,
                    itemBuilder: (context, index) {
                      final isActive = index == currentIndex;
                      final item = _visibleNavItems[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 6.0,
                        ),
                        child: Container(
                          decoration: isActive
                              ? BoxDecoration(
                                  // 改为更简约的选中状态样式
                                  color: isPurpleTheme
                                      ? AppTheme.purpleCardBackground
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                )
                              : null,
                          child: InkWell(
                            onTap: () {
                              appState.activePageIndex = index;

                              // 如果是切换到仪表盘，强制刷新数据
                              if (index == 0) {
                                final dbProvider =
                                    Provider.of<DatabaseProvider>(context,
                                        listen: false);
                                dbProvider.markDashboardNeedRefresh();
                              }
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 14.0,
                              ),
                              child: Row(
                                children: [
                                  // 导航图标 - 简化样式
                                  SizedBox(
                                    width: 20, // 固定宽度
                                    child: FaIcon(
                                      item.icon,
                                      color: isActive
                                          ? isPurpleTheme
                                              ? AppTheme.purpleColor
                                              : AppTheme.primaryColor
                                          : isPurpleTheme
                                              ? AppTheme.purpleSecondaryText
                                              : AppTheme.secondaryText
                                                  .withOpacity(0.8),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // 导航文本 - 确保第一个字对齐
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: isActive
                                            ? isPurpleTheme
                                                ? AppTheme.purpleColor
                                                : AppTheme.primaryColor
                                            : isPurpleTheme
                                                ? AppTheme.purpleSecondaryText
                                                : AppTheme.secondaryText,
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),

                                  // 移除右侧指示条，使用左侧主色竖条
                                  if (isActive) ...[
                                    Container(
                                      width: 4,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isPurpleTheme
                                            ? AppTheme.purpleColor
                                            : AppTheme.primaryColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 底部版本信息
                Container(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Divider(color: Colors.grey.withOpacity(0.2), height: 1),
                      const SizedBox(height: 16),

                      // 添加用户信息区域
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: FaIcon(
                                  FontAwesomeIcons.userAlt,
                                  color: AppTheme.primaryColor,
                                  size: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  FutureBuilder<String>(
                                      future: _getCurrentUsername(context),
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? 'admin',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.primaryText,
                                          ),
                                        );
                                      }),
                                  FutureBuilder<String>(
                                      future: _getCurrentUserRole(context),
                                      builder: (context, snapshot) {
                                        return Text(
                                          snapshot.data ?? '管理员',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.secondaryText,
                                          ),
                                        );
                                      }),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                // 退出登录功能
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('退出登录'),
                                    content: const Text('确认要退出登录吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('取消'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                          Navigator.of(context)
                                              .pushReplacementNamed('/login');
                                        },
                                        child: const Text('确认'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: FaIcon(
                                  FontAwesomeIcons.signOutAlt,
                                  color: Colors.red.shade600,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.code,
                            color: AppTheme.lightText,
                            size: 12,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'v1.0.0',
                            style: TextStyle(
                              color: AppTheme.lightText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 主内容区域 - 使用纯白色背景增加对比度
          Expanded(
            child: Container(
              color: Colors.white, // 简化为纯白色背景
              child: ClipRRect(
                child: IndexedStack(
                  index: currentIndex,
                  children: _visiblePages,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 获取当前登录用户名的方法
  Future<String> _getCurrentUsername(BuildContext context) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    // 读取应用状态保存的当前用户信息，或者从本地存储获取
    try {
      final user = await dbProvider.getCurrentUser();
      if (user != null) {
        return user.username;
      }
    } catch (e) {
      print('获取当前用户名失败: $e');
    }
    return 'admin'; // 默认返回admin
  }

  // 获取当前用户角色的方法
  Future<String> _getCurrentUserRole(BuildContext context) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    try {
      final user = await dbProvider.getCurrentUser();
      if (user != null) {
        return user.roleDisplay;
      }
    } catch (e) {
      print('获取当前用户角色失败: $e');
    }
    return '管理员'; // 默认返回管理员
  }

  String _getPageTitle(int index) {
    switch (index) {
      case 0:
        return '仪表盘';
      case 1:
        return '患者管理';
      case 2:
        return '预约管理';
      case 3:
        return '用户管理';
      case 4:
        return '系统设置';
      default:
        return '未知页面';
    }
  }
}

// 导航项目模型
class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Color color;
  final String? requiredRole;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.color,
    this.requiredRole,
  });
}

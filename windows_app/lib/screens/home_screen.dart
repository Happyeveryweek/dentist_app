import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/home/widgets/home_widgets.dart';
import '../providers/app_state.dart';
import '../providers/settings_provider.dart';
// import '../widgets/theme_switcher.dart'; // 主题切换功能已移除
import 'modern_dashboard_screen.dart';
import 'patients_screen.dart';
import 'appointments_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';
import 'financial_management_screen.dart';
import 'materials_screen.dart';
import 'purchase_records_screen.dart';
import 'medical_management_screen.dart';
import '../providers/database_provider.dart';
import '../providers/user_provider.dart';
import '../providers/patient_provider.dart';
import '../widgets/dental_icons.dart';
import '../utils/log_manager.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 页面列表
  final List<Widget> _allPages = [
    const ModernDashboardScreen(),
    const PatientsScreen(),
    const AppointmentsScreen(),
    const FinancialManagementScreen(),
    const MaterialsScreen(),
    const PurchaseRecordsScreen(),
    const MedicalManagementScreen(),
    const UsersScreen(),
    const SettingsScreen(),
  ];

  // 导航项 - 使用牙科专业图标
  List<NavigationItem> _allNavItems = [];

  List<NavigationItem> _visibleNavItems = [];
  List<Widget> _visiblePages = [];

  @override
  void initState() {
    super.initState();
    // 监听UserProvider的变化以实现权限变更时的菜单动态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.addListener(_onUserProviderChanged);
    });
  }

  void _rebuildNavigationItems() {
    final tokens = context.tokens;
    _allNavItems = [
      NavigationItem(
        icon: DentalIcons.chartPie,
        selectedIcon: DentalIcons.chartPie,
        label: '仪表盘',
        color: tokens.primaryAccent,
        moduleId: 'dashboard',
      ),
      NavigationItem(
        icon: DentalIcons.hospitalUser,
        selectedIcon: DentalIcons.hospitalUser,
        label: '患者管理',
        color: tokens.secondaryAccent,
        moduleId: 'patients',
        requiredRole: 'admin',
      ),
      NavigationItem(
        icon: DentalIcons.calendarCheck,
        selectedIcon: DentalIcons.calendarCheck,
        label: '预约管理',
        color: tokens.info,
        moduleId: 'appointments',
        requiredRole: 'admin',
      ),
      NavigationItem(
        icon: Icons.account_balance_wallet,
        selectedIcon: Icons.account_balance_wallet,
        label: '财务管理',
        color: tokens.success,
        moduleId: 'financial',
        requiredRole: 'admin',
      ),
      NavigationItem(
        icon: Icons.inventory_2,
        selectedIcon: Icons.inventory_2,
        label: '材料管理',
        color: tokens.warning,
        moduleId: 'materials',
        requiredRole: 'admin',
      ),
      NavigationItem(
        icon: Icons.shopping_cart,
        selectedIcon: Icons.shopping_cart,
        label: '采购管理',
        color: tokens.info,
        moduleId: 'purchase',
        requiredRole: 'admin',
      ),
      NavigationItem(
        icon: Icons.medical_information,
        selectedIcon: Icons.medical_information,
        label: '病历管理',
        color: tokens.secondaryAccent,
        moduleId: 'medical_records',
        requiredRole: 'admin',
      ),
      NavigationItem(
        icon: Icons.people,
        selectedIcon: Icons.people,
        label: '用户管理',
        color: tokens.primaryAccent,
        moduleId: 'users',
        requiredRole: 'admin',
      ),
      NavigationItem(
        icon: Icons.settings,
        selectedIcon: Icons.settings,
        label: '系统设置',
        color: context.colors.onSurfaceVariant,
        moduleId: 'settings',
        requiredRole: 'admin',
      ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rebuildNavigationItems();
    _checkUserRole();
  }

  @override
  void dispose() {
    // 移除监听器
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.removeListener(_onUserProviderChanged);
    } catch (e) {
      // 忽略dispose时的错误
    }
    super.dispose();
  }

  // UserProvider变化时的回调
  void _onUserProviderChanged() {
    if (mounted) {
      try {
        setState(() {
          _updateVisibleItems();
        });
      } catch (e) {
        LogManager.e('HomeScreen', '权限变更时菜单更新失败', error: e);
      }
    }
  }

  Future<void> _checkUserRole() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;

      if (user != null) {
        setState(() {
          _updateVisibleItems();
        });
      } else {
        // 如果UserProvider中没有当前用户，尝试从DatabaseProvider获取
        final dbProvider =
            Provider.of<DatabaseProvider>(context, listen: false);
        final dbUser = await dbProvider.getCurrentUser();
        if (dbUser != null) {
          // 将用户信息设置到UserProvider中并加载权限
          try {
            await userProvider.loadUserPermissions(dbUser);
            setState(() {
              _updateVisibleItems();
            });
          } catch (e) {
            LogManager.e('HomeScreen', 'HomeScreen权限加载失败', error: e);
            // 权限加载失败时仍然设置用户
            userProvider.setCurrentUser(dbUser);
            setState(() {
              _updateVisibleItems();
            });
          }
        } else {
          // 如果都没有用户信息，设置为非管理员
          setState(() {
            _updateVisibleItems();
          });
        }
      }
    } catch (e) {
      LogManager.e('HomeScreen', '获取用户角色失败', error: e);
      // 出错时默认为非管理员，只显示仪表盘
      setState(() {
        _updateVisibleItems();
      });
    }
  }

  void _updateVisibleItems() {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final currentUser = userProvider.currentUser;

      if (currentUser == null) {
        // 如果没有当前用户，只显示仪表盘
        _visibleNavItems = [_allNavItems[0]]; // 仪表盘
        _visiblePages = [_allPages[0]];

        return;
      }

      if (currentUser.isAdmin) {
        // 管理员可以看到所有菜单
        _visibleNavItems = _allNavItems;
        _visiblePages = _allPages;
      } else {
        // 普通用户基于权限配置过滤菜单
        _visibleNavItems = [];
        _visiblePages = [];

        for (var i = 0; i < _allNavItems.length; i++) {
          final navItem = _allNavItems[i];

          // 仪表盘始终对所有用户可见
          if (navItem.moduleId == 'dashboard') {
            _visibleNavItems.add(navItem);
            _visiblePages.add(_allPages[i]);
            continue;
          }

          // 检查用户是否有该模块的权限
          final moduleId = navItem.moduleId;
          if (moduleId != null && currentUser.hasModulePermission(moduleId)) {
            _visibleNavItems.add(navItem);
            _visiblePages.add(_allPages[i]);
          }
        }

        // 确保至少有仪表盘可见
        if (_visibleNavItems.isEmpty) {
          _visibleNavItems = [_allNavItems[0]]; // 仪表盘
          _visiblePages = [_allPages[0]];
        }
      }
    } catch (e) {
      LogManager.e('HomeScreen', '更新可见项目时出错', error: e);
      // 出错时只显示仪表盘
      _visibleNavItems = [_allNavItems[0]];
      _visiblePages = [_allPages[0]];
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final tokens = context.tokens;

    // 确保当前索引在可见项范围内
    int currentIndex = appState.activePageIndex;
    if (currentIndex >= _visibleNavItems.length) {
      currentIndex = 0;
      appState.activePageIndex = 0;
    }

    return Scaffold(
      body: Row(
        children: [
          // 现代化侧边导航栏
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: tokens.shellBackground,
              border: Border(
                right: BorderSide(
                  color: tokens.border,
                  width: 1,
                ),
              ),
              boxShadow: tokens.cardShadow,
            ),
            child: Column(
              children: [
                // MySQL连接状态提示
                if (!appState.isMySQLConnected &&
                    appState.affectedMySQLModules.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: tokens.warningContainer,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: tokens.warningAccent,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.warning_rounded,
                              color: tokens.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'MySQL连接失败',
                                style: TextStyle(
                                  color: tokens.warning,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'MySQL连接失败以下模块降级到SQLite: ${appState.getAffectedModulesInChinese().join('、')}',
                          style: TextStyle(
                            color: tokens.warning,
                            fontSize: 11,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                // 应用标志区域
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 32.0, horizontal: 24.0),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: SizedBox(
                          height: 92,
                          width: 92,
                          child: Image.asset(
                            'assets/images/sidebar_tooth_logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Consumer<SettingsProvider>(
                        builder: (context, settingsProvider, child) {
                          return Text(
                            settingsProvider.appName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: context.colors.onSurface,
                              letterSpacing: 0.5,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'DENTAL CLINIC',
                        style: TextStyle(
                          fontSize: 11,
                          color: tokens.textMuted,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: tokens.divider),
                const SizedBox(height: 16),

                // 导航按钮列表
                Expanded(
                  child: ListView.builder(
                    padding:
                        const EdgeInsets.only(left: 12, right: 12, bottom: 100),
                    itemCount: _visibleNavItems.length,
                    itemBuilder: (context, index) {
                      final isActive = index == currentIndex;
                      final item = _visibleNavItems[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12.0, vertical: 3.0),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              appState.activePageIndex = index;
                              _refreshModuleDataOnNavigation(index);
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  // 选中状态指示条
                                  if (isActive)
                                    Container(
                                      width: 4,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: item.color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  if (isActive) const SizedBox(width: 12),

                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? item.color.withValues(alpha: 0.1)
                                          : item.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isActive ? item.selectedIcon : item.icon,
                                      color: item.color,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: TextStyle(
                                        color: isActive
                                            ? item.color
                                            : context.colors.onSurfaceVariant,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 底部用户信息区域 - 使用单独的Widget避免AppState更新导致重建
                const UserInfoSection(),

                const SizedBox(height: 12),
                Divider(color: tokens.divider, height: 1),
                const SizedBox(height: 12),

                // 版本信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: tokens.textMuted,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 主内容区域
          Expanded(
            child: Column(
              children: [
                // 顶部装饰条
                Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: tokens.shellBackground,
                    boxShadow: tokens.cardShadow,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Row(
                      children: [
                        // 左侧装饰性元素 - 简约抽象装饰
                        Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: tokens.primaryAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: tokens.secondaryAccent
                                    .withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color:
                                    tokens.primaryAccent.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // 当前日期
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: tokens.mutedBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getCurrentDate(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.colors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 当前时间
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _visibleNavItems[currentIndex]
                                .color
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: _visibleNavItems[currentIndex].color,
                              ),
                              const SizedBox(width: 6),
                              StreamBuilder(
                                stream:
                                    Stream.periodic(const Duration(seconds: 1)),
                                builder: (context, snapshot) {
                                  return Text(
                                    _getCurrentTime(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          _visibleNavItems[currentIndex].color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 页面内容
                Expanded(
                  child: Container(
                    color: context.tokens.pageBackground,
                    child: IndexedStack(
                      index: currentIndex,
                      children: _visiblePages,
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

  // 根据导航到的模块自动刷新该模块的数据
  void _refreshModuleDataOnNavigation(int index) {
    try {
      // 获取点击的菜单项
      if (index >= _visibleNavItems.length) return;

      switch (index) {
        case 0: // 仪表盘

          break;
        case 1: // 患者管理
          final patientProvider =
              Provider.of<PatientProvider>(context, listen: false);
          patientProvider.clearCache();

          break;
        case 2: // 预约管理

          break;
        case 3: // 财务管理

          break;
        case 4: // 材料管理

          break;
        case 5: // 采购管理

          break;
        case 6: // 病历管理

          break;
        case 7: // 用户管理
        case 8: // 系统设置

          break;
      }
    } catch (e) {
      LogManager.e('HomeScreen', '⚠️ 刷新模块数据失败', error: e);
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }

  String _getCurrentDate() {
    final now = DateTime.now();
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    return '${now.month}月${now.day}日 ${weekdays[now.weekday - 1]}';
  }
}

// 导航项目模型

// 用户信息显示区域 - 单独的Widget，只监听UserProvider，避免不必要的重建

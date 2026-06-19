import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'dart:typed_data';

import '../theme/app_theme.dart';
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
import '../providers/appointment_provider.dart';
import '../providers/financial_provider.dart';
import '../providers/material_provider.dart';
import '../providers/purchase_provider.dart';
import '../widgets/success_toast.dart';
import '../widgets/dental_icons.dart';
import '../models/user.dart';

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
  final List<NavigationItem> _allNavItems = [
    NavigationItem(
      icon: DentalIcons.chartPie,
      selectedIcon: DentalIcons.chartPie,
      label: '仪表盘',
      color: DentalColors.primary,
      moduleId: 'dashboard',
    ),
    NavigationItem(
      icon: DentalIcons.hospitalUser,
      selectedIcon: DentalIcons.hospitalUser,
      label: '患者管理',
      color: DentalColors.secondary,
      moduleId: 'patients',
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: DentalIcons.calendarCheck,
      selectedIcon: DentalIcons.calendarCheck,
      label: '预约管理',
      color: DentalColors.info,
      moduleId: 'appointments',
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: Icons.account_balance_wallet,
      selectedIcon: Icons.account_balance_wallet,
      label: '财务管理',
      color: DentalColors.success,
      moduleId: 'financial',
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: Icons.inventory_2,
      selectedIcon: Icons.inventory_2,
      label: '材料管理',
      color: DentalColors.warning,
      moduleId: 'materials',
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: Icons.shopping_cart,
      selectedIcon: Icons.shopping_cart,
      label: '采购管理',
      color: DentalColors.info,
      moduleId: 'purchase',
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: Icons.medical_information,
      selectedIcon: Icons.medical_information,
      label: '病历管理',
      color: DentalColors.secondary,
      moduleId: 'medical_records',
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: Icons.people,
      selectedIcon: Icons.people,
      label: '用户管理',
      color: DentalColors.primary,
      moduleId: 'users',
      requiredRole: 'admin',
    ),
    NavigationItem(
      icon: Icons.settings,
      selectedIcon: Icons.settings,
      label: '系统设置',
      color: DentalColors.onSurfaceVariant,
      moduleId: 'settings',
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
    
    // 监听UserProvider的变化以实现权限变更时的菜单动态更新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      userProvider.addListener(_onUserProviderChanged);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
          final userProvider = Provider.of<UserProvider>(context, listen: false);
          final currentUser = userProvider.currentUser;
          _isUserAdmin = currentUser?.isAdmin ?? false;
          _updateVisibleItems();
        });
        print('权限变更时菜单动态更新完成');
      } catch (e) {
        print('权限变更时菜单更新失败: $e');
      }
    }
  }

  Future<void> _checkUserRole() async {
    try {
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final user = userProvider.currentUser;
      
      if (user != null) {
        setState(() {
          _isUserAdmin = user.isAdmin;
          _updateVisibleItems();
        });
      } else {
        // 如果UserProvider中没有当前用户，尝试从DatabaseProvider获取
        final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
        final dbUser = await dbProvider.getCurrentUser();
        if (dbUser != null) {
          // 将用户信息设置到UserProvider中并加载权限
          try {
            await userProvider.loadUserPermissions(dbUser);
            setState(() {
              _isUserAdmin = dbUser.isAdmin;
              _updateVisibleItems();
            });
          } catch (e) {
            print('HomeScreen权限加载失败: $e');
            // 权限加载失败时仍然设置用户
            userProvider.setCurrentUser(dbUser);
            setState(() {
              _isUserAdmin = dbUser.isAdmin;
              _updateVisibleItems();
            });
          }
        } else {
          // 如果都没有用户信息，设置为非管理员
          setState(() {
            _isUserAdmin = false;
            _updateVisibleItems();
          });
        }
      }
    } catch (e) {
      print('获取用户角色失败: $e');
      // 出错时默认为非管理员，只显示仪表盘
      setState(() {
        _isUserAdmin = false;
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
        print('无当前用户，仅显示仪表盘');
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
          if (navItem.moduleId != null && currentUser.hasModulePermission(navItem.moduleId!)) {
            _visibleNavItems.add(navItem);
            _visiblePages.add(_allPages[i]);
          }
        }
        
        // 确保至少有仪表盘可见
        if (_visibleNavItems.isEmpty) {
          _visibleNavItems = [_allNavItems[0]]; // 仪表盘
          _visiblePages = [_allPages[0]];
        }
        
        print('普通用户权限过滤完成: ${_visibleNavItems.length} 个可见项目');
        for (var item in _visibleNavItems) {
          print('- ${item.label} (${item.moduleId})');
        }
      }
    } catch (e) {
      print('更新可见项目时出错: $e');
      // 出错时只显示仪表盘
      _visibleNavItems = [_allNavItems[0]];
      _visiblePages = [_allPages[0]];
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
      body: Row(
        children: [
          // 现代化侧边导航栏
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(
                  color: Colors.grey[200]!,
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // MySQL连接状态提示
                if (!appState.isMySQLConnected && appState.affectedMySQLModules.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.shade200,
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
                              color: Colors.orange.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'MySQL连接失败',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
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
                            color: Colors.orange.shade600,
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
                  padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
                  child: Column(
                    children: [
                      Container(
                        height: 72,
                        width: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF4FACFE), // 亮蓝
                              Color(0xFF00F2FE), // 青色
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF4FACFE).withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 背景装饰圆圈
                            Positioned(
                              top: -10,
                              right: -10,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Icon(
                              DentalIcons.tooth,
                              color: Colors.white,
                              size: 36,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.1),
                                  offset: const Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ],
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
                              color: Colors.grey[800],
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
                          color: Colors.grey[500],
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Divider(height: 1, color: Colors.grey[200]),
                const SizedBox(height: 16),

                // 导航按钮列表
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 12, right: 12, bottom: 100),
                    itemCount: _visibleNavItems.length,
                    itemBuilder: (context, index) {
                      final isActive = index == currentIndex;
                      final item = _visibleNavItems[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
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
                                          ? item.color.withOpacity(0.1) 
                                          : item.color.withOpacity(0.1),
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
                                            : Colors.grey[700],
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
                Divider(color: Colors.grey.shade300, height: 1),
                const SizedBox(height: 12),
                
                // 版本信息
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.grey[400],
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: Colors.grey[500],
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
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
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
                                color: Color(0xFF4FACFE), // 亮蓝
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(0xFF00F2FE).withOpacity(0.6), // 青色
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Color(0xFF4FACFE).withOpacity(0.3), // 浅蓝
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // 当前日期
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _getCurrentDate(),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // 当前时间
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _visibleNavItems[currentIndex].color.withOpacity(0.1),
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
                                stream: Stream.periodic(const Duration(seconds: 1)),
                                builder: (context, snapshot) {
                                  return Text(
                                    _getCurrentTime(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _visibleNavItems[currentIndex].color,
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
                    color: DentalColors.background,
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

  // 获取当前用户对象的方法
  Future<User?> _getCurrentUser(BuildContext context) async {
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    try {
      final user = await dbProvider.getCurrentUser();
      return user;
    } catch (e) {
      print('获取当前用户失败: $e');
    }
    return null;
  }

  // 根据导航到的模块自动刷新该模块的数据
  void _refreshModuleDataOnNavigation(int index) {
    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      
      // 获取点击的菜单项
      if (index >= _visibleNavItems.length) return;
      
      final moduleId = _visibleNavItems[index].moduleId;
      
      switch (index) {
        case 0: // 仪表盘
          dbProvider.markDashboardNeedRefresh();
          print('🔄 切换到仪表盘：标记数据需要刷新');
          break;
        case 1: // 患者管理
          final patientProvider = Provider.of<PatientProvider>(context, listen: false);
          patientProvider.clearCache();
          print('🔄 切换到患者管理：清除缓存，下次加载时获取最新数据');
          break;
        case 2: // 预约管理
          print('🔄 切换到预约管理');
          break;
        case 3: // 财务管理
          print('🔄 切换到财务管理');
          break;
        case 4: // 材料管理
          print('🔄 切换到材料管理');
          break;
        case 5: // 采购管理
          print('🔄 切换到采购管理');
          break;
        case 6: // 病历管理
          print('🔄 切换到病历管理');
          break;
        case 7: // 用户管理
        case 8: // 系统设置
          print('🔄 切换到${_visibleNavItems[index].label}');
          break;
      }
    } catch (e) {
      print('⚠️ 刷新模块数据失败: $e');
    }
  }

  String _getPageTitle(int index) {
    if (index < _visibleNavItems.length) {
      return _visibleNavItems[index].label;
    }
    return '未知页面';
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

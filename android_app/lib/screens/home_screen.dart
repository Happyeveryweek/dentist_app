import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dashboard_screen.dart';
import 'patients_screen.dart';
import 'appointments_screen.dart';
import 'financial_management_screen.dart';
import '../features/purchases/screens/purchase_records_screen.dart';
import '../features/materials/screens/materials_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import '../theme/app_theme.dart';
import '../providers/user_provider.dart';
import '../widgets/lazy_indexed_stack.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pages = const [
      DashboardScreen(),
      PatientsScreen(),
      AppointmentsScreen(),
      _BusinessManagementScreen(),
      SettingsScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        // 检查登录状态
        if (userProvider.currentUser == null) {
          return const LoginScreen();
        }

        return Scaffold(
          body: LazyIndexedStack(index: _selectedIndex, children: _pages),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.dashboard_rounded,
                      label: '仪表盘',
                      index: 0,
                      color: AppTheme.primaryColor,
                    ),
                    _buildNavItem(
                      icon: Icons.people_rounded,
                      label: '患者',
                      index: 1,
                      color: AppTheme.secondaryColor,
                    ),
                    _buildNavItem(
                      icon: Icons.calendar_month_rounded,
                      label: '预约',
                      index: 2,
                      color: AppTheme.accentColor,
                    ),
                    _buildNavItem(
                      icon: Icons.business_center_rounded,
                      label: '业务',
                      index: 3,
                      color: AppTheme.navigationBusiness,
                    ),
                    _buildNavItem(
                      icon: Icons.settings_rounded,
                      label: '设置',
                      index: 4,
                      color: AppTheme.navigationSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required Color color,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _selectPage(index);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(isSelected ? 8 : 6),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? color.withValues(alpha: 0.15)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: isSelected ? 26 : 24,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: isSelected ? 12 : 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _selectPage(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
  }
}

/// 业务管理页面 - 包含财务管理、采购管理、材料管理
class _BusinessManagementScreen extends StatefulWidget {
  const _BusinessManagementScreen();

  @override
  State<_BusinessManagementScreen> createState() =>
      _BusinessManagementScreenState();
}

class _BusinessManagementScreenState extends State<_BusinessManagementScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final TabController _tabController;

  // 缓存子页面实例
  final List<Widget> _businessPages = [
    const FinancialManagementScreen(),
    const PurchaseRecordsScreen(),
    const MaterialsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // AutomaticKeepAliveClientMixin 必须调用
    // 财务、采购、材料详情使用蓝色 AppBar，会把状态栏图标改成白色。
    // 本页没有 AppBar，返回后必须自己把图标恢复为深色，否则浅色背景上看不到时间、信号和电量。
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        body: Column(
          children: [
            // 紧凑的顶部导航栏
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: BusinessManagementTabs(controller: _tabController),
                ),
              ),
            ),
            // 页面内容 - 占据剩余所有空间
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final page in _businessPages)
                    _KeepAliveBusinessPage(child: page),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BusinessManagementTabs extends StatelessWidget {
  final TabController controller;

  const BusinessManagementTabs({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final tabAnimation = controller.animation;
    if (tabAnimation == null) {
      return _buildTabs(selectedIndex: controller.index);
    }

    return AnimatedBuilder(
      animation: tabAnimation,
      builder:
          (context, _) => _buildTabs(
            selectedIndex:
                controller.indexIsChanging
                    ? controller.index
                    : tabAnimation.value.round(),
          ),
    );
  }

  Widget _buildTabs({required int selectedIndex}) {
    return Row(
      children: [
        _buildCompactTab(
          icon: Icons.account_balance_wallet_rounded,
          label: '财务',
          index: 0,
          selected: selectedIndex == 0,
          color: AppTheme.successColor,
        ),
        const SizedBox(width: 8),
        _buildCompactTab(
          icon: Icons.shopping_cart_rounded,
          label: '采购',
          index: 1,
          selected: selectedIndex == 1,
          color: AppTheme.infoColor,
        ),
        const SizedBox(width: 8),
        _buildCompactTab(
          icon: Icons.inventory_2_rounded,
          label: '材料',
          index: 2,
          selected: selectedIndex == 2,
          color: AppTheme.warningColor,
        ),
      ],
    );
  }

  Widget _buildCompactTab({
    required IconData icon,
    required String label,
    required int index,
    required bool selected,
    required Color color,
  }) {
    final isSelected = selected;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.animateTo(index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            gradient:
                isSelected
                    ? LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.15),
                        color.withValues(alpha: 0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color: isSelected ? null : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isSelected
                      ? color.withValues(alpha: 0.3)
                      : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? color : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? color : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeepAliveBusinessPage extends StatefulWidget {
  final Widget child;

  const _KeepAliveBusinessPage({required this.child});

  @override
  State<_KeepAliveBusinessPage> createState() => _KeepAliveBusinessPageState();
}

class _KeepAliveBusinessPageState extends State<_KeepAliveBusinessPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/settings_provider.dart';
import 'package:dentist_app/providers/app_state.dart';
import 'package:dentist_app/screens/dashboard_screen.dart';
import 'package:dentist_app/screens/patients_screen.dart';
import 'package:dentist_app/screens/appointments_screen.dart';
import 'package:dentist_app/screens/settings_screen.dart';
// import 'package:dentist_app/screens/splash_screen.dart';
// import 'package:dentist_app/screens/error_screen.dart';

// 临时声明的加载和错误页面
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('出错了！', style: TextStyle(fontSize: 24)),
            const SizedBox(height: 8),
            Text(error, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Provider.of<DatabaseProvider>(
                  context,
                  listen: false,
                ).initDatabase();
              },
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 初始化中文日期格式
  await initializeDateFormatting('zh_CN', null);

  // 初始化数据库提供者
  final databaseProvider = DatabaseProvider();
  await databaseProvider.initDatabase();

  // 初始化设置提供者
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // 创建应用状态
  final appState = AppState();

  // 运行应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: databaseProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: appState),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    // 使用refreshCounter作为key，强制重建整个应用
    return KeyedSubtree(
      key: ValueKey('app_rebuild_${appState.refreshCounter}'),
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            navigatorKey: appState.navigatorKey,
            debugShowCheckedModeBanner: false,
            title: '牙科诊所管理系统',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            locale: const Locale('zh', 'CN'),
            supportedLocales: const [Locale('zh', 'CN')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: FutureBuilder<void>(
              // 移除对DatabaseProvider的监听，直接获取引用
              future:
                  Provider.of<DatabaseProvider>(
                    context,
                    listen: false,
                  ).initDatabase(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SplashScreen();
                } else if (snapshot.hasError) {
                  return ErrorScreen(error: snapshot.error.toString());
                } else {
                  return Builder(
                    builder: (context) {
                      // 创建一个全局key用于访问首页状态
                      final GlobalKey<_MainScreenState> mainScreenKey =
                          GlobalKey<_MainScreenState>();

                      return MainScreen(
                        key: mainScreenKey,
                        onDataChanged: () {
                          // 当数据变更时，强制刷新仪表盘
                          if (mainScreenKey.currentState != null) {
                            mainScreenKey.currentState!.refreshDashboard();
                          }
                        },
                      );
                    },
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  final Function() onDataChanged;

  const MainScreen({
    Key? key,
    this.initialIndex = 0,
    required this.onDataChanged,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen>
    with SingleTickerProviderStateMixin {
  late int _selectedIndex;
  late AnimationController _animationController;

  // 页面实例
  late List<Widget> _pages;

  // 添加一个标志，用于跟踪数据库是否已变更
  bool _needsRebuild = false;

  // 保存对DatabaseProvider的引用
  DatabaseProvider? _dbProvider;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 启动动画控制器，确保初次进入时内容可见
    _animationController.value = 1.0; // 直接设置为1，跳过动画

    // 初始化页面
    _initPages();

    // 不再需要检查数据库状态
    // 让各个页面自行管理自己的刷新
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // 在这里获取Provider引用，以便在dispose中安全使用
    if (_dbProvider == null) {
      _dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      // 不再添加自动监听
      // _dbProvider?.addListener(_checkDatabaseChanges);
    }
  }

  // 检查数据库变更
  void _checkDatabaseChanges() {
    if (!mounted) return;

    final dbProvider = _dbProvider;
    if (dbProvider == null) return;

    // 只在必要时重置刷新标志
    // 不再处理任何刷新逻辑或重建页面
    // 让各个页面自己负责它们自己的刷新
    print('检测到数据库变更标志，但不进行任何刷新操作');

    // 重置所有刷新标志
    dbProvider.resetDatabaseChanged();
  }

  // 创建特定索引的页面
  Widget _createPage(int index) {
    print('创建新的页面实例：index=$index');

    // 对于仪表盘，创建一个能够调用刷新方法的实例
    if (index == 0) {
      // 重新创建仪表盘实例，确保数据刷新
      return DashboardScreen(key: UniqueKey());
    }

    // 其他页面正常创建
    return [
      const DashboardScreen(key: Key('dashboard')),
      const PatientsScreen(key: Key('patients')),
      const AppointmentsScreen(key: Key('appointments')),
      const SettingsScreen(key: Key('settings')),
    ][index];
  }

  // 初始化页面
  void _initPages() {
    print('初始化页面实例');
    _pages = [_createPage(0), _createPage(1), _createPage(2), _createPage(3)];
  }

  // 仅重建当前页面，而不是所有页面 - 保留但不使用
  void _rebuildCurrentPage() {
    print('仅重建当前页面: $_selectedIndex');
    setState(() {
      // 只重建当前选中的页面
      _pages[_selectedIndex] = _createPage(_selectedIndex);
      _needsRebuild = false;
    });

    // 播放动画效果，但动画效果更轻微
    _animationController.reset();
    _animationController.forward();
  }

  @override
  void dispose() {
    // 已移除监听器，无需再此处移除
    _animationController.dispose();
    super.dispose();
  }

  // 底部导航项
  final List<BottomNavigationBarItem> _navItems = [
    const BottomNavigationBarItem(
      icon: Icon(Icons.dashboard_outlined),
      activeIcon: Icon(Icons.dashboard),
      label: '仪表盘',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.people_outline),
      activeIcon: Icon(Icons.people),
      label: '患者管理',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.calendar_month_outlined),
      activeIcon: Icon(Icons.calendar_month),
      label: '预约管理',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.settings_outlined),
      activeIcon: Icon(Icons.settings),
      label: '系统设置',
    ),
  ];

  // 导航项点击处理
  void onItemTapped(int index) {
    // 如果选择的已经是当前页面，则不做任何改变
    if (_selectedIndex == index) {
      // 如果点击的是仪表盘，尝试刷新仪表盘数据
      if (index == 0) {
        print('点击仪表盘导航项，强制刷新仪表盘数据');
        _pages[0] = _createPage(0); // 重建仪表盘页面
        setState(() {}); // 触发UI更新
      }
      return;
    }

    // 如果要切换到仪表盘，确保创建一个新的实例
    if (index == 0) {
      _pages[0] = _createPage(0); // 切换到仪表盘前重建仪表盘页面
    }

    setState(() {
      _selectedIndex = index;
    });

    // 播放动画
    _animationController.reset();
    _animationController.forward();
  }

  void refreshDashboard() {
    if (_selectedIndex == 0) {
      // 如果当前在仪表盘页面，则刷新
      if (_animationController.isAnimating == false) {
        // 通知仪表盘页面刷新数据
        setState(() {
          // 强制重建页面
          _animationController.reset();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查数据库变更，如果需要重建页面，先重新初始化
    if (_needsRebuild) {
      print('数据库已变更，重新初始化页面');
      _initPages();
      setState(() {
        _needsRebuild = false;
      });
    }

    // 不再使用Consumer监听数据库变更
    return Scaffold(
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeIn,
          reverseCurve: Curves.easeOut,
        ),
        child: IndexedStack(index: _selectedIndex, children: _pages),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          items: _navItems,
          currentIndex: _selectedIndex,
          onTap: onItemTapped,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: AppTheme.primaryColor,
          unselectedItemColor: AppTheme.secondaryText,
          backgroundColor: AppTheme.cardBackground,
          elevation: 8,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}

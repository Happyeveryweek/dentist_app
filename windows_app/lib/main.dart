import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';

import 'theme/app_theme.dart';
import 'providers/database_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/app_state.dart';
import 'screens/dashboard_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

// 加载页面
class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

// 错误页面
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

  // 设置Windows应用窗口
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = WindowOptions(
      title: '牙医诊所管理系统',
      titleBarStyle: TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // 初始化intl日期格式
  Intl.defaultLocale = 'zh_CN';
  await initializeDateFormatting('zh_CN', null);

  // 在Windows和Linux平台上初始化sqflite
  if (Platform.isWindows || Platform.isLinux) {
    // 初始化FFI
    sqfliteFfiInit();
    // 设置全局databaseFactory为databaseFactoryFfi
    databaseFactory = databaseFactoryFfi;
    print("已设置databaseFactory = databaseFactoryFfi");
  }

  // 确保所有平台都正确设置了数据库工厂
  print("当前数据库工厂: $databaseFactory");

  runApp(const DentistApp());
}

class DentistApp extends StatelessWidget {
  const DentistApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProxyProvider<SettingsProvider, DatabaseProvider>(
          create: (_) => DatabaseProvider(),
          update: (_, settings, db) {
            db ??= DatabaseProvider();
            return db;
          },
        ),
      ],
      child: const AppWithProviders(),
    );
  }
}

class AppWithProviders extends StatefulWidget {
  const AppWithProviders({Key? key}) : super(key: key);

  @override
  State<AppWithProviders> createState() => _AppWithProvidersState();
}

class _AppWithProvidersState extends State<AppWithProviders> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

    try {
      // 初始化设置
      await settings.init();

      // 设置数据源类型
      String dataSourceType = settings.dataSourceType;
      print('初始化数据源类型: $dataSourceType');

      if (dataSourceType == 'sqlite') {
        // 如果是SQLite，检查是否有自定义数据库路径
        String? sqliteDbPath = settings.sqliteDbPath;
        print('SQLite数据库路径: ${sqliteDbPath ?? "使用默认路径"}');

        // 直接在切换数据源时传递自定义路径
        await dbProvider.setDataSourceType(
          dataSourceType,
          customSqlitePath: sqliteDbPath,
        );
      } else if (dataSourceType == 'mysql') {
        // 如果是MySQL，设置连接参数
        Map<String, dynamic> mysqlSettings = {
          'host': settings.mysqlHost ?? 'localhost',
          'port': int.tryParse(settings.mysqlPort ?? '3306') ?? 3306,
          'database': settings.mysqlDatabase ?? 'dentist_db',
          'username': settings.mysqlUsername ?? 'root',
          'password': settings.mysqlPassword ?? '',
        };

        print('MySQL设置: $mysqlSettings');

        // 初始化MySQL连接
        await dbProvider.setDataSourceType(
          dataSourceType,
          mysqlSettings: mysqlSettings,
        );
      } else {
        print('未知的数据源类型，使用默认SQLite');
        // 默认使用SQLite
        await dbProvider.setDataSourceType('sqlite');
      }

      // 在数据库初始化后检查是否需要执行自动备份
      await _checkAutoBackup(settings, dbProvider);

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('初始化时发生错误: $e');
      try {
        // 发生错误时，尝试使用默认SQLite
        print('尝试使用默认SQLite初始化...');
        await dbProvider.setDataSourceType('sqlite');
        setState(() {
          _isInitialized = true;
        });
      } catch (e) {
        print('无法初始化默认数据库: $e');
        setState(() {
          _isInitialized = true; // 仍然标记为已初始化，但应用程序将显示错误界面
        });
      }
    }
  }

  // 检查是否需要执行自动备份
  Future<void> _checkAutoBackup(
      SettingsProvider settings, DatabaseProvider dbProvider) async {
    try {
      // 检查是否启用了自动备份
      if (settings.autoBackup) {
        print('自动备份已启用，检查是否需要执行备份');

        // 获取上次备份日期
        DateTime? lastBackupDate = settings.lastBackupDate;
        final now = DateTime.now();

        // 如果从未备份过，或者备份日志被清空导致lastBackupDate为null，则执行备份
        if (lastBackupDate == null) {
          print('首次备份或备份记录已清空，执行备份');
          await _performBackup(settings, dbProvider);
        } else {
          // 计算自上次备份以来的天数 - 修复日期比较问题
          // 将日期对象转换为年月日格式，忽略时间部分
          final nowDate = DateTime(now.year, now.month, now.day);
          final lastBackupDateOnly = DateTime(
              lastBackupDate.year, lastBackupDate.month, lastBackupDate.day);

          // 计算日期差异（天数）
          final difference = nowDate.difference(lastBackupDateOnly).inDays;
          print('距离上次备份已经过去 $difference 天');

          // 如果超过设定的备份间隔，执行备份
          if (difference >= settings.backupInterval) {
            print('已达到备份间隔 (${settings.backupInterval} 天)，执行备份');
            await _performBackup(settings, dbProvider);
          } else {
            print('未达到备份间隔，跳过自动备份');
          }
        }
      } else {
        print('自动备份未启用');
      }
    } catch (e) {
      print('检查自动备份时出错: $e');
    }
  }

  // 执行备份操作
  Future<void> _performBackup(
      SettingsProvider settings, DatabaseProvider dbProvider) async {
    // 检查备份路径设置
    final path1 = settings.backupPath;
    final path2 = settings.backupPath2;

    if (path1.isEmpty && path2.isEmpty) {
      print('错误：未设置备份路径，无法执行自动备份');
      return;
    }

    try {
      bool backupSuccessful = false;

      // 优先使用第一个备份路径
      if (path1.isNotEmpty) {
        print('使用备份路径1: $path1');
        await settings.setBackupPath(path1);
        await dbProvider.backupDatabase();
        backupSuccessful = true;
      }

      // 如果设置了第二个备份路径，也执行备份
      if (path2.isNotEmpty) {
        print('使用备份路径2: $path2');
        await settings.setBackupPath(path2);
        await dbProvider.backupDatabase();
        backupSuccessful = true;
      }

      // 恢复到第一个备份路径
      if (path1.isNotEmpty) {
        await settings.setBackupPath(path1);
      }

      // 手动更新备份日期到今天
      if (backupSuccessful) {
        final now = DateTime.now();
        final todayDate = DateTime(now.year, now.month, now.day);
        await settings.updateLastBackupDate(todayDate);
        print('主函数中已更新最后备份日期: ${todayDate.toIso8601String()}');
      }

      print('自动备份完成');
    } catch (e) {
      print('执行自动备份时出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: '牙医诊所管理系统',
      navigatorKey: appState.navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      builder: (context, child) {
        // 处理特殊主题模式
        if (settings.extendedThemeMode == ExtendedThemeMode.grey) {
          return Theme(
            data: AppTheme.greyTheme,
            child: child!,
          );
        } else if (settings.extendedThemeMode == ExtendedThemeMode.purple) {
          return Theme(
            data: AppTheme.purpleTheme,
            child: child!,
          );
        }
        return child!;
      },
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      routes: {
        '/login': (context) => const LoginScreen(),
      },
      home: !_isInitialized
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : const LoginScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 页面列表
  final List<Widget> _pages = [
    const DashboardScreen(),
    const PatientsScreen(),
    const AppointmentsScreen(),
    const SettingsScreen(),
  ];

  // 侧边导航项
  List<NavigationRailDestination> get _navItems => [
        const NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('仪表盘'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.people_outline),
          selectedIcon: Icon(Icons.people),
          label: Text('患者管理'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.calendar_month_outlined),
          selectedIcon: Icon(Icons.calendar_month),
          label: Text('预约管理'),
        ),
        const NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('系统设置'),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 侧边导航栏 - Windows风格
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: _navItems,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.medical_services,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '牙科诊所',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            backgroundColor: AppTheme.cardBackground,
            elevation: 3,
          ),

          // 分隔线
          const VerticalDivider(thickness: 1, width: 1),

          // 主内容区域
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

// 获取当前主题的ThemeData
ThemeData getThemeData(BuildContext context) {
  final settings = Provider.of<SettingsProvider>(context);

  // 处理特殊主题模式
  if (settings.extendedThemeMode == ExtendedThemeMode.purple) {
    return AppTheme.purpleTheme;
  } else if (settings.extendedThemeMode == ExtendedThemeMode.grey) {
    return AppTheme.greyTheme;
  }

  // 默认返回浅色主题
  return AppTheme.lightTheme;
}

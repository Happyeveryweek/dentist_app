import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme/app_theme.dart';
import 'providers/database_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/app_state.dart';
import 'providers/financial_provider.dart';
import 'providers/material_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/user_provider.dart';
import 'providers/patient_provider.dart';
import 'providers/patient_image_provider.dart';
import 'providers/medical_record_provider.dart';
import 'providers/appointments_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/settings_screen.dart';
import 'models/sync_config.dart';
import 'utils/app_lifecycle_manager.dart';
import 'utils/connection_manager.dart';
import 'utils/app_logger.dart';

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

// 主应用类，集成增强的生命周期管理
class MyApp extends StatefulWidget {
  final DatabaseProvider databaseProvider;
  final SettingsProvider settingsProvider;
  final AppState appState;

  const MyApp({
    Key? key,
    required this.databaseProvider,
    required this.settingsProvider,
    required this.appState,
  }) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _connectionManagerStarted = false;

  @override
  void initState() {
    super.initState();

    // 监听数据库提供者的初始化状态
    widget.databaseProvider.addListener(_onDatabaseProviderChanged);

    AppLogger.info('🚀 应用启动完成，等待数据库初始化后启动连接管理器');
  }

  @override
  void dispose() {
    widget.databaseProvider.removeListener(_onDatabaseProviderChanged);
    // 停止连接管理器
    ConnectionManager.instance.stopMonitoring();
    super.dispose();
  }

  /// 监听数据库提供者状态变化
  void _onDatabaseProviderChanged() {
    // 只有在数据库初始化完成且连接管理器还未启动时才启动
    if (widget.databaseProvider.isInitialized && !_connectionManagerStarted) {
      _connectionManagerStarted = true;

      AppLogger.info('📊 数据库初始化完成，最终数据库类型: ${widget.databaseProvider.dbType}');

      // 延迟启动连接管理器，确保数据库类型已经确定
      Future.delayed(const Duration(milliseconds: 100), () {
        final finalDbType = widget.databaseProvider.dbType;
        AppLogger.info('🔧 延迟启动连接管理器，确认数据库类型: $finalDbType');

        // 根据最终确定的数据库类型启动连接管理器
        ConnectionManager.instance.startMonitoring(widget.databaseProvider);

        if (finalDbType == 'mysql') {
          AppLogger.info('🌐 MySQL模式：连接管理器已启动');
        } else {
          AppLogger.info('📱 SQLite模式：连接管理器已启动（无网络监控）');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return AppLifecycleManager(
          child: MaterialApp(
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
            // 添加命名路由
            initialRoute: '/',
            routes: {
              '/': (context) => const LoginScreen(), // 直接显示登录页面，不等待数据库初始化
              '/home': (context) => const HomeScreen(),
              '/login': (context) => const LoginScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
            // 移除home属性，使用initialRoute和routes
          ),
        );
      },
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

  // 检查并执行自动同步
  Future<void> checkAndPerformAutoSync(
    DatabaseProvider dbProvider,
    SettingsProvider settingsProvider,
  ) async {
    try {
      // 检查是否启用自动同步
      final syncConfig = await SyncConfig.loadSyncConfig();
      if (!syncConfig.syncEnabled) {
        AppLogger.info('自动同步已禁用，跳过启动时同步检查');
        return;
      }

      // 检查数据源类型
      if (dbProvider.dbType != 'mysql') {
        AppLogger.info('当前数据源不是MySQL，跳过启动时同步检查');
        return;
      }

      AppLogger.info('检测到MySQL数据源且启用自动同步，检查是否需要执行启动时同步...');

      // 检查是否需要同步
      if (syncConfig.shouldSync()) {
        AppLogger.info('需要执行启动时同步，开始同步数据...');

        // 执行同步
        final syncResult = await dbProvider.forceDataSync();
        if (syncResult) {
          AppLogger.info('启动时自动同步成功完成');
        } else {
          AppLogger.info('启动时自动同步失败');
        }
      } else {
        AppLogger.info('距离上次同步时间不足，跳过启动时同步');
      }
    } catch (e) {
      AppLogger.info('检查启动时自动同步时出错: $e');
    }
  }

  // 在后台异步初始化数据库和自动同步
  Future<void> initializeDatabaseInBackground(
    DatabaseProvider dbProvider,
    SettingsProvider settingsProvider,
  ) async {
    try {
      AppLogger.info('🔄 开始在后台初始化数据库...');
      await dbProvider.initDatabase();
      AppLogger.info('✅ 数据库初始化完成');

      // 数据库初始化完成后，执行自动同步检查
      await checkAndPerformAutoSync(dbProvider, settingsProvider);
    } catch (e) {
      AppLogger.info('❌ 后台数据库初始化失败: $e');
      // 不抛出异常，让应用继续运行，错误将在登录界面处理
    }
  }

  // 初始化数据库提供者（异步执行，不阻塞UI）
  final databaseProvider = DatabaseProvider();

  // 立即初始化设置提供者（不依赖数据库）
  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  // 在后台异步初始化数据库和自动同步
  unawaited(initializeDatabaseInBackground(databaseProvider, settingsProvider));

  // 创建应用状态
  final appState = AppState();

  // 运行应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: databaseProvider),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: appState),
        // UserProvider must come first since other providers depend on it
        ChangeNotifierProxyProvider<DatabaseProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, dbProvider, userProvider) {
            userProvider ??= UserProvider();
            if (dbProvider.isInitialized &&
                (!userProvider.initialized ||
                    userProvider.dataSourceType != dbProvider.dbType)) {
              userProvider.initializeFromDatabase(dbProvider);
            }
            return userProvider;
          },
        ),
        ChangeNotifierProxyProvider2<
          DatabaseProvider,
          UserProvider,
          AppointmentsProvider
        >(
          create: (_) => AppointmentsProvider(),
          update: (_, dbProvider, userProvider, appointmentsProvider) {
            appointmentsProvider ??= AppointmentsProvider();
            if (dbProvider.isInitialized && !appointmentsProvider.initialized) {
              appointmentsProvider.initializeFromDatabase(dbProvider);
            }
            // 设置用户提供者用于权限控制
            appointmentsProvider.setUserProvider(userProvider);
            return appointmentsProvider;
          },
        ),
        ChangeNotifierProxyProvider2<
          DatabaseProvider,
          UserProvider,
          FinancialProvider
        >(
          create: (_) => FinancialProvider(),
          update: (_, dbProvider, userProvider, financialProvider) {
            financialProvider ??= FinancialProvider();
            if (dbProvider.isInitialized && !financialProvider.initialized) {
              financialProvider.initializeFromDatabase(dbProvider);
            }
            // 设置用户提供者用于权限控制
            financialProvider.setUserProvider(userProvider);
            return financialProvider;
          },
        ),
        ChangeNotifierProxyProvider2<
          DatabaseProvider,
          UserProvider,
          PatientProvider
        >(
          create: (_) => PatientProvider(),
          update: (_, dbProvider, userProvider, patientProvider) {
            patientProvider ??= PatientProvider();
            if (dbProvider.isInitialized && !patientProvider.initialized) {
              patientProvider.initializeFromDatabase(dbProvider);
            }
            // 设置用户提供者用于权限控制
            patientProvider.setUserProvider(userProvider);
            return patientProvider;
          },
        ),
        ChangeNotifierProxyProvider<DatabaseProvider, MaterialProvider>(
          create: (_) => MaterialProvider(),
          update: (_, dbProvider, materialProvider) {
            materialProvider ??= MaterialProvider();
            if (dbProvider.isInitialized && !materialProvider.initialized) {
              materialProvider.initializeFromDatabase(dbProvider);
            }
            return materialProvider;
          },
        ),
        ChangeNotifierProxyProvider2<
          DatabaseProvider,
          UserProvider,
          PurchaseProvider
        >(
          create: (_) => PurchaseProvider(),
          update: (_, dbProvider, userProvider, purchaseProvider) {
            purchaseProvider ??= PurchaseProvider();
            // 先绑定用户提供者，避免采购Provider初始化时权限服务捕获空引用。
            purchaseProvider.setUserProvider(userProvider);
            if (dbProvider.isInitialized && !purchaseProvider.initialized) {
              purchaseProvider.initializeFromDatabase(dbProvider);
            }
            return purchaseProvider;
          },
        ),
        ChangeNotifierProxyProvider<DatabaseProvider, PatientImageProvider>(
          create: (_) => PatientImageProvider(databaseProvider),
          update: (_, dbProvider, imageProvider) {
            imageProvider ??= PatientImageProvider(dbProvider);
            if (dbProvider.isInitialized && !imageProvider.initialized) {
              imageProvider.initializeFromDatabase(dbProvider);
            }
            return imageProvider;
          },
        ),
        ChangeNotifierProxyProvider<DatabaseProvider, MedicalRecordProvider>(
          create: (_) => MedicalRecordProvider(),
          update: (_, dbProvider, medicalRecordProvider) {
            medicalRecordProvider ??= MedicalRecordProvider();
            if (dbProvider.isInitialized &&
                !medicalRecordProvider.initialized) {
              medicalRecordProvider.initializeFromDatabase(dbProvider);
            }
            return medicalRecordProvider;
          },
        ),
      ],
      child: MyApp(
        databaseProvider: databaseProvider,
        settingsProvider: settingsProvider,
        appState: appState,
      ),
    ),
  );
}

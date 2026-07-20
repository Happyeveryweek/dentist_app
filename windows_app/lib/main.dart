import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:window_manager/window_manager.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import 'theme/app_theme.dart';
import 'providers/database_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/app_state.dart';
import 'providers/material_provider.dart';
import 'providers/purchase_provider.dart';
import 'providers/financial_provider.dart';
import 'providers/user_provider.dart'; // Added import for UserProvider
import 'providers/appointment_provider.dart';
import 'providers/patient_provider.dart'; // Added import for PatientProvider
import 'providers/medical_record_provider.dart'; // Added import for MedicalRecordProvider
import 'screens/modern_dashboard_screen.dart';
import 'screens/patients_screen.dart';
import 'screens/appointments_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'utils/app_paths.dart';
import 'utils/log_manager.dart';
import 'utils/single_instance.dart';
import 'services/medical_template_service.dart';
import 'config/app_defaults.dart';
import 'models/data_source.dart';
import 'models/app_module.dart';

void main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // Windows平台单实例检测
  if (Platform.isWindows) {
    final isUnique = await SingleInstance.checkSingleInstance();
    if (!isUnique) {
      try {
        await windowManager.ensureInitialized();
        const duplicateWindowOptions = WindowOptions(
          title: defaultAppName,
          titleBarStyle: TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
        await windowManager.waitUntilReadyToShow(
          duplicateWindowOptions,
          () async {
            await windowManager.show();
            await windowManager.focus();
          },
        );
      } catch (_) {
        // 重复打开提示页属于兜底路径，窗口初始化失败时继续展示提示内容即可。
      }

      // 已有实例在运行，显示提示页并由页面控制倒计时退出
      runApp(const AlreadyRunningApp());
      return;
    }
  }

  try {
    // 初始化应用路径管理（日志落盘前必须先初始化）
    await AppPaths.initialize();
    await AppPaths.initializeAllDirectories();

    // 初始化日志管理器
    await LogManager.initialize();

    // 设置全局错误处理（必须在日志管理器初始化之后）
    FlutterError.onError = (FlutterErrorDetails details) {
      LogManager.e(
        'Global',
        'Flutter UI错误',
        error: details.exception,
        stackTrace: details.stack,
      );
      FlutterError.dumpErrorToConsole(details, forceReport: true);
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      LogManager.e(
        'Global',
        '异步错误',
        error: error,
        stackTrace: stack,
      );
      return true; // 已处理
    };

    LogManager.i('Main', 'main(): 应用启动开始');

    // 初始化医疗模板服务（如果没有模板数据则创建默认模板）
    try {
      final hasTemplateData = await MedicalTemplateService.hasTemplateData();
      if (!hasTemplateData) {
        LogManager.i('Main', 'main(): 初始化默认医疗模板...');
        await MedicalTemplateService.initializeDefaultTemplates();
        LogManager.i('Main', '默认医疗模板初始化完成');
      }
    } catch (e, stackTrace) {
      LogManager.e('Main', '医疗模板初始化失败', error: e, stackTrace: stackTrace);
      // 继续，不阻止应用启动
    }

    // 设置Windows应用窗口
    if (Platform.isWindows) {
      try {
        LogManager.i('Main', 'main(): 初始化Windows窗口...');
        await windowManager.ensureInitialized();
        WindowOptions windowOptions = const WindowOptions(
          title: defaultAppName,
          titleBarStyle: TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
        LogManager.i('Main', 'Windows窗口初始化成功');
      } catch (e, stackTrace) {
        LogManager.e('Main', 'Windows窗口初始化失败',
            error: e, stackTrace: stackTrace);
        // 继续运行，窗口初始化失败不应该阻止应用启动
      }
    }

    // 初始化intl日期格式
    try {
      LogManager.i('Main', 'main(): 初始化日期格式...');
      Intl.defaultLocale = 'zh_CN';
      await initializeDateFormatting('zh_CN', null);
      LogManager.i('Main', '日期格式初始化成功');
    } catch (e, stackTrace) {
      LogManager.e('Main', '日期格式初始化失败', error: e, stackTrace: stackTrace);
    }

    // 在Windows和Linux平台上初始化sqflite
    if (Platform.isWindows || Platform.isLinux) {
      try {
        LogManager.i('Main', 'main(): 初始化数据库工厂...');
        // 初始化FFI
        sqfliteFfiInit();
        // 设置全局databaseFactory为databaseFactoryFfi
        databaseFactory = databaseFactoryFfi;
        LogManager.i('Main', '数据库工厂初始化成功: $databaseFactory');
      } catch (e, stackTrace) {
        LogManager.e('Main', '数据库工厂初始化失败', error: e, stackTrace: stackTrace);
        rethrow;
      }
    }

    // 确保所有平台都正确设置了数据库工厂

    LogManager.i('Main', 'main(): 准备启动应用...');
    runApp(const DentistApp());
  } catch (e, stackTrace) {
    // 日志系统可能尚未初始化，使用 debugPrint 作为最后兜底
    debugPrint('应用启动失败: $e');
    debugPrint('堆栈: $stackTrace');
    // 显示错误应用
    runApp(ErrorApp(error: '应用启动失败:\n\n$e\n\n堆栈:\n$stackTrace'));
  }
}

// 错误应用 - 当main()出现未捕获的异常时显示
class ErrorApp extends StatelessWidget {
  final String error;

  const ErrorApp({Key? key, required this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: context.tokens.errorContainer,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    color: context.tokens.error, size: 64),
                const SizedBox(height: 20),
                const Text('应用启动失败',
                    style:
                        TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      error,
                      style: TextStyle(
                          fontSize: 14, color: context.colors.onSurface),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 应用已运行提示界面
class AlreadyRunningApp extends StatelessWidget {
  const AlreadyRunningApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8F74A8)),
        useMaterial3: true,
      ),
      home: const AlreadyRunningScreen(),
    );
  }
}

class AlreadyRunningScreen extends StatefulWidget {
  const AlreadyRunningScreen({Key? key}) : super(key: key);

  @override
  State<AlreadyRunningScreen> createState() => _AlreadyRunningScreenState();
}

class _AlreadyRunningScreenState extends State<AlreadyRunningScreen> {
  static const int _initialSeconds = 5;
  int _secondsRemaining = _initialSeconds;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        _exitApp();
        return;
      }
      setState(() {
        _secondsRemaining -= 1;
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _exitApp() async {
    _countdownTimer?.cancel();
    try {
      if (Platform.isWindows) {
        await windowManager.close();
      }
    } catch (_) {
      // ignore and fall back to process exit
    }
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDF7),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(40),
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: colorScheme.error,
                  size: 54,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '应用已经打开',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '检测到$defaultAppName已经在运行。\n\n为了避免数据冲突，不允许重复打开多个实例。\n请切换到已打开的窗口继续操作。',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  height: 1.6,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '此窗口将在 $_secondsRemaining 秒后自动退出，也可以手动点击下方按钮关闭。',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _exitApp,
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('立即退出'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DentistApp extends StatelessWidget {
  const DentistApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DatabaseProvider()),
        ChangeNotifierProxyProvider<DatabaseProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, dbProvider, userProvider) {
            userProvider ??= UserProvider();

            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode;
            final moduleDataSources = settings.moduleDataSources;

            // 智能初始化：根据配置模式决定数据源类型
            userProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
            );

            return userProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider,
            FinancialProvider>(
          create: (_) => FinancialProvider(),
          update: (_, dbProvider, userProvider, financialProvider) {
            financialProvider ??= FinancialProvider();

            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode;
            final moduleDataSources = settings.moduleDataSources;

            // 使用initializeFromDatabase方法，传递模块配置和用户权限提供者
            financialProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
              userProvider: userProvider,
            );

            return financialProvider;
          },
        ),
        ChangeNotifierProxyProvider<DatabaseProvider, MaterialProvider>(
          create: (_) => MaterialProvider(),
          update: (_, dbProvider, materialProvider) {
            materialProvider ??= MaterialProvider();

            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode;
            final moduleDataSources = settings.moduleDataSources;

            // 智能初始化：根据配置模式决定数据源类型
            materialProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
            );

            return materialProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider,
            PurchaseProvider>(
          create: (_) => PurchaseProvider(),
          update: (_, dbProvider, userProvider, purchaseProvider) {
            purchaseProvider ??= PurchaseProvider();

            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode;
            final moduleDataSources = settings.moduleDataSources;

            // 使用initializeFromDatabase方法，传递模块配置和用户权限提供者
            purchaseProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
              userProvider: userProvider,
            );

            return purchaseProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider,
            PatientProvider>(
          create: (_) => PatientProvider(),
          update: (_, dbProvider, userProvider, patientProvider) {
            patientProvider ??= PatientProvider();

            patientProvider.setUserProvider(userProvider);

            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode;
            final moduleDataSources = settings.moduleDataSources;

            // 智能初始化：根据配置模式决定数据源类型
            patientProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
              userProvider: userProvider,
            );

            return patientProvider;
          },
        ),
        ChangeNotifierProxyProvider3<DatabaseProvider, PatientProvider,
            UserProvider, AppointmentProvider>(
          create: (_) => AppointmentProvider(),
          update: (_, dbProvider, patientProvider, userProvider,
              appointmentProvider) {
            appointmentProvider ??= AppointmentProvider();

            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode;
            final moduleDataSources = settings.moduleDataSources;

            // 智能初始化：根据配置模式决定数据源类型，并传递PatientProvider
            appointmentProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
              patientProvider: patientProvider,
              userProvider: userProvider,
            );

            return appointmentProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider,
            MedicalRecordProvider>(
          create: (_) => MedicalRecordProvider(),
          update: (_, dbProvider, userProvider, medicalRecordProvider) {
            medicalRecordProvider ??= MedicalRecordProvider();

            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode;
            final moduleDataSources = settings.moduleDataSources;

            // 立即同步初始化数据源
            medicalRecordProvider.initializeFromDatabaseSync(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
              userProvider: userProvider,
            );

            return medicalRecordProvider;
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
  @override
  void initState() {
    super.initState();
    LogManager.i('Main', 'AppWithProviders initState: 开始初始化Provider');
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    final appState = Provider.of<AppState>(context, listen: false);

    try {
      // 初始化设置
      await settings.init();

      // 设置数据源类型 - 确保有默认值
      String dataSourceType = settings.dataSourceType;
      if (dataSourceType.isEmpty) {
        LogManager.w('Main', '数据源类型为空，使用默认SQLite');
        dataSourceType = DataSourceType.sqlite.storageValue;
        await settings.setDataSourceType(DataSourceType.sqlite.storageValue);
      }
      LogManager.i('Main', '初始化数据源类型: $dataSourceType');

      // 检查数据源模式
      final dataSourceMode = settings.dataSourceMode;
      LogManager.i('Main', '数据源模式: $dataSourceMode');

      if (dataSourceType == DataSourceType.sqlite.storageValue) {
        // 如果是SQLite，检查是否有自定义数据库路径
        String? sqliteDbPath = settings.sqliteDbPath;
        LogManager.i('Main', 'SQLite数据库路径: $sqliteDbPath');

        // 直接在切换数据源时传递自定义路径
        await dbProvider.setDataSourceType(
          dataSourceType,
          customSqlitePath: sqliteDbPath,
        );
        // 主动选择SQLite，不是MySQL失败，所以 isFailure = false
        appState.setMySQLConnectionStatus(false, isFailure: false);
      } else if (dataSourceType == DataSourceType.mysql.storageValue) {
        // 如果是MySQL，设置连接参数
        Map<String, dynamic> mysqlSettings = {
          'host': settings.mysqlHost,
          'port': int.tryParse(settings.mysqlPort) ??
              MySqlConnectionPolicy.defaultPort,
          'database': settings.mysqlDatabase,
          'username': settings.mysqlUsername,
          'password': settings.mysqlPassword,
        };

        LogManager.i('Main', 'MySQL设置: $mysqlSettings');

        try {
          // 尝试初始化MySQL连接
          await dbProvider.setDataSourceType(
            dataSourceType,
            mysqlSettings: mysqlSettings,
          );
          // MySQL连接成功
          appState.setMySQLConnectionStatus(true, isFailure: false);
        } catch (mysqlError) {
          LogManager.e('Main', 'MySQL连接失败，自动回退到SQLite', error: mysqlError);
          // 自动回退到SQLite
          await dbProvider
              .setDataSourceType(DataSourceType.sqlite.storageValue);
          // 更新设置中的数据源类型
          await settings.setDataSourceType(DataSourceType.sqlite.storageValue);
          // MySQL连接失败，设置 isFailure = true
          appState.setMySQLConnectionStatus(false, isFailure: true);
        }
      } else {
        LogManager.w('Main', '未知的数据源类型，使用默认SQLite');
        // 默认使用SQLite，并确保设置被保存
        await dbProvider.setDataSourceType(DataSourceType.sqlite.storageValue);
        await settings.setDataSourceType(DataSourceType.sqlite.storageValue);
        // 主动选择SQLite，不是MySQL失败
        appState.setMySQLConnectionStatus(false, isFailure: false);
      }

      // 如果是模块化模式，检查是否需要额外初始化MySQL连接
      if (dataSourceMode == DataSourceMode.modular.storageValue) {
        final moduleDataSources = settings.moduleDataSources;
        final affectedModules = moduleDataSources.entries
            .where((entry) => entry.value == DataSourceType.mysql.storageValue)
            .map((entry) => entry.key)
            .toList();
        final hasMySQLModules = affectedModules.isNotEmpty;

        if (hasMySQLModules &&
            dataSourceType != DataSourceType.mysql.storageValue) {
          LogManager.i('Main', '检测到模块化模式中有MySQL模块，初始化MySQL连接...');

          // 初始化MySQL连接
          Map<String, dynamic> mysqlSettings = {
            'host': settings.mysqlHost,
            'port': int.tryParse(settings.mysqlPort) ??
                MySqlConnectionPolicy.defaultPort,
            'database': settings.mysqlDatabase,
            'username': settings.mysqlUsername,
            'password': settings.mysqlPassword,
          };

          // 初始化MySQL连接（不改变当前数据源类型）
          try {
            // 添加5秒的主级超时保险，防止长时间等待
            await dbProvider.initializeMySQLConnection(mysqlSettings).timeout(
              MySqlConnectionPolicy.modularInitializationTimeout,
              onTimeout: () {
                LogManager.w('Main', 'MySQL连接初始化超时，自动降级到SQLite');
                throw TimeoutException('MySQL连接超时');
              },
            );
            // MySQL连接成功
            appState.setMySQLConnectionStatus(true,
                affectedModules: affectedModules, isFailure: false);
          } catch (mysqlError) {
            LogManager.e('Main', '模块化模式下MySQL连接失败', error: mysqlError);
            // MySQL连接失败，设置 isFailure = true
            appState.setMySQLConnectionStatus(false,
                affectedModules: affectedModules, isFailure: true);

            // 当MySQL连接失败时，临时将受影响的模块数据源切换到SQLite（仅运行时，不保存）
            LogManager.w('Main', '临时将受影响的模块数据源切换到SQLite（仅运行时）...');
            final temporaryModuleDataSources =
                Map<String, String>.from(settings.moduleDataSources);
            for (final module in affectedModules) {
              temporaryModuleDataSources[module] =
                  DataSourceType.sqlite.storageValue;
              LogManager.w('Main', '临时切换 $module 模块到SQLite（不保存设置）');
            }

            // 更新各个Provider的模块数据源配置（仅运行时）
            if (!mounted) return;
            if (affectedModules
                .contains(AppModule.purchase.dataSourceConfigKey)) {
              final purchaseProvider =
                  Provider.of<PurchaseProvider>(context, listen: false);
              purchaseProvider
                  .updateModuleDataSources(temporaryModuleDataSources);
            }
            if (affectedModules
                .contains(AppModule.financial.dataSourceConfigKey)) {
              final financialProvider =
                  Provider.of<FinancialProvider>(context, listen: false);
              financialProvider
                  .updateModuleDataSources(temporaryModuleDataSources);
            }
          }
        }
      }

      if (!mounted) return;
      // 在数据库初始化后检查是否需要执行自动备份
      _checkAutoBackup(settings, dbProvider);

      final moduleDataSources = settings.moduleDataSources;
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final patientProvider =
          Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.initializeFromDatabase(
        dbProvider,
        moduleDataSources: moduleDataSources,
        dataSourceMode: dataSourceMode,
        userProvider: userProvider,
      );

      if (!mounted) return;
      // 设置其他提供者的数据库连接
      Provider.of<MaterialProvider>(context, listen: false);
      Provider.of<PurchaseProvider>(context, listen: false);
      Provider.of<FinancialProvider>(context, listen: false);

      // 在模块化模式下，需要同时传递SQLite和MySQL连接
      if (dataSourceMode == DataSourceMode.modular.storageValue) {
        // MaterialProvider已在ChangeNotifierProxyProvider中使用initializeFromDatabase初始化，无需重复初始化
        // PurchaseProvider和FinancialProvider已在ChangeNotifierProxyProvider中初始化，无需重复初始化
        // AppointmentProvider已在ChangeNotifierProxyProvider中使用initializeFromDatabase初始化，无需重复初始化
        // PatientProvider已在ChangeNotifierProxyProvider中使用initializeFromDatabase初始化，无需重复初始化
        // UserProvider已在ChangeNotifierProxyProvider中使用initializeFromDatabase初始化，无需重复初始化
      } else {
        // 全局模式：MaterialProvider已在ChangeNotifierProxyProvider中初始化，无需重复初始化
        // PurchaseProvider和FinancialProvider已在ChangeNotifierProxyProvider中初始化，无需重复初始化
      }

      // 注意：现在Provider在初始化时就已经根据模块配置设置了正确的数据源，无需额外更新
    } catch (e, stackTrace) {
      LogManager.e('Main', '初始化时发生错误', error: e, stackTrace: stackTrace);
      try {
        // 发生错误时，尝试使用默认SQLite
        LogManager.w('Main', '尝试使用默认SQLite初始化...');
        await dbProvider.setDataSourceType(DataSourceType.sqlite.storageValue);
        // 确保设置被保存
        await settings.setDataSourceType(DataSourceType.sqlite.storageValue);
        LogManager.i('Main', '默认SQLite初始化成功');
      } catch (fallbackError, fallbackStackTrace) {
        LogManager.e('Main', '默认SQLite初始化也失败',
            error: fallbackError, stackTrace: fallbackStackTrace);
        // 最后的兜底：创建最基本的SQLite数据库
        try {
          LogManager.w('Main', '尝试创建最基本的SQLite数据库...');
          await _createEmergencyDatabase(dbProvider, settings);
          LogManager.i('Main', '紧急数据库创建成功');
        } catch (emergencyError, emergencyStackTrace) {
          LogManager.e('Main', '紧急数据库创建失败',
              error: emergencyError, stackTrace: emergencyStackTrace);
        }
      }
    }
  }

  // 检查是否需要执行自动备份
  Future<void> _checkAutoBackup(
      SettingsProvider settings, DatabaseProvider dbProvider) async {
    try {
      // 检查是否启用了自动备份
      if (settings.autoBackup) {
        // 获取上次备份日期
        DateTime? lastBackupDate = settings.lastBackupDate;
        final now = DateTime.now();

        // 如果从未备份过，或者备份日志被清空导致lastBackupDate为null，则执行备份
        if (lastBackupDate == null) {
          await _performBackup(settings, dbProvider);
        } else {
          // 计算自上次备份以来的天数 - 修复日期比较问题
          // 将日期对象转换为年月日格式，忽略时间部分
          final nowDate = DateTime(now.year, now.month, now.day);
          final lastBackupDateOnly = DateTime(
              lastBackupDate.year, lastBackupDate.month, lastBackupDate.day);

          // 计算日期差异（天数）
          final difference = nowDate.difference(lastBackupDateOnly).inDays;

          // 如果超过设定的备份间隔，执行备份
          if (difference >= settings.backupInterval) {
            await _performBackup(settings, dbProvider);
          } else {
            LogManager.w('Main', '未达到备份间隔，跳过自动备份');
          }
        }
      } else {
        LogManager.w('Main', '自动备份未启用');
      }
    } catch (e) {
      LogManager.e('Main', '检查自动备份时出错', error: e);
    }
  }

  // 紧急数据库创建方法 - 当所有其他方法都失败时使用
  Future<void> _createEmergencyDatabase(
      DatabaseProvider dbProvider, SettingsProvider settings) async {
    LogManager.i('Main', '开始创建紧急SQLite数据库...');

    try {
      // 强制使用默认路径创建SQLite数据库
      await dbProvider.setDataSourceType(DataSourceType.sqlite.storageValue,
          customSqlitePath: null);

      // 确保设置被保存
      await settings.setDataSourceType(DataSourceType.sqlite.storageValue);

      LogManager.i('Main', '紧急SQLite数据库创建成功');
    } catch (e) {
      LogManager.e('Main', '紧急数据库创建失败', error: e);
      rethrow;
    }
  }

  // 执行备份操作
  Future<void> _performBackup(
      SettingsProvider settings, DatabaseProvider dbProvider) async {
    // 检查备份路径设置
    final path1 = settings.backupPath;
    final path2 = settings.backupPath2;

    if (path1.isEmpty && path2.isEmpty) {
      LogManager.e('Main', '错误：未设置备份路径，无法执行自动备份');
      return;
    }

    try {
      bool backupSuccessful = false;

      // 优先使用第一个备份路径
      if (path1.isNotEmpty) {
        await settings.setBackupPath(path1);
        await dbProvider.backupDatabase();
        backupSuccessful = true;
      }

      // 如果设置了第二个备份路径，也执行备份
      if (path2.isNotEmpty) {
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
      }

      LogManager.i('Main', '自动备份完成');
    } catch (e) {
      LogManager.e('Main', '执行自动备份时出错', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final appState = Provider.of<AppState>(context);
      final settings = Provider.of<SettingsProvider>(context);

      return MaterialApp(
        title: settings.appName,
        navigatorKey: appState.navigatorKey,
        theme: AppTheme.resolve(settings.windowsThemeVariant),
        builder: (context, child) {
          final content = child;
          if (content == null) return const SizedBox.shrink();
          return content;
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
        home: const LoginScreen(), // 始终显示登录屏幕，后台异步初始化
      );
    } catch (e) {
      LogManager.e('Main', 'AppWithProviders build错误', error: e);
      return MaterialApp(
        home: Scaffold(
          backgroundColor: context.tokens.errorContainer,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      color: context.tokens.error, size: 64),
                  const SizedBox(height: 20),
                  const Text('应用界面加载失败',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        '$e',
                        style: TextStyle(
                            fontSize: 14, color: context.colors.onSurface),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // 不再自动执行数据库结构检测，只在用户主动点击时才执行

  // 页面列表
  final List<Widget> _pages = [
    const ModernDashboardScreen(),
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
                    decoration: BoxDecoration(
                      color: context.tokens.primaryAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.medical_services,
                        color: context.tokens.cardBackground,
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
            backgroundColor: context.tokens.cardBackground,
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
  final settings = Provider.of<SettingsProvider>(context, listen: false);
  return AppTheme.resolve(settings.windowsThemeVariant);
}

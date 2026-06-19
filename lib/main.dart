import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

import 'theme/app_theme.dart';
import 'providers/database_provider.dart';
import 'providers/settings_provider.dart';
import 'utils/datetime_formatter.dart';
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
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'utils/app_paths.dart';
import 'utils/log_manager.dart';
import 'utils/single_instance.dart';
import 'services/medical_template_service.dart';



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

  // Windows平台单实例检测
  if (Platform.isWindows) {
    final isUnique = await SingleInstance.checkSingleInstance();
    if (!isUnique) {
      // 已有实例在运行，显示提示并退出
      runApp(const AlreadyRunningApp());
      // 等待一段时间让用户看到提示
      await Future.delayed(const Duration(seconds: 3));
      exit(0);
      return;
    }
  }

  // 设置全局错误处理
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🔴 Flutter UI错误: ${details.exceptionAsString()}');
    print('🔴 堆栈: ${details.stack}');
    FlutterError.dumpErrorToConsole(details, forceReport: true);
  };

  // 捕获所有异步错误
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    print('🔴 异步错误: $error');
    print('🔴 堆栈: $stack');
    return true; // 已处理
  };

  try {
    print('🟢 main(): 应用启动开始');
    
    // 初始化应用路径管理
    try {
      print('🟢 main(): 初始化应用路径...');
      await AppPaths.initialize();
      await AppPaths.initializeAllDirectories();
      print('✅ 应用路径初始化完成');
      print('✅ 应用信息: ${AppPaths.appInfo}');
      
      // 初始化日志管理器
      await LogManager.initialize();
      print('✅ 日志管理器初始化完成');
      
      // 初始化医疗模板服务（如果没有模板数据则创建默认模板）
      try {
        final hasTemplateData = await MedicalTemplateService.hasTemplateData();
        if (!hasTemplateData) {
          print('🟢 main(): 初始化默认医疗模板...');
          await MedicalTemplateService.initializeDefaultTemplates();
          print('✅ 默认医疗模板初始化完成');
        } else {
          print('✅ 医疗模板数据已存在，跳过初始化');
        }
      } catch (e) {
        print('⚠️ 医疗模板初始化失败: $e');
        // 继续，不阻止应用启动
      }
    } catch (e, stackTrace) {
      print('🔴 应用路径初始化失败: $e');
      print('🔴 堆栈: $stackTrace');
      rethrow;
    }

    // 设置Windows应用窗口
    if (Platform.isWindows) {
      try {
        print('🟢 main(): 初始化Windows窗口...');
        await windowManager.ensureInitialized();
        WindowOptions windowOptions = WindowOptions(
          title: '牙科诊所管理系统',
          titleBarStyle: TitleBarStyle.normal,
          windowButtonVisibility: true,
        );
        await windowManager.waitUntilReadyToShow(windowOptions, () async {
          await windowManager.show();
          await windowManager.focus();
        });
        print('✅ Windows窗口初始化成功');
      } catch (e, stackTrace) {
        print('⚠️ Windows窗口初始化失败: $e');
        print('⚠️ 堆栈: $stackTrace');
        // 继续运行，窗口初始化失败不应该阻止应用启动
      }
    }

    // 初始化intl日期格式
    try {
      print('🟢 main(): 初始化日期格式...');
      Intl.defaultLocale = 'zh_CN';
      await initializeDateFormatting('zh_CN', null);
      print('✅ 日期格式初始化成功');
    } catch (e, stackTrace) {
      print('⚠️ 日期格式初始化失败: $e');
      print('⚠️ 堆栈: $stackTrace');
    }

    // 在Windows和Linux平台上初始化sqflite
    if (Platform.isWindows || Platform.isLinux) {
      try {
        print('🟢 main(): 初始化数据库工厂...');
        // 初始化FFI
        sqfliteFfiInit();
        // 设置全局databaseFactory为databaseFactoryFfi
        databaseFactory = databaseFactoryFfi;
        print('✅ 数据库工厂初始化成功: $databaseFactory');
      } catch (e, stackTrace) {
        print('🔴 数据库工厂初始化失败: $e');
        print('🔴 堆栈: $stackTrace');
        rethrow;
      }
    }

    // 确保所有平台都正确设置了数据库工厂
    print('✅ 当前数据库工厂: $databaseFactory');

    print('🟢 main(): 准备启动应用...');
    runApp(const DentistApp());
  } catch (e, stackTrace) {
    print('🔴 应用启动失败: $e');
    print('🔴 堆栈: $stackTrace');
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
        backgroundColor: Colors.red.shade50,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 64),
                const SizedBox(height: 20),
                const Text('应用启动失败', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(
                      error,
                      style: const TextStyle(fontSize: 14, color: Colors.black87),
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
      home: Scaffold(
        backgroundColor: Colors.orange.shade50,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(40),
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.orange.shade700,
                  size: 80,
                ),
                const SizedBox(height: 30),
                Text(
                  '应用已在运行',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '牙科诊所管理系统已经在运行中。\n\n为了避免数据冲突，系统不允许同时运行多个实例。\n\n请在任务栏或任务管理器中找到已运行的窗口。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.orange.shade800,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Colors.orange.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '此窗口将在 3 秒后自动关闭',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
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
            final dataSourceMode = settings.dataSourceMode ?? 'global';
            final moduleDataSources = settings.moduleDataSources ?? {};
            
            // 智能初始化：根据配置模式决定数据源类型
            userProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
            );
            
            return userProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider, FinancialProvider>(
          create: (_) => FinancialProvider(),
          update: (_, dbProvider, userProvider, financialProvider) {
            financialProvider ??= FinancialProvider();
            
            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode ?? 'global';
            final moduleDataSources = settings.moduleDataSources ?? {};
            
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
            final dataSourceMode = settings.dataSourceMode ?? 'global';
            final moduleDataSources = settings.moduleDataSources ?? {};
            
            // 智能初始化：根据配置模式决定数据源类型
            materialProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
            );
            
            return materialProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider, PurchaseProvider>(
          create: (_) => PurchaseProvider(),
          update: (_, dbProvider, userProvider, purchaseProvider) {
            purchaseProvider ??= PurchaseProvider();
            
            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode ?? 'global';
            final moduleDataSources = settings.moduleDataSources ?? {};
            
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
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider, PatientProvider>(
          create: (_) => PatientProvider(),
          update: (_, dbProvider, userProvider, patientProvider) {
            patientProvider ??= PatientProvider();
            
            // 设置当前用户信息
            if (userProvider.currentUser != null) {
              patientProvider.setCurrentUser(userProvider.currentUser!);
            }
            
            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode ?? 'global';
            final moduleDataSources = settings.moduleDataSources ?? {};
            
            // 智能初始化：根据配置模式决定数据源类型
            patientProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
            );
            
            return patientProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, PatientProvider, AppointmentProvider>(
          create: (_) => AppointmentProvider(),
          update: (_, dbProvider, patientProvider, appointmentProvider) {
            appointmentProvider ??= AppointmentProvider();
            
            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode ?? 'global';
            final moduleDataSources = settings.moduleDataSources ?? {};
            
            // 智能初始化：根据配置模式决定数据源类型，并传递PatientProvider
            appointmentProvider.initializeFromDatabase(
              dbProvider,
              moduleDataSources: moduleDataSources,
              dataSourceMode: dataSourceMode,
              patientProvider: patientProvider,
            );
            
            return appointmentProvider;
          },
        ),
        ChangeNotifierProxyProvider2<DatabaseProvider, UserProvider, MedicalRecordProvider>(
          create: (_) => MedicalRecordProvider(),
          update: (_, dbProvider, userProvider, medicalRecordProvider) {
            medicalRecordProvider ??= MedicalRecordProvider();
            
            // 获取设置提供者以获取模块配置
            final settings = Provider.of<SettingsProvider>(_, listen: false);
            final dataSourceMode = settings.dataSourceMode ?? 'global';
            final moduleDataSources = settings.moduleDataSources ?? {};
            
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
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    print('🟢 AppWithProviders initState: 开始初始化Provider');
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
        print('数据源类型为空，使用默认SQLite');
        dataSourceType = 'sqlite';
        await settings.setDataSourceType('sqlite');
      }
      print('初始化数据源类型: $dataSourceType');

      // 检查数据源模式
      final dataSourceMode = settings.dataSourceMode ?? 'global';
      print('数据源模式: $dataSourceMode');

      if (dataSourceType == 'sqlite') {
        // 如果是SQLite，检查是否有自定义数据库路径
        String? sqliteDbPath = settings.sqliteDbPath;
        print('SQLite数据库路径: ${sqliteDbPath ?? "使用默认路径"}');

        // 直接在切换数据源时传递自定义路径
        await dbProvider.setDataSourceType(
          dataSourceType,
          customSqlitePath: sqliteDbPath,
        );
        // 主动选择SQLite，不是MySQL失败，所以 isFailure = false
        appState.setMySQLConnectionStatus(false, isFailure: false);
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

        try {
          // 尝试初始化MySQL连接
          await dbProvider.setDataSourceType(
            dataSourceType,
            mysqlSettings: mysqlSettings,
          );
          // MySQL连接成功
          appState.setMySQLConnectionStatus(true, isFailure: false);
        } catch (mysqlError) {
          print('MySQL连接失败，自动回退到SQLite: $mysqlError');
          // 自动回退到SQLite
          await dbProvider.setDataSourceType('sqlite');
          // 更新设置中的数据源类型
          await settings.setDataSourceType('sqlite');
          // MySQL连接失败，设置 isFailure = true
          appState.setMySQLConnectionStatus(false, isFailure: true);
        }
      } else {
        print('未知的数据源类型，使用默认SQLite');
        // 默认使用SQLite，并确保设置被保存
        await dbProvider.setDataSourceType('sqlite');
        await settings.setDataSourceType('sqlite');
        // 主动选择SQLite，不是MySQL失败
        appState.setMySQLConnectionStatus(false, isFailure: false);
      }

      // 如果是模块化模式，检查是否需要额外初始化MySQL连接
      if (dataSourceMode == 'modular') {
        final moduleDataSources = settings.moduleDataSources ?? {};
        final affectedModules = moduleDataSources.entries
            .where((entry) => entry.value == 'mysql')
            .map((entry) => entry.key)
            .toList();
        final hasMySQLModules = affectedModules.isNotEmpty;
        
        if (hasMySQLModules && dataSourceType != 'mysql') {
          print('检测到模块化模式中有MySQL模块，初始化MySQL连接...');
          
          // 初始化MySQL连接
          Map<String, dynamic> mysqlSettings = {
            'host': settings.mysqlHost ?? 'localhost',
            'port': int.tryParse(settings.mysqlPort ?? '3306') ?? 3306,
            'database': settings.mysqlDatabase ?? 'dentist_db',
            'username': settings.mysqlUsername ?? 'root',
            'password': settings.mysqlPassword ?? '',
          };

          print('MySQL设置: $mysqlSettings');

          // 初始化MySQL连接（不改变当前数据源类型）
          try {
            // 添加5秒的主级超时保险，防止长时间等待
            await dbProvider.initializeMySQLConnection(mysqlSettings).timeout(
              const Duration(seconds: 5),
              onTimeout: () {
                print('MySQL连接初始化超时，自动降级到SQLite');
                throw TimeoutException('MySQL连接超时');
              },
            );
            // MySQL连接成功
            appState.setMySQLConnectionStatus(true, affectedModules: affectedModules, isFailure: false);
          } catch (mysqlError) {
            print('模块化模式下MySQL连接失败: $mysqlError');
            // MySQL连接失败，设置 isFailure = true
            appState.setMySQLConnectionStatus(false, affectedModules: affectedModules, isFailure: true);
            
            // 当MySQL连接失败时，临时将受影响的模块数据源切换到SQLite（仅运行时，不保存）
            print('临时将受影响的模块数据源切换到SQLite（仅运行时）...');
            final temporaryModuleDataSources = Map<String, String>.from(settings.moduleDataSources);
            for (final module in affectedModules) {
              temporaryModuleDataSources[module] = 'sqlite';
              print('⏸️ 临时切换 $module 模块到SQLite（不保存设置）');
            }
            
            // 更新各个Provider的模块数据源配置（仅运行时）
            if (affectedModules.contains('purchase')) {
              final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
              purchaseProvider.updateModuleDataSources(temporaryModuleDataSources);
            }
            if (affectedModules.contains('financial')) {
              final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
              financialProvider.updateModuleDataSources(temporaryModuleDataSources);
            }
          }
        }
      }

      // 在数据库初始化后检查是否需要执行自动备份
      _checkAutoBackup(settings, dbProvider);

      final moduleDataSources = settings.moduleDataSources ?? {};
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final patientProvider = Provider.of<PatientProvider>(context, listen: false);
      await patientProvider.initializeFromDatabase(
        dbProvider,
        moduleDataSources: moduleDataSources,
        dataSourceMode: dataSourceMode,
        userProvider: userProvider,
      );

              // 设置其他提供者的数据库连接
        final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        
        // 在模块化模式下，需要同时传递SQLite和MySQL连接
        if (dataSourceMode == 'modular') {
          // 获取模块配置
          final moduleDataSources = settings.moduleDataSources ?? {};
          
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

      setState(() {
        _isInitialized = true;
      });
    } catch (e, stackTrace) {
      print('🔴 初始化时发生错误: $e');
      print('🔴 堆栈跟踪: $stackTrace');
      try {
        // 发生错误时，尝试使用默认SQLite
        print('⚠️ 尝试使用默认SQLite初始化...');
        await dbProvider.setDataSourceType('sqlite');
        // 确保设置被保存
        await settings.setDataSourceType('sqlite');
        print('✅ 默认SQLite初始化成功');
        setState(() {
          _isInitialized = true;
        });
      } catch (fallbackError, fallbackStackTrace) {
        print('🔴 默认SQLite初始化也失败: $fallbackError');
        print('🔴 堆栈跟踪: $fallbackStackTrace');
        // 最后的兜底：创建最基本的SQLite数据库
        try {
          print('⚠️ 尝试创建最基本的SQLite数据库...');
          await _createEmergencyDatabase(dbProvider, settings);
          print('✅ 紧急数据库创建成功');
          setState(() {
            _isInitialized = true;
          });
        } catch (emergencyError, emergencyStackTrace) {
          print('🔴 紧急数据库创建失败: $emergencyError');
          print('🔴 堆栈跟踪: $emergencyStackTrace');
          setState(() {
            _isInitialized = true; // 仍然标记为已初始化，但应用程序将显示错误界面
          });
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

  // 更新所有Provider的模块数据源配置
  Future<void> _updateAllProvidersModuleDataSources(SettingsProvider settings) async {
    try {
      print('开始更新所有Provider的模块数据源配置...');
      
      // 获取数据源模式和模块配置
      final dataSourceMode = settings.dataSourceMode ?? 'global';
      final moduleDataSources = settings.moduleDataSources ?? {};
      
      print('数据源模式: $dataSourceMode');
      print('模块数据源配置: $moduleDataSources');
      
      if (dataSourceMode == 'modular' && moduleDataSources.isNotEmpty) {
        // 模块化模式：更新各个Provider的模块配置
        final materialProvider = Provider.of<MaterialProvider>(context, listen: false);
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
        final appointmentProvider = Provider.of<AppointmentProvider>(context, listen: false);
        
        // 更新MaterialProvider
        if (moduleDataSources.containsKey('materials')) {
          materialProvider.updateModuleDataSources(moduleDataSources);
          print('已更新MaterialProvider的模块数据源配置: ${moduleDataSources['materials']}');
        }
        
        // 更新PurchaseProvider
        if (moduleDataSources.containsKey('purchase')) {
          purchaseProvider.updateModuleDataSources(moduleDataSources);
          print('已更新PurchaseProvider的模块数据源配置: ${moduleDataSources['purchase']}');
        }
        
        // 更新FinancialProvider
        if (moduleDataSources.containsKey('financial')) {
          financialProvider.updateModuleDataSources(moduleDataSources);
          print('已更新FinancialProvider的模块数据源配置: ${moduleDataSources['financial']}');
        }

        // AppointmentProvider已在ChangeNotifierProxyProvider中使用initializeFromDatabase初始化，无需重复初始化
        
        print('所有Provider的模块数据源配置更新完成');
      } else {
        print('使用全局数据源模式，无需更新模块配置');
      }
    } catch (e) {
      print('更新Provider模块数据源配置失败: $e');
    }
  }

  // 紧急数据库创建方法 - 当所有其他方法都失败时使用
  Future<void> _createEmergencyDatabase(
      DatabaseProvider dbProvider, SettingsProvider settings) async {
    print('开始创建紧急SQLite数据库...');
    
    try {
      // 强制使用默认路径创建SQLite数据库
      await dbProvider.setDataSourceType('sqlite', customSqlitePath: null);
      
      // 确保设置被保存
      await settings.setDataSourceType('sqlite');
      
      print('紧急SQLite数据库创建成功');
    } catch (e) {
      print('紧急数据库创建失败: $e');
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
        print('主函数中已更新最后备份日期: ${DateTimeFormatter.toDbString(todayDate)}');
      }

      print('自动备份完成');
    } catch (e) {
      print('执行自动备份时出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final appState = Provider.of<AppState>(context);
      final settings = Provider.of<SettingsProvider>(context);

      return MaterialApp(
        title: '牙科诊所管理系统',
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
        home: const LoginScreen(), // 始终显示登录屏幕，后台异步初始化
      );
    } catch (e) {
      print('🔴 AppWithProviders build错误: $e');
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.red.shade50,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 20),
                  const Text('应用界面加载失败', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        '$e',
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
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

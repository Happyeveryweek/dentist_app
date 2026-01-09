import 'package:flutter/foundation.dart';
import '../models/database_models.dart';
import '../models/schemas/table_schema.dart';
import '../models/schemas/mysql_schema.dart';
import '../models/schemas/sqlite_schema.dart';
// 患者相关模型已迁移到 PatientProvider
import '../models/material_image.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/database_config.dart';
import '../models/sync_config.dart';
import '../utils/database_utils.dart';
import '../utils/pinyin_util.dart'; // 导入拼音工具类
import '../utils/datetime_formatter.dart';
import '../utils/sync_manager.dart' as sync_manager;
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as path;
import 'dart:convert';
import 'dart:typed_data';
import 'package:mysql1/mysql1.dart';
import 'package:excel/excel.dart';
import 'dart:async'; // 添加Timer支持
import 'mysql_connection_pool.dart';

// 数据库提供者，用于管理应用程序与数据库的交互
class DatabaseProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  String _dbType = ''; // 初始化前不设置默认值，避免误导
  String _dbPath = '';
  late DatabaseConfig _dbConfig;
  bool _initialized = false;
  // 添加一个数据库变更标志，当数据库切换时会变更
  bool _databaseChanged = false;
  bool _shouldNavigateToDashboard = false; // 添加控制是否导航到仪表盘的标志

  // 用于仪表盘页面检查是否需要刷新数据
  bool _dashboardNeedsRefresh = false;
  bool get dashboardNeedsRefresh => _dashboardNeedsRefresh;

  // 缓存数据
  List<String>? _cachedDoctors;

  // 数据源具体实现
  SqliteDataSource? _sqliteDataSource;
  MySqlDataSource? _mysqlDataSource;

  // MySQL连接配置
  MySqlConnection? _mysqlConnection;
  
  // MySQL连接池
  MySQLConnectionPool? _connectionPool;
  
  // 连接状态监控
  bool _isConnected = false;
  bool _isReconnecting = false;
  Timer? _connectionHealthTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5; // 增加到5次重连尝试
  static const Duration _healthCheckInterval = Duration(seconds: 30); // 更频繁的健康检查
  static const Duration _reconnectDelay = Duration(seconds: 1); // 初始重连延迟

  // 获取连接状态
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  bool get hasConnectionIssues => !_isConnected && _dbType == 'mysql';
  
  // 获取连接状态描述
  String get connectionStatusText {
    if (_dbType != 'mysql') return '本地数据库';
    if (_isReconnecting) return '正在重连...';
    if (_isConnected) return '已连接';
    return '连接断开';
  }
  
  // 获取连接状态图标
  String get connectionStatusIcon {
    if (_dbType != 'mysql') return '💾';
    if (_isReconnecting) return '🔄';
    if (_isConnected) return '✅';
    return '❌';
  }

  // 获取数据库类型
  String get dbType => _dbType.isEmpty ? 'initializing' : _dbType;
  
  // 获取MySQL连接池
  MySQLConnectionPool? get connectionPool => _connectionPool;
  
  // 获取配置文件中设置的数据库类型（不受自动切换影响）
  String get configDbType => _dbConfig.dbType;
  
  // 获取当前实际使用的数据库类型描述
  String get currentDbTypeDescription {
    if (_isAutoSwitchedToSQLite && _dbConfig.dbType == 'mysql') {
      return 'SQLite (MySQL连接失败时自动切换)';
    }
    return _dbType == 'mysql' ? 'MySQL' : 'SQLite';
  }
  
  // 用于记录之前的数据库类型
  String _previousDbType = 'sqlite';
  String get previousDbType => _previousDbType;
  set previousDbType(String value) {
    _previousDbType = value;
  }
  
  // 标记是否是自动切换到SQLite（MySQL连接失败时）
  bool _isAutoSwitchedToSQLite = false;
  bool get isAutoSwitchedToSQLite => _isAutoSwitchedToSQLite;

  // 获取数据库路径
  String get dbPath => _dbPath;

  // 初始化标志
  bool get isInitialized => _initialized;

  // 数据库变更标志
  bool get databaseChanged => _databaseChanged;

  // 是否需要导航到仪表盘
  bool get shouldNavigateToDashboard => _shouldNavigateToDashboard;

  // 构造函数
  DatabaseProvider() {
    // 延迟初始化数据源，避免循环依赖
  }

  // 启动连接健康监控
  void _startConnectionHealthMonitoring() {
    if (_dbType == 'mysql' && _connectionHealthTimer == null) {
      print('启动MySQL连接健康监控，检查间隔: $_healthCheckInterval');
      _connectionHealthTimer = Timer.periodic(_healthCheckInterval, (timer) {
        _checkConnectionHealth();
      });
      
      // 添加更频繁的快速检查（用于检测连接丢失）
      Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_dbType == 'mysql' && !_isReconnecting) {
          _quickConnectionCheck();
        }
      });
    }
  }

  // 停止连接健康监控
  void _stopConnectionHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  // 检查连接健康状态
  Future<void> _checkConnectionHealth() async {
    if (_dbType != 'mysql' || _isReconnecting) return;
    
    try {
      print('🔍 检查MySQL连接健康状态...');
      final isHealthy = await _testConnectionHealth();
      
      if (!isHealthy && !_isReconnecting) {
        print('⚠️ 检测到连接异常，启动自动重连...');
        _isConnected = false;
        notifyListeners();
        _startAutoReconnect();
      } else if (isHealthy && !_isConnected) {
        print('✅ 连接已恢复');
        _isConnected = true;
        _reconnectAttempts = 0;
        notifyListeners();
        _markDataNeedsRefresh(); // 连接恢复后刷新数据
      }
    } catch (e) {
      print('❌ 连接健康检查失败: $e');
      if (!_isReconnecting) {
        _startAutoReconnect();
      }
    }
  }

  // 快速连接检查（轻量级检查，用于频繁检测）
  Future<void> _quickConnectionCheck() async {
    if (_dbType != 'mysql' || _isReconnecting || _mysqlConnection == null) return;
    
    try {
      // 使用更快的超时时间进行快速检查
      final results = await _mysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 2), // 进一步减少快速检查超时时间
        onTimeout: () {
          throw TimeoutException('快速连接检查超时', const Duration(seconds: 2));
        },
      );
      
      if (results.isNotEmpty && !_isConnected) {
        print('✅ 快速检查发现连接已恢复');
        _isConnected = true;
        _reconnectAttempts = 0;
        notifyListeners();
      }
    } catch (e) {
      // 快速检查失败，但不立即重连，等待完整检查
      if (_isConnected) {
        print('⚠️ 快速检查发现连接可能丢失: $e');
        _isConnected = false;
        notifyListeners();
      }
    }
  }

  // 测试连接健康状态
  Future<bool> _testConnectionHealth() async {
    if (_mysqlConnection == null) return false;
    
    try {
      // 使用简单的查询测试连接，增加超时时间以提高稳定性
      final results = await _mysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 5), // 增加超时时间以提高稳定性
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 5));
        },
      );
      
      if (results.isNotEmpty) {
        _isConnected = true;
        return true;
      }
      return false;
    } catch (e) {
      print('连接健康测试失败: $e');
      _isConnected = false;
      return false;
    }
  }

  // 测试MySQL连接（初始化时使用）
  Future<bool> _testMySQLConnection() async {
    try {
      print('正在测试MySQL连接...');
      String host = _dbConfig.mysql.host;
      final port = int.parse(_dbConfig.mysql.port);
      final database = _dbConfig.mysql.database;
      final username = _dbConfig.mysql.username;
      final password = _dbConfig.mysql.password;

      // 在Android模拟器上自动转换localhost为10.0.2.2
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        host = '10.0.2.2';
        print('Android模拟器检测到localhost，自动转换为10.0.2.2');
      }

      // 先快速测试Socket连接（1秒超时）- 快速失败
      try {
        print('快速测试Socket连接: $host:$port');
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 1), // 快速Socket检测，1秒超时
        );
        socket.destroy();
        print('Socket连接测试成功');
      } catch (e) {
        print('Socket连接测试失败（快速失败）: $e');
        return false; // Socket连接失败，直接返回false，不再尝试MySQL连接
      }

      final settings = ConnectionSettings(
        host: host,
        port: port,
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 2), // MySQL连接超时2秒（快速失败）
      );
      
      final connection = await MySqlConnection.connect(settings);
      final results = await connection.query('SELECT 1');
      await connection.close();
      
      return results.isNotEmpty;
    } catch (e) {
      print('MySQL连接测试失败: $e');
      return false;
    }
  }

  // 检查并执行数据同步
  Future<void> _checkAndSyncData() async {
    try {
      final syncConfig = await SyncConfig.loadSyncConfig();
      if (!syncConfig.syncEnabled) {
        print('数据同步已禁用');
        return;
      }

      final lastSyncStr = syncConfig.lastSyncTime;
      final syncIntervalDays = syncConfig.syncIntervalDays;
      final now = DateTime.now();
      
      if (lastSyncStr.isEmpty) {
        print('从未进行过数据同步，需要执行首次同步');
      } else {
        try {
          final lastSync = DateTimeFormatter.fromDbString(lastSyncStr);
          if (now.difference(lastSync).inDays >= syncIntervalDays) {
            print('需要执行数据同步，上次同步时间: $lastSync');
          } else {
            print('距离上次同步不足$syncIntervalDays天，跳过同步');
            return;
          }
        } catch (e) {
          print('解析上次同步时间失败，执行同步: $e');
        }
      }
      
      final syncResult = await sync_manager.SyncManager.checkAndSync();
    } catch (e) {
      print('检查数据同步时出错: $e');
    }
  }

  // 强制数据同步（供外部调用）
  Future<bool> forceDataSync() async {
    try {
      print('DatabaseProvider: 开始执行强制数据同步...');
      print('DatabaseProvider: 当前数据源类型: $_dbType');
      
      if (_dbType != 'mysql') {
        print('DatabaseProvider: 当前不是MySQL模式，无法进行数据同步');
        return false;
      }

      print('DatabaseProvider: 调用SyncManager.forceSync()...');
      final result = await sync_manager.SyncManager.forceSync();
      print('DatabaseProvider: 同步结果: $result');
      return result;
    } catch (e) {
      print('DatabaseProvider: 强制数据同步失败: $e');
      return false;
    }
  }

  // 启动自动重连（指数退避机制）
  void _startAutoReconnect() {
    if (_isReconnecting) {
      print('重连已在进行中');
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;
    
    // 指数退避延迟：1, 2, 4, 8, 16, 32秒
    final backoffDelay = Duration(seconds: (1 << (_reconnectAttempts - 1)).clamp(1, 32));
    print('🔄 开始第 $_reconnectAttempts 次重连尝试，延迟 ${backoffDelay.inSeconds} 秒...');
    notifyListeners();

    _reconnectTimer = Timer(backoffDelay, () async {
      await _performReconnect();
    });
  }

  // 执行重连
  Future<void> _performReconnect() async {
    try {
      print('🔄 正在重连MySQL数据库...');
      
      // 关闭旧连接
      if (_mysqlConnection != null) {
        try {
          await _mysqlConnection!.close();
        } catch (e) {
          print('关闭旧连接时出错: $e');
        }
        _mysqlConnection = null;
      }

      // 重新初始化连接（自动重连时允许多次重试）
      await _initMySQLConnection(isStartup: false);
      
      // 测试新连接
      final isHealthy = await _testConnectionHealth();
      if (isHealthy) {
        print('✅ 重连成功！');
        _isConnected = true;
        _isReconnecting = false;
        _reconnectAttempts = 0;
        
        // 通知所有监听器连接已恢复
        notifyListeners();
        
        // 标记需要刷新数据
        _markDataNeedsRefresh();
      } else {
        throw Exception('重连后连接测试失败');
      }
    } catch (e) {
      print('❌ 重连失败: $e');
      _isConnected = false;
      
      if (_reconnectAttempts < _maxReconnectAttempts) {
        print('🔄 将在 $_reconnectDelay 后重试...');
        _isReconnecting = false; // 重置状态以便下次重连
        _startAutoReconnect();
      } else {
        print('❌ 已达到最大重连次数，停止重连');
        _isReconnecting = false;
        notifyListeners();
      }
    }
  }

  // 标记数据需要刷新
  void _markDataNeedsRefresh() {
    _dashboardNeedsRefresh = true;
    // 通知其他Provider数据需要刷新
    notifyListeners();
  }

  // 手动重连（供UI调用）
  Future<bool> manualReconnect() async {
    if (_dbType != 'mysql') return true;
    
    print('🔄 手动重连MySQL数据库...');
    _reconnectAttempts = 0;
    _startAutoReconnect();
    
    // 等待重连完成
    while (_isReconnecting) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return _isConnected;
  }

  // 强制重连（应用恢复时使用）
  Future<bool> forceReconnect() async {
    if (_dbType != 'mysql') return true;
    
    print('🔄 强制重连MySQL数据库（应用恢复）...');
    
    // 设置重连状态
    _isReconnecting = true;
    notifyListeners();
    
    try {
      // 强制关闭现有连接
      if (_mysqlConnection != null) {
        try {
          await _mysqlConnection!.close();
          print('🔄 已关闭旧的MySQL连接');
        } catch (e) {
          print('⚠️ 关闭旧连接时出错: $e');
        }
        _mysqlConnection = null;
      }
      
      _isConnected = false;
      _reconnectAttempts = 0;
      
      // 重新建立连接（强制重连时允许多次重试）
      await _initMySQLConnection(isStartup: false);
      
      // 重置重连状态
      _isReconnecting = false;
      notifyListeners();
      
      return _isConnected;
    } catch (e) {
      print('❌ 强制重连失败: $e');
      _isConnected = false;
      _isReconnecting = false; // 确保重置状态
      notifyListeners();
      return false;
    }
  }

  // 检查并确保连接可用
  Future<bool> ensureConnection() async {
    if (_dbType != 'mysql') return true;
    
    if (_isConnected && await _testConnectionHealth()) {
      return true;
    }
    
    if (!_isReconnecting) {
      _startAutoReconnect();
    }
    
    // 等待重连完成
    while (_isReconnecting) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return _isConnected;
  }

  // 应用恢复时强制检查连接状态 - 始终创建新连接
  Future<bool> checkConnectionOnAppResume() async {
    if (_dbType != 'mysql') return true;
    
    print('🔄 应用恢复，强制重新建立MySQL连接（防止socket超时）...');
    
    try {
      // 强制关闭旧连接（不管它是否还有效）
      if (_mysqlConnection != null) {
        try {
          await _mysqlConnection!.close();
          print('🔄 已关闭旧的MySQL连接');
        } catch (e) {
          print('⚠️ 关闭旧连接时出错: $e');
        }
        _mysqlConnection = null;
      }
      
      _isConnected = false;
      _reconnectAttempts = 0;
      
      // 重新初始化连接（应用恢复时允许多次重试）
      await _initMySQLConnection(isStartup: false);
      
      if (_isConnected) {
        print('✅ 应用恢复重连成功（新socket连接）');
        _markDataNeedsRefresh();
        return true;
      } else {
        print('❌ 应用恢复重连失败');
        return false;
      }
      
    } catch (e) {
      print('❌ 应用恢复时重连失败: $e');
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // 智能连接检查（用于操作前的连接验证）
  Future<bool> smartConnectionCheck() async {
    if (_dbType != 'mysql') return true;
    
    // 如果已知连接正常，直接返回
    if (_isConnected && !_isReconnecting) {
      return true;
    }
    
    // 如果正在重连，等待重连完成
    if (_isReconnecting) {
      print('⏳ 等待重连完成...');
      int waitCount = 0;
      while (_isReconnecting && waitCount < 50) { // 最多等待5秒
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      return _isConnected;
    }
    
    // 执行连接检查
    return await ensureConnection();
  }

  // 获取当前活跃的数据源
  DataSource get _activeDataSource {
    switch (_dbType) {
      case 'sqlite':
        if (_sqliteDataSource == null) {
          _sqliteDataSource = SqliteDataSource(this);
        }
        return _sqliteDataSource!;
      case 'mysql':
        if (_mysqlDataSource == null) {
          _mysqlDataSource = MySqlDataSource(this);
        }
        return _mysqlDataSource!;
      default:
        throw Exception('不支持的数据库类型: $_dbType');
    }
  }

  // 为了兼容性，将init()方法作为initDatabase()的别名
  Future<void> init() => initDatabase();

  // 重置数据库变更标志
  void resetDatabaseChanged() {
    _databaseChanged = false;
    _shouldNavigateToDashboard = false;
  }
  
  // 重置自动切换状态（用于下次启动时重新尝试MySQL）
  void resetAutoSwitchState() {
    _isAutoSwitchedToSQLite = false;
    // 不重置_dbType，让它从配置文件重新加载
  }
  
  // 检查是否应该使用配置文件中的数据源类型
  bool _shouldUseConfigDbType() {
    // 如果是自动切换到SQLite的，但配置文件中是MySQL，则应该重新尝试MySQL
    if (_isAutoSwitchedToSQLite && _dbConfig.dbType == 'mysql') {
      return true;
    }
    return false;
  }

  // 强制设置数据库变更标志
  void forceDataChanged({bool navigateToDashboard = false}) {
    print('强制设置数据变更标志, 导航到仪表盘: $navigateToDashboard');

    // 只有明确要求导航到仪表盘时才设置全局变更标志
    if (navigateToDashboard) {
      _databaseChanged = true;
      _shouldNavigateToDashboard = true;
    } else {
      // 否则只标记仪表盘需要刷新，不导航
      _dashboardNeedsRefresh = true;
    }

    _forceInvalidateCache();
    notifyListeners();
  }

  // 患者数据刷新操作已迁移到 PatientProvider



  // 重置仪表盘刷新标志
  void resetDashboardRefreshFlag() {
    print('重置仪表盘刷新标志');
    _dashboardNeedsRefresh = false;
  }

  // 初始化数据库
  Future<void> initDatabase() async {
    if (_initialized) {
      print('数据库已经初始化，跳过初始化过程');
      return;
    }

    try {
      print('开始初始化数据库...');
      print('当前工作目录: ${Directory.current.path}');
      
      // 加载配置
      print('开始加载数据库配置...');
      _dbConfig = await DatabaseConfig.loadConfig();
      
      // 始终使用配置文件中的数据源类型，忽略之前的自动切换状态
      _dbType = _dbConfig.dbType;
      print('数据库类型: $_dbType');
      print('数据库配置: $_dbConfig');
      
      // 重置自动切换状态，确保每次启动都重新尝试配置文件中的数据源
      resetAutoSwitchState();

      // 初始化SQLite数据源（始终初始化SQLite作为备份）
      _sqliteDataSource = SqliteDataSource(this);

      // 如果是SQLite，确保路径存在
      if (_dbType == 'sqlite') {
        print('初始化SQLite数据库...');
        if (_dbConfig.sqlite.path.isEmpty) {
          // 设置默认路径
          print('SQLite路径为空，设置默认路径');
          _dbConfig.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
          print('设置的默认路径: ${_dbConfig.sqlite.path}');
          await _dbConfig.saveConfig();
        } else if (!File(_dbConfig.sqlite.path).existsSync()) {
          print('SQLite路径不存在: ${_dbConfig.sqlite.path}');
          // 确保目录存在
          final dbDir = Directory(path.dirname(_dbConfig.sqlite.path));
          if (!dbDir.existsSync()) {
            print('创建数据库目录: ${dbDir.path}');
            await dbDir.create(recursive: true);
          }
        }

        // 设置数据库路径
        _dbPath = _dbConfig.sqlite.path;
        print('SQLite数据库路径: $_dbPath');

        // 初始化SQLite数据库
        try {
          print('开始初始化DatabaseHelper...');
          await _dbHelper.database;
          print('SQLite数据库初始化成功');
        } catch (e) {
          print('SQLite数据库初始化失败: $e');
          print('错误堆栈: ${StackTrace.current}');
          throw Exception('SQLite数据库初始化失败: $e');
        }
      } else if (_dbType == 'mysql') {
        // 测试MySQL连接
        final canConnect = await _testMySQLConnection();
        bool shouldSwitchToSQLite = false;
        
        if (canConnect) {
          // 初始化MySQL连接（启动时快速失败）
          try {
            await _initMySQLConnection(isStartup: true);
            // 启动连接健康监控
            _startConnectionHealthMonitoring();
            print('MySQL数据库初始化成功');
          } catch (e) {
            shouldSwitchToSQLite = true;
          }
        } else {
          shouldSwitchToSQLite = true;
        }
        
        // 统一处理切换到SQLite的逻辑
        if (shouldSwitchToSQLite) {
          print('MySQL连接失败，自动切换到SQLite数据库');
          
          // 标记为自动切换到SQLite
          _isAutoSwitchedToSQLite = true;
          
          // 记录之前的数据库类型（保留配置中的MySQL设置）
          _previousDbType = 'mysql'; // 始终记录为mysql，不修改配置文件
          
          // 切换到SQLite（仅运行时切换，不保存到配置）
          _dbType = 'sqlite';
          // 注意：不修改 _dbConfig.dbType，保持配置文件中的mysql设置
          
          // 初始化SQLite
          await _initSQLiteWithNotification();
          
          // 只在第一次切换时设置标志，避免重复通知
          if (!_databaseChanged) {
            _databaseChanged = true;
            _shouldNavigateToDashboard = true;
          }
        }
      }

      // 测试数据库连接
      try {
        print('开始测试数据库连接...');
        if (_dbType == 'sqlite') {
          final db = await _dbHelper.database;
          print('获取到数据库实例: ${db.path}');
          await db.rawQuery('SELECT 1');
          print('数据库连接测试成功');
        } else if (_dbType == 'mysql') {
          final results = await _mysqlConnection!.query('SELECT 1');
          if (results.isNotEmpty) {
            print('数据库连接测试成功');
          } else {
            throw Exception('数据库连接测试失败: 查询返回空结果');
          }
        }
      } catch (e) {
        print('数据库连接测试失败: $e');
        print('错误堆栈: ${StackTrace.current}');
        throw Exception('数据库连接测试失败: $e');
      }

      _initialized = true;
      print('数据库初始化完成，_initialized = $_initialized');
      
      // 通知所有监听器数据库已初始化
      notifyListeners();
      
      // 仅在需要时延迟通知，避免重复触发
      if (_databaseChanged) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_initialized && _databaseChanged) {
            print('延迟通知数据库切换完成');
            notifyListeners();
          }
        });
      }
      
      // 初始化完成后，确保所有Provider都能获取到数据库实例
      await _initializeAllProviders();
      
    } catch (e) {
      debugPrint('初始化数据库错误: $e');
      print('错误堆栈: ${StackTrace.current}');
      _initialized = false;
      throw Exception('数据库初始化失败: $e');
    }
  }

  // 初始化SQLite并显示通知
  Future<void> _initSQLiteWithNotification() async {
    try {
      print('初始化SQLite数据库（带通知）...');
      
      // 设置数据库路径
      if (_dbConfig.sqlite.path.isEmpty) {
        _dbConfig.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
        await _dbConfig.saveConfig();
      }
      _dbPath = _dbConfig.sqlite.path;
      
      // 确保目录存在
      final dbDir = Directory(path.dirname(_dbPath));
      if (!dbDir.existsSync()) {
        await dbDir.create(recursive: true);
      }
      
      // 初始化SQLite数据库
      await _dbHelper.database;
      print('SQLite数据库初始化成功');
      
    } catch (e) {
      print('SQLite数据库初始化失败: $e');
      throw Exception('SQLite数据库初始化失败: $e');
    }
  }

  // 初始化所有Provider
  Future<void> _initializeAllProviders() async {
    try {
      print('开始初始化所有Provider...');
      
      // 延迟执行以确保BuildContext可用
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          // 通知所有Provider数据库已就绪
          notifyListeners();
          print('所有Provider将通过监听器获取数据库实例');
        } catch (e) {
          print('初始化Provider时出错: $e');
        }
      });
      
    } catch (e) {
      print('初始化Provider时出错: $e');
    }
  }

  // 初始化MySQL连接
  Future<void> _initMySQLConnection({bool isStartup = true}) async {
    // 启动时快速失败（只尝试1次），应用恢复时可以多次重试
    final maxRetries = isStartup ? 1 : 3;
    const retryDelay = Duration(seconds: 1); // 减少重试延迟
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('配置MySQL连接参数... 尝试第 $attempt/$maxRetries 次');
        
        // 检查并转换localhost为10.0.2.2（如果在Android平台）
        if (Platform.isAndroid &&
            (_dbConfig.mysql.host == 'localhost' ||
                _dbConfig.mysql.host == '127.0.0.1')) {
          print('Android平台检测到localhost配置，自动转换为10.0.2.2');
          _dbConfig.mysql.host = '10.0.2.2';

          // 保存更新后的配置
          await _dbConfig.saveConfig();
          print('已自动更新配置文件中的MySQL主机为10.0.2.2');
        }

        final host = _dbConfig.mysql.host;
        final port = _dbConfig.mysql.port;
        final database = _dbConfig.mysql.database;
        final username = _dbConfig.mysql.username;
        final password = _dbConfig.mysql.password;

        print('MySQL连接参数: $host:$port/$database, 用户: $username');

        // 设置连接参数 - 启动时快速失败，应用恢复时允许更长时间
      final connectionTimeout = isStartup ? const Duration(seconds: 2) : const Duration(seconds: 10);
      final settings = ConnectionSettings(
        host: host,
        port: int.parse(port),
        user: username,
        password: password,
        db: database,
        timeout: connectionTimeout, // 启动时2秒，应用恢复时10秒
        useSSL: false, // 显式禁用SSL以减少连接开销
        useCompression: false, // 禁用压缩以提高响应速度
      );

        // 先测试Socket连接
        try {
          print('测试Socket连接到MySQL: $host:$port');
          // 启动时快速失败（1秒），应用恢复时允许更长时间（3秒）
          final socketTimeout = isStartup ? const Duration(seconds: 1) : const Duration(seconds: 3);
          final socket = await Socket.connect(
            host,
            int.parse(port),
            timeout: socketTimeout,
            sourceAddress: InternetAddress.anyIPv4,
          );
          print('Socket连接成功，销毁临时Socket');
          socket.destroy();
        } catch (socketError) {
          print('Socket连接测试失败: $socketError');
          if (attempt < maxRetries) {
            print('等待 ${retryDelay.inSeconds} 秒后重试...');
            await Future.delayed(retryDelay);
            continue;
          }
          throw Exception('无法连接到MySQL服务器: $socketError');
        }

        // 尝试连接
        print('准备连接到MySQL: $host:$port/$database');

        try {
          _mysqlConnection = await MySqlConnection.connect(settings);
          
          // 设置会话字符编码，确保中文字符正确显示
          await _mysqlConnection!.query("SET NAMES 'utf8mb4'");
          await _mysqlConnection!.query("SET CHARACTER SET utf8mb4");
          await _mysqlConnection!.query("SET character_set_connection=utf8mb4");
          
          // 设置连接保持参数
          await _mysqlConnection!.query("SET wait_timeout = 28800"); // 8小时
          await _mysqlConnection!.query("SET interactive_timeout = 28800"); // 8小时
          print('MySQL字符编码和连接超时已设置');
        } catch (e) {
          print('MySQL连接错误: $e');
          if (attempt < maxRetries) {
            print('等待 ${retryDelay.inSeconds} 秒后重试...');
            await Future.delayed(retryDelay);
            continue;
          }
          
          if (e.toString().contains('SocketException')) {
            throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确');
          } else if (e.toString().contains('Access denied')) {
            throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
          } else if (e.toString().contains('Unknown database')) {
            throw Exception('数据库不存在，请检查数据库名称是否正确');
          } else {
            throw Exception('MySQL连接失败: $e');
          }
        }

        // 测试连接
        try {
          final results = await _mysqlConnection!.query('SELECT 1');
          if (results.isNotEmpty) {
            print('MySQL连接测试成功');
            _isConnected = true;
            break; // 连接成功，退出重试循环
          } else {
            if (attempt < maxRetries) {
              print('连接测试失败，重试中...');
              continue;
            }
            throw Exception('MySQL连接测试失败: 查询返回空结果');
          }
        } catch (e) {
          print('MySQL查询测试错误: $e');
          if (attempt < maxRetries) {
            print('等待 ${retryDelay.inSeconds} 秒后重试...');
            await Future.delayed(retryDelay);
            continue;
          }
          throw Exception('MySQL连接成功但查询测试失败: $e');
        }
        
      } catch (e) {
        print('MySQL连接尝试 $attempt/$maxRetries 失败: $e');
        if (attempt == maxRetries) {
          _mysqlConnection = null;
          throw Exception('MySQL连接失败: $e');
        }
        await Future.delayed(retryDelay);
      }
    }
    
    if (_isConnected) {
      // 设置数据库路径为MySQL连接信息
      _dbPath = '${_dbConfig.mysql.host}:${_dbConfig.mysql.port}/${_dbConfig.mysql.database}';
      print('MySQL数据库路径已设置: $_dbPath');
      
      // 初始化MySQL连接池
      try {
        _connectionPool = MySQLConnectionPool();
        await _connectionPool!.initialize(_dbConfig);
        print('MySQL连接池初始化成功');
      } catch (e) {
        print('MySQL连接池初始化失败: $e');
        // 连接池初始化失败不影响单连接模式的使用
      }
      
      // 启动连接健康监控
      _startConnectionHealthMonitoring();
    }
  }



  // 强制使所有缓存失效并重建
  void _forceInvalidateCache() {
    print('强制清除所有缓存数据');
          // 清空所有缓存数据
      _cachedDoctors = null;

    // 其他可能的缓存数据
    // 修改为仅标记仪表盘需要刷新，不设置全局变更标志
    _dashboardNeedsRefresh = true;
    // _databaseChanged = true;

    // 主动加载一些数据以刷新缓存
    Future.delayed(Duration.zero, () async {
      try {
        print('主动重新加载数据以更新缓存');
        if (_dbType == 'sqlite') {
          final db = await _dbHelper.database;
          // 执行一些简单查询以确保数据库连接正常
          await db.rawQuery('SELECT 1');

          // 患者数据缓存更新已迁移到 PatientProvider

          // 再次通知监听者
          notifyListeners();
        }
      } catch (e) {
        print('主动加载数据失败: $e');
      }
    });
  }

  // 查询MySQL数据
  Future<List<Map<String, dynamic>>> _queryMySQLData(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    const maxQueryRetries = 3;
    
    for (int attempt = 1; attempt <= maxQueryRetries; attempt++) {
      try {
        // 确保MySQL连接可用
        if (_mysqlConnection == null || !_isConnected) {
          print('MySQL连接不可用，尝试重新连接...');
          await _initMySQLConnection(isStartup: false);
          if (_mysqlConnection == null) {
            if (attempt < maxQueryRetries) {
              await Future.delayed(Duration(seconds: attempt));
              continue;
            }
            throw Exception('MySQL连接不可用');
          }
        }

        // 在每次查询前发送心跳包以保持连接活跃
        try {
          await _mysqlConnection!.query('SELECT 1').timeout(const Duration(seconds: 3));
        } catch (e) {
          print('心跳检测失败，标记连接为不可用');
          _isConnected = false;
          if (attempt < maxQueryRetries) {
            await Future.delayed(Duration(seconds: attempt));
            continue;
          }
          throw Exception('MySQL连接心跳检测失败');
        }

        // 构建查询语句
        String query;
        if (where != null && whereArgs != null) {
          // 使用参数化查询防止SQL注入
          if (whereArgs.isNotEmpty) {
            query = 'SELECT * FROM $table WHERE $where';
          } else {
            query = 'SELECT * FROM $table WHERE $where';
          }
        } else {
          query = 'SELECT * FROM $table';
        }

        print('执行MySQL查询: $query (尝试 $attempt/$maxQueryRetries)');
        
        Results results;
        if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
          // 使用参数化查询
          results = await _mysqlConnection!.query(query, whereArgs).timeout(
            const Duration(seconds: 30), // 增加查询超时时间
          );
        } else {
          results = await _mysqlConnection!.query(query).timeout(
            const Duration(seconds: 30),
          );
        }

        print('MySQL查询结果行数: ${results.length}');

        // 将结果转换为Map列表
        final List<Map<String, dynamic>> resultList = [];
        for (var row in results) {
          final Map<String, dynamic> rowMap = {};

          // 优化的字段处理逻辑
          for (var field in row.fields.keys) {
            // 使用原始字段名，避免不必要的转换
            String key = field;
            var value = row[field];

            // 简化的类型处理
            if (value is DateTime) {
              // 如果MySQL返回的是UTC时间，转换为本地时间
              final localDateTime = value.isUtc ? value.toLocal() : value;
              rowMap[key] = DateTimeFormatter.toDbString(localDateTime);
            } else if (value is Blob) {
              // 只转换必要的Blob字段
              try {
                final bytes = value.toBytes();
                rowMap[key] = bytes.isNotEmpty ? utf8.decode(bytes, allowMalformed: true) : '';
              } catch (e) {
                rowMap[key] = '';
              }
            } else if (value is Uint8List) {
              try {
                rowMap[key] = value.isNotEmpty ? utf8.decode(value, allowMalformed: true) : '';
              } catch (e) {
                rowMap[key] = '';
              }
            } else {
              rowMap[key] = value;
            }
          }

          resultList.add(rowMap);
        }

        return resultList;
        
      } catch (e) {
        print('MySQL查询错误 (尝试 $attempt/$maxQueryRetries): $e');
        
        if (attempt < maxQueryRetries) {
          print('等待 ${attempt} 秒后重试查询...');
          await Future.delayed(Duration(seconds: attempt));
          
          // 尝试重新连接
          try {
            if (_mysqlConnection != null) {
              await _mysqlConnection!.close();
            }
            _mysqlConnection = null;
            await _initMySQLConnection(isStartup: false);
          } catch (reconnectError) {
            print('重连失败: $reconnectError');
          }
          
          continue;
        }
        
        throw Exception('MySQL查询失败: $e');
      }
    }
    
    throw Exception('MySQL查询重试次数已用完');
  }

  // 安全获取MySQL结果中的值
  dynamic _getSafeValue(var row, String fieldName) {
    try {
      if (row.fields.containsKey(fieldName)) {
        return row[fieldName];
      }

      // 尝试查找不区分大小写的匹配
      var lowerFieldName = fieldName.toLowerCase();
      for (var key in row.fields.keys) {
        if (key.toLowerCase() == lowerFieldName) {
          return row[key];
        }
      }

      return null;
    } catch (e) {
      print('获取字段 $fieldName 值错误: $e');
      return null;
    }
  }

  // 处理日期字段
  void _processDateField(
    var row,
    Map<String, dynamic> rowMap,
    String fieldName,
  ) {
    var dateValue = _getSafeValue(row, fieldName);
    if (dateValue is DateTime) {
      // 如果MySQL返回的是UTC时间，转换为本地时间
      final localDateTime = dateValue.isUtc ? dateValue.toLocal() : dateValue;
      rowMap[fieldName] = DateTimeFormatter.toDbString(localDateTime);
    } else if (dateValue != null) {
      try {
        var date = DateTimeFormatter.fromDbString(dateValue.toString());
        rowMap[fieldName] = DateTimeFormatter.toDbString(date);
      } catch (e) {
        print('解析$fieldName错误: $e');
        rowMap[fieldName] = DateTimeFormatter.nowDbString();
      }
    } else {
      rowMap[fieldName] = DateTimeFormatter.nowDbString();
    }
  }

  // 将日期字符串转换为MySQL兼容的格式
  String _formatDateForMySQL(String dateString) {
    try {
      // 使用统一的时间格式工具解析和转换
      final date = DateTimeFormatter.fromDbString(dateString);
      return DateTimeFormatter.toDbString(date);
    } catch (e) {
      print('日期格式转换错误: $e，使用当前时间');
      return DateTimeFormatter.nowDbString();
    }
  }

  





  // 数据库配置相关操作




  // 使用参数初始化MySQL连接
  Future<void> _initMySQLConnectionWithParams(
    String host,
    String port,
    String database,
    String username,
    String password,
  ) async {
    try {
      print('使用参数初始化MySQL连接...');

      // 首先关闭已有连接
      if (_mysqlConnection != null) {
        await _mysqlConnection!.close();
        _mysqlConnection = null;
      }

      // 检查参数
      if (host.isEmpty) {
        throw Exception('MySQL主机名为空');
      }

      // 检查并转换localhost为10.0.2.2（如果在Android平台）
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        print('Android连接检测到localhost参数，自动转换为10.0.2.2');
        effectiveHost = '10.0.2.2';
      }

      // 打印所有连接参数，帮助调试
      print(
        'MySQL连接参数: host=$effectiveHost (原始值:$host), port=$port, db=$database, user=$username',
      );

      // 对于Android模拟器，如果使用10.0.2.2，记录下来
      if (effectiveHost == "10.0.2.2") {
        print('使用Android模拟器特殊主机: 10.0.2.2 (模拟器中的localhost)');
      }

      // 先测试Socket连接
      print('测试Socket连接到MySQL: $effectiveHost:$port');
      try {
        final socket = await Socket.connect(
          effectiveHost,
          int.parse(port),
          timeout: const Duration(seconds: 15),
          sourceAddress: InternetAddress.anyIPv4, // 指定使用IPv4地址
        );
        print('Socket连接成功，销毁临时Socket');
        socket.destroy();
      } catch (socketError) {
        print('Socket连接测试失败: $socketError');
        throw Exception('无法连接到MySQL服务器: $socketError');
      }

      // 创建新连接设置
      final settings = ConnectionSettings(
        host: effectiveHost, // 使用可能转换后的主机名
        port: int.parse(port),
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 20), // 增加超时时间到20秒
      );

      // 尝试连接
      print('准备连接到MySQL: $effectiveHost:$port/$database');

      try {
        _mysqlConnection = await MySqlConnection.connect(settings);
        
        // 设置会话字符编码，确保中文字符正确显示
        await _mysqlConnection!.query("SET NAMES 'utf8mb4'");
        await _mysqlConnection!.query("SET CHARACTER SET utf8mb4");
        await _mysqlConnection!.query("SET character_set_connection=utf8mb4");
        print('MySQL字符编码已设置为utf8mb4');
      } catch (e) {
        print('MySQL连接错误: $e');
        if (e.toString().contains('SocketException')) {
          throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确');
        } else if (e.toString().contains('Access denied')) {
          throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
        } else if (e.toString().contains('Unknown database')) {
          throw Exception('数据库不存在，请检查数据库名称是否正确');
        } else {
          throw Exception('MySQL连接失败: $e');
        }
      }

      // 测试连接
      try {
        final results = await _mysqlConnection!.query('SELECT 1');
        if (results.isNotEmpty) {
          print('MySQL连接测试成功');
        } else {
          throw Exception('MySQL连接测试失败: 查询返回空结果');
        }
      } catch (e) {
        print('MySQL查询测试错误: $e');
        throw Exception('MySQL连接成功但查询测试失败: $e');
      }
    } catch (e) {
      print('MySQL连接错误: $e');
      _mysqlConnection = null;
      throw Exception('MySQL连接失败: $e');
    }
  }

  // 关闭数据库连接
  Future<void> closeDatabase() async {
    print('显式关闭数据库连接');
    try {
      // 关闭SQLite连接
      await _dbHelper.closeDatabase();

      // 关闭MySQL连接
      if (_mysqlConnection != null) {
        print('关闭MySQL连接');
        await _mysqlConnection!.close();
        _mysqlConnection = null;
      }

      // 清除缓存
      _cachedDoctors = null;

      print('所有数据库连接已关闭');
    } catch (e) {
      print('关闭数据库连接错误: $e');
    }
  }



  // 获取SQLite数据库实例（供其他Provider使用）
  Future<Database?> get sqliteDatabase async {
    if (_dbType == 'sqlite' && _initialized) {
      return await _dbHelper.database;
    }
    return null;
  }

  // 获取MySQL连接（供其他Provider使用）
  MySqlConnection? get mysqlConnection {
    if (_dbType == 'mysql' && _initialized) {
      return _mysqlConnection;
    }
    return null;
  }

  // 创建MySQL数据库表
  Future<void> _createMySQLTables() async {
    try {
      if (_mysqlConnection == null) {
        throw Exception('MySQL连接未建立');
      }

      print('开始创建MySQL数据库表...');

      // 使用新的表结构系统创建所有表
      final tableNames = [
        'patients',
        'appointments',
        'financial_records',
        'financial_items',
        'materials',
        'purchase_records',
        'purchase_items',
        'patient_materials',
        'material_images',
        'users',
        'patient_medical_records',
        'medical_record_items',
        'medical_record_templates',
      ];

      for (final tableName in tableNames) {
        final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
        
        // 创建表
        await _mysqlConnection!.query(schema.createTableSql);
        
        // 创建索引
        for (final indexSql in schema.indexDefinitions) {
          await _mysqlConnection!.query(indexSql);
        }
        
        print('成功创建MySQL表: ${schema.tableName}');
      }

      print('MySQL数据库表创建完成');
    } catch (e) {
      print('创建MySQL表错误: $e');
      rethrow;
    }
  }

  // 销毁资源
  @override
  void dispose() {
    _stopConnectionHealthMonitoring();
    _mysqlConnection?.close();
    super.dispose();
  }
}

// 抽象数据源接口
abstract class DataSource {
  // 其他数据库操作方法...
}

// SQLite实现
class SqliteDataSource implements DataSource {
  final DatabaseProvider _provider;

  SqliteDataSource(this._provider);

  Future<Database> get _database async => await _provider._dbHelper.database;

 
 
}

// MySQL实现
class MySqlDataSource implements DataSource {
  final DatabaseProvider _provider;

  MySqlDataSource(this._provider);

  MySqlConnection? get _connection => _provider._mysqlConnection;

  Future<MySqlConnection> get _ensuredConnection async {
    if (_connection == null) {
      await _provider._initMySQLConnection();
      if (_provider._mysqlConnection == null) {
        throw Exception('MySQL连接不可用');
      }
    }
    return _provider._mysqlConnection!;
  }

  // MySQL专用方法 - 格式化日期
  String _formatDateForMySQL(String dateString) {
    try {
      final date = DateTimeFormatter.fromDbString(dateString);
      return DateTimeFormatter.toDbString(date);
    } catch (e) {
      print('日期格式化错误: $e');
      return DateTimeFormatter.nowDbString();
    }
  }

  // 安全获取MySQL结果中的字段值
  dynamic _getSafeValue(dynamic row, String fieldName) {
    try {
      return row[fieldName];
    } catch (e) {
      print('获取MySQL字段 $fieldName 错误: $e');
      return null;
    }
  }



}
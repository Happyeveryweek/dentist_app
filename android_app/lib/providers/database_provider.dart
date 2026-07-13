import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:async';
// 导入新创建的服务
import '../services/mysql_connection_service.dart';
import '../services/database_health_service.dart';
import '../services/mysql_reconnect_service.dart';
import '../services/sqlite_initialization_service.dart';
import '../services/database_sync_service.dart';
import '../services/database_bootstrap_service.dart';
import '../utils/app_logger.dart';

// 数据库提供者，用于管理应用程序与数据库的交互
class DatabaseProvider extends ChangeNotifier {
  // 服务实例
  final MySQLConnectionService _mysqlConnectionService =
      MySQLConnectionService();
  final DatabaseHealthService _healthService = DatabaseHealthService();
  MySQLReconnectService? _reconnectServiceInstance;
  final SQLiteInitializationService _sqliteInitService =
      SQLiteInitializationService();
  final DatabaseSyncService _syncService = DatabaseSyncService();
  final DatabaseBootstrapService _bootstrapService = DatabaseBootstrapService();

  String _dbType = ''; // 初始化前不设置默认值，避免误导
  String _dbPath = '';
  bool _initialized = false;
  // 添加一个数据库变更标志，当数据库切换时会变更
  bool _databaseChanged = false;
  bool _shouldNavigateToDashboard = false; // 添加控制是否导航到仪表盘的标志

  // 获取连接状态（从健康服务获取）
  bool get isConnected => _healthService.isConnected;
  bool get isReconnecting => _healthService.isReconnecting;

  // 获取数据库类型
  String get dbType => _dbType.isEmpty ? 'initializing' : _dbType;

  // 获取MySQL连接（从连接服务获取）
  MySqlConnection? get mysqlConnection => _mysqlConnectionService.connection;

  // 用于记录之前的数据库类型
  String previousDbType = 'sqlite';

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

  MySQLReconnectService get _reconnectService {
    final service = _reconnectServiceInstance;
    if (service == null) {
      throw StateError('MySQLReconnectService 尚未初始化');
    }
    return service;
  }

  // 构造函数
  DatabaseProvider() {
    _reconnectServiceInstance = MySQLReconnectService(
      connectionService: _mysqlConnectionService,
      healthService: _healthService,
    );

    // 设置健康检查服务的回调
    _healthService.setOnHealthStatusChanged((isConnected) {
      notifyListeners();
    });

    _reconnectService.setOnReconnectSuccess(notifyListeners);

    // 延迟初始化数据源，避免循环依赖
  }

  // 强制数据同步（供外部调用）
  Future<bool> forceDataSync() async {
    return await _syncService.forceDataSync();
  }

  // 手动重连（供UI调用）
  Future<bool> manualReconnect() async {
    if (_dbType != 'mysql') return true;
    return await _reconnectService.manualReconnect();
  }

  // 强制重连（应用恢复时使用）
  Future<bool> forceReconnect() async {
    if (_dbType != 'mysql') return true;
    return await _reconnectService.forceReconnect();
  }

  // 检查并确保连接可用
  Future<bool> ensureConnection() async {
    if (_dbType != 'mysql') return true;
    return await _reconnectService.ensureConnection();
  }

  // 应用恢复时强制检查连接状态 - 始终创建新连接
  Future<bool> checkConnectionOnAppResume() async {
    if (_dbType != 'mysql') return true;
    final result = await _reconnectService.checkConnectionOnAppResume();
    _healthService.startHealthMonitoring();
    if (result) {
      notifyListeners();
    }
    return result;
  }

  /// 应用进入后台时停止 MySQL 心跳，避免后台持续访问网络。
  void pauseMySqlHealthMonitoring() {
    if (_dbType == 'mysql') {
      _healthService.stopHealthMonitoring();
    }
  }

  // 智能连接检查（用于操作前的连接验证）
  Future<bool> smartConnectionCheck() async {
    if (_dbType != 'mysql') return true;
    return await _reconnectService.smartConnectionCheck();
  }

  // 为了兼容性，将init()方法作为initDatabase()的别名
  Future<void> init() => initDatabase();

  // 重置数据库变更标志
  void resetDatabaseChanged() {
    _databaseChanged = false;
    _shouldNavigateToDashboard = false;
  }

  // 患者数据刷新操作已迁移到 PatientProvider

  // 初始化数据库
  Future<void> initDatabase() async {
    if (_initialized) {
      AppLogger.info('数据库已经初始化，跳过初始化过程');
      return;
    }

    try {
      final result = await _bootstrapService.bootstrap(
        mysqlConnectionService: _mysqlConnectionService,
        healthService: _healthService,
        sqliteInitService: _sqliteInitService,
        syncService: _syncService,
      );

      _dbType = result.dbType;
      _dbPath = result.dbPath;
      _initialized = result.initialized;
      _databaseChanged = result.databaseChanged;
      _shouldNavigateToDashboard = result.shouldNavigateToDashboard;
      _isAutoSwitchedToSQLite = result.isAutoSwitchedToSQLite;
      previousDbType = result.previousDbType;

      notifyListeners();

      if (_databaseChanged) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_initialized && _databaseChanged) {
            AppLogger.info('延迟通知数据库切换完成');
            notifyListeners();
          }
        });
      }

      await _initializeAllProviders();
    } catch (e) {
      debugPrint('初始化数据库错误: $e');
      AppLogger.info('错误堆栈: ${StackTrace.current}');
      _initialized = false;
      throw Exception('数据库初始化失败: $e');
    }
  }

  // 初始化所有Provider
  Future<void> _initializeAllProviders() async {
    try {
      AppLogger.info('开始初始化所有Provider...');

      // 延迟执行以确保BuildContext可用
      Future.delayed(const Duration(milliseconds: 500), () async {
        try {
          // 通知所有Provider数据库已就绪
          notifyListeners();
          AppLogger.info('所有Provider将通过监听器获取数据库实例');
        } catch (e) {
          AppLogger.info('初始化Provider时出错: $e');
        }
      });
    } catch (e) {
      AppLogger.info('初始化Provider时出错: $e');
    }
  }

  // 数据库配置相关操作

  // 关闭数据库连接
  Future<void> closeDatabase() async {
    AppLogger.info('显式关闭数据库连接');
    try {
      // 关闭SQLite连接
      await _sqliteInitService.closeDatabase();

      // 关闭MySQL连接
      await _mysqlConnectionService.closeConnection();

      // 停止健康监控
      _healthService.dispose();
      _reconnectService.dispose();

      // 清除缓存

      AppLogger.info('所有数据库连接已关闭');
    } catch (e) {
      AppLogger.info('关闭数据库连接错误: $e');
    }
  }

  // 获取SQLite数据库实例（供其他Provider使用）
  Future<Database?> get sqliteDatabase async {
    if (_dbType == 'sqlite' && _initialized) {
      return await _sqliteInitService.getDatabase();
    }
    return null;
  }

  // 销毁资源
  @override
  void dispose() {
    _healthService.dispose();
    _reconnectService.dispose();
    super.dispose();
  }
}

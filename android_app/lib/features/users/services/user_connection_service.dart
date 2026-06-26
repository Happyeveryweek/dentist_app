import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import 'user_connection_state_service.dart';
import 'user_connection_health_service.dart';

/// 用户连接管理服务
/// 职责：MySQL 连接获取、连接状态检查、连接确保
class UserConnectionService {
  final UserConnectionStateService _stateService = UserConnectionStateService();
  UserConnectionHealthService? _healthServiceInstance;

  UserConnectionHealthService get _healthService {
    final service = _healthServiceInstance;
    if (service == null) {
      throw StateError('UserConnectionHealthService 尚未初始化');
    }
    return service;
  }

  // Getters
  bool get isConnected => _stateService.isConnected;
  bool get isReconnecting => _stateService.isReconnecting;
  String? get lastError => _stateService.lastError;
  String get dataSourceType => _healthService.dataSourceType;

  UserConnectionService({
    MySqlConnection? mysqlConnection,
    Database? database,
    String dataSourceType = 'sqlite',
    dynamic databaseProvider,
  }) {
    _healthServiceInstance = UserConnectionHealthService(
      stateService: _stateService,
      mysqlConnection: mysqlConnection,
      database: database,
      dataSourceType: dataSourceType,
      databaseProvider: databaseProvider,
    );
  }

  /// 设置数据库连接
  void setConnections({
    MySqlConnection? mysqlConnection,
    Database? database,
    String? dataSourceType,
    dynamic databaseProvider,
  }) {
    _healthService.setConnections(
      mysqlConnection: mysqlConnection,
      database: database,
      dataSourceType: dataSourceType,
      databaseProvider: databaseProvider,
    );
  }

  /// 获取最新的MySQL连接（防止连接过期）
  MySqlConnection? getCurrentMysqlConnection() {
    return _healthService.getCurrentMysqlConnection();
  }

  /// 获取SQLite数据库连接
  Database? getSqliteDatabase() {
    return _healthService.getSqliteDatabase();
  }

  /// 检查数据库是否已初始化
  bool isInitialized() {
    return _healthService.isInitialized();
  }

  /// 测试MySQL连接
  Future<bool> testMySqlConnection() async {
    return _healthService.testMySqlConnection();
  }

  /// 测试SQLite连接
  Future<bool> testSQLiteConnection() async {
    return _healthService.testSQLiteConnection();
  }

  /// 确保连接可用
  Future<bool> ensureConnection() async {
    return _healthService.ensureConnection();
  }

  /// 重置连接状态
  void resetConnectionState() {
    _stateService.resetConnectionState();
  }

  /// 设置重连状态
  void setReconnecting(bool reconnecting) {
    _stateService.setReconnecting(reconnecting);
  }
}

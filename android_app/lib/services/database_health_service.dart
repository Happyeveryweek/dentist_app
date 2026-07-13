import 'dart:async';
import 'package:mysql1/mysql1.dart';
import '../utils/app_logger.dart';

/// 数据库健康检查服务
/// 职责：连接健康检查、快速检查、健康监控定时器
class DatabaseHealthService {
  MySqlConnection? _mysqlConnection;
  Timer? _connectionHealthTimer;
  bool _isCheckingConnection = false;

  // 连接状态
  bool _isConnected = false;
  bool _isReconnecting = false;

  // 健康检查配置
  static const Duration _healthCheckInterval = Duration(seconds: 30);

  // 回调函数
  Function(bool)? _onHealthStatusChanged;
  Function()? _onReconnectNeeded;

  /// 获取连接状态
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;

  /// 设置 MySQL 连接
  void setConnection(MySqlConnection? connection) {
    _mysqlConnection = connection;
  }

  /// 设置连接状态
  void setConnectionStatus(bool connected) {
    _isConnected = connected;
  }

  /// 设置重连状态
  void setReconnectingStatus(bool reconnecting) {
    _isReconnecting = reconnecting;
  }

  /// 设置健康状态变化回调
  void setOnHealthStatusChanged(Function(bool) callback) {
    _onHealthStatusChanged = callback;
  }

  /// 设置需要重连回调
  void setOnReconnectNeeded(Function() callback) {
    _onReconnectNeeded = callback;
  }

  /// 启动连接健康监控
  void startHealthMonitoring() {
    if (_connectionHealthTimer == null) {
      AppLogger.info('启动MySQL连接健康监控，检查间隔: $_healthCheckInterval');
      _connectionHealthTimer = Timer.periodic(_healthCheckInterval, (timer) {
        unawaited(_checkConnectionHealth());
      });
    }
  }

  /// 停止连接健康监控
  void stopHealthMonitoring() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  /// 等待正在执行的健康检查结束，避免重连时关闭仍在查询的 socket。
  Future<void> waitForHealthCheckToFinish() async {
    while (_isCheckingConnection) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
  }

  /// 检查连接健康状态
  Future<void> _checkConnectionHealth() async {
    if (_isReconnecting || _isCheckingConnection) return;

    _isCheckingConnection = true;

    try {
      final isHealthy = await testConnectionHealth();

      if (!isHealthy && !_isReconnecting) {
        AppLogger.info('⚠️ 检测到连接异常，启动自动重连...');
        _isConnected = false;
        _onHealthStatusChanged?.call(false);
        _onReconnectNeeded?.call();
      } else if (isHealthy && !_isConnected) {
        AppLogger.info('✅ 连接已恢复');
        _isConnected = true;
        _onHealthStatusChanged?.call(true);
      }
    } catch (e) {
      AppLogger.info('❌ 连接健康检查失败: $e');
      if (!_isReconnecting) {
        _onReconnectNeeded?.call();
      }
    } finally {
      _isCheckingConnection = false;
    }
  }

  /// 测试连接健康状态
  Future<bool> testConnectionHealth() async {
    final connection = _mysqlConnection;
    if (connection == null) return false;

    try {
      // 使用简单的查询测试连接，增加超时时间以提高稳定性
      final results = await connection
          .query('SELECT 1')
          .timeout(
            const Duration(seconds: 5),
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
      AppLogger.info('连接健康测试失败: $e');
      _isConnected = false;
      return false;
    }
  }

  /// 销毁资源
  void dispose() {
    stopHealthMonitoring();
  }
}

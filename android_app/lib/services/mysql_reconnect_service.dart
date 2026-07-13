import 'dart:async';
import 'mysql_connection_service.dart';
import 'database_health_service.dart';
import '../utils/app_logger.dart';

/// MySQL 自动重连服务
/// 职责：自动重连逻辑、指数退避、重连状态管理
class MySQLReconnectService {
  final MySQLConnectionService _connectionService;
  final DatabaseHealthService _healthService;

  static const int _maxReconnectAttempts = 5;
  Future<bool>? _activeReconnect;

  // 回调函数
  Function()? _onReconnectSuccess;

  /// 获取重连状态
  bool get isReconnecting => _healthService.isReconnecting;

  /// 构造函数
  MySQLReconnectService({
    required MySQLConnectionService connectionService,
    required DatabaseHealthService healthService,
  }) : _connectionService = connectionService,
       _healthService = healthService {
    // 设置健康检查服务的回调
    _healthService.setOnReconnectNeeded(_startAutoReconnect);
  }

  /// 设置重连成功回调
  void setOnReconnectSuccess(Function() callback) {
    _onReconnectSuccess = callback;
  }

  /// 启动自动重连（指数退避机制）
  void _startAutoReconnect() {
    unawaited(_reconnect('健康检查发现连接异常'));
  }

  /// 串行重建连接，避免查询和关闭同一个 socket 并发发生。
  Future<bool> _reconnect(String reason) {
    final activeReconnect = _activeReconnect;
    if (activeReconnect != null) {
      return activeReconnect;
    }

    final reconnect = _performReconnect(reason);
    _activeReconnect = reconnect;
    unawaited(
      reconnect.whenComplete(() {
        if (identical(_activeReconnect, reconnect)) {
          _activeReconnect = null;
        }
      }),
    );
    return reconnect;
  }

  /// 执行重连
  Future<bool> _performReconnect(String reason) async {
    await _healthService.waitForHealthCheckToFinish();
    _healthService.setReconnectingStatus(true);
    try {
      for (var attempt = 1; attempt <= _maxReconnectAttempts; attempt++) {
        try {
          AppLogger.info('🔄 $reason，开始第 $attempt 次重连尝试...');
          await _connectionService.closeConnection();
          await _connectionService.initConnection(isStartup: false);
          _healthService.setConnection(_connectionService.connection);

          if (await _healthService.testConnectionHealth()) {
            _healthService.setConnectionStatus(true);
            AppLogger.info('✅ MySQL重连成功');
            _onReconnectSuccess?.call();
            return true;
          }
        } catch (e) {
          AppLogger.info('❌ MySQL第 $attempt 次重连失败: $e');
        }

        if (attempt < _maxReconnectAttempts) {
          final delay = Duration(seconds: 1 << (attempt - 1));
          await Future.delayed(delay);
        }
      }
      AppLogger.info('❌ 已达到最大重连次数，停止重连');
      _healthService.setConnectionStatus(false);
      return false;
    } finally {
      _healthService.setReconnectingStatus(false);
    }
  }

  /// 手动重连（供UI调用）
  Future<bool> manualReconnect() async {
    AppLogger.info('🔄 手动重连MySQL数据库...');
    return _reconnect('用户手动发起重连');
  }

  /// 强制重连（应用恢复时使用）
  Future<bool> forceReconnect() async {
    AppLogger.info('🔄 强制重连MySQL数据库（应用恢复）...');
    return _reconnect('强制重建MySQL连接');
  }

  /// 检查并确保连接可用
  Future<bool> ensureConnection() async {
    final activeReconnect = _activeReconnect;
    if (activeReconnect != null) {
      return activeReconnect;
    }

    if (_healthService.isConnected &&
        await _healthService.testConnectionHealth()) {
      return true;
    }
    return _reconnect('业务操作前连接检查失败');
  }

  /// 应用恢复时强制检查连接状态 - 始终创建新连接
  Future<bool> checkConnectionOnAppResume() async {
    AppLogger.info('🔄 应用恢复，强制重新建立MySQL连接（防止socket超时）...');
    return _reconnect('应用恢复，重建MySQL连接');
  }

  /// 智能连接检查（用于操作前的连接验证）
  Future<bool> smartConnectionCheck() async {
    // 如果已知连接正常，直接返回
    if (_healthService.isConnected && !_healthService.isReconnecting) {
      return true;
    }

    // 如果正在重连，等待重连完成
    final activeReconnect = _activeReconnect;
    if (activeReconnect != null) {
      AppLogger.info('⏳ 等待重连完成...');
      return activeReconnect;
    }

    // 执行连接检查
    return await ensureConnection();
  }

  /// 销毁资源
  void dispose() {}
}

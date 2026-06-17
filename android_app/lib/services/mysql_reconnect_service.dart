import 'dart:async';
import 'mysql_connection_service.dart';
import 'database_health_service.dart';

/// MySQL 自动重连服务
/// 职责：自动重连逻辑、指数退避、重连状态管理
class MySQLReconnectService {
  final MySQLConnectionService _connectionService;
  final DatabaseHealthService _healthService;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 1);

  // 回调函数
  Function()? _onReconnectSuccess;
  Function()? _onReconnectFailed;

  /// 获取重连状态
  bool get isReconnecting => _healthService.isReconnecting;
  int get reconnectAttempts => _reconnectAttempts;

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

  /// 设置重连失败回调
  void setOnReconnectFailed(Function() callback) {
    _onReconnectFailed = callback;
  }

  /// 启动自动重连（指数退避机制）
  void _startAutoReconnect() {
    if (_healthService.isReconnecting) {
      print('重连已在进行中');
      return;
    }

    _healthService.setReconnectingStatus(true);
    _reconnectAttempts++;

    // 指数退避延迟：1, 2, 4, 8, 16, 32秒
    final backoffDelay = Duration(
      seconds: (1 << (_reconnectAttempts - 1)).clamp(1, 32),
    );
    print('🔄 开始第 $_reconnectAttempts 次重连尝试，延迟 ${backoffDelay.inSeconds} 秒...');

    _reconnectTimer = Timer(backoffDelay, () async {
      await _performReconnect();
    });
  }

  /// 执行重连
  Future<void> _performReconnect() async {
    try {
      print('🔄 正在重连MySQL数据库...');

      // 关闭旧连接
      await _connectionService.closeConnection();

      // 重新初始化连接（自动重连时允许多次重试）
      await _connectionService.initConnection(isStartup: false);
      _healthService.setConnection(_connectionService.connection);

      // 测试新连接
      final isHealthy = await _healthService.testConnectionHealth();
      if (isHealthy) {
        print('✅ 重连成功！');
        _healthService.setConnectionStatus(true);
        _healthService.setReconnectingStatus(false);
        _reconnectAttempts = 0;

        // 通知重连成功
        _onReconnectSuccess?.call();
      } else {
        throw Exception('重连后连接测试失败');
      }
    } catch (e) {
      print('❌ 重连失败: $e');
      _healthService.setConnectionStatus(false);

      if (_reconnectAttempts < _maxReconnectAttempts) {
        print('🔄 将在 $_reconnectDelay 后重试...');
        _healthService.setReconnectingStatus(false); // 重置状态以便下次重连
        _startAutoReconnect();
      } else {
        print('❌ 已达到最大重连次数，停止重连');
        _healthService.setReconnectingStatus(false);
        _onReconnectFailed?.call();
      }
    }
  }

  /// 手动重连（供UI调用）
  Future<bool> manualReconnect() async {
    print('🔄 手动重连MySQL数据库...');
    _reconnectAttempts = 0;
    _startAutoReconnect();

    // 等待重连完成
    while (_healthService.isReconnecting) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return _healthService.isConnected;
  }

  /// 强制重连（应用恢复时使用）
  Future<bool> forceReconnect() async {
    print('🔄 强制重连MySQL数据库（应用恢复）...');

    // 设置重连状态
    _healthService.setReconnectingStatus(true);

    try {
      // 强制关闭现有连接
      await _connectionService.closeConnection();

      _healthService.setConnectionStatus(false);
      _reconnectAttempts = 0;

      // 重新建立连接（强制重连时允许多次重试）
      await _connectionService.initConnection(isStartup: false);
      _healthService.setConnection(_connectionService.connection);

      final isHealthy = await _healthService.testConnectionHealth();
      _healthService.setConnectionStatus(isHealthy);

      // 重置重连状态
      _healthService.setReconnectingStatus(false);

      return isHealthy;
    } catch (e) {
      print('❌ 强制重连失败: $e');
      _healthService.setConnectionStatus(false);
      _healthService.setReconnectingStatus(false); // 确保重置状态
      return false;
    }
  }

  /// 检查并确保连接可用
  Future<bool> ensureConnection() async {
    if (_healthService.isConnected &&
        await _healthService.testConnectionHealth()) {
      return true;
    }

    if (!_healthService.isReconnecting) {
      _startAutoReconnect();
    }

    // 等待重连完成
    while (_healthService.isReconnecting) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return _healthService.isConnected;
  }

  /// 应用恢复时强制检查连接状态 - 始终创建新连接
  Future<bool> checkConnectionOnAppResume() async {
    print('🔄 应用恢复，强制重新建立MySQL连接（防止socket超时）...');

    try {
      // 强制关闭旧连接（不管它是否还有效）
      await _connectionService.closeConnection();

      _healthService.setConnectionStatus(false);
      _reconnectAttempts = 0;

      // 重新初始化连接（应用恢复时允许多次重试）
      await _connectionService.initConnection(isStartup: false);
      _healthService.setConnection(_connectionService.connection);

      final isHealthy = await _healthService.testConnectionHealth();
      _healthService.setConnectionStatus(isHealthy);

      if (isHealthy) {
        print('✅ 应用恢复重连成功（新socket连接）');
        return true;
      } else {
        print('❌ 应用恢复重连失败');
        return false;
      }
    } catch (e) {
      print('❌ 应用恢复时重连失败: $e');
      _healthService.setConnectionStatus(false);
      return false;
    }
  }

  /// 智能连接检查（用于操作前的连接验证）
  Future<bool> smartConnectionCheck() async {
    // 如果已知连接正常，直接返回
    if (_healthService.isConnected && !_healthService.isReconnecting) {
      return true;
    }

    // 如果正在重连，等待重连完成
    if (_healthService.isReconnecting) {
      print('⏳ 等待重连完成...');
      int waitCount = 0;
      while (_healthService.isReconnecting && waitCount < 50) {
        // 最多等待5秒
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      return _healthService.isConnected;
    }

    // 执行连接检查
    return await ensureConnection();
  }

  /// 重置重连状态
  void resetReconnectState() {
    _reconnectAttempts = 0;
    _healthService.setReconnectingStatus(false);
  }

  /// 销毁资源
  void dispose() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
}

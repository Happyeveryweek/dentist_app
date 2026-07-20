import 'dart:async';
import 'package:mysql1/mysql1.dart';
import '../utils/log_manager.dart';
import '../config/app_defaults.dart';

/// MySQL连接管理器 - 统一处理连接验证、重连和健康检查
///
/// 功能：
/// 1. 自动验证连接有效性
/// 2. 连接失效时自动重连
/// 3. 提供健康检查机制
/// 4. 统一的错误处理
class MySqlConnectionManager {
  final Future<MySqlConnection?> Function() _connectionProvider;
  final Future<void> Function()? _reconnectCallback;

  MySqlConnection? _cachedConnection;
  DateTime? _lastValidationTime;

  // 连接验证间隔（避免频繁验证）
  static const Duration _validationInterval =
      MySqlConnectionPolicy.healthCheckInterval;

  // 连接验证超时时间
  static const Duration _validationTimeout =
      MySqlConnectionPolicy.validationTimeout;

  MySqlConnectionManager({
    required Future<MySqlConnection?> Function() connectionProvider,
    Future<void> Function()? reconnectCallback,
  })  : _connectionProvider = connectionProvider,
        _reconnectCallback = reconnectCallback;

  /// 获取有效的MySQL连接
  ///
  /// 工作流程：
  /// 1. 检查缓存的连接是否需要验证
  /// 2. 如果需要验证，执行健康检查
  /// 3. 如果连接失效，尝试重新获取
  /// 4. 返回有效的连接或null
  Future<MySqlConnection?> getConnection() async {
    try {
      // 如果有缓存连接且最近验证过，直接返回
      if (_cachedConnection != null && _isRecentlyValidated()) {
        return _cachedConnection;
      }

      // 获取连接（可能是新连接或现有连接）
      final connection = await _connectionProvider();
      if (connection == null) {
        LogManager.w(
            'MysqlConnectionManager', '⚠️ MySqlConnectionManager: 无法获取MySQL连接');
        return null;
      }

      // 验证连接是否有效
      final isValid = await _validateConnection(connection);

      if (isValid) {
        // 连接有效，缓存并返回
        _cachedConnection = connection;
        _lastValidationTime = DateTime.now();
        return connection;
      } else {
        // 连接失效，尝试重连
        LogManager.w('MysqlConnectionManager',
            '⚠️ MySqlConnectionManager: 连接失效，尝试重新连接...');
        _cachedConnection = null;
        _lastValidationTime = null;

        // 调用重连回调
        final reconnect = _reconnectCallback;
        if (reconnect != null) {
          await reconnect();

          // 重新获取连接
          final newConnection = await _connectionProvider();
          if (newConnection != null) {
            final isNewValid = await _validateConnection(newConnection);
            if (isNewValid) {
              _cachedConnection = newConnection;
              _lastValidationTime = DateTime.now();
              LogManager.i(
                  'MysqlConnectionManager', '✅ MySqlConnectionManager: 重新连接成功');
              return newConnection;
            }
          }
        }

        LogManager.e(
            'MysqlConnectionManager', '❌ MySqlConnectionManager: 重新连接失败');
        return null;
      }
    } catch (e) {
      LogManager.e(
          'MysqlConnectionManager', '❌ MySqlConnectionManager: 获取连接时发生错误',
          error: e);
      _cachedConnection = null;
      _lastValidationTime = null;
      return null;
    }
  }

  /// 验证连接是否有效
  ///
  /// 通过执行简单的SELECT 1查询来测试连接
  Future<bool> _validateConnection(MySqlConnection connection) async {
    try {
      await connection.query('SELECT 1').timeout(
        _validationTimeout,
        onTimeout: () {
          throw TimeoutException('连接验证超时');
        },
      );
      return true;
    } catch (e) {
      LogManager.e(
          'MysqlConnectionManager', '⚠️ MySqlConnectionManager: 连接验证失败',
          error: e);
      return false;
    }
  }

  /// 检查连接是否最近验证过
  bool _isRecentlyValidated() {
    final lastTime = _lastValidationTime;
    if (lastTime == null) return false;
    final elapsed = DateTime.now().difference(lastTime);
    return elapsed < _validationInterval;
  }

  /// 强制重新验证连接
  ///
  /// 用于在关键操作前确保连接有效
  Future<bool> forceValidate() async {
    _lastValidationTime = null; // 清除验证时间，强制重新验证
    final connection = await getConnection();
    return connection != null;
  }

  /// 清除缓存的连接
  ///
  /// 用于手动触发重连或清理资源
  void clearCache() {
    _cachedConnection = null;
    _lastValidationTime = null;
  }
}

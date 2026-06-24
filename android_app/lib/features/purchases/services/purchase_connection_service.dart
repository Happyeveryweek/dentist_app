import 'dart:async';
import 'package:mysql1/mysql1.dart';
import '../../../utils/app_logger.dart';

/// 采购数据连接服务
/// 职责：MySQL 连接测试、连接确保、自动重连、错误处理
class PurchaseConnectionService {
  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;

  // Getters
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  String? get lastError => _lastError;

  /// 测试MySQL连接是否有效
  Future<bool> testMySqlConnection(MySqlConnection? connection) async {
    if (connection == null) return false;

    try {
      // 执行一个简单的查询来测试连接
      await connection
          .query('SELECT 1')
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('连接测试超时', const Duration(seconds: 10));
            },
          );
      _isConnected = true;
      _clearError();
      return true;
    } catch (e) {
      AppLogger.info('MySQL连接测试失败: $e');
      // 如果连接失败，标记连接为无效
      _setError('MySQL连接测试失败: $e');
      return false;
    }
  }

  /// 检查并确保连接可用
  Future<bool> ensureConnection(MySqlConnection? connection) async {
    if (connection == null) return false;

    try {
      // 测试连接
      await connection
          .query('SELECT 1')
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('连接测试超时', const Duration(seconds: 10));
            },
          );
      _isConnected = true;
      _clearError();
      return true;
    } catch (e) {
      AppLogger.info('PurchaseProvider: 连接检查失败: $e');
      _setError('数据库连接失败: $e');
      return false;
    }
  }

  /// 自动重连
  Future<bool> autoReconnect(MySqlConnection? connection) async {
    if (_isReconnecting) return false;

    _isReconnecting = true;

    try {
      AppLogger.info('PurchaseProvider: 尝试自动重连...');

      // 等待一段时间后重试
      await Future.delayed(const Duration(seconds: 3));

      // 重新检查连接
      final success = await ensureConnection(connection);

      if (success) {
        AppLogger.info('PurchaseProvider: 自动重连成功');
        _isReconnecting = false;
        return true;
      } else {
        throw Exception('重连失败');
      }
    } catch (e) {
      AppLogger.info('PurchaseProvider: 自动重连失败: $e');
      _isReconnecting = false;
      return false;
    }
  }

  /// 清除错误状态
  void _clearError() {
    _lastError = null;
  }

  /// 设置错误状态
  void _setError(String error) {
    _lastError = error;
    _isConnected = false;
  }

  /// 重置连接状态（用于外部重置）
  void resetConnectionState() {
    _isConnected = true;
    _isReconnecting = false;
    _lastError = null;
  }
}

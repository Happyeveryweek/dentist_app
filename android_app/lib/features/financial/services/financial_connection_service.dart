import 'package:mysql1/mysql1.dart';
import 'dart:async';

/// 财务连接管理服务
/// 职责：管理财务数据的连接状态、自动重连、错误处理
class FinancialConnectionService {
  MySqlConnection? _mysqlConnection;
  dynamic _databaseProvider;
  String _dataSourceType = 'sqlite';

  // 连接状态
  bool _isConnected = true;
  bool _isReconnecting = false;
  String? _lastError;

  /// 获取连接状态
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  String? get lastError => _lastError;

  /// 设置数据源类型
  void setDataSourceType(String dataSourceType) {
    _dataSourceType = dataSourceType;
  }

  /// 设置数据库提供者
  void setDatabaseProvider(dynamic dbProvider) {
    _databaseProvider = dbProvider;
  }

  /// 设置 MySQL 连接
  void setMysqlConnection(MySqlConnection? connection) {
    _mysqlConnection = connection;
  }

  /// 获取最新的 MySQL 连接（防止连接过期）
  MySqlConnection? get currentMysqlConnection {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }
    
    // 每次都从DatabaseProvider获取最新连接
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        _mysqlConnection = latestConnection;
        return latestConnection;
      }
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
    }
    
    return _mysqlConnection;
  }

  /// 清除错误状态
  void clearError() {
    _lastError = null;
  }

  /// 设置错误状态
  void setError(String error) {
    _lastError = error;
    _isConnected = false;
  }

  /// 检查并确保连接可用
  Future<bool> ensureConnection() async {
    if (_dataSourceType != 'mysql') return true;
    
    final conn = currentMysqlConnection;
    if (conn == null) return false;
    
    try {
      // 测试连接
      await conn.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      _isConnected = true;
      clearError();
      return true;
    } catch (e) {
      print('FinancialConnectionService: 连接检查失败: $e');
      setError('数据库连接失败: $e');
      return false;
    }
  }

  /// 自动重连
  Future<bool> autoReconnect() async {
    if (_isReconnecting) return false;
    
    _isReconnecting = true;
    
    try {
      print('FinancialConnectionService: 尝试自动重连...');
      
      // 等待一段时间后重试
      await Future.delayed(const Duration(seconds: 3));
      
      // 重新检查连接
      final success = await ensureConnection();
      
      if (success) {
        print('FinancialConnectionService: 自动重连成功');
        _isReconnecting = false;
        return true;
      } else {
        throw Exception('重连失败');
      }
    } catch (e) {
      print('FinancialConnectionService: 自动重连失败: $e');
      _isReconnecting = false;
      return false;
    }
  }
}

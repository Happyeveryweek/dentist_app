import 'dart:async';
import 'dart:io';
import 'package:mysql1/mysql1.dart';
import '../models/database_config.dart';

/// MySQL连接池管理器
class MySQLConnectionPool {
  static final MySQLConnectionPool _instance = MySQLConnectionPool._internal();
  factory MySQLConnectionPool() => _instance;
  MySQLConnectionPool._internal();

  // 连接池配置
  final int _maxConnections = 5; // 最大连接数
  final int _minConnections = 2; // 最小连接数
  final Duration _idleTimeout = const Duration(minutes: 5); // 空闲超时
  final Duration _maxWaitTime = const Duration(seconds: 30); // 最大等待时间

  // 连接池状态
  final List<MySqlConnection> _availableConnections = [];
  final List<MySqlConnection> _busyConnections = [];
  final List<Completer<MySqlConnection>> _waitingQueue = [];
  
  // 连接统计
  int _totalConnections = 0;
  int _activeConnections = 0;
  
  // 配置信息
  ConnectionSettings? _settings;
  bool _isInitialized = false;
  
  // 定时器
  Timer? _cleanupTimer;

  /// 初始化连接池
  Future<void> initialize(DatabaseConfig config) async {
    if (_isInitialized) return;
    
    _settings = ConnectionSettings(
      host: config.mysql.host,
      port: int.parse(config.mysql.port),
      user: config.mysql.username,
      password: config.mysql.password,
      db: config.mysql.database,
      timeout: const Duration(seconds: 30),
    );

    // 创建最小连接数
    await _createInitialConnections();
    
    // 启动清理定时器
    _startCleanupTimer();
    
    _isInitialized = true;
    print('MySQL连接池已初始化，当前连接数: $_totalConnections');
  }

  /// 创建初始连接
  Future<void> _createInitialConnections() async {
    for (int i = 0; i < _minConnections; i++) {
      try {
        final connection = await _createConnection();
        _availableConnections.add(connection);
        _totalConnections++;
      } catch (e) {
        print('创建初始连接失败: $e');
      }
    }
  }

  /// 创建新连接
  Future<MySqlConnection> _createConnection() async {
    try {
      final connection = await MySqlConnection.connect(_settings!);
      
      // 设置字符编码
      await connection.query("SET NAMES 'utf8mb4'");
      await connection.query("SET CHARACTER SET utf8mb4");
      await connection.query("SET character_set_connection=utf8mb4");
      
      return connection;
    } catch (e) {
      print('创建MySQL连接失败: $e');
      throw Exception('创建MySQL连接失败: $e');
    }
  }

  /// 获取连接
  Future<MySqlConnection> getConnection() async {
    if (!_isInitialized) {
      throw Exception('连接池未初始化');
    }

    final completer = Completer<MySqlConnection>();
    
    // 如果有可用连接，直接返回
    if (_availableConnections.isNotEmpty) {
      final connection = _availableConnections.removeAt(0);
      _busyConnections.add(connection);
      _activeConnections++;
      return connection;
    }

    // 如果未达到最大连接数，创建新连接
    if (_totalConnections < _maxConnections) {
      try {
        final connection = await _createConnection();
        _busyConnections.add(connection);
        _totalConnections++;
        _activeConnections++;
        return connection;
      } catch (e) {
        print('创建新连接失败，加入等待队列: $e');
      }
    }

    // 加入等待队列
    _waitingQueue.add(completer);
    
    // 设置超时
    Timer(_maxWaitTime, () {
      if (!completer.isCompleted) {
        completer.completeError(Exception('获取连接超时'));
        _waitingQueue.remove(completer);
      }
    });

    return completer.future;
  }

  /// 归还连接
  Future<void> releaseConnection(MySqlConnection connection) async {
    if (!_busyConnections.contains(connection)) {
      return;
    }

    _busyConnections.remove(connection);
    _activeConnections--;

    // 检查连接是否仍然有效
    try {
      await connection.query('SELECT 1');
      
      // 如果有等待的客户端，直接分配
      if (_waitingQueue.isNotEmpty) {
        final completer = _waitingQueue.removeAt(0);
        if (!completer.isCompleted) {
          _busyConnections.add(connection);
          _activeConnections++;
          completer.complete(connection);
        }
      } else {
        // 放回可用连接池
        _availableConnections.add(connection);
      }
    } catch (e) {
      // 连接已失效，关闭并创建新连接
      try {
        await connection.close();
      } catch (_) {}
      _totalConnections--;
      
      // 补充连接池
      if (_totalConnections < _minConnections) {
        try {
          final newConnection = await _createConnection();
          _availableConnections.add(newConnection);
          _totalConnections++;
        } catch (_) {}
      }
    }
  }

  /// 执行查询（自动管理连接）
  Future<Results> query(String sql, [List<Object?>? values]) async {
    final connection = await getConnection();
    try {
      final results = await connection.query(sql, values);
      return results;
    } finally {
      await releaseConnection(connection);
    }
  }

  /// 执行事务
  Future<T> transaction<T>(Future<T> Function(MySqlConnection) action) async {
    final connection = await getConnection();
    try {
      await connection.query('START TRANSACTION');
      final result = await action(connection);
      await connection.query('COMMIT');
      return result;
    } catch (e) {
      await connection.query('ROLLBACK');
      rethrow;
    } finally {
      await releaseConnection(connection);
    }
  }

  /// 获取连接池状态
  Map<String, dynamic> getPoolStats() {
    return {
      'totalConnections': _totalConnections,
      'activeConnections': _activeConnections,
      'availableConnections': _availableConnections.length,
      'busyConnections': _busyConnections.length,
      'waitingQueue': _waitingQueue.length,
    };
  }

  /// 清理空闲连接
  Future<void> _cleanupIdleConnections() async {
    final now = DateTime.now();
    
    // 清理过期的可用连接
    if (_availableConnections.length > _minConnections) {
      final connectionsToRemove = _availableConnections.length - _minConnections;
      for (int i = 0; i < connectionsToRemove; i++) {
        final connection = _availableConnections.removeAt(0);
        try {
          await connection.close();
        } catch (_) {}
        _totalConnections--;
      }
    }
  }

  /// 启动清理定时器
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _cleanupIdleConnections();
    });
  }

  /// 关闭连接池
  Future<void> close() async {
    _cleanupTimer?.cancel();
    
    // 关闭所有连接
    for (final connection in _availableConnections) {
      try {
        await connection.close();
      } catch (_) {}
    }
    
    for (final connection in _busyConnections) {
      try {
        await connection.close();
      } catch (_) {}
    }
    
    _availableConnections.clear();
    _busyConnections.clear();
    _totalConnections = 0;
    _activeConnections = 0;
    _isInitialized = false;
    
    print('MySQL连接池已关闭');
  }

  /// 检查连接池健康状态
  Future<bool> checkHealth() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      // 检查可用连接
      for (final connection in List.from(_availableConnections)) {
        try {
          await connection.query('SELECT 1');
        } catch (e) {
          // 移除失效连接
          _availableConnections.remove(connection);
          _totalConnections--;
          try {
            await connection.close();
          } catch (_) {}
        }
      }

      // 检查忙碌连接（可选，可能正在使用）
      for (final connection in List.from(_busyConnections)) {
        try {
          await connection.query('SELECT 1');
        } catch (e) {
          // 标记为失效，等待归还时处理
        }
      }

      // 确保最小连接数
      if (_availableConnections.isEmpty && _totalConnections < _minConnections) {
        try {
          final newConnection = await _createConnection();
          _availableConnections.add(newConnection);
          _totalConnections++;
        } catch (_) {}
      }

      return _totalConnections > 0;
    } catch (e) {
      print('连接池健康检查失败: $e');
      return false;
    }
  }

  /// 强制刷新所有连接（用于网络恢复后）
  Future<void> refreshAllConnections() async {
    print('强制刷新所有连接...');
    
    // 关闭所有现有连接
    for (final connection in List.from(_availableConnections)) {
      try {
        await connection.close();
      } catch (_) {}
    }
    _availableConnections.clear();
    
    for (final connection in List.from(_busyConnections)) {
      try {
        await connection.close();
      } catch (_) {}
    }
    _busyConnections.clear();
    
    _totalConnections = 0;
    _activeConnections = 0;
    
    // 重新创建初始连接
    await _createInitialConnections();
    print('连接池已刷新，当前连接数: $_totalConnections');
  }

  /// 获取详细的连接状态
  Map<String, dynamic> getDetailedStats() {
    return {
      ...getPoolStats(),
      'isInitialized': _isInitialized,
      'settings': _settings != null ? {
        'host': _settings!.host,
        'port': _settings!.port,
        'database': _settings!.db,
      } : null,
    };
  }
}
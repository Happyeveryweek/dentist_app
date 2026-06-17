import 'dart:async';
import '../providers/database_provider.dart';

/// 数据库操作包装器
/// 在每次数据库操作前自动检查和恢复连接
class DatabaseOperationWrapper {
  final DatabaseProvider _databaseProvider;

  DatabaseOperationWrapper(this._databaseProvider);

  /// 包装数据库操作，自动处理连接问题
  Future<T> wrapOperation<T>(
    String operationName,
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    // 如果是SQLite，直接执行操作，无需连接管理
    if (_databaseProvider.dbType == 'sqlite') {
      return await operation();
    }

    // MySQL操作需要连接管理
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;

      try {
        // MySQL操作前确保连接可用。后台恢复后旧socket可能已经失效，
        // 这里只依赖状态标记不够，需要真正检查并在必要时重连。
        final connectionReady = await _databaseProvider.ensureConnection();
        if (!connectionReady) {
          throw DatabaseConnectionException('MySQL连接不可用');
        }

        // 执行实际操作
        final result = await operation();

        // 操作成功，仅在重试成功时打印
        if (attempt > 1) {
          print('✅ MySQL操作重试成功: $operationName (尝试 $attempt 次)');
        }

        return result;
      } catch (e) {
        print('❌ MySQL操作失败: $operationName (尝试 $attempt/$maxRetries) - $e');

        // 检查是否是连接相关的错误
        if (isConnectionError(e) && attempt < maxRetries) {
          print('🔄 检测到MySQL连接错误，强制重连后重试...');
          final reconnected = await _databaseProvider.forceReconnect();
          if (!reconnected) {
            throw DatabaseOperationException(
              'MySQL操作失败: $operationName (自动重连失败)',
              originalException: e,
            );
          }
          await Future.delayed(retryDelay);
          continue;
        }

        // 如果不是连接错误或已达到最大重试次数，直接抛出异常
        if (attempt >= maxRetries) {
          throw DatabaseOperationException(
            'MySQL操作失败: $operationName (已重试 $maxRetries 次)',
            originalException: e,
          );
        }

        rethrow;
      }
    }

    throw DatabaseOperationException('MySQL操作超出最大重试次数: $operationName');
  }

  /// 检查是否是连接相关的错误
  static bool isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    return errorString.contains('connection') ||
        errorString.contains('socket') ||
        errorString.contains('timeout') ||
        errorString.contains('network') ||
        errorString.contains('broken pipe') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection refused') ||
        errorString.contains('host unreachable') ||
        errorString.contains('no route to host') ||
        errorString.contains('closed') ||
        errorString.contains('disconnected') ||
        errorString.contains('cannot write to socket') ||
        errorString.contains('bad state') ||
        errorString.contains('数据库连接失败') ||
        errorString.contains('数据库未初始化') ||
        errorString.contains('mysql连接已断开');
  }

  /// 包装查询操作
  Future<List<Map<String, dynamic>>> wrapQuery(
    String operationName,
    Future<List<Map<String, dynamic>>> Function() queryOperation,
  ) async {
    return await wrapOperation<List<Map<String, dynamic>>>(
      operationName,
      queryOperation,
    );
  }

  /// 包装插入操作
  Future<int> wrapInsert(
    String operationName,
    Future<int> Function() insertOperation,
  ) async {
    return await wrapOperation<int>(operationName, insertOperation);
  }

  /// 包装更新操作
  Future<int> wrapUpdate(
    String operationName,
    Future<int> Function() updateOperation,
  ) async {
    return await wrapOperation<int>(operationName, updateOperation);
  }

  /// 包装删除操作
  Future<int> wrapDelete(
    String operationName,
    Future<int> Function() deleteOperation,
  ) async {
    return await wrapOperation<int>(operationName, deleteOperation);
  }
}

/// 数据库连接异常
class DatabaseConnectionException implements Exception {
  final String message;
  final dynamic originalException;

  DatabaseConnectionException(this.message, {this.originalException});

  @override
  String toString() {
    if (originalException != null) {
      return 'DatabaseConnectionException: $message (原因: $originalException)';
    }
    return 'DatabaseConnectionException: $message';
  }
}

/// 数据库操作异常
class DatabaseOperationException implements Exception {
  final String message;
  final dynamic originalException;

  DatabaseOperationException(this.message, {this.originalException});

  @override
  String toString() {
    if (originalException != null) {
      return 'DatabaseOperationException: $message (原因: $originalException)';
    }
    return 'DatabaseOperationException: $message';
  }
}

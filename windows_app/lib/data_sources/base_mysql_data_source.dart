import 'package:mysql1/mysql1.dart';
import '../utils/mysql_connection_manager.dart';
import '../utils/log_manager.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/datetime_formatter.dart';
import 'package:flutter/foundation.dart';

/// MySQL数据源基类
///
/// 提供统一的连接管理和错误处理机制
/// 所有MySQL数据源都应该继承此类
abstract class BaseMySqlDataSource {
  final MySqlConnectionManager _connectionManager;

  BaseMySqlDataSource({
    required Future<MySqlConnection?> Function() connectionProvider,
    Future<void> Function()? reconnectCallback,
  }) : _connectionManager = MySqlConnectionManager(
          connectionProvider: connectionProvider,
          reconnectCallback: reconnectCallback,
        );

  /// 获取有效的MySQL连接
  ///
  /// 自动处理连接验证和重连
  Future<MySqlConnection> get connection async {
    final conn = await _connectionManager.getConnection();
    if (conn == null) {
      throw Exception('无法获取有效的MySQL连接');
    }
    return conn;
  }

  /// 执行查询操作（带自动重试）
  ///
  /// 如果查询失败且是连接问题，会自动重试一次
  Future<Results> executeQuery(
    String sql, [
    List<Object?>? values,
  ]) async {
    try {
      final conn = await connection;
      return await conn.query(sql, values);
    } on MySqlException catch (e) {
      if (await _tryReconnectOnConnectionError(e)) {
        final conn = await connection;
        return await conn.query(sql, values);
      }
      rethrow;
    } on Exception catch (e) {
      if (await _tryReconnectOnConnectionError(e)) {
        final conn = await connection;
        return await conn.query(sql, values);
      }
      rethrow;
    }
  }

  Future<bool> _tryReconnectOnConnectionError(Object error) async {
    if (!_isConnectionError(error)) {
      return false;
    }

    LogManager.w('BaseMySqlDataSource', '检测到连接错误，尝试重新连接并重试...');
    _connectionManager.clearCache();
    return true;
  }

  /// 判断是否是连接相关的错误
  bool _isConnectionError(Object error) {
    final errorMessage = error.toString().toLowerCase();
    return errorMessage.contains('socket') ||
        errorMessage.contains('connection') ||
        errorMessage.contains('closed') ||
        errorMessage.contains('timeout') ||
        errorMessage.contains('broken pipe') ||
        errorMessage.contains('connection reset') ||
        errorMessage.contains('connection abort') ||
        errorMessage.contains('cannot write to socket') ||
        errorMessage.contains('no connection') ||
        errorMessage.contains('server has gone away');
  }

  /// 辅助方法：将MySQL行数据转换为Map
  ///
  /// 处理各种数据类型，包括Blob、DateTime等
  Map<String, dynamic> convertRowToMap(dynamic row) {
    final Map<String, dynamic> recordMap = {};
    for (var entry in row.fields.entries) {
      final key = entry.key;
      var value = entry.value;
      if (value is Blob) {
        recordMap[key] = _convertBinaryValue(key, value.toBytes());
      } else if (value is Uint8List) {
        recordMap[key] = _convertBinaryValue(key, value);
      } else if (value is DateTime) {
        // 将DateTime转换为字符串格式
        recordMap[key] = DateTimeFormatter.toDbString(value);
      } else if (value is BigInt) {
        // 将BigInt转换为int
        recordMap[key] = value.toInt();
      } else {
        recordMap[key] = value;
      }
    }
    return recordMap;
  }

  dynamic _convertBinaryValue(String columnName, List<int> bytes) {
    if (_isBinaryColumn(columnName)) {
      return Uint8List.fromList(bytes);
    }

    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  bool _isBinaryColumn(String columnName) {
    final normalized = columnName.toLowerCase();
    return normalized == 'image_data' || normalized == 'thumbnail_data';
  }

  /// 辅助方法：安全地获取整数值
  int safeGetInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// 辅助方法：安全地获取双精度浮点数值
  double safeGetDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is BigInt) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  /// 强制验证连接
  Future<bool> validateConnection() async {
    return await _connectionManager.forceValidate();
  }

  /// 清除连接缓存
  void clearConnectionCache() {
    _connectionManager.clearCache();
  }

  /// 获取连接状态（用于调试）
  Map<String, dynamic> getConnectionStatus() {
    return _connectionManager.getStatus();
  }
}

import 'dart:async';
import 'package:mysql1/mysql1.dart';
import '../utils/log_manager.dart';

/// MySQL 连接服务
/// 职责：MySQL 连接管理、连接测试、字符集设置
class MysqlConnectionService {
  MySqlConnection? _mysqlConnection;

  MySqlConnection? get connection => _mysqlConnection;
  bool get isConnected => _mysqlConnection != null;

  /// 初始化 MySQL 连接
  Future<MySqlConnection> initMySQLConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    final settings = ConnectionSettings(
      host: host,
      port: port,
      user: username,
      password: password,
      db: database,
    );

    // 使用 3 秒连接超时，快速失败以支持降级
    final connection = await MySqlConnection.connect(settings).timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw TimeoutException('MySQL 连接超时，请检查网络和服务器配置'),
    );

    // 设置字符集
    await _setCharacterSet(connection);

    _mysqlConnection = connection;
    LogManager.i('MysqlConnectionService', 'MySQL 连接初始化成功');
    return connection;
  }

  /// 初始化 MySQL 连接（不改变当前数据源类型）
  Future<void> initializeMySQLConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      LogManager.w('MysqlConnectionService', '初始化 MySQL 连接...');

      final existingConnection = _mysqlConnection;
      if (existingConnection != null) {
        try {
          // 测试现有连接（5 秒超时）
          await existingConnection.query('SELECT 1').timeout(
                const Duration(seconds: 5),
                onTimeout: () => throw TimeoutException('MySQL 连接验证超时'),
              );
          LogManager.w('MysqlConnectionService', '现有 MySQL 连接可用');
          return;
        } catch (e) {
          LogManager.w('MysqlConnectionService', '现有 MySQL 连接失效，重新建立连接');
          try {
            await existingConnection.close();
          } catch (_) {}
          _mysqlConnection = null;
        }
      }

      // 使用 3 秒连接超时，快速失败以支持降级
      _mysqlConnection = await MySqlConnection.connect(
        ConnectionSettings(
          host: host,
          port: port,
          db: database,
          user: username,
          password: password,
        ),
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('MySQL 连接超时，请检查网络和服务器配置'),
      );

      // 设置字符集
      final newConnection = _mysqlConnection;
      if (newConnection == null) {
        throw Exception('MySQL 连接未初始化');
      }
      await _setCharacterSet(newConnection);

      LogManager.i('MysqlConnectionService', 'MySQL 连接初始化成功');
    } catch (e) {
      LogManager.e('MysqlConnectionService', '初始化 MySQL 连接失败', error: e);
      rethrow;
    }
  }

  /// 测试 MySQL 连接
  Future<bool> testConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      // 创建一个临时连接进行测试
      final conn = await MySqlConnection.connect(
        ConnectionSettings(
          host: host,
          port: port,
          db: database,
          user: username,
          password: password,
        ),
      );

      // 测试连接是否成功
      await conn.query('SELECT 1');

      // 关闭连接
      await conn.close();

      return true;
    } catch (e) {
      LogManager.e('MysqlConnectionService', 'MySQL 连接测试失败', error: e);
      return false;
    }
  }

  /// 测试现有连接是否有效
  Future<bool> testExistingConnection() async {
    final mysqlConnection = _mysqlConnection;
    if (mysqlConnection == null) {
      return false;
    }

    try {
      await mysqlConnection.query('SELECT 1');
      return true;
    } catch (e) {
      LogManager.e('MysqlConnectionService', '现有 MySQL 连接测试失败', error: e);
      return false;
    }
  }

  /// 设置 MySQL 会话字符集
  Future<void> _setCharacterSet(MySqlConnection connection) async {
    try {
      await connection.query("SET NAMES 'utf8mb4'");
      await connection.query("SET character_set_connection = 'utf8mb4'");
      await connection.query("SET character_set_results = 'utf8mb4'");
    } catch (e) {
      LogManager.e('MysqlConnectionService', '设置 MySQL 会话字符集失败', error: e);
    }
  }

  /// 检查表是否存在
  Future<bool> checkTableExists(String tableName,
      {String? databaseName}) async {
    final mysqlConnection = _mysqlConnection;
    if (mysqlConnection == null) {
      throw Exception('MySQL 连接未建立');
    }

    try {
      final dbName = databaseName ?? 'dentist_db'; // 默认数据库名
      final result = await mysqlConnection.query(
          'SELECT 1 FROM information_schema.tables WHERE table_schema = ? AND table_name = ?',
          [dbName, tableName]);
      return result.isNotEmpty;
    } catch (e) {
      LogManager.e('MysqlConnectionService', '检查表是否存在时出错', error: e);
      return false;
    }
  }

  /// 关闭连接
  Future<void> close() async {
    final mysqlConnection = _mysqlConnection;
    if (mysqlConnection != null) {
      LogManager.w('MysqlConnectionService', '关闭 MySQL 数据库连接');
      try {
        await mysqlConnection.close();
        LogManager.w('MysqlConnectionService', 'MySQL 数据库连接已关闭');
      } catch (e) {
        LogManager.e('MysqlConnectionService', '关闭 MySQL 连接时出错', error: e);
      }
      _mysqlConnection = null;
    }
  }
}

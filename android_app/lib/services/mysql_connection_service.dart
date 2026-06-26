import 'dart:io';
import 'package:mysql1/mysql1.dart';
import '../models/database_config.dart';
import '../utils/app_logger.dart';

/// MySQL 连接管理服务
/// 职责：MySQL 连接创建、关闭、参数配置、localhost 转换、字符编码设置
class MySQLConnectionService {
  MySqlConnection? _mysqlConnection;
  DatabaseConfig? _dbConfig;

  /// 获取当前 MySQL 连接
  MySqlConnection? get connection => _mysqlConnection;

  /// 设置数据库配置
  void setDatabaseConfig(DatabaseConfig config) {
    _dbConfig = config;
  }

  /// 初始化 MySQL 连接（启动时快速失败）
  Future<void> initConnection({bool isStartup = true}) async {
    final config = _dbConfig;
    if (config == null) {
      throw Exception('数据库配置未设置');
    }

    // 启动时快速失败（只尝试1次），应用恢复时可以多次重试
    final maxRetries = isStartup ? 1 : 3;
    const retryDelay = Duration(seconds: 1);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        AppLogger.info('配置MySQL连接参数... 尝试第 $attempt/$maxRetries 次');

        // 检查并转换localhost为10.0.2.2（如果在Android平台）
        if (Platform.isAndroid &&
            (config.mysql.host == 'localhost' ||
                config.mysql.host == '127.0.0.1')) {
          AppLogger.info('Android平台检测到localhost配置，自动转换为10.0.2.2');
          config.mysql.host = '10.0.2.2';

          // 保存更新后的配置
          await config.saveConfig();
          AppLogger.info('已自动更新配置文件中的MySQL主机为10.0.2.2');
        }

        final host = config.mysql.host;
        final port = config.mysql.port;
        final database = config.mysql.database;
        final username = config.mysql.username;
        final password = config.mysql.password;

        AppLogger.info('MySQL连接参数: $host:$port/$database, 用户: $username');

        // 设置连接参数 - 启动时快速失败，应用恢复时允许更长时间
        final connectionTimeout =
            isStartup
                ? const Duration(seconds: 2)
                : const Duration(seconds: 10);
        final settings = ConnectionSettings(
          host: host,
          port: int.parse(port),
          user: username,
          password: password,
          db: database,
          timeout: connectionTimeout,
          useSSL: false, // 显式禁用SSL以减少连接开销
          useCompression: false, // 禁用压缩以提高响应速度
        );

        // 先测试Socket连接
        try {
          AppLogger.info('测试Socket连接到MySQL: $host:$port');
          // 启动时快速失败（1秒），应用恢复时允许更长时间（3秒）
          final socketTimeout =
              isStartup
                  ? const Duration(seconds: 1)
                  : const Duration(seconds: 3);
          final socket = await Socket.connect(
            host,
            int.parse(port),
            timeout: socketTimeout,
            sourceAddress: InternetAddress.anyIPv4,
          );
          AppLogger.info('Socket连接成功，销毁临时Socket');
          socket.destroy();
        } catch (socketError) {
          AppLogger.info('Socket连接测试失败: $socketError');
          if (attempt < maxRetries) {
            AppLogger.info('等待 ${retryDelay.inSeconds} 秒后重试...');
            await Future.delayed(retryDelay);
            continue;
          }
          throw Exception('无法连接到MySQL服务器: $socketError');
        }

        // 尝试连接
        AppLogger.info('准备连接到MySQL: $host:$port/$database');

        try {
          final connection = await MySqlConnection.connect(settings);
          _mysqlConnection = connection;

          // 设置会话字符编码，确保中文字符正确显示
          await connection.query("SET NAMES 'utf8mb4'");
          await connection.query("SET CHARACTER SET utf8mb4");
          await connection.query("SET character_set_connection=utf8mb4");

          // 设置连接保持参数
          await connection.query("SET wait_timeout = 28800"); // 8小时
          await connection.query(
            "SET interactive_timeout = 28800",
          ); // 8小时
          AppLogger.info('MySQL字符编码和连接超时已设置');
        } catch (e) {
          AppLogger.info('MySQL连接错误: $e');
          if (attempt < maxRetries) {
            AppLogger.info('等待 ${retryDelay.inSeconds} 秒后重试...');
            await Future.delayed(retryDelay);
            continue;
          }

          if (e.toString().contains('SocketException')) {
            throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确');
          } else if (e.toString().contains('Access denied')) {
            throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
          } else if (e.toString().contains('Unknown database')) {
            throw Exception('数据库不存在，请检查数据库名称是否正确');
          } else {
            throw Exception('MySQL连接失败: $e');
          }
        }

        // 测试连接
        final currentConnection = _mysqlConnection;
        if (currentConnection == null) {
          throw Exception('MySQL连接未建立');
        }
        try {
          final results = await currentConnection.query('SELECT 1');
          if (results.isNotEmpty) {
            AppLogger.info('MySQL连接测试成功');
            break; // 连接成功，退出重试循环
          } else {
            if (attempt < maxRetries) {
              AppLogger.info('连接测试失败，重试中...');
              continue;
            }
            throw Exception('MySQL连接测试失败: 查询返回空结果');
          }
        } catch (e) {
          AppLogger.info('MySQL查询测试错误: $e');
          if (attempt < maxRetries) {
            AppLogger.info('等待 ${retryDelay.inSeconds} 秒后重试...');
            await Future.delayed(retryDelay);
            continue;
          }
          throw Exception('MySQL连接成功但查询测试失败: $e');
        }
      } catch (e) {
        AppLogger.info('MySQL连接尝试 $attempt/$maxRetries 失败: $e');
        if (attempt == maxRetries) {
          _mysqlConnection = null;
          throw Exception('MySQL连接失败: $e');
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  /// 使用参数初始化MySQL连接
  Future<void> initWithParams(
    String host,
    String port,
    String database,
    String username,
    String password,
  ) async {
    try {
      AppLogger.info('使用参数初始化MySQL连接...');

      // 首先关闭已有连接
      final existingConnection = _mysqlConnection;
      if (existingConnection != null) {
        await existingConnection.close();
        _mysqlConnection = null;
      }

      // 检查参数
      if (host.isEmpty) {
        throw Exception('MySQL主机名为空');
      }

      // 检查并转换localhost为10.0.2.2（如果在Android平台）
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        AppLogger.info('Android连接检测到localhost参数，自动转换为10.0.2.2');
        effectiveHost = '10.0.2.2';
      }

      // 打印所有连接参数，帮助调试
      AppLogger.info(
        'MySQL连接参数: host=$effectiveHost (原始值:$host), port=$port, db=$database, user=$username',
      );

      // 对于Android模拟器，如果使用10.0.2.2，记录下来
      if (effectiveHost == "10.0.2.2") {
        AppLogger.info('使用Android模拟器特殊主机: 10.0.2.2 (模拟器中的localhost)');
      }

      // 先测试Socket连接
      AppLogger.info('测试Socket连接到MySQL: $effectiveHost:$port');
      try {
        final socket = await Socket.connect(
          effectiveHost,
          int.parse(port),
          timeout: const Duration(seconds: 15),
          sourceAddress: InternetAddress.anyIPv4,
        );
        AppLogger.info('Socket连接成功，销毁临时Socket');
        socket.destroy();
      } catch (socketError) {
        AppLogger.info('Socket连接测试失败: $socketError');
        throw Exception('无法连接到MySQL服务器: $socketError');
      }

      // 创建新连接设置
      final settings = ConnectionSettings(
        host: effectiveHost,
        port: int.parse(port),
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 20),
      );

      // 尝试连接
      AppLogger.info('准备连接到MySQL: $effectiveHost:$port/$database');

      try {
        final connection = await MySqlConnection.connect(settings);
        _mysqlConnection = connection;

        // 设置会话字符编码，确保中文字符正确显示
        await connection.query("SET NAMES 'utf8mb4'");
        await connection.query("SET CHARACTER SET utf8mb4");
        await connection.query("SET character_set_connection=utf8mb4");
        AppLogger.info('MySQL字符编码已设置为utf8mb4');
      } catch (e) {
        AppLogger.info('MySQL连接错误: $e');
        if (e.toString().contains('SocketException')) {
          throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确');
        } else if (e.toString().contains('Access denied')) {
          throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
        } else if (e.toString().contains('Unknown database')) {
          throw Exception('数据库不存在，请检查数据库名称是否正确');
        } else {
          throw Exception('MySQL连接失败: $e');
        }
      }

      // 测试连接
      final newConnection = _mysqlConnection;
      if (newConnection == null) {
        throw Exception('MySQL连接未建立');
      }
      try {
        final results = await newConnection.query('SELECT 1');
        if (results.isNotEmpty) {
          AppLogger.info('MySQL连接测试成功');
        } else {
          throw Exception('MySQL连接测试失败: 查询返回空结果');
        }
      } catch (e) {
        AppLogger.info('MySQL查询测试错误: $e');
        throw Exception('MySQL连接成功但查询测试失败: $e');
      }
    } catch (e) {
      AppLogger.info('MySQL连接错误: $e');
      _mysqlConnection = null;
      throw Exception('MySQL连接失败: $e');
    }
  }

  /// 测试MySQL连接（初始化时使用）
  Future<bool> testConnection(DatabaseConfig config) async {
    try {
      AppLogger.info('正在测试MySQL连接...');
      String host = config.mysql.host;
      final port = int.parse(config.mysql.port);
      final database = config.mysql.database;
      final username = config.mysql.username;
      final password = config.mysql.password;

      // 在Android模拟器上自动转换localhost为10.0.2.2
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        host = '10.0.2.2';
        AppLogger.info('Android模拟器检测到localhost，自动转换为10.0.2.2');
      }

      // 先快速测试Socket连接（1秒超时）- 快速失败
      try {
        AppLogger.info('快速测试Socket连接: $host:$port');
        final socket = await Socket.connect(
          host,
          port,
          timeout: const Duration(seconds: 1),
        );
        socket.destroy();
        AppLogger.info('Socket连接测试成功');
      } catch (e) {
        AppLogger.info('Socket连接测试失败（快速失败）: $e');
        return false;
      }

      final settings = ConnectionSettings(
        host: host,
        port: port,
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 2),
      );

      final connection = await MySqlConnection.connect(settings);
      final results = await connection.query('SELECT 1');
      await connection.close();

      return results.isNotEmpty;
    } catch (e) {
      AppLogger.info('MySQL连接测试失败: $e');
      return false;
    }
  }

  /// 关闭MySQL连接
  Future<void> closeConnection() async {
    final connection = _mysqlConnection;
    if (connection != null) {
      try {
        AppLogger.info('关闭MySQL连接');
        await connection.close();
        AppLogger.info('MySQL连接已关闭');
      } catch (e) {
        AppLogger.info('关闭MySQL连接时出错: $e');
      } finally {
        _mysqlConnection = null;
      }
    }
  }

  /// 重置连接状态
  void resetConnection() {
    _mysqlConnection = null;
  }
}

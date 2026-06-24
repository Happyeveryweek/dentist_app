import 'dart:io';
import 'package:mysql1/mysql1.dart';
import '../../../utils/app_logger.dart';

/// MySQL 配置管理服务
/// 负责测试 MySQL 连接、保存配置、测试网络连接
class MysqlConfigService {
  /// 测试网络连接
  ///
  /// [host] - 主机地址
  /// [port] - 端口号
  ///
  /// 返回 true 表示连接成功，false 表示连接失败
  static Future<bool> testNetworkConnection(String host, String port) async {
    try {
      // 如果是Android模拟器使用的localhost，转换为10.0.2.2
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        effectiveHost = '10.0.2.2';
        AppLogger.info('Android模拟器检测到，网络测试将localhost转换为10.0.2.2');
      }

      AppLogger.info('测试与 $effectiveHost:$port 的网络连接...');

      // 使用Socket尝试连接
      try {
        final socket = await Socket.connect(
          effectiveHost,
          int.parse(port),
          timeout: const Duration(seconds: 5),
        );

        // 如果能连接成功，关闭Socket
        await socket.close();
        AppLogger.info('网络连接测试成功：可以连接到 $effectiveHost:$port');

        return true;
      } catch (e) {
        AppLogger.info('网络连接测试失败: $e');
        return false;
      }
    } catch (e) {
      AppLogger.info('网络测试错误: $e');
      return false;
    }
  }

  /// 测试 MySQL 连接
  ///
  /// [host] - 主机地址
  /// [port] - 端口号
  /// [database] - 数据库名称
  /// [username] - 用户名
  /// [password] - 密码
  ///
  /// 返回 true 表示连接成功，false 表示连接失败
  static Future<bool> testMySqlConnection({
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      AppLogger.info('测试MySQL连接...');

      // 检查并转换localhost为10.0.2.2（如果在Android平台）
      String effectiveHost = host;
      if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
        AppLogger.info('Android连接检测到localhost参数，自动转换为10.0.2.2');
        effectiveHost = '10.0.2.2';
      }

      // 先测试Socket连接
      AppLogger.info('测试Socket连接到MySQL: $effectiveHost:$port');
      try {
        final socket = await Socket.connect(
          effectiveHost,
          int.parse(port),
          timeout: const Duration(seconds: 15),
          sourceAddress: InternetAddress.anyIPv4, // 指定使用IPv4地址
        );
        AppLogger.info('Socket连接成功，销毁临时Socket');
        socket.destroy();
      } catch (socketError) {
        AppLogger.info('Socket连接测试失败: $socketError');
        throw Exception('无法连接到MySQL服务器: $socketError');
      }

      // 创建临时连接设置
      final settings = ConnectionSettings(
        host: effectiveHost,
        port: int.parse(port),
        user: username,
        password: password,
        db: database,
        timeout: const Duration(seconds: 20), // 增加超时时间，与正式连接保持一致
      );

      // 尝试连接
      AppLogger.info(
        '尝试连接到MySQL: $effectiveHost:$port/$database (用户名: $username)',
      );

      MySqlConnection? connection;

      // 增加重试机制
      int retryCount = 0;
      const maxRetries = 2;

      while (retryCount <= maxRetries) {
        try {
          AppLogger.info('连接尝试 ${retryCount + 1}/$maxRetries');
          connection = await MySqlConnection.connect(settings);
          break; // 连接成功，跳出循环
        } catch (e) {
          retryCount++;
          AppLogger.info('MySQL连接错误(尝试 $retryCount): $e');

          if (retryCount > maxRetries) {
            // 所有重试都失败
            if (e.toString().contains('SocketException')) {
              throw Exception('无法连接到MySQL服务器，请检查主机名和端口是否正确，以及网络连接是否稳定');
            } else if (e.toString().contains('Access denied')) {
              throw Exception('MySQL访问被拒绝，请检查用户名和密码是否正确');
            } else if (e.toString().contains('Unknown database')) {
              throw Exception('数据库不存在，请检查数据库名称是否正确');
            } else {
              throw Exception('MySQL连接失败: $e');
            }
          }

          // 等待一段时间后重试
          await Future.delayed(const Duration(seconds: 1));
        }
      }

      if (connection == null) {
        throw Exception('无法建立MySQL连接，请检查网络连接或服务器状态');
      }

      // 测试连接
      try {
        final results = await connection.query('SELECT 1');
        if (results.isNotEmpty) {
          AppLogger.info('MySQL连接测试成功');
          // 关闭连接
          await connection.close();
          return true;
        } else {
          throw Exception('MySQL连接测试失败: 查询返回空结果');
        }
      } catch (e) {
        AppLogger.info('MySQL查询测试错误: $e');
        // 关闭连接
        await connection.close();
        throw Exception('MySQL连接成功但查询测试失败: $e');
      }
    } catch (e) {
      AppLogger.info('MySQL连接测试错误: $e');
      return false;
    }
  }

  /// 获取有效的 MySQL 主机地址
  ///
  /// [host] - 原始主机地址
  ///
  /// 返回转换后的主机地址（Android模拟器 localhost 转换为 10.0.2.2）
  static String getEffectiveHost(String host) {
    if (Platform.isAndroid && (host == 'localhost' || host == '127.0.0.1')) {
      return '10.0.2.2';
    }
    return host;
  }

  /// 检查是否使用了转换后的主机地址
  ///
  /// [originalHost] - 原始主机地址
  /// [effectiveHost] - 转换后的主机地址
  ///
  /// 返回 true 表示使用了转换，false 表示未使用
  static bool isHostConverted(String originalHost, String effectiveHost) {
    return effectiveHost != originalHost;
  }
}

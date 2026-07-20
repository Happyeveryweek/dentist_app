/// 应用在设置尚未加载时使用的唯一默认名称。
const String defaultAppName = '牙科诊所管理系统';

/// MySQL 连接的共享默认值和各自语义明确的超时策略。
abstract final class MySqlConnectionPolicy {
  static const int defaultPort = 3306;
  static const Duration connectionTimeout = Duration(seconds: 3);
  static const Duration validationTimeout = Duration(seconds: 3);
  static const Duration userTestTimeout = Duration(seconds: 10);
  static const Duration healthCheckInterval = Duration(seconds: 30);
  static const Duration modularInitializationTimeout = Duration(seconds: 5);
}

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 应用路径管理类
class AppPaths {
  static String? _appDataPath;

  /// 获取应用数据目录路径
  static Future<String> get appDataPath async {
    if (_appDataPath != null) return _appDataPath!;

    try {
      final directory = await getApplicationSupportDirectory();
      _appDataPath = directory.path;
      return _appDataPath!;
    } catch (e) {
      // 如果获取应用支持目录失败，回退到文档目录
      final directory = await getApplicationDocumentsDirectory();
      _appDataPath = directory.path;
      return _appDataPath!;
    }
  }

  /// 同步配置文件路径
  static Future<String> get syncConfigPath async {
    final appPath = await appDataPath;
    return path.join(appPath, 'sync_config.json');
  }

  /// 数据库文件路径
  static Future<String> get databasePath async {
    final appPath = await appDataPath;
    return path.join(appPath, 'dentist_app.db');
  }

  /// 日志文件路径
  static Future<String> get logPath async {
    final appPath = await appDataPath;
    return path.join(appPath, 'logs');
  }

  /// 备份文件路径
  static Future<String> get backupPath async {
    final appPath = await appDataPath;
    return path.join(appPath, 'backups');
  }
}

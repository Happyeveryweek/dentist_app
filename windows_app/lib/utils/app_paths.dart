import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'log_manager.dart';

/// 应用路径管理工具类
/// 统一管理应用的所有数据文件路径
class AppPaths {
  static String? _appDirectory;
  static String? _dataDirectory;

  /// 初始化应用路径
  static Future<void> initialize() async {
    try {
      // 获取应用可执行文件所在目录
      final executable = Platform.resolvedExecutable;
      final appDirectory = path.dirname(executable);
      _appDirectory = appDirectory;

      // 设置数据目录为应用目录下的data文件夹
      final dataDirectory = path.join(appDirectory, 'data');
      _dataDirectory = dataDirectory;

      // 确保数据目录存在
      final dataDir = Directory(dataDirectory);
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
    } catch (e) {
      LogManager.e('AppPaths', '初始化应用路径失败', error: e);
      // 如果获取应用目录失败，回退到文档目录
      await _initializeFallback();
    }
  }

  /// 回退初始化方法（使用文档目录）
  static Future<void> _initializeFallback() async {
    try {
      // 优先尝试使用应用数据目录而不是文档目录
      Directory? appDataDir;
      try {
        appDataDir = await getApplicationSupportDirectory();
      } catch (e) {
        LogManager.w('AppPaths', '无法获取应用支持目录，使用文档目录', error: e);
        appDataDir = await getApplicationDocumentsDirectory();
      }

      final appDirectory = appDataDir.path;
      _appDirectory = appDirectory;
      final dataDirectory = path.join(appDirectory, 'DentistApp');
      _dataDirectory = dataDirectory;

      final dataDir = Directory(dataDirectory);
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
      }
    } catch (e) {
      LogManager.e('AppPaths', '回退初始化也失败', error: e);
      throw Exception('无法初始化应用路径');
    }
  }

  static String get _requireAppDirectory {
    final appDir = _appDirectory;
    if (appDir == null) {
      throw Exception('应用路径未初始化，请先调用 AppPaths.initialize()');
    }
    return appDir;
  }

  static String get _requireDataDirectory {
    final dataDir = _dataDirectory;
    if (dataDir == null) {
      throw Exception('数据目录未初始化，请先调用 AppPaths.initialize()');
    }
    return dataDir;
  }

  /// 获取应用根目录
  static String get appDirectory => _requireAppDirectory;

  /// 获取数据目录
  static String get dataDirectory => _requireDataDirectory;

  /// 获取数据库文件路径
  static String get databasePath {
    return path.join(dataDirectory, 'dental_clinic.db');
  }

  /// 获取备份日志文件路径
  static String get backupLogPath {
    return path.join(logDirectory, 'backup_logs.json');
  }

  /// 获取数据库结构检测日志路径（存储在SQLite数据库中，这里提供一个导出路径）
  static String get databaseStructureLogPath {
    return path.join(logDirectory, 'database_structure_logs.json');
  }

  /// 获取应用运行日志路径
  static String get appLogPath {
    return path.join(logDirectory, 'app_logs.txt');
  }

  /// 获取错误日志路径
  static String get errorLogPath {
    return path.join(logDirectory, 'error_logs.txt');
  }

  /// 获取同步日志路径
  static String get syncLogPath {
    return path.join(logDirectory, 'sync_logs.txt');
  }

  /// 获取配置目录
  static String get configDirectory {
    return path.join(dataDirectory, 'config');
  }

  /// 获取配置文件路径
  static String get configPath {
    return path.join(configDirectory, 'app_config.json');
  }

  /// 获取缓存目录
  static String get cacheDirectory {
    return path.join(dataDirectory, 'cache');
  }

  /// 获取缩略图缓存目录
  static String get thumbnailCacheDirectory {
    return path.join(cacheDirectory, 'thumbnails');
  }

  /// 获取同步配置文件路径
  static String get syncConfigPath {
    return path.join(configDirectory, 'sync_config.json');
  }

  /// 获取日志目录
  static String get logDirectory {
    return path.join(dataDirectory, 'logs');
  }

  /// 获取备份目录（默认）
  static String get defaultBackupDirectory {
    return path.join(dataDirectory, 'backups');
  }

  /// 获取导出目录
  static String get exportDirectory {
    return path.join(dataDirectory, 'exports');
  }

  /// 获取临时目录
  static String get tempDirectory {
    return path.join(dataDirectory, 'temp');
  }

  /// 确保目录存在
  static Future<void> ensureDirectoryExists(String dirPath) async {
    final directory = Directory(dirPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
  }

  // 缓存MySQL工具路径，避免重复检测
  static String? _cachedMysqlToolsDirectory;
  static bool _mysqlToolsDirectoryChecked = false;

  /// 获取MySQL工具路径（智能检测开发和生产环境）
  static String get mysqlToolsDirectory {
    final cached = _cachedMysqlToolsDirectory;
    if (_mysqlToolsDirectoryChecked && cached != null) {
      return cached;
    }

    // 生产环境：应用安装目录下的tools文件夹
    final appToolsDir = path.join(appDirectory, 'tools');

    // 开发环境：当前工程目录下的tools文件夹
    const projectToolsDir =
        r'D:\Data\android_project\dentist_app\windows_app\tools';

    // 兼容旧工程路径，避免历史环境直接失效
    const legacyProjectToolsDir =
        r'D:\Data\android\dentist_app\windows_app\tools';

    final candidates = <String>[
      appToolsDir,
      projectToolsDir,
      legacyProjectToolsDir,
    ];

    String resultPath = appToolsDir;
    for (final candidate in candidates) {
      if (!Directory(candidate).existsSync()) {
        continue;
      }

      final mysqlFile = File(path.join(candidate, 'mysql.exe'));
      final mysqldumpFile = File(path.join(candidate, 'mysqldump.exe'));
      if (mysqlFile.existsSync() && mysqldumpFile.existsSync()) {
        resultPath = candidate;
        break;
      }

      LogManager.w('AppPaths', 'tools目录存在但MySQL工具不完整: $candidate');
    }

    if (resultPath == appToolsDir && !Directory(appToolsDir).existsSync()) {
      LogManager.w('AppPaths', 'MySQL工具未找到，使用默认路径: $appToolsDir');
    }

    _cachedMysqlToolsDirectory = resultPath;
    _mysqlToolsDirectoryChecked = true;
    return resultPath;
  }

  /// 获取mysql.exe路径
  static String get mysqlExePath {
    return path.join(mysqlToolsDirectory, 'mysql.exe');
  }

  /// 获取mysqldump.exe路径
  static String get mysqldumpExePath {
    return path.join(mysqlToolsDirectory, 'mysqldump.exe');
  }

  /// 检查MySQL工具是否存在
  static bool get hasMySQLTools {
    final mysqlFile = File(mysqlExePath);
    final mysqldumpFile = File(mysqldumpExePath);
    return mysqlFile.existsSync() && mysqldumpFile.existsSync();
  }

  // 缓存MySQL工具信息
  static Map<String, dynamic>? _cachedMysqlToolsInfo;

  /// 获取MySQL工具的详细信息
  static Map<String, dynamic> get mysqlToolsInfo {
    final cached = _cachedMysqlToolsInfo;
    if (cached != null) {
      return cached;
    }

    final toolsDir = mysqlToolsDirectory;
    final mysqlFile = File(mysqlExePath);
    final mysqldumpFile = File(mysqldumpExePath);
    final libmysqlFile = File(path.join(toolsDir, 'libmysql.dll'));

    final info = {
      'toolsDirectory': toolsDir,
      'mysqlExists': mysqlFile.existsSync(),
      'mysqldumpExists': mysqldumpFile.existsSync(),
      'libmysqlExists': libmysqlFile.existsSync(),
      'mysqlPath': mysqlExePath,
      'mysqldumpPath': mysqldumpExePath,
      'libmysqlPath': libmysqlFile.path,
      'allToolsAvailable': hasMySQLTools && libmysqlFile.existsSync(),
    };
    _cachedMysqlToolsInfo = info;

    return info;
  }

  /// 初始化所有必要的目录
  static Future<void> initializeAllDirectories() async {
    final directories = [
      dataDirectory,
      configDirectory,
      cacheDirectory,
      thumbnailCacheDirectory,
      logDirectory,
      defaultBackupDirectory,
      exportDirectory,
      tempDirectory,
    ];

    for (final dir in directories) {
      await ensureDirectoryExists(dir);
    }
  }

  /// 获取相对于数据目录的路径
  static String getDataPath(String relativePath) {
    return path.join(dataDirectory, relativePath);
  }

  /// 检查是否为便携模式（应用目录下有data文件夹）
  static bool get isPortableMode {
    final appDir = _appDirectory;
    if (appDir == null) return false;
    final dataDir = Directory(path.join(appDir, 'data'));
    return dataDir.existsSync();
  }

  /// 获取应用信息
  static Map<String, String> get appInfo {
    return {
      'appDirectory': _appDirectory ?? 'Unknown',
      'dataDirectory': _dataDirectory ?? 'Unknown',
      'isPortableMode': isPortableMode.toString(),
      'hasMySQLTools': hasMySQLTools.toString(),
    };
  }
}

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

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
      _appDirectory = path.dirname(executable);
      
      // 设置数据目录为应用目录下的data文件夹
      _dataDirectory = path.join(_appDirectory!, 'data');
      
      // 确保数据目录存在
      final dataDir = Directory(_dataDirectory!);
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
        print('创建数据目录: $_dataDirectory');
      }
      
      print('应用目录: $_appDirectory');
      print('数据目录: $_dataDirectory');
    } catch (e) {
      print('初始化应用路径失败: $e');
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
        print('无法获取应用支持目录，使用文档目录: $e');
        appDataDir = await getApplicationDocumentsDirectory();
      }
      
      _appDirectory = appDataDir.path;
      _dataDirectory = path.join(_appDirectory!, 'DentistApp');
      
      final dataDir = Directory(_dataDirectory!);
      if (!await dataDir.exists()) {
        await dataDir.create(recursive: true);
        print('创建回退数据目录: $_dataDirectory');
      }
      
      print('使用回退路径 - 应用目录: $_appDirectory');
      print('使用回退路径 - 数据目录: $_dataDirectory');
    } catch (e) {
      print('回退初始化也失败: $e');
      throw Exception('无法初始化应用路径');
    }
  }
  
  /// 获取应用根目录
  static String get appDirectory {
    if (_appDirectory == null) {
      throw Exception('应用路径未初始化，请先调用 AppPaths.initialize()');
    }
    return _appDirectory!;
  }
  
  /// 获取数据目录
  static String get dataDirectory {
    if (_dataDirectory == null) {
      throw Exception('数据目录未初始化，请先调用 AppPaths.initialize()');
    }
    return _dataDirectory!;
  }
  
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
      print('创建目录: $dirPath');
    }
  }
  
  // 缓存MySQL工具路径，避免重复检测
  static String? _cachedMysqlToolsDirectory;
  static bool _mysqlToolsDirectoryChecked = false;

  /// 获取MySQL工具路径（智能检测开发和生产环境）
  static String get mysqlToolsDirectory {
    if (_mysqlToolsDirectoryChecked && _cachedMysqlToolsDirectory != null) {
      return _cachedMysqlToolsDirectory!;
    }

    // 生产环境：应用安装目录下的tools文件夹
    final appToolsDir = path.join(appDirectory, 'tools');
    
    // 开发环境：项目根目录下的tools文件夹
    final devToolsDir = r'D:\Data\android\dentist_app\windows_app\tools';
    
    String resultPath = appToolsDir;
    
    // 优先检查生产环境路径（打包后的应用）
    if (Directory(appToolsDir).existsSync()) {
      final mysqlFile = File(path.join(appToolsDir, 'mysql.exe'));
      final mysqldumpFile = File(path.join(appToolsDir, 'mysqldump.exe'));
      if (mysqlFile.existsSync() && mysqldumpFile.existsSync()) {
        print('✅ 使用生产环境MySQL工具路径: $appToolsDir');
        resultPath = appToolsDir;
      } else {
        print('⚠️ 生产环境tools目录存在但MySQL工具不完整');
      }
    } else {
      // 检查开发环境路径（仅在开发时使用）
      if (Directory(devToolsDir).existsSync()) {
        final mysqlFile = File(path.join(devToolsDir, 'mysql.exe'));
        final mysqldumpFile = File(path.join(devToolsDir, 'mysqldump.exe'));
        if (mysqlFile.existsSync() && mysqldumpFile.existsSync()) {
          print('✅ 使用开发环境MySQL工具: $devToolsDir');
          resultPath = devToolsDir;
        } else {
          print('⚠️ 开发环境tools目录存在但MySQL工具不完整');
        }
      } else {
        // 如果都找不到，返回生产环境路径（安装程序会创建）
        print('⚠️ MySQL工具未找到，使用默认路径: $appToolsDir');
        resultPath = appToolsDir;
      }
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

  /// 显示MySQL工具状态（用于调试）
  static void printMySQLToolsStatus() {
    if (hasMySQLTools) {
      print('✅ MySQL工具已找到: $mysqlToolsDirectory');
    } else {
      print('❌ MySQL工具未找到');
      print('  检查路径: $mysqlExePath');
      print('  检查路径: $mysqldumpExePath');
    }
  }
  
  // 缓存MySQL工具信息
  static Map<String, dynamic>? _cachedMysqlToolsInfo;

  /// 获取MySQL工具的详细信息
  static Map<String, dynamic> get mysqlToolsInfo {
    if (_cachedMysqlToolsInfo != null) {
      return _cachedMysqlToolsInfo!;
    }

    final toolsDir = mysqlToolsDirectory;
    final mysqlFile = File(mysqlExePath);
    final mysqldumpFile = File(mysqldumpExePath);
    final libmysqlFile = File(path.join(toolsDir, 'libmysql.dll'));
    
    _cachedMysqlToolsInfo = {
      'toolsDirectory': toolsDir,
      'mysqlExists': mysqlFile.existsSync(),
      'mysqldumpExists': mysqldumpFile.existsSync(),
      'libmysqlExists': libmysqlFile.existsSync(),
      'mysqlPath': mysqlExePath,
      'mysqldumpPath': mysqldumpExePath,
      'libmysqlPath': libmysqlFile.path,
      'allToolsAvailable': hasMySQLTools && libmysqlFile.existsSync(),
    };
    
    return _cachedMysqlToolsInfo!;
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
    
    print('所有必要目录已初始化完成');
    print('目录结构:');
    print('  数据目录: $dataDirectory');
    print('  配置目录: $configDirectory');
    print('  缓存目录: $cacheDirectory');
    print('  日志目录: $logDirectory');
    print('  备份目录: $defaultBackupDirectory');
    print('  导出目录: $exportDirectory');
    print('  临时目录: $tempDirectory');
  }
  
  /// 获取相对于数据目录的路径
  static String getDataPath(String relativePath) {
    return path.join(dataDirectory, relativePath);
  }
  
  /// 检查是否为便携模式（应用目录下有data文件夹）
  static bool get isPortableMode {
    if (_appDirectory == null) return false;
    final dataDir = Directory(path.join(_appDirectory!, 'data'));
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
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/utils/database_utils.dart';
import '../../../utils/app_logger.dart';

/// 数据库切换服务
/// 负责数据库类型切换、路径选择、配置保存
class DatabaseSwitchService {
  /// 初始化数据库配置
  ///
  /// 返回初始化后的 DatabaseConfig 对象
  static Future<DatabaseConfig> initDatabaseConfig() async {
    try {
      final dbConfig = await DatabaseConfig.loadConfig();
      final dbType = dbConfig.dbType;

      if (dbType == 'sqlite') {
        if (dbConfig.sqlite.path.isNotEmpty) {
          AppLogger.info('SQLite数据库路径初始化为: ${dbConfig.sqlite.path}');
        } else {
          // 如果配置中没有路径，使用默认路径
          final defaultPath = await DatabaseUtils.getDefaultDatabasePath();
          dbConfig.sqlite.path = defaultPath;
          await dbConfig.saveConfig();
          AppLogger.info('SQLite数据库路径初始化为: $defaultPath');
        }
      } else if (dbType == 'mysql') {
        final dbPath =
            '${dbConfig.mysql.host}:${dbConfig.mysql.port}/${dbConfig.mysql.database}';
        AppLogger.info('MySQL连接信息初始化为: $dbPath');
      }

      return dbConfig;
    } catch (e) {
      AppLogger.info('初始化数据库配置错误: $e');
      rethrow;
    }
  }

  /// 切换数据库类型
  ///
  /// [dbType] - 数据库类型 ('sqlite' 或 'mysql')
  /// [dbConfig] - 数据库配置对象
  /// [path] - 可选的SQLite路径
  ///
  /// 返回切换后的 DatabaseConfig 对象
  static Future<DatabaseConfig> switchDatabaseType(
    String dbType,
    DatabaseConfig dbConfig, {
    String? path,
  }) async {
    final oldType = dbConfig.dbType;
    AppLogger.info('切换数据库类型到 $dbType，当前类型: $oldType');

    try {
      dbConfig.dbType = dbType;

      if (dbType == 'sqlite') {
        if (path != null && path.isNotEmpty) {
          // 使用提供的路径
          dbConfig.sqlite.path = path;
        } else if (dbConfig.sqlite.path.isNotEmpty) {
          // 使用配置中的路径
          // 路径已存在，无需修改
        } else {
          // 使用默认路径
          final defaultPath = await DatabaseUtils.getDefaultDatabasePath();
          dbConfig.sqlite.path = defaultPath;
        }
        await dbConfig.saveConfig();
        AppLogger.info('SQLite路径已设置为: ${dbConfig.sqlite.path}');
      } else if (dbType == 'mysql') {
        // 确保配置已保存
        await dbConfig.saveConfig();
        final dbPath =
            '${dbConfig.mysql.host}:${dbConfig.mysql.port}/${dbConfig.mysql.database}';
        AppLogger.info('MySQL连接信息已设置为: $dbPath');
      }

      AppLogger.info('数据库类型切换完成: $dbType');
      return dbConfig;
    } catch (e) {
      AppLogger.info('切换数据库类型错误: $e');
      // 回退到原类型
      dbConfig.dbType = oldType;
      rethrow;
    }
  }

  /// 选择自定义数据库路径
  ///
  /// 返回选择的文件路径，如果用户取消则返回 null
  static Future<String?> selectCustomDbPath() async {
    try {
      // 获取应用文档目录作为默认目录
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbDir = path.join(documentsDir.path, 'databases');

      // 确保目录存在
      final dirObj = Directory(dbDir);
      if (!await dirObj.exists()) {
        await dirObj.create(recursive: true);
      }

      // 使用file_selector打开文件选择器
      const XTypeGroup sqliteGroup = XTypeGroup(
        label: 'SQLite数据库',
        extensions: ['db', 'sqlite', 'sqlite3'],
        mimeTypes: [
          'application/octet-stream',
          'application/x-sqlite3',
          'application/vnd.sqlite3',
        ],
        uniformTypeIdentifiers: ['public.database', 'public.data'],
      );

      // 使用初始目录打开文件选择器（注意：某些平台可能不支持初始目录参数）
      final file = await openFile(
        acceptedTypeGroups: [sqliteGroup],
        initialDirectory: dbDir,
      );

      if (file != null) {
        final filePath = file.path;

        // 检查文件是否存在
        final fileObj = File(filePath);
        if (!(await fileObj.exists())) {
          return null;
        }

        return filePath;
      }

      return null;
    } catch (e) {
      AppLogger.info('选择自定义数据库路径错误: $e');
      return null;
    }
  }

  /// 先选择目录，再选择数据库文件
  ///
  /// 返回选择的文件路径，如果用户取消则返回 null
  static Future<String?> selectCustomDbPathAlternative() async {
    try {
      // Step 1: 先选择目录
      final String? directoryPath = await getDirectoryPath();

      if (directoryPath == null) {
        return null;
      }

      AppLogger.info('选择的目录: $directoryPath');

      // 确认目录存在
      final selectedDir = Directory(directoryPath);
      if (!await selectedDir.exists()) {
        return null;
      }

      // Step 2: 从目录中列出并选择数据库文件
      final List<FileSystemEntity> entities = await selectedDir.list().toList();
      final List<File> dbFiles =
          entities.whereType<File>().where((file) {
            final extension = path.extension(file.path).toLowerCase();
            return extension == '.db' ||
                extension == '.sqlite' ||
                extension == '.sqlite3';
          }).toList();

      // 如果目录中没有数据库文件，提示用户
      if (dbFiles.isEmpty) {
        return null;
      }

      // 返回第一个文件（简化处理，实际应该让用户选择）
      return dbFiles.first.path;
    } catch (e) {
      AppLogger.info('选择数据库路径错误: $e');
      return null;
    }
  }

  /// 获取目录路径
  ///
  /// 返回选择的目录路径，如果用户取消则返回 null
  static Future<String?> getDirectoryPath() async {
    try {
      final String? directoryPath = await getDirectoryPath();
      return directoryPath;
    } on MissingPluginException {
      // 如果平台不支持，返回null
      AppLogger.info('平台不支持目录选择');
      return null;
    } catch (e) {
      AppLogger.info('获取目录路径错误: $e');
      return null;
    }
  }

  /// 保存数据库配置
  ///
  /// [dbConfig] - 数据库配置对象
  ///
  /// 返回 true 表示保存成功，false 表示保存失败
  static Future<bool> saveDatabaseConfig(DatabaseConfig dbConfig) async {
    try {
      await dbConfig.saveConfig();
      return true;
    } catch (e) {
      AppLogger.info('保存数据库配置失败: $e');
      return false;
    }
  }

  /// 检查是否使用的是缓存路径
  ///
  /// [dbPath] - 数据库路径
  ///
  /// 返回 true 表示是缓存路径，false 表示不是
  static bool isUsingCachePath(String dbPath) {
    return dbPath.contains('/cache/') || dbPath.endsWith('.bin');
  }
}

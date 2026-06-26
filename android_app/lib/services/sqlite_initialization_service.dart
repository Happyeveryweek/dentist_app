import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/database_config.dart';
import '../models/database_models.dart';
import '../utils/database_utils.dart';
import '../utils/app_logger.dart';

/// SQLite 初始化服务
/// 职责：SQLite 数据库初始化、路径管理、默认路径设置
class SQLiteInitializationService {
  DatabaseHelper? _dbHelper;
  DatabaseConfig? _dbConfig;
  String _dbPath = '';

  /// 获取数据库路径
  String get dbPath => _dbPath;

  /// 获取 DatabaseHelper 实例
  DatabaseHelper? get dbHelper => _dbHelper;

  /// 设置数据库配置
  void setDatabaseConfig(DatabaseConfig config) {
    _dbConfig = config;
  }

  /// 初始化 SQLite 数据库
  Future<void> initDatabase() async {
    final config = _dbConfig;
    if (config == null) {
      throw Exception('数据库配置未设置');
    }

    AppLogger.info('初始化SQLite数据库...');

    // 设置数据库路径
    if (config.sqlite.path.isEmpty) {
      AppLogger.info('SQLite路径为空，设置默认路径');
      config.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
      AppLogger.info('设置的默认路径: ${config.sqlite.path}');
      await config.saveConfig();
    } else if (!File(config.sqlite.path).existsSync()) {
      AppLogger.info('SQLite路径不存在: ${config.sqlite.path}');
      // 确保目录存在
      final dbDir = Directory(path.dirname(config.sqlite.path));
      if (!dbDir.existsSync()) {
        AppLogger.info('创建数据库目录: ${dbDir.path}');
        await dbDir.create(recursive: true);
      }
    }

    // 设置数据库路径
    _dbPath = config.sqlite.path;
    AppLogger.info('SQLite数据库路径: $_dbPath');

    // 初始化 SQLite 数据库
    try {
      AppLogger.info('开始初始化DatabaseHelper...');
      final helper = DatabaseHelper();
      _dbHelper = helper;
      await helper.database;
      AppLogger.info('SQLite数据库初始化成功');
    } catch (e) {
      AppLogger.info('SQLite数据库初始化失败: $e');
      AppLogger.info('错误堆栈: ${StackTrace.current}');
      throw Exception('SQLite数据库初始化失败: $e');
    }
  }

  /// 初始化 SQLite 并显示通知
  Future<void> initWithNotification() async {
    final config = _dbConfig;
    if (config == null) {
      throw Exception('数据库配置未设置');
    }

    try {
      AppLogger.info('初始化SQLite数据库（带通知）...');

      // 设置数据库路径
      if (config.sqlite.path.isEmpty) {
        config.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
        await config.saveConfig();
      }
      _dbPath = config.sqlite.path;

      // 确保目录存在
      final dbDir = Directory(path.dirname(_dbPath));
      if (!dbDir.existsSync()) {
        await dbDir.create(recursive: true);
      }

      // 初始化 SQLite 数据库
      final helper = DatabaseHelper();
      _dbHelper = helper;
      await helper.database;
      AppLogger.info('SQLite数据库初始化成功');
    } catch (e) {
      AppLogger.info('SQLite数据库初始化失败: $e');
      throw Exception('SQLite数据库初始化失败: $e');
    }
  }

  /// 确保数据库路径存在
  Future<void> ensureDatabasePath() async {
    final config = _dbConfig;
    if (config == null) {
      throw Exception('数据库配置未设置');
    }

    if (config.sqlite.path.isEmpty) {
      config.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
      await config.saveConfig();
    }

    _dbPath = config.sqlite.path;

    // 确保目录存在
    final dbDir = Directory(path.dirname(_dbPath));
    if (!dbDir.existsSync()) {
      await dbDir.create(recursive: true);
    }
  }

  /// 获取 SQLite 数据库实例
  Future<Database?> getDatabase() async {
    final helper = _dbHelper;
    if (helper != null) {
      return await helper.database;
    }
    return null;
  }

  /// 关闭数据库连接
  Future<void> closeDatabase() async {
    final helper = _dbHelper;
    if (helper != null) {
      await helper.closeDatabase();
    }
  }
}

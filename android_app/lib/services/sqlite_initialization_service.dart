import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../models/database_config.dart';
import '../models/database_models.dart';
import '../utils/database_utils.dart';

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
    if (_dbConfig == null) {
      throw Exception('数据库配置未设置');
    }

    print('初始化SQLite数据库...');

    // 设置数据库路径
    if (_dbConfig!.sqlite.path.isEmpty) {
      print('SQLite路径为空，设置默认路径');
      _dbConfig!.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
      print('设置的默认路径: ${_dbConfig!.sqlite.path}');
      await _dbConfig!.saveConfig();
    } else if (!File(_dbConfig!.sqlite.path).existsSync()) {
      print('SQLite路径不存在: ${_dbConfig!.sqlite.path}');
      // 确保目录存在
      final dbDir = Directory(path.dirname(_dbConfig!.sqlite.path));
      if (!dbDir.existsSync()) {
        print('创建数据库目录: ${dbDir.path}');
        await dbDir.create(recursive: true);
      }
    }

    // 设置数据库路径
    _dbPath = _dbConfig!.sqlite.path;
    print('SQLite数据库路径: $_dbPath');

    // 初始化 SQLite 数据库
    try {
      print('开始初始化DatabaseHelper...');
      _dbHelper = DatabaseHelper();
      await _dbHelper!.database;
      print('SQLite数据库初始化成功');
    } catch (e) {
      print('SQLite数据库初始化失败: $e');
      print('错误堆栈: ${StackTrace.current}');
      throw Exception('SQLite数据库初始化失败: $e');
    }
  }

  /// 初始化 SQLite 并显示通知
  Future<void> initWithNotification() async {
    try {
      print('初始化SQLite数据库（带通知）...');

      // 设置数据库路径
      if (_dbConfig!.sqlite.path.isEmpty) {
        _dbConfig!.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
        await _dbConfig!.saveConfig();
      }
      _dbPath = _dbConfig!.sqlite.path;

      // 确保目录存在
      final dbDir = Directory(path.dirname(_dbPath));
      if (!dbDir.existsSync()) {
        await dbDir.create(recursive: true);
      }

      // 初始化 SQLite 数据库
      _dbHelper = DatabaseHelper();
      await _dbHelper!.database;
      print('SQLite数据库初始化成功');
    } catch (e) {
      print('SQLite数据库初始化失败: $e');
      throw Exception('SQLite数据库初始化失败: $e');
    }
  }

  /// 确保数据库路径存在
  Future<void> ensureDatabasePath() async {
    if (_dbConfig == null) {
      throw Exception('数据库配置未设置');
    }

    if (_dbConfig!.sqlite.path.isEmpty) {
      _dbConfig!.sqlite.path = await DatabaseUtils.getDefaultDatabasePath();
      await _dbConfig!.saveConfig();
    }

    _dbPath = _dbConfig!.sqlite.path;

    // 确保目录存在
    final dbDir = Directory(path.dirname(_dbPath));
    if (!dbDir.existsSync()) {
      await dbDir.create(recursive: true);
    }
  }

  /// 获取 SQLite 数据库实例
  Future<Database?> getDatabase() async {
    if (_dbHelper != null) {
      return await _dbHelper!.database;
    }
    return null;
  }

  /// 关闭数据库连接
  Future<void> closeDatabase() async {
    if (_dbHelper != null) {
      await _dbHelper!.closeDatabase();
    }
  }
}

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:mysql1/mysql1.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import '../utils/datetime_formatter.dart';



// 移除随访记录相关导入
import '../models/user.dart';

import '../models/material_image.dart';
// 移除对SettingsProvider的引用，避免循环依赖
import '../utils/pinyin_util.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import 'patient_provider.dart';
import '../utils/app_paths.dart';
import '../models/database_structure_log.dart';
import '../models/schemas/table_schema.dart';
import '../models/schemas/mysql_schema.dart';
import '../models/schemas/sqlite_schema.dart';


class DatabaseProvider extends ChangeNotifier {
  static const String DB_NAME = 'dentist_clinic.db';
  static const int DB_VERSION = 3;

  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;

  // MySQL连接参数 - 已移动到SettingsProvider
  // 请使用SettingsProvider中的MySQL设置

  // 数据源类型
  String _dataSourceType = 'sqlite';

  // 刷新标志
  bool _dashboardNeedRefresh = false;

  // 数据库路径
  String? _sqliteDbPath;
  String? _customSqliteDbPath;
  String? _databasePath; // 添加缺失的字段
  Map<String, dynamic>? _mysqlSettings; // MySQL连接设置
  Map<String, dynamic>? _lastMySQLSettings; // 用于临时存储MySQL设置
  
  // MySQL连接参数 - 用于内部操作
  String _mysqlHost = 'localhost';
  String _mysqlPort = '3306';
  String _mysqlDatabase = 'dentist_db';
  String _mysqlUsername = 'root';
  String _mysqlPassword = '';

  // Getters
  Database? get database => _database;
  bool get initialized => _database != null || _mysqlConnection != null;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  String get dataSourceType => _dataSourceType;

  bool get dashboardNeedRefresh => _dashboardNeedRefresh;

  // 当前用户信息
  User? _currentUser;

  // 获取当前用户
  Future<User?> getCurrentUser() async {
    if (_currentUser != null) {
      return _currentUser;
    }

    // 从数据库中获取当前登录用户信息
    return _currentUser;
  }

  // 设置当前用户
  void setCurrentUser(User user) {
    _currentUser = user;
  }

  // 初始化数据库
  Future<void> initDatabase(
      {String? customPath, Map<String, dynamic>? mysqlSettings}) async {
    print('开始初始化数据库...');
    print('当前数据源类型: $_dataSourceType');
    print('当前工作目录: ${Directory.current.path}');
    print('可执行文件路径: ${Platform.resolvedExecutable}');

    try {
      // 关闭现有连接
      if (_dataSourceType == 'sqlite') {
        if (_database != null) {
          await _database!.close();
          _database = null;
        }

        // 使用自定义路径或默认路径
        String dbPath;
        if (customPath != null && customPath.isNotEmpty) {
          print('自定义路径: $customPath');
          dbPath = customPath;
          _customSqliteDbPath = customPath;
        } else {
          try {
            // 使用应用数据目录
            dbPath = AppPaths.databasePath;
            print('使用应用数据目录: $dbPath');
          } catch (e) {
            print('AppPaths未初始化，使用默认路径: $e');
            final dbDir = await getDatabasesPath();
            dbPath = path.join(dbDir, DB_NAME);
            print('默认路径: $dbPath');
          }
        }

        print('使用自定义SQLite数据库路径: $dbPath');
        print('初始化SQLite数据库...');
        _database = await openDatabase(
          dbPath,
          version: DB_VERSION,
          onCreate: _createDatabase,
          onUpgrade: _upgradeDatabase,
        );
        print('SQLite数据库初始化完成，路径: ${_database!.path}');
      } else if (_dataSourceType == 'mysql') {
        // 检查是否已经有有效的MySQL连接
        if (_mysqlConnection != null) {
          try {
            // 测试现有连接是否仍然有效
            await _mysqlConnection!.query('SELECT 1');
            print('现有MySQL连接仍然有效，无需重新初始化');
            // 数据库初始化完成，表结构检测由SettingsProvider统一管理
            _markAllDataForRefresh();
            notifyListeners();
            print('数据库初始化完成（使用现有连接）');
            return;
          } catch (e) {
            print('现有MySQL连接已失效，需要重新建立: $e');
            // 关闭失效的连接
            try {
              await _mysqlConnection!.close();
            } catch (closeError) {
              print('关闭失效MySQL连接时出错: $closeError');
            }
            _mysqlConnection = null;
          }
        }

        // 使用提供的设置
        if (mysqlSettings == null) {
          throw Exception('MySQL设置不能为空，请先配置MySQL连接参数');
        }
        
        final host = mysqlSettings['host'];
        final port = int.tryParse(mysqlSettings['port']?.toString() ?? '3306') ?? 3306;
        final database = mysqlSettings['database'];
        final username = mysqlSettings['username'];
        final password = mysqlSettings['password'];
        
        // 验证必要的参数
        if (host == null || host.isEmpty || 
            database == null || database.isEmpty || 
            username == null || username.isEmpty) {
          throw Exception('MySQL连接参数不完整，请检查host、database和username设置');
        }

        print('MySQL连接参数: $host:$port/$database 用户:$username');

        // MySQL设置已移动到SettingsProvider，不再需要保存到内部变量
        print('使用SettingsProvider中的MySQL设置进行连接');

        try {
          print('正在连接MySQL数据库...');
          _mysqlConnection = await MySqlConnection.connect(
            ConnectionSettings(
              host: host,
              port: port,
              db: database,
              user: username,
              password: password,
            ),
          );
          // 强制设置会话字符集，防止客户端/服务端协商导致的乱码
          try {
            await _mysqlConnection!.query("SET NAMES 'utf8mb4'");
            await _mysqlConnection!.query("SET character_set_connection = 'utf8mb4'");
            await _mysqlConnection!.query("SET character_set_results = 'utf8mb4'");
          } catch (e) {
            print('设置MySQL会话字符集失败: $e');
          }

          print('MySQL数据库连接成功');

          // 验证连接是否正常
          try {
            final results = await _mysqlConnection!.query('SELECT 1');
            print('MySQL连接测试: ${results.isNotEmpty ? '成功' : '失败'}');
            
            // 连接成功后，创建MySQL表结构
            await _createMySQLTables();
          } catch (e) {
            print('MySQL连接测试失败: $e');
            throw Exception('MySQL连接测试失败: $e');
          }
        } catch (e) {
          print('MySQL连接初始化失败: $e');
          throw Exception('MySQL数据库连接失败: $e');
        }
      }

      // 数据库初始化完成，表结构检测由SettingsProvider统一管理
      // 标记所有数据需要刷新
      _markAllDataForRefresh();
      notifyListeners();
      print('数据库初始化完成');
      
      // 在数据库初始化完成后，可以在这里添加自动表结构检测的逻辑
      // 但为了避免循环依赖，这里暂时不直接调用SettingsProvider
    } catch (e) {
      print('初始化数据库时出错: $e');
      rethrow;
    }
  }

  // 初始化SQLite数据库
  Future<Database> initSQLiteDatabase() async {
    // 为Windows应用使用sqflite_ffi
    sqfliteFfiInit();

    String dbPath;

    // 检查是否使用自定义路径
    if (_customSqliteDbPath != null && _customSqliteDbPath!.isNotEmpty) {
      dbPath = _customSqliteDbPath!;
      print('使用自定义SQLite数据库路径: $dbPath');

      // 如果指定的数据库文件不存在，创建它
      if (!await File(dbPath).exists()) {
        print('指定的SQLite数据库文件不存在，将创建新文件: $dbPath');
        // 确保目录存在
        final dbDir = Directory(path.dirname(dbPath));
        if (!await dbDir.exists()) {
          await dbDir.create(recursive: true);
          print('创建数据库目录: ${dbDir.path}');
        }
      }
    } else {
      // 使用默认路径
      try {
        // 优先使用应用数据目录
        dbPath = AppPaths.databasePath;
        print('使用应用数据目录: $dbPath');
      } catch (e) {
        print('AppPaths未初始化，尝试文档目录: $e');
        try {
          final documentsDirectory = await getApplicationDocumentsDirectory();
          dbPath = path.join(documentsDirectory.path, DB_NAME);
          print('使用文档目录: $dbPath');
        } catch (e2) {
          print('获取文档目录失败: $e2，使用当前目录');
          // 如果获取文档目录失败，使用当前目录
          dbPath = path.join(Directory.current.path, DB_NAME);
          print('使用当前目录作为数据库路径: $dbPath');
        }
      }
    }

    // 确保数据库目录存在
    final dbDir = Directory(path.dirname(dbPath));
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
      print('创建数据库目录: ${dbDir.path}');
    }

    // 打开数据库
    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DB_VERSION,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      ),
    );
  }

  // 确保SQLite数据库可用的方法（紧急情况使用）
  Future<void> ensureSQLiteDatabase() async {
    try {
      print('确保SQLite数据库可用...');
      
      if (_database == null) {
        _database = await initSQLiteDatabase();
        print('SQLite数据库初始化成功');
      } else {
        // 测试现有数据库连接
        try {
          await _database!.query('SELECT 1');
          print('现有SQLite数据库连接正常');
        } catch (e) {
          print('现有SQLite数据库连接异常，重新初始化: $e');
          try {
            await _database!.close();
          } catch (_) {}
          _database = await initSQLiteDatabase();
          print('SQLite数据库重新初始化成功');
        }
      }
      
      // 确保基本表结构存在
      await _ensureBasicTables();
      
    } catch (e) {
      print('确保SQLite数据库可用失败: $e');
      rethrow;
    }
  }

  // 确保基本表结构存在
  Future<void> _ensureBasicTables() async {
    if (_database == null) return;
    
    try {
      // 检查users表是否存在
      final tables = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
      );
      
      if (tables.isEmpty) {
        print('users表不存在，创建基本表结构...');
        await _createDatabase(_database!, DB_VERSION);
      } else {
        print('基本表结构已存在');
      }
    } catch (e) {
      print('检查基本表结构时出错: $e');
      // 如果检查失败，尝试创建表结构
      try {
        await _createDatabase(_database!, DB_VERSION);
      } catch (createError) {
        print('创建基本表结构失败: $createError');
      }
    }
  }

  // 初始化MySQL连接
  Future<MySqlConnection> initMySQLConnection({Map<String, dynamic>? mysqlSettings}) async {
    // 使用传入的MySQL设置
    if (mysqlSettings == null) {
      throw Exception('MySQL设置不能为空，请先配置MySQL连接参数');
    }
    
    final settings = ConnectionSettings(
      host: mysqlSettings['host'],
              port: int.tryParse(mysqlSettings['port']?.toString() ?? '3306') ?? 3306,
      user: mysqlSettings['username'],
      password: mysqlSettings['password'],
      db: mysqlSettings['database'],
    );

    // 使用3秒连接超时，快速失败以支持降级
    final connection = await MySqlConnection.connect(settings).timeout(
      const Duration(seconds: 3),
      onTimeout: () => throw TimeoutException('MySQL连接超时，请检查网络和服务器配置'),
    );

    // 确保必要的表存在 - 现在由新的Schema架构统一管理
    // await _createMySQLTables(connection);

    return connection;
  }

  /// 初始化MySQL连接（不改变当前数据源类型）
  Future<void> initializeMySQLConnection(Map<String, dynamic> mysqlSettings) async {
    try {
      print('初始化MySQL连接...');
      
      if (_mysqlConnection != null) {
        try {
          // 测试现有连接（5秒超时）
          await _mysqlConnection!.query('SELECT 1').timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('MySQL连接验证超时'),
          );
          print('现有MySQL连接可用');
          return;
        } catch (e) {
          print('现有MySQL连接失效，重新建立连接');
          try {
            await _mysqlConnection!.close();
          } catch (_) {}
          _mysqlConnection = null;
        }
      }
      
      // 使用3秒连接超时，快速失败以支持降级
      _mysqlConnection = await MySqlConnection.connect(
        ConnectionSettings(
          host: mysqlSettings['host'],
          port: mysqlSettings['port'],
          db: mysqlSettings['database'],
          user: mysqlSettings['username'],
          password: mysqlSettings['password'],
        ),
      ).timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw TimeoutException('MySQL连接超时，请检查网络和服务器配置'),
      );
      
      // 设置字符集
      await _mysqlConnection!.query("SET NAMES 'utf8mb4'");
      await _mysqlConnection!.query("SET character_set_connection = 'utf8mb4'");
      await _mysqlConnection!.query("SET character_set_results = 'utf8mb4'");
      
      print('MySQL连接初始化成功');
    } catch (e) {
      print('初始化MySQL连接失败: $e');
      rethrow;
    }
  }

  // 确保所有必要的表都存在
  Future<void> _ensureTablesExist() async {
    if (_database == null) return;
    
    print('检查并确保所有必要的表都存在...');
    
    try {

      
      // 财务相关表由FinancialProvider负责创建
      
      print('所有必要的表检查完成');
    } catch (e) {
      print('检查表存在性时出错: $e');
    }
  }
  

  

  

  

  

  


  // 创建SQLite数据库表
  Future<void> _createDatabase(Database db, int version) async {
    print('使用新的分离式架构创建SQLite数据库表...');
    
    try {
      // 使用新的Schema架构创建所有表
      final tableNames = [
        'patients',
        'appointments',
        'financial_records',
        'financial_items',
        'materials',
        'material_images',
        'patient_materials',
        'purchase_records',
        'purchase_items',
        'users',
        'database_structure_logs',
        'patient_medical_records',
        'medical_record_templates',
      ];

      for (final tableName in tableNames) {
        try {
          final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.sqlite);
          
          // 创建表
          await db.execute(schema.createTableSql);
          print('成功创建表: $tableName');
          
          // 创建索引（如果有的话）
          for (final indexSql in schema.indexDefinitions) {
            if (!indexSql.contains('PRIMARY KEY')) {
              await db.execute(indexSql);
              print('成功创建索引: $tableName - ${indexSql.substring(0, 50)}...');
            }
          }
        } catch (e) {
          print('创建表 $tableName 时出错: $e');
        }
      }

      // 添加默认管理员用户
      try {
        final DateFormat dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
        final hashedPassword = _hashPassword('123456');
        
        final now = dateFormat.format(DateTime.now());
        await db.insert('users', {
          'username': 'admin',
          'email': 'admin@example.com',
          'password': hashedPassword,
          'role': 'admin',
          'doctor': '系统管理员',
          'avatar': 'avatar_5',
          'created_at': now,
          'updated_at': now,
        });
        
        print('成功创建默认管理员用户: admin/123456');
      } catch (e) {
        print('创建默认管理员用户时出错: $e');
      }
      
      print('SQLite数据库表创建完成');
    } catch (e) {
      print('使用新架构创建数据库表时出错: $e');
      rethrow;
    }
  }

  // 创建MySQL数据库表
  Future<void> _createMySQLTables() async {
    if (_mysqlConnection == null) {
      print('MySQL连接未建立，无法创建表');
      return;
    }
    
    print('使用新的分离式架构创建MySQL数据库表...');
    
    try {
      final tableNames = [
        'patients',
        'appointments',
        'financial_records',
        'financial_items',
        'materials',
        'material_images',
        'patient_materials',
        'purchase_records',
        'purchase_items',
        'users',
        'database_structure_logs',
        'patient_medical_records',
        'medical_record_templates',
      ];

      for (final tableName in tableNames) {
        try {
          final schema = TableSchemaFactory.getSchema(tableName, DatabaseType.mysql);
          
          // 创建表
          await _mysqlConnection!.query(schema.createTableSql);
          print('成功创建MySQL表: $tableName');
          
          // 创建索引（如果有的话）
          for (final indexSql in schema.indexDefinitions) {
            if (!indexSql.contains('PRIMARY KEY')) {
              try {
                // 提取索引名称
                final indexNameMatch = RegExp(r'CREATE (?:UNIQUE )?INDEX (\w+)').firstMatch(indexSql);
                final indexName = indexNameMatch?.group(1) ?? 'unknown';
                
                // 检查索引是否已存在
                final checkResult = await _mysqlConnection!.query(
                  "SELECT COUNT(*) as count FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = ? AND index_name = ?",
                  [tableName, indexName]
                );
                
                final indexExists = checkResult.first['count'] > 0;
                
                if (!indexExists) {
                  await _mysqlConnection!.query(indexSql);
                  final displayText = indexSql.length > 50 ? '${indexSql.substring(0, 50)}...' : indexSql;
                  print('成功创建MySQL索引: $tableName - $displayText');
                } else {
                  final displayText = indexSql.length > 50 ? '${indexSql.substring(0, 50)}...' : indexSql;
                  print('MySQL索引已存在，跳过创建: $tableName - $displayText');
                }
              } catch (e) {
                final displayText = indexSql.length > 50 ? '${indexSql.substring(0, 50)}...' : indexSql;
                print('创建MySQL索引失败: $tableName - $displayText 错误: $e');
              }
            }
          }
        } catch (e) {
          print('创建MySQL表 $tableName 时出错: $e');
        }
      }
      
      print('MySQL数据库表创建完成');
    } catch (e) {
      print('使用新架构创建MySQL数据库表时出错: $e');
      rethrow;
    }
  }

  // 数据库升级
  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('数据库升级: 从 v$oldVersion 到 v$newVersion');

    // 如果新版本高于旧版本，执行升级逻辑
    if (oldVersion < newVersion) {
      // 添加新表或修改表结构的逻辑
      print('执行数据库升级操作...');

      // 随访表已移除

      // 财务和材料采购表由相应的Provider负责创建
      if (oldVersion < 2) {
        print('财务和材料采购表由FinancialProvider和MaterialProvider负责创建...');
      }
      
      // 版本3：材料表升级由MaterialProvider负责
      if (oldVersion < 3) {
        print('版本3材料表升级由MaterialProvider负责...');
      }
    }
  }

  // 重置数据库（删除现有数据库文件，重新创建）
  Future<void> resetDatabase() async {
    print('正在重置数据库...');
    
    try {
      // 关闭现有连接
      await closeDatabase();
      
      // 删除数据库文件
      if (_sqliteDbPath != null) {
        final dbFile = File(_sqliteDbPath!);
        if (await dbFile.exists()) {
          await dbFile.delete();
          print('已删除数据库文件: $_sqliteDbPath');
        }
      }
      
      // 重新初始化数据库
      await initDatabase();
      print('数据库重置完成');
    } catch (e) {
      print('重置数据库时出错: $e');
      rethrow;
    }
  }

  // 关闭数据库连接
  Future<void> closeDatabase() async {
    print('正在关闭数据库连接...');

    try {
      if (_database != null) {
        print('关闭SQLite数据库连接');
        await _database!.close();
        _database = null;
        print('SQLite数据库连接已关闭');
      }

      if (_mysqlConnection != null) {
        print('关闭MySQL数据库连接');
        try {
          await _mysqlConnection!.close();
          print('MySQL数据库连接已关闭');
        } catch (e) {
          print('关闭MySQL连接时出错: $e');
          // 继续执行，即使关闭时出错
        }
        _mysqlConnection = null;
      }
      print('所有数据库连接已关闭');
    } catch (e) {
      print('关闭数据库连接时出错: $e');
      // 继续执行，不阻止程序运行
    }
  }

  // 密码哈希方法
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  // 标记刷新
  void markDashboardNeedRefresh() {
    _dashboardNeedRefresh = true;
    notifyListeners();
  }

  // 重置刷新标志



  void resetDashboardRefreshFlag() {
    _dashboardNeedRefresh = false;
  }

  // 数据库备份方法
  Future<String> backupDatabase({
    String? backupPath,
    Function(String)? onLogSuccess,
    Function(String)? onLogFailure,
    String? backupDataSource, // 新增：指定备份数据源
  }) async {
    try {
      // 使用传入的备份路径
      final userBackupPath = backupPath ?? '';

      if (userBackupPath.isEmpty) {
        final errorMsg = '请设置备份路径';
        // 记录备份失败日志
        if (onLogFailure != null) {
          onLogFailure(errorMsg);
        }
        throw Exception(errorMsg);
      }

      // 确保备份目录存在
      final userBackupDir = Directory(userBackupPath);
      if (!await userBackupDir.exists()) {
        try {
          // 尝试创建备份目录
          await userBackupDir.create(recursive: true);
          print('创建备份目录: $userBackupPath');
        } catch (dirError) {
          final errorMsg = '无法创建备份目录: $dirError';
          // 记录备份失败日志
          if (onLogFailure != null) {
            onLogFailure(errorMsg);
        }
          throw Exception(errorMsg);
        }
      }

      String finalBackupPath;
      
      // 根据备份数据源设置选择备份方法
      final targetDataSource = backupDataSource ?? _dataSourceType;
      
      if (targetDataSource == 'mysql') {
        // 直接使用MySQL备份方法，不检查当前数据源
        finalBackupPath = await backupMySQLDatabase(backupPath: userBackupPath);
      } else {
        // 直接使用SQLite备份方法，不检查当前数据源
        finalBackupPath = await backupSQLiteDatabase(backupPath: userBackupPath);
      }

      // 备份成功，记录备份日志
      if (onLogSuccess != null) {
        onLogSuccess(finalBackupPath);
      }

      // 备份完成，返回备份路径
      print('数据库备份完成: $finalBackupPath (数据源: $targetDataSource)');

      return finalBackupPath;
    } catch (e) {
      print('执行数据库备份时出错: $e');
      rethrow;
    }
  }

  // 备份日志记录已移动到SettingsProvider
  // 请使用SettingsProvider中的相关方法记录备份操作

  // SQLite数据库备份方法 - 使用文件复制
  Future<String> backupSQLiteDatabase({String? backupPath}) async {
    try {
      // 确保数据库连接已初始化
      if (_database == null) {
        throw Exception('SQLite数据库未初始化');
      }

      // 获取当前数据库文件路径
      String dbPath;
      if (_customSqliteDbPath != null && _customSqliteDbPath!.isNotEmpty) {
        dbPath = _customSqliteDbPath!;
      } else {
        try {
          // 使用应用数据目录
          dbPath = AppPaths.databasePath;
        } catch (e) {
          print('AppPaths未初始化，使用默认路径: $e');
          final dbDir = await getDatabasesPath();
          dbPath = path.join(dbDir, DB_NAME);
        }
      }

      // 确保数据库文件存在
      if (!await File(dbPath).exists()) {
        throw Exception('数据库文件不存在: $dbPath');
      }

      // 使用传入的备份路径
      final userBackupPath = backupPath ?? '';

      if (userBackupPath.isEmpty) {
        throw Exception('未设置备份目录');
      }

      // 确保备份目录存在
      final backupDir = Directory(userBackupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 生成备份文件名
      final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-');
      final backupFilePath =
          path.join(userBackupPath, 'sqlite_backup_$timestamp.db');

      // 关闭数据库连接，确保没有写入操作
      await _database!.close();
      _database = null;

      // 复制数据库文件
      await File(dbPath).copy(backupFilePath);

      // 重新打开数据库连接
      _database = await openDatabase(
        dbPath,
        version: DB_VERSION,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );

      print('SQLite数据库文件已备份到: $backupFilePath');
      return backupFilePath;
    } catch (e) {
      print('SQLite数据库备份出错: $e');

      // 如果数据库连接已关闭，尝试重新打开
      if (_database == null) {
        try {
          // 获取当前数据库文件路径
          String dbPath;
          if (_customSqliteDbPath != null && _customSqliteDbPath!.isNotEmpty) {
            dbPath = _customSqliteDbPath!;
          } else {
            try {
              // 使用应用数据目录
              dbPath = AppPaths.databasePath;
            } catch (e) {
              print('AppPaths未初始化，使用默认路径: $e');
              final dbDir = await getDatabasesPath();
              dbPath = path.join(dbDir, DB_NAME);
            }
          }

          // 重新打开数据库连接
          _database = await openDatabase(
            dbPath,
            version: DB_VERSION,
            onCreate: _createDatabase,
            onUpgrade: _upgradeDatabase,
          );
        } catch (reopenError) {
          print('重新打开数据库连接失败: $reopenError');
        }
      }

      rethrow;
    }
  }

  // 从备份文件恢复数据库
  Future<void> restoreFromBackup(String backupFilePath) async {
    try {
      // 读取备份文件
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在');
      }

      final backupData = jsonDecode(await backupFile.readAsString());

      if (dataSourceType == 'mysql') {
        // 清空所有表
        final tables = await mysqlConnection!.query('SHOW TABLES');
        for (var table in tables) {
          final values = table.values;
          final tableName = values != null && values.isNotEmpty
              ? values.first.toString()
              : '';
          if (tableName.isNotEmpty) {
            await mysqlConnection!.query('TRUNCATE TABLE $tableName');
          }
        }

        // 恢复数据
        for (var entry in backupData.entries) {
          final tableName = entry.key;
          final records = entry.value as List;

          for (var record in records) {
            final fields = record.keys.join(', ');
            final placeholders = List.filled(record.length, '?').join(', ');
            final values = record.values.map((value) {
              // 处理 DateTime 字符串
              if (value is String && value.contains('T')) {
                try {
                  return DateTimeFormatter.fromDbString(value);
                } catch (e) {
                  return value;
                }
              }
              return value;
            }).toList();

            await mysqlConnection!.query(
              'INSERT INTO $tableName ($fields) VALUES ($placeholders)',
              values,
            );
          }
        }
      } else {
        // 清空所有表
        final tables = await database!.query('sqlite_master',
            where: 'type = ? AND name NOT LIKE ?',
            whereArgs: ['table', 'sqlite_%']);
        for (var table in tables) {
          final tableName = table['name'] as String;
          await database!.delete(tableName);
        }

        // 恢复数据
        for (var entry in backupData.entries) {
          final tableName = entry.key;
          final records = entry.value as List;

          for (var record in records) {
            // 处理 DateTime 字符串
            final processedRecord = Map<String, dynamic>.from(record);
            processedRecord.forEach((key, value) {
              if (value is String && value.contains('T')) {
                try {
                  processedRecord[key] = DateTimeFormatter.fromDbString(value);
                } catch (e) {
                  // 如果解析失败，保持原值
                }
              }
            });

            await database!.insert(tableName, processedRecord);
          }
        }
      }

      print('数据库恢复成功');
    } catch (e) {
      print('执行数据库恢复时出错: $e');
      rethrow;
    }
  }

  // 检查MySQL表是否存在
  Future<bool> _checkTableExists(String tableName, {String? databaseName}) async {
    try {
      final dbName = databaseName ?? 'dentist_db'; // 默认数据库名
      final result = await _mysqlConnection!.query(
          'SELECT 1 FROM information_schema.tables WHERE table_schema = ? AND table_name = ?',
          [dbName, tableName]);
      return result.isNotEmpty;
    } catch (e) {
      print('检查表是否存在时出错: $e');
      return false;
    }
  }

  // 数据库恢复方法
  Future<void> restoreDatabase(String filePath) async {
    print('开始从备份文件恢复数据库: $filePath');
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('备份文件不存在: $filePath');
    }

    try {
      if (_dataSourceType == 'sqlite') {
        // 检查文件扩展名
        if (path.extension(filePath).toLowerCase() == '.db') {
          // 使用文件复制方式恢复SQLite数据库
          await restoreSQLiteDatabase(filePath);
        } else {
          // 使用JSON格式恢复 - 原有方式
          await restoreFromBackup(filePath);
        }
      } else if (_dataSourceType == 'mysql') {
        // 从SQL文件恢复MySQL数据库
        await restoreFromMySQLDump(filePath);
      }

      // 标记数据需要刷新
      _markAllDataForRefresh();
      notifyListeners();
    } catch (e) {
      print('恢复数据库时出错: $e');
      rethrow;
    }
  }

  // SQLite数据库恢复方法 - 使用文件复制
  Future<void> restoreSQLiteDatabase(String backupFilePath) async {
    try {
      print('使用文件复制方式恢复SQLite数据库');

      // 确认备份文件存在
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在: $backupFilePath');
      }

      // 关闭现有连接
      if (_database != null) {
        await _database!.close();
        _database = null;
      }

      // 获取目标数据库文件路径
      String dbPath;
      if (_customSqliteDbPath != null && _customSqliteDbPath!.isNotEmpty) {
        dbPath = _customSqliteDbPath!;
      } else {
        try {
          // 使用应用数据目录
          dbPath = AppPaths.databasePath;
        } catch (e) {
          print('AppPaths未初始化，使用默认路径: $e');
          final dbDir = await getDatabasesPath();
          dbPath = path.join(dbDir, DB_NAME);
        }
      }

      // 复制备份文件到数据库位置
      await backupFile.copy(dbPath);
      print('SQLite备份文件已复制到: $dbPath');

      // 重新打开数据库
      _database = await openDatabase(
        dbPath,
        version: DB_VERSION,
        onCreate: _createDatabase,
        onUpgrade: _upgradeDatabase,
      );

      print('SQLite数据库已恢复');
    } catch (e) {
      print('使用文件复制方式恢复SQLite数据库出错: $e');
      rethrow;
    }
  }

  /// 分割SQL转储文件中的SQL语句
  List<String> _splitSqlStatements(String sqlDump) {
    List<String> statements = [];
    StringBuffer currentStatement = StringBuffer();
    bool inString = false;
    bool inComment = false;
    bool inMultiLineComment = false;

    for (int i = 0; i < sqlDump.length; i++) {
      String char = sqlDump[i];
      String nextChar = i < sqlDump.length - 1 ? sqlDump[i + 1] : '';

      // 处理多行注释
      if (!inString && char == '/' && nextChar == '*' && !inComment) {
        inMultiLineComment = true;
        currentStatement.write(char);
        currentStatement.write(nextChar);
        i++; // 跳过 '*'
        continue;
      }

      if (inMultiLineComment && char == '*' && nextChar == '/') {
        inMultiLineComment = false;
        currentStatement.write(char);
        currentStatement.write(nextChar);
        i++; // 跳过 '/'
        continue;
      }

      if (inMultiLineComment) {
        currentStatement.write(char);
        continue;
      }

      // 处理单行注释
      if (!inString &&
          char == '-' &&
          nextChar == '-' &&
          !inComment &&
          !inMultiLineComment) {
        inComment = true;
        currentStatement.write(char);
        currentStatement.write(nextChar);
        i++; // 跳过第二个 '-'
        continue;
      }

      // 处理单行注释结束
      if (inComment && (char == '\n' || char == '\r')) {
        inComment = false;
        currentStatement.write(char);
        continue;
      }

      if (inComment) {
        currentStatement.write(char);
        continue;
      }

      // 处理字符串
      if (char == '\'' && !inComment && !inMultiLineComment) {
        // 检查是否为转义单引号
        if (inString && nextChar == '\'') {
          currentStatement.write(char);
          currentStatement.write(nextChar);
          i++; // 跳过第二个单引号
          continue;
        }
        inString = !inString;
        currentStatement.write(char);
        continue;
      }

      // 语句结束
      if (char == ';' && !inString && !inComment && !inMultiLineComment) {
        currentStatement.write(char);
        String statement = currentStatement.toString().trim();
        if (statement.isNotEmpty) {
          statements.add(statement);
        }
        currentStatement = StringBuffer();
        continue;
      }

      // 添加当前字符到语句
      currentStatement.write(char);
    }

    // 处理没有分号结尾的最后一条语句
    String lastStatement = currentStatement.toString().trim();
    if (lastStatement.isNotEmpty) {
      statements.add(lastStatement);
    }

    return statements;
  }

  // 按照正确的顺序执行SQL语句
  Future<void> _executeMySQLImport(String sqlContent, {Map<String, dynamic>? mysqlSettings}) async {
    // 使用传入的MySQL设置重新建立连接
    if (mysqlSettings == null) {
      throw Exception('MySQL设置不能为空，请先配置MySQL连接参数');
    }
    
    _mysqlConnection = await MySqlConnection.connect(
      ConnectionSettings(
        host: mysqlSettings['host'],
        port: int.tryParse(mysqlSettings['port']?.toString() ?? '3306') ?? 3306,
        db: mysqlSettings['database'],
        user: mysqlSettings['username'],
        password: mysqlSettings['password'],
      ),
    );

    // 处理SQL中的日期时间格式
    sqlContent = _fixDateTimeFormatsInSQL(sqlContent);

    // 备份前先尝试获取所有表名
    List<String> tables = [];
    try {
      final Results results = await _mysqlConnection!.query('SHOW TABLES');
      for (var row in results) {
        if (row.values != null && row.values!.isNotEmpty) {
          tables.add(row.values!.first.toString());
        }
      }
      print('找到MySQL数据库中的表: ${tables.join(', ')}');

      // 先禁用外键约束检查
      await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 0');

      // 清空所有表
      for (String table in tables) {
        try {
          print('正在截断表: $table');
          await _mysqlConnection!.query('TRUNCATE TABLE `$table`');
        } catch (e) {
          print('截断表 $table 失败: $e');
          // 继续尝试其他表
        }
      }
    } catch (e) {
      print('获取表名或截断表时出错: $e');
      // 继续执行导入
    }

    // 处理牙齿状况的数据格式
    final patientProvider = PatientProvider(
      mysqlConnection: _mysqlConnection,
      dataSourceType: _dataSourceType,
    );
    sqlContent = patientProvider.processDentalConditionFormat(sqlContent);

    // 分割SQL语句
    final statements = _splitSqlStatements(sqlContent);
    print('找到 ${statements.length} 条SQL语句需要执行');

    // 先禁用外键约束，确保可以按任意顺序插入数据
    await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 0');

    // 按顺序执行每个SQL语句，但先执行表结构语句，再执行数据插入语句
    List<String> createStatements = [];
    Map<String, List<String>> insertStatementsByTable = {
      'users': [],
      'patients': [],
    };
    List<String> otherStatements = [];

    // 表的处理顺序（从无依赖到有依赖）
    final tableOrder = [
      'users',
      'patients',
    ];

    // 分类语句
    for (var statement in statements) {
      statement = statement.trim();
      if (statement.isEmpty) continue;

      if (statement.toUpperCase().contains('CREATE TABLE')) {
        createStatements.add(statement);
      } else if (statement.toUpperCase().contains('INSERT INTO')) {
        // 确定插入的是哪个表
        String tableName = '';
        RegExp tableNameRegex = RegExp(r'INSERT INTO `?(\w+)`?');
        var match = tableNameRegex.firstMatch(statement);

        if (match != null && match.groupCount >= 1) {
          tableName = match.group(1)!.toLowerCase();

          // 确保表在映射中存在
          if (!insertStatementsByTable.containsKey(tableName)) {
            insertStatementsByTable[tableName] = [];
          }

          insertStatementsByTable[tableName]!.add(statement);
        } else {
          // 如果无法确定表名，则添加到其他语句中
          otherStatements.add(statement);
        }
      } else {
        otherStatements.add(statement);
      }
    }

    print(
        '分类结果: 创建表语句 ${createStatements.length} 条，其他语句 ${otherStatements.length} 条');

    // 打印每个表的插入语句数量
    for (var tableName in insertStatementsByTable.keys) {
      print(
          '表 $tableName 的插入语句: ${insertStatementsByTable[tableName]?.length ?? 0} 条');
    }

    // 执行语句的顺序：先创建表，再执行其他语句，最后按表的依赖顺序执行插入数据
    int successCount = 0;
    int errorCount = 0;

    // 1. 先执行创建表语句
    for (var i = 0; i < createStatements.length; i++) {
      try {
        await _mysqlConnection!.query(createStatements[i]);
        successCount++;
        print('成功执行创建表语句 ${i + 1}/${createStatements.length}');
      } catch (e) {
        errorCount++;
        print('执行创建表语句失败 (${i + 1}/${createStatements.length}): ${e}');
      }
    }

    // 2. 执行其他语句
    for (var i = 0; i < otherStatements.length; i++) {
      try {
        await _mysqlConnection!.query(otherStatements[i]);
        successCount++;
        print('成功执行其他语句 ${i + 1}/${otherStatements.length}');
      } catch (e) {
        errorCount++;
        print('执行其他语句失败 (${i + 1}/${otherStatements.length}): ${e}');
      }
    }

    // 3. 按表的依赖顺序执行插入语句
    for (var tableName in tableOrder) {
      var statements = insertStatementsByTable[tableName] ?? [];
      print('开始执行表 $tableName 的 ${statements.length} 条插入语句');

      for (var i = 0; i < statements.length; i++) {
        try {
          await _mysqlConnection!.query(statements[i]);
          successCount++;

          // 每20条语句打印一次进度
          if (i % 20 == 0 || i == statements.length - 1) {
            print('已成功执行表 $tableName 的 ${i + 1}/${statements.length} 条插入语句');
          }
        } catch (e) {
          errorCount++;
          print(
              '执行表 $tableName 的插入语句失败 (${i + 1}/${statements.length}): ${statements[i].substring(0, min(50, statements[i].length))}...');
          print('错误: $e');
        }
      }
    }

    // 处理未分类的其他表的插入语句
    for (var tableName in insertStatementsByTable.keys) {
      if (!tableOrder.contains(tableName)) {
        var statements = insertStatementsByTable[tableName] ?? [];
        if (statements.isNotEmpty) {
          print('开始执行表 $tableName 的 ${statements.length} 条插入语句');

          for (var i = 0; i < statements.length; i++) {
            try {
              await _mysqlConnection!.query(statements[i]);
              successCount++;

              // 每20条语句打印一次进度
              if (i % 20 == 0 || i == statements.length - 1) {
                print(
                    '已成功执行表 $tableName 的 ${i + 1}/${statements.length} 条插入语句');
              }
            } catch (e) {
              errorCount++;
              print(
                  '执行表 $tableName 的插入语句失败 (${i + 1}/${statements.length}): ${statements[i].substring(0, min(50, statements[i].length))}...');
              print('错误: $e');
            }
          }
        }
      }
    }

    // 恢复外键约束检查
    await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 1');

    print('MySQL导入完成: 成功 $successCount 条，失败 $errorCount 条');

    if (errorCount > 0 && successCount == 0) {
      throw Exception('所有SQL语句执行失败，数据库恢复失败');
    }
  }

  // 修复SQL语句中的日期时间格式，使用本地时间格式
  String _fixDateTimeFormatsInSQL(String sqlContent) {
    // 查找并修复INSERT语句中的日期时间值
    final insertRegex = RegExp(
        r"INSERT INTO `(\w+)`\s*\(([^)]+)\)\s*VALUES\s*\(([^)]+)\)",
        multiLine: true);

    return sqlContent.replaceAllMapped(insertRegex, (match) {
      String tableName = match.group(1) ?? '';
      String columns = match.group(2) ?? '';
      String values = match.group(3) ?? '';

      // 分割列名和值
      List<String> columnList =
          columns.split(',').map((c) => c.trim()).toList();
      List<String> valueList = values.split(',').map((v) => v.trim()).toList();

      // 处理每个值
      for (int i = 0; i < valueList.length; i++) {
        String value = valueList[i];

        // 检查是否是日期时间值
        if (value.startsWith("'") && value.endsWith("'")) {
          String dateStr = value.substring(1, value.length - 1);

          // 尝试解析日期时间
          try {
            DateTime? dateTime;
            if (dateStr.contains('T')) {
              // ISO 8601格式
              dateTime = DateTimeFormatter.fromDbString(dateStr);
            } else if (dateStr.contains(' ')) {
              // MySQL datetime格式
              dateTime = DateTimeFormatter.fromDbString(dateStr);
            } else {
              // 仅日期格式
              dateTime = DateTimeFormatter.fromDbString(dateStr + ' 00:00:00');
            }

            if (dateTime != null) {
              // 使用本地时间格式
              String localDateTime = dateTime
                  .toLocal()
                  .toString()
                  .replaceAll('T', ' ')
                  .split('.')[0];
              valueList[i] = "'$localDateTime'";
            }
          } catch (e) {
            print('解析日期时间失败: $dateStr, 错误: $e');
          }
        }
      }

      // 重新组合SQL语句
      return "INSERT INTO `$tableName` ($columns) VALUES (${valueList.join(', ')})";
    });
  }





  // 设置数据源类型
  Future<void> setDataSourceType(
    String type, {
    Map<String, dynamic>? mysqlSettings,
    String? customSqlitePath,
  }) async {
    print('开始切换数据源类型到: $type');
    print('当前数据源类型: $_dataSourceType');

    try {
      // 如果切换到相同的数据源类型，检查是否需要重新初始化
      if (_dataSourceType == type) {
        print('数据源类型未改变，检查连接状态...');
        
        if (type == 'sqlite') {
          // 检查SQLite连接是否有效
          if (_database != null) {
            try {
              await _database!.query('SELECT 1');
              print('SQLite连接仍然有效，无需重新初始化');
              return;
            } catch (e) {
              print('SQLite连接已失效，需要重新初始化: $e');
            }
          }
        } else if (type == 'mysql') {
          // 检查MySQL连接是否有效
          if (_mysqlConnection != null) {
            try {
              await _mysqlConnection!.query('SELECT 1');
              print('MySQL连接仍然有效，无需重新初始化');
              return;
            } catch (e) {
              print('MySQL连接已失效，需要重新初始化: $e');
            }
          }
        }
      }

      // 如果切换到SQLite，检查是否有自定义数据库路径
      if (type == 'sqlite') {
        // 从设置中获取SQLite路径
        String? sqliteDbPath = customSqlitePath;
        print('从设置中获取的SQLite路径: $sqliteDbPath');

        // 如果自定义路径为空，使用默认路径
        if (sqliteDbPath == null || sqliteDbPath.isEmpty) {
          print('使用默认SQLite路径');
          try {
            // 使用应用数据目录
            sqliteDbPath = AppPaths.databasePath;
            print('使用应用数据目录: $sqliteDbPath');
          } catch (e) {
            print('AppPaths未初始化，使用系统默认路径: $e');
            final dbPath = await getDatabasesPath();
            sqliteDbPath = path.join(dbPath, DB_NAME);
          }
        }

        // 确保自定义路径不为空
        if (sqliteDbPath.isEmpty) {
          throw Exception('SQLite数据库路径不能为空');
        }

        // 保存自定义路径
        _customSqliteDbPath = sqliteDbPath;
      }

      // 关闭现有数据库连接
      print('关闭现有数据库连接...');
      if (_dataSourceType != type) {
        // 只有在真正切换数据源类型时才关闭连接
        await closeDatabase();
      }

      // 更新数据源类型
      _dataSourceType = type;
      print('数据源类型已切换为: $type');

      // 如果是MySQL，保存设置
      if (type == 'mysql' && mysqlSettings != null) {
        _mysqlHost = mysqlSettings['host'] ?? 'localhost';
        _mysqlPort = mysqlSettings['port']?.toString() ?? '3306';
        _mysqlDatabase = mysqlSettings['database'] ?? 'dentist_db';
        _mysqlUsername = mysqlSettings['username'] ?? 'root';
        _mysqlPassword = mysqlSettings['password'] ?? '';

        // 保存完整的MySQL设置
        _mysqlSettings = {
          'host': _mysqlHost,
          'port': int.tryParse(_mysqlPort) ?? 3306,
          'database': _mysqlDatabase,
          'username': _mysqlUsername,
          'password': _mysqlPassword,
        };

        print(
            '已保存MySQL设置到_mysqlSettings: ${_mysqlSettings.toString().replaceAll(_mysqlPassword, '******')}');
      }

      // 初始化新数据源连接
      print('初始化新数据源连接...');
      if (type == 'sqlite') {
        try {
          print('使用自定义SQLite路径初始化数据库: $_customSqliteDbPath');
          await initDatabase(customPath: _customSqliteDbPath);
        } catch (e) {
          print('常规SQLite初始化失败，尝试紧急初始化: $e');
          // 如果常规初始化失败，尝试紧急初始化
          await ensureSQLiteDatabase();
        }
      } else if (type == 'mysql') {
        await initDatabase(mysqlSettings: mysqlSettings);
      }

      // 标记所有数据需要刷新
      _markAllDataForRefresh();

      print('数据源切换完成');
      notifyListeners();
    } catch (e) {
      print('切换数据源类型时出错: $e');
      rethrow;
    }
  }



  // 测试MySQL连接
  Future<bool> testMySQLConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      if (_dataSourceType != 'mysql') {
        // 如果当前不是MySQL数据源，创建一个临时连接进行测试
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
      } else {
        // 如果已经是MySQL数据源，可能正在使用中，需要检查当前连接是否可用
        if (_mysqlConnection != null) {
          try {
            await _mysqlConnection!.query('SELECT 1');
            return true;
          } catch (e) {
            // 当前连接不可用，尝试重新连接
            try {
              await _mysqlConnection!.close();
            } catch (_) {}

            _mysqlConnection = await MySqlConnection.connect(
              ConnectionSettings(
                host: host,
                port: port,
                db: database,
                user: username,
                password: password,
              ),
            );

            await _mysqlConnection!.query('SELECT 1');
            return true;
          }
        } else {
          // 没有现有连接，创建新连接
          _mysqlConnection = await MySqlConnection.connect(
            ConnectionSettings(
              host: host,
              port: port,
              db: database,
              user: username,
              password: password,
            ),
          );

          await _mysqlConnection!.query('SELECT 1');
          return true;
        }
      }
    } catch (e) {
      print('MySQL连接测试失败: $e');
      return false;
    }
  }

  // 标记所有数据需要刷新
  void _markAllDataForRefresh() {
    markDashboardNeedRefresh();
  }

  // 获取数据库实例
  Future<Database?> getDatabase() async {
    if (_database != null) {
      return _database;
    }

    if (_dataSourceType == 'sqlite') {
      if (_database == null) {
        _database = await initSQLiteDatabase();
      }
      return _database;
    }
    return null;
  }

  


  // MySQL数据库还原方法
  // 注意：此方法执行实际的数据库还原操作，设置管理由SettingsProvider负责

  // 添加新的方法来处理MySQL备份还原
  Future<void> restoreFromMySQLDump(String dumpFilePath, {
    Map<String, dynamic>? mysqlSettings,
    Function(String)? onLogOperation,
  }) async {
    print('开始恢复MySQL数据库...');

    // 检查数据源类型
    if (_dataSourceType != 'mysql') {
      throw Exception('当前数据源不是MySQL');
    }

    // 记录还原操作开始
    if (onLogOperation != null) {
      onLogOperation('MySQL还原开始: $dumpFilePath');
    }

    // 验证MySQL设置参数
    if (mysqlSettings == null) {
      throw Exception('MySQL设置不能为空，请先配置MySQL连接参数');
    }
    
    // 验证参数
    if (mysqlSettings['host'] == null ||
        mysqlSettings['host'].toString().isEmpty ||
        mysqlSettings['database'] == null ||
        mysqlSettings['database'].toString().isEmpty) {
      throw Exception('MySQL连接参数不完整，请检查host和database设置');
    }
    
    print('使用传入的MySQL设置进行还原');

    try {
      print('当前工作目录: ${Directory.current.path}');

      // 检查备份文件是否存在
      final dumpFile = File(dumpFilePath);
      if (!await dumpFile.exists()) {
        throw Exception('备份文件不存在: $dumpFilePath');
      }

      // 使用直接方法执行SQL文件
      try {
        print('开始直接方法执行SQL还原...');

        // 使用AppPaths获取mysql.exe的路径
        final mysqlPath = AppPaths.mysqlExePath;
        print('MySQL工具路径: $mysqlPath');

        // 构建命令行参数 - 直接命令行方式
        final List<String> args = [
          '-h${mysqlSettings['host']}',
          '-P${mysqlSettings['port']}',
          '-u${mysqlSettings['username']}',
          '-p${mysqlSettings['password']}',
          '--default-character-set=utf8mb4',
          mysqlSettings['database'],
          '--execute=source ${dumpFilePath.replaceAll('\\', '/')}',
        ];

        print(
            '执行命令: $mysqlPath ${args.join(' ').replaceAll(mysqlSettings['password'], '******')}');

        // 直接执行mysql命令
        final result = await Process.run(
          mysqlPath,
          args,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        // 检查执行结果
        if (result.exitCode != 0) {
          print('MySQL命令行方式执行失败: ${result.stderr}');
          print('标准输出: ${result.stdout}');
          throw Exception('MySQL还原失败: ${result.stderr}');
        } else {
          print('MySQL命令行方式执行成功');
          print('标准输出: ${result.stdout}');
          return; // 成功执行，直接返回
        }
      } catch (e) {
        print('直接命令行方式执行出错: $e');
        print('尝试其他方法...');
      }

      // 创建临时文件包含认证信息
      try {
        print('尝试使用临时配置文件方式执行...');

        // 使用AppPaths获取mysql.exe的路径
        final mysqlPath = AppPaths.mysqlExePath;
        print('MySQL工具路径: $mysqlPath');

        // 创建临时配置文件
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final configFilePath =
            path.join(Directory.systemTemp.path, 'mysql_config_$timestamp.cnf');
        final configFile = File(configFilePath);

        // 写入配置内容
        await configFile.writeAsString('''
[client]
host=${mysqlSettings['host']}
port=${mysqlSettings['port']}
user=${mysqlSettings['username']}
password=${mysqlSettings['password']}
database=${mysqlSettings['database']}
default-character-set=utf8mb4
''');

        print('创建了临时配置文件: $configFilePath');

        // 构建命令参数
        final args = [
          '--defaults-file=$configFilePath',
          '--execute=source ${dumpFilePath.replaceAll('\\', '/')}',
        ];

        print('执行命令: $mysqlPath ${args.join(' ')}');

        // 执行MySQL命令
        final result = await Process.run(
          mysqlPath,
          args,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        // 删除临时配置文件
        try {
          await configFile.delete();
          print('删除了临时配置文件');
        } catch (e) {
          print('删除临时配置文件时出错: $e');
        }

        // 检查执行结果
        if (result.exitCode != 0) {
          print('配置文件方式执行失败: ${result.stderr}');
          print('标准输出: ${result.stdout}');
          throw Exception('MySQL还原失败: ${result.stderr}');
        } else {
          print('配置文件方式执行成功');
          print('标准输出: ${result.stdout}');
          return; // 成功执行，直接返回
        }
      } catch (e) {
        print('配置文件方式执行出错: $e');
        print('尝试最后方法...');
      }

      // 最后尝试批处理文件方式
      try {
        print('尝试使用批处理方式执行...');

        // 使用AppPaths获取mysql.exe的路径
        final mysqlPath = AppPaths.mysqlExePath;
        print('MySQL工具路径: $mysqlPath');

        // 创建临时批处理文件
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final batchFilePath = path.join(
            Directory.systemTemp.path, 'mysql_restore_$timestamp.bat');
        final batchFile = File(batchFilePath);

        // 编写批处理文件内容 - 处理路径和特殊字符
        final escapedPassword =
            mysqlSettings['password'].toString().replaceAll('"', '\\"');

        final batchContent = '''
@echo off
chcp 65001
cd /d "${path.dirname(mysqlPath)}"
"${path.basename(mysqlPath)}" -h${mysqlSettings['host']} -P${mysqlSettings['port']} -u${mysqlSettings['username']} -p"${escapedPassword}" --default-character-set=utf8mb4 ${mysqlSettings['database']} < "${dumpFilePath}"
if %ERRORLEVEL% NEQ 0 (
  echo 还原失败，错误代码: %ERRORLEVEL%
  exit /b %ERRORLEVEL%
)
''';

        await batchFile.writeAsString(batchContent);
        print('创建了临时批处理文件: $batchFilePath');

        // 使用管理员权限执行批处理文件
        print('正在执行批处理文件...');
        final result = await Process.run(
          batchFilePath,
          [],
          runInShell: true,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );

        // 删除临时批处理文件
        try {
          await batchFile.delete();
          print('删除了临时批处理文件');
        } catch (e) {
          print('删除临时批处理文件时出错: $e');
        }

        // 检查执行结果
        if (result.exitCode != 0) {
          print('批处理方式执行失败: ${result.stderr}');
          print('标准输出: ${result.stdout}');
          throw Exception('MySQL还原失败: ${result.stderr}');
        } else {
          print('批处理方式执行成功');
          print('标准输出: ${result.stdout}');
          return; // 成功执行，直接返回
        }
      } catch (e) {
        print('批处理方式执行出错: $e');
        print('所有常规尝试都失败，尝试直接连接方式...');
      }

      // 如果所有外部命令方式都失败，则尝试读取SQL文件内容并直接用MySQL连接执行
      print('尝试直接读取SQL文件内容并连接执行...');
      String sqlContent;
      try {
        // 尝试以UTF-8编码读取
        sqlContent = await dumpFile.readAsString(encoding: utf8);
      } catch (e) {
        print('UTF-8读取文件失败: $e，尝试Latin1编码');
        // 如果UTF-8读取失败，尝试Latin1编码
        final bytes = await dumpFile.readAsBytes();
        sqlContent = latin1.decode(bytes);
      }

      print('SQL文件读取成功，大小: ${sqlContent.length} 字符');

      // 分割SQL语句并执行
      List<String> statements = _splitSqlStatements(sqlContent);
      print('分割出 ${statements.length} 条SQL语句');

      int successCount = 0;
      int failCount = 0;

      // 禁用外键约束检查
      try {
        await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 0');
        print('已禁用外键约束检查');
      } catch (e) {
        print('禁用外键约束检查失败: $e');
      }

      // 执行每条SQL语句
      for (int i = 0; i < statements.length; i++) {
        String statement = statements[i].trim();
        if (statement.isEmpty || statement.startsWith('--')) {
          continue;
        }

        try {
          await _mysqlConnection!.query(statement);
          successCount++;

          // 每20条语句输出一次进度
          if (i % 20 == 0 || i == statements.length - 1) {
            print('已执行 ${i + 1}/${statements.length} 条SQL语句');
          }
        } catch (e) {
          failCount++;
          print('执行SQL语句失败: $e');
          print(
              '问题语句: ${statement.length > 100 ? statement.substring(0, 100) + "..." : statement}');
          // 继续执行其他语句
        }
      }

      // 重新启用外键约束检查
      try {
        await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 1');
        print('已重新启用外键约束检查');
      } catch (e) {
        print('重新启用外键约束检查失败: $e');
      }

      print('MySQL数据库已从文件还原: $dumpFilePath');
      print('成功执行: $successCount 条语句，失败: $failCount 条语句');

      if (successCount == 0 && failCount > 0) {
        throw Exception('所有SQL语句执行失败，可能存在格式或编码问题');
      }

      // 记录还原操作完成
      if (onLogOperation != null) {
        final success = successCount > 0;
        onLogOperation('MySQL还原完成: ${success ? '成功' : '部分失败'}');
      }
    } catch (e) {
      print('执行MySQL还原时出错: $e');
      rethrow;
    }
  }

  // MySQL备份功能已移动到SettingsProvider
  // 请使用SettingsProvider.backupMySQLDatabase()方法

  // 辅助方法：格式化SQL值
  String _formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is num) return value.toString();
    if (value is DateTime) {
      // 确保DateTime值使用UTC格式
      final utcDate = value.toUtc();
      return "'${DateTimeFormatter.toDbString(value)}'";
    }
    if (value is bool) return value ? '1' : '0';
    return "'${value.toString().replaceAll("'", "''")}'";
  }



  // 获取MySQL工具路径
  String _getMySQLToolPath(String toolName) {
    print('查找MySQL工具: $toolName');
    print('当前工作目录: ${Directory.current.path}');
    print('可执行文件路径: ${Platform.resolvedExecutable}');
    print('可执行文件目录: ${path.dirname(Platform.resolvedExecutable)}');

    // 添加更多详细日志
    print('系统环境变量PATH: ${Platform.environment['PATH']}');

    // 尝试几种可能的路径
    final List<String> possiblePaths = [
      // 优先检查安装后的标准路径
      path.join(path.dirname(Platform.resolvedExecutable), 'tools', toolName),
      // 相对路径直接使用工具名 - 如果tools目录已添加到PATH
      toolName,
      // 应用程序目录下的工具
      path.join(path.dirname(Platform.resolvedExecutable), toolName),
      // 使用绝对路径表示
      '${path.dirname(Platform.resolvedExecutable)}\\tools\\$toolName',
      // 包含上级目录
      path.join(path.dirname(Directory.current.path), 'tools', toolName),
      // 当前目录下的tools
      path.join(Directory.current.path, 'tools', toolName),
      // 标准安装路径
      'C:\\Program Files\\牙医诊所管理系统\\tools\\$toolName',
      'C:\\Program Files (x86)\\牙医诊所管理系统\\tools\\$toolName',
      // 尝试使用环境变量中的MySQL路径
      ...Platform.environment['PATH']!
          .split(';')
          .map((p) => path.join(p, toolName)),
    ];

    print('尝试以下可能的路径:');
    for (int i = 0; i < math.min(10, possiblePaths.length); i++) {
      print('- ${possiblePaths[i]}');
    }

    // 检查每个路径
    for (final possiblePath in possiblePaths) {
      try {
        final file = File(possiblePath);
        if (file.existsSync()) {
          print('找到MySQL工具: $possiblePath');
          return possiblePath;
        }
      } catch (e) {
        print('检查路径时出错: $e');
      }
    }

    // 如果都找不到，返回默认路径
    final defaultPath = path.join(path.dirname(Platform.resolvedExecutable), 'tools', toolName);
    print('未找到MySQL工具，使用默认路径: $defaultPath');
    return defaultPath;
  }

  // 备份MySQL数据库
  Future<String> backupMySQLDatabase({String? backupPath}) async {
    print('开始MySQL备份过程...');

    // 不再检查数据源类型，直接根据备份数据源设置执行

    // 确保MySQL设置已初始化，如果未初始化，尝试从设置中获取
    Map<String, dynamic> mysqlSettings;
    if (_mysqlSettings == null) {
      print('MySQL设置未初始化，尝试使用连接参数');

      // 使用已保存的连接参数
      mysqlSettings = {
        'host': _mysqlHost,
        'port': int.tryParse(_mysqlPort) ?? 3306,
        'database': _mysqlDatabase,
        'username': _mysqlUsername,
        'password': _mysqlPassword,
      };

      // 验证参数
      if (mysqlSettings['host'] == null ||
          mysqlSettings['host'].toString().isEmpty ||
          mysqlSettings['database'] == null ||
          mysqlSettings['database'].toString().isEmpty) {
        throw Exception('MySQL连接参数不完整，请在设置中配置MySQL连接');
      }

      print(
          '使用已保存的MySQL连接参数: ${mysqlSettings.toString().replaceAll(mysqlSettings['password'], '******')}');
    } else {
      // 使用已初始化的MySQL设置
      mysqlSettings = Map<String, dynamic>.from(_mysqlSettings!);
      print(
          'MySQL设置已初始化: ${mysqlSettings.toString().replaceAll(mysqlSettings['password'], '******')}');
    }

    print('当前工作目录: ${Directory.current.path}');

    // 使用AppPaths获取mysqldump工具路径
    final toolPath = AppPaths.mysqldumpExePath;
    print('使用mysqldump工具: $toolPath');

    // 使用传入的备份路径或默认路径
    String userBackupPath = backupPath ?? '';
    if (userBackupPath.isEmpty) {
      // 如果用户没有设置备份路径，使用默认路径
      try {
        // 使用应用数据目录下的备份文件夹作为默认路径
        userBackupPath = AppPaths.defaultBackupDirectory;
        print('用户未设置备份路径，使用默认应用数据目录: $userBackupPath');
      } catch (e) {
        print('AppPaths未初始化，使用系统默认路径: $e');
        final dbDir = await getDatabasesPath();
        userBackupPath = path.join(dbDir, 'backups');
        print('使用系统默认备份路径: $userBackupPath');
      }
    } else {
      print('使用用户设置的备份路径: $userBackupPath');
    }

    print('备份目录: $userBackupPath');

    // 确保备份目录存在
    final backupDir = Directory(userBackupPath);
    if (!await backupDir.exists()) {
      print('创建备份目录: ${backupDir.path}');
      await backupDir.create(recursive: true);
    }

    // 生成备份文件名
    final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-');
    final backupFileName = 'backup_$timestamp.sql';
    final finalBackupPath = path.join(userBackupPath, backupFileName);
    print('备份文件路径: $finalBackupPath');

    // 构建命令参数列表
    final List<String> args = [
      '-h${mysqlSettings['host']}',
      '-P${mysqlSettings['port']}',
      '-u${mysqlSettings['username']}',
      '-p${mysqlSettings['password']}',
      '--default-character-set=utf8mb4',
      mysqlSettings['database'],
      '--result-file=$finalBackupPath' // 直接指定输出文件
    ];

    print(
        '执行mysqldump命令: $toolPath ${args.join(' ').replaceAll(mysqlSettings['password'], '******')}');

    try {
      // 使用Process.run执行mysqldump命令
      final result = await Process.run(
        toolPath,
        args,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );

      print('mysqldump命令执行结果: exitCode=${result.exitCode}');
      print('标准输出: ${result.stdout}');

      if (result.exitCode != 0) {
        print('备份失败，错误输出: ${result.stderr}');
        throw Exception('备份失败: ${result.stderr}');
      }

      print('MySQL备份已保存到: $finalBackupPath');
      return finalBackupPath;
    } catch (e) {
      print('执行备份命令时出错: $e');
      throw Exception('备份失败: $e');
    }
  }

  // 将MySQL结果行转换为Map
  Map<String, dynamic> _convertResultRowToMap(ResultRow row) {
    final map = <String, dynamic>{};

    for (var field in row.fields.keys) {
      var value = row[field];
      // 处理Blob类型，将其转换为字符串
      if (value is Blob) {
        // 将Blob转换为字符串
        final blobString = String.fromCharCodes(value.toBytes());
        map[field] = blobString;
      } else {
        map[field] = value;
      }
    }

    return map;
  }



  // 辅助方法：日期时间格式化
  String _formatDateTime(DateTime dateTime) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(dateTime);
  }

  // 辅助方法：获取数据库表名
  Future<List<String>> _getTableNames() async {
    if (_dataSourceType == 'sqlite') {
      final result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      return result.map((table) => table['name'] as String).toList();
    } else {
      // MySQL获取表名
      final result = await _mysqlConnection!.query('SHOW TABLES');
      // 确保不为null
      List<String> tableNames = [];
      for (var row in result) {
        if (row.fields.isNotEmpty &&
            row.values != null &&
            row.values!.isNotEmpty) {
          var value = row.values!.first;
          tableNames.add(value?.toString() ?? '');
        }
      }
      return tableNames;
    }
  }

  DateTime _parseDateTime(dynamic dateTime) {
    try {
      if (dateTime is DateTime) {
        return dateTime;
      } else if (dateTime is String) {
        try {
          return DateTimeFormatter.fromDbString(dateTime);
        } catch (e) {
          // 尝试使用不同格式解析
          try {
            return DateFormat('yyyy-MM-dd HH:mm:ss').parse(dateTime);
          } catch (e2) {
            try {
              return DateFormat('yyyy-MM-dd').parse(dateTime);
            } catch (e3) {
              print('无法解析日期字符串: $dateTime，使用当前日期');
              return DateTime.now();
            }
          }
        }
      } else if (dateTime is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateTime);
      } else {
        print('未知日期格式: $dateTime，使用当前日期');
        return DateTime.now();
      }
    } catch (e) {
      print('日期解析错误: $e，使用当前日期');
      return DateTime.now();
    }
  }

  /// 获取数据库文件路径
  String get databasePath => _databasePath ?? _sqliteDbPath ?? '';

  


}
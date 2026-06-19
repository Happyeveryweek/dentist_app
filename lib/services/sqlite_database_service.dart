import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/intl.dart';
import 'package:crypto/crypto.dart';
import '../utils/app_paths.dart';
import '../models/schemas/table_schema.dart';

/// SQLite 数据库服务
/// 职责：SQLite 连接管理、初始化、表创建
class SqliteDatabaseService {
  static const String DB_NAME = 'dentist_clinic.db';
  static const int DB_VERSION = 3;

  Database? _database;
  String? _customSqliteDbPath;

  Database? get database => _database;
  String? get customSqliteDbPath => _customSqliteDbPath;

  /// 初始化 SQLite 数据库
  Future<Database> initSQLiteDatabase() async {
    // 为 Windows 应用使用 sqflite_ffi
    sqfliteFfiInit();

    String dbPath;

    // 检查是否使用自定义路径
    if (_customSqliteDbPath != null && _customSqliteDbPath!.isNotEmpty) {
      dbPath = _customSqliteDbPath!;
      print('使用自定义 SQLite 数据库路径: $dbPath');

      // 如果指定的数据库文件不存在，创建它
      if (!await File(dbPath).exists()) {
        print('指定的 SQLite 数据库文件不存在，将创建新文件: $dbPath');
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
        print('AppPaths 未初始化，尝试文档目录: $e');
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

  /// 确保 SQLite 数据库可用（紧急情况使用）
  Future<void> ensureSQLiteDatabase() async {
    try {
      print('确保 SQLite 数据库可用...');
      
      if (_database == null) {
        _database = await initSQLiteDatabase();
        print('SQLite 数据库初始化成功');
      } else {
        // 测试现有数据库连接
        try {
          await _database!.query('SELECT 1');
          print('现有 SQLite 数据库连接正常');
        } catch (e) {
          print('现有 SQLite 数据库连接异常，重新初始化: $e');
          try {
            await _database!.close();
          } catch (_) {}
          _database = await initSQLiteDatabase();
          print('SQLite 数据库重新初始化成功');
        }
      }
      
      // 确保基本表结构存在
      await _ensureBasicTables();
      
    } catch (e) {
      print('确保 SQLite 数据库可用失败: $e');
      rethrow;
    }
  }

  /// 确保基本表结构存在
  Future<void> _ensureBasicTables() async {
    if (_database == null) return;
    
    try {
      // 检查 users 表是否存在
      final tables = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
      );
      
      if (tables.isEmpty) {
        print('users 表不存在，创建基本表结构...');
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

  /// 设置自定义 SQLite 数据库路径
  void setCustomSqliteDbPath(String? path) {
    _customSqliteDbPath = path;
  }

  /// 创建 SQLite 数据库表
  Future<void> _createDatabase(Database db, int version) async {
    print('使用新的分离式架构创建 SQLite 数据库表...');
    
    try {
      // 使用新的 Schema 架构创建所有表
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
      
      print('SQLite 数据库表创建完成');
    } catch (e) {
      print('使用新架构创建数据库表时出错: $e');
      rethrow;
    }
  }

  /// 数据库升级
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

      // 财务和材料采购表由相应的 Provider 负责创建
      if (oldVersion < 2) {
        print('财务和材料采购表由 FinancialProvider 和 MaterialProvider 负责创建...');
      }
      
      // 版本3：材料表升级由 MaterialProvider 负责
      if (oldVersion < 3) {
        print('版本3材料表升级由 MaterialProvider 负责...');
      }
    }
  }

  /// 密码哈希方法
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = md5.convert(bytes);
    return digest.toString();
  }

  /// 关闭数据库连接
  Future<void> close() async {
    if (_database != null) {
      print('关闭 SQLite 数据库连接');
      await _database!.close();
      _database = null;
      print('SQLite 数据库连接已关闭');
    }
  }
}

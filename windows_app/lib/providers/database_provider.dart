import 'dart:io';
import 'dart:async';
import 'dart:convert'; // 添加这个导入以获取jsonEncode
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

import '../models/patient.dart';
import '../models/appointment.dart';
import '../models/follow_up.dart';
import '../models/user.dart';
import '../providers/settings_provider.dart';
import '../utils/pinyin_util.dart';
import 'package:dentist_app_windows/models/backup_log.dart';

class DatabaseProvider extends ChangeNotifier {
  static const String DB_NAME = 'dentist_clinic.db';
  static const int DB_VERSION = 1;

  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;

  // MySQL连接参数
  String _mysqlHost = 'localhost';
  String _mysqlPort = '3306';
  String _mysqlDatabase = 'dentist_db';
  String _mysqlUsername = 'root';
  String _mysqlPassword = '';

  // 数据源类型
  String _dataSourceType = 'sqlite';

  // 刷新标志
  bool _patientsNeedRefresh = false;
  bool _appointmentsNeedRefresh = false;
  bool _dashboardNeedRefresh = false;
  bool _followUpsNeedRefresh = false;

  // 数据库路径
  String? _sqliteDbPath;
  String? _customSqliteDbPath;
  Map<String, dynamic>? _mysqlSettings; // MySQL连接设置
  Map<String, dynamic>? _lastMySQLSettings; // 用于临时存储MySQL设置

  // Getters
  Database? get database => _database;
  bool get initialized => _database != null || _mysqlConnection != null;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  String get dataSourceType => _dataSourceType;

  bool get patientsNeedRefresh => _patientsNeedRefresh;
  bool get appointmentsNeedRefresh => _appointmentsNeedRefresh;
  bool get dashboardNeedRefresh => _dashboardNeedRefresh;
  bool get followUpsNeedRefresh => _followUpsNeedRefresh;

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
          final dbDir = await getDatabasesPath();
          dbPath = path.join(dbDir, DB_NAME);
          print('默认路径: $dbPath');
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
        if (_mysqlConnection != null) {
          await _mysqlConnection!.close();
          _mysqlConnection = null;
        }

        // 使用提供的设置或默认值
        final host = mysqlSettings?['host'] ?? _mysqlHost;
        final port =
            int.tryParse(mysqlSettings?['port']?.toString() ?? _mysqlPort) ??
                3306;
        final database = mysqlSettings?['database'] ?? _mysqlDatabase;
        final username = mysqlSettings?['username'] ?? _mysqlUsername;
        final password = mysqlSettings?['password'] ?? _mysqlPassword;

        print('MySQL连接参数: $host:$port/$database 用户:$username');

        // 保存MySQL设置到成员变量
        _mysqlSettings = {
          'host': host,
          'port': port,
          'database': database,
          'username': username,
          'password': password,
        };

        // 同时更新单独的字段，确保一致性
        _mysqlHost = host;
        _mysqlPort = port.toString();
        _mysqlDatabase = database;
        _mysqlUsername = username;
        _mysqlPassword = password;

        print('已保存MySQL连接参数到_mysqlSettings和各个字段中');
        print('MySQL设置: $_mysqlSettings');

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
          print('MySQL数据库连接成功');

          // 验证连接是否正常
          try {
            final results = await _mysqlConnection!.query('SELECT 1');
            print('MySQL连接测试: ${results.isNotEmpty ? '成功' : '失败'}');
          } catch (e) {
            print('MySQL连接测试失败: $e');
            throw Exception('MySQL连接测试失败: $e');
          }
        } catch (e) {
          print('MySQL连接初始化失败: $e');
          throw Exception('MySQL数据库连接失败: $e');
        }
      }

      // 标记所有数据需要刷新
      _markAllDataForRefresh();
      notifyListeners();
      print('数据库初始化完成');
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

      // 确保数据库文件存在
      if (!await File(dbPath).exists()) {
        throw Exception('指定的SQLite数据库文件不存在: $dbPath');
      }
    } else {
      // 使用默认路径
      final documentsDirectory = await getApplicationDocumentsDirectory();
      dbPath = path.join(documentsDirectory.path, DB_NAME);
      print('使用默认SQLite数据库路径: $dbPath');
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

  // 初始化MySQL连接
  Future<MySqlConnection> initMySQLConnection() async {
    // 从设置中获取MySQL配置
    final settings = ConnectionSettings(
      host: _mysqlHost,
      port: int.parse(_mysqlPort),
      user: _mysqlUsername,
      password: _mysqlPassword,
      db: _mysqlDatabase,
    );

    // 建立连接
    final connection = await MySqlConnection.connect(settings);

    // 确保必要的表存在
    await _createMySQLTables(connection);

    return connection;
  }

  // 在MySQL中创建必要的表
  Future<void> _createMySQLTables(MySqlConnection connection) async {
    // 创建患者表
    await connection.query('''
    CREATE TABLE IF NOT EXISTS `patients` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `medical_record_number` int(11) DEFAULT NULL,
      `name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
      `name_pinyin` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      `age` int(11) DEFAULT NULL,
      `gender` varchar(10) COLLATE utf8mb4_unicode_ci NOT NULL,
      `phone` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      `identification_number` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      `doctor` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      `address` varchar(200) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      `address_pinyin` varchar(400) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      `first_visit_date` datetime NOT NULL,
      `dental_condition` text COLLATE utf8mb4_unicode_ci,
      `treatment_items` mediumtext COLLATE utf8mb4_unicode_ci,
      `total_cost` float DEFAULT NULL,
      `created_at` datetime NOT NULL,
      `updated_at` datetime NOT NULL,
      PRIMARY KEY (`id`) USING BTREE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
    ''');

    // 创建预约表
    await connection.query('''
    CREATE TABLE IF NOT EXISTS `appointments` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `patient_id` int(11) NOT NULL,
      `appointment_date` datetime NOT NULL,
      `status` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'scheduled',
      `treatment_type` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
      `notes` text COLLATE utf8mb4_unicode_ci,
      `cost` float DEFAULT NULL,
      `created_at` datetime NOT NULL,
      `updated_at` datetime NOT NULL,
      PRIMARY KEY (`id`) USING BTREE,
      KEY `patient_id` (`patient_id`) USING BTREE,
      CONSTRAINT `appointments_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
    ''');

    // 创建随访表
    await connection.query('''
    CREATE TABLE IF NOT EXISTS `follow_up_visits` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `patient_id` int(11) NOT NULL,
      `follow_up_date` datetime NOT NULL,
      `notes` text,
      `created_at` datetime NOT NULL,
      `updated_at` datetime NOT NULL,
      PRIMARY KEY (`id`) USING BTREE,
      KEY `patient_id` (`patient_id`) USING BTREE,
      CONSTRAINT `follow_up_visits_ibfk_1` FOREIGN KEY (`patient_id`) REFERENCES `patients` (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=latin1 ROW_FORMAT=DYNAMIC
    ''');

    // 创建用户表
    await connection.query('''
    CREATE TABLE IF NOT EXISTS `users` (
      `id` int(11) NOT NULL AUTO_INCREMENT,
      `username` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
      `email` varchar(120) COLLATE utf8mb4_unicode_ci NOT NULL,
      `password` mediumtext COLLATE utf8mb4_unicode_ci NOT NULL,
      `role` varchar(20) COLLATE utf8mb4_unicode_ci NOT NULL,
      `created_at` datetime NOT NULL,
      PRIMARY KEY (`id`) USING BTREE,
      UNIQUE KEY `username` (`username`) USING BTREE,
      UNIQUE KEY `email` (`email`) USING BTREE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci ROW_FORMAT=DYNAMIC
    ''');

    // 检查是否已存在admin用户
    final Results results = await connection.query(
        'SELECT COUNT(*) as count FROM users WHERE username = ?', ['admin']);
    final int count = results.first['count'] as int;

    if (count == 0) {
      // 添加默认admin用户
      var bytes = utf8.encode('123456');
      var digest = md5.convert(bytes);
      final hashedPassword = digest.toString();

      await connection.query(
          'INSERT INTO users (username, email, password, role, created_at) VALUES (?, ?, ?, ?, ?)',
          [
            'admin',
            'admin@example.com',
            hashedPassword,
            'admin',
            DateTime.now()
          ]);

      print('MySQL创建默认admin用户，密码：123456');
    }
  }

  // 创建SQLite数据库表
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS patients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medical_record_number INTEGER,
        name TEXT NOT NULL,
        name_pinyin TEXT,
        age INTEGER,
        gender TEXT NOT NULL,
        phone TEXT,
        identification_number TEXT,
        doctor TEXT,
        address TEXT,
        address_pinyin TEXT,
        first_visit_date TEXT NOT NULL,
        dental_condition TEXT,
        treatment_items TEXT,
        total_cost REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS appointments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        appointment_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'scheduled',
        treatment_type TEXT,
        notes TEXT,
        cost REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS follow_up_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        follow_up_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 创建索引
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_patient_id ON appointments (patient_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_appointment_date ON appointments (appointment_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_follow_up_patient_id ON follow_up_visits (patient_id)',
    );

    // 检查是否已有admin用户
    final List<Map<String, dynamic>> adminUsers = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: ['admin'],
      limit: 1,
    );

    // 如果没有admin用户，则创建一个
    if (adminUsers.isEmpty) {
      // 添加默认admin用户
      var bytes = utf8.encode('123456');
      var digest = md5.convert(bytes);
      final hashedPassword = digest.toString();

      await db.insert('users', {
        'username': 'admin',
        'email': 'admin@example.com',
        'password': hashedPassword,
        'role': 'admin',
        'created_at': DateTime.now().toIso8601String(),
      });

      print('SQLite创建默认admin用户，密码：123456');
    } else {
      print('SQLite已存在admin用户，跳过创建');
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

      // 示例：添加随访表
      if (oldVersion < 1) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS follow_ups (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            follow_up_date DATETIME NOT NULL,
            notes TEXT,
            status TEXT NOT NULL,
            created_at DATETIME,
            updated_at DATETIME,
            FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
          )
        ''');
        print('已创建随访表');
      }
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

  // 标记刷新
  void markPatientsNeedRefresh() {
    _patientsNeedRefresh = true;
    notifyListeners();
  }

  void markAppointmentsNeedRefresh() {
    _appointmentsNeedRefresh = true;
    notifyListeners();
  }

  void markDashboardNeedRefresh() {
    _dashboardNeedRefresh = true;
    notifyListeners();
  }

  void markFollowUpsNeedRefresh() {
    _followUpsNeedRefresh = true;
    notifyListeners();
  }

  // 重置刷新标志
  void resetPatientsRefreshFlag() {
    _patientsNeedRefresh = false;
  }

  void resetAppointmentsRefreshFlag() {
    _appointmentsNeedRefresh = false;
  }

  void resetDashboardRefreshFlag() {
    _dashboardNeedRefresh = false;
  }

  void resetFollowUpsRefreshFlag() {
    _followUpsNeedRefresh = false;
  }

  // 数据库备份方法
  Future<String> backupDatabase() async {
    try {
      // 创建备份目录
      final directory = await getApplicationDocumentsDirectory();
      final backupDir = Directory('${directory.path}/backups');
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 从SettingsProvider获取用户指定的备份目录
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      final userBackupPath = settingsProvider.backupPath;

      if (userBackupPath.isEmpty) {
        final errorMsg = '请设置备份路径';
        // 记录备份失败日志
        await _logBackupFailure(errorMsg);
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
          await _logBackupFailure(errorMsg);
          throw Exception(errorMsg);
        }
      }

      String backupPath;
      // 根据数据源类型选择备份方法
      if (dataSourceType == 'mysql') {
        // 使用MySQL专用的备份方法
        backupPath = await backupMySQLDatabase();
      } else {
        // 使用SQLite专用的备份方法
        backupPath = await backupSQLiteDatabase();
      }

      // 备份成功，记录备份日志
      await _logBackupSuccess(backupPath);

      // 更新上次备份日期 - 使用当天日期的零点时间，避免时间部分造成的计算误差
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      await settingsProvider.updateLastBackupDate(todayDate);
      print('已更新最后备份日期: ${todayDate.toIso8601String()}');

      return backupPath;
    } catch (e) {
      print('执行数据库备份时出错: $e');
      rethrow;
    }
  }

  // 记录备份成功日志
  Future<void> _logBackupSuccess(String backupPath) async {
    try {
      final log = BackupLog(
        backupDate: DateTime.now(),
        backupPath: backupPath,
        success: true,
      );

      await BackupLog.addLog(log);
      print('已记录备份成功日志');
    } catch (e) {
      print('记录备份成功日志出错: $e');
    }
  }

  // 记录备份失败日志
  Future<void> _logBackupFailure(String errorMessage) async {
    try {
      final log = BackupLog(
        backupDate: DateTime.now(),
        backupPath: '',
        success: false,
        errorMessage: errorMessage,
      );

      await BackupLog.addLog(log);
      print('已记录备份失败日志: $errorMessage');
    } catch (e) {
      print('记录备份失败日志出错: $e');
    }
  }

  // SQLite数据库备份方法 - 使用文件复制
  Future<String> backupSQLiteDatabase() async {
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
        final dbDir = await getDatabasesPath();
        dbPath = path.join(dbDir, DB_NAME);
      }

      // 确保数据库文件存在
      if (!await File(dbPath).exists()) {
        throw Exception('数据库文件不存在: $dbPath');
      }

      // 从SettingsProvider获取用户指定的备份目录
      final settingsProvider = SettingsProvider();
      await settingsProvider.init();
      final userBackupPath = settingsProvider.backupPath;

      if (userBackupPath.isEmpty) {
        throw Exception('未设置备份目录');
      }

      // 确保备份目录存在
      final backupDir = Directory(userBackupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 生成备份文件名
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
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
            final dbDir = await getDatabasesPath();
            dbPath = path.join(dbDir, DB_NAME);
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
                  return DateTime.parse(value);
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
                  processedRecord[key] = DateTime.parse(value);
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
  Future<bool> _checkTableExists(String tableName) async {
    try {
      final result = await _mysqlConnection!.query(
          'SELECT 1 FROM information_schema.tables WHERE table_schema = ? AND table_name = ?',
          [_mysqlDatabase, tableName]);
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
        final dbDir = await getDatabasesPath();
        dbPath = path.join(dbDir, DB_NAME);
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
  Future<void> _executeMySQLImport(String sqlContent) async {
    // 重新建立连接
    _mysqlConnection = await MySqlConnection.connect(
      ConnectionSettings(
        host: _mysqlHost,
        port: int.tryParse(_mysqlPort) ?? 3306,
        db: _mysqlDatabase,
        user: _mysqlUsername,
        password: _mysqlPassword,
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
    sqlContent = _processDentalConditionFormat(sqlContent);

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
      'appointments': [],
      'follow_up_visits': [],
    };
    List<String> otherStatements = [];

    // 表的处理顺序（从无依赖到有依赖）
    final tableOrder = [
      'users',
      'patients',
      'appointments',
      'follow_up_visits'
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
              dateTime = DateTime.parse(dateStr);
            } else if (dateStr.contains(' ')) {
              // MySQL datetime格式
              dateTime = DateTime.parse(dateStr.replaceAll(' ', 'T'));
            } else {
              // 仅日期格式
              dateTime = DateTime.parse(dateStr + 'T00:00:00');
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

  // 处理牙齿状况的数据格式
  String _processDentalConditionFormat(String sqlContent) {
    // 处理所有INSERT语句中的二进制数据，不仅仅是patients表
    final regex = RegExp(r'INSERT INTO `(\w+)`.*VALUES.*', multiLine: true);

    return sqlContent.replaceAllMapped(regex, (match) {
      String statement = match.group(0) ?? '';
      String tableName = match.group(1) ?? '';

      // 处理常见的二进制字段
      if (tableName == 'patients') {
        // 处理患者表中的特定字段
        statement = _processBinaryDentalCondition(statement);
        statement = _processTreatmentItems(statement);
        statement = _processTotalCost(statement);
      }

      // 处理所有表中的任何可能的二进制数据格式
      statement = _processAnyBinaryField(statement);

      return statement;
    });
  }

  // 处理任何表中的二进制数据字段
  String _processAnyBinaryField(String sqlStatement) {
    // 正则表达式匹配任何字段后的X'...'格式的十六进制数据
    RegExp binaryRegex = RegExp(r"', X'([0-9A-Fa-f]+)'");

    return sqlStatement.replaceAllMapped(binaryRegex, (match) {
      String fullMatch = match.group(0) ?? '';
      String hexString = match.group(1) ?? '';

      // 尝试将十六进制转换回文本
      try {
        List<int> bytes = [];
        for (int i = 0; i < hexString.length; i += 2) {
          if (i + 1 < hexString.length) {
            String hex = hexString.substring(i, i + 2);
            bytes.add(int.parse(hex, radix: 16));
          }
        }

        // 尝试解码为UTF-8文本
        String textValue = utf8.decode(bytes);
        textValue = textValue.replaceAll("'", "''");

        return "', '$textValue'";
      } catch (e) {
        print('处理通用二进制数据时出错: $e');
        return fullMatch; // 如果解码失败，保留原格式
      }
    });
  }

  // 处理二进制格式的dental_condition字段
  String _processBinaryDentalCondition(String sqlStatement) {
    // 正则表达式匹配dental_condition后面的X'...'格式的二进制数据
    RegExp binaryRegex = RegExp(r"dental_condition', X'([0-9A-Fa-f]+)'");

    return sqlStatement.replaceAllMapped(binaryRegex, (match) {
      String hexString = match.group(1) ?? '';

      try {
        // 将十六进制字符串转换为字节列表
        List<int> bytes = [];
        for (int i = 0; i < hexString.length; i += 2) {
          if (i + 1 < hexString.length) {
            String hex = hexString.substring(i, i + 2);
            bytes.add(int.parse(hex, radix: 16));
          }
        }

        // 解码为UTF-8字符串
        String jsonString = utf8.decode(bytes);

        // 对JSON字符串进行转义，以便在SQL语句中安全使用
        jsonString = jsonString.replaceAll("'", "''");

        // 返回为普通字符串形式
        return "dental_condition', '$jsonString'";
      } catch (e) {
        print('处理二进制牙齿状况数据时出错: $e');
        return match.group(0) ?? '';
      }
    });
  }

  // 处理treatment_items字段的二进制数据
  String _processTreatmentItems(String sqlStatement) {
    // 匹配treatment_items后面的X'...'格式
    RegExp binaryRegex = RegExp(r"treatment_items', X'([0-9A-Fa-f]+)'");

    return sqlStatement.replaceAllMapped(binaryRegex, (match) {
      String hexString = match.group(1) ?? '';

      try {
        // 将十六进制字符串转换为字节列表
        List<int> bytes = [];
        for (int i = 0; i < hexString.length; i += 2) {
          if (i + 1 < hexString.length) {
            String hex = hexString.substring(i, i + 2);
            bytes.add(int.parse(hex, radix: 16));
          }
        }

        // 解码为UTF-8字符串
        String textValue = utf8.decode(bytes);

        // 对字符串进行转义
        textValue = textValue.replaceAll("'", "''");

        // 返回为普通字符串形式
        return "treatment_items', '$textValue'";
      } catch (e) {
        print('处理treatment_items字段时出错: $e');
        return match.group(0) ?? '';
      }
    });
  }

  // 处理total_cost字段确保格式正确
  String _processTotalCost(String sqlStatement) {
    // 匹配total_cost后面的浮点数格式并替换为整数格式
    RegExp floatRegex = RegExp(r"total_cost', (\d+)\.0");

    return sqlStatement.replaceAllMapped(floatRegex, (match) {
      String numValue = match.group(1) ?? '0';
      return "total_cost', $numValue";
    });
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

  // 删除患者
  Future<void> deletePatient(int patientId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      try {
        // 首先删除与该患者关联的所有预约
        await _database!.delete(
          'appointments',
          where: 'patient_id = ?',
          whereArgs: [patientId],
        );

        // 然后删除患者
        await _database!.delete(
          'patients',
          where: 'id = ?',
          whereArgs: [patientId],
        );

        // 更新刷新标记
        _patientsNeedRefresh = true;
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true; // 确保仪表盘刷新
        notifyListeners(); // 通知监听者数据已更改
      } catch (e) {
        print('删除患者时出错: $e');
        throw Exception('删除患者失败: $e');
      }
    } else {
      try {
        print('开始删除MySQL患者ID: $patientId');

        // 禁用外键约束检查，以便我们可以按顺序删除
        await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 0');

        // 1. 首先删除随访记录
        print('删除与患者相关的随访记录...');
        final followUpResult = await _mysqlConnection!.query(
          'DELETE FROM follow_up_visits WHERE patient_id = ?',
          [patientId],
        );
        print('已删除${followUpResult.affectedRows}条随访记录');

        // 2. 删除预约记录
        print('删除与患者相关的预约记录...');
        final apptResult = await _mysqlConnection!.query(
          'DELETE FROM appointments WHERE patient_id = ?',
          [patientId],
        );
        print('已删除${apptResult.affectedRows}条预约记录');

        // 3. 最后删除患者记录
        print('删除患者记录...');
        final patientResult = await _mysqlConnection!.query(
          'DELETE FROM patients WHERE id = ?',
          [patientId],
        );
        print('已删除${patientResult.affectedRows}条患者记录');

        // 恢复外键约束检查
        await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 1');

        // 更新刷新标记
        _patientsNeedRefresh = true;
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true; // 确保仪表盘刷新
        notifyListeners(); // 通知监听者数据已更改

        print('患者删除完成');
      } catch (e) {
        print('MySQL删除患者时出错: $e');
        // 确保恢复外键约束检查
        try {
          await _mysqlConnection!.query('SET FOREIGN_KEY_CHECKS = 1');
        } catch (e2) {
          print('恢复外键约束检查时出错: $e2');
        }
        throw Exception('删除患者失败: $e');
      }
    }
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
      // 如果切换到SQLite，检查是否有自定义数据库路径
      if (type == 'sqlite') {
        // 从设置中获取SQLite路径
        String? sqliteDbPath = customSqlitePath;
        print('从设置中获取的SQLite路径: $sqliteDbPath');

        // 如果自定义路径为空，使用默认路径
        if (sqliteDbPath == null || sqliteDbPath.isEmpty) {
          print('使用默认SQLite路径');
          final dbPath = await getDatabasesPath();
          sqliteDbPath = path.join(dbPath, DB_NAME);
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
      await closeDatabase();

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
        print('使用自定义SQLite路径初始化数据库: $_customSqliteDbPath');
        await initDatabase(customPath: _customSqliteDbPath);
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

  // 设置MySQL连接参数
  void setMySQLConnectionParams({
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) {
    _mysqlHost = host;
    _mysqlPort = port;
    _mysqlDatabase = database;
    _mysqlUsername = username;
    _mysqlPassword = password;

    if (_dataSourceType == 'mysql' && _mysqlConnection != null) {
      closeDatabase();
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

  // =================== 患者相关方法 ===================

  // 获取所有患者
  Future<List<Patient>> getAllPatients() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 标记已刷新
    _patientsNeedRefresh = false;

    // 获取当前用户信息，用于过滤数据
    User? currentUser = _currentUser;
    bool isAdmin = currentUser?.role == 'admin';
    String? doctorName = currentUser?.doctor;

    if (_dataSourceType == 'sqlite') {
      try {
        List<Map<String, dynamic>> maps;

        // 如果用户不是管理员且有医生姓名，则只查询该医生的患者
        if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
          print('根据医生权限过滤患者: $doctorName');
          maps = await _database!.query(
            'patients',
            where: 'doctor = ?',
            whereArgs: [doctorName],
          );
        } else {
          // 管理员可查看所有患者
          maps = await _database!.query('patients');
        }

        return List.generate(maps.length, (i) {
          return Patient.fromMap(maps[i]);
        });
      } catch (e) {
        print('获取患者时出错: $e');
        return [];
      }
    } else {
      // MySQL数据获取
      try {
        print('从MySQL获取患者数据');

        Results results;

        // 如果用户不是管理员且有医生姓名，则只查询该医生的患者
        if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
          print('MySQL根据医生权限过滤患者: $doctorName');
          results = await _mysqlConnection!
              .query('SELECT * FROM patients WHERE doctor = ?', [doctorName]);
        } else {
          // 管理员可查看所有患者
          results = await _mysqlConnection!.query('SELECT * FROM patients');
        }

        List<Patient> patients = [];
        for (var row in results) {
          final Map<String, dynamic> map = {};
          for (var field in row.fields.keys) {
            var value = row[field];
            // 处理Blob类型，将其转换为字符串
            if (value is Blob) {
              final blobString = String.fromCharCodes(value.toBytes());
              map[field] = blobString;

              // 创建预览字符串用于日志
              final previewString = blobString.length > 20
                  ? '${blobString.substring(0, 20)}...'
                  : blobString;
              print('将Blob字段 $field 转换为字符串: $previewString');
            } else {
              map[field] = value;
            }
          }

          // 确保first_visit_date字段是DateTime类型
          if (map['first_visit_date'] != null &&
              map['first_visit_date'] is String) {
            try {
              map['first_visit_date'] = DateTime.parse(map['first_visit_date']);
            } catch (e) {
              print('解析first_visit_date失败: $e, 使用当前日期');
              map['first_visit_date'] = DateTime.now();
            }
          }

          patients.add(Patient.fromMap(map));
        }

        print('成功构建${patients.length}个患者对象');
        return patients;
      } catch (e) {
        print('获取所有患者时出错: $e, 堆栈: ${StackTrace.current}');
        return [];
      }
    }
  }

  // 根据ID获取患者
  Future<Patient?> getPatient(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 获取当前用户信息，用于权限验证
    User? currentUser = _currentUser;
    bool isAdmin = currentUser?.role == 'admin';
    String? doctorName = currentUser?.doctor;

    if (_dataSourceType == 'sqlite') {
      try {
        // 尝试使用Windows应用的表结构
        List<Map<String, dynamic>> maps;

        if (isAdmin) {
          // 管理员可以查看任何患者
          maps = await _database!.query(
            'patients',
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          // 医生只能查看自己的患者
          maps = await _database!.query(
            'patients',
            where: 'id = ? AND doctor = ?',
            whereArgs: [id, doctorName],
          );
        }

        if (maps.isNotEmpty) {
          return Patient.fromMap(maps.first);
        }

        // 如果没有找到，尝试使用Android应用的表结构
        List<Map<String, dynamic>> androidMaps;

        if (isAdmin) {
          androidMaps = await _database!.query(
            'Patient', // Android使用的表名
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          androidMaps = await _database!.query(
            'Patient', // Android使用的表名
            where: 'id = ? AND doctor = ?',
            whereArgs: [id, doctorName],
          );
        }

        if (androidMaps.isEmpty) {
          return null;
        }

        // 转换为Windows应用期望的结构
        final Map<String, dynamic> convertedMap =
            _convertAndroidPatientToMap(androidMaps.first);
        return Patient.fromMap(convertedMap);
      } catch (e) {
        print('获取患者时出错: $e');
        return null;
      }
    } else {
      // MySQL查询
      Results results;

      if (isAdmin) {
        // 管理员可以查看任何患者
        results = await _mysqlConnection!
            .query('SELECT * FROM patients WHERE id = ?', [id]);
      } else {
        // 医生只能查看自己的患者
        results = await _mysqlConnection!.query(
            'SELECT * FROM patients WHERE id = ? AND doctor = ?',
            [id, doctorName]);
      }

      if (results.isEmpty) {
        return null;
      }

      final row = results.first;
      final Map<String, dynamic> map = {};
      for (var field in row.fields.keys) {
        var value = row[field];
        // 处理Blob类型，将其转换为字符串
        if (value is Blob) {
          // 将Blob转换为字符串
          final blobString = String.fromCharCodes(value.toBytes());
          map[field] = blobString;
          print(
              '将Blob字段 $field 转换为字符串: ${map[field].substring(0, min(20, (map[field] as String).length))}...');
        } else {
          map[field] = value;
        }
      }

      return Patient.fromMap(map);
    }
  }

  // 将Android应用的患者数据转换为Windows应用期望的格式
  Map<String, dynamic> _convertAndroidPatientToMap(
      Map<String, dynamic> androidMap) {
    // 打印转换前的Map结构，帮助调试
    print('Android患者Map结构: $androidMap');

    // 创建一个新的Map以保存转换后的数据
    final Map<String, dynamic> windowsMap = {
      'id': androidMap['id'],
      'name': androidMap['name'] ?? '',
      'age': androidMap['age'] ?? 0,
      'gender': androidMap['gender'] ?? '',
      'phone': androidMap['phoneNumber'] ?? '', // Android中可能是phoneNumber
      'medical_record_number': androidMap['medicalRecordNumber'], // 字段名转换
      'address': androidMap['address'],
      'identification_number': androidMap['identificationNumber'], // 字段名转换
      'doctor': androidMap['doctor'],
      'dental_condition': androidMap['dentalCondition'], // 字段名转换
      'treatment_items': androidMap['treatmentItems'], // 字段名转换
      'total_cost': androidMap['totalCost']?.toDouble() ?? 0.0, // 字段名转换
    };

    // 处理日期字段
    if (androidMap['registrationDate'] != null) {
      windowsMap['first_visit_date'] =
          androidMap['registrationDate']; // 注意Android使用registrationDate
    } else if (androidMap['firstVisitDate'] != null) {
      windowsMap['first_visit_date'] =
          androidMap['firstVisitDate']; // 有些Android应用可能使用firstVisitDate
    } else {
      windowsMap['first_visit_date'] = DateTime.now().toIso8601String();
    }

    return windowsMap;
  }

  // 搜索患者 - 包含姓名、电话、备注等信息的模糊搜索
  Future<List<Patient>> searchPatients(
    String query, {
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
    Map<String, String>? advancedCriteria,
  }) async {
    try {
      final db = await database;
      // 检查数据库连接状态
      if (db == null) {
        return [];
      }

      List<Patient> patients = [];

      // 是否是高级搜索
      bool isAdvancedSearch =
          advancedCriteria != null && advancedCriteria.isNotEmpty;

      if (isAdvancedSearch) {
        // 处理多条件高级搜索
        String nameQuery = advancedCriteria['name'] ?? '';
        String addressQuery = advancedCriteria['address'] ?? '';
        String phoneQuery = advancedCriteria['phone'] ?? '';
        String doctorQuery = advancedCriteria['doctor'] ?? '';
        String medicalRecordQuery = advancedCriteria['medical_record'] ?? '';

        // 生成带空格和不带空格的搜索词，以提高拼音搜索的准确性
        String nameQueryNoSpace = nameQuery.replaceAll(' ', '');
        String addressQueryNoSpace = addressQuery.replaceAll(' ', '');

        // 构建SQL查询
        String sql = '''
          SELECT * FROM patients WHERE 1=1
        ''';

        List<dynamic> arguments = [];

        // 添加名称搜索条件 - 支持姓名、姓名拼音和姓名首字母搜索
        if (nameQuery.isNotEmpty) {
          sql += '''
            AND (
              name LIKE ? OR 
              name_pinyin LIKE ? OR 
              REPLACE(name_pinyin, ' ', '') LIKE ? OR
              name_initials LIKE ?
            )
          ''';
          arguments.add('%$nameQuery%'); // 原始姓名查询
          arguments.add('%$nameQuery%'); // 拼音带空格匹配
          arguments.add('%$nameQueryNoSpace%'); // 数据库中删除空格后匹配无空格输入
          arguments.add('%$nameQuery%'); // 首字母匹配
        }

        // 添加地址搜索条件 - 支持地址和地址拼音搜索
        if (addressQuery.isNotEmpty) {
          sql += '''
            AND (
              address LIKE ? OR 
              address_pinyin LIKE ? OR
              REPLACE(address_pinyin, ' ', '') LIKE ?
            )
          ''';
          arguments.add('%$addressQuery%'); // 原始地址查询
          arguments.add('%$addressQuery%'); // 拼音带空格匹配
          arguments.add('%$addressQueryNoSpace%'); // 数据库中删除空格后匹配无空格输入
        }

        // 添加电话搜索条件
        if (phoneQuery.isNotEmpty) {
          sql += ' AND phone LIKE ?';
          arguments.add('%$phoneQuery%');
        }

        // 添加医生搜索条件
        if (doctorQuery.isNotEmpty) {
          sql += ' AND doctor LIKE ?';
          arguments.add('%$doctorQuery%');
        }

        // 添加病历号搜索条件
        if (medicalRecordQuery.isNotEmpty) {
          sql += ' AND medical_record_number LIKE ?';
          arguments.add('%$medicalRecordQuery%');
        }

        // 添加日期过滤
        if (startDate != null) {
          sql += ' AND $dateFilterType >= ?';
          arguments.add(startDate.toIso8601String());
        }
        if (endDate != null) {
          sql += ' AND $dateFilterType <= ?';
          arguments.add(endDate.toIso8601String());
        }

        // 添加排序
        sql +=
            ' ORDER BY ${sortField ?? 'updated_at'} ${sortAscending ? 'ASC' : 'DESC'}, id DESC';

        final List<Map<String, dynamic>> results =
            await db.rawQuery(sql, arguments);
        patients = results.map((data) => Patient.fromMap(data)).toList();
      } else {
        // 使用传统的模糊搜索
        // 处理查询字符串，生成无空格版本用于拼音搜索
        String queryNoSpace = query.replaceAll(' ', '');

        // 更改查询方式，确保拼音和首字母搜索能正常工作
        final List<Map<String, dynamic>> results = await db.rawQuery(
          '''
          SELECT * FROM patients 
          WHERE medical_record_number LIKE ? 
          OR name LIKE ? 
          OR (name_pinyin IS NOT NULL AND name_pinyin LIKE ?)
          OR (name_pinyin IS NOT NULL AND REPLACE(name_pinyin, ' ', '') LIKE ?)
          OR (name_initials IS NOT NULL AND name_initials LIKE ?)
          OR phone LIKE ? 
          OR address LIKE ?
          OR (address_pinyin IS NOT NULL AND address_pinyin LIKE ?)
          OR (address_pinyin IS NOT NULL AND REPLACE(address_pinyin, ' ', '') LIKE ?)
          ${startDate != null ? 'AND $dateFilterType >= ?' : ''}
          ${endDate != null ? 'AND $dateFilterType <= ?' : ''}
          ORDER BY ${sortField ?? 'updated_at'} ${sortAscending ? 'ASC' : 'DESC'}, id DESC
          ''',
          [
            '%$query%', // 病历号
            '%$query%', // 姓名
            '%$query%', // 姓名拼音带空格
            '%$queryNoSpace%', // 删除数据库中拼音空格后匹配无空格输入
            '%$query%', // 姓名首字母
            '%$query%', // 电话
            '%$query%', // 地址
            '%$query%', // 地址拼音带空格
            '%$queryNoSpace%', // 删除数据库中拼音空格后匹配无空格输入
            if (startDate != null) startDate.toIso8601String(),
            if (endDate != null) endDate.toIso8601String(),
          ],
        );
        patients = results.map((data) => Patient.fromMap(data)).toList();
      }

      // 返回搜索结果
      return patients;
    } catch (e) {
      print('搜索患者时出错: $e');
      return [];
    }
  }

  // 获取患者分页数据
  Future<Map<String, dynamic>> getPatientsPage({
    required int page,
    required int pageSize,
    String? searchQuery,
    String? sortField,
    bool sortAscending = false,
    DateTime? startDate,
    DateTime? endDate,
    String dateFilterType = 'first_visit_date',
  }) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 获取当前用户信息，用于过滤数据
    User? currentUser = _currentUser;
    bool isAdmin = currentUser?.role == 'admin';
    String? doctorName = currentUser?.doctor;

    print(
        '获取患者分页数据: 页码=$page, 每页数量=$pageSize, 排序字段=$sortField, 升序=$sortAscending');

    final offset = (page - 1) * pageSize;
    List<Patient> patients = [];
    int totalCount = 0;

    if (_dataSourceType == 'sqlite') {
      try {
        // 获取所有表名
        final tables = await _getTableNames();

        // 尝试不同可能的表名
        final possiblePatientTables = [
          'Patient',
          'patient',
          'patients',
          'Patients'
        ];
        String? actualTableName;

        for (var tableName in possiblePatientTables) {
          if (tables.contains(tableName)) {
            actualTableName = tableName;
            break;
          }
        }

        if (actualTableName == null) {
          print('未找到患者表');
          return {
            'patients': [],
            'totalCount': 0,
            'totalPages': 0,
            'currentPage': page,
          };
        }

        print('使用表 $actualTableName 获取患者数据');

        // 处理搜索和排序
        String whereClause = '';
        List<dynamic> whereArgs = [];

        if (searchQuery != null && searchQuery.isNotEmpty) {
          // 根据表名调整字段名
          if (actualTableName.toLowerCase() == 'patients' ||
              actualTableName.toLowerCase() == 'patient') {
            // 为拼音搜索创建无空格版本
            String queryNoSpace = searchQuery.replaceAll(' ', '');

            whereClause = '''
            name LIKE ? 
            OR phone LIKE ? 
            OR address LIKE ? 
            OR identification_number LIKE ? 
            OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?))
            OR (name_initials IS NOT NULL AND name_initials LIKE ?)
            OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
            ''';

            whereArgs = [
              '%$searchQuery%', // 姓名
              '%$searchQuery%', // 电话
              '%$searchQuery%', // 地址
              '%$searchQuery%', // 身份证号
              '%$searchQuery%', // 姓名拼音带空格
              '%$queryNoSpace%', // 姓名拼音无空格
              '%$searchQuery%', // 姓名首字母
              '%$searchQuery%', // 地址拼音带空格
              '%$queryNoSpace%', // 地址拼音无空格
            ];
          } else {
            whereClause =
                'name LIKE ? OR phoneNumber LIKE ? OR address LIKE ? OR identificationNumber LIKE ?';
            whereArgs = [
              '%$searchQuery%',
              '%$searchQuery%',
              '%$searchQuery%',
              '%$searchQuery%'
            ];
          }
        }

        // 添加日期过滤条件
        if (startDate != null && endDate != null) {
          String startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
          String endDateStr = DateFormat('yyyy-MM-dd')
              .format(endDate.add(const Duration(days: 1)));

          // 根据筛选类型和表名选择日期字段
          String dateField;
          if (dateFilterType == 'first_visit_date') {
            dateField = actualTableName.toLowerCase() == 'patients'
                ? 'first_visit_date'
                : 'firstVisitDate';
          } else if (dateFilterType == 'updated_at') {
            dateField = 'updated_at';
          } else {
            dateField = 'updated_at'; // 默认使用updated_at
          }

          if (whereClause.isNotEmpty) {
            whereClause += ' AND ';
          }

          whereClause += '$dateField BETWEEN ? AND ?';
          whereArgs.add(startDateStr);
          whereArgs.add(endDateStr);
        }

        // 添加医生权限过滤
        if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
          if (whereClause.isNotEmpty) {
            whereClause += ' AND ';
          }
          whereClause += 'doctor = ?';
          whereArgs.add(doctorName);
        }

        // 获取总数
        final countResult = await _database!.rawQuery(
          'SELECT COUNT(*) as count FROM $actualTableName${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
          whereArgs,
        );
        totalCount = countResult.first['count'] as int;

        // 处理排序
        String orderBy = 'updated_at DESC'; // 默认排序

        if (sortField != null && sortField.isNotEmpty) {
          // 根据表名和字段名调整排序字段
          String fieldName = sortField;

          switch (sortField) {
            case 'updated_at':
              fieldName = 'updated_at'; // 直接使用updated_at字段
              break;
            case 'first_visit_date':
              fieldName = actualTableName.toLowerCase() == 'patients'
                  ? 'first_visit_date'
                  : 'firstVisitDate';
              break;
            case 'name':
              fieldName = 'name'; // 名称字段在不同表中通常是一致的
              break;
            case 'age':
              fieldName = 'age';
              break;
            case 'medical_record_number':
              // 确保以数字形式排序病历号
              fieldName = 'CAST(medical_record_number AS INTEGER)';
              break;
          }

          orderBy = '$fieldName ${sortAscending ? 'ASC' : 'DESC'}';
        }

        print('最终查询排序条件: $orderBy');

        // 执行查询
        final List<Map<String, dynamic>> maps = await _database!.rawQuery(
          'SELECT * FROM $actualTableName${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''} ORDER BY $orderBy LIMIT $pageSize OFFSET $offset',
          whereArgs,
        );

        print('查询返回 ${maps.length} 条记录');

        // 转换为Patient对象
        patients = maps.map((map) => Patient.fromMap(map)).toList();

        // 输出患者排序信息
        if (patients.isNotEmpty) {
          print(
              '第一个患者: id=${patients[0].id}, name=${patients[0].name}, updated_at=${patients[0].updated_at}');
          if (patients.length > 1) {
            print(
                '第二个患者: id=${patients[1].id}, name=${patients[1].name}, updated_at=${patients[1].updated_at}');
          }
        }
      } catch (e) {
        print('获取患者分页数据时出错: $e');
        rethrow;
      }
    } else if (_dataSourceType == 'mysql') {
      // MySQL查询
      try {
        print('从MySQL获取患者数据');
        // 处理搜索和排序
        String whereClause = '';
        List<dynamic> whereArgs = [];

        if (searchQuery != null && searchQuery.isNotEmpty) {
          // 为拼音搜索创建无空格版本
          String queryNoSpace = searchQuery.replaceAll(' ', '');

          whereClause = '''
          name LIKE ? 
          OR phone LIKE ? 
          OR address LIKE ? 
          OR identification_number LIKE ? 
          OR (name_pinyin IS NOT NULL AND (name_pinyin LIKE ? OR REPLACE(name_pinyin, ' ', '') LIKE ?))
          OR (name_initials IS NOT NULL AND name_initials LIKE ?)
          OR (address_pinyin IS NOT NULL AND (address_pinyin LIKE ? OR REPLACE(address_pinyin, ' ', '') LIKE ?))
          ''';

          whereArgs = [
            '%$searchQuery%', // 姓名
            '%$searchQuery%', // 电话
            '%$searchQuery%', // 地址
            '%$searchQuery%', // 身份证号
            '%$searchQuery%', // 姓名拼音带空格
            '%$queryNoSpace%', // 姓名拼音无空格
            '%$searchQuery%', // 姓名首字母
            '%$searchQuery%', // 地址拼音带空格
            '%$queryNoSpace%', // 地址拼音无空格
          ];
        }

        // 添加日期过滤条件
        if (startDate != null && endDate != null) {
          String startDateStr = DateFormat('yyyy-MM-dd').format(startDate);
          String endDateStr = DateFormat('yyyy-MM-dd')
              .format(endDate.add(const Duration(days: 1)));

          if (whereClause.isNotEmpty) {
            whereClause += ' AND ';
          }

          whereClause += '$dateFilterType BETWEEN ? AND ?';
          whereArgs.add(startDateStr);
          whereArgs.add(endDateStr);
        }

        // 添加医生权限过滤
        if (!isAdmin && doctorName != null && doctorName.isNotEmpty) {
          if (whereClause.isNotEmpty) {
            whereClause += ' AND ';
          }
          whereClause += 'doctor = ?';
          whereArgs.add(doctorName);
        }

        // 获取总数
        final countResults = await _mysqlConnection!.query(
          'SELECT COUNT(*) as count FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
          whereArgs,
        );
        totalCount = countResults.first['count'] as int;

        // 处理排序
        String orderBy = 'updated_at DESC'; // 默认排序

        if (sortField != null && sortField.isNotEmpty) {
          // 确保在MySQL中使用下划线形式的列名
          String mysqlSortField = sortField;
          if (sortField == 'medicalRecordNumber') {
            mysqlSortField = 'medical_record_number';
          } else if (sortField == 'firstVisitDate') {
            mysqlSortField = 'first_visit_date';
          }

          // 对病历号进行数值排序
          if (mysqlSortField == 'medical_record_number') {
            mysqlSortField = 'CAST(medical_record_number AS SIGNED)';
          }

          orderBy = '$mysqlSortField ${sortAscending ? 'ASC' : 'DESC'}';
        }

        print('MySQL查询排序条件: $orderBy');

        // 执行分页查询
        final results = await _mysqlConnection!.query(
          'SELECT * FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''} ORDER BY $orderBy LIMIT ? OFFSET ?',
          [...whereArgs, pageSize, offset],
        );

        print('MySQL查询返回 ${results.length} 条记录');

        // 转换为Patient对象
        for (var row in results) {
          final map = <String, dynamic>{};
          for (var field in row.fields.keys) {
            var value = row[field];
            if (value is Blob) {
              // 将Blob转换为字符串
              map[field] = String.fromCharCodes(value.toBytes());
            } else {
              map[field] = value;
            }
          }
          patients.add(Patient.fromMap(map));
        }

        // 输出患者排序信息
        if (patients.isNotEmpty) {
          print(
              'MySQL第一个患者: id=${patients[0].id}, name=${patients[0].name}, updated_at=${patients[0].updated_at}');
          if (patients.length > 1) {
            print(
                'MySQL第二个患者: id=${patients[1].id}, name=${patients[1].name}, updated_at=${patients[1].updated_at}');
          }
        }
      } catch (e) {
        print('获取MySQL患者分页数据时出错: $e');
        rethrow;
      }
    }

    // 返回数据
    return {
      'patients': patients,
      'totalCount': totalCount,
      'totalPages': (totalCount / pageSize).ceil(),
      'currentPage': page,
    };
  }

  // 获取患者的预约
  Future<List<Appointment>> getAppointmentsByPatient(int patientId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      try {
        // 获取所有表名
        final tables = await _getTableNames();
        if (!tables.contains('appointments')) {
          print('未找到预约表appointments');
          return [];
        }

        // 使用正确的表名和字段名
        final List<Map<String, dynamic>> maps = await _database!.query(
          'appointments',
          where: 'patient_id = ?',
          whereArgs: [patientId],
          orderBy: 'appointment_date DESC',
        );

        // 获取预约关联的患者信息
        List<Appointment> appointments = [];
        for (var map in maps) {
          final appointment = Appointment.fromMap(map);

          // 尝试获取关联的患者信息
          try {
            final patient = await getPatient(patientId);
            if (patient != null) {
              appointments.add(appointment.copyWith(patient: patient));
            } else {
              appointments.add(appointment);
            }
          } catch (e) {
            print('获取预约关联的患者时出错: $e');
            appointments.add(appointment);
          }
        }

        return appointments;
      } catch (e) {
        print('获取患者预约时出错: $e');
        return [];
      }
    } else {
      // MySQL查询患者预约
      final results = await _mysqlConnection!.query(
          'SELECT * FROM appointments WHERE patient_id = ?', [patientId]);

      return results.map((row) {
        final Map<String, dynamic> map = {};
        for (var field in row.fields.keys) {
          map[field] = row[field];
        }
        return Appointment.fromMap(map);
      }).toList();
    }
  }

  // 根据日期获取预约
  Future<List<Appointment>> getAppointmentsByDate(DateTime date) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      final DateTime startOfDay = DateTime(date.year, date.month, date.day);
      final DateTime endOfDay =
          DateTime(date.year, date.month, date.day, 23, 59, 59);

      // 格式化日期为字符串
      final String formattedStartDate = _formatDateTime(startOfDay);
      final String formattedEndDate = _formatDateTime(endOfDay);

      // 用于MySQL的日期格式
      final String mysqlFormattedDate = DateFormat('yyyy-MM-dd').format(date);

      List<Appointment> appointments = [];

      if (_dataSourceType == 'sqlite') {
        // SQLite版本 - 使用字符串比较
        final db = await database;
        final result = await db!.rawQuery('''
          SELECT a.*, p.name, p.gender, p.phone
          FROM appointments a
          LEFT JOIN patients p ON a.patient_id = p.id
          WHERE a.appointment_date BETWEEN ? AND ?
          ORDER BY a.appointment_date
        ''', [formattedStartDate, formattedEndDate]);

        appointments = result.map((e) => Appointment.fromMap(e)).toList();
      } else if (_dataSourceType == 'mysql') {
        try {
          final conn = await mysqlConnection;

          // MySQL版本 - 使用DATE()函数提取日期部分
          final results = await conn!.query('''
            SELECT a.*
            FROM appointments a
            WHERE DATE(a.appointment_date) = ?
            ORDER BY a.appointment_date
          ''', [mysqlFormattedDate]);

          print('MySQL日期查询结果: ${results.length} 条记录, 日期: $mysqlFormattedDate');

          // 专门为MySQL处理结果
          for (var row in results) {
            try {
              // 创建一个映射以使用Appointment.fromMap构造函数
              final map = <String, dynamic>{};

              // 从MySQL行中提取字段值
              for (var field in row.fields.keys) {
                var value = row[field];

                // 处理BLOB字段
                if (value is Blob) {
                  final blobString = String.fromCharCodes(value.toBytes());
                  print(
                      '将Blob字段 $field 转换为字符串: ${blobString.substring(0, math.min(30, blobString.length))}...');
                  map[field] = blobString;
                } else {
                  // 其他字段直接放入map
                  map[field] = value;
                }
              }

              // 创建预约对象
              final appointment = Appointment.fromMap(map);

              // 如果有患者ID，尝试获取患者信息
              if (appointment.patient_id != null) {
                try {
                  final patient = await getPatient(appointment.patient_id!);
                  if (patient != null) {
                    appointment.patient = patient;
                  }
                } catch (e) {
                  print('获取预约关联的患者信息出错: $e');
                }
              }

              appointments.add(appointment);
            } catch (e) {
              print('处理MySQL预约数据时出错: $e');
            }
          }
        } catch (e) {
          print('MySQL查询今日预约出错: $e');
          rethrow;
        }
      }

      // 添加患者信息到每个预约
      for (var appointment in appointments) {
        if (appointment.patient_id != null && appointment.patient == null) {
          try {
            final patient = await getPatient(appointment.patient_id!);
            if (patient != null) {
              appointment.patient = patient;
            }
          } catch (e) {
            print('获取预约患者信息出错: $e');
          }
        }
      }

      return appointments;
    } catch (e) {
      print('获取预约出错: $e');
      rethrow;
    }
  }

  // 处理MySQL查询结果的辅助方法
  Future<List<Appointment>> _processAppointmentResults(dynamic results) async {
    List<Appointment> appointments = [];
    for (var row in results) {
      final Map<String, dynamic> map = {};
      for (var field in row.fields.keys) {
        map[field] = row[field];
      }

      final appointment = Appointment.fromMap(map);
      print(
          '处理预约ID: ${appointment.id}, 日期: ${appointment.appointment_date}, 患者ID: ${appointment.patient_id}');

      // 尝试获取关联的患者信息
      if (appointment.patient_id != null) {
        try {
          final patient = await getPatient(appointment.patient_id!);
          if (patient != null) {
            appointments.add(appointment.copyWith(patient: patient));
            print('成功关联患者: ${patient.name}');
          } else {
            appointments.add(appointment);
            print('未找到对应患者');
          }
        } catch (e) {
          print('获取预约关联的患者时出错: $e');
          appointments.add(appointment);
        }
      } else {
        appointments.add(appointment);
        print('预约没有患者ID');
      }
    }

    print('最终返回 ${appointments.length} 条预约');
    return appointments;
  }

  // 获取所有预约
  Future<List<Appointment>> getAllAppointments() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      try {
        // 获取所有表名
        final tables = await _getTableNames();
        if (!tables.contains('appointments')) {
          print('未找到预约表appointments');
          return [];
        }

        // 使用正确的表名
        final List<Map<String, dynamic>> maps =
            await _database!.query('appointments');

        // 获取预约关联的患者信息
        List<Appointment> appointments = [];
        for (var map in maps) {
          final appointment = Appointment.fromMap(map);

          // 尝试获取关联的患者信息
          if (appointment.patient_id != null) {
            try {
              final patient = await getPatient(appointment.patient_id!);
              if (patient != null) {
                appointments.add(appointment.copyWith(patient: patient));
              } else {
                appointments.add(appointment);
              }
            } catch (e) {
              print('获取预约关联的患者时出错: $e');
              appointments.add(appointment);
            }
          } else {
            appointments.add(appointment);
          }
        }

        return appointments;
      } catch (e) {
        print('获取所有预约时出错: $e');
        return [];
      }
    } else {
      // MySQL获取所有预约
      try {
        final results = await _mysqlConnection!.query('''
          SELECT a.*
          FROM appointments a
          ORDER BY a.appointment_date DESC
        ''');

        List<Appointment> appointments = [];

        // 专门为MySQL处理结果
        for (var row in results) {
          try {
            // 创建一个映射以使用Appointment.fromMap构造函数
            final map = <String, dynamic>{};

            // 从MySQL行中提取字段值
            for (var field in row.fields.keys) {
              var value = row[field];

              // 处理BLOB字段
              if (value is Blob) {
                final blobString = String.fromCharCodes(value.toBytes());
                print(
                    '将Blob字段 $field 转换为字符串: ${blobString.substring(0, math.min(30, blobString.length))}...');
                map[field] = blobString;
              } else {
                // 其他字段直接放入map
                map[field] = value;
              }
            }

            // 创建预约对象
            final appointment = Appointment.fromMap(map);

            // 如果有患者ID，尝试获取患者信息
            if (appointment.patient_id != null) {
              try {
                final patient = await getPatient(appointment.patient_id!);
                if (patient != null) {
                  appointment.patient = patient;
                }
              } catch (e) {
                print('获取预约关联的患者信息出错: $e');
              }
            }

            appointments.add(appointment);
          } catch (e) {
            print('处理MySQL预约数据时出错: $e');
          }
        }

        return appointments;
      } catch (e) {
        print('MySQL获取所有预约时出错: $e');
        return [];
      }
    }
  }

  // 将Android应用的预约数据转换为Windows应用期望的格式
  Map<String, dynamic> _convertAndroidAppointmentToMap(
      Map<String, dynamic> androidMap) {
    // 打印转换前的Map结构，帮助调试
    print('Android预约Map结构: $androidMap');

    // 创建一个新的Map以保存转换后的数据
    final Map<String, dynamic> windowsMap = {
      'id': androidMap['id'],
      'patient_id':
          androidMap['patientId'] ?? androidMap['patient_id'], // 适配不同表结构
      'treatment_type':
          androidMap['treatmentType'] ?? androidMap['appointmentType'] ?? '',
      'status': androidMap['status'] ?? '已预约',
      'notes': androidMap['description'] ?? androidMap['notes'],
      'cost': androidMap['cost']?.toDouble() ?? 0.0,
    };

    // 处理日期字段
    if (androidMap['appointmentDate'] != null) {
      windowsMap['appointment_date'] = androidMap['appointmentDate'];
    } else if (androidMap['appointment_date'] != null) {
      windowsMap['appointment_date'] = androidMap['appointment_date'];
    } else {
      windowsMap['appointment_date'] = DateTime.now().toIso8601String();
    }

    return windowsMap;
  }

  // =================== 随访相关方法 ===================

  // 获取患者的随访记录
  Future<List<dynamic>> getPatientFollowUps(int patientId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'follow_ups',
        where: 'patient_id = ?',
        whereArgs: [patientId],
        orderBy: 'follow_up_date DESC',
      );

      return maps;
    } else {
      // MySQL查询 - 简化返回空列表
      return [];
    }
  }

  // 添加随访记录
  Future<int> addFollowUp(dynamic followUp) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      final id = await _database!.insert(
        'follow_ups',
        followUp.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return id;
    } else {
      // MySQL添加 - 简化版本
      return 0;
    }
  }

  // 更新随访记录
  Future<int> updateFollowUp(dynamic followUp) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      final result = await _database!.update(
        'follow_ups',
        followUp.toMap(),
        where: 'id = ?',
        whereArgs: [followUp.id],
      );

      return result;
    } else {
      // MySQL更新 - 简化版本
      return 0;
    }
  }

  // 删除随访记录
  Future<int> deleteFollowUp(int id) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      final result = await _database!.delete(
        'follow_ups',
        where: 'id = ?',
        whereArgs: [id],
      );

      return result;
    } else {
      // MySQL删除
      final result = await _mysqlConnection!
          .query('DELETE FROM follow_ups WHERE id = ?', [id]);

      return result.affectedRows ?? 0;
    }
  }

  // 数据同步功能 - 为了与安卓端保持一致
  Future<String> exportDatabase() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 导出数据库实现...
    throw UnimplementedError('数据导出功能尚未实现');
  }

  Future<void> importDatabase(String importFilePath) async {
    try {
      // 关闭当前数据库连接
      await closeDatabase();

      // 获取应用数据库文件路径
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final dbPath = path.join(documentsDirectory.path, DB_NAME);

      // 检查导入文件是否存在
      final importFile = File(importFilePath);
      if (!await importFile.exists()) {
        throw Exception('导入文件不存在');
      }

      // 删除当前数据库文件
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // 复制导入文件到数据库位置
      await importFile.copy(dbPath);

      // 重新初始化数据库连接
      await initDatabase();

      // 标记所有页面需要刷新
      markPatientsNeedRefresh();
      markAppointmentsNeedRefresh();
      markDashboardNeedRefresh();
      markFollowUpsNeedRefresh();

      print('数据库已从导入文件恢复: $importFilePath');
    } catch (e) {
      print('导入数据库错误: $e');
      rethrow;
    }
  }

  // 自动备份功能
  Future<void> performAutoBackup(String backupDir) async {
    try {
      final backupPath = await backupDatabase();
      print('自动备份已完成: $backupPath');

      // 删除旧备份 (保留最近10个备份)
      await _cleanupOldBackups(backupDir, 10);
    } catch (e) {
      print('自动备份失败: $e');
      rethrow;
    }
  }

  // 清理旧备份文件
  Future<void> _cleanupOldBackups(String backupDir, int keepCount) async {
    try {
      final directory = Directory(backupDir);
      if (!await directory.exists()) return;

      // 获取所有备份文件
      final files = await directory
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.db'))
          .toList();

      // 按修改时间排序
      files.sort((a, b) {
        return File(
          b.path,
        ).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });

      // 删除旧文件
      if (files.length > keepCount) {
        for (int i = keepCount; i < files.length; i++) {
          await File(files[i].path).delete();
          print('删除旧备份文件: ${files[i].path}');
        }
      }
    } catch (e) {
      print('清理旧备份失败: $e');
    }
  }

  // 添加患者
  Future<int> addPatient(Patient patient) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 明确设置创建时间和更新时间
    final Map<String, dynamic> patientMap = patient.toMap();
    final now = DateTime.now();
    final nowStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    patientMap['created_at'] = nowStr;
    patientMap['updated_at'] = nowStr;

    // 自动生成拼音字段 - 无论之前是否有值
    patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
    patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);
    print('生成姓名拼音: ${patientMap['name_pinyin']}');
    print('生成姓名首字母: ${patientMap['name_initials']}');

    if (patient.address != null) {
      patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
      print('生成地址拼音: ${patientMap['address_pinyin']}');
    }

    print('添加患者: ${patient.name}, 设置更新时间为: $nowStr');

    if (dataSourceType == 'sqlite') {
      try {
        final id = await _database!.insert('patients', patientMap);

        // 标记患者数据需要刷新
        _patientsNeedRefresh = true;
        notifyListeners();

        return id;
      } catch (e) {
        print('添加患者时出错: $e');
        rethrow;
      }
    } else {
      try {
        final result = await _mysqlConnection!.query(
          'INSERT INTO patients (name, name_pinyin, age, gender, phone, medical_record_number, address, address_pinyin, identification_number, doctor, dental_condition, treatment_items, first_visit_date, total_cost, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            patientMap['name'],
            patientMap['name_pinyin'],
            patientMap['age'],
            patientMap['gender'],
            patientMap['phone'],
            patientMap['medical_record_number'],
            patientMap['address'],
            patientMap['address_pinyin'],
            patientMap['identification_number'],
            patientMap['doctor'],
            patientMap['dental_condition'],
            patientMap['treatment_items'],
            patientMap['first_visit_date'],
            patientMap['total_cost'],
            patientMap['created_at'],
            patientMap['updated_at'],
          ],
        );

        // 标记患者数据需要刷新
        _patientsNeedRefresh = true;
        notifyListeners();

        return result.insertId ?? 0;
      } catch (e) {
        print('添加患者(MySQL)时出错: $e');
        rethrow;
      }
    }
  }

  // 更新患者
  Future<int> updatePatient(Patient patient) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (patient.id == null) {
      throw Exception('更新患者时必须提供ID');
    }

    // 明确设置更新时间为当前时间
    final Map<String, dynamic> patientMap = patient.toMap();
    final now = DateTime.now();
    patientMap['updated_at'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    // 自动更新拼音字段 - 无论拼音字段是否为空，只要有姓名和地址信息就更新
    patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
    patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);
    print('更新姓名拼音: ${patientMap['name_pinyin']}');
    print('更新姓名首字母: ${patientMap['name_initials']}');

    if (patient.address != null) {
      patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
      print('更新地址拼音: ${patientMap['address_pinyin']}');
    }

    print('更新患者ID: ${patient.id}, 设置更新时间为: ${patientMap['updated_at']}');

    if (dataSourceType == 'sqlite') {
      try {
        final result = await _database!.update(
          'patients',
          patientMap,
          where: 'id = ?',
          whereArgs: [patient.id],
        );

        // 标记患者数据需要刷新
        _patientsNeedRefresh = true;
        notifyListeners();

        return result;
      } catch (e) {
        print('更新患者数据时出错: $e');
        rethrow;
      }
    } else {
      try {
        final result = await _mysqlConnection!.query(
          'UPDATE patients SET name = ?, name_pinyin = ?, age = ?, gender = ?, phone = ?, medical_record_number = ?, address = ?, address_pinyin = ?, identification_number = ?, doctor = ?, dental_condition = ?, treatment_items = ?, first_visit_date = ?, total_cost = ?, updated_at = ? WHERE id = ?',
          [
            patientMap['name'],
            patientMap['name_pinyin'],
            patientMap['age'],
            patientMap['gender'],
            patientMap['phone'],
            patientMap['medical_record_number'],
            patientMap['address'],
            patientMap['address_pinyin'],
            patientMap['identification_number'],
            patientMap['doctor'],
            patientMap['dental_condition'],
            patientMap['treatment_items'],
            patientMap['first_visit_date'],
            patientMap['total_cost'],
            patientMap['updated_at'],
            patient.id,
          ],
        );

        // 标记患者数据需要刷新
        _patientsNeedRefresh = true;
        notifyListeners();

        return result.affectedRows ?? 0;
      } catch (e) {
        print('更新患者数据(MySQL)时出错: $e');
        rethrow;
      }
    }
  }

  // 添加预约
  Future<int> addAppointment(Appointment appointment) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      try {
        // 转换Appointment对象为符合数据库结构的Map
        Map<String, dynamic> appointmentMap = {
          'patient_id': appointment.patient_id,
          'appointment_date': _formatDateTime(appointment.appointment_date),
          'status': appointment.status,
          'treatment_type': appointment.treatment_type,
          'notes': appointment.notes,
          'cost': appointment.cost,
          'created_at': _formatDateTime(DateTime.now()),
          'updated_at': _formatDateTime(DateTime.now()),
        };

        // 插入数据
        int id = await _database!.insert('appointments', appointmentMap);

        // 标记预约数据需要刷新
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true;
        notifyListeners(); // 通知监听者数据已更改

        return id;
      } catch (e) {
        print('添加预约时出错: $e');
        throw Exception('添加预约失败: $e');
      }
    } else {
      // MySQL添加预约
      try {
        // 转换Appointment对象为符合数据库结构的Map
        Map<String, dynamic> appointmentMap = {
          'patient_id': appointment.patient_id,
          'appointment_date': _formatDateTime(appointment.appointment_date),
          'status': appointment.status,
          'treatment_type': appointment.treatment_type,
          'notes': appointment.notes,
          'cost': appointment.cost,
          'created_at': _formatDateTime(DateTime.now()),
          'updated_at': _formatDateTime(DateTime.now()),
        };

        final result = await _mysqlConnection!.query(
          'INSERT INTO appointments (patient_id, appointment_date, status, treatment_type, notes, cost, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
          [
            appointmentMap['patient_id'],
            appointmentMap['appointment_date'],
            appointmentMap['status'],
            appointmentMap['treatment_type'],
            appointmentMap['notes'],
            appointmentMap['cost'],
            appointmentMap['created_at'],
            appointmentMap['updated_at'],
          ],
        );

        // 标记预约数据需要刷新
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true;
        notifyListeners(); // 通知监听者数据已更改

        return result.insertId!;
      } catch (e) {
        print('MySQL添加预约时出错: $e');
        throw Exception('添加预约失败: $e');
      }
    }
  }

  // 更新预约
  Future<int> updateAppointment(Appointment appointment) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (appointment.id == null) {
      throw Exception('更新预约时必须提供ID');
    }

    if (_dataSourceType == 'sqlite') {
      try {
        // 转换Appointment对象为符合数据库结构的Map
        Map<String, dynamic> appointmentMap = {
          'patient_id': appointment.patient_id,
          'appointment_date': _formatDateTime(appointment.appointment_date),
          'status': appointment.status,
          'treatment_type': appointment.treatment_type,
          'notes': appointment.notes,
          'cost': appointment.cost,
          'updated_at': _formatDateTime(DateTime.now()),
        };

        // 更新数据
        int count = await _database!.update(
          'appointments',
          appointmentMap,
          where: 'id = ?',
          whereArgs: [appointment.id],
        );

        // 标记预约数据需要刷新
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true;
        notifyListeners(); // 通知监听者数据已更改

        return count;
      } catch (e) {
        print('更新预约时出错: $e');
        throw Exception('更新预约失败: $e');
      }
    } else {
      // MySQL更新预约
      try {
        // 转换Appointment对象为符合数据库结构的Map
        Map<String, dynamic> appointmentMap = {
          'patient_id': appointment.patient_id,
          'appointment_date': _formatDateTime(appointment.appointment_date),
          'status': appointment.status,
          'treatment_type': appointment.treatment_type,
          'notes': appointment.notes,
          'cost': appointment.cost,
          'updated_at': _formatDateTime(DateTime.now()),
        };

        final result = await _mysqlConnection!.query(
          'UPDATE appointments SET patient_id = ?, appointment_date = ?, status = ?, treatment_type = ?, notes = ?, cost = ?, updated_at = ? WHERE id = ?',
          [
            appointmentMap['patient_id'],
            appointmentMap['appointment_date'],
            appointmentMap['status'],
            appointmentMap['treatment_type'],
            appointmentMap['notes'],
            appointmentMap['cost'],
            appointmentMap['updated_at'],
            appointment.id,
          ],
        );

        // 标记预约数据需要刷新
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true;
        notifyListeners(); // 通知监听者数据已更改

        return result.affectedRows ?? 0;
      } catch (e) {
        print('MySQL更新预约时出错: $e');
        throw Exception('更新预约失败: $e');
      }
    }
  }

  // 删除预约
  Future<void> deleteAppointment(int appointmentId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      try {
        await _database!.delete(
          'appointments',
          where: 'id = ?',
          whereArgs: [appointmentId],
        );

        // 更新刷新标记
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true;
        notifyListeners(); // 通知监听者数据已更改
      } catch (e) {
        print('删除预约时出错: $e');
        throw Exception('删除预约失败: $e');
      }
    } else {
      try {
        await _mysqlConnection!.query(
          'DELETE FROM appointments WHERE id = ?',
          [appointmentId],
        );

        // 更新刷新标记
        _appointmentsNeedRefresh = true;
        _dashboardNeedRefresh = true;
        notifyListeners(); // 通知监听者数据已更改
      } catch (e) {
        print('MySQL删除预约时出错: $e');
        throw Exception('删除预约失败: $e');
      }
    }
  }

  // 获取预约总数
  Future<int> getAppointmentCount({String? doctorName}) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      // 按医生过滤
      if (doctorName != null && doctorName.isNotEmpty) {
        whereClause = 'doctor = ?';
        whereArgs = [doctorName];
      }

      if (_dataSourceType == 'sqlite') {
        final countResult = await _database!.rawQuery(
          'SELECT COUNT(*) as count FROM appointments${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
          whereArgs,
        );
        return countResult.first['count'] as int;
      } else {
        final conn = await _getMySQLConnection();
        final result = await conn.query(
          'SELECT COUNT(*) as count FROM appointments${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
          whereArgs,
        );
        await conn.close();
        return result.first['count'] as int;
      }
    } catch (e) {
      print('获取预约数量时出错: $e');
      return 0;
    }
  }

  // 获取已完成预约数量
  Future<int> getCompletedAppointmentCount({String? doctorName}) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 修改SQL查询，支持所有可能的"已完成"状态值
      String whereClause =
          "(status = 'completed' OR status = '已完成' OR status = 'Completed')";
      List<dynamic> whereArgs = [];

      // 按医生过滤
      if (doctorName != null && doctorName.isNotEmpty) {
        whereClause += ' AND doctor = ?';
        whereArgs.add(doctorName);
      }

      print('执行已完成预约查询: $whereClause, 参数: $whereArgs');

      if (_dataSourceType == 'sqlite') {
        final countResult = await _database!.rawQuery(
          'SELECT COUNT(*) as count FROM appointments WHERE $whereClause',
          whereArgs,
        );
        final count = countResult.first['count'] as int;
        print('查询到已完成预约数量: $count');
        return count;
      } else {
        final conn = await _getMySQLConnection();
        final result = await conn.query(
          'SELECT COUNT(*) as count FROM appointments WHERE $whereClause',
          whereArgs,
        );
        await conn.close();
        final count = result.first['count'] as int;
        print('查询到已完成预约数量: $count');
        return count;
      }
    } catch (e) {
      print('获取已完成预约数量时出错: $e');
      return 0;
    }
  }

  // 获取患者统计数据
  Future<int> getPatientCount({String? doctorName}) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      // 按医生过滤
      if (doctorName != null && doctorName.isNotEmpty) {
        whereClause = 'doctor = ?';
        whereArgs = [doctorName];
      }

      if (_dataSourceType == 'sqlite') {
        final countResult = await _database!.rawQuery(
          'SELECT COUNT(*) as count FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
          whereArgs,
        );
        return countResult.first['count'] as int;
      } else {
        final conn = await _getMySQLConnection();
        final result = await conn.query(
          'SELECT COUNT(*) as count FROM patients${whereClause.isNotEmpty ? ' WHERE $whereClause' : ''}',
          whereArgs,
        );
        await conn.close();
        return result.first['count'] as int;
      }
    } catch (e) {
      print('获取患者数量时出错: $e');
      return 0;
    }
  }

  // 获取今日预约
  Future<List<Appointment>> getTodayAppointments({String? doctorName}) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      // 获取今天的日期，格式化为 YYYY-MM-DD
      final today = DateTime.now();
      final dateString =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      List<Appointment> appointments = [];

      if (_dataSourceType == 'sqlite') {
        String query = '''
          SELECT a.*, p.name as patient_name, p.doctor, p.gender, p.age, p.phone, p.first_visit_date
          FROM appointments a 
          JOIN patients p ON a.patient_id = p.id 
          WHERE date(a.appointment_date) = date(?) 
        ''';

        List<dynamic> args = [dateString];

        // 如果提供了医生名称，添加过滤条件
        if (doctorName != null && doctorName.isNotEmpty) {
          query += 'AND p.doctor = ? ';
          args.add(doctorName);
        }

        query += 'ORDER BY a.appointment_date ASC';

        final results = await _database!.rawQuery(query, args);
        appointments = results.map((row) {
          // 创建带有患者信息的Appointment对象
          final appointment = Appointment.fromMap(row);
          appointment.patient = Patient(
            id: row['patient_id'] as int,
            name: row['patient_name'] as String,
            gender: row['gender'] as String,
            age: row['age'] as int,
            phone: row['phone'],
            first_visit_date: _parseDateTime(row['first_visit_date']),
            doctor: row['doctor'] as String?,
          );
          return appointment;
        }).toList();
      } else {
        // 为MySQL实现相同的查询
        final conn = await _getMySQLConnection();
        String query = '''
          SELECT a.*, p.name as patient_name, p.doctor, p.gender, p.age, p.phone, p.first_visit_date
          FROM appointments a 
          JOIN patients p ON a.patient_id = p.id 
          WHERE DATE(a.appointment_date) = DATE(?) 
        ''';

        List<dynamic> args = [dateString];

        // 如果提供了医生名称，添加过滤条件
        if (doctorName != null && doctorName.isNotEmpty) {
          query += 'AND p.doctor = ? ';
          args.add(doctorName);
        }

        query += 'ORDER BY a.appointment_date ASC';

        final results = await conn.query(query, args);
        for (var row in results) {
          final Map<String, dynamic> appointmentMap = {};
          for (var entry in row.fields.entries) {
            appointmentMap[entry.key] = entry.value;
          }

          final appointment = Appointment.fromMap(appointmentMap);
          appointment.patient = Patient(
            id: row['patient_id'] as int,
            name: row['patient_name'] as String,
            gender: row['gender'] as String,
            age: row['age'] as int,
            phone: row['phone'],
            first_visit_date: _parseDateTime(row['first_visit_date']),
            doctor: row['doctor'] as String?,
          );
          appointments.add(appointment);
        }
        await conn.close();
      }

      return appointments;
    } catch (e) {
      print('获取今日预约时出错: $e');
      return [];
    }
  }

  // 获取最近添加的患者
  Future<List<Patient>> getRecentPatients(
      {int limit = 5, String? doctorName}) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      String whereClause = '';
      List<dynamic> whereArgs = [];

      // 按医生过滤
      if (doctorName != null && doctorName.isNotEmpty) {
        whereClause = 'WHERE doctor = ?';
        whereArgs = [doctorName];
      }

      if (_dataSourceType == 'sqlite') {
        final List<Map<String, dynamic>> maps = await _database!.rawQuery(
          'SELECT * FROM patients $whereClause ORDER BY updated_at DESC LIMIT ?',
          [...whereArgs, limit],
        );

        return maps.map((map) => Patient.fromMap(map)).toList();
      } else {
        final conn = await _getMySQLConnection();
        final results = await conn.query(
          'SELECT * FROM patients $whereClause ORDER BY updated_at DESC LIMIT ?',
          [...whereArgs, limit],
        );
        await conn.close();

        // 转换为Patient对象
        final List<Map<String, dynamic>> maps = [];
        for (var row in results) {
          maps.add({
            for (var entry in row.fields.entries) entry.key: entry.value,
          });
        }

        return maps.map((map) => Patient.fromMap(map)).toList();
      }
    } catch (e) {
      print('获取最近患者时出错: $e');
      return [];
    }
  }

  // MySQL连接帮助方法
  Future<MySqlConnection> _getMySQLConnection() async {
    final settingsProvider = SettingsProvider();
    await settingsProvider.init();

    final String host = settingsProvider.mysqlHost;
    final int port = int.tryParse(settingsProvider.mysqlPort) ?? 3306;
    final String database = settingsProvider.mysqlDatabase;
    final String username = settingsProvider.mysqlUsername;
    final String password = settingsProvider.mysqlPassword;

    final settings = ConnectionSettings(
      host: host,
      port: port,
      user: username,
      password: password,
      db: database,
    );

    return await MySqlConnection.connect(settings);
  }

  // 保存上次MySQL设置的方法
  Future<void> _saveLastMySQLSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> settings = {
        'host': _mysqlHost,
        'port': _mysqlPort,
        'database': _mysqlDatabase,
        'username': _mysqlUsername,
        'password': _mysqlPassword,
      };

      await prefs.setString('last_mysql_settings', jsonEncode(settings));
      _lastMySQLSettings = settings;
    } catch (e) {
      print('保存MySQL设置失败: $e');
    }
  }

  // =================== 用户相关方法 ===================

  // 获取所有用户
  Future<List<User>> getAllUsers() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      List<User> users = [];

      if (_dataSourceType == 'sqlite') {
        final db = await database;
        final result =
            await db!.rawQuery('SELECT * FROM users ORDER BY username');
        users = result.map((e) => User.fromMap(e)).toList();
      } else if (_dataSourceType == 'mysql') {
        try {
          final conn = await mysqlConnection;
          final results =
              await conn!.query('SELECT * FROM users ORDER BY username');

          print('MySQL查询用户数据: ${results.length} 个用户');

          for (var row in results) {
            try {
              final map = <String, dynamic>{};
              for (var field in row.fields.keys) {
                var value = row[field];
                if (value is Blob) {
                  final blobString = String.fromCharCodes(value.toBytes());
                  print(
                      '将用户Blob字段 $field 转换为字符串: ${blobString.substring(0, math.min(30, blobString.length))}...');
                  map[field] = blobString;
                } else {
                  // 其他字段直接放入map
                  map[field] = value;
                }
              }
              users.add(User.fromMap(map));
            } catch (e) {
              print('处理MySQL用户数据时出错: $e');
            }
          }
        } catch (e) {
          print('MySQL查询用户列表出错: $e');
          rethrow;
        }
      }

      return users;
    } catch (e) {
      print('获取所有用户出错: $e');
      return [];
    }
  }

  // 添加用户 - 使用本地时间而非UTC
  Future<void> addUser(String username, String password, String role,
      {String? email, String? doctor}) async {
    try {
      // 使用SHA-256加密密码，与登录时使用的加密方法一致
      var bytes = utf8.encode(password);
      var digest = sha256.convert(bytes);
      final hashedPassword = digest.toString();

      final now = DateTime.now(); // 使用本地时间
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      if (_dataSourceType == 'mysql' && _mysqlConnection != null) {
        await _mysqlConnection!.query(
          'INSERT INTO users (username, password, role, email, doctor, created_at) VALUES (?, ?, ?, ?, ?, ?)',
          [
            username,
            hashedPassword,
            role,
            email ?? '',
            doctor ?? '',
            timestamp
          ],
        );
      } else {
        await _database!.insert(
          'users',
          {
            'username': username,
            'password': hashedPassword,
            'role': role,
            'email': email ?? '',
            'doctor': doctor,
            'created_at': timestamp,
          },
        );
      }
    } catch (e) {
      if (_dataSourceType == 'mysql') {
        print('MySQL添加用户时出错: $e');
      } else {
        print('SQLite添加用户时出错: $e');
      }
      rethrow;
    }
  }

  // 更新用户信息 - 使用本地时间而非UTC
  Future<void> updateUser(
      int id, String username, String? password, String role,
      {String? email, String? doctor}) async {
    try {
      final now = DateTime.now(); // 使用本地时间

      // 构建更新数据
      Map<String, dynamic> userData = {
        'username': username,
        'role': role,
        'email': email ?? '',
      };

      // 如果提供了医生姓名，则更新医生字段
      if (doctor != null) {
        userData['doctor'] = doctor;
      }

      // 如果提供了新密码，则更新密码
      if (password != null && password.isNotEmpty) {
        // 使用SHA-256加密密码，与登录时使用的加密方法一致
        var bytes = utf8.encode(password);
        var digest = sha256.convert(bytes);
        userData['password'] = digest.toString();
      }

      if (_dataSourceType == 'mysql' && _mysqlConnection != null) {
        String query = 'UPDATE users SET ';
        List<String> setParts = [];
        List<dynamic> params = [];

        userData.forEach((key, value) {
          setParts.add('$key = ?');
          params.add(value);
        });

        query += setParts.join(', ');
        query += ' WHERE id = ?';
        params.add(id);

        await _mysqlConnection!.query(query, params);
      } else {
        await _database!.update(
          'users',
          userData,
          where: 'id = ?',
          whereArgs: [id],
        );
      }
    } catch (e) {
      print('更新用户信息时出错: $e');
      rethrow;
    }
  }

  // 更新用户密码
  Future<int> updateUserPassword(int userId, String newPassword) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    // 使用MD5加密密码，确保与登录验证一致
    var bytes = utf8.encode(newPassword);
    var digest = md5.convert(bytes);
    String hashedPassword = digest.toString();

    print('更新用户密码，使用MD5加密: $hashedPassword');

    if (_dataSourceType == 'sqlite') {
      try {
        // 更新密码
        Map<String, dynamic> passwordMap = {
          'password': hashedPassword,
        };

        int count = await _database!.update(
          'users',
          passwordMap,
          where: 'id = ?',
          whereArgs: [userId],
        );
        print('SQLite更新用户密码成功，影响行数: $count');
        return count;
      } catch (e) {
        print('更新用户密码时出错: $e');
        throw Exception('更新用户密码失败: $e');
      }
    } else {
      // MySQL更新密码
      try {
        Results results = await _mysqlConnection!.query(
          'UPDATE users SET password = ? WHERE id = ?',
          [hashedPassword, userId],
        );
        print('MySQL更新用户密码成功，影响行数: ${results.affectedRows}');
        return results.affectedRows ?? 0;
      } catch (e) {
        print('MySQL更新用户密码时出错: $e');
        throw Exception('更新用户密码失败: $e');
      }
    }
  }

  // 删除用户
  Future<int> deleteUser(int userId) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    if (_dataSourceType == 'sqlite') {
      try {
        int count = await _database!.delete(
          'users',
          where: 'id = ?',
          whereArgs: [userId],
        );
        print('SQLite删除用户成功，影响行数: $count');
        return count;
      } catch (e) {
        print('删除用户时出错: $e');
        throw Exception('删除用户失败: $e');
      }
    } else {
      // MySQL删除用户
      try {
        Results results = await _mysqlConnection!.query(
          'DELETE FROM users WHERE id = ?',
          [userId],
        );
        print('MySQL删除用户成功，影响行数: ${results.affectedRows}');
        return results.affectedRows ?? 0;
      } catch (e) {
        print('MySQL删除用户时出错: $e');
        throw Exception('删除用户失败: $e');
      }
    }
  }

  // 从SQL文件恢复数据库
  Future<void> restoreFromSqlFile(String sqlFilePath) async {
    try {
      // 读取SQL文件内容
      final file = File(sqlFilePath);
      String sqlContent = await file.readAsString();

      // 替换牙齿状况的十六进制格式为JSON字符串格式
      sqlContent = _processDentalConditionFormat(sqlContent);

      // 分割SQL语句
      List<String> statements = _splitSqlStatements(sqlContent);

      print('共有 ${statements.length} 条SQL语句需要执行');

      // 逐条执行SQL语句
      for (var statement in statements) {
        // 跳过空语句和注释
        statement = statement.trim();
        if (statement.isEmpty || statement.startsWith('--')) {
          continue;
        }

        try {
          await _mysqlConnection!.query(statement);
        } catch (e) {
          print('执行SQL语句时出错: $e');
          print('问题语句: $statement');
          // 继续执行其他语句
        }
      }

      print('数据库已从 $sqlFilePath 恢复');
    } catch (e) {
      print('恢复数据库时出错: $e');
      rethrow;
    }
  }

  // 添加新的方法来处理MySQL备份还原
  Future<void> restoreFromMySQLDump(String dumpFilePath) async {
    print('开始恢复MySQL数据库...');

    // 检查数据源类型
    if (_dataSourceType != 'mysql') {
      throw Exception('当前数据源不是MySQL');
    }

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

        // 获取mysql.exe的路径
        final mysqlPath = _getMySQLToolPath('mysql.exe');
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

        // 获取mysql.exe的路径
        final mysqlPath = _getMySQLToolPath('mysql.exe');
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

        // 获取mysql.exe的路径
        final mysqlPath = _getMySQLToolPath('mysql.exe');
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
    } catch (e) {
      print('执行MySQL还原时出错: $e');
      rethrow;
    }
  }

  // 添加备份MySQL数据库的方法
  Future<String> backupMySQLDatabase() async {
    print('开始MySQL备份过程...');

    // 检查数据源类型
    if (_dataSourceType != 'mysql') {
      throw Exception('当前数据源不是MySQL，无法执行MySQL备份');
    }

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

    // 构建mysqldump工具路径
    final toolPath = _getMySQLToolPath('mysqldump.exe');
    print('使用mysqldump工具: $toolPath');

    // 从SettingsProvider获取用户指定的备份目录
    final settingsProvider = SettingsProvider();
    await settingsProvider.init();
    final userBackupPath = settingsProvider.backupPath;
    print('备份目录: $userBackupPath');

    if (userBackupPath.isEmpty) {
      throw Exception('未设置备份目录');
    }

    // 确保备份目录存在
    final backupDir = Directory(userBackupPath);
    if (!await backupDir.exists()) {
      print('创建备份目录: ${backupDir.path}');
      await backupDir.create(recursive: true);
    }

    // 生成备份文件名
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFileName = 'backup_$timestamp.sql';
    final backupPath = path.join(userBackupPath, backupFileName);
    print('备份文件路径: $backupPath');

    // 构建命令参数列表
    final List<String> args = [
      '-h${mysqlSettings['host']}',
      '-P${mysqlSettings['port']}',
      '-u${mysqlSettings['username']}',
      '-p${mysqlSettings['password']}',
      '--default-character-set=utf8mb4',
      mysqlSettings['database'],
      '--result-file=$backupPath' // 直接指定输出文件
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

      print('MySQL备份已保存到: $backupPath');
      return backupPath;
    } catch (e) {
      print('执行备份命令时出错: $e');
      throw Exception('备份失败: $e');
    }
  }

  // 辅助方法：格式化SQL值
  String _formatValue(dynamic value) {
    if (value == null) return 'NULL';
    if (value is num) return value.toString();
    if (value is DateTime) {
      // 确保DateTime值使用UTC格式
      final utcDate = value.toUtc();
      return "'${utcDate.toIso8601String().replaceAll('T', ' ').split('.')[0]}'";
    }
    if (value is bool) return value ? '1' : '0';
    return "'${value.toString().replaceAll("'", "''")}'";
  }

  // 标记所有数据需要刷新
  void _markAllDataForRefresh() {
    print('标记数据需要刷新...');
    markPatientsNeedRefresh();
    markAppointmentsNeedRefresh();
    markDashboardNeedRefresh();
    markFollowUpsNeedRefresh();
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
    for (int i = 0; i < min(10, possiblePaths.length); i++) {
      print('- ${possiblePaths[i]}');
    }
    if (possiblePaths.length > 10) {
      print('...及其他 ${possiblePaths.length - 10} 个路径');
    }

    // 首先检查具体路径
    for (final toolPath in possiblePaths) {
      try {
        if (File(toolPath).existsSync()) {
          print('找到MySQL工具: $toolPath');
          return toolPath;
        }
      } catch (e) {
        print('检查路径时出错: $e');
      }
    }

    // 搜索应用程序目录及其子目录
    print('在应用程序目录及其子目录中搜索...');
    try {
      final directories = [
        path.dirname(Platform.resolvedExecutable),
        Directory.current.path,
        path.dirname(Directory.current.path),
        'C:\\Program Files\\牙医诊所管理系统',
        'C:\\Program Files (x86)\\牙医诊所管理系统',
      ];

      for (final dir in directories) {
        final foundPath = _findFileRecursively(dir, toolName, maxDepth: 4);
        if (foundPath != null) {
          print('通过递归搜索找到MySQL工具: $foundPath');
          return foundPath;
        }
      }
    } catch (e) {
      print('递归搜索时出错: $e');
    }

    // 尝试创建tools目录并测试权限
    final appDir = path.dirname(Platform.resolvedExecutable);
    final toolsDir = path.join(appDir, 'tools');

    print('应用程序目录: $appDir');
    try {
      print('应用程序目录内容:');
      Directory(appDir).listSync().forEach((entity) {
        print('- ${entity.path}');
      });
    } catch (e) {
      print('无法列出应用程序目录内容: $e');
    }

    try {
      if (Directory(toolsDir).existsSync()) {
        print('tools目录存在，目录内容:');
        Directory(toolsDir).listSync().forEach((entity) {
          print('- ${entity.path}');
        });
      } else {
        print('tools目录不存在: $toolsDir，尝试创建...');
        try {
          Directory(toolsDir).createSync();
          print('成功创建tools目录');

          // 测试写入权限
          final testFile = File(path.join(toolsDir, 'test.tmp'));
          testFile.writeAsStringSync('测试写入权限');
          print('成功写入测试文件');
          testFile.deleteSync();
          print('成功删除测试文件');
        } catch (e) {
          print('无法创建或测试tools目录: $e');
        }
      }
    } catch (e) {
      print('测试tools目录权限时出错: $e');
    }

    // 如果找不到工具，尝试使用命令名
    print('未找到MySQL工具，将尝试直接使用命令名: $toolName');
    return toolName;
  }

  // 递归查找文件
  String? _findFileRecursively(String directory, String fileName,
      {int maxDepth = 3, int currentDepth = 0}) {
    if (currentDepth > maxDepth) return null;

    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return null;

      for (var entity in dir.listSync()) {
        if (entity is File && path.basename(entity.path) == fileName) {
          return entity.path;
        } else if (entity is Directory) {
          final result = _findFileRecursively(entity.path, fileName,
              maxDepth: maxDepth, currentDepth: currentDepth + 1);
          if (result != null) return result;
        }
      }
    } catch (e) {
      print('在目录 $directory 中搜索时出错: $e');
    }

    return null;
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

  // 在database_provider.dart中添加以下方法
  Future<void> updateAllPatientsPinyin() async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    List<Patient> patients = await getAllPatients();
    int updatedCount = 0;

    for (var patient in patients) {
      Map<String, dynamic> patientMap = patient.toMap();

      // 更新拼音和首字母字段
      patientMap['name_pinyin'] = PinyinUtil.toPinyin(patient.name);
      patientMap['name_initials'] = PinyinUtil.getInitials(patient.name);

      if (patient.address != null && patient.address!.isNotEmpty) {
        patientMap['address_pinyin'] = PinyinUtil.toPinyin(patient.address!);
      }

      try {
        if (dataSourceType == 'sqlite') {
          await _database!.update(
            'patients',
            {
              'name_pinyin': patientMap['name_pinyin'],
              'name_initials': patientMap['name_initials'],
              'address_pinyin': patientMap['address_pinyin'],
            },
            where: 'id = ?',
            whereArgs: [patient.id],
          );
          updatedCount++;
        } else {
          await _mysqlConnection!.query(
            'UPDATE patients SET name_pinyin = ?, name_initials = ?, address_pinyin = ? WHERE id = ?',
            [
              patientMap['name_pinyin'],
              patientMap['name_initials'],
              patientMap['address_pinyin'],
              patient.id,
            ],
          );
          updatedCount++;
        }
      } catch (e) {
        print('更新患者拼音数据时出错: $e');
      }
    }

    print('已更新 $updatedCount/${patients.length} 位患者的拼音和首字母数据');

    // 标记患者数据需要刷新
    _patientsNeedRefresh = true;
    notifyListeners();
  }

  // 检查病历号是否已存在
  Future<bool> checkMedicalRecordExists(int medicalRecordNumber,
      [int? excludePatientId]) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      if (_dataSourceType == 'sqlite') {
        final db = await database;

        // 构建查询条件
        String whereClause = 'medical_record_number = ?';
        List<dynamic> whereArgs = [medicalRecordNumber];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final result = await db!.query(
          'patients',
          where: whereClause,
          whereArgs: whereArgs,
          limit: 1,
        );

        return result.isNotEmpty;
      } else if (_dataSourceType == 'mysql') {
        final conn = await mysqlConnection;

        // 构建查询条件
        String whereClause = 'medical_record_number = ?';
        List<dynamic> whereArgs = [medicalRecordNumber];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final results = await conn!.query(
          'SELECT id FROM patients WHERE $whereClause LIMIT 1',
          whereArgs,
        );

        return results.isNotEmpty;
      }

      return false;
    } catch (e) {
      print('检查病历号存在性时出错: $e');
      return false;
    }
  }

  // 检查姓名是否已存在
  Future<bool> checkPatientNameExists(String name,
      [int? excludePatientId]) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      if (_dataSourceType == 'sqlite') {
        final db = await database;

        // 构建查询条件
        String whereClause = 'name = ?';
        List<dynamic> whereArgs = [name];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final result = await db!.query(
          'patients',
          where: whereClause,
          whereArgs: whereArgs,
          limit: 1,
        );

        return result.isNotEmpty;
      } else if (_dataSourceType == 'mysql') {
        final conn = await mysqlConnection;

        // 构建查询条件
        String whereClause = 'name = ?';
        List<dynamic> whereArgs = [name];

        // 如果是编辑模式，排除当前患者
        if (excludePatientId != null) {
          whereClause += ' AND id != ?';
          whereArgs.add(excludePatientId);
        }

        final results = await conn!.query(
          'SELECT id FROM patients WHERE $whereClause LIMIT 1',
          whereArgs,
        );

        return results.isNotEmpty;
      }

      return false;
    } catch (e) {
      print('检查患者姓名存在性时出错: $e');
      return false;
    }
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
          return DateTime.parse(dateTime);
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

  // 获取特定医生的所有预约
  Future<List<Appointment>> getAppointmentsByDoctor(String doctorName) async {
    if (!initialized) {
      throw Exception('数据库未初始化');
    }

    try {
      List<Appointment> appointments = [];

      if (_dataSourceType == 'sqlite') {
        // SQLite查询
        final results = await _database!.rawQuery('''
          SELECT a.*, p.name as patient_name, p.gender, p.age, p.phone, p.doctor, p.first_visit_date
          FROM appointments a
          JOIN patients p ON a.patient_id = p.id
          WHERE p.doctor = ?
          ORDER BY a.appointment_date DESC
        ''', [doctorName]);

        for (var appointmentMap in results) {
          final appointment = Appointment.fromMap(appointmentMap);

          // 创建患者对象
          appointment.patient = Patient(
            id: appointmentMap['patient_id'] as int,
            name: appointmentMap['patient_name'] as String,
            gender: appointmentMap['gender'] as String,
            age: appointmentMap['age'] as int,
            phone: appointmentMap['phone'] as String?,
            doctor: appointmentMap['doctor'] as String?,
            first_visit_date:
                _parseDateTime(appointmentMap['first_visit_date']),
          );

          appointments.add(appointment);
        }
      } else {
        // MySQL查询
        final conn = await _getMySQLConnection();
        final results = await conn.query('''
          SELECT a.*, p.name as patient_name, p.gender, p.age, p.phone, p.doctor, p.first_visit_date
          FROM appointments a
          JOIN patients p ON a.patient_id = p.id
          WHERE p.doctor = ?
          ORDER BY a.appointment_date DESC
        ''', [doctorName]);

        for (var row in results) {
          // 将结果转换为Map
          final Map<String, dynamic> appointmentMap = {};
          for (var entry in row.fields.entries) {
            appointmentMap[entry.key] = entry.value;
          }

          // 创建预约对象
          final appointment = Appointment.fromMap(appointmentMap);

          // 创建患者对象
          appointment.patient = Patient(
            id: appointmentMap['patient_id'] as int,
            name: appointmentMap['patient_name'] as String,
            gender: appointmentMap['gender'] as String,
            age: appointmentMap['age'] as int,
            phone: appointmentMap['phone'] as String?,
            doctor: appointmentMap['doctor'] as String?,
            first_visit_date:
                _parseDateTime(appointmentMap['first_visit_date']),
          );

          appointments.add(appointment);
        }

        await conn.close();
      }

      return appointments;
    } catch (e) {
      print('获取医生预约时出错: $e');
      return [];
    }
  }
}

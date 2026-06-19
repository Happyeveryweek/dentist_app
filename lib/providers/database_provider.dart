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

// 导入新的服务类
import '../services/sqlite_database_service.dart';
import '../services/mysql_connection_service.dart';
import '../services/database_backup_service.dart';
import '../services/database_schema_service.dart';


class DatabaseProvider extends ChangeNotifier {
  static const String DB_NAME = 'dentist_clinic.db';
  static const int DB_VERSION = 3;

  // 服务实例
  late SqliteDatabaseService _sqliteService;
  late MysqlConnectionService _mysqlService;
  late DatabaseBackupService _backupService;
  late DatabaseSchemaService _schemaService;

  // 数据库实例（保留用于兼容）
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
  
  // MySQL连接参数 - 用于内部操作
  String _mysqlHost = 'localhost';
  String _mysqlPort = '3306';
  String _mysqlDatabase = 'dentist_db';
  String _mysqlUsername = 'root';
  String _mysqlPassword = '';

  // Getters
  Database? get database => _database;
  bool get initialized => _database != null || mysqlConnection != null;
  MySqlConnection? get mysqlConnection {
    _syncMysqlConnectionFromService();
    return _mysqlConnection;
  }
  Map<String, dynamic>? get mysqlSettings => _mysqlSettings;
  String get dataSourceType => _dataSourceType;

  bool get dashboardNeedRefresh => _dashboardNeedRefresh;

  // 当前用户信息
  User? _currentUser;

  // 服务实例 getters（供其他 Provider 使用）
  SqliteDatabaseService get sqliteService => _sqliteService;
  MysqlConnectionService get mysqlService => _mysqlService;
  DatabaseBackupService get backupService => _backupService;
  DatabaseSchemaService get schemaService => _schemaService;

  // 构造函数
  DatabaseProvider() {
    _initializeServices();
  }

  // 初始化服务实例
  void _initializeServices() {
    _sqliteService = SqliteDatabaseService();
    _mysqlService = MysqlConnectionService();
    _backupService = DatabaseBackupService(
      dataSourceType: _dataSourceType,
    );
    _schemaService = DatabaseSchemaService(
      dataSourceType: _dataSourceType,
    );
  }

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

        // 设置自定义路径
        if (customPath != null && customPath.isNotEmpty) {
          print('自定义路径: $customPath');
          _customSqliteDbPath = customPath;
          _sqliteService.setCustomSqliteDbPath(customPath);
        }

        print('初始化SQLite数据库...');
        _database = await _sqliteService.initSQLiteDatabase();
        
        // 同步服务中的数据库实例
        _updateServiceConnections();
        
        print('SQLite数据库初始化完成，路径: ${_database!.path}');
      } else if (_dataSourceType == 'mysql') {
        // 检查是否已经有有效的MySQL连接
        _syncMysqlConnectionFromService();
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
        
        final normalizedMySQLSettings = _normalizeMySQLSettings(mysqlSettings);
        final host = normalizedMySQLSettings.host;
        final port = normalizedMySQLSettings.port;
        final database = normalizedMySQLSettings.database;
        final username = normalizedMySQLSettings.username;
        final password = normalizedMySQLSettings.password;
        
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
          _mysqlConnection = await _mysqlService.initMySQLConnection(
            host: host,
            port: port,
            database: database,
            username: username,
            password: password,
          );

          print('MySQL数据库连接成功');

          // 验证连接是否正常
          try {
            final results = await _mysqlConnection!.query('SELECT 1');
            print('MySQL连接测试: ${results.isNotEmpty ? '成功' : '失败'}');
            
            // 连接成功后，创建MySQL表结构
            _updateServiceConnections();
            await _schemaService.createMySQLTables();
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

  // 更新服务中的连接实例
  void _updateServiceConnections() {
    _backupService = DatabaseBackupService(
      sqliteDatabase: _database,
      mysqlConnection: _mysqlConnection,
      dataSourceType: _dataSourceType,
    );
    _schemaService = DatabaseSchemaService(
      sqliteDatabase: _database,
      mysqlConnection: _mysqlConnection,
      dataSourceType: _dataSourceType,
    );
  }

  void _syncMysqlConnectionFromService() {
    final serviceConnection = _mysqlService.connection;
    if (serviceConnection != null && !identical(serviceConnection, _mysqlConnection)) {
      _mysqlConnection = serviceConnection;
    }
  }

  _MySQLConnectionInfo _normalizeMySQLSettings(Map<String, dynamic> mysqlSettings) {
    final connectionInfo = _MySQLConnectionInfo(
      host: (mysqlSettings['host'] ?? 'localhost').toString(),
      port: int.tryParse(mysqlSettings['port']?.toString() ?? '3306') ?? 3306,
      database: (mysqlSettings['database'] ?? 'dentist_db').toString(),
      username: (mysqlSettings['username'] ?? 'root').toString(),
      password: (mysqlSettings['password'] ?? '').toString(),
    );

    _mysqlHost = connectionInfo.host;
    _mysqlPort = connectionInfo.port.toString();
    _mysqlDatabase = connectionInfo.database;
    _mysqlUsername = connectionInfo.username;
    _mysqlPassword = connectionInfo.password;
    _mysqlSettings = connectionInfo.toMap();

    return connectionInfo;
  }

  _MySQLConnectionInfo _resolveMySQLCredentials({
    Map<String, dynamic>? mysqlSettings,
  }) {
    if (mysqlSettings != null) {
      return _MySQLConnectionInfo(
        host: (mysqlSettings['host'] ?? _mysqlHost).toString(),
        port: int.tryParse(mysqlSettings['port']?.toString() ?? _mysqlPort) ?? 3306,
        database: (mysqlSettings['database'] ?? _mysqlDatabase).toString(),
        username: (mysqlSettings['username'] ?? _mysqlUsername).toString(),
        password: (mysqlSettings['password'] ?? _mysqlPassword).toString(),
      );
    }

    return _MySQLConnectionInfo(
      host: _mysqlHost,
      port: int.tryParse(_mysqlPort) ?? 3306,
      database: _mysqlDatabase,
      username: _mysqlUsername,
      password: _mysqlPassword,
    );
  }

  // 初始化SQLite数据库（委托给服务）
  Future<Database> initSQLiteDatabase() async {
    return await _sqliteService.initSQLiteDatabase();
  }

  // 确保SQLite数据库可用的方法（紧急情况使用）
  Future<void> ensureSQLiteDatabase() async {
    await _sqliteService.ensureSQLiteDatabase();
    _database = _sqliteService.database;
    _updateServiceConnections();
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
  

  

  

  

  

  


  // _createDatabase 已移至 DatabaseSchemaService

  // _createMySQLTables 已移至 DatabaseSchemaService

  // _upgradeDatabase 已移至 DatabaseSchemaService

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
      _syncMysqlConnectionFromService();
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

  // 数据库备份方法（委托给 DatabaseBackupService）
  Future<String> backupDatabase({
    String? backupPath,
    Function(String)? onLogSuccess,
    Function(String)? onLogFailure,
    String? backupDataSource,
  }) async {
    _syncMysqlConnectionFromService();
    _updateServiceConnections();
    
    // 如果备份 MySQL，需要传递连接参数
    final targetDataSource = backupDataSource ?? _dataSourceType;
    if (targetDataSource == 'mysql') {
      return await _backupService.backupDatabase(
        backupPath: backupPath,
        onLogSuccess: onLogSuccess,
        onLogFailure: onLogFailure,
        backupDataSource: backupDataSource,
        mysqlHost: _mysqlHost,
        mysqlPort: int.tryParse(_mysqlPort) ?? 3306,
        mysqlDatabase: _mysqlDatabase,
        mysqlUsername: _mysqlUsername,
        mysqlPassword: _mysqlPassword,
      );
    }
    
    return await _backupService.backupDatabase(
      backupPath: backupPath,
      onLogSuccess: onLogSuccess,
      onLogFailure: onLogFailure,
      backupDataSource: backupDataSource,
    );
  }

  // 备份日志记录已移动到SettingsProvider
  // 请使用SettingsProvider中的相关方法记录备份操作

  // backupSQLiteDatabase 已移至 DatabaseBackupService

  // 从备份文件恢复数据库（委托给 DatabaseBackupService）
  Future<void> restoreFromBackup(String backupFilePath) async {
    _syncMysqlConnectionFromService();
    _updateServiceConnections();
    await _backupService.restoreFromBackup(backupFilePath);
  }

  // _checkTableExists 已移至 MysqlConnectionService

  // 数据库恢复方法（委托给 DatabaseBackupService）
  Future<void> restoreDatabase(String filePath) async {
    print('开始从备份文件恢复数据库: $filePath');
    _syncMysqlConnectionFromService();
    _updateServiceConnections();
    await _backupService.restoreDatabase(filePath);
    
    // 标记数据需要刷新
    _markAllDataForRefresh();
    notifyListeners();
  }

  // restoreSQLiteDatabase 已移至 DatabaseBackupService

  // _splitSqlStatements 已移至 DatabaseBackupService

  // _executeMySQLImport 已移至 DatabaseBackupService
  // _fixDateTimeFormatsInSQL 已移至 DatabaseBackupService





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
          _syncMysqlConnectionFromService();
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
        // 保存完整的MySQL设置
        _normalizeMySQLSettings(mysqlSettings);

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



  // 测试MySQL连接（委托给 MysqlConnectionService）
  Future<bool> testMySQLConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    return await _mysqlService.testConnection(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
  }

  // 初始化MySQL连接（委托给 MysqlConnectionService）
  Future<void> initializeMySQLConnection(Map<String, dynamic> mysqlSettings) async {
    final connectionInfo = _normalizeMySQLSettings(mysqlSettings);

    await _mysqlService.initializeMySQLConnection(
      host: connectionInfo.host,
      port: connectionInfo.port,
      database: connectionInfo.database,
      username: connectionInfo.username,
      password: connectionInfo.password,
    );
    
    // 同步连接实例
    _mysqlConnection = _mysqlService.connection;
    _updateServiceConnections();
  }

  // 兼容旧调用：根据当前保存的 MySQL 设置重新初始化连接
  Future<void> initializeMySQL() async {
    _syncMysqlConnectionFromService();
    final settings = _mysqlSettings;
    if (settings == null) {
      throw Exception('MySQL设置为空，无法重新初始化连接');
    }
    await initializeMySQLConnection(settings);
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

  // restoreFromMySQLDump 已移至 DatabaseBackupService
  Future<void> restoreFromMySQLDump(String dumpFilePath, {
    Map<String, dynamic>? mysqlSettings,
    Function(String)? onLogOperation,
  }) async {
    _syncMysqlConnectionFromService();
    _updateServiceConnections();
    await _backupService.restoreFromMySQLDump(dumpFilePath, onLogOperation: onLogOperation);
  }

  // MySQL备份功能已移动到SettingsProvider
  // 请使用SettingsProvider.backupMySQLDatabase()方法

  // _formatValue 已移至 DatabaseBackupService
  // _getMySQLToolPath 已移至 DatabaseBackupService

  // backupMySQLDatabase 已移至 DatabaseBackupService
  Future<String> backupMySQLDatabase({
    String? backupPath,
    Map<String, dynamic>? mysqlSettings,
  }) async {
    _syncMysqlConnectionFromService();
    _updateServiceConnections();
    
    // 从内部变量或传入的设置获取连接参数
    final credentials = _resolveMySQLCredentials(mysqlSettings: mysqlSettings);
    
    return await _backupService.backupMySQLDatabase(
      backupPath: backupPath,
      host: credentials.host,
      port: credentials.port,
      database: credentials.database,
      username: credentials.username,
      password: credentials.password,
    );
  }

  // _convertResultRowToMap 已移至 DatabaseBackupService
  // _formatDateTime 已移至 DatabaseBackupService

  // _getTableNames 已移至 DatabaseSchemaService
  Future<List<String>> _getTableNames() async {
    _syncMysqlConnectionFromService();
    _updateServiceConnections();
    return await _schemaService.getTableNames();
  }

  // _parseDateTime 已移至 DatabaseBackupService

  /// 获取数据库文件路径
  String get databasePath => _databasePath ?? _sqliteDbPath ?? '';

  


}

class _MySQLConnectionInfo {
  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  const _MySQLConnectionInfo({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'host': host,
      'port': port,
      'database': database,
      'username': username,
      'password': password,
    };
  }
}

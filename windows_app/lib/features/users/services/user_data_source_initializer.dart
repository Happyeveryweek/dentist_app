import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../data_sources/user_data_source.dart';
import '../../../utils/mysql_sync_connection_helper.dart';

/// 用户数据源初始化服务
/// 负责数据源初始化、连接管理和数据源切换
class UserDataSourceInitializer {
  // 数据库实例
  Database? _database;
  MySqlConnection? _mysqlConnection;

  // 数据源类型
  String _dataSourceType = 'sqlite';

  // 模块数据源配置
  Map<String, String>? _moduleDataSources;

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 数据源具体实现
  SqliteUserDataSource? _sqliteDataSource;
  MySqlUserDataSource? _mysqlDataSource;

  UserDataSourceInitializer({
    Database? database,
    MySqlConnection? mysqlConnection,
    String dataSourceType = 'sqlite',
    Map<String, String>? moduleDataSources,
    dynamic databaseProvider,
  }) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dataSourceType = dataSourceType;
    _moduleDataSources = moduleDataSources;
    _databaseProvider = databaseProvider;
  }

  // 获取有效的数据源类型（考虑模块化配置）
  String get effectiveDataSourceType {
    if (_moduleDataSources != null && _moduleDataSources!.containsKey('users')) {
      return _moduleDataSources!['users']!;
    }
    return _dataSourceType;
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _database = database;
    _sqliteDataSource = SqliteUserDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlConnection = connection;
    _mysqlDataSource = MySqlUserDataSource.withConnectionGetter(
      () async {
        final conn = await _currentMysqlConnection;
        return conn;
      },
      reconnectCallback: () async {
        if (_databaseProvider != null) {
          try {
            await _databaseProvider.initializeMySQL();
            print('✅ UserDataSourceInitializer: MySQL重连成功');
          } catch (e) {
            print('❌ UserDataSourceInitializer: MySQL重连失败: $e');
          }
        }
      },
    );
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  UserDataSource get currentDataSource {
    final effectiveType = effectiveDataSourceType;
    if (effectiveType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL用户数据源未初始化 - 模块配置要求使用MySQL但数据源未设置');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite用户数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  // 获取最新的MySQL连接（防止连接过期）
  MySqlConnection? get _currentMysqlConnection {
    if (effectiveDataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }

    // 每次都从DatabaseProvider获取最新连接
    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      if (latestConnection != null) {
        _mysqlConnection = latestConnection;
        return latestConnection;
      }
    } catch (e) {
      print('获取最新MySQL连接失败: $e');
    }

    return _mysqlConnection;
  }

  /// 获取用于同步的MySQL连接
  ///
  /// 说明：
  /// - 此连接专门用于SQLite→MySQL数据同步
  /// - 无论当前模块使用什么数据源，都能获取到MySQL连接
  /// - 自动从DatabaseProvider获取最新连接，确保连接有效
  ///
  /// 使用场景：
  /// - 当模块配置为SQLite时，需要同步数据到MySQL
  /// - 不能使用_currentMysqlConnection（它在SQLite模式下不会获取连接）
  MySqlConnection? get syncMysqlConnection {
    return MySqlSyncConnectionHelper.getSyncConnection(
      databaseProvider: _databaseProvider,
      cachedConnection: _mysqlConnection,
      onConnectionUpdate: (newConnection) {
        _mysqlConnection = newConnection;
      },
    );
  }

  // 测试MySQL连接是否有效
  Future<bool> testMySqlConnection() async {
    if (_currentMysqlConnection == null) return false;

    try {
      await _currentMysqlConnection!.query('SELECT 1').timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('连接测试超时', const Duration(seconds: 10));
        },
      );
      return true;
    } catch (e) {
      print('MySQL连接测试失败: $e');
      _mysqlConnection = null;
      return false;
    }
  }

  // 智能初始化（支持模块化配置）
  Future<void> initializeFromDatabase(
    dynamic dbProvider, {
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
  }) async {
    try {
      print('🔧 UserDataSourceInitializer.initializeFromDatabase 开始初始化');
      print('🔧 UserDataSourceInitializer - 数据源模式: $dataSourceMode');
      print('🔧 UserDataSourceInitializer - 模块配置: $moduleDataSources');
      print('🔧 UserDataSourceInitializer - 全局数据源类型: ${dbProvider?.dataSourceType}');

      // 保存数据库提供者引用
      _databaseProvider = dbProvider;

      // 保存模块配置
      _moduleDataSources = moduleDataSources;

      // 确定要使用的数据源类型
      String dbType = 'sqlite';

      // 如果是模块化模式且有用户模块配置，优先使用模块配置
      if (dataSourceMode == 'modular' &&
          moduleDataSources != null &&
          moduleDataSources.containsKey('users')) {
        dbType = moduleDataSources['users']!;
        print('🔧 UserDataSourceInitializer使用模块化配置: users -> $dbType');
      } else {
        // 否则使用全局配置
        dbType = dbProvider?.dataSourceType ?? 'sqlite';
        print('🔧 UserDataSourceInitializer使用全局配置: $dbType');
      }

      // 更新数据源类型
      _dataSourceType = dbType;

      // 一次性初始化正确的数据源
      if (dbType == 'sqlite') {
        final database = dbProvider?.database;
        if (database != null) {
          _database = database;
          setSqliteDataSource(database);
        } else {
          throw Exception('SQLite数据库连接不可用');
        }
      } else if (dbType == 'mysql') {
        final mysqlConnection = dbProvider?.mysqlConnection;
        if (mysqlConnection != null) {
          _mysqlConnection = mysqlConnection;
          setMySqlDataSource(mysqlConnection);

          // 测试MySQL连接
          final isConnected = await testMySqlConnection();
          if (isConnected) {
            print('✅ UserDataSourceInitializer MySQL连接测试成功');
          } else {
            print('⚠️ UserDataSourceInitializer MySQL连接测试失败，但继续使用');
          }
        } else {
          throw Exception('MySQL数据库连接不可用');
        }
      }
    } catch (e) {
      print('❌ UserDataSourceInitializer初始化失败: $e');
      rethrow;
    }
  }

  // 模块数据源配置更新（向后兼容）
  void updateModuleDataSources(Map<String, String>? moduleDataSources) {
    _moduleDataSources = moduleDataSources;
    print('UserDataSourceInitializer模块数据源配置已更新: $moduleDataSources');

    // 如果有模块配置且当前是模块化模式，重新初始化数据源
    if (moduleDataSources != null &&
        moduleDataSources.containsKey('users') &&
        _databaseProvider != null) {

      final newDataSourceType = moduleDataSources['users']!;
      if (newDataSourceType != _dataSourceType) {
        print('用户模块数据源类型变更: $_dataSourceType -> $newDataSourceType');

        // 重新初始化数据源
        initializeFromDatabase(
          _databaseProvider,
          moduleDataSources: moduleDataSources,
          dataSourceMode: 'modular',
        );
      }
    }
  }

  // Getters
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  String get dataSourceType => _dataSourceType;
  Map<String, String>? get moduleDataSources => _moduleDataSources;
  dynamic get databaseProvider => _databaseProvider;
}

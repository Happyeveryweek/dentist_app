import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../data_sources/appointment_data_source.dart';

/// 预约数据库连接管理 mixin
/// 提供数据库连接管理和数据源切换功能
mixin AppointmentDatabaseMixin {
  // 数据库连接
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _dataSourceType = 'sqlite';

  // 数据库提供者引用（用于获取最新连接）
  dynamic _databaseProvider;

  // 数据源具体实现
  SqliteAppointmentDataSource? _sqliteDataSource;
  MySqlAppointmentDataSource? _mysqlDataSource;

  // 初始化标志
  bool _isInitializedFlag = false;

  // Getters
  bool get initialized => _database != null || _mysqlConnection != null;
  String get dataSourceType => _dataSourceType;

  // 检查数据库是否已初始化
  bool get isInitialized {
    if (_dataSourceType == 'mysql') {
      return _mysqlConnection != null;
    } else {
      return _database != null;
    }
  }

  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqliteAppointmentDataSource(database);
  }

  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlAppointmentDataSource.withConnectionGetter(
      () => currentMysqlConnection,
    );
  }

  // 获取当前数据源（必须可用，否则抛出异常）
  AppointmentDataSource get currentDataSource {
    if (_dataSourceType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL预约数据源未初始化');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite预约数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  // 获取最新的MySQL连接（防止连接过期）
  MySqlConnection? get currentMysqlConnection {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
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

  // 获取数据库连接（供子类使用）
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;
  dynamic get databaseProvider => _databaseProvider;
  bool get isInitializedFlag => _isInitializedFlag;

  // 设置数据库连接（供子类使用）
  set database(Database? value) => _database = value;
  set mysqlConnection(MySqlConnection? value) => _mysqlConnection = value;
  set databaseProvider(dynamic value) => _databaseProvider = value;
  set isInitializedFlag(bool value) => _isInitializedFlag = value;
  set dataSourceType(String value) => _dataSourceType = value;
}

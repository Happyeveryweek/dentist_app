import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import 'user_connection_state_service.dart';

/// 用户连接检查服务
class UserConnectionHealthService {
  final UserConnectionStateService _stateService;
  MySqlConnection? _mysqlConnection;
  Database? _database;
  String _dataSourceType = 'sqlite';
  dynamic _databaseProvider;

  UserConnectionHealthService({
    required UserConnectionStateService stateService,
    MySqlConnection? mysqlConnection,
    Database? database,
    String dataSourceType = 'sqlite',
    dynamic databaseProvider,
  })  : _stateService = stateService,
        _mysqlConnection = mysqlConnection,
        _database = database,
        _dataSourceType = dataSourceType,
        _databaseProvider = databaseProvider;

  String get dataSourceType => _dataSourceType;

  void setConnections({
    MySqlConnection? mysqlConnection,
    Database? database,
    String? dataSourceType,
    dynamic databaseProvider,
  }) {
    if (mysqlConnection != null) _mysqlConnection = mysqlConnection;
    if (database != null) _database = database;
    if (dataSourceType != null) _dataSourceType = dataSourceType;
    if (databaseProvider != null) _databaseProvider = databaseProvider;
  }

  MySqlConnection? getCurrentMysqlConnection() {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
      return _mysqlConnection;
    }

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

  Database? getSqliteDatabase() {
    return _database;
  }

  bool isInitialized() {
    if (_dataSourceType == 'mysql') {
      return getCurrentMysqlConnection() != null;
    } else {
      return _database != null;
    }
  }

  Future<bool> testMySqlConnection() async {
    if (_dataSourceType != 'mysql') return true;

    final conn = getCurrentMysqlConnection();
    if (conn == null) {
      _stateService.markDisconnected('MySQL连接为null');
      return false;
    }

    try {
      await conn.query('SELECT 1');
      _stateService.markConnected();
      return true;
    } catch (e) {
      _stateService.markDisconnected('MySQL连接测试失败: $e');
      return false;
    }
  }

  Future<bool> testSQLiteConnection() async {
    if (_dataSourceType != 'sqlite') return true;

    final db = _database;
    if (db == null) {
      _stateService.markDisconnected('SQLite数据库为null');
      return false;
    }

    try {
      if (!db.isOpen) {
        _stateService.markDisconnected('SQLite数据库连接已关闭');
        return false;
      }
      _stateService.markConnected();
      return true;
    } catch (e) {
      _stateService.markDisconnected('SQLite连接测试失败: $e');
      return false;
    }
  }

  Future<bool> ensureConnection() async {
    if (_dataSourceType == 'mysql') {
      return await testMySqlConnection();
    } else {
      return await testSQLiteConnection();
    }
  }
}

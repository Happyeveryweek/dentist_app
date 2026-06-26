import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../../../data_sources/patient_data_source.dart';
import '../../../utils/app_logger.dart';

/// 患者数据源初始化服务
/// 职责：管理患者数据源的初始化、数据源类型切换、连接管理
class PatientInitializationService {
  SqlitePatientDataSource? _sqliteDataSource;
  MySqlPatientDataSource? _mysqlDataSource;
  String _dataSourceType = 'sqlite';
  dynamic _databaseProvider;

  /// 获取当前数据源类型
  String get dataSourceType => _dataSourceType;

  /// 设置数据源类型
  void setDataSourceType(String dataSourceType) {
    _dataSourceType = dataSourceType;
  }

  /// 设置 SQLite 数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqlitePatientDataSource(database);
  }

  /// 设置 MySQL 数据源
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlDataSource = MySqlPatientDataSource.withConnectionGetter(
      () => _currentMysqlConnection,
    );
  }

  /// 获取当前数据源（必须可用，否则抛出异常）
  PatientDataSource get currentDataSource {
    if (_dataSourceType == 'mysql') {
      final dataSource = _mysqlDataSource;
      if (dataSource == null) {
        throw Exception('MySQL患者数据源未初始化');
      }
      return dataSource;
    } else {
      final dataSource = _sqliteDataSource;
      if (dataSource == null) {
        throw Exception('SQLite患者数据源未初始化');
      }
      return dataSource;
    }
  }

  /// 获取最新的 MySQL 连接（防止连接过期）
  MySqlConnection? get _currentMysqlConnection {
    if (_dataSourceType != 'mysql' || _databaseProvider == null) {
      return null;
    }

    try {
      final latestConnection = _databaseProvider.mysqlConnection;
      return latestConnection;
    } catch (e) {
      AppLogger.info('获取最新MySQL连接失败: $e');
      return null;
    }
  }

  /// 统一的数据库初始化方法
  Future<bool> initializeFromDatabase(dynamic dbProvider) async {
    try {
      AppLogger.info('PatientInitializationService 开始初始化...');

      _databaseProvider = dbProvider;
      setDataSourceType(dbProvider.dbType);

      if (dbProvider.dbType == 'sqlite') {
        final database = await dbProvider.sqliteDatabase;
        if (database != null) {
          setSqliteDataSource(database);
          AppLogger.info('✅ PatientInitializationService SQLite数据源设置成功');
          return true;
        } else {
          throw Exception('SQLite数据库为null，无法创建数据源');
        }
      } else if (dbProvider.dbType == 'mysql') {
        final mysqlConnection = dbProvider.mysqlConnection;
        if (mysqlConnection != null) {
          setMySqlDataSource(mysqlConnection);
          AppLogger.info('✅ PatientInitializationService MySQL数据源设置成功');
          return true;
        } else {
          throw Exception('MySQL连接为null，无法创建数据源');
        }
      }

      return false;
    } catch (e) {
      AppLogger.info('PatientInitializationService 初始化失败: $e');
      return false;
    }
  }

  /// 获取 SQLite 数据源
  SqlitePatientDataSource? get sqliteDataSource => _sqliteDataSource;

  /// 获取 MySQL 数据源
  MySqlPatientDataSource? get mysqlDataSource => _mysqlDataSource;
}

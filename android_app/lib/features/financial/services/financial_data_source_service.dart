import '../../../data_sources/financial_data_source.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../utils/app_logger.dart';

/// 财务数据源管理服务
/// 职责：管理财务数据源的初始化、数据源类型切换、连接管理
class FinancialDataSourceService {
  SqliteFinancialDataSource? _sqliteDataSource;
  MySqlFinancialDataSource? _mysqlDataSource;
  String _dataSourceType = 'sqlite';
  MySqlConnection? _mysqlConnection;
  MySqlConnection? Function()? _mysqlConnectionGetter;

  /// 获取当前数据源类型
  String get dataSourceType => _dataSourceType;

  /// 设置数据源类型
  void setDataSourceType(String dataSourceType) {
    _dataSourceType = dataSourceType;
  }

  /// 设置 SQLite 数据源
  void setSqliteDataSource(Database database) {
    _sqliteDataSource = SqliteFinancialDataSource(database);
  }

  /// 设置 MySQL 数据源
  void setMySqlDataSource(MySqlConnection connection) {
    _mysqlConnection = connection;
    _mysqlDataSource = MySqlFinancialDataSource.withConnectionGetter(
      () => currentMysqlConnection,
    );
  }

  /// 设置 MySQL 连接获取器，避免后台恢复后继续使用旧 socket
  void setMySqlConnectionGetter(MySqlConnection? Function() getter) {
    _mysqlConnectionGetter = getter;
    _mysqlDataSource = MySqlFinancialDataSource.withConnectionGetter(
      () => currentMysqlConnection,
    );
  }

  /// 获取当前 MySQL 连接
  MySqlConnection? get currentMysqlConnection {
    final latest = _mysqlConnectionGetter?.call();
    if (latest != null) {
      _mysqlConnection = latest;
      return latest;
    }
    return _mysqlConnection;
  }

  /// 获取当前数据源（必须可用，否则抛出异常）
  FinancialDataSource get currentDataSource {
    if (_dataSourceType == 'mysql') {
      if (_mysqlDataSource == null) {
        throw Exception('MySQL财务数据源未初始化');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite财务数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }

  /// 获取 SQLite 数据源
  SqliteFinancialDataSource? get sqliteDataSource => _sqliteDataSource;

  /// 获取 MySQL 数据源
  MySqlFinancialDataSource? get mysqlDataSource => _mysqlDataSource;

  /// 确保财务记录表存在（内部方法，不需要包装）
  Future<void> ensureFinancialRecordsTableExists({
    required String dataSourceType,
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
  }) async {
    try {
      if (dataSourceType == 'sqlite') {
        final db = sqliteDatabase;
        if (db == null) return;

        // 创建财务记录表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS financial_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            total_quantity INTEGER DEFAULT 0,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients(id)
          )
        ''');

        // 创建财务项目明细表
        await db.execute('''
          CREATE TABLE IF NOT EXISTS financial_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            financial_record_id INTEGER NOT NULL,
            item_name TEXT NOT NULL,
            payment_method TEXT,
            item_price REAL NOT NULL,
            processing_fee REAL DEFAULT 0.0,
            quantity INTEGER DEFAULT 1,
            total_price REAL NOT NULL,
            charge_date TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (financial_record_id) REFERENCES financial_records(id)
          )
        ''');
      } else if (dataSourceType == 'mysql') {
        final conn = mysqlConnection ?? currentMysqlConnection;
        if (conn == null) return;

        // 创建财务记录表
        await conn.query('''
          CREATE TABLE IF NOT EXISTS financial_records (
            id INT AUTO_INCREMENT PRIMARY KEY,
            patient_id INT NOT NULL,
            total_quantity INT DEFAULT 0,
            notes TEXT,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients(id)
          )
        ''');

        // 创建财务项目明细表
        await conn.query('''
          CREATE TABLE IF NOT EXISTS financial_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            financial_record_id INT NOT NULL,
            item_name VARCHAR(255) NOT NULL,
            payment_method VARCHAR(20) DEFAULT NULL,
            item_price DECIMAL(10,2) NOT NULL,
            processing_fee DECIMAL(10,2) DEFAULT 0.0,
            quantity INT DEFAULT 1,
            total_price DECIMAL(10,2) NOT NULL,
            charge_date DATETIME NOT NULL,
            created_at DATETIME NOT NULL,
            updated_at DATETIME NOT NULL,
            FOREIGN KEY (financial_record_id) REFERENCES financial_records(id)
          )
        ''');
      }
    } catch (e) {
      AppLogger.info('创建财务记录表失败: $e');
      rethrow;
    }
  }
}

import '../utils/config_utils.dart';

abstract final class DatabaseDefaults {
  static const sqliteFileName = 'dental_clinic.db';
  static const mysqlHost = 'localhost';
  static const mysqlPort = '3306';
  static const mysqlDatabase = 'dental_clinic';
  static const mysqlUsername = 'root';
}

// 数据库配置模型
class DatabaseConfig {
  String dbType; // 'sqlite' 或 'mysql'
  SqliteConfig sqlite;
  MySqlConfig mysql;

  // 构造函数
  DatabaseConfig({
    this.dbType = 'sqlite',
    SqliteConfig? sqlite,
    MySqlConfig? mysql,
  }) : sqlite = sqlite ?? SqliteConfig(),
       mysql = mysql ?? MySqlConfig();

  // 从JSON创建配置
  factory DatabaseConfig.fromJson(Map<String, dynamic> json) {
    return DatabaseConfig(
      dbType: json['db_type'] ?? 'sqlite',
      sqlite:
          json['sqlite'] != null ? SqliteConfig.fromJson(json['sqlite']) : null,
      mysql: json['mysql'] != null ? MySqlConfig.fromJson(json['mysql']) : null,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'db_type': dbType,
      'sqlite': sqlite.toJson(),
      'mysql': mysql.toJson(),
    };
  }

  // 字符串表示
  @override
  String toString() {
    return 'DatabaseConfig(dbType: $dbType, sqlite: ${sqlite.path}, mysql: ${mysql.host}:${mysql.port}/${mysql.database})';
  }

  // 保存配置到加密文件
  Future<void> saveConfig() async {
    await ConfigUtils.saveConfig(this);
  }

  // 从加密文件加载配置
  static Future<DatabaseConfig> loadConfig() async {
    return await ConfigUtils.loadConfig();
  }
}

// SQLite配置
class SqliteConfig {
  String path;

  SqliteConfig({this.path = DatabaseDefaults.sqliteFileName});

  factory SqliteConfig.fromJson(Map<String, dynamic> json) {
    return SqliteConfig(path: json['path'] ?? DatabaseDefaults.sqliteFileName);
  }

  Map<String, dynamic> toJson() {
    return {'path': path};
  }
}

// MySQL配置
class MySqlConfig {
  String host;
  String port;
  String database;
  String username;
  String password;

  MySqlConfig({
    this.host = DatabaseDefaults.mysqlHost,
    this.port = DatabaseDefaults.mysqlPort,
    this.database = DatabaseDefaults.mysqlDatabase,
    this.username = DatabaseDefaults.mysqlUsername,
    this.password = '',
  });

  factory MySqlConfig.fromJson(Map<String, dynamic> json) {
    return MySqlConfig(
      host: json['host'] ?? DatabaseDefaults.mysqlHost,
      port: json['port'] ?? DatabaseDefaults.mysqlPort,
      database: json['database'] ?? DatabaseDefaults.mysqlDatabase,
      username: json['username'] ?? DatabaseDefaults.mysqlUsername,
      password: json['password'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'database': database,
      'username': username,
      'password': password,
    };
  }
}

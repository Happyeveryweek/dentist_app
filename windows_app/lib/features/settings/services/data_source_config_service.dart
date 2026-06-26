import '../../../providers/settings_provider.dart';
import '../../../providers/database_provider.dart';

/// 数据源配置服务
/// 负责数据源配置的保存和加载逻辑
class DataSourceConfigService {
  final SettingsProvider settingsProvider;
  final DatabaseProvider databaseProvider;

  DataSourceConfigService({
    required this.settingsProvider,
    required this.databaseProvider,
  });

  /// 保存全局数据源类型
  Future<void> saveDataSourceType(String dataSourceType) async {
    await settingsProvider.setDataSourceType(dataSourceType);
  }

  /// 保存SQLite数据库路径
  Future<void> saveSqliteDbPath(String sqliteDbPath) async {
    await settingsProvider.setSqliteDbPath(sqliteDbPath);
  }

  /// 保存MySQL连接参数
  Future<void> saveMySQLSettings({
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) async {
    await settingsProvider.setMySQLHost(host);
    await settingsProvider.setMySQLPort(port);
    await settingsProvider.setMySQLDatabase(database);
    await settingsProvider.setMySQLUsername(username);
    await settingsProvider.setMySQLPassword(password);
  }

  /// 保存数据源模式（global 或 modular）
  Future<void> saveDataSourceMode(String dataSourceMode) async {
    await settingsProvider.setDataSourceMode(dataSourceMode);
  }

  /// 保存所有模块数据源配置
  Future<void> saveAllModuleDataSources(
      Map<String, String> moduleDataSources) async {
    await settingsProvider.setAllModuleDataSources(moduleDataSources);
  }

  /// 保存备份数据源设置
  Future<void> saveBackupDataSource(String backupDataSource) async {
    await settingsProvider.setBackupDataSource(backupDataSource);
  }

  /// 应用SQLite数据源设置
  Future<void> applySqliteDataSource({
    required String dataSourceType,
    String? customSqlitePath,
  }) async {
    await databaseProvider.setDataSourceType(
      dataSourceType,
      customSqlitePath:
          customSqlitePath?.isNotEmpty == true ? customSqlitePath : null,
    );
  }

  /// 应用MySQL数据源设置
  Future<void> applyMySQLDataSource({
    required String dataSourceType,
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) async {
    final mysqlSettings = {
      'host': host,
      'port': int.tryParse(port) ?? 3306,
      'database': database,
      'username': username,
      'password': password,
    };

    await databaseProvider.setDataSourceType(
      dataSourceType,
      mysqlSettings: mysqlSettings,
    );
  }

  /// 保存并应用SQLite完整配置
  Future<void> saveAndApplySqliteConfig({
    required String dataSourceType,
    required String sqliteDbPath,
  }) async {
    // 保存SQLite数据库路径
    await saveSqliteDbPath(sqliteDbPath);

    // 如果当前选择的是SQLite，则应用设置
    if (dataSourceType == 'sqlite') {
      await applySqliteDataSource(
        dataSourceType: dataSourceType,
        customSqlitePath: sqliteDbPath.isNotEmpty ? sqliteDbPath : null,
      );
    }
  }

  /// 保存并应用MySQL完整配置
  Future<void> saveAndApplyMySQLConfig({
    required String dataSourceType,
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) async {
    // 保存MySQL设置
    await saveMySQLSettings(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );

    // 如果当前选择的是MySQL，则应用设置
    if (dataSourceType == 'mysql') {
      await applyMySQLDataSource(
        dataSourceType: dataSourceType,
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );
    }
  }

  /// 保存数据源类型切换完整配置
  Future<void> saveDataSourceTypeConfig({
    required String dataSourceMode,
    required String selectedDataSource,
    required String sqliteDbPath,
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
    required Map<String, String> moduleDataSources,
  }) async {
    // 保存数据源模式
    await saveDataSourceMode(dataSourceMode);

    // 保存全局数据源类型
    await saveDataSourceType(selectedDataSource);

    // 保存SQLite数据库路径
    if (selectedDataSource == 'sqlite') {
      await saveSqliteDbPath(sqliteDbPath);
    }

    // 保存MySQL设置
    if (selectedDataSource == 'mysql') {
      await saveMySQLSettings(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );
    }

    // 保存模块数据源配置
    await saveAllModuleDataSources(moduleDataSources);

    // 应用数据源设置
    if (selectedDataSource == 'sqlite') {
      await applySqliteDataSource(
        dataSourceType: selectedDataSource,
        customSqlitePath: sqliteDbPath.isNotEmpty ? sqliteDbPath : null,
      );
    } else if (selectedDataSource == 'mysql') {
      await applyMySQLDataSource(
        dataSourceType: selectedDataSource,
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );
    }
  }

  /// 保存备份数据源完整配置
  Future<void> saveBackupDataSourceConfig({
    required String selectedDataSource,
    required String sqliteDbPath,
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
    required String backupDataSource,
  }) async {
    // 保存全局数据源类型
    await saveDataSourceType(selectedDataSource);

    // 保存SQLite数据库路径
    if (selectedDataSource == 'sqlite') {
      await saveSqliteDbPath(sqliteDbPath);
    }

    // 保存MySQL设置
    if (selectedDataSource == 'mysql') {
      await saveMySQLSettings(
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );
    }

    // 保存备份数据源设置
    await saveBackupDataSource(backupDataSource);

    // 应用数据源设置
    if (selectedDataSource == 'sqlite') {
      await applySqliteDataSource(
        dataSourceType: selectedDataSource,
        customSqlitePath: sqliteDbPath.isNotEmpty ? sqliteDbPath : null,
      );
    } else if (selectedDataSource == 'mysql') {
      await applyMySQLDataSource(
        dataSourceType: selectedDataSource,
        host: host,
        port: port,
        database: database,
        username: username,
        password: password,
      );
    }
  }
}

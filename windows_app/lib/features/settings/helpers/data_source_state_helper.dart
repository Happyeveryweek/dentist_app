/// 数据源状态管理 Helper
/// 负责数据源配置的原始设置备份和恢复逻辑
class DataSourceStateHelper {
  /// 备份模块数据源配置
  static Map<String, String> backupModuleDataSources(Map<String, String> current) {
    return Map<String, String>.from(current);
  }

  /// 恢复模块数据源配置
  static Map<String, String> restoreModuleDataSources(Map<String, String> backup) {
    return Map<String, String>.from(backup);
  }

  /// 备份数据源类型
  static String backupDataSourceType(String current) {
    return current;
  }

  /// 恢复数据源类型
  static String restoreDataSourceType(String backup) {
    return backup;
  }

  /// 备份数据源模式
  static String backupDataSourceMode(String current) {
    return current;
  }

  /// 恢复数据源模式
  static String restoreDataSourceMode(String backup) {
    return backup;
  }

  /// 备份SQLite数据库路径
  static String backupSqliteDbPath(String current) {
    return current;
  }

  /// 恢复SQLite数据库路径
  static String restoreSqliteDbPath(String backup) {
    return backup;
  }

  /// 备份备份数据源设置
  static String backupBackupDataSource(String current) {
    return current;
  }

  /// 恢复备份数据源设置
  static String restoreBackupDataSource(String backup) {
    return backup;
  }

  /// 创建完整的状态备份
  static DataSourceStateBackup createBackup({
    required Map<String, String> moduleDataSources,
    required String dataSource,
    required String dataSourceMode,
    required String backupDataSource,
    required String sqliteDbPath,
  }) {
    return DataSourceStateBackup(
      moduleDataSources: backupModuleDataSources(moduleDataSources),
      dataSource: backupDataSourceType(dataSource),
      dataSourceMode: backupDataSourceMode(dataSourceMode),
      backupDataSource: backupBackupDataSource(backupDataSource),
      sqliteDbPath: backupSqliteDbPath(sqliteDbPath),
    );
  }

  /// 恢复完整的状态
  static DataSourceStateRestore restoreFromBackup(DataSourceStateBackup backup) {
    return DataSourceStateRestore(
      moduleDataSources: restoreModuleDataSources(backup.moduleDataSources),
      dataSource: restoreDataSourceType(backup.dataSource),
      dataSourceMode: restoreDataSourceMode(backup.dataSourceMode),
      backupDataSource: restoreBackupDataSource(backup.backupDataSource),
      sqliteDbPath: restoreSqliteDbPath(backup.sqliteDbPath),
    );
  }
}

/// 数据源状态备份
class DataSourceStateBackup {
  final Map<String, String> moduleDataSources;
  final String dataSource;
  final String dataSourceMode;
  final String backupDataSource;
  final String sqliteDbPath;

  DataSourceStateBackup({
    required this.moduleDataSources,
    required this.dataSource,
    required this.dataSourceMode,
    required this.backupDataSource,
    required this.sqliteDbPath,
  });
}

/// 数据源状态恢复
class DataSourceStateRestore {
  final Map<String, String> moduleDataSources;
  final String dataSource;
  final String dataSourceMode;
  final String backupDataSource;
  final String sqliteDbPath;

  DataSourceStateRestore({
    required this.moduleDataSources,
    required this.dataSource,
    required this.dataSourceMode,
    required this.backupDataSource,
    required this.sqliteDbPath,
  });
}

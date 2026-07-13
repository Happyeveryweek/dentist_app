import 'dart:io';
import 'package:mysql1/mysql1.dart';
import 'package:dentist_app_windows/utils/datetime_formatter.dart';
import 'package:path/path.dart' as path;
import '../../../utils/log_manager.dart';

/// 数据源管理服务
/// 负责数据源的配置和管理，包括SQLite和MySQL
class DataSourceManagementService {
  static const Map<String, String> _defaultModuleDataSources = {
    'patients': 'sqlite',
    'appointments': 'sqlite',
    'financial': 'sqlite',
    'materials': 'sqlite',
    'purchase': 'sqlite',
    'users': 'sqlite',
    'medical': 'sqlite',
  };

  String _dataSourceType = 'sqlite';
  String _dataSourceMode = 'global';
  String _sqliteDbPath = '';
  String _customSqliteDbPath = '';
  String _mysqlHost = '';
  String _mysqlPort = '3306';
  String _mysqlDatabase = '';
  String _mysqlUsername = '';
  String _mysqlPassword = '';
  Map<String, dynamic>? _mysqlSettings;
  Map<String, dynamic>? _lastMySQLSettings;
  String _backupDataSource = 'sqlite';
  Map<String, String> _moduleDataSources =
      Map<String, String>.from(_defaultModuleDataSources);

  String get dataSourceType => _dataSourceType;
  String get dataSourceMode => _dataSourceMode;
  String get sqliteDbPath => _sqliteDbPath;
  String get customSqliteDbPath => _customSqliteDbPath;
  String get mysqlHost => _mysqlHost;
  String get mysqlPort => _mysqlPort;
  String get mysqlDatabase => _mysqlDatabase;
  String get mysqlUsername => _mysqlUsername;
  String get mysqlPassword => _mysqlPassword;
  Map<String, dynamic>? get mysqlSettings => _mysqlSettings;
  Map<String, dynamic>? get lastMySQLSettings => _lastMySQLSettings;
  String get backupDataSource => _backupDataSource;
  Map<String, String> get moduleDataSources =>
      Map<String, String>.from(_moduleDataSources);
  Map<String, String> get defaultModuleDataSources =>
      Map<String, String>.from(_defaultModuleDataSources);

  Map<String, String> _normalizeModuleDataSources(
      Map<String, String> moduleDataSources) {
    final normalized = Map<String, String>.from(_defaultModuleDataSources);
    normalized.addAll(moduleDataSources);
    return normalized;
  }

  Map<String, dynamic> _buildMySQLSettings({
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) {
    return {
      'host': host,
      'port': int.tryParse(port) ?? 3306,
      'database': database,
      'username': username,
      'password': password,
    };
  }

  void _applyMySQLSettings(Map<String, dynamic> mysqlSettings) {
    _mysqlHost = mysqlSettings['host']?.toString() ?? '';
    _mysqlPort = mysqlSettings['port']?.toString() ?? '3306';
    _mysqlDatabase = mysqlSettings['database']?.toString() ?? '';
    _mysqlUsername = mysqlSettings['username']?.toString() ?? '';
    _mysqlPassword = mysqlSettings['password']?.toString() ?? '';
    _mysqlSettings = Map<String, dynamic>.from(mysqlSettings);
  }

  /// 更新数据源类型
  void updateDataSourceType(String type) {
    _dataSourceType = type;
  }

  /// 更新数据源模式
  void updateDataSourceMode(String mode) {
    _dataSourceMode = mode;
  }

  /// 更新SQLite路径
  void updateSqlitePaths({
    required String sqliteDbPath,
    String? customSqliteDbPath,
  }) {
    _sqliteDbPath = sqliteDbPath;
    if (customSqliteDbPath != null) {
      _customSqliteDbPath = customSqliteDbPath;
    }
  }

  /// 更新MySQL连接参数
  void updateMySQLConnectionParams({
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
    _mysqlSettings = _buildMySQLSettings(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
  }

  /// 设置数据源模式
  void setDataSourceMode(String mode) {
    _dataSourceMode = mode;
  }

  /// 设置数据源类型
  void setDataSourceType(
    String type, {
    Map<String, dynamic>? mysqlSettings,
    String? customSqlitePath,
  }) {
    _dataSourceType = type;

    if (type == 'sqlite') {
      if (customSqlitePath != null && customSqlitePath.isNotEmpty) {
        _customSqliteDbPath = customSqlitePath;
        _sqliteDbPath = customSqlitePath;
      }
      return;
    }

    if (type == 'mysql' && mysqlSettings != null) {
      _applyMySQLSettings(mysqlSettings);
    }
  }

  /// 保存MySQL设置到映射中
  void saveMySQLSettings(Map<String, dynamic> mysqlSettings) {
    _applyMySQLSettings(mysqlSettings);
  }

  /// 获取完整的MySQL设置
  Map<String, dynamic> getCompleteMySQLSettings() {
    return _buildMySQLSettings(
      host: _mysqlHost,
      port: _mysqlPort,
      database: _mysqlDatabase,
      username: _mysqlUsername,
      password: _mysqlPassword,
    );
  }

  /// 验证MySQL设置是否完整
  bool isMySQLSettingsComplete() {
    return _mysqlHost.isNotEmpty &&
        _mysqlPort.isNotEmpty &&
        _mysqlDatabase.isNotEmpty &&
        _mysqlUsername.isNotEmpty;
  }

  /// 设置备份数据源
  void setBackupDataSource(String dataSource) {
    _backupDataSource = dataSource;
  }

  /// 设置模块数据源
  void setModuleDataSource(String module, String dataSource) {
    _moduleDataSources = _normalizeModuleDataSources({
      ..._moduleDataSources,
      module: dataSource,
    });
  }

  /// 设置所有模块数据源
  void setAllModuleDataSources(Map<String, String> moduleDataSources) {
    _moduleDataSources = _normalizeModuleDataSources(moduleDataSources);
  }

  /// 测试MySQL连接
  Future<bool> testMySQLConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    try {
      // 创建临时连接进行测试
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
    } catch (e) {
      LogManager.e('DataSourceManagementService', 'MySQL连接测试失败', error: e);
      return false;
    }
  }

  /// 数据库导入功能
  Future<void> importDatabase(
    String importFilePath, {
    required Function(String, String, bool,
            {String? errorMessage, String? preRestoreBackupPath})
        logRestoreOperation,
    required String Function(String) detectRestoreFileType,
    required Future<bool> Function(
            {required String filePath, required String targetDataSource})
        validateRestoreStrategy,
  }) async {
    try {
      // 验证文件存在
      final importFile = File(importFilePath);
      if (!await importFile.exists()) {
        throw Exception('导入文件不存在: $importFilePath');
      }

      // 验证导入策略
      final isValid = await validateRestoreStrategy(
        filePath: importFilePath,
        targetDataSource: _dataSourceType,
      );

      if (!isValid) {
        throw Exception('导入策略验证失败');
      }

      // 记录导入操作
      logRestoreOperation(
        '数据库导入',
        importFilePath,
        true,
        preRestoreBackupPath: null,
      );
    } catch (e) {
      LogManager.e('DataSourceManagementService', '导入数据库时出错', error: e);

      // 记录导入失败
      logRestoreOperation(
        '数据库导入',
        importFilePath,
        false,
        errorMessage: e.toString(),
        preRestoreBackupPath: null,
      );

      rethrow;
    }
  }

  /// 数据库导出功能
  Future<String> exportDatabase({
    required String backupPath,
    required Function(String) logBackupSuccess,
    required Function(String) logBackupFailure,
  }) async {
    try {
      if (_dataSourceType.isEmpty) {
        throw Exception('数据源类型未设置');
      }

      // 生成导出文件名
      final timestamp = DateTimeFormatter.nowDbString()
          .replaceAll(':', '-')
          .replaceAll(' ', '_');
      final exportFileName = 'export_${_dataSourceType}_$timestamp';

      String exportPath;
      if (_dataSourceType == 'mysql') {
        exportPath = '$exportFileName.sql';
      } else {
        exportPath = '$exportFileName.db';
      }

      // 这里可以添加实际的导出逻辑
      // 目前返回模拟路径
      final fullPath = path.join(backupPath, exportPath);

      // 记录导出操作
      logBackupSuccess(fullPath);

      return fullPath;
    } catch (e) {
      LogManager.e('DataSourceManagementService', '导出数据库时出错', error: e);

      // 记录导出失败
      logBackupFailure('导出失败: $e');

      rethrow;
    }
  }
}

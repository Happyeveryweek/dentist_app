import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import 'package:dentist_app_windows/features/settings/services/config_storage_service.dart';
import 'package:dentist_app_windows/features/settings/services/backup_management_service.dart';
import 'package:dentist_app_windows/features/settings/services/data_source_management_service.dart';
import 'package:dentist_app_windows/features/settings/services/database_structure_detection_service.dart';
import 'package:dentist_app_windows/features/settings/services/mysql_connection_service.dart';
import 'package:dentist_app_windows/models/database_structure_log.dart';
import 'package:dentist_app_windows/utils/datetime_formatter.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import '../utils/log_manager.dart';

// 扩展主题模式枚举（历史兼容，当前只保留标准主题）
enum ExtendedThemeMode { light }

class SettingsProvider extends ChangeNotifier {
  // ==================== Service 实例 ====================
  final ConfigStorageService _configStorageService = ConfigStorageService();
  final BackupManagementService _backupManagementService =
      BackupManagementService();
  final DataSourceManagementService _dataSourceManagementService =
      DataSourceManagementService();
  final DatabaseStructureDetectionService _databaseStructureDetectionService =
      DatabaseStructureDetectionService();
  final MySQLConnectionService _mysqlConnectionService =
      MySQLConnectionService();

  // ==================== 状态字段 ====================

  // Windows 主题变体
  WindowsThemeVariant _windowsThemeVariant = WindowsThemeVariant.medicalBlue;
  WindowsThemeVariant get windowsThemeVariant => _windowsThemeVariant;

  // 扩展主题设置（历史兼容，当前只保留标准主题）
  ExtendedThemeMode _extendedThemeMode = ExtendedThemeMode.light;
  ExtendedThemeMode get extendedThemeMode => _extendedThemeMode;

  // 兼容原有的ThemeMode
  ThemeMode _themeMode = ThemeMode.light;
  ThemeMode get themeMode => ThemeMode.light;

  // 字体大小设置
  double _fontSize = 1.0;
  double get fontSize => _fontSize;

  // 语言设置
  String _language = 'zh_CN';
  String get language => _language;

  // 应用名称设置
  String _appName = '牙科诊所管理系统';
  String get appName => _appName;

  // Windows特定设置
  Size _windowSize = const Size(1280, 720);
  Size get windowSize => _windowSize;

  // 数据库连接实例 - 用于结构检测
  Database? _database;
  MySqlConnection? _mysqlConnection;
  Database? get database => _database;
  MySqlConnection? get mysqlConnection => _mysqlConnection;

  // ==================== Getter 委托给 Service ====================

  bool get useFileStorage => _configStorageService.useFileStorage;
  String get backupPath => _backupManagementService.backupPath;
  String get backupPath2 => _backupManagementService.backupPath2;
  bool get autoBackup => _backupManagementService.autoBackup;
  int get backupInterval => _backupManagementService.backupInterval;
  DateTime? get lastBackupDate => _backupManagementService.lastBackupDate;
  String get dataSourceType => _dataSourceManagementService.dataSourceType;
  String get dataSourceMode => _dataSourceManagementService.dataSourceMode;
  String get sqliteDbPath => _dataSourceManagementService.sqliteDbPath;
  String get customSqliteDbPath =>
      _dataSourceManagementService.customSqliteDbPath;
  String get mysqlHost => _dataSourceManagementService.mysqlHost;
  String get mysqlPort => _dataSourceManagementService.mysqlPort;
  String get mysqlDatabase => _dataSourceManagementService.mysqlDatabase;
  String get mysqlUsername => _dataSourceManagementService.mysqlUsername;
  String get mysqlPassword => _dataSourceManagementService.mysqlPassword;
  Map<String, dynamic>? get mysqlSettings =>
      _dataSourceManagementService.mysqlSettings;
  Map<String, dynamic>? get lastMySQLSettings =>
      _dataSourceManagementService.lastMySQLSettings;
  String get backupDataSource => _dataSourceManagementService.backupDataSource;
  Map<String, String> get moduleDataSources =>
      _dataSourceManagementService.moduleDataSources;

  Map<String, String> _defaultModuleDataSources() {
    return _dataSourceManagementService.defaultModuleDataSources;
  }

  Map<String, String> _loadModuleDataSources(dynamic rawValue) {
    if (rawValue is Map) {
      return Map<String, String>.from(
        rawValue
            .map((key, value) => MapEntry(key.toString(), value.toString())),
      );
    }

    if (rawValue is String && rawValue.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValue);
        if (decoded is Map) {
          return Map<String, String>.from(
            decoded.map(
                (key, value) => MapEntry(key.toString(), value.toString())),
          );
        }
      } catch (e) {
        LogManager.e('SettingsProvider', '解析模块数据源配置出错', error: e);
      }
    }

    return _defaultModuleDataSources();
  }

  void _applyLoadedSettings(Map<String, dynamic> settings) {
    // 主题设置：历史配置迁移，任何旧值统一映射到标准主题
    _windowsThemeVariant = WindowsThemeVariantParsing.fromStorageValue(
      settings['windowsThemeVariant']?.toString(),
    );
    _extendedThemeMode = ExtendedThemeMode.light;

    final themeModeIndex = settings['themeMode'] ?? 0;
    if (themeModeIndex is int && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    // 加载其他设置
    _fontSize = (settings['fontSize'] as num?)?.toDouble() ?? 1.0;
    _language = settings['language']?.toString() ?? 'zh_CN';
    _appName = settings['appName']?.toString() ?? '牙科诊所管理系统';

    // 加载窗口大小
    final width = (settings['windowWidth'] as num?)?.toDouble();
    final height = (settings['windowHeight'] as num?)?.toDouble();
    if (width != null && height != null) {
      _windowSize = Size(width, height);
    }

    // 更新 Service 状态
    _backupManagementService.updateBackupPaths(
      primaryPath: settings['backupPath']?.toString() ?? '',
      secondaryPath: settings['backupPath2']?.toString() ?? '',
    );
    _backupManagementService.updateAutoBackupSettings(
      autoBackup: settings['autoBackup'] ?? false,
      backupInterval: settings['backupInterval'] ?? 5,
      lastBackupDate: settings['lastBackupDate'] != null
          ? DateTime.tryParse(settings['lastBackupDate'].toString())
          : null,
    );

    _dataSourceManagementService.updateDataSourceType(
      settings['dataSourceType']?.toString() ?? 'sqlite',
    );
    _dataSourceManagementService.updateDataSourceMode(
      settings['dataSourceMode']?.toString() ?? 'global',
    );
    _dataSourceManagementService.updateSqlitePaths(
      sqliteDbPath: settings['sqliteDbPath']?.toString() ?? '',
      customSqliteDbPath: settings['customSqliteDbPath']?.toString() ?? '',
    );
    _dataSourceManagementService.updateMySQLConnectionParams(
      host: settings['mysqlHost']?.toString() ?? '',
      port: settings['mysqlPort']?.toString() ?? '3306',
      database: settings['mysqlDatabase']?.toString() ?? '',
      username: settings['mysqlUsername']?.toString() ?? '',
      password: settings['mysqlPassword']?.toString() ?? '',
    );
    final backupDataSource = settings['backupDataSource']?.toString();
    _dataSourceManagementService.setBackupDataSource(
      backupDataSource == 'mysql' ? 'mysql' : 'sqlite',
    );

    final moduleDataSources =
        _loadModuleDataSources(settings['moduleDataSources']);
    _dataSourceManagementService.setAllModuleDataSources(moduleDataSources);
  }

  // ==================== 初始化 ====================

  Future<void> init() async {
    await _configStorageService.initialize();
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _configStorageService.loadSettings();
    _applyLoadedSettings(settings);

    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final settings = <String, dynamic>{
      'windowsThemeVariant': _windowsThemeVariant.storageValue,
      'extendedThemeMode': _extendedThemeMode.index,
      'themeMode': _themeMode.index,
      'fontSize': _fontSize,
      'language': _language,
      'appName': _appName,
      'backupPath': _backupManagementService.backupPath,
      'backupPath2': _backupManagementService.backupPath2,
      'autoBackup': _backupManagementService.autoBackup,
      'backupInterval': _backupManagementService.backupInterval,
      'lastBackupDate': _backupManagementService.lastBackupDate,
      'dataSourceType': _dataSourceManagementService.dataSourceType,
      'dataSourceMode': _dataSourceManagementService.dataSourceMode,
      'sqliteDbPath': _dataSourceManagementService.sqliteDbPath,
      'customSqliteDbPath': _dataSourceManagementService.customSqliteDbPath,
      'mysqlHost': _dataSourceManagementService.mysqlHost,
      'mysqlPort': _dataSourceManagementService.mysqlPort,
      'mysqlDatabase': _dataSourceManagementService.mysqlDatabase,
      'mysqlUsername': _dataSourceManagementService.mysqlUsername,
      'mysqlPassword': _dataSourceManagementService.mysqlPassword,
      'backupDataSource': _dataSourceManagementService.backupDataSource,
      'moduleDataSources': _dataSourceManagementService.moduleDataSources,
      'windowWidth': _windowSize.width,
      'windowHeight': _windowSize.height,
    };

    await _configStorageService.saveSettings(settings);
  }

  // ==================== 主题设置 ====================

  Future<void> setExtendedThemeMode(ExtendedThemeMode mode) async {
    _extendedThemeMode = mode;
    _themeMode = ThemeMode.light;
    _windowsThemeVariant = WindowsThemeVariant.medicalBlue;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    _extendedThemeMode = ExtendedThemeMode.light;
    _windowsThemeVariant = WindowsThemeVariant.medicalBlue;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setWindowsThemeVariant(WindowsThemeVariant variant) async {
    _windowsThemeVariant = variant;
    _extendedThemeMode = ExtendedThemeMode.light;
    _themeMode = ThemeMode.light;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setFontSize(double size) async {
    _fontSize = size;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAppName(String name) async {
    if (name.trim().isEmpty) {
      LogManager.w('SettingsProvider', '应用名称不能为空');
      return;
    }
    _appName = name.trim();
    await _saveSettings();
    notifyListeners();
  }

  // ==================== 窗口设置 ====================

  Future<void> saveWindowSize(Size size) async {
    _windowSize = size;
    await _saveSettings();
    notifyListeners();
  }

  Future<void> loadWindowSize() async {
    final settings = await _configStorageService.loadSettings();
    final width = settings['windowWidth'];
    final height = settings['windowHeight'];
    if (width != null && height != null) {
      _windowSize = Size(width, height);
      notifyListeners();
    }
  }

  // ==================== 备份路径设置 ====================

  Future<void> setBackupPath(String path) async {
    _backupManagementService.updateBackupPaths(primaryPath: path);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBackupPath2(String path) async {
    _backupManagementService.updateBackupPaths(
      primaryPath: _backupManagementService.backupPath,
      secondaryPath: path,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAutoBackup(bool value) async {
    _backupManagementService.updateAutoBackupSettings(
      autoBackup: value,
      backupInterval: _backupManagementService.backupInterval,
      lastBackupDate: _backupManagementService.lastBackupDate,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBackupInterval(int days) async {
    _backupManagementService.updateAutoBackupSettings(
      autoBackup: _backupManagementService.autoBackup,
      backupInterval: days,
      lastBackupDate: _backupManagementService.lastBackupDate,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateLastBackupDate(DateTime date) async {
    _backupManagementService.updateAutoBackupSettings(
      autoBackup: _backupManagementService.autoBackup,
      backupInterval: _backupManagementService.backupInterval,
      lastBackupDate: date,
    );
    await _saveSettings();
    notifyListeners();
  }

  // ==================== 数据源设置 ====================

  Future<void> setSqliteDbPath(String path) async {
    _dataSourceManagementService.updateSqlitePaths(
      sqliteDbPath: path,
      customSqliteDbPath: path,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setCustomSqliteDbPath(String path) async {
    _dataSourceManagementService.updateSqlitePaths(
      sqliteDbPath: _dataSourceManagementService.sqliteDbPath,
      customSqliteDbPath: path,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMySQLHost(String host) async {
    _dataSourceManagementService.updateMySQLConnectionParams(
      host: host,
      port: _dataSourceManagementService.mysqlPort,
      database: _dataSourceManagementService.mysqlDatabase,
      username: _dataSourceManagementService.mysqlUsername,
      password: _dataSourceManagementService.mysqlPassword,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMySQLPort(String port) async {
    _dataSourceManagementService.updateMySQLConnectionParams(
      host: _dataSourceManagementService.mysqlHost,
      port: port,
      database: _dataSourceManagementService.mysqlDatabase,
      username: _dataSourceManagementService.mysqlUsername,
      password: _dataSourceManagementService.mysqlPassword,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMySQLDatabase(String database) async {
    _dataSourceManagementService.updateMySQLConnectionParams(
      host: _dataSourceManagementService.mysqlHost,
      port: _dataSourceManagementService.mysqlPort,
      database: database,
      username: _dataSourceManagementService.mysqlUsername,
      password: _dataSourceManagementService.mysqlPassword,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMySQLUsername(String username) async {
    _dataSourceManagementService.updateMySQLConnectionParams(
      host: _dataSourceManagementService.mysqlHost,
      port: _dataSourceManagementService.mysqlPort,
      database: _dataSourceManagementService.mysqlDatabase,
      username: username,
      password: _dataSourceManagementService.mysqlPassword,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setMySQLPassword(String password) async {
    _dataSourceManagementService.updateMySQLConnectionParams(
      host: _dataSourceManagementService.mysqlHost,
      port: _dataSourceManagementService.mysqlPort,
      database: _dataSourceManagementService.mysqlDatabase,
      username: _dataSourceManagementService.mysqlUsername,
      password: password,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDataSourceType(String type,
      {Map<String, dynamic>? mysqlSettings, String? customSqlitePath}) async {
    _dataSourceManagementService.setDataSourceType(
      type,
      mysqlSettings: mysqlSettings,
      customSqlitePath: customSqlitePath,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setDataSourceMode(String mode) async {
    _dataSourceManagementService.setDataSourceMode(mode);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setBackupDataSource(String dataSource) async {
    _dataSourceManagementService.setBackupDataSource(dataSource);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setModuleDataSource(String module, String dataSource) async {
    _dataSourceManagementService.setModuleDataSource(module, dataSource);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setAllModuleDataSources(
      Map<String, String> moduleDataSources) async {
    _dataSourceManagementService.setAllModuleDataSources(moduleDataSources);
    await _saveSettings();
    notifyListeners();
  }

  // ==================== 委托给 Service 的方法 ====================

  // 配置存储
  Map<String, dynamic> getConfigStorageInfo() =>
      _configStorageService.getConfigStorageInfo();
  Future<bool> switchToFileStorage() =>
      _configStorageService.switchToFileStorage();
  Future<void> switchToPreferencesStorage() =>
      _configStorageService.switchToPreferencesStorage();
  Future<bool> saveConfigValue(String key, dynamic value) =>
      _configStorageService.saveConfigValue(key, value);
  Future<T?> loadConfigValue<T>(String key, {T? defaultValue}) =>
      _configStorageService.loadConfigValue<T>(key, defaultValue: defaultValue);
  Future<bool> clearAllConfigs() => _configStorageService.clearAllConfigs();
  Future<List<String>> getAllConfigKeys() =>
      _configStorageService.getAllConfigKeys();
  Future<void> clearAllSettings() => _configStorageService.clearAllSettings();

  // 备份管理
  Future<String> performAutoBackup() =>
      _backupManagementService.performAutoBackup();
  Future<void> logBackupSuccess(String backupPath) =>
      _backupManagementService.logBackupSuccess(backupPath);
  Future<void> logBackupFailure(String errorMessage) =>
      _backupManagementService.logBackupFailure(errorMessage);
  Future<bool> validateBackupPath(String backupPath) =>
      _backupManagementService.validateBackupPath(backupPath);
  Future<List<FileSystemEntity>> getBackupFiles() =>
      _backupManagementService.getBackupFiles();
  Future<Map<String, dynamic>> getBackupStatistics() =>
      _backupManagementService.getBackupStatistics();
  bool shouldPerformAutoBackup() =>
      _backupManagementService.shouldPerformAutoBackup();
  DateTime? getNextAutoBackupTime() =>
      _backupManagementService.getNextAutoBackupTime();
  Future<void> setBackupStrategy(
          {required bool autoBackup,
          required int backupInterval,
          required int keepBackupCount}) =>
      _backupManagementService.setBackupStrategy(
          autoBackup: autoBackup,
          backupInterval: backupInterval,
          keepBackupCount: keepBackupCount);
  Map<String, dynamic> getBackupStrategy() =>
      _backupManagementService.getBackupStrategy();
  Future<void> setRestoreStrategy(
          {required bool autoRestore,
          required bool backupBeforeRestore,
          required bool validateRestoreData}) =>
      _backupManagementService.setRestoreStrategy(
          autoRestore: autoRestore,
          backupBeforeRestore: backupBeforeRestore,
          validateRestoreData: validateRestoreData);
  Map<String, dynamic> getRestoreStrategy() =>
      _backupManagementService.getRestoreStrategy();
  Future<void> setRestorePath(String restorePath) =>
      _backupManagementService.setRestorePath(restorePath);
  Future<bool> validateRestorePath(String restorePath) =>
      _backupManagementService.validateRestorePath(restorePath);
  Future<List<FileSystemEntity>> getAvailableRestoreFiles() =>
      _backupManagementService.getAvailableRestoreFiles();
  Future<String?> createPreRestoreBackup({
    required Future<String> Function({
      String? backupPath,
      String? backupDataSource,
    }) executeBackup,
    String? backupDataSource,
  }) =>
      _backupManagementService.createPreRestoreBackup(
        executeBackup: executeBackup,
        backupDataSource: backupDataSource ?? dataSourceType,
      );
  Future<void> cleanupAfterRestore(
          {required bool success,
          String? restorePath,
          String? preRestoreBackupPath}) =>
      _backupManagementService.cleanupAfterRestore(
          success: success,
          restorePath: restorePath,
          preRestoreBackupPath: preRestoreBackupPath);
  String detectRestoreFileType(String filePath) =>
      _backupManagementService.detectRestoreFileType(filePath);
  Future<Map<String, dynamic>> getRestoreFileInfo(String filePath) =>
      _backupManagementService.getRestoreFileInfo(filePath);
  Future<void> updateRestoreProgress(
          {required String operation,
          required int current,
          required int total,
          String? detail}) =>
      _backupManagementService.updateRestoreProgress(
          operation: operation, current: current, total: total, detail: detail);
  Future<void> logRestoreOperation(
          {required String operation,
          required String filePath,
          required bool success,
          String? errorMessage,
          String? preRestoreBackupPath}) =>
      _backupManagementService.logRestoreOperation(
          operation: operation,
          filePath: filePath,
          success: success,
          errorMessage: errorMessage,
          preRestoreBackupPath: preRestoreBackupPath);
  Future<bool> validateRestoreStrategy(
          {required String filePath, required String targetDataSource}) =>
      _backupManagementService.validateRestoreStrategy(
          filePath: filePath, targetDataSource: targetDataSource);

  // 数据源管理
  Future<bool> testMySQLConnection(
          {required String host,
          required int port,
          required String database,
          required String username,
          required String password}) =>
      _dataSourceManagementService.testMySQLConnection(
          host: host,
          port: port,
          database: database,
          username: username,
          password: password);
  Future<void> importDatabase(String importFilePath) =>
      _dataSourceManagementService.importDatabase(
        importFilePath,
        logRestoreOperation: (operation, filePath, success,
                {errorMessage, preRestoreBackupPath}) =>
            logRestoreOperation(
                operation: operation,
                filePath: filePath,
                success: success,
                errorMessage: errorMessage,
                preRestoreBackupPath: preRestoreBackupPath),
        detectRestoreFileType: detectRestoreFileType,
        validateRestoreStrategy: validateRestoreStrategy,
      );
  Future<String> exportDatabase() =>
      _dataSourceManagementService.exportDatabase(
          backupPath: backupPath,
          logBackupSuccess: logBackupSuccess,
          logBackupFailure: logBackupFailure);
  Map<String, dynamic> getCompleteMySQLSettings() =>
      _dataSourceManagementService.getCompleteMySQLSettings();
  bool isMySQLSettingsComplete() =>
      _dataSourceManagementService.isMySQLSettingsComplete();
  Future<void> resetMySQLSettings() async =>
      _dataSourceManagementService.resetMySQLSettings();
  Future<void> clearMySQLSettings() async =>
      _dataSourceManagementService.clearMySQLSettings();
  String getValidatedDataSourceType() =>
      _dataSourceManagementService.getValidatedDataSourceType();
  bool shouldShowMySQLWarning() =>
      _dataSourceManagementService.shouldShowMySQLWarning();
  String getModuleDataSource(String module) =>
      _dataSourceManagementService.getModuleDataSource(module);
  bool isModuleUsingMySQL(String module) =>
      _dataSourceManagementService.isModuleUsingMySQL(module);
  List<String> getMySQLModules() =>
      _dataSourceManagementService.getMySQLModules();
  List<String> getSQLiteModules() =>
      _dataSourceManagementService.getSQLiteModules();

  // 数据库结构检测
  void setDatabaseConnection(
      {Database? database, MySqlConnection? mysqlConnection}) {
    _database = database;
    _mysqlConnection = mysqlConnection;
    _databaseStructureDetectionService.setDatabaseConnection(
        database: database, mysqlConnection: mysqlConnection);
  }

  Future<void> initializeMySQLConnection(Map<String, dynamic> mysqlSettings) =>
      _databaseStructureDetectionService
          .initializeMySQLConnection(mysqlSettings);
  Future<Map<String, dynamic>> detectAndUpdateDatabaseStructure(
      {String? targetDataSource}) async {
    final result = await _databaseStructureDetectionService
        .detectAndUpdateDatabaseStructure(
      targetDataSource: targetDataSource,
    );

    try {
      await saveDatabaseStructureLog(_createLogFromResult(result));
      LogManager.i('SettingsProvider', '数据库结构检测日志已保存');
    } catch (e) {
      LogManager.e('SettingsProvider', '保存数据库结构检测日志失败', error: e);
    }

    return result;
  }

  Future<List<DatabaseStructureLog>> getDatabaseStructureLogs(
          {int limit = 50}) =>
      _databaseStructureDetectionService.getDatabaseStructureLogs(limit: limit);
  Future<bool> deleteDatabaseStructureLog(int logId) =>
      _databaseStructureDetectionService.deleteDatabaseStructureLog(logId);
  Future<bool> clearAllDatabaseStructureLogs() =>
      _databaseStructureDetectionService.clearAllDatabaseStructureLogs();
  Future<void> saveDatabaseStructureLog(DatabaseStructureLog log) =>
      _databaseStructureDetectionService.saveDatabaseStructureLog(log);

  DatabaseStructureLog _createLogFromResult(Map<String, dynamic> result) {
    return DatabaseStructureLog(
      dataSourceType: result['dataSourceType']?.toString() ?? '',
      detectionTime: DateTimeFormatter.fromDbString(
          result['detectionTime']?.toString() ?? ''),
      status: result['status']?.toString() ?? '',
      requiredTables: result['requiredTables'] ?? 0,
      missingTables: result['missingTables'] ?? 0,
      structureChanges: result['structureChanges'] ?? 0,
      errors: List<String>.from(result['errors'] ?? const <String>[]),
      details: Map<String, dynamic>.from(
          result['details'] ?? const <String, dynamic>{}),
      summary: _generateLogSummary(result),
    );
  }

  String _generateLogSummary(Map<String, dynamic> result) {
    final dataSourceType = result['dataSourceType']?.toString() ?? '';
    final errors = List<String>.from(result['errors'] ?? const <String>[]);
    final missingTables = (result['missingTables'] as int?) ?? 0;
    final structureChanges = (result['structureChanges'] as int?) ?? 0;
    final details = Map<String, dynamic>.from(
        result['details'] ?? const <String, dynamic>{});
    final tablesCreated = (details['tablesCreated'] as List?)?.length ?? 0;
    final tablesUpdated = (details['tablesUpdated'] as List?)?.length ?? 0;
    final columnsAdded = (details['columnsAdded'] as List?)?.length ?? 0;
    final ignoredTables = (details['ignoredTables'] as List?)?.length ?? 0;

    if (errors.isNotEmpty) {
      if (missingTables > 0) {
        final suffix = ignoredTables > 0 ? ', 忽略${1}个非系统表' : '';
        return '${dataSourceType.toUpperCase()}数据库结构检测: 发现 ${1} 个缺失表$suffix';
      }
      if (structureChanges > 0 ||
          tablesCreated > 0 ||
          tablesUpdated > 0 ||
          columnsAdded > 0) {
        final suffix = ignoredTables > 0 ? ', 忽略${1}个非系统表' : '';
        return '${dataSourceType.toUpperCase()}数据库结构检测: 存在结构变更$suffix';
      }
      final suffix = ignoredTables > 0 ? ', 忽略${1}个非系统表' : '';
      return '${dataSourceType.toUpperCase()}数据库结构检测: 存在警告$suffix';
    }

    if (tablesCreated > 0 || tablesUpdated > 0 || columnsAdded > 0) {
      final suffix = ignoredTables > 0 ? ', 忽略${1}个非系统表' : '';
      return '${dataSourceType.toUpperCase()}数据库结构检测: 创建${1}个表, 更新${1}个表, 添加${1}个字段$suffix';
    }

    if (structureChanges > 0) {
      final suffix = ignoredTables > 0 ? ', 忽略${1}个非系统表' : '';
      return '${dataSourceType.toUpperCase()}数据库结构检测: 检测到结构更新$suffix';
    }

    if (ignoredTables > 0) {
      return '${dataSourceType.toUpperCase()}数据库结构检测: 数据库结构正常，无需更新，忽略${1}个非系统表';
    }

    return '${dataSourceType.toUpperCase()}数据库结构检测: 数据库结构正常，无需更新';
  }

  // MySQL连接
  Future<String> backupMySQLDatabase({String? backupPath}) =>
      _mysqlConnectionService.backupMySQLDatabase(backupPath: backupPath);
}

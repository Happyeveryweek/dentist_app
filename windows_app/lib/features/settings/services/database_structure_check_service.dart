import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/material_provider.dart';
import 'package:dentist_app_windows/utils/log_manager.dart';
import '../../../models/data_source.dart';

/// 数据库结构检测服务
/// 负责数据库结构检测的业务逻辑
class DatabaseStructureCheckService {
  final DatabaseProvider _dbProvider;
  final SettingsProvider _settingsProvider;
  final MaterialProvider _materialProvider;

  DatabaseStructureCheckService({
    required DatabaseProvider dbProvider,
    required SettingsProvider settingsProvider,
    required MaterialProvider materialProvider,
  })  : _dbProvider = dbProvider,
        _settingsProvider = settingsProvider,
        _materialProvider = materialProvider;

  /// 执行数据库结构检测
  ///
  /// [selectedDataSource] 选择的数据源（'sqlite' 或 'mysql'）
  ///
  /// 返回检测结果
  Future<DatabaseStructureCheckResult> checkDatabaseStructure(
    String selectedDataSource,
  ) async {
    LogManager.i(
        'DatabaseStructureCheckService', '开始数据库结构检测，数据源: $selectedDataSource');
    try {
      // 根据选择的数据源设置连接
      if (selectedDataSource.isSqliteDataSource) {
        // 确保SQLite连接可用
        if (_dbProvider.database == null) {
          await _dbProvider.ensureSQLiteDatabase();
        } else {}

        _settingsProvider.setDatabaseConnection(database: _dbProvider.database);

        await _materialProvider.setDatabaseConnection(
          database: _dbProvider.database,
          dataSourceType: 'sqlite',
        );
      } else if (selectedDataSource.isMySqlDataSource) {
        // 确保SQLite连接可用（用于保存日志）
        if (_dbProvider.database == null) {
          await _dbProvider.ensureSQLiteDatabase();
        } else {}

        // 确保MySQL连接可用
        if (_dbProvider.mysqlConnection == null) {
          final mysqlSettings = _settingsProvider.getCompleteMySQLSettings();

          if (!_settingsProvider.isMySQLSettingsComplete()) {
            throw Exception('MySQL设置不完整，请先在数据源配置中设置MySQL连接参数');
          }
          await _dbProvider.initializeMySQLConnection(mysqlSettings);
        } else {}

        // 一次性设置所有连接

        _settingsProvider.setDatabaseConnection(
          database: _dbProvider.database,
          mysqlConnection: _dbProvider.mysqlConnection,
        );

        await _materialProvider.setDatabaseConnection(
          mysqlConnection: _dbProvider.mysqlConnection,
          dataSourceType: 'mysql',
        );
      }

      // 使用SettingsProvider的数据库结构检测和更新方法
      final result = await _settingsProvider.detectAndUpdateDatabaseStructure(
        targetDataSource: selectedDataSource,
      );

      LogManager.i('DatabaseStructureCheckService', '数据库结构检测成功');
      return DatabaseStructureCheckResult(
        success: true,
        errorMessage: null,
        checkResult: result,
      );
    } catch (e) {
      LogManager.e('DatabaseStructureCheckService', '数据库结构检测失败', error: e);
      return DatabaseStructureCheckResult(
        success: false,
        errorMessage: e.toString(),
        checkResult: null,
      );
    }
  }
}

/// 数据库结构检测结果
class DatabaseStructureCheckResult {
  final bool success;
  final String? errorMessage;
  final dynamic checkResult;

  DatabaseStructureCheckResult({
    required this.success,
    required this.errorMessage,
    required this.checkResult,
  });
}

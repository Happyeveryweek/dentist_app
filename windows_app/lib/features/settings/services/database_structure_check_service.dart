import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/material_provider.dart';

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
    try {
      // 根据选择的数据源设置连接
      if (selectedDataSource == 'sqlite') {
        print('=== 开始SQLite检测，设置数据库连接 ===');
        print('dbProvider.database状态: ${_dbProvider.database}');
        print('settingsProvider.database状态: ${_settingsProvider.database}');

        // 确保SQLite连接可用
        if (_dbProvider.database == null) {
          print('dbProvider.database为null，调用ensureSQLiteDatabase()...');
          await _dbProvider.ensureSQLiteDatabase();
          print('ensureSQLiteDatabase()调用完成');
        } else {
          print('dbProvider.database已存在');
        }

        print('设置SQLite连接到settingsProvider...');
        _settingsProvider.setDatabaseConnection(database: _dbProvider.database);
        print('设置完成');

        print('设置MaterialProvider连接...');
        await _materialProvider.setDatabaseConnection(
          database: _dbProvider.database,
          dataSourceType: 'sqlite',
        );
        print('MaterialProvider连接设置完成');
      } else if (selectedDataSource == 'mysql') {
        print('=== 开始MySQL检测，设置数据库连接 ===');
        print('dbProvider.database状态: ${_dbProvider.database}');
        print('dbProvider.mysqlConnection状态: ${_dbProvider.mysqlConnection}');
        print('settingsProvider.database状态: ${_settingsProvider.database}');
        print('settingsProvider.mysqlConnection状态: ${_settingsProvider.mysqlConnection}');

        // 确保SQLite连接可用（用于保存日志）
        if (_dbProvider.database == null) {
          print('dbProvider.database为null，调用ensureSQLiteDatabase()...');
          await _dbProvider.ensureSQLiteDatabase();
          print('ensureSQLiteDatabase()调用完成');
        } else {
          print('dbProvider.database已存在');
        }

        // 确保MySQL连接可用
        if (_dbProvider.mysqlConnection == null) {
          print('dbProvider.mysqlConnection为null，初始化MySQL连接...');
          final mysqlSettings = _settingsProvider.getCompleteMySQLSettings();
          print('MySQL设置: $mysqlSettings');
          if (!_settingsProvider.isMySQLSettingsComplete()) {
            throw Exception('MySQL设置不完整，请先在数据源配置中设置MySQL连接参数');
          }
          await _dbProvider.initializeMySQLConnection(mysqlSettings);
          print('MySQL连接初始化完成');
        } else {
          print('dbProvider.mysqlConnection已存在');
        }

        // 一次性设置所有连接
        print('一次性设置所有数据库连接...');
        _settingsProvider.setDatabaseConnection(
          database: _dbProvider.database,
          mysqlConnection: _dbProvider.mysqlConnection,
        );
        print('设置完成');

        print('设置MaterialProvider连接...');
        await _materialProvider.setDatabaseConnection(
          mysqlConnection: _dbProvider.mysqlConnection,
          dataSourceType: 'mysql',
        );
        print('MaterialProvider连接设置完成');
      }
      
      // 使用SettingsProvider的数据库结构检测和更新方法
      final result = await _settingsProvider.detectAndUpdateDatabaseStructure(
        targetDataSource: selectedDataSource,
      );

      return DatabaseStructureCheckResult(
        success: true,
        errorMessage: null,
        checkResult: result,
      );
    } catch (e) {
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

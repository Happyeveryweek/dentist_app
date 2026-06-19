import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../data_sources/financial_data_source.dart';
import '../../../data_sources/sqlite_financial_data_source.dart';
import '../../../data_sources/mysql_financial_data_source.dart';

/// 财务数据源初始化服务
/// 负责SQLite和MySQL数据源的初始化和切换
class FinancialDataSourceInitializer {
  Database? _database;
  MySqlConnection? _mysqlConnection;
  String _dataSourceType = 'sqlite';
  Map<String, String>? _moduleDataSources;
  
  SqliteFinancialDataSource? _sqliteDataSource;
  MySqlFinancialDataSource? _mysqlDataSource;
  
  // 获取有效的数据源类型（考虑模块化配置）
  String get effectiveDataSourceType {
    if (_moduleDataSources != null && _moduleDataSources!.containsKey('financial')) {
      return _moduleDataSources!['financial']!;
    }
    return _dataSourceType;
  }
  
  // 获取SQLite数据源
  SqliteFinancialDataSource? get sqliteDataSource => _sqliteDataSource;
  
  // 获取MySQL数据源
  MySqlFinancialDataSource? get mysqlDataSource => _mysqlDataSource;
  
  // 设置SQLite数据源
  void setSqliteDataSource(Database database) {
    _database = database;
    _sqliteDataSource = SqliteFinancialDataSource(database);
  }
  
  // 设置MySQL数据源（使用动态连接获取）
  void setMySqlDataSource({
    required MySqlConnection connection,
    required dynamic databaseProvider,
  }) {
    _mysqlConnection = connection;
    _mysqlDataSource = MySqlFinancialDataSource.withConnectionGetter(
      () async {
        // 从 databaseProvider 获取最新连接
        try {
          final conn = databaseProvider.mysqlConnection;
          if (conn != null) {
            return conn;
          }
        } catch (e) {
          print('获取MySQL连接失败: $e');
        }
        return _mysqlConnection;
      },
      reconnectCallback: () async {
        // 重连回调：尝试重新初始化MySQL连接
        try {
          await databaseProvider.initializeMySQL();
          print('✅ FinancialDataSourceInitializer: MySQL重连成功');
        } catch (e) {
          print('❌ FinancialDataSourceInitializer: MySQL重连失败: $e');
        }
      },
    );
  }
  
  // 初始化数据源（从DatabaseProvider）
  Future<void> initialize({
    required dynamic databaseProvider,
    required Map<String, String>? moduleDataSources,
    required String? dataSourceMode,
  }) async {
    _moduleDataSources = moduleDataSources;
    
    // 确定要使用的数据源类型
    String dbType = 'sqlite';
    
    // 如果是模块化模式且有模块配置，优先使用模块配置
    if (dataSourceMode == 'modular' && moduleDataSources != null && moduleDataSources.containsKey('financial')) {
      dbType = moduleDataSources['financial']!;
      print('FinancialDataSourceInitializer使用模块化配置: financial -> $dbType');
    } else {
      // 否则使用全局配置
      try {
        if (databaseProvider.dataSourceType != null) {
          dbType = databaseProvider.dataSourceType;
        }
      } catch (e) {
        print('获取dataSourceType失败，使用默认值: $e');
      }
      print('FinancialDataSourceInitializer使用全局配置: $dbType');
    }
    
    // 设置数据源类型
    _dataSourceType = dbType;
    
    // 根据确定的数据源类型初始化对应的数据源
    if (dbType == 'sqlite') {
      // 初始化SQLite数据源
      try {
        if (databaseProvider.database != null) {
          _database = databaseProvider.database;
          setSqliteDataSource(databaseProvider.database);
        }
      } catch (e) {
        print('获取SQLite数据库失败: $e');
      }
    } else if (dbType == 'mysql') {
      // 初始化MySQL数据源
      try {
        final mysqlConnection = databaseProvider.mysqlConnection;
        if (mysqlConnection != null) {
          _mysqlConnection = mysqlConnection;
          setMySqlDataSource(
            connection: mysqlConnection,
            databaseProvider: databaseProvider,
          );
        } else {
          print('⚠️ MySQL连接为null，自动降级到SQLite');
          _dataSourceType = 'sqlite';
          // 立即更新模块配置，避免后续代码仍然尝试使用MySQL
          if (_moduleDataSources != null) {
            _moduleDataSources!['financial'] = 'sqlite';
            print('✅ 已更新模块配置: financial -> sqlite');
          }
          
          // 降级到SQLite
          if (databaseProvider.database != null) {
            _database = databaseProvider.database;
            setSqliteDataSource(databaseProvider.database);
            print('✅ FinancialDataSourceInitializer已降级到SQLite数据源');
          } else {
            print('❌ SQLite数据库也不可用');
          }
        }
      } catch (e) {
        print('获取MySQL连接失败: $e');
        // 尝试降级到SQLite
        _dataSourceType = 'sqlite';
        // 立即更新模块配置，避免后续代码仍然尝试使用MySQL
        if (_moduleDataSources != null) {
          _moduleDataSources!['financial'] = 'sqlite';
          print('✅ 已更新模块配置: financial -> sqlite');
        }
        
        if (databaseProvider.database != null) {
          _database = databaseProvider.database;
          try {
            setSqliteDataSource(databaseProvider.database);
            print('✅ FinancialDataSourceInitializer已降级到SQLite数据源');
          } catch (fallbackError) {
            print('❌ 降级到SQLite也失败: $fallbackError');
          }
        }
      }
    }
    
    print('FinancialDataSourceInitializer初始化完成，数据源类型: $dbType');
  }
  
  // 更新模块数据源配置
  void updateModuleDataSources(Map<String, String> moduleDataSources) {
    _moduleDataSources = moduleDataSources;
    print('FinancialDataSourceInitializer.updateModuleDataSources - 模块数据源配置已更新: $_moduleDataSources');
  }
  
  // 获取当前数据源（必须可用，否则抛出异常）
  FinancialDataSource getCurrentDataSource() {
    final effectiveType = effectiveDataSourceType;
    
    if (effectiveType == 'mysql') {
      // 如果要求使用MySQL但未初始化，尝试降级到SQLite
      if (_mysqlDataSource == null) {
        if (_sqliteDataSource != null) {
          print('⚠️ MySQL财务数据源未初始化，自动降级到SQLite');
          return _sqliteDataSource!;
        }
        throw Exception('MySQL财务数据源未初始化 - 模块配置要求使用MySQL但数据源未设置');
      }
      return _mysqlDataSource!;
    } else {
      if (_sqliteDataSource == null) {
        throw Exception('SQLite财务数据源未初始化');
      }
      return _sqliteDataSource!;
    }
  }
}

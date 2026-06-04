import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../data_sources/medical_record_data_source.dart';
import '../../../utils/mysql_sync_connection_helper.dart';
import '../../../models/user.dart';
import '../../../providers/user_provider.dart';

/// 病历数据源初始化服务
/// 负责处理病历数据源的初始化、连接管理和降级逻辑
class MedicalRecordDataSourceInitializer {
  final dynamic Function() getDatabaseProvider;
  final UserProvider? Function()? getUserProvider;
  final User? Function()? getCurrentUser;
  final void Function(String) setError;
  final void Function(String) printLog;

  MedicalRecordDataSourceInitializer({
    required this.getDatabaseProvider,
    this.getUserProvider,
    this.getCurrentUser,
    required this.setError,
    required this.printLog,
  });

  /// 获取用于同步的MySQL连接
  MySqlConnection? getSyncMysqlConnection({
    MySqlConnection? cachedConnection,
    Function(MySqlConnection?)? onConnectionUpdate,
  }) {
    final dbProvider = getDatabaseProvider();
    return MySqlSyncConnectionHelper.getSyncConnection(
      databaseProvider: dbProvider,
      cachedConnection: cachedConnection,
      onConnectionUpdate: onConnectionUpdate ?? (newConnection) {},
    );
  }

  /// 获取当前MySQL连接（动态）
  MySqlConnection? getCurrentMysqlConnection({
    MySqlConnection? cachedConnection,
  }) {
    final dbProvider = getDatabaseProvider();
    if (dbProvider == null) return cachedConnection;

    try {
      final latestConnection = dbProvider.mysqlConnection;
      if (latestConnection != null) {
        return latestConnection;
      }
    } catch (e) {
      printLog('获取最新MySQL连接失败: $e');
    }

    return cachedConnection;
  }

  /// 获取当前数据源类型
  String? getEffectiveDataSourceType({
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
  }) {
    final dbProvider = getDatabaseProvider();
    if (dbProvider == null) return null;

    String dbType = 'sqlite';

    // 病历管理始终跟随患者管理的数据源配置
    if (dataSourceMode == 'modular' &&
        moduleDataSources != null &&
        moduleDataSources.containsKey('patients')) {
      dbType = moduleDataSources['patients']!;
      printLog('MedicalRecordDataSourceInitializer: 跟随患者模块配置: patients -> $dbType');
    } else {
      // 否则使用全局配置
      dbType = dbProvider.dataSourceType ?? 'sqlite';
      printLog('MedicalRecordDataSourceInitializer: 使用全局配置: $dbType');
    }

    return dbType;
  }

  /// 同步初始化数据源（立即设置数据源）
  DataSourceInitializationResult initializeFromDatabaseSync({
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    UserProvider? userProvider,
    User? currentUser,
    Function(SqliteMedicalRecordDataSource)? onSqliteDataSourceReady,
    Function(MySqlMedicalRecordDataSource)? onMysqlDataSourceReady,
    Function(Database)? onDatabaseReady,
    Function(MySqlConnection?)? onMysqlConnectionReady,
    Function(String)? onDataSourceTypeChanged,
  }) {
    printLog('MedicalRecordDataSourceInitializer: 开始同步初始化');

    final dbProvider = getDatabaseProvider();
    final effectiveDataSourceType = getEffectiveDataSourceType(
      moduleDataSources: moduleDataSources,
      dataSourceMode: dataSourceMode,
    );

    // 获取当前用户信息（优先从UserProvider获取，其次从_currentUser）
    final finalUserProvider = userProvider ?? getUserProvider?.call();
    final finalCurrentUser = currentUser ?? getCurrentUser?.call();
    final resolvedUser = finalUserProvider?.currentUser ?? finalCurrentUser;
    final doctorName = resolvedUser?.doctor;
    final isAdmin = resolvedUser?.role == 'admin';

    DataSourceInitializationResult result = DataSourceInitializationResult(
      success: false,
      dataSourceType: effectiveDataSourceType ?? 'sqlite',
      error: null,
    );

    // 立即初始化数据源
    if (effectiveDataSourceType == 'sqlite') {
      final database = dbProvider?.database;
      printLog('MedicalRecordDataSourceInitializer: 初始化SQLite数据源，database=${database != null ? "存在" : "null"}');
      if (database != null) {
        final sqliteDataSource = SqliteMedicalRecordDataSource(
          database,
          doctorName: doctorName,
          isAdmin: isAdmin ?? false,
        );

        onSqliteDataSourceReady?.call(sqliteDataSource);
        onDatabaseReady?.call(database);
        onDataSourceTypeChanged?.call('sqlite');

        result = DataSourceInitializationResult(
          success: true,
          dataSourceType: 'sqlite',
          sqliteDataSource: sqliteDataSource,
          database: database,
          error: null,
        );

        printLog('MedicalRecordDataSourceInitializer: SQLite数据源初始化完成');
      } else {
        printLog('MedicalRecordDataSourceInitializer: SQLite数据库连接不可用');
        setError('SQLite数据库连接不可用');
        result = DataSourceInitializationResult(
          success: false,
          dataSourceType: 'sqlite',
          error: 'SQLite数据库连接不可用',
        );
      }
    } else if (effectiveDataSourceType == 'mysql') {
      // 检查MySQL连接是否可用
      final mysqlConn = dbProvider?.mysqlConnection;
      if (mysqlConn == null) {
        printLog('⚠️ MedicalRecordDataSourceInitializer: MySQL连接不可用，自动降级到SQLite');

        // 降级到SQLite
        final database = dbProvider?.database;
        if (database != null) {
          final sqliteDataSource = SqliteMedicalRecordDataSource(
            database,
            doctorName: doctorName,
            isAdmin: isAdmin ?? false,
          );

          onSqliteDataSourceReady?.call(sqliteDataSource);
          onDatabaseReady?.call(database);
          onDataSourceTypeChanged?.call('sqlite');

          result = DataSourceInitializationResult(
            success: true,
            dataSourceType: 'sqlite',
            sqliteDataSource: sqliteDataSource,
            database: database,
            error: null,
            degraded: true,
          );

          printLog('MedicalRecordDataSourceInitializer: 已降级到SQLite数据源');
        } else {
          setError('SQLite数据库连接不可用');
          result = DataSourceInitializationResult(
            success: false,
            dataSourceType: 'sqlite',
            error: 'SQLite数据库连接不可用',
          );
        }
      } else {
        printLog('MedicalRecordDataSourceInitializer: 初始化MySQL数据源');
        final mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
          () async {
            final conn = getCurrentMysqlConnection();
            return conn;
          },
          doctorName: doctorName,
          isAdmin: isAdmin ?? false,
          reconnectCallback: () async {
            if (dbProvider != null) {
              try {
                await dbProvider.initializeMySQL();
                printLog('✅ MedicalRecordDataSourceInitializer: MySQL重连成功');
              } catch (e) {
                printLog('❌ MedicalRecordDataSourceInitializer: MySQL重连失败: $e');
              }
            }
          },
        );

        onMysqlDataSourceReady?.call(mysqlDataSource);
        onMysqlConnectionReady?.call(dbProvider.mysqlConnection);
        onDataSourceTypeChanged?.call('mysql');

        result = DataSourceInitializationResult(
          success: true,
          dataSourceType: 'mysql',
          mysqlDataSource: mysqlDataSource,
          mysqlConnection: dbProvider.mysqlConnection,
          error: null,
        );

        printLog('MedicalRecordDataSourceInitializer: MySQL数据源初始化完成');
      }
    }

    printLog('MedicalRecordDataSourceInitializer: 同步初始化完成');
    return result;
  }

  /// 异步初始化数据源
  Future<DataSourceInitializationResult> initializeFromDatabase({
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    UserProvider? userProvider,
    User? currentUser,
    Function(SqliteMedicalRecordDataSource)? onSqliteDataSourceReady,
    Function(MySqlMedicalRecordDataSource)? onMysqlDataSourceReady,
    Function(Database)? onDatabaseReady,
    Function(MySqlConnection?)? onMysqlConnectionReady,
    Function(String)? onDataSourceTypeChanged,
    Function()? onEnsureTablesExist,
  }) async {
    try {
      final dbProvider = getDatabaseProvider();
      final effectiveDataSourceType = getEffectiveDataSourceType(
        moduleDataSources: moduleDataSources,
        dataSourceMode: dataSourceMode,
      );

      // 获取当前用户信息（优先从UserProvider获取，其次从_currentUser）
      final finalUserProvider = userProvider ?? getUserProvider?.call();
      final finalCurrentUser = currentUser ?? getCurrentUser?.call();
      final resolvedUser = finalUserProvider?.currentUser ?? finalCurrentUser;
      final doctorName = resolvedUser?.doctor;
      final isAdmin = resolvedUser?.role == 'admin';

      DataSourceInitializationResult result = DataSourceInitializationResult(
        success: false,
        dataSourceType: effectiveDataSourceType ?? 'sqlite',
        error: null,
      );

      // 一次性初始化正确的数据源
      if (effectiveDataSourceType == 'sqlite') {
        final database = dbProvider?.database;
        printLog('MedicalRecordDataSourceInitializer: 初始化SQLite数据源，database=${database != null ? "存在" : "null"}');
        if (database != null) {
          // 检查并创建必要的表
          onEnsureTablesExist?.call();

          final sqliteDataSource = SqliteMedicalRecordDataSource(
            database,
            doctorName: doctorName,
            isAdmin: isAdmin ?? false,
          );

          onSqliteDataSourceReady?.call(sqliteDataSource);
          onDatabaseReady?.call(database);
          onDataSourceTypeChanged?.call('sqlite');

          result = DataSourceInitializationResult(
            success: true,
            dataSourceType: 'sqlite',
            sqliteDataSource: sqliteDataSource,
            database: database,
            error: null,
          );

          printLog('MedicalRecordDataSourceInitializer: SQLite数据源初始化完成，effectiveDataSourceType=$effectiveDataSourceType');
        } else {
          printLog('MedicalRecordDataSourceInitializer: SQLite数据库连接不可用');
          setError('SQLite数据库连接不可用');
          result = DataSourceInitializationResult(
            success: false,
            dataSourceType: 'sqlite',
            error: 'SQLite数据库连接不可用',
          );
        }
      } else if (effectiveDataSourceType == 'mysql') {
        // 检查MySQL连接是否可用
        final mysqlConn = dbProvider?.mysqlConnection;
        if (mysqlConn == null) {
          printLog('⚠️ MedicalRecordDataSourceInitializer: MySQL连接不可用，自动降级到SQLite');

          // 降级到SQLite
          final database = dbProvider?.database;
          if (database != null) {
            // 检查并创建必要的表
            onEnsureTablesExist?.call();

            final sqliteDataSource = SqliteMedicalRecordDataSource(
              database,
              doctorName: doctorName,
              isAdmin: isAdmin ?? false,
            );

            onSqliteDataSourceReady?.call(sqliteDataSource);
            onDatabaseReady?.call(database);
            onDataSourceTypeChanged?.call('sqlite');

            result = DataSourceInitializationResult(
              success: true,
              dataSourceType: 'sqlite',
              sqliteDataSource: sqliteDataSource,
              database: database,
              error: null,
              degraded: true,
            );

            printLog('MedicalRecordDataSourceInitializer: 已降级到SQLite数据源');
          } else {
            setError('SQLite数据库连接不可用');
            result = DataSourceInitializationResult(
              success: false,
              dataSourceType: 'sqlite',
              error: 'SQLite数据库连接不可用',
            );
          }
        } else {
          printLog('MedicalRecordDataSourceInitializer: 初始化MySQL数据源');
          final mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
            () async {
              final conn = getCurrentMysqlConnection();
              return conn;
            },
            doctorName: doctorName,
            isAdmin: isAdmin ?? false,
            reconnectCallback: () async {
              if (dbProvider != null) {
                try {
                  await dbProvider.initializeMySQL();
                  printLog('✅ MedicalRecordDataSourceInitializer: MySQL重连成功');
                } catch (e) {
                  printLog('❌ MedicalRecordDataSourceInitializer: MySQL重连失败: $e');
                }
              }
            },
          );

          // 测试MySQL连接
          final testResult = await _testMySqlConnection(mysqlConn);
          if (testResult) {
            onMysqlDataSourceReady?.call(mysqlDataSource);
            onMysqlConnectionReady?.call(dbProvider.mysqlConnection);
            onDataSourceTypeChanged?.call('mysql');

            result = DataSourceInitializationResult(
              success: true,
              dataSourceType: 'mysql',
              mysqlDataSource: mysqlDataSource,
              mysqlConnection: dbProvider.mysqlConnection,
              error: null,
            );

            printLog('MedicalRecordDataSourceInitializer: MySQL数据源初始化完成，effectiveDataSourceType=$effectiveDataSourceType');
          } else {
            printLog('⚠️ MedicalRecordDataSourceInitializer: MySQL连接测试失败，自动降级到SQLite');

            // 降级到SQLite
            final database = dbProvider?.database;
            if (database != null) {
              // 检查并创建必要的表
              onEnsureTablesExist?.call();

              final sqliteDataSource = SqliteMedicalRecordDataSource(
                database,
                doctorName: doctorName,
                isAdmin: isAdmin ?? false,
              );

              onSqliteDataSourceReady?.call(sqliteDataSource);
              onDatabaseReady?.call(database);
              onDataSourceTypeChanged?.call('sqlite');

              result = DataSourceInitializationResult(
                success: true,
                dataSourceType: 'sqlite',
                sqliteDataSource: sqliteDataSource,
                database: database,
                error: null,
                degraded: true,
              );

              printLog('MedicalRecordDataSourceInitializer: 已降级到SQLite数据源');
            } else {
              setError('SQLite数据库连接不可用');
              result = DataSourceInitializationResult(
                success: false,
                dataSourceType: 'sqlite',
                error: 'SQLite数据库连接不可用',
              );
            }
          }
        }
      }

      return result;
    } catch (e) {
      printLog('MedicalRecordDataSourceInitializer初始化失败: $e');
      setError('初始化失败: $e');
      return DataSourceInitializationResult(
        success: false,
        dataSourceType: 'sqlite',
        error: '初始化失败: $e',
      );
    }
  }

  /// MySQL连接测试
  Future<bool> _testMySqlConnection(MySqlConnection? connection) async {
    if (connection == null) return false;

    try {
      await connection.query('SELECT 1').timeout(
        const Duration(seconds: 10),
      );
      return true;
    } catch (e) {
      printLog('MySQL连接测试失败: $e');
      return false;
    }
  }

  /// 重新初始化数据源以应用新的用户信息
  DataSourceInitializationResult reinitializeDataSourcesWithUser({
    String? effectiveDataSourceType,
    Database? database,
    MySqlConnection? cachedMysqlConnection,
    UserProvider? userProvider,
    User? currentUser,
  }) {
    // 优先从UserProvider获取用户信息
    final finalUserProvider = userProvider ?? getUserProvider?.call();
    final finalCurrentUser = currentUser ?? getCurrentUser?.call();
    final currentUserInfo = finalUserProvider?.currentUser ?? finalCurrentUser;
    final doctorName = currentUserInfo?.doctor;
    final isAdmin = currentUserInfo?.role == 'admin';

    final dbProvider = getDatabaseProvider();

    if (effectiveDataSourceType == 'sqlite' && dbProvider?.database != null) {
      final sqliteDataSource = SqliteMedicalRecordDataSource(
        dbProvider!.database!,
        doctorName: doctorName,
        isAdmin: isAdmin ?? false,
      );

      printLog('MedicalRecordDataSourceInitializer: SQLite数据源权限更新');

      return DataSourceInitializationResult(
        success: true,
        dataSourceType: 'sqlite',
        sqliteDataSource: sqliteDataSource,
        database: dbProvider.database,
        error: null,
      );
    } else if (effectiveDataSourceType == 'mysql' && dbProvider?.mysqlConnection != null) {
      final mysqlDataSource = MySqlMedicalRecordDataSource.withConnectionGetter(
        () async {
          final conn = getCurrentMysqlConnection(cachedConnection: cachedMysqlConnection);
          if (conn == null) throw Exception('MySQL连接不可用');
          return conn;
        },
        doctorName: doctorName,
        isAdmin: isAdmin ?? false,
        reconnectCallback: () async {
          if (dbProvider != null) {
            try {
              await dbProvider.initializeMySQL();
              printLog('✅ MedicalRecordDataSourceInitializer: MySQL重连成功');
            } catch (e) {
              printLog('❌ MedicalRecordDataSourceInitializer: MySQL重连失败: $e');
            }
          }
        },
      );

      printLog('MedicalRecordDataSourceInitializer: MySQL数据源权限更新');

      return DataSourceInitializationResult(
        success: true,
        dataSourceType: 'mysql',
        mysqlDataSource: mysqlDataSource,
        mysqlConnection: dbProvider.mysqlConnection,
        error: null,
      );
    }

    return DataSourceInitializationResult(
      success: false,
      dataSourceType: effectiveDataSourceType ?? 'sqlite',
      error: '无法重新初始化数据源',
    );
  }
}

/// 数据源初始化结果
class DataSourceInitializationResult {
  final bool success;
  final String dataSourceType;
  final SqliteMedicalRecordDataSource? sqliteDataSource;
  final MySqlMedicalRecordDataSource? mysqlDataSource;
  final Database? database;
  final MySqlConnection? mysqlConnection;
  final String? error;
  final bool degraded;

  DataSourceInitializationResult({
    required this.success,
    required this.dataSourceType,
    this.sqliteDataSource,
    this.mysqlDataSource,
    this.database,
    this.mysqlConnection,
    this.error,
    this.degraded = false,
  });
}

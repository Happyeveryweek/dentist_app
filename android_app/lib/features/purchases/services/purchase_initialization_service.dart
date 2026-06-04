import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/models/purchase_item.dart';
import 'package:dentist_app/models/purchase_record.dart';
import 'package:dentist_app/providers/database_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/utils/database_operation_wrapper.dart';
import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';

import 'purchase_cache_service.dart';
import 'purchase_connection_service.dart';
import 'purchase_permission_service.dart';
import 'purchase_statistics_service.dart';
import '../../../data_sources/purchase_data_source.dart' hide SqlitePurchaseDataSource, MySqlPurchaseDataSource;
import '../../../data_sources/sqlite_purchase_data_source.dart';
import '../../../data_sources/mysql_purchase_data_source.dart';

class PurchaseInitializationResult {
  final Database? database;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;
  final bool initialized;
  final DatabaseOperationWrapper dbWrapper;
  final PurchaseCacheService cacheService;
  final PurchasePermissionService permissionService;
  final PurchaseConnectionService connectionService;
  final PurchaseDatabaseStatisticsService statisticsService;
  final SqlitePurchaseDataSource? sqliteDataSource;
  final MySqlPurchaseDataSource? mysqlDataSource;

  PurchaseInitializationResult({
    required this.database,
    required this.mysqlConnection,
    required this.dataSourceType,
    required this.initialized,
    required this.dbWrapper,
    required this.cacheService,
    required this.permissionService,
    required this.connectionService,
    required this.statisticsService,
    required this.sqliteDataSource,
    required this.mysqlDataSource,
  });
}

class PurchaseInitializationService {
  Future<PurchaseInitializationResult> initialize({
    required dynamic dbProvider,
    required UserProvider? userProvider,
    required String dataSourceType,
    required Database? database,
    required MySqlConnection? mysqlConnection,
    required void Function(String) log,
  }) async {
    var currentDatabase = database;
    var currentMysqlConnection = mysqlConnection;
    var currentDataSourceType = dataSourceType;
    SqlitePurchaseDataSource? sqliteDataSource;
    MySqlPurchaseDataSource? mysqlDataSource;

    log('PurchaseProvider开始初始化...');

    String dbType = 'sqlite';
    if (dbProvider.dbType != null) {
      dbType = dbProvider.dbType;
    } else if (dbProvider.dataSourceType != null) {
      dbType = dbProvider.dataSourceType;
    }

    if (dbType == 'mysql') {
      final mysqlConn = dbProvider.mysqlConnection;
      if (mysqlConn != null) {
        currentMysqlConnection = mysqlConn;
        currentDataSourceType = 'mysql';
        mysqlDataSource = MySqlPurchaseDataSource.withConnectionGetter(() => currentMysqlConnection);
        log('✅ PurchaseProvider MySQL数据源设置成功');
      } else {
        log('警告：MySQL连接为null，尝试SQLite');
        final db = await dbProvider.sqliteDatabase;
        if (db != null) {
          currentDatabase = db;
          currentDataSourceType = 'sqlite';
          sqliteDataSource = SqlitePurchaseDataSource(db);
          log('PurchaseProvider 回退到SQLite数据源设置成功');
        } else {
          log('警告：SQLite数据库实例为null，延迟初始化...');
          return PurchaseInitializationResult(
            database: currentDatabase,
            mysqlConnection: currentMysqlConnection,
            dataSourceType: currentDataSourceType,
            initialized: false,
            dbWrapper: DatabaseOperationWrapper(dbProvider),
            cacheService: PurchaseCacheService(),
            permissionService: PurchasePermissionService(userProvider: userProvider),
            connectionService: PurchaseConnectionService(),
            statisticsService: PurchaseDatabaseStatisticsService(
              sqliteDatabase: currentDatabase,
              mysqlConnection: currentMysqlConnection,
              dataSourceType: currentDataSourceType,
              getDoctorFilter: () => userProvider == null ? null : userProvider.buildDoctorFilter(userProvider.currentUser),
              shouldFilterByDoctor: () => userProvider != null && userProvider.currentUser != null && userProvider.currentUser!.role != 'admin' && userProvider.currentUser!.doctor != null && userProvider.currentUser!.doctor!.isNotEmpty,
              testMySqlConnection: () => Future.value(false),
            ),
            sqliteDataSource: sqliteDataSource,
            mysqlDataSource: mysqlDataSource,
          );
        }
      }
    } else {
      try {
        final db = await dbProvider.sqliteDatabase;
        if (db != null) {
          currentDatabase = db;
          currentDataSourceType = 'sqlite';
          sqliteDataSource = SqlitePurchaseDataSource(db);
          log('✅ PurchaseProvider SQLite数据源设置成功');
        } else {
          log('警告：SQLite数据库实例为null，延迟初始化...');
          return PurchaseInitializationResult(
            database: currentDatabase,
            mysqlConnection: currentMysqlConnection,
            dataSourceType: currentDataSourceType,
            initialized: false,
            dbWrapper: DatabaseOperationWrapper(dbProvider),
            cacheService: PurchaseCacheService(),
            permissionService: PurchasePermissionService(userProvider: userProvider),
            connectionService: PurchaseConnectionService(),
            statisticsService: PurchaseDatabaseStatisticsService(
              sqliteDatabase: currentDatabase,
              mysqlConnection: currentMysqlConnection,
              dataSourceType: currentDataSourceType,
              getDoctorFilter: () => userProvider == null ? null : userProvider.buildDoctorFilter(userProvider.currentUser),
              shouldFilterByDoctor: () => userProvider != null && userProvider.currentUser != null && userProvider.currentUser!.role != 'admin' && userProvider.currentUser!.doctor != null && userProvider.currentUser!.doctor!.isNotEmpty,
              testMySqlConnection: () => Future.value(false),
            ),
            sqliteDataSource: sqliteDataSource,
            mysqlDataSource: mysqlDataSource,
          );
        }
      } catch (e) {
        log('获取SQLite数据库失败: $e');
        if (dbProvider.database != null) {
          currentDatabase = dbProvider.database;
          currentDataSourceType = 'sqlite';
          sqliteDataSource = SqlitePurchaseDataSource(dbProvider.database);
          log('通过备用方式获取SQLite数据库: ${currentDatabase != null ? "成功" : "失败"}');
        } else {
          log('警告：所有数据库获取方式都失败');
          return PurchaseInitializationResult(
            database: currentDatabase,
            mysqlConnection: currentMysqlConnection,
            dataSourceType: currentDataSourceType,
            initialized: false,
            dbWrapper: DatabaseOperationWrapper(dbProvider),
            cacheService: PurchaseCacheService(),
            permissionService: PurchasePermissionService(userProvider: userProvider),
            connectionService: PurchaseConnectionService(),
            statisticsService: PurchaseDatabaseStatisticsService(
              sqliteDatabase: currentDatabase,
              mysqlConnection: currentMysqlConnection,
              dataSourceType: currentDataSourceType,
              getDoctorFilter: () => userProvider == null ? null : userProvider.buildDoctorFilter(userProvider.currentUser),
              shouldFilterByDoctor: () => userProvider != null && userProvider.currentUser != null && userProvider.currentUser!.role != 'admin' && userProvider.currentUser!.doctor != null && userProvider.currentUser!.doctor!.isNotEmpty,
              testMySqlConnection: () => Future.value(false),
            ),
            sqliteDataSource: sqliteDataSource,
            mysqlDataSource: mysqlDataSource,
          );
        }
      }
    }

    final connectionService = PurchaseConnectionService();
    final permissionService = PurchasePermissionService(userProvider: userProvider);
    final cacheService = PurchaseCacheService();
    final statisticsService = PurchaseDatabaseStatisticsService(
      sqliteDatabase: currentDatabase,
      mysqlConnection: currentMysqlConnection,
      dataSourceType: currentDataSourceType,
      getDoctorFilter: () => permissionService.getDoctorFilter(),
      shouldFilterByDoctor: () => permissionService.shouldFilterByDoctor(),
      testMySqlConnection: () => connectionService.testMySqlConnection(currentMysqlConnection),
    );

    return PurchaseInitializationResult(
      database: currentDatabase,
      mysqlConnection: currentMysqlConnection,
      dataSourceType: currentDataSourceType,
      initialized: true,
      dbWrapper: DatabaseOperationWrapper(dbProvider),
      cacheService: cacheService,
      permissionService: permissionService,
      connectionService: connectionService,
      statisticsService: statisticsService,
      sqliteDataSource: sqliteDataSource,
      mysqlDataSource: mysqlDataSource,
    );
  }
}

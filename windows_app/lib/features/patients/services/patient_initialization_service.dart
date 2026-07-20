import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../data_sources/patient_data_source.dart';
import '../../../models/user.dart';
import '../../../utils/log_manager.dart';
import '../../../config/app_defaults.dart';
import '../../../models/app_module.dart';
import '../../../models/data_source.dart';

/// 患者模块初始化与数据源构建服务
class PatientInitializationService {
  /// 测试 MySQL 连接是否可用
  static Future<bool> testMySqlConnection(MySqlConnection? conn) async {
    if (conn == null) return false;
    try {
      await conn
          .query('SELECT 1')
          .timeout(MySqlConnectionPolicy.validationTimeout);
      return true;
    } catch (e) {
      LogManager.e('PatientInitializationService',
          'PatientInitializationService: MySQL 连接测试失败',
          error: e);
      return false;
    }
  }

  /// 构建初始数据源配置
  static Future<Map<String, dynamic>> initializeDataSources({
    required dynamic dbProvider,
    Map<String, String>? moduleDataSources,
    String? dataSourceMode,
    User? currentUser,
  }) async {
    final mode =
        DataSourceMode.tryParse(dataSourceMode) ?? DataSourceMode.global;
    final configuredType = mode == DataSourceMode.modular
        ? DataSourceType.tryParse(
                moduleDataSources?[AppModule.patients.dataSourceConfigKey]) ??
            DataSourceType.sqlite
        : DataSourceType.tryParse(dbProvider.dataSourceType?.toString()) ??
            DataSourceType.sqlite;
    var effectiveType = configuredType;
    SqlitePatientDataSource? sqliteDS;
    MySqlPatientDataSource? mysqlDS;
    Database? database;
    MySqlConnection? mysqlConn;

    if (configuredType == DataSourceType.sqlite) {
      database = dbProvider.database;
      if (database != null) {
        sqliteDS = SqlitePatientDataSource(
          database,
          doctorName: currentUser?.doctor,
          isAdmin: currentUser?.isAdmin ?? false,
        );
      } else {
        LogManager.e('PatientInitializationService',
            'PatientInitializationService: SQLite数据库连接不可用');
      }
    } else if (configuredType == DataSourceType.mysql) {
      mysqlConn = dbProvider.mysqlConnection;
      if (mysqlConn != null) {
        mysqlDS = MySqlPatientDataSource.withConnectionGetter(
          () async => dbProvider.mysqlConnection,
          doctorName: currentUser?.doctor,
          isAdmin: currentUser?.isAdmin ?? false,
          reconnectCallback: () async {
            if (dbProvider != null) await dbProvider.initializeMySQL();
          },
        );

        // 验证 MySQL 连通性，失败则降级
        if (!await testMySqlConnection(mysqlConn)) {
          effectiveType = DataSourceType.sqlite;
          database = dbProvider.database;
          if (database != null) {
            sqliteDS = SqlitePatientDataSource(
              database,
              doctorName: currentUser?.doctor,
              isAdmin: currentUser?.isAdmin ?? false,
            );
          }
        } else {}
      } else {
        LogManager.w('PatientInitializationService',
            'PatientInitializationService: MySQL连接不可用，自动降级到SQLite');
        effectiveType = DataSourceType.sqlite;
        database = dbProvider.database;
        if (database != null) {
          sqliteDS = SqlitePatientDataSource(
            database,
            doctorName: currentUser?.doctor,
            isAdmin: currentUser?.isAdmin ?? false,
          );
        } else {
          LogManager.e('PatientInitializationService',
              'PatientInitializationService: 降级失败，SQLite数据库连接也不可用');
        }
      }
    }

    return {
      'effectiveType': effectiveType.storageValue,
      'sqliteDataSource': sqliteDS,
      'mysqlDataSource': mysqlDS,
      'database': database,
      'mysqlConnection': mysqlConn,
    };
  }

  /// 根据当前用户权限重新构建数据源
  static Map<String, dynamic> reinitializeWithUser({
    required String effectiveType,
    required User? user,
    required Database? database,
    required MySqlConnection? mysqlConnection,
    required Future<MySqlConnection?> Function() mysqlConnectionGetter,
    required Future<void> Function() onReconnect,
  }) {
    SqlitePatientDataSource? sqliteDS;
    MySqlPatientDataSource? mysqlDS;

    final doctor = user?.doctor;
    final isAdmin = user?.role == 'admin';

    final type = DataSourceType.parseOrThrow(effectiveType);
    if (type == DataSourceType.sqlite && database != null) {
      sqliteDS = SqlitePatientDataSource(database,
          doctorName: doctor, isAdmin: isAdmin);
    } else if (type == DataSourceType.mysql && mysqlConnection != null) {
      mysqlDS = MySqlPatientDataSource.withConnectionGetter(
        mysqlConnectionGetter,
        doctorName: doctor,
        isAdmin: isAdmin,
        reconnectCallback: onReconnect,
      );
    }

    return {
      'sqliteDataSource': sqliteDS,
      'mysqlDataSource': mysqlDS,
    };
  }
}

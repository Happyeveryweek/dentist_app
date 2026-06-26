import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../data_sources/patient_data_source.dart';
import '../../../models/user.dart';
import '../../../utils/log_manager.dart';

/// 患者模块初始化与数据源构建服务
class PatientInitializationService {
  /// 测试 MySQL 连接是否可用
  static Future<bool> testMySqlConnection(MySqlConnection? conn) async {
    if (conn == null) return false;
    try {
      await conn.query('SELECT 1').timeout(const Duration(seconds: 10));
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
    String dbType = 'sqlite';
    if (dataSourceMode == 'modular' && moduleDataSources != null) {
      final patientsType = moduleDataSources['patients'];
      if (patientsType != null) {
        dbType = patientsType;
      }
    } else {
      dbType = dbProvider.dataSourceType ?? 'sqlite';
    }

    String effectiveType = dbType;
    SqlitePatientDataSource? sqliteDS;
    MySqlPatientDataSource? mysqlDS;
    Database? database;
    MySqlConnection? mysqlConn;

    if (dbType == 'sqlite') {
      database = dbProvider.database;
      if (database != null) {
        sqliteDS =
            SqlitePatientDataSource(database, doctorName: null, isAdmin: true);
      } else {
        LogManager.e('PatientInitializationService',
            'PatientInitializationService: SQLite数据库连接不可用');
      }
    } else if (dbType == 'mysql') {
      mysqlConn = dbProvider.mysqlConnection;
      if (mysqlConn != null) {
        mysqlDS = MySqlPatientDataSource.withConnectionGetter(
          () async => dbProvider.mysqlConnection,
          doctorName: null,
          isAdmin: true,
          reconnectCallback: () async {
            if (dbProvider != null) await dbProvider.initializeMySQL();
          },
        );

        // 验证 MySQL 连通性，失败则降级
        if (!await testMySqlConnection(mysqlConn)) {
          effectiveType = 'sqlite';
          database = dbProvider.database;
          if (database != null) {
            sqliteDS = SqlitePatientDataSource(database,
                doctorName: null, isAdmin: true);
          }
        } else {}
      } else {
        LogManager.e('PatientInitializationService',
            'PatientInitializationService: MySQL连接不可用');
      }
    }

    return {
      'effectiveType': effectiveType,
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

    if (effectiveType == 'sqlite' && database != null) {
      sqliteDS = SqlitePatientDataSource(database,
          doctorName: doctor, isAdmin: isAdmin);
    } else if (effectiveType == 'mysql' && mysqlConnection != null) {
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

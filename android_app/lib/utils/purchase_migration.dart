import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import './app_logger.dart';

/// 采购记录数据库迁移工具
/// 用于为现有的采购记录表添加医生字段
class PurchaseMigration {
  /// 为SQLite数据库添加医生字段
  static Future<void> migrateSQLiteAddDoctorField(Database database) async {
    try {
      AppLogger.info('开始为SQLite采购记录表添加医生字段...');

      // 检查字段是否已存在
      final tableInfo = await database.rawQuery(
        'PRAGMA table_info(purchase_records)',
      );
      final hasDoctoField = tableInfo.any(
        (column) => column['name'] == 'doctor',
      );

      if (!hasDoctoField) {
        // 添加医生字段
        await database.execute(
          'ALTER TABLE purchase_records ADD COLUMN doctor TEXT',
        );
        AppLogger.info('✅ 成功为SQLite采购记录表添加医生字段');
      } else {
        AppLogger.info('ℹ️ SQLite采购记录表已包含医生字段，跳过迁移');
      }
    } catch (e) {
      AppLogger.info('❌ SQLite采购记录表添加医生字段失败: $e');
      rethrow;
    }
  }

  /// 为MySQL数据库添加医生字段
  static Future<void> migrateMySQLAddDoctorField(
    MySqlConnection connection,
  ) async {
    try {
      AppLogger.info('开始为MySQL采购记录表添加医生字段...');

      // 检查字段是否已存在
      final results = await connection.query('''
        SELECT COLUMN_NAME 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_NAME = 'purchase_records' AND COLUMN_NAME = 'doctor'
      ''');

      if (results.isEmpty) {
        // 添加医生字段
        await connection.query('''
          ALTER TABLE purchase_records 
          ADD COLUMN doctor VARCHAR(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL
        ''');
        AppLogger.info('✅ 成功为MySQL采购记录表添加医生字段');
      } else {
        AppLogger.info('ℹ️ MySQL采购记录表已包含医生字段，跳过迁移');
      }
    } catch (e) {
      AppLogger.info('❌ MySQL采购记录表添加医生字段失败: $e');
      rethrow;
    }
  }

  /// 自动检测并执行迁移
  static Future<void> autoMigrate({
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
  }) async {
    try {
      if (sqliteDatabase != null) {
        await migrateSQLiteAddDoctorField(sqliteDatabase);
      }

      if (mysqlConnection != null) {
        await migrateMySQLAddDoctorField(mysqlConnection);
      }

      AppLogger.info('🎉 采购记录数据库迁移完成');
    } catch (e) {
      AppLogger.info('❌ 采购记录数据库迁移失败: $e');
      rethrow;
    }
  }
}

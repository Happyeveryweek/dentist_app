import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../utils/log_manager.dart';

/// 采购记录表迁移工具
class PurchaseMigration {
  /// 为SQLite数据库添加doctor字段
  static Future<void> addDoctorFieldToSQLite(Database database) async {
    try {
      // 检查doctor字段是否已存在
      final result =
          await database.rawQuery("PRAGMA table_info(purchase_records)");
      final hasDoctoField = result.any((column) => column['name'] == 'doctor');

      if (!hasDoctoField) {
        await database
            .execute('ALTER TABLE purchase_records ADD COLUMN doctor TEXT');
      } else {
        // 字段已存在，静默跳过
        return;
      }
    } catch (e) {
      LogManager.e('PurchaseMigration', 'SQLite purchase_records表添加doctor字段失败',
          error: e);
      throw Exception('SQLite迁移失败: $e');
    }
  }

  /// 为MySQL数据库添加doctor字段
  static Future<void> addDoctorFieldToMySQL(MySqlConnection connection) async {
    try {
      // 检查doctor字段是否已存在
      final result = await connection.query(
          "SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'purchase_records' AND COLUMN_NAME = 'doctor'");

      if (result.isEmpty) {
        await connection.query(
            'ALTER TABLE purchase_records ADD COLUMN doctor VARCHAR(255)');
      } else {
        // 字段已存在，静默跳过
        return;
      }
    } catch (e) {
      LogManager.e('PurchaseMigration', 'MySQL purchase_records表添加doctor字段失败',
          error: e);
      throw Exception('MySQL迁移失败: $e');
    }
  }
}

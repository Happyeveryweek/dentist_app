import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import './app_logger.dart';

class DatabaseUtils {
  /// 关闭数据库
  static Future<void> closeDatabase(String path) async {
    // 不再主动关闭数据库，让DatabaseHelper管理数据库连接
    // 这样可以避免"database_closed"错误
  }

  /// 备份数据库到指定目录
  static Future<String> backupDatabase(
    String sourcePath,
    String destinationDir,
  ) async {
    try {
      // 确保源数据库存在
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('源数据库不存在: $sourcePath');
      }

      // 确保目标目录存在
      final destDir = Directory(destinationDir);
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      // 构建备份文件路径，添加时间戳
      final timestamp = DateTimeFormatter.toDbString(
        DateTime.now(),
      ).replaceAll(':', '-').replaceAll(' ', '_');
      final filename = 'dental_clinic_backup_$timestamp.db';
      final destPath = join(destinationDir, filename);

      // 不再尝试关闭数据库
      // 使用文件复制API
      try {
        await sourceFile.copy(destPath);
        return destPath;
      } catch (e) {
        if (e.toString().contains('Operation not permitted')) {
          debugPrint('权限错误，可能是Android 10+ 存储权限问题: $e');
          throw Exception('无法访问目标目录，请使用内置文件选择器');
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('备份数据库错误: $e');
      return '';
    }
  }

  /// 重置数据库（恢复出厂设置）
  static Future<bool> resetDatabase(String dbPath) async {
    try {
      // 删除数据库文件
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
      }

      // 创建新的空数据库
      final db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          // 创建患者表
          await db.execute('''
          CREATE TABLE IF NOT EXISTS patients (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medical_record_number INTEGER,
            name TEXT NOT NULL,
            age INTEGER NOT NULL,
            gender TEXT NOT NULL,
            phone TEXT NOT NULL,
            address TEXT,
            email TEXT,
            identification_number TEXT,
            doctor TEXT,
            first_visit_date TEXT NOT NULL,
            dental_condition TEXT,
            treatment_items TEXT,
            total_cost REAL DEFAULT 0.0,
            notes TEXT,
            birth_date TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
          ''');

          // 创建预约表
          await db.execute('''
          CREATE TABLE IF NOT EXISTS appointments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            appointment_date TEXT NOT NULL,
            status TEXT NOT NULL,
            treatment_type TEXT,
            notes TEXT,
            cost REAL DEFAULT 0.0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
          )
          ''');

          // 创建复诊表
          await db.execute('''
          CREATE TABLE IF NOT EXISTS follow_up_visits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            patient_id INTEGER NOT NULL,
            follow_up_date TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
          )
          ''');
        },
      );

      await db.close();
      return true;
    } catch (e) {
      debugPrint('重置数据库错误: $e');
      return false;
    }
  }

  /// 重置默认数据库并重新初始化
  static Future<bool> resetDefaultDatabase() async {
    try {
      final dbPath = await getDefaultDatabasePath();
      final success = await resetDatabase(dbPath);
      if (success) {
        debugPrint('默认数据库已重置并重新初始化');
      }
      return success;
    } catch (e) {
      debugPrint('重置默认数据库失败: $e');
      return false;
    }
  }

  /// 获取默认数据库路径
  static Future<String> getDefaultDatabasePath() async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbDir = join(documentsDir.path, 'databases');

      // 确保目录存在
      final dir = Directory(dbDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final defaultDbPath = join(dbDir, 'dental_clinic.db');

      // 如果数据库不存在，使用DatabaseHelper创建完整的数据库
      if (!await File(defaultDbPath).exists()) {
        AppLogger.info('默认数据库不存在，创建新的数据库: $defaultDbPath');

        // 设置自定义数据库路径
        DatabaseHelper.setCustomDbPath(defaultDbPath);

        // 通过DatabaseHelper创建数据库，这会自动创建所有表和默认用户
        final dbHelper = DatabaseHelper();
        final db = await dbHelper.database;
        await db.close();

        AppLogger.info('✅ 默认数据库创建完成，包含所有表和默认用户');
      }

      return defaultDbPath;
    } catch (e) {
      AppLogger.info('获取默认数据库路径错误: $e');
      return 'dental_clinic.db'; // 返回一个相对路径作为备用
    }
  }

  /// 仅导出患者表数据到指定目录
  static Future<String> exportPatientsTable(
    String sourcePath,
    String destinationDir,
  ) async {
    try {
      // 打开源数据库
      final db = await openDatabase(sourcePath);

      // 查询所有患者数据
      final List<Map<String, dynamic>> patients = await db.query('patients');

      // 构建备份文件路径，添加时间戳
      final timestamp = DateTimeFormatter.toDbString(
        DateTime.now(),
      ).replaceAll(':', '-').replaceAll(' ', '_');
      final filename = 'patients_backup_$timestamp.db';
      final destPath = join(destinationDir, filename);

      // 创建新数据库，只包含患者表
      final newDb = await openDatabase(
        destPath,
        version: 1,
        onCreate: (Database db, int version) async {
          // 创建患者表
          await db.execute('''
            CREATE TABLE patients (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              age INTEGER,
              gender TEXT,
              phone TEXT,
              address TEXT,
              identification_number TEXT,
              medical_record_number INTEGER,
              doctor TEXT,
              first_visit_date TEXT,
              dental_condition TEXT,
              treatment_items TEXT,
              total_cost REAL,
              created_at TEXT,
              updated_at TEXT
            )
          ''');

          // 插入所有患者数据
          for (var patient in patients) {
            await db.insert('patients', patient);
          }
        },
      );

      // 关闭数据库
      await newDb.close();
      await db.close();

      return destPath;
    } catch (e) {
      debugPrint('导出患者表错误: $e');
      return '';
    }
  }
}

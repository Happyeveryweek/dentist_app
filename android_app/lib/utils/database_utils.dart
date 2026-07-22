import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/models/database_config.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import './app_logger.dart';

class DatabaseUtils {
  /// 解析同步目标 SQLite 路径。
  ///
  /// 未选择自定义数据库时，配置中保存的是默认文件名占位值；此时必须
  /// 使用应用数据库目录下的完整路径，不能把相对路径交给 sqflite。
  static String resolveSqliteSyncPath({
    required String configuredPath,
    required String defaultPath,
  }) {
    final normalized = configuredPath.trim();
    if (usesDefaultSqliteSyncPath(normalized)) {
      return defaultPath;
    }
    return normalize(normalized);
  }

  static bool usesDefaultSqliteSyncPath(String configuredPath) {
    final normalized = configuredPath.trim();
    return normalized.isEmpty ||
        normalized == DatabaseDefaults.sqliteFileName ||
        !isAbsolute(normalized);
  }

  static String getSqliteSyncTargetLabel({
    required String configuredPath,
    required String resolvedPath,
  }) {
    final type =
        usesDefaultSqliteSyncPath(configuredPath) ? '默认 SQLite' : '自定义 SQLite';
    return '$type（${basename(resolvedPath)}）';
  }

  static Future<String> getSqliteSyncTargetPath(String configuredPath) async {
    final normalized = configuredPath.trim();
    if (!usesDefaultSqliteSyncPath(normalized)) {
      return normalize(normalized);
    }
    final defaultPath = await getDefaultDatabasePath();
    return resolveSqliteSyncPath(
      configuredPath: configuredPath,
      defaultPath: defaultPath,
    );
  }

  /// 关闭数据库
  static Future<void> closeDatabase(String path) async {
    // 不再主动关闭数据库，让DatabaseHelper管理数据库连接
    // 这样可以避免"database_closed"错误
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

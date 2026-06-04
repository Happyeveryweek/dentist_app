import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';

class DatabaseUtils {
  /// 初始化空数据库
  static Future<String> initEmptyDatabase(String dbName) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbPath = join(documentsDir.path, 'databases', dbName);

      // 确保目录存在
      final dbDir = Directory(dirname(dbPath));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }

      // 如果数据库不存在，创建一个空数据库
      if (!await File(dbPath).exists()) {
        // 打开数据库会自动创建
        final db = await openDatabase(dbPath, version: 1);
        await db.close();
      }

      return dbPath;
    } catch (e) {
      print('初始化空数据库错误: $e');
      return '';
    }
  }

  /// 复制测试数据库到应用文档目录
  static Future<String> copyTestDatabaseToDocuments() async {
    try {
      // 获取应用文档目录
      final documentsDir = await getApplicationDocumentsDirectory();
      final dbDir = join(documentsDir.path, 'databases');
      final testDbPath = join(dbDir, 'dental_clinic_test.db');

      // 确保目录存在
      final dir = Directory(dbDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      print('准备复制测试数据库到: $testDbPath');

      // 先尝试关闭可能存在的数据库实例
      try {
        print('尝试关闭所有打开的数据库连接');
        // 注意：sqflite不提供关闭所有数据库的方法，因此这里只能尝试关闭特定的数据库实例
        final db = await openDatabase(testDbPath, readOnly: true);
        await db.close();
        await Future.delayed(const Duration(milliseconds: 300));
        print('已关闭指定的数据库连接');
      } catch (e) {
        print('关闭数据库连接时发生错误: $e');
      }

      // 检查测试数据库是否已经存在
      final testDbFile = File(testDbPath);
      if (await testDbFile.exists()) {
        print('测试数据库已存在: $testDbPath');

        // 先删除现有测试数据库文件
        try {
          print('删除现有测试数据库文件');
          await testDbFile.delete();
          await Future.delayed(const Duration(milliseconds: 300));
          print('成功删除现有测试数据库文件');
        } catch (e) {
          print('删除现有测试数据库文件失败: $e');
        }
      }

      // 使用DatabaseHelper创建测试数据库
      try {
        print('测试数据库不存在，通过DatabaseHelper自动创建');
        
        // 使用DatabaseHelper创建数据库
        DatabaseHelper.setCustomDbPath(testDbPath);
        final dbHelper = DatabaseHelper();
        final db = await dbHelper.database;
        await db.close();
        
        print('成功通过DatabaseHelper创建测试数据库: $testDbPath');

        // 验证文件可访问性
        if (await testDbFile.exists()) {
          print('测试数据库文件已成功创建和验证');

          // 验证数据库完整性
          try {
            Database testDb = await openDatabase(testDbPath);
            try {
              // 测试查询
              final result = await testDb.rawQuery('SELECT 1');
              print('测试数据库连接测试成功: $result');
              await testDb.close();
            } catch (e) {
              print('测试数据库初始查询失败: $e');
              await testDb.close();
              throw e;
            }
          } catch (e) {
            print('测试数据库完整性验证失败: $e');
            throw e;
          }
        } else {
          print('无法验证测试数据库文件存在');
          throw Exception('测试数据库文件创建失败');
        }

        return testDbPath;
      } catch (e) {
        print('从assets加载测试数据库失败: $e，将创建新的测试数据库');

        // 如果从assets加载失败，创建一个带有测试数据的测试数据库
        print('开始创建新的测试数据库...');
        final db = await openDatabase(
          testDbPath,
          version: 1,
          onCreate: (Database db, int version) async {
            print('创建测试数据库表结构...');
            // 创建患者表 - 确保与models.py完全一致
            await db.execute('''
            CREATE TABLE patients (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              medical_record_number INTEGER,
              name TEXT NOT NULL,
              age INTEGER NOT NULL,
              gender TEXT NOT NULL,
              phone TEXT NOT NULL,
              address TEXT,
              identification_number TEXT,
              doctor TEXT,
              first_visit_date TEXT NOT NULL,
              dental_condition TEXT,
              treatment_items TEXT,
              total_cost REAL DEFAULT 0.0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
            ''');

            // 创建预约表 - 确保与models.py完全一致
            await db.execute('''
            CREATE TABLE appointments (
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

            // 创建复诊表 - 确保与models.py完全一致
            await db.execute('''
            CREATE TABLE follow_up_visits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              patient_id INTEGER NOT NULL,
              follow_up_date TEXT NOT NULL,
              notes TEXT,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (patient_id) REFERENCES patients (id) ON DELETE CASCADE
            )
            ''');

            print('测试数据库表结构创建完成，开始插入测试数据...');

            // 插入测试数据
            final now = DateTime.now();
            final yesterday = now.subtract(const Duration(days: 1));
            final tomorrow = now.add(const Duration(days: 1));

            print('插入测试患者数据...');
            // 添加测试患者
            await db.insert('patients', {
              'medical_record_number': 10001,
              'name': '张三',
              'age': 35,
              'gender': '男',
              'phone': '13800138000',
              'address': '北京市海淀区中关村大街1号',
              'identification_number': '110101198001010001',
              'doctor': '王医生',
              'first_visit_date': DateTimeFormatter.toDbString(yesterday),
              'dental_condition': '牙周炎',
              'treatment_items': '洗牙、根管治疗',
              'total_cost': 1200.0,
              'created_at': DateTimeFormatter.toDbString(yesterday),
              'updated_at': DateTimeFormatter.toDbString(now),
            });

            await db.insert('patients', {
              'medical_record_number': 10002,
              'name': '李四',
              'age': 28,
              'gender': '女',
              'phone': '13900139000',
              'address': '北京市朝阳区建国路2号',
              'identification_number': '110101199001010002',
              'doctor': '张医生',
              'first_visit_date': DateTimeFormatter.toDbString(yesterday),
              'dental_condition': '蛀牙',
              'treatment_items': '补牙',
              'total_cost': 500.0,
              'created_at': DateTimeFormatter.toDbString(yesterday),
              'updated_at': DateTimeFormatter.toDbString(now),
            });

            await db.insert('patients', {
              'medical_record_number': 10003,
              'name': '王五',
              'age': 18,
              'gender': '男',
              'phone': '13700137000',
              'address': '北京市西城区西长安街3号',
              'identification_number': '110101200001010003',
              'doctor': '李医生',
              'first_visit_date': DateTimeFormatter.toDbString(now),
              'dental_condition': '牙齿矫正',
              'treatment_items': '正畸治疗',
              'total_cost': 8000.0,
              'created_at': DateTimeFormatter.toDbString(now),
              'updated_at': DateTimeFormatter.toDbString(now),
            });

            // 测试多电话号码格式
            await db.insert('patients', {
              'medical_record_number': 10004,
              'name': '赵六',
              'age': 42,
              'gender': '男',
              'phone': '[\"13600136000\",\"13600136001\"]', // JSON格式保存多个号码
              'address': '北京市东城区东长安街4号',
              'identification_number': '110101198001010004',
              'doctor': '钱医生',
              'first_visit_date': DateTimeFormatter.toDbString(yesterday),
              'dental_condition': '牙齿美白',
              'treatment_items': '美白治疗',
              'total_cost': 2000.0,
              'created_at': DateTimeFormatter.toDbString(yesterday),
              'updated_at': DateTimeFormatter.toDbString(now),
            });

            print('插入测试预约数据...');
            // 添加测试预约
            await db.insert('appointments', {
              'patient_id': 1,
              'appointment_date': DateTimeFormatter.toDbString(now),
              'status': '已完成',
              'treatment_type': '洗牙',
              'notes': '常规洗牙',
              'cost': 200.0,
              'created_at': DateTimeFormatter.toDbString(yesterday),
              'updated_at': DateTimeFormatter.toDbString(yesterday),
            });

            await db.insert('appointments', {
              'patient_id': 2,
              'appointment_date': DateTimeFormatter.toDbString(tomorrow),
              'status': '已预约',
              'treatment_type': '根管治疗',
              'notes': '牙髓炎症',
              'cost': 1200.0,
              'created_at': DateTimeFormatter.toDbString(yesterday),
              'updated_at': DateTimeFormatter.toDbString(yesterday),
            });

            await db.insert('appointments', {
              'patient_id': 3,
              'appointment_date':
                  DateTimeFormatter.toDbString(tomorrow.add(const Duration(days: 1))),
              'status': '已预约',
              'treatment_type': '正畸调整',
              'notes': '定期调整牙套',
              'cost': 500.0,
              'created_at': DateTimeFormatter.toDbString(now),
              'updated_at': DateTimeFormatter.toDbString(now),
            });

            // 预约给有多电话号码的患者
            await db.insert('appointments', {
              'patient_id': 4,
              'appointment_date':
                  DateTimeFormatter.toDbString(tomorrow.add(const Duration(days: 2))),
              'status': '已预约',
              'treatment_type': '美白治疗',
              'notes': '第二次美白',
              'cost': 1500.0,
              'created_at': DateTimeFormatter.toDbString(now),
              'updated_at': DateTimeFormatter.toDbString(now),
            });

            print('插入测试复诊记录...');
            // 添加测试复诊记录
            await db.insert('follow_up_visits', {
              'patient_id': 1,
              'follow_up_date':
                  DateTimeFormatter.toDbString(tomorrow.add(const Duration(days: 30))),
              'notes': '一个月后复查',
              'created_at': DateTimeFormatter.toDbString(now),
              'updated_at': DateTimeFormatter.toDbString(now),
            });

            await db.insert('follow_up_visits', {
              'patient_id': 2,
              'follow_up_date':
                  DateTimeFormatter.toDbString(tomorrow.add(const Duration(days: 14))),
              'notes': '两周后复查根管治疗效果',
              'created_at': DateTimeFormatter.toDbString(now),
              'updated_at': DateTimeFormatter.toDbString(now),
            });
          },
        );

        await db.close();

        print('测试数据库已创建: $testDbPath');
        return testDbPath;
      }
    } catch (e) {
      print('复制测试数据库错误: $e');
      return '';
    }
  }

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
      final timestamp = DateTimeFormatter.toDbString(DateTime.now())
          .replaceAll(':', '-')
          .replaceAll(' ', '_');
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

  /// 从备份文件恢复数据库
  static Future<bool> restoreDatabase(
    String backupPath,
    String destPath,
  ) async {
    try {
      // 确保备份文件存在
      final backupFile = File(backupPath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在: $backupPath');
      }

      try {
        // 如果目标数据库存在，先删除它
        final destFile = File(destPath);
        if (await destFile.exists()) {
          await destFile.delete();
        }

        // 确保目标目录存在
        final destDir = Directory(dirname(destPath));
        if (!await destDir.exists()) {
          await destDir.create(recursive: true);
        }

        // 复制备份文件到目标路径
        await backupFile.copy(destPath);

        return true;
      } catch (e) {
        debugPrint('恢复数据库错误: $e');
        return false;
      }
    } catch (e) {
      debugPrint('恢复数据库错误: $e');
      return false;
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
        print('默认数据库不存在，创建新的数据库: $defaultDbPath');
        
        // 设置自定义数据库路径
        DatabaseHelper.setCustomDbPath(defaultDbPath);
        
        // 通过DatabaseHelper创建数据库，这会自动创建所有表和默认用户
        final dbHelper = DatabaseHelper();
        final db = await dbHelper.database;
        await db.close();
        
        print('✅ 默认数据库创建完成，包含所有表和默认用户');
      }

      return defaultDbPath;
    } catch (e) {
      print('获取默认数据库路径错误: $e');
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
      final timestamp = DateTimeFormatter.toDbString(DateTime.now())
          .replaceAll(':', '-')
          .replaceAll(' ', '_');
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

  Future<bool> testMySQLConnection(
    String host,
    String port,
    String database,
    String username,
    String password,
  ) async {
    try {
      print('测试MySQL连接 $host:$port/$database');
      final socket = await Socket.connect(
        host,
        int.parse(port),
        timeout: const Duration(seconds: 15),
        sourceAddress: InternetAddress.anyIPv4, // 指定使用IPv4
      );
      socket.destroy();
      return true;
    } catch (e) {
      print('MySQL连接测试失败: $e');
      return false;
    }
  }
}

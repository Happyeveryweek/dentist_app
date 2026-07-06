import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../utils/datetime_formatter.dart';
import '../utils/app_paths.dart';
import '../utils/log_manager.dart';

/// 数据库备份恢复服务
/// 职责：SQLite 和 MySQL 的备份恢复、SQL 语句处理
class DatabaseBackupService {
  final Database? sqliteDatabase;
  final MySqlConnection? mysqlConnection;
  final String dataSourceType;

  DatabaseBackupService({
    this.sqliteDatabase,
    this.mysqlConnection,
    required this.dataSourceType,
  });

  bool get _isSqliteDataSource => dataSourceType == 'sqlite';

  /// 统一备份接口
  Future<String> backupDatabase({
    String? backupPath,
    Function(String)? onLogSuccess,
    Function(String)? onLogFailure,
    String? backupDataSource,
    // MySQL 连接参数
    String? mysqlHost,
    int? mysqlPort,
    String? mysqlDatabase,
    String? mysqlUsername,
    String? mysqlPassword,
  }) async {
    try {
      // 使用传入的备份路径
      final userBackupPath = backupPath ?? '';

      if (userBackupPath.isEmpty) {
        const errorMsg = '请设置备份路径';
        if (onLogFailure != null) {
          onLogFailure(errorMsg);
        }
        throw Exception(errorMsg);
      }

      // 确保备份目录存在
      final userBackupDir = Directory(userBackupPath);
      if (!await userBackupDir.exists()) {
        try {
          await userBackupDir.create(recursive: true);
        } catch (dirError) {
          final errorMsg = '无法创建备份目录: $dirError';
          if (onLogFailure != null) {
            onLogFailure(errorMsg);
          }
          throw Exception(errorMsg);
        }
      }

      String finalBackupPath;

      // 根据备份数据源设置选择备份方法
      final targetDataSource = backupDataSource ?? dataSourceType;

      if (targetDataSource == 'mysql') {
        if (mysqlHost == null ||
            mysqlDatabase == null ||
            mysqlUsername == null) {
          throw Exception('MySQL 备份需要提供连接参数');
        }
        finalBackupPath = await backupMySQLDatabase(
          backupPath: userBackupPath,
          host: mysqlHost,
          port: mysqlPort ?? 3306,
          database: mysqlDatabase,
          username: mysqlUsername,
          password: mysqlPassword ?? '',
        );
      } else {
        finalBackupPath =
            await backupSQLiteDatabase(backupPath: userBackupPath);
      }

      // 备份成功，记录备份日志
      if (onLogSuccess != null) {
        onLogSuccess(finalBackupPath);
      }

      LogManager.i('DatabaseBackupService',
          '数据库备份完成: $finalBackupPath (数据源: $targetDataSource)');
      return finalBackupPath;
    } catch (e) {
      LogManager.e('DatabaseBackupService', '执行数据库备份时出错', error: e);
      rethrow;
    }
  }

  /// SQLite 数据库备份方法 - 使用文件复制
  Future<String> backupSQLiteDatabase({String? backupPath}) async {
    try {
      // 确保数据库连接已初始化
      final db = sqliteDatabase;
      if (db == null) {
        throw Exception('SQLite 数据库未初始化');
      }

      // 优先使用当前 SQLite 连接对应的真实文件路径，避免退回到默认数据目录
      String resolvedDbPath = db.path;
      if (resolvedDbPath.isEmpty) {
        try {
          resolvedDbPath = AppPaths.databasePath;
        } catch (e) {
          final dbDir = await getDatabasesPath();
          resolvedDbPath = path.join(dbDir, 'dentist_clinic.db');
        }
      }

      // 确保数据库文件存在
      if (!await File(resolvedDbPath).exists()) {
        throw Exception('数据库文件不存在: $resolvedDbPath');
      }

      // 使用传入的备份路径
      final userBackupPath = backupPath ?? '';

      if (userBackupPath.isEmpty) {
        throw Exception('未设置备份目录');
      }

      // 确保备份目录存在
      final backupDir = Directory(userBackupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // 生成备份文件名
      final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-');
      final backupFilePath =
          path.join(userBackupPath, 'sqlite_backup_$timestamp.db');

      // 尽量先把 WAL 内容落盘，避免复制出不完整快照。
      try {
        await db.execute('PRAGMA wal_checkpoint(FULL)');
      } catch (e) {
        LogManager.e('DatabaseBackupService', 'SQLite checkpoint 执行失败，继续复制文件',
            error: e);
      }

      // 复制数据库文件
      await File(resolvedDbPath).copy(backupFilePath);

      LogManager.w(
          'DatabaseBackupService', 'SQLite 数据库文件已备份到: $backupFilePath');
      return backupFilePath;
    } catch (e) {
      LogManager.e('DatabaseBackupService', 'SQLite 数据库备份出错', error: e);
      rethrow;
    }
  }

  /// MySQL 数据库备份
  Future<String> backupMySQLDatabase({
    String? backupPath,
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    if (mysqlConnection == null) {
      throw Exception('MySQL 连接未建立');
    }

    // 使用传入的备份路径或默认路径
    String userBackupPath = backupPath ?? '';
    if (userBackupPath.isEmpty) {
      try {
        userBackupPath = AppPaths.defaultBackupDirectory;
        LogManager.w(
            'DatabaseBackupService', '用户未设置备份路径，使用默认应用数据目录: $userBackupPath');
      } catch (e) {
        final dbDir = await getDatabasesPath();
        userBackupPath = path.join(dbDir, 'backups');
      }
    }

    // 确保备份目录存在
    final backupDir = Directory(userBackupPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // 生成备份文件名
    final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-');
    final backupFileName = 'backup_$timestamp.sql';
    final finalBackupPath = path.join(userBackupPath, backupFileName);

    // 使用 AppPaths 获取 mysqldump 工具路径
    final toolPath = AppPaths.mysqldumpExePath;

    // 构建命令参数列表
    final List<String> args = [
      '-h$host',
      '-P$port',
      '-u$username',
      '-p$password',
      '--default-character-set=utf8mb4',
      database,
      '--result-file=$finalBackupPath'
    ];

    LogManager.w('DatabaseBackupService',
        '执行 mysqldump 命令: $toolPath ${args.join(' ').replaceAll(password, '******')}');

    try {
      final result = await Process.run(
        toolPath,
        args,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );

      LogManager.w('DatabaseBackupService',
          'mysqldump 命令执行结果: exitCode=${result.exitCode}');

      if (result.exitCode != 0) {
        LogManager.e('DatabaseBackupService', '备份失败，错误输出',
            error: result.stderr);
        throw Exception('备份失败: ${result.stderr}');
      }

      return finalBackupPath;
    } catch (e) {
      LogManager.e('DatabaseBackupService', '执行备份命令时出错', error: e);
      throw Exception('备份失败: $e');
    }
  }

  /// 统一恢复接口
  Future<void> restoreDatabase(String filePath) async {
    try {
      final backupFile = File(filePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在');
      }

      if (dataSourceType == 'mysql') {
        await restoreFromMySQLDump(filePath);
      } else {
        // 检查文件扩展名
        if (path.extension(filePath).toLowerCase() == '.db') {
          await restoreSQLiteDatabase(filePath);
        } else {
          await restoreFromBackup(filePath);
        }
      }

      LogManager.i('DatabaseBackupService', '数据库恢复成功');
    } catch (e) {
      LogManager.e('DatabaseBackupService', '执行数据库恢复时出错', error: e);
      rethrow;
    }
  }

  /// SQLite 数据库恢复方法 - 使用文件复制
  Future<void> restoreSQLiteDatabase(String backupFilePath) async {
    try {
      if (!_isSqliteDataSource) {
        throw Exception('当前数据源不是 SQLite，不能执行 SQLite 文件恢复');
      }

      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在: $backupFilePath');
      }

      // 获取目标数据库文件路径
      String dbPath;
      try {
        dbPath = AppPaths.databasePath;
      } catch (e) {
        final dbDir = await getDatabasesPath();
        dbPath = path.join(dbDir, 'dentist_clinic.db');
      }

      final targetFile = File(dbPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }

      // 复制备份文件到数据库位置
      await backupFile.copy(dbPath);
    } catch (e) {
      rethrow;
    }
  }

  /// 从备份文件恢复数据库（JSON 格式）
  Future<void> restoreFromBackup(String backupFilePath) async {
    try {
      final backupFile = File(backupFilePath);
      if (!await backupFile.exists()) {
        throw Exception('备份文件不存在');
      }

      final backupData = jsonDecode(await backupFile.readAsString());

      final mysqlConnection = this.mysqlConnection;
      final sqliteDatabase = this.sqliteDatabase;

      if (dataSourceType == 'mysql' && mysqlConnection != null) {
        // 清空所有表
        final tables = await mysqlConnection.query('SHOW TABLES');
        for (var table in tables) {
          final values = table.values;
          final tableName = values != null && values.isNotEmpty
              ? values.first.toString()
              : '';
          if (tableName.isNotEmpty) {
            await mysqlConnection.query('TRUNCATE TABLE $tableName');
          }
        }

        // 恢复数据
        for (var entry in backupData.entries) {
          final tableName = entry.key;
          final records = entry.value as List;

          for (var record in records) {
            final fields = record.keys.join(', ');
            final placeholders = List.filled(record.length, '?').join(', ');
            final values = record.values.map((value) {
              // 处理 DateTime 字符串
              if (value is String && value.contains('T')) {
                try {
                  return DateTimeFormatter.fromDbString(value);
                } catch (e) {
                  return value;
                }
              }
              return value;
            }).toList();

            await mysqlConnection.query(
              'INSERT INTO $tableName ($fields) VALUES ($placeholders)',
              values,
            );
          }
        }
      } else if (sqliteDatabase != null) {
        // 清空所有表
        final tables = await sqliteDatabase.query('sqlite_master',
            where: 'type = ? AND name NOT LIKE ?',
            whereArgs: ['table', 'sqlite_%']);
        for (var table in tables) {
          final tableName = table['name'] as String;
          await sqliteDatabase.delete(tableName);
        }

        // 恢复数据
        for (var entry in backupData.entries) {
          final tableName = entry.key;
          final records = entry.value as List;

          for (var record in records) {
            final processedRecord = Map<String, dynamic>.from(record);
            processedRecord.forEach((key, value) {
              if (value is String && value.contains('T')) {
                try {
                  processedRecord[key] = DateTimeFormatter.fromDbString(value);
                } catch (e) {
                  // 如果解析失败，保持原值
                }
              }
            });

            await sqliteDatabase.insert(tableName, processedRecord);
          }
        }
      }
    } catch (e) {
      LogManager.e('DatabaseBackupService', '执行数据库恢复时出错', error: e);
      rethrow;
    }
  }

  /// 从 MySQL dump 恢复
  Future<MySQLRestoreResult> restoreFromMySQLDump(
    String dumpFilePath, {
    Function(String)? onLogOperation,
  }) async {
    final mysqlConnection = this.mysqlConnection;
    if (dataSourceType != 'mysql' || mysqlConnection == null) {
      throw Exception('当前数据源不是 MySQL 或连接未建立');
    }

    if (onLogOperation != null) {
      onLogOperation('MySQL 还原开始: $dumpFilePath');
    }

    try {
      final dumpFile = File(dumpFilePath);
      if (!await dumpFile.exists()) {
        throw Exception('备份文件不存在: $dumpFilePath');
      }

      // 读取 SQL 文件内容
      String sqlContent;
      try {
        sqlContent = await dumpFile.readAsString(encoding: utf8);
      } catch (e) {
        LogManager.e('DatabaseBackupService', 'UTF-8 读取文件失败，尝试 Latin1 编码',
            error: e);
        final bytes = await dumpFile.readAsBytes();
        sqlContent = latin1.decode(bytes);
      }

      LogManager.i(
          'DatabaseBackupService', 'SQL 文件读取成功，大小: ${sqlContent.length} 字符');

      // 分割 SQL 语句并执行
      List<String> statements = _splitSqlStatements(sqlContent);
      LogManager.w(
          'DatabaseBackupService', '分割出 ${statements.length} 条 SQL 语句');

      int successCount = 0;
      int failCount = 0;
      final failedStatements = <String>[];

      // 禁用外键约束检查
      try {
        await mysqlConnection.query('SET FOREIGN_KEY_CHECKS = 0');
      } catch (e) {
        LogManager.e('DatabaseBackupService', '禁用外键约束检查失败', error: e);
      }

      // 执行每条 SQL 语句
      for (int i = 0; i < statements.length; i++) {
        String statement = statements[i].trim();
        if (statement.isEmpty || statement.startsWith('--')) {
          continue;
        }

        try {
          await mysqlConnection.query(statement);
          successCount++;

          if (i % 20 == 0 || i == statements.length - 1) {
            LogManager.w('DatabaseBackupService',
                '已执行 ${i + 1}/${statements.length} 条 SQL 语句');
          }
        } catch (e) {
          failCount++;
          if (failedStatements.length < 5) {
            failedStatements.add(
              statement.length > 200
                  ? '${statement.substring(0, 200)}...'
                  : statement,
            );
          }
          LogManager.e('DatabaseBackupService', '执行 SQL 语句失败', error: e);
          LogManager.w('DatabaseBackupService',
              '问题语句: ${statement.length > 100 ? "${statement.substring(0, 100)}..." : statement}');
        }
      }

      // 重新启用外键约束检查
      try {
        await mysqlConnection.query('SET FOREIGN_KEY_CHECKS = 1');
      } catch (e) {
        LogManager.e('DatabaseBackupService', '重新启用外键约束检查失败', error: e);
      }

      LogManager.w('DatabaseBackupService', 'MySQL 数据库已从文件还原: $dumpFilePath');
      LogManager.e('DatabaseBackupService',
          '成功执行: $successCount 条语句，失败: $failCount 条语句');

      final result = MySQLRestoreResult(
        totalStatements: successCount + failCount,
        successCount: successCount,
        failedCount: failCount,
        failedStatements: failedStatements,
      );

      if (onLogOperation != null) {
        onLogOperation(
          'MySQL 还原完成: ${result.isSuccess ? '成功' : '失败'}，成功 $successCount 条，失败 $failCount 条',
        );
      }

      if (!result.isSuccess) {
        final sample =
            failedStatements.isEmpty ? '' : '，示例语句: ${failedStatements.first}';
        throw Exception(
          'MySQL 还原未完成：共 ${result.totalStatements} 条，成功 $successCount 条，失败 $failCount 条$sample',
        );
      }

      return result;
    } catch (e) {
      LogManager.e('DatabaseBackupService', '执行 MySQL 还原时出错', error: e);
      rethrow;
    }
  }

  /// 分割 SQL 转储文件中的 SQL 语句
  List<String> _splitSqlStatements(String sqlDump) {
    List<String> statements = [];
    StringBuffer currentStatement = StringBuffer();
    bool inString = false;
    bool inComment = false;
    bool inMultiLineComment = false;

    for (int i = 0; i < sqlDump.length; i++) {
      String char = sqlDump[i];
      String nextChar = i < sqlDump.length - 1 ? sqlDump[i + 1] : '';

      // 处理多行注释
      if (!inString && char == '/' && nextChar == '*' && !inComment) {
        inMultiLineComment = true;
        currentStatement.write(char);
        currentStatement.write(nextChar);
        i++;
        continue;
      }

      if (inMultiLineComment && char == '*' && nextChar == '/') {
        inMultiLineComment = false;
        currentStatement.write(char);
        currentStatement.write(nextChar);
        i++;
        continue;
      }

      if (inMultiLineComment) {
        currentStatement.write(char);
        continue;
      }

      // 处理单行注释
      if (!inString &&
          char == '-' &&
          nextChar == '-' &&
          !inComment &&
          !inMultiLineComment) {
        inComment = true;
        currentStatement.write(char);
        currentStatement.write(nextChar);
        i++;
        continue;
      }

      if (inComment && (char == '\n' || char == '\r')) {
        inComment = false;
        currentStatement.write(char);
        continue;
      }

      if (inComment) {
        currentStatement.write(char);
        continue;
      }

      // 处理字符串
      if (char == '\'' && !inComment && !inMultiLineComment) {
        if (inString && nextChar == '\'') {
          currentStatement.write(char);
          currentStatement.write(nextChar);
          i++;
          continue;
        }
        inString = !inString;
        currentStatement.write(char);
        continue;
      }

      // 语句结束
      if (char == ';' && !inString && !inComment && !inMultiLineComment) {
        currentStatement.write(char);
        String statement = currentStatement.toString().trim();
        if (statement.isNotEmpty) {
          statements.add(statement);
        }
        currentStatement = StringBuffer();
        continue;
      }

      currentStatement.write(char);
    }

    String lastStatement = currentStatement.toString().trim();
    if (lastStatement.isNotEmpty) {
      statements.add(lastStatement);
    }

    return statements;
  }
}

class MySQLRestoreResult {
  final int totalStatements;
  final int successCount;
  final int failedCount;
  final List<String> failedStatements;

  const MySQLRestoreResult({
    required this.totalStatements,
    required this.successCount,
    required this.failedCount,
    required this.failedStatements,
  });

  bool get isSuccess => failedCount == 0 && successCount > 0;
}

import 'dart:io';
import 'package:file_picker/file_picker.dart';

import '../../../providers/database_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/backup_log.dart';
import 'package:dentist_app_windows/utils/log_manager.dart';

/// 备份恢复服务
/// 负责数据库备份和恢复的业务逻辑
class BackupRestoreService {
  final DatabaseProvider _dbProvider;
  final SettingsProvider _settingsProvider;

  BackupRestoreService({
    required DatabaseProvider dbProvider,
    required SettingsProvider settingsProvider,
  })  : _dbProvider = dbProvider,
        _settingsProvider = settingsProvider;

  /// 执行备份操作
  ///
  /// [path1] 第一个备份路径
  /// [path2] 第二个备份路径
  ///
  /// 返回备份成功的路径列表
  Future<BackupResult> performBackup({
    required String path1,
    required String path2,
  }) async {
    LogManager.i('BackupRestoreService', '开始执行备份操作，路径1: $path1, 路径2: $path2');

    // 如果两个路径都为空，提示用户至少设置一个
    if (path1.isEmpty && path2.isEmpty) {
      return BackupResult(
        success: false,
        errorMessage: '请至少设置一个备份目录后再执行备份',
        successPaths: [],
      );
    }

    bool backupSuccess = false;
    String errorMessage = '';
    List<String> successPaths = [];

    // 执行备份到第一个目录
    if (path1.isNotEmpty) {
      try {
        // 确保目录存在
        Directory directory = Directory(path1);
        if (!directory.existsSync()) {
          try {
            directory.createSync(recursive: true);
          } catch (e) {
            throw Exception('无法创建目录: $e');
          }
        }

        await _settingsProvider.setBackupPath(path1);

        // 先验证备份路径
        final isValid = await _settingsProvider.validateBackupPath(path1);
        if (!isValid) {
          throw Exception('备份路径无效: $path1');
        }

        // 执行备份
        final backupPath = await _dbProvider.backupDatabase(
          backupPath: path1,
          onLogSuccess: (path) => _settingsProvider.logBackupSuccess(path),
          onLogFailure: (error) => _settingsProvider.logBackupFailure(error),
          backupDataSource: _settingsProvider.backupDataSource,
        );

        // 更新备份日期
        await _settingsProvider.updateLastBackupDate(DateTime.now());
        backupSuccess = true;
        successPaths.add(backupPath);
      } catch (e) {
        LogManager.e('BackupRestoreService', '备份到目录1失败', error: e);
        errorMessage = '备份到目录1失败: $e';

        // 记录失败日志
        await BackupLog.addLog(BackupLog(
          backupDate: DateTime.now(),
          backupPath: path1,
          success: false,
          errorMessage: e.toString(),
        ));
      }
    } else {
      // 备份目录1为空，记录日志
      await BackupLog.addLog(BackupLog(
        backupDate: DateTime.now(),
        backupPath: '未设置备份目录1',
        success: false,
        errorMessage: '备份目录1为空，跳过备份',
      ));
    }

    // 执行备份到第二个目录
    if (path2.isNotEmpty) {
      try {
        // 确保目录存在
        Directory directory = Directory(path2);
        if (!directory.existsSync()) {
          try {
            directory.createSync(recursive: true);
          } catch (e) {
            throw Exception('无法创建目录: $e');
          }
        }

        await _settingsProvider.setBackupPath(path2);

        // 先验证备份路径
        final isValid = await _settingsProvider.validateBackupPath(path2);
        if (!isValid) {
          throw Exception('备份路径无效: $path2');
        }

        // 执行备份到第二个目录
        final backupPath2 = await _dbProvider.backupDatabase(
          backupPath: path2,
          onLogSuccess: (path) => _settingsProvider.logBackupSuccess(path),
          onLogFailure: (error) => _settingsProvider.logBackupFailure(error),
          backupDataSource: _settingsProvider.backupDataSource,
        );

        // 更新备份日期
        await _settingsProvider.updateLastBackupDate(DateTime.now());

        backupSuccess = true;
        successPaths.add(backupPath2);
      } catch (e) {
        LogManager.e('BackupRestoreService', '备份到目录2失败', error: e);
        if (errorMessage.isNotEmpty) {
          errorMessage += '\n';
        }
        errorMessage += '备份到目录2失败: $e';

        // 记录失败日志
        await BackupLog.addLog(BackupLog(
          backupDate: DateTime.now(),
          backupPath: path2,
          success: false,
          errorMessage: e.toString(),
        ));
      }
    } else {
      // 备份目录2为空，记录日志
      await BackupLog.addLog(BackupLog(
        backupDate: DateTime.now(),
        backupPath: '未设置备份目录2',
        success: false,
        errorMessage: '备份目录2为空，跳过备份',
      ));
    }

    // 恢复到第一个备份路径（如果有）
    if (path1.isNotEmpty) {
      await _settingsProvider.setBackupPath(path1);
    } else if (path2.isNotEmpty) {
      await _settingsProvider.setBackupPath(path2);
    }

    // 根据备份结果显示不同的提示
    if (!backupSuccess) {
      LogManager.e('BackupRestoreService', '备份失败，错误信息', error: errorMessage);
      return BackupResult(
        success: false,
        errorMessage: errorMessage.isEmpty ? '备份失败' : errorMessage,
        successPaths: successPaths,
      );
    }

    return BackupResult(
      success: true,
      errorMessage: null,
      successPaths: successPaths,
    );
  }

  /// 选择备份文件
  ///
  /// 返回选中的文件路径，如果用户取消则返回 null
  Future<String?> selectBackupFile() async {
    final isMySQL = _settingsProvider.dataSourceType == 'mysql';

    // 根据数据源类型选择不同的文件扩展名
    final allowedExtensions = isMySQL ? ['sql'] : ['db', 'sqlite', 'sqlite3'];
    final dialogTitle = isMySQL ? '选择MySQL备份文件(.sql)' : '选择SQLite备份文件(.db)';

    // 使用FilePicker选择备份文件
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      dialogTitle: dialogTitle,
    );

    if (result == null || result.files.isEmpty) {
      // 用户取消了选择
      return null;
    }

    return result.files.single.path;
  }

  /// 验证备份文件
  ///
  /// [filePath] 文件路径
  ///
  /// 返回验证结果，如果验证失败则返回错误信息
  Future<String?> validateBackupFile(String filePath) async {
    // 检查文件是否存在
    final file = File(filePath);
    if (!await file.exists()) {
      return '文件不存在';
    }

    final isMySQL = _settingsProvider.dataSourceType == 'mysql';

    // 验证文件类型
    if (isMySQL && !filePath.toLowerCase().endsWith('.sql')) {
      return '请选择.sql格式的MySQL备份文件';
    } else if (!isMySQL &&
        !filePath.toLowerCase().endsWith('.db') &&
        !filePath.toLowerCase().endsWith('.sqlite') &&
        !filePath.toLowerCase().endsWith('.sqlite3')) {
      return '请选择.db/.sqlite/.sqlite3格式的SQLite备份文件';
    }

    return null; // 验证通过
  }

  /// 执行恢复操作
  ///
  /// [filePath] 备份文件路径
  ///
  /// 返回恢复结果
  Future<RestoreResult> performRestore(String filePath) async {
    final isMySQL = _settingsProvider.dataSourceType == 'mysql';

    try {
      if (isMySQL) {
        // MySQL 恢复使用 mysql.exe
        final mysqlSettings = _settingsProvider.getCompleteMySQLSettings();

        // 先验证还原策略
        final isValid = await _settingsProvider.validateRestoreStrategy(
          filePath: filePath,
          targetDataSource: 'mysql',
        );

        if (!isValid) {
          throw Exception('还原策略验证失败');
        }

        // 创建还原前备份
        final preBackup = await _settingsProvider.createPreRestoreBackup();

        // 执行还原
        await _dbProvider.restoreFromMySQLDump(
          filePath,
          mysqlSettings: mysqlSettings,
          onLogOperation: (message) =>
              LogManager.i('BackupRestoreService', 'MySQL还原: $message'),
        );

        // 还原后清理
        await _settingsProvider.cleanupAfterRestore(
          success: true,
          restorePath: filePath,
          preRestoreBackupPath: preBackup,
        );

        // 记录还原操作
        await _settingsProvider.logRestoreOperation(
          operation: 'MySQL还原完成',
          filePath: filePath,
          success: true,
          preRestoreBackupPath: preBackup,
        );
      } else {
        // SQLite 恢复使用原有方法
        await _dbProvider.restoreDatabase(filePath);
      }

      return RestoreResult(
        success: true,
        errorMessage: null,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        errorMessage: e.toString(),
      );
    }
  }
}

/// 备份结果
class BackupResult {
  final bool success;
  final String? errorMessage;
  final List<String> successPaths;

  BackupResult({
    required this.success,
    required this.errorMessage,
    required this.successPaths,
  });
}

/// 恢复结果
class RestoreResult {
  final bool success;
  final String? errorMessage;

  RestoreResult({
    required this.success,
    required this.errorMessage,
  });
}

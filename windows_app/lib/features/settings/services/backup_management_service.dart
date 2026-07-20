import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dentist_app_windows/models/backup_log.dart';
import 'package:dentist_app_windows/utils/log_manager.dart';
import 'package:dentist_app_windows/models/data_source.dart';

/// 备份管理服务
/// 负责应用的备份和还原管理
class BackupManagementService {
  String _backupPath = '';
  String _backupPath2 = '';
  bool _autoBackup = false;
  int _backupInterval = 5;
  DateTime? _lastBackupDate;

  String get backupPath => _backupPath;
  String get backupPath2 => _backupPath2;
  bool get autoBackup => _autoBackup;
  int get backupInterval => _backupInterval;
  DateTime? get lastBackupDate => _lastBackupDate;

  /// 更新备份路径
  void updateBackupPaths({
    required String primaryPath,
    String? secondaryPath,
  }) {
    _backupPath = primaryPath;
    if (secondaryPath != null) {
      _backupPath2 = secondaryPath;
    }
  }

  /// 更新自动备份设置
  void updateAutoBackupSettings({
    required bool autoBackup,
    required int backupInterval,
    DateTime? lastBackupDate,
  }) {
    _autoBackup = autoBackup;
    _backupInterval = backupInterval;
    if (lastBackupDate != null) {
      _lastBackupDate = lastBackupDate;
    }
  }

  /// 备份日志管理 - 记录备份成功
  Future<void> logBackupSuccess(String backupPath) async {
    try {
      final log = BackupLog(
        backupDate: DateTime.now(),
        backupPath: backupPath,
        success: true,
      );

      await BackupLog.addLog(log);
    } catch (e) {
      LogManager.e('BackupManagementService', '记录备份成功日志出错', error: e);
    }
  }

  /// 备份日志管理 - 记录备份失败
  Future<void> logBackupFailure(String errorMessage) async {
    try {
      final log = BackupLog(
        backupDate: DateTime.now(),
        backupPath: '',
        success: false,
        errorMessage: errorMessage,
      );

      await BackupLog.addLog(log);
      LogManager.e('BackupManagementService', '已记录备份失败日志', error: errorMessage);
    } catch (e) {
      LogManager.e('BackupManagementService', '记录备份失败日志出错', error: e);
    }
  }

  /// 备份路径验证和管理
  Future<bool> validateBackupPath(String backupPath) async {
    LogManager.d('BackupManagementService', '验证备份路径: $backupPath');
    try {
      if (backupPath.isEmpty) return false;

      final directory = Directory(backupPath);

      // 检查目录是否存在，如果不存在则尝试创建
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
        } catch (e) {
          LogManager.e('BackupManagementService', '无法创建备份目录', error: e);
          return false;
        }
      }

      // 检查目录是否可写
      try {
        final testFile = File(path.join(backupPath, 'test_write.tmp'));
        await testFile.writeAsString('测试写入权限');
        await testFile.delete();

        return true;
      } catch (e) {
        LogManager.e('BackupManagementService', '备份目录写入权限验证失败', error: e);
        return false;
      }
    } catch (e) {
      LogManager.e('BackupManagementService', '验证备份路径时出错', error: e);
      return false;
    }
  }

  /// 获取备份文件列表
  Future<List<FileSystemEntity>> getBackupFiles() async {
    try {
      if (_backupPath.isEmpty) return [];

      final directory = Directory(_backupPath);
      if (!await directory.exists()) return [];

      final files = await directory
          .list()
          .where((entity) =>
              entity is File &&
              (entity.path.endsWith('.db') || entity.path.endsWith('.sql')))
          .toList();

      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        return File(b.path)
            .lastModifiedSync()
            .compareTo(File(a.path).lastModifiedSync());
      });

      return files;
    } catch (e) {
      LogManager.e('BackupManagementService', '获取备份文件列表时出错', error: e);
      return [];
    }
  }

  /// 检查备份路径状态
  Future<Map<String, bool>> checkBackupPathStatus() async {
    final primaryStatus = await validateBackupPath(_backupPath);
    final secondaryStatus =
        _backupPath2.isNotEmpty ? await validateBackupPath(_backupPath2) : true;

    return {
      'primary': primaryStatus,
      'secondary': secondaryStatus,
      'hasValidPath': primaryStatus || secondaryStatus,
    };
  }

  /// =================== 备份还原管理功能 ===================

  Future<bool> validateRestorePath(String restorePath) async {
    try {
      if (restorePath.isEmpty) return false;

      final file = File(restorePath);

      // 检查文件是否存在
      if (!await file.exists()) {
        return false;
      }

      // 检查文件是否可读
      RandomAccessFile? handle;
      try {
        handle = await file.open(mode: FileMode.read);
        await handle.read(1);

        return true;
      } catch (e) {
        LogManager.e('BackupManagementService', '还原文件读取权限验证失败', error: e);
        return false;
      } finally {
        await handle?.close();
      }
    } catch (e) {
      LogManager.e('BackupManagementService', '验证还原路径时出错', error: e);
      return false;
    }
  }

  /// 还原前备份策略
  Future<String?> createPreRestoreBackup({
    required Future<String> Function({
      String? backupPath,
      String? backupDataSource,
    }) executeBackup,
    required String backupDataSource,
  }) async {
    LogManager.i('BackupManagementService', '开始创建还原前备份');
    try {
      if (_backupPath.isEmpty) {
        LogManager.e('BackupManagementService', '未设置备份路径，无法创建还原前备份');
        return null;
      }

      // 确保备份目录存在
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      final backupPath = await executeBackup(
        backupPath: _backupPath,
        backupDataSource: backupDataSource,
      );
      LogManager.i('BackupManagementService', '已创建真实的还原前备份: $backupPath');
      return backupPath;
    } catch (e) {
      LogManager.e('BackupManagementService', '创建还原前备份失败', error: e);
      return null;
    }
  }

  /// 还原后清理策略
  Future<void> cleanupAfterRestore({
    required bool success,
    String? restorePath,
    String? preRestoreBackupPath,
  }) async {
    try {
      if (success) {
        // 还原成功，可以清理临时文件
        if (preRestoreBackupPath != null &&
            await File(preRestoreBackupPath).exists()) {
          // 可以选择保留或删除还原前备份
          // await File(preRestoreBackupPath).delete();
        }
      } else {
        // 还原失败，保留还原前备份
        if (preRestoreBackupPath != null) {
          LogManager.e('BackupManagementService', '还原失败，还原前备份保留在',
              error: preRestoreBackupPath);
        }
      }
    } catch (e) {
      LogManager.e('BackupManagementService', '还原后清理时出错', error: e);
    }
  }

  /// 还原文件类型检测
  String detectRestoreFileType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();

    switch (extension) {
      case '.db':
      case '.sqlite':
      case '.sqlite3':
        return 'sqlite';
      case '.sql':
        return 'mysql';
      default:
        return 'unknown';
    }
  }

  /// 获取还原文件信息
  Future<Map<String, dynamic>> getRestoreFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return {'error': '文件不存在'};
      }

      final stat = await file.stat();
      final fileType = detectRestoreFileType(filePath);

      return {
        'path': filePath,
        'name': path.basename(filePath),
        'size': stat.size,
        'modified': stat.modified,
        'type': fileType,
        'readable': true,
      };
    } catch (e) {
      return {'error': '获取文件信息失败: $e'};
    }
  }

  /// 还原历史记录管理
  Future<void> logRestoreOperation({
    required String operation,
    required String filePath,
    required bool success,
    String? errorMessage,
    String? preRestoreBackupPath,
  }) async {
    try {
      // 这里可以记录还原操作到日志中
      // 目前先打印日志，后续可以扩展为持久化存储

      if (errorMessage != null) {
        LogManager.e('BackupManagementService', '错误信息', error: errorMessage);
      }
      if (preRestoreBackupPath != null) {}
    } catch (e) {
      LogManager.e('BackupManagementService', '记录还原操作时出错', error: e);
    }
  }

  /// 还原策略验证
  Future<bool> validateRestoreStrategy({
    required String filePath,
    required String targetDataSource,
  }) async {
    try {
      // 检查文件类型是否匹配数据源
      final fileType = detectRestoreFileType(filePath);

      if (targetDataSource.isMySqlDataSource && !fileType.isMySqlDataSource) {
        return false;
      }

      if (targetDataSource.isSqliteDataSource && !fileType.isSqliteDataSource) {
        return false;
      }

      // 检查文件是否有效
      final fileInfo = await getRestoreFileInfo(filePath);
      if (fileInfo.containsKey('error')) {
        return false;
      }

      // 检查备份路径状态
      final backupStatus = await checkBackupPathStatus();
      if (backupStatus['hasValidPath'] != true) {
        LogManager.e('BackupManagementService', '备份路径无效，无法创建还原前备份');
        return false;
      }

      return true;
    } catch (e) {
      LogManager.e('BackupManagementService', '验证还原策略时出错', error: e);
      return false;
    }
  }
}

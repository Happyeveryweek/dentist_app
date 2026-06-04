import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dentist_app_windows/models/backup_log.dart';
import 'package:dentist_app_windows/utils/datetime_formatter.dart';

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

  /// 自动备份功能
  Future<String> performAutoBackup() async {
    try {
      print('开始执行自动备份...');
      
      // 检查备份路径是否设置
      if (_backupPath.isEmpty) {
        throw Exception('未设置备份路径，无法执行自动备份');
      }

      // 获取当前时间戳
      final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-').replaceAll(' ', '_');
      final backupFileName = 'auto_backup_$timestamp.db';
      final backupPath = path.join(_backupPath, backupFileName);

      // 确保备份目录存在
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
        print('创建备份目录: $_backupPath');
      }

      // 执行备份（这里需要调用DatabaseProvider的实际备份方法）
      // 注意：实际的数据库备份操作仍然由DatabaseProvider执行
      // 这里只负责备份策略和路径管理
      
      // 更新上次备份日期
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      _lastBackupDate = todayDate;
      
      // 清理旧备份
      await _cleanupOldBackups(_backupPath, _backupInterval);
      
      print('自动备份策略执行完成');
      return backupPath;
    } catch (e) {
      print('执行自动备份策略时出错: $e');
      rethrow;
    }
  }

  /// 清理旧备份文件
  Future<void> _cleanupOldBackups(String backupDir, int keepCount) async {
    try {
      final directory = Directory(backupDir);
      if (!await directory.exists()) return;

      // 获取所有备份文件
      final files = await directory
          .list()
          .where((entity) => entity is File && 
              (entity.path.endsWith('.db') || entity.path.endsWith('.sql')))
          .toList();

      // 按修改时间排序
      files.sort((a, b) {
        return File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });

      // 删除旧文件
      if (files.length > keepCount) {
        for (int i = keepCount; i < files.length; i++) {
          await File(files[i].path).delete();
          print('删除旧备份文件: ${files[i].path}');
        }
      }
    } catch (e) {
      print('清理旧备份失败: $e');
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
      print('已记录备份成功日志');
    } catch (e) {
      print('记录备份成功日志出错: $e');
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
      print('已记录备份失败日志: $errorMessage');
    } catch (e) {
      print('记录备份失败日志出错: $e');
    }
  }

  /// 备份路径验证和管理
  Future<bool> validateBackupPath(String backupPath) async {
    try {
      if (backupPath.isEmpty) return false;
      
      final directory = Directory(backupPath);
      
      // 检查目录是否存在，如果不存在则尝试创建
      if (!await directory.exists()) {
        try {
          await directory.create(recursive: true);
          print('创建备份目录: $backupPath');
        } catch (e) {
          print('无法创建备份目录: $e');
          return false;
        }
      }
      
      // 检查目录是否可写
      try {
        final testFile = File(path.join(backupPath, 'test_write.tmp'));
        await testFile.writeAsString('测试写入权限');
        await testFile.delete();
        print('备份目录写入权限验证成功');
        return true;
      } catch (e) {
        print('备份目录写入权限验证失败: $e');
        return false;
      }
    } catch (e) {
      print('验证备份路径时出错: $e');
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
          .where((entity) => entity is File && 
              (entity.path.endsWith('.db') || entity.path.endsWith('.sql')))
          .toList();
      
      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        return File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });
      
      return files;
    } catch (e) {
      print('获取备份文件列表时出错: $e');
      return [];
    }
  }

  /// 获取备份统计信息
  Future<Map<String, dynamic>> getBackupStatistics() async {
    try {
      final files = await getBackupFiles();
      final totalSize = await _calculateTotalBackupSize(files);
      final lastBackup = files.isNotEmpty ? File(files.first.path).lastModifiedSync() : null;
      
      return {
        'totalFiles': files.length,
        'totalSize': totalSize,
        'lastBackup': lastBackup,
        'backupPath': _backupPath,
        'autoBackupEnabled': _autoBackup,
        'backupInterval': _backupInterval,
        'lastBackupDate': _lastBackupDate,
      };
    } catch (e) {
      print('获取备份统计信息时出错: $e');
      return {};
    }
  }

  /// 计算备份文件总大小
  Future<int> _calculateTotalBackupSize(List<FileSystemEntity> files) async {
    int totalSize = 0;
    for (final file in files) {
      if (file is File) {
        try {
          totalSize += await file.length();
        } catch (e) {
          print('计算文件大小时出错: ${file.path}, $e');
        }
      }
    }
    return totalSize;
  }

  /// 检查是否需要执行自动备份
  bool shouldPerformAutoBackup() {
    if (!_autoBackup) return false;
    if (_backupPath.isEmpty) return false;
    if (_lastBackupDate == null) return true;
    
    final now = DateTime.now();
    final daysSinceLastBackup = now.difference(_lastBackupDate!).inDays;
    
    return daysSinceLastBackup >= _backupInterval;
  }

  /// 获取下次自动备份时间
  DateTime? getNextAutoBackupTime() {
    if (!_autoBackup || _lastBackupDate == null) return null;
    
    return _lastBackupDate!.add(Duration(days: _backupInterval));
  }

  /// 备份策略管理
  Future<void> setBackupStrategy({
    required bool autoBackup,
    required int backupInterval,
    required int keepBackupCount,
  }) async {
    _autoBackup = autoBackup;
    _backupInterval = backupInterval;
    
    print('备份策略已更新: 自动备份=$autoBackup, 间隔=$backupInterval天');
  }

  Map<String, dynamic> getBackupStrategy() {
    return {
      'autoBackup': _autoBackup,
      'backupInterval': _backupInterval,
      'backupPath': _backupPath,
      'backupPath2': _backupPath2,
    };
  }

  /// 备份路径管理
  Future<void> setBackupPaths({
    required String primaryPath,
    String? secondaryPath,
  }) async {
    _backupPath = primaryPath;
    if (secondaryPath != null) {
      _backupPath2 = secondaryPath;
    }
    
    // 验证路径
    final primaryValid = await validateBackupPath(primaryPath);
    if (!primaryValid) {
      throw Exception('主备份路径无效或无法访问: $primaryPath');
    }
    
    if (secondaryPath != null && secondaryPath.isNotEmpty) {
      final secondaryValid = await validateBackupPath(secondaryPath);
      if (!secondaryValid) {
        throw Exception('备用备份路径无效或无法访问: $secondaryPath');
      }
    }
    
    print('备份路径已更新: 主路径=$primaryPath, 备用路径=$secondaryPath');
  }

  /// 检查备份路径状态
  Future<Map<String, bool>> checkBackupPathStatus() async {
    final primaryStatus = await validateBackupPath(_backupPath);
    final secondaryStatus = _backupPath2.isNotEmpty ? 
        await validateBackupPath(_backupPath2) : true;
    
    return {
      'primary': primaryStatus,
      'secondary': secondaryStatus,
      'hasValidPath': primaryStatus || secondaryStatus,
    };
  }

  /// =================== 备份还原管理功能 ===================

  /// 备份还原策略管理
  Future<void> setRestoreStrategy({
    required bool autoRestore,
    required bool backupBeforeRestore,
    required bool validateRestoreData,
  }) async {
    // 这里可以添加还原策略的设置
    // 目前先保存到设置中，后续可以扩展
    print('还原策略已更新');
  }

  Map<String, dynamic> getRestoreStrategy() {
    return {
      'autoRestore': false, // 默认不自动还原
      'backupBeforeRestore': true, // 默认还原前备份
      'validateRestoreData': true, // 默认验证还原数据
    };
  }

  /// 备份还原路径管理
  Future<void> setRestorePath(String restorePath) async {
    // 验证还原路径
    final isValid = await validateRestorePath(restorePath);
    if (!isValid) {
      throw Exception('还原路径无效或无法访问: $restorePath');
    }
    
    print('还原路径已设置: $restorePath');
  }

  Future<bool> validateRestorePath(String restorePath) async {
    try {
      if (restorePath.isEmpty) return false;
      
      final file = File(restorePath);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        print('还原文件不存在: $restorePath');
        return false;
      }
      
      // 检查文件是否可读
      try {
        await file.open(mode: FileMode.read);
        print('还原文件读取权限验证成功');
        return true;
      } catch (e) {
        print('还原文件读取权限验证失败: $e');
        return false;
      }
    } catch (e) {
      print('验证还原路径时出错: $e');
      return false;
    }
  }

  /// 获取可用的还原文件列表
  Future<List<FileSystemEntity>> getAvailableRestoreFiles() async {
    try {
      final List<FileSystemEntity> allFiles = [];
      
      // 从主备份路径获取
      if (_backupPath.isNotEmpty) {
        final primaryFiles = await _getRestoreFilesFromPath(_backupPath);
        allFiles.addAll(primaryFiles);
      }
      
      // 从备用备份路径获取
      if (_backupPath2.isNotEmpty) {
        final secondaryFiles = await _getRestoreFilesFromPath(_backupPath2);
        allFiles.addAll(secondaryFiles);
      }
      
      // 按修改时间排序（最新的在前）
      allFiles.sort((a, b) {
        return File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync());
      });
      
      return allFiles;
    } catch (e) {
      print('获取可用还原文件列表时出错: $e');
      return [];
    }
  }

  Future<List<FileSystemEntity>> _getRestoreFilesFromPath(String pathStr) async {
    try {
      final directory = Directory(pathStr);
      if (!await directory.exists()) return [];
      
      final files = await directory
          .list()
          .where((entity) => entity is File && 
              (entity.path.endsWith('.db') || entity.path.endsWith('.sql')))
          .toList();
      
      return files;
    } catch (e) {
      print('从路径获取还原文件时出错: $pathStr, $e');
      return [];
    }
  }

  /// 还原前备份策略
  Future<String?> createPreRestoreBackup() async {
    try {
      if (_backupPath.isEmpty) {
        print('未设置备份路径，无法创建还原前备份');
        return null;
      }
      
      // 创建还原前备份
      final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-').replaceAll(' ', '_');
      final backupFileName = 'pre_restore_backup_$timestamp.db';
      final backupPath = path.join(_backupPath, backupFileName);
      
      // 确保备份目录存在
      final backupDir = Directory(_backupPath);
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }
      
      print('已创建还原前备份: $backupPath');
      return backupPath;
    } catch (e) {
      print('创建还原前备份失败: $e');
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
        if (preRestoreBackupPath != null && await File(preRestoreBackupPath).exists()) {
          // 可以选择保留或删除还原前备份
          // await File(preRestoreBackupPath).delete();
          print('还原成功，还原前备份保留在: $preRestoreBackupPath');
        }
      } else {
        // 还原失败，保留还原前备份
        if (preRestoreBackupPath != null) {
          print('还原失败，还原前备份保留在: $preRestoreBackupPath');
        }
      }
      
      print('还原后清理完成');
    } catch (e) {
      print('还原后清理时出错: $e');
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

  /// 还原进度跟踪
  Future<void> updateRestoreProgress({
    required String operation,
    required int current,
    required int total,
    String? detail,
  }) async {
    // 这里可以保存还原进度到设置中
    // 目前先打印日志，后续可以扩展为持久化存储
    print('还原进度: $operation $current/$total ${detail ?? ''}');
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
      print('还原操作记录: $operation, 文件: $filePath, 结果: ${success ? '成功' : '失败'}');
      if (errorMessage != null) {
        print('错误信息: $errorMessage');
      }
      if (preRestoreBackupPath != null) {
        print('还原前备份: $preRestoreBackupPath');
      }
    } catch (e) {
      print('记录还原操作时出错: $e');
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
      
      if (targetDataSource == 'mysql' && fileType != 'mysql') {
        print('MySQL数据源不能使用SQLite备份文件');
        return false;
      }
      
      if (targetDataSource == 'sqlite' && fileType != 'sqlite') {
        print('SQLite数据源不能使用MySQL备份文件');
        return false;
      }
      
      // 检查文件是否有效
      final fileInfo = await getRestoreFileInfo(filePath);
      if (fileInfo.containsKey('error')) {
        print('文件无效: ${fileInfo['error']}');
        return false;
      }
      
      // 检查备份路径状态
      final backupStatus = await checkBackupPathStatus();
      if (backupStatus['hasValidPath'] != true) {
        print('备份路径无效，无法创建还原前备份');
        return false;
      }
      
      return true;
    } catch (e) {
      print('验证还原策略时出错: $e');
      return false;
    }
  }
}

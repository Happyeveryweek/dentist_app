import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:dentist_app_windows/utils/app_paths.dart';
import 'package:dentist_app_windows/utils/datetime_formatter.dart';
import 'package:dentist_app_windows/utils/log_manager.dart';

/// MySQL连接管理服务
/// 负责MySQL连接管理和备份操作
class MySQLConnectionService {
  String _mysqlHost = '';
  String _mysqlPort = '3306';
  String _mysqlDatabase = '';
  String _mysqlUsername = '';
  String _mysqlPassword = '';
  String _backupPath = '';

  String get mysqlHost => _mysqlHost;
  String get mysqlPort => _mysqlPort;
  String get mysqlDatabase => _mysqlDatabase;
  String get mysqlUsername => _mysqlUsername;
  String get mysqlPassword => _mysqlPassword;
  String get backupPath => _backupPath;

  /// 更新MySQL连接参数
  void updateMySQLConnectionParams({
    required String host,
    required String port,
    required String database,
    required String username,
    required String password,
  }) {
    _mysqlHost = host;
    _mysqlPort = port;
    _mysqlDatabase = database;
    _mysqlUsername = username;
    _mysqlPassword = password;
  }

  /// 更新备份路径
  void updateBackupPath(String path) {
    _backupPath = path;
  }

  /// MySQL数据库备份方法
  Future<String> backupMySQLDatabase({String? backupPath}) async {
    LogManager.i('MySQLConnectionService', '开始MySQL备份过程');

    // 验证MySQL设置是否完整
    if (_mysqlHost.isEmpty ||
        _mysqlDatabase.isEmpty ||
        _mysqlUsername.isEmpty) {
      LogManager.e('MySQLConnectionService', 'MySQL设置不完整，请在设置中配置MySQL连接参数');
      throw Exception('MySQL设置不完整，请在设置中配置MySQL连接参数');
    }

    // 使用AppPaths获取mysqldump工具路径
    final toolPath = AppPaths.mysqldumpExePath;

    // 验证工具是否存在
    if (!File(toolPath).existsSync()) {
      LogManager.e('MySQLConnectionService', 'mysqldump工具不存在: $toolPath');
      throw Exception('mysqldump工具不存在: $toolPath');
    }

    // 获取用户指定的备份目录
    final userBackupPath = backupPath ?? _backupPath;

    if (userBackupPath.isEmpty) {
      LogManager.e('MySQLConnectionService', '未设置备份目录');
      throw Exception('未设置备份目录');
    }

    // 确保备份目录存在
    final backupDir = Directory(userBackupPath);
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    // 生成备份文件名
    final timestamp = DateTimeFormatter.nowDbString()
        .replaceAll(':', '-')
        .replaceAll(' ', '_');
    final backupFileName = 'backup_$timestamp.sql';
    final finalBackupPath = path.join(userBackupPath, backupFileName);

    // 构建命令参数列表
    final List<String> args = [
      '-h$_mysqlHost',
      '-P$_mysqlPort',
      '-u$_mysqlUsername',
      '-p$_mysqlPassword',
      '--default-character-set=utf8mb4',
      _mysqlDatabase,
      '--result-file=$finalBackupPath'
    ];

    try {
      // 使用Process.run执行mysqldump命令
      final result = await Process.run(
        toolPath,
        args,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );

      if (result.exitCode != 0) {
        LogManager.e('MySQLConnectionService', 'mysqldump备份失败',
            error: result.stderr);
        throw Exception('备份失败: ${result.stderr}');
      }

      LogManager.i('MySQLConnectionService', 'MySQL备份已保存到: $finalBackupPath');

      return finalBackupPath;
    } catch (e) {
      LogManager.e('MySQLConnectionService', '执行备份命令时出错', error: e);
      throw Exception('备份失败: $e');
    }
  }
}

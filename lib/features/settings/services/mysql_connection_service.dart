import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:dentist_app_windows/utils/app_paths.dart';
import 'package:dentist_app_windows/utils/datetime_formatter.dart';
import 'package:dentist_app_windows/models/backup_log.dart';

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
    print('开始MySQL备份过程...');

    // 验证MySQL设置是否完整
    if (_mysqlHost.isEmpty || _mysqlDatabase.isEmpty || _mysqlUsername.isEmpty) {
      throw Exception('MySQL设置不完整，请在设置中配置MySQL连接参数');
    }

    print('使用MySQL设置: ${_mysqlHost}:${_mysqlPort}/${_mysqlDatabase}');
    print('当前工作目录: ${Directory.current.path}');

    // 使用AppPaths获取mysqldump工具路径
    final toolPath = AppPaths.mysqldumpExePath;
    print('使用mysqldump工具: $toolPath');
    
    // 验证工具是否存在
    if (!File(toolPath).existsSync()) {
      throw Exception('mysqldump工具不存在: $toolPath');
    }

    // 获取用户指定的备份目录
    final userBackupPath = backupPath ?? _backupPath;
    print('备份目录: $userBackupPath');

    if (userBackupPath.isEmpty) {
      throw Exception('未设置备份目录');
    }

    // 确保备份目录存在
    final backupDir = Directory(userBackupPath);
    if (!await backupDir.exists()) {
      print('创建备份目录: ${backupDir.path}');
      await backupDir.create(recursive: true);
    }

    // 生成备份文件名
    final timestamp = DateTimeFormatter.nowDbString().replaceAll(':', '-').replaceAll(' ', '_');
    final backupFileName = 'backup_$timestamp.sql';
    final finalBackupPath = path.join(userBackupPath, backupFileName);
    print('备份文件路径: $finalBackupPath');

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

    print('执行mysqldump命令: $toolPath ${args.join(' ').replaceAll(_mysqlPassword, '******')}');

    try {
      // 使用Process.run执行mysqldump命令
      final result = await Process.run(
        toolPath,
        args,
        stdoutEncoding: const SystemEncoding(),
        stderrEncoding: const SystemEncoding(),
      );

      print('mysqldump命令执行结果: exitCode=${result.exitCode}');
      print('标准输出: ${result.stdout}');

      if (result.exitCode != 0) {
        print('备份失败，错误输出: ${result.stderr}');
        throw Exception('备份失败: ${result.stderr}');
      }

      print('MySQL备份已保存到: $finalBackupPath');
      
      return finalBackupPath;
    } catch (e) {
      print('执行备份命令时出错: $e');
      throw Exception('备份失败: $e');
    }
  }

  /// 获取MySQL工具路径
  String _getMySQLToolPath(String toolName) {
    print('查找MySQL工具: $toolName');
    print('当前工作目录: ${Directory.current.path}');
    print('可执行文件路径: ${Platform.resolvedExecutable}');
    print('可执行文件目录: ${path.dirname(Platform.resolvedExecutable)}');

    print('系统环境变量PATH: ${Platform.environment['PATH']}');

    // 尝试几种可能的路径
    final List<String> possiblePaths = [
      path.join(path.dirname(Platform.resolvedExecutable), 'tools', toolName),
      toolName,
      path.join(path.dirname(Platform.resolvedExecutable), toolName),
      '${path.dirname(Platform.resolvedExecutable)}\\tools\\$toolName',
      path.join(path.dirname(Directory.current.path), 'tools', toolName),
      path.join(Directory.current.path, 'tools', toolName),
      'C:\\Program Files\\牙科诊所管理系统\\tools\\$toolName',
      'C:\\Program Files (x86)\\牙科诊所管理系统\\tools\\$toolName',
      ...Platform.environment['PATH']!
          .split(';')
          .map((p) => path.join(p, toolName)),
    ];

    print('尝试以下可能的路径:');
    for (int i = 0; i < math.min(10, possiblePaths.length); i++) {
      print('- ${possiblePaths[i]}');
    }
    if (possiblePaths.length > 10) {
      print('...及其他 ${possiblePaths.length - 10} 个路径');
    }

    // 首先检查具体路径
    for (final toolPath in possiblePaths) {
      try {
        if (File(toolPath).existsSync()) {
          print('找到MySQL工具: $toolPath');
          return toolPath;
        }
      } catch (e) {
        print('检查路径时出错: $e');
      }
    }

    // 搜索应用程序目录及其子目录
    print('在应用程序目录及其子目录中搜索...');
    try {
      final directories = [
        path.dirname(Platform.resolvedExecutable),
        Directory.current.path,
        path.dirname(Directory.current.path),
        'C:\\Program Files\\牙科诊所管理系统',
        'C:\\Program Files (x86)\\牙科诊所管理系统',
      ];

      for (final dir in directories) {
        final foundPath = _findFileRecursively(dir, toolName, maxDepth: 4);
        if (foundPath != null) {
          print('通过递归搜索找到MySQL工具: $foundPath');
          return foundPath;
        }
      }
    } catch (e) {
      print('递归搜索时出错: $e');
    }

    // 如果找不到工具，尝试使用命令名
    print('未找到MySQL工具，将尝试直接使用命令名: $toolName');
    return toolName;
  }

  /// 递归查找文件
  String? _findFileRecursively(String directory, String fileName,
      {int maxDepth = 3, int currentDepth = 0}) {
    if (currentDepth > maxDepth) return null;

    try {
      final dir = Directory(directory);
      if (!dir.existsSync()) return null;

      for (var entity in dir.listSync()) {
        if (entity is File && path.basename(entity.path) == fileName) {
          return entity.path;
        } else if (entity is Directory) {
          final result = _findFileRecursively(entity.path, fileName,
              maxDepth: maxDepth, currentDepth: currentDepth + 1);
          if (result != null) return result;
        }
      }
    } catch (e) {
      print('在目录 $directory 中搜索时出错: $e');
    }

    return null;
  }
}

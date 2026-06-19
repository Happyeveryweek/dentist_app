import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import '../../../providers/database_provider.dart';

/// 数据源连接测试服务
/// 负责数据库连接测试和路径验证逻辑
class DataSourceConnectionService {
  final DatabaseProvider databaseProvider;

  DataSourceConnectionService({
    required this.databaseProvider,
  });

  /// 测试MySQL连接
  /// 
  /// [host] MySQL主机地址
  /// [port] MySQL端口
  /// [database] 数据库名称
  /// [username] 用户名
  /// [password] 密码
  /// 
  /// 返回连接是否成功
  Future<bool> testMySQLConnection({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) async {
    return await databaseProvider.testMySQLConnection(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
  }

  /// 选择SQLite数据库文件
  /// 
  /// 返回选择的文件路径，如果用户取消选择则返回null
  Future<String?> selectSqliteDatabase() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        dialogTitle: '选择SQLite数据库文件',
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      String filePath = result.files.single.path!;

      // 检查文件是否存在
      if (!await File(filePath).exists()) {
        throw Exception('选择的文件不存在');
      }

      return filePath;
    } catch (e) {
      throw Exception('选择文件时出错: $e');
    }
  }

  /// 验证SQLite数据库文件路径
  /// 
  /// [filePath] 文件路径
  /// 
  /// 返回文件是否有效
  Future<bool> validateSqliteFile(String filePath) async {
    try {
      final file = File(filePath);
      
      // 检查文件是否存在
      if (!await file.exists()) {
        return false;
      }

      // 检查文件扩展名
      final extension = path.extension(filePath).toLowerCase();
      if (!['.db', '.sqlite', '.sqlite3'].contains(extension)) {
        return false;
      }

      // 检查文件大小（至少要有一些内容）
      final fileSize = await file.length();
      if (fileSize < 100) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取SQLite数据库文件信息
  /// 
  /// [filePath] 文件路径
  /// 
  /// 返回文件信息（文件名、大小等）
  Future<Map<String, dynamic>> getSqliteFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();
      
      return {
        'path': filePath,
        'name': path.basename(filePath),
        'size': stat.size,
        'modified': stat.modified,
        'exists': await file.exists(),
      };
    } catch (e) {
      throw Exception('获取文件信息失败: $e');
    }
  }
}

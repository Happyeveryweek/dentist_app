import 'dart:io';
import 'package:file_picker/file_picker.dart';
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

      final selectedPath = result.files.single.path;
      if (selectedPath == null) {
        throw Exception('选择的文件路径为空');
      }

      // 检查文件是否存在
      if (!await File(selectedPath).exists()) {
        throw Exception('选择的文件不存在');
      }

      return selectedPath;
    } catch (e) {
      throw Exception('选择文件时出错: $e');
    }
  }
}

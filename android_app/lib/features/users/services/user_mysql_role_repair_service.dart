import 'user_connection_service.dart';
import '../../../utils/app_logger.dart';

/// MySQL 用户角色修复服务
class UserMySqlRoleRepairService {
  final UserConnectionService _connectionService;

  UserMySqlRoleRepairService({required UserConnectionService connectionService})
    : _connectionService = connectionService;

  /// 修复 MySQL 数据库中的角色值
  Future<void> fixInvalidRoles() async {
    final conn = _connectionService.getCurrentMysqlConnection();
    if (conn == null) {
      AppLogger.info('MySQL连接为null，跳过角色修复');
      return;
    }

    try {
      await conn.query('SELECT 1');
    } catch (e) {
      AppLogger.info('MySQL连接已断开，跳过角色修复');
      return;
    }

    await conn.query('''
      UPDATE users 
      SET role = 'doctor' 
      WHERE role = 'assistant'
    ''');
    AppLogger.info('MySQL数据库角色修复完成');
  }
}

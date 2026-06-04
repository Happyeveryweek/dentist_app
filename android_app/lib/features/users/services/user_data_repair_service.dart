import 'package:sqflite/sqflite.dart';
import 'user_connection_service.dart';
import 'user_mysql_role_repair_service.dart';
import 'user_sqlite_role_repair_service.dart';

/// 用户数据修复服务
/// 职责：数据库数据修复
class UserDataRepairService {
  final Database? _database;
  final String _dataSourceType;
  final Future<void> Function() refreshUsers;
  late final UserMySqlRoleRepairService _mySqlRoleRepairService;
  late final UserSqliteRoleRepairService _sqliteRoleRepairService;

  UserDataRepairService({
    required UserConnectionService connectionService,
    required Database? database,
    required String dataSourceType,
    required this.refreshUsers,
  }) : _database = database,
       _dataSourceType = dataSourceType {
    _mySqlRoleRepairService = UserMySqlRoleRepairService(
      connectionService: connectionService,
    );
    _sqliteRoleRepairService = UserSqliteRoleRepairService(
      database: database,
    );
  }

  /// 修复数据库中的无效角色值
  Future<void> fixInvalidRoles() async {
    try {
      print('开始修复数据库中的无效角色值...');
      
      if (_dataSourceType == 'mysql') {
        await _mySqlRoleRepairService.fixInvalidRoles();
      } else {
        await _sqliteRoleRepairService.fixInvalidRoles();
      }
      
      // 刷新用户列表
      await refreshUsers();
    } catch (e) {
      print('修复角色值失败: $e');
    }
  }
}

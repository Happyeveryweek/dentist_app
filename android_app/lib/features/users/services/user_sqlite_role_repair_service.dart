import 'package:sqflite/sqflite.dart';

/// SQLite 用户角色修复服务
class UserSqliteRoleRepairService {
  final Database? _database;

  UserSqliteRoleRepairService({
    required Database? database,
  }) : _database = database;

  /// 修复 SQLite 数据库中的角色值
  Future<void> fixInvalidRoles() async {
    final db = _database;
    if (db == null) {
      print('SQLite数据库为null，跳过角色修复');
      return;
    }

    if (!db.isOpen) {
      print('SQLite数据库连接已关闭，跳过角色修复');
      return;
    }

    await db.update(
      'users',
      {'role': 'doctor'},
      where: 'role = ?',
      whereArgs: ['assistant'],
    );
    print('SQLite数据库角色修复完成');
  }
}

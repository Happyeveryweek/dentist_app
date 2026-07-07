import 'package:mysql1/mysql1.dart';
import '../../../utils/datetime_formatter.dart';
import '../../../models/user.dart';
import 'package:flutter/foundation.dart';
import '../../../utils/log_manager.dart';

/// 用户同步服务
/// 负责处理 SQLite → MySQL 的数据同步逻辑（从 UserProvider 中提取）
class UserSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  UserSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 判断是否需要同步（当前使用 SQLite 数据源时需要同步到 MySQL）
  bool get needsSync => getEffectiveDataSourceType() == 'sqlite';

  /// 尝试将SQLite中的用户同步到MySQL（非阻塞操作）
  Future<void> syncUserToMySQL(User user, {required bool isUpdate}) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w('UserSyncService', 'MySQL连接不可用，跳过用户同步(id=${user.id})');
          return;
        }

        // 处理图片数据
        Uint8List? imageBlob;
        final imageData = user.imageData;
        if (imageData != null && imageData.isNotEmpty) {
          imageBlob = Uint8List.fromList(imageData);
        }

        if (isUpdate) {
          try {
            final result = await conn.query('''
              UPDATE users SET
                username = ?, password = ?, role = ?, doctor = ?,
                email = ?, avatar = ?, module_permissions = ?,
                image_data = ?, created_at = ?, updated_at = NOW()
              WHERE id = ?
            ''', [
              user.username,
              user.password,
              user.role,
              user.doctor,
              user.email,
              user.avatar,
              user.modulePermissions,
              imageBlob,
              DateTimeFormatter.toDbString(user.createdAt),
              user.id,
            ]);
            LogManager.i('UserSyncService',
                '成功更新MySQL用户(id=${user.id})，影响行数: ${result.affectedRows}');
          } catch (e) {
            LogManager.e('UserSyncService', '更新MySQL用户(id=${user.id})时出错',
                error: e);
          }
        } else {
          try {
            final existResult = await conn.query(
              'SELECT id FROM users WHERE id = ? LIMIT 1',
              [user.id],
            );

            if (existResult.isNotEmpty) {
              final result = await conn.query('''
                UPDATE users SET
                  username = ?, password = ?, role = ?, doctor = ?,
                  email = ?, avatar = ?, module_permissions = ?,
                  image_data = ?, created_at = ?, updated_at = NOW()
                WHERE id = ?
              ''', [
                user.username,
                user.password,
                user.role,
                user.doctor,
                user.email,
                user.avatar,
                user.modulePermissions,
                imageBlob,
                DateTimeFormatter.toDbString(user.createdAt),
                user.id,
              ]);
              LogManager.w('UserSyncService',
                  'MySQL中已存在用户，执行更新(id=${user.id})，影响行数: ${result.affectedRows}');
            } else {
              final result = await conn.query('''
                INSERT INTO users 
                (id, username, password, role, doctor, email, avatar, module_permissions, image_data, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
              ''', [
                user.id,
                user.username,
                user.password,
                user.role,
                user.doctor,
                user.email,
                user.avatar,
                user.modulePermissions,
                imageBlob,
                DateTimeFormatter.toDbString(user.createdAt),
              ]);
              LogManager.i('UserSyncService',
                  '成功插入MySQL用户(id=${user.id})，插入ID: ${result.insertId}');
            }
          } catch (e) {
            LogManager.e('UserSyncService', '同步MySQL用户(id=${user.id})时出错',
                error: e);
          }
        }
      } catch (e) {
        LogManager.e('UserSyncService', '用户同步到MySQL发生不可预期错误', error: e);
      }
    });
  }

  /// 尝试从MySQL删除用户（非阻塞操作）
  Future<void> syncDeleteUserToMySQL(int id) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w('UserSyncService', 'MySQL连接不可用，跳过用户删除同步(id=$id)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM users WHERE id = ?',
            [id],
          );
          LogManager.i('UserSyncService',
              '成功从MySQL删除用户(id=$id)，影响行数: ${result.affectedRows}');
        } catch (e) {
          LogManager.e('UserSyncService', '从MySQL删除用户(id=$id)时出错', error: e);
        }
      } catch (e) {
        LogManager.e('UserSyncService', '用户删除同步到MySQL发生不可预期错误', error: e);
      }
    });
  }
}

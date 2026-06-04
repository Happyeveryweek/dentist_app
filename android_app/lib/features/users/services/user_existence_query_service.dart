import 'package:sqflite/sqflite.dart';
import 'user_connection_service.dart';

/// 用户存在性查询服务
class UserExistenceQueryService {
  final UserConnectionService _connectionService;
  final Database? _database;
  final String _dataSourceType;

  UserExistenceQueryService({
    required UserConnectionService connectionService,
    required Database? database,
    required String dataSourceType,
  })  : _connectionService = connectionService,
        _database = database,
        _dataSourceType = dataSourceType;

  Future<bool> exists(
    String table,
    String column,
    String value, {
    int? excludeId,
  }) async {
    try {
      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) return false;

        final result = await db.rawQuery(
          excludeId != null
              ? 'SELECT 1 FROM $table WHERE $column = ? AND id != ?'
              : 'SELECT 1 FROM $table WHERE $column = ?',
          excludeId != null ? [value, excludeId] : [value],
        );
        return result.isNotEmpty;
      }

      if (_dataSourceType == 'mysql') {
        final conn = _connectionService.getCurrentMysqlConnection();
        if (conn == null) return false;

        final results = await conn.query(
          excludeId != null
              ? 'SELECT 1 FROM $table WHERE $column = ? AND id != ?'
              : 'SELECT 1 FROM $table WHERE $column = ?',
          excludeId != null ? [value, excludeId] : [value],
        );
        return results.isNotEmpty;
      }

      return false;
    } catch (e) {
      print('存在性查询失败: $e');
      return false;
    }
  }
}

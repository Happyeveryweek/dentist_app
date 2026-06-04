import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import 'user_connection_service.dart';

/// 用户统计服务
/// 职责：用户统计信息查询
class UserStatisticsService {
  final UserConnectionService _connectionService;

  UserStatisticsService({
    required UserConnectionService connectionService,
  }) : _connectionService = connectionService;

  /// 获取用户统计信息
  Future<Map<String, dynamic>> getUserStatistics() async {
    if (!_connectionService.isInitialized()) {
      return {
        'totalUsers': 0,
        'adminCount': 0,
        'doctorCount': 0,
        'userCount': 0,
      };
    }

    try {
      Map<String, dynamic> stats = {
        'totalUsers': 0,
        'adminCount': 0,
        'doctorCount': 0,
        'userCount': 0,
      };

      if (_connectionService.dataSourceType == 'sqlite') {
        final db = _connectionService.getSqliteDatabase();
        if (db == null) return stats;
        
        // 检查数据库是否仍然可用
        if (!db.isOpen) {
          print('SQLite数据库连接已关闭，返回默认统计信息');
          return stats;
        }
        
        final result = await db.rawQuery('''
          SELECT 
            COUNT(*) as total_users,
            COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count,
            COUNT(CASE WHEN role = 'doctor' THEN 1 END) as doctor_count,
            COUNT(CASE WHEN role = 'user' THEN 1 END) as user_count
          FROM users
        ''');
        
        if (result.isNotEmpty) {
          stats['totalUsers'] = result.first['total_users'] ?? 0;
          stats['adminCount'] = result.first['admin_count'] ?? 0;
          stats['doctorCount'] = result.first['doctor_count'] ?? 0;
          stats['userCount'] = result.first['user_count'] ?? 0;
        }
      } else if (_connectionService.dataSourceType == 'mysql') {
        final conn = _connectionService.getCurrentMysqlConnection();
        if (conn == null) return stats;
        
        // 检查MySQL连接是否仍然有效
        try {
          // 尝试执行一个简单的查询来测试连接
          await conn.query('SELECT 1');
        } catch (e) {
          print('MySQL连接已断开，返回默认统计信息');
          return stats;
        }
        
        final results = await conn.query('''
          SELECT 
            COUNT(*) as total_users,
            COUNT(CASE WHEN role = 'admin' THEN 1 END) as admin_count,
            COUNT(CASE WHEN role = 'doctor' THEN 1 END) as doctor_count,
            COUNT(CASE WHEN role = 'user' THEN 1 END) as user_count
          FROM users
        ''');
        
        if (results.isNotEmpty) {
          final row = results.first;
          stats['totalUsers'] = row['total_users'] ?? 0;
          stats['adminCount'] = row['admin_count'] ?? 0;
          stats['doctorCount'] = row['doctor_count'] ?? 0;
          stats['userCount'] = row['user_count'] ?? 0;
        }
      }

      return stats;
    } catch (e) {
      print('获取用户统计信息失败: $e');
      return {
        'totalUsers': 0,
        'adminCount': 0,
        'doctorCount': 0,
        'userCount': 0,
      };
    }
  }
}

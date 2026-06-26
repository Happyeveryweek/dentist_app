import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../utils/datetime_formatter.dart';
import '../../../features/financial/services/financial_permission_service.dart';
import '../../../utils/app_logger.dart';

/// 财务数据清理服务
/// 职责：管理财务数据的清理、无效记录检测、数据验证
class FinancialDataCleanerService {
  /// 检查并清理无效的财务记录（patient_id为0或null）
  Future<Map<String, int>> checkAndCleanInvalidRecords({
    required String dataSourceType,
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
    required Future<void> Function() clearCache,
    required Future<bool> Function() autoReconnect,
  }) async {
    Map<String, int> result = {'total': 0, 'invalid': 0, 'cleaned': 0};

    try {
      if (dataSourceType == 'sqlite') {
        final db = sqliteDatabase;
        if (db == null) throw Exception('SQLite数据库未初始化');

        // 获取总记录数
        final totalCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM financial_records',
        );
        result['total'] = totalCount.first['count'] as int;

        // 获取无效记录数
        final invalidCount = await db.rawQuery(
          'SELECT COUNT(*) as count FROM financial_records WHERE patient_id IS NULL OR patient_id = 0',
        );
        final invalid = invalidCount.first['count'] as int;
        result['invalid'] = invalid;

        if (invalid > 0) {
          // 删除无效记录
          final deleted = await db.delete(
            'financial_records',
            where: 'patient_id IS NULL OR patient_id = 0',
          );
          result['cleaned'] = deleted;
          AppLogger.info('✅ SQLite清理完成，删除 $deleted 条无效财务记录');
        }
      } else if (dataSourceType == 'mysql') {
        final conn = mysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');

        try {
          // 获取总记录数
          final totalResults = await conn.query(
            'SELECT COUNT(*) as count FROM financial_records',
          );
          result['total'] =
              int.tryParse(totalResults.first['count'].toString()) ?? 0;

          // 获取无效记录数
          final invalidResults = await conn.query(
            'SELECT COUNT(*) as count FROM financial_records WHERE patient_id IS NULL OR patient_id = 0',
          );
          final invalid =
              int.tryParse(invalidResults.first['count'].toString()) ?? 0;
          result['invalid'] = invalid;

          if (invalid > 0) {
            // 删除无效记录
            final deletedResults = await conn.query(
              'DELETE FROM financial_records WHERE patient_id IS NULL OR patient_id = 0',
            );
            result['cleaned'] = deletedResults.affectedRows ?? 0;
            AppLogger.info('✅ MySQL清理完成，删除 ${result["cleaned"]} 条无效财务记录');
          }
        } catch (e) {
          if (e.toString().contains('SocketException') ||
              e.toString().contains('Cannot write to socket') ||
              e.toString().contains('Connection reset')) {
            await autoReconnect();
            return await checkAndCleanInvalidRecords(
              dataSourceType: dataSourceType,
              sqliteDatabase: sqliteDatabase,
              mysqlConnection: mysqlConnection,
              clearCache: clearCache,
              autoReconnect: autoReconnect,
            );
          }
          rethrow;
        }
      }

      // 清理缓存
      await clearCache();
    } catch (e) {
      AppLogger.info('❌ 清理无效财务记录时出错: $e');
      rethrow;
    }

    return result;
  }

  /// 获取无效财务记录的详细信息
  Future<List<Map<String, dynamic>>> getInvalidRecordsInfo({
    required String dataSourceType,
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
    required Future<bool> Function() autoReconnect,
  }) async {
    List<Map<String, dynamic>> invalidRecords = [];

    try {
      if (dataSourceType == 'sqlite') {
        final db = sqliteDatabase;
        if (db == null) throw Exception('SQLite数据库未初始化');

        invalidRecords = await db.rawQuery('''
          SELECT fr.*, 'SQLite' as source, COALESCE(p.name, '未知患者') as patient_name
          FROM financial_records fr
          LEFT JOIN patients p ON fr.patient_id = p.id
          WHERE fr.patient_id IS NULL OR fr.patient_id = 0
          ORDER BY fr.created_at DESC
        ''');
      } else if (dataSourceType == 'mysql') {
        final conn = mysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');

        try {
          final results = await conn.query('''
            SELECT fr.*, 'MySQL' as source, COALESCE(p.name, '未知患者') as patient_name
            FROM financial_records fr
            LEFT JOIN patients p ON fr.patient_id = p.id
            WHERE fr.patient_id IS NULL OR fr.patient_id = 0
            ORDER BY fr.created_at DESC
          ''');

          invalidRecords =
              results
                  .map(
                    (row) => {
                      'id': int.tryParse(row['id'].toString()) ?? 0,
                      'patient_id':
                          int.tryParse(row['patient_id'].toString()) ?? 0,
                      'patient_name':
                          FinancialPermissionService.convertBlobToString(
                            row['patient_name'],
                          ),
                      'total_quantity':
                          int.tryParse(row['total_quantity'].toString()) ?? 0,
                      'notes': row['notes']?.toString(),
                      'created_at':
                          FinancialPermissionService.convertBlobToString(
                            row['created_at'],
                          ) ??
                          DateTimeFormatter.nowDbString(),
                      'updated_at':
                          FinancialPermissionService.convertBlobToString(
                            row['updated_at'],
                          ) ??
                          DateTimeFormatter.nowDbString(),
                      'source': 'MySQL',
                    },
                  )
                  .toList();
        } catch (e) {
          if (e.toString().contains('SocketException') ||
              e.toString().contains('Cannot write to socket') ||
              e.toString().contains('Connection reset')) {
            await autoReconnect();
            return await getInvalidRecordsInfo(
              dataSourceType: dataSourceType,
              sqliteDatabase: sqliteDatabase,
              mysqlConnection: mysqlConnection,
              autoReconnect: autoReconnect,
            );
          }
          rethrow;
        }
      }
    } catch (e) {
      AppLogger.info('❌ 获取无效财务记录信息时出错: $e');
    }

    return invalidRecords;
  }
}

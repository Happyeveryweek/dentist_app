import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../utils/app_logger.dart';

/// 财务统计服务
/// 职责：管理财务数据的统计计算、患者消费统计、财务统计
class FinancialStatisticsService {
  /// 获取患者总消费额
  Future<double> getPatientTotalCost({
    required int patientId,
    required String dataSourceType,
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
    required String? Function() getDoctorFilter,
    required bool Function() shouldFilterByDoctor,
  }) async {
    try {
      double totalCost = 0.0;

      if (dataSourceType == 'sqlite') {
        final db = sqliteDatabase;
        if (db == null) return 0.0;

        // 构建查询条件
        List<String> conditions = ['fr.patient_id = ?'];
        List<dynamic> queryArgs = [patientId];

        // 权限过滤：基于医生字段
        final doctorFilter = getDoctorFilter();
        if (doctorFilter != null && shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }

        // 根据实际的数据库表结构，需要通过 financial_items 表计算总消费
        final result = await db.rawQuery('''
          SELECT SUM(fi.total_price) as total
          FROM financial_records fr
          JOIN financial_items fi ON fr.id = fi.financial_record_id
          LEFT JOIN patients p ON fr.patient_id = p.id
          WHERE ${conditions.join(' AND ')}
        ''', queryArgs);
        if (result.isNotEmpty && result.first['total'] != null) {
          totalCost = (result.first['total'] as num).toDouble();
        }
      } else if (dataSourceType == 'mysql') {
        final conn = mysqlConnection;
        if (conn == null) return 0.0;

        // 构建查询条件
        List<String> conditions = ['fr.patient_id = ?'];
        List<dynamic> queryArgs = [patientId];

        // 权限过滤：基于医生字段
        final doctorFilter = getDoctorFilter();
        if (doctorFilter != null && shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }

        // 根据实际的数据库表结构，需要通过 financial_items 表计算总消费
        final results = await conn.query('''
          SELECT SUM(fi.total_price) as total
          FROM financial_records fr
          JOIN financial_items fi ON fr.id = fi.financial_record_id
          LEFT JOIN patients p ON fr.patient_id = p.id
          WHERE ${conditions.join(' AND ')}
        ''', queryArgs);
        if (results.isNotEmpty && results.first['total'] != null) {
          totalCost = (results.first['total'] as num).toDouble();
        }
      }

      return totalCost;
    } catch (e) {
      AppLogger.info('获取患者总消费额失败: $e');
      return 0.0;
    }
  }

  /// 获取所有财务记录的统计信息
  Future<Map<String, dynamic>> getFinancialStatistics({
    required String dataSourceType,
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
    required String? Function() getDoctorFilter,
    required bool Function() shouldFilterByDoctor,
  }) async {
    try {
      Map<String, dynamic> stats = {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalPaid': 0.0,
        'totalOutstanding': 0.0,
      };

      if (dataSourceType == 'sqlite') {
        final db = sqliteDatabase;
        if (db == null) return stats;

        // 构建查询条件
        List<String> conditions = [];
        List<dynamic> queryArgs = [];

        // 权限过滤：基于医生字段
        final doctorFilter = getDoctorFilter();
        if (doctorFilter != null && shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }

        String whereClause =
            conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

        // 根据实际的数据库表结构，需要通过 financial_items 表计算统计信息
        final result = await db.rawQuery('''
          SELECT
            COUNT(DISTINCT fr.id) as total_records,
            SUM(fi.total_price) as total_amount,
            SUM(fi.total_price) as total_paid,
            0.0 as total_outstanding
          FROM financial_records fr
          LEFT JOIN financial_items fi ON fr.id = fi.financial_record_id
          LEFT JOIN patients p ON fr.patient_id = p.id
          $whereClause
        ''', queryArgs);

        if (result.isNotEmpty) {
          stats['totalRecords'] = result.first['total_records'] ?? 0;
          stats['totalAmount'] =
              (result.first['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalPaid'] =
              (result.first['total_paid'] as num?)?.toDouble() ?? 0.0;
          stats['totalOutstanding'] =
              (result.first['total_outstanding'] as num?)?.toDouble() ?? 0.0;
        }
      } else if (dataSourceType == 'mysql') {
        final conn = mysqlConnection;
        if (conn == null) return stats;

        // 构建查询条件
        List<String> conditions = [];
        List<dynamic> queryArgs = [];

        // 权限过滤：基于医生字段
        final doctorFilter = getDoctorFilter();
        if (doctorFilter != null && shouldFilterByDoctor()) {
          conditions.add('p.doctor = ?');
          queryArgs.add(doctorFilter);
        }

        String whereClause =
            conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

        // 根据实际的数据库表结构，需要通过 financial_items 表计算统计信息
        final results = await conn.query('''
          SELECT
            COUNT(DISTINCT fr.id) as total_records,
            SUM(fi.total_price) as total_amount,
            SUM(fi.total_price) as total_paid,
            0.0 as total_outstanding
          FROM financial_records fr
          LEFT JOIN financial_items fi ON fr.id = fi.financial_record_id
          LEFT JOIN patients p ON fr.patient_id = p.id
          $whereClause
        ''', queryArgs);

        if (results.isNotEmpty) {
          final row = results.first;
          stats['totalRecords'] = row['total_records'] ?? 0;
          stats['totalAmount'] =
              (row['total_amount'] as num?)?.toDouble() ?? 0.0;
          stats['totalPaid'] = (row['total_paid'] as num?)?.toDouble() ?? 0.0;
          stats['totalOutstanding'] =
              (row['total_outstanding'] as num?)?.toDouble() ?? 0.0;
        }
      }

      return stats;
    } catch (e) {
      AppLogger.info('获取财务统计信息失败: $e');
      return {
        'totalRecords': 0,
        'totalAmount': 0.0,
        'totalPaid': 0.0,
        'totalOutstanding': 0.0,
      };
    }
  }
}

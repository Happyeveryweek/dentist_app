import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../utils/datetime_formatter.dart';
import '../../../utils/app_logger.dart';

/// 统计信息数据类
class PurchaseStatistics {
  final int totalRecords;
  final double totalAmount;
  final int totalQuantity;
  final int materialCount;

  PurchaseStatistics({
    required this.totalRecords,
    required this.totalAmount,
    required this.totalQuantity,
    required this.materialCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalRecords': totalRecords,
      'totalAmount': totalAmount,
      'totalQuantity': totalQuantity,
      'materialCount': materialCount,
    };
  }
}

/// 采购统计计算服务
/// 职责：计算采购记录的统计信息（总记录数、总金额、总采购量、材料种类）
class PurchaseStatisticsService {
  /// 计算采购记录的统计信息
  ///
  /// [records] 采购记录列表
  /// [getItemsCallback] 获取采购项目的回调函数，用于计算实际数量和材料种类
  ///
  /// 返回统计信息对象
  static Future<PurchaseStatistics> calculateStatistics(
    List<PurchaseRecord> records,
    Future<List<PurchaseItem>> Function(int recordId) getItemsCallback,
  ) async {
    if (records.isEmpty) {
      return PurchaseStatistics(
        totalRecords: 0,
        totalAmount: 0.0,
        totalQuantity: 0,
        materialCount: 0,
      );
    }

    double totalAmount = 0.0;
    int totalQuantity = 0;
    Set<String> materials = {};

    for (final record in records) {
      totalAmount += record.totalAmount;
    }

    final itemResults = await Future.wait(
      records.map((record) async {
        final recordId = record.id;
        if (recordId == null) return (record, <PurchaseItem>[], true);
        try {
          return (record, await getItemsCallback(recordId), false);
        } catch (e) {
          AppLogger.info('获取采购记录 $recordId 的项目失败: $e');
          return (record, <PurchaseItem>[], true);
        }
      }),
    );
    for (final result in itemResults) {
      if (result.$3) {
        totalQuantity += result.$1.totalQuantity;
        continue;
      }
      for (final item in result.$2) {
        totalQuantity += item.quantity;
        materials.add(item.materialName);
      }
    }

    AppLogger.info(
      '✅ 统计信息计算完成: 记录数=${records.length}, 总金额=$totalAmount, 总数量=$totalQuantity, 材料种类=${materials.length}',
    );

    return PurchaseStatistics(
      totalRecords: records.length,
      totalAmount: totalAmount,
      totalQuantity: totalQuantity,
      materialCount: materials.length,
    );
  }

  /// 计算基础统计信息（不获取采购项目，仅使用记录本身的字段）
  ///
  /// 这是一个降级方案，当获取采购项目失败时使用
  static PurchaseStatistics calculateBasicStatistics(
    List<PurchaseRecord> records,
  ) {
    if (records.isEmpty) {
      return PurchaseStatistics(
        totalRecords: 0,
        totalAmount: 0.0,
        totalQuantity: 0,
        materialCount: 0,
      );
    }

    double totalAmount = 0.0;
    int totalQuantity = 0;

    for (var record in records) {
      totalAmount += record.totalAmount;
      totalQuantity += record.totalQuantity;
    }

    return PurchaseStatistics(
      totalRecords: records.length,
      totalAmount: totalAmount,
      totalQuantity: totalQuantity,
      materialCount: 0, // 基础统计无法获取材料种类
    );
  }
}

/// 采购数据库统计服务
/// 职责：从数据库直接查询统计信息
class PurchaseDatabaseStatisticsService {
  final Database? _sqliteDatabase;
  final MySqlConnection? _mysqlConnection;
  final MySqlConnection? Function()? _mysqlConnectionGetter;
  final String _dataSourceType;
  final String? Function()? _getDoctorFilter;
  final bool Function()? _shouldFilterByDoctor;
  final Future<bool> Function()? _testMySqlConnection;

  PurchaseDatabaseStatisticsService({
    Database? sqliteDatabase,
    MySqlConnection? mysqlConnection,
    MySqlConnection? Function()? mysqlConnectionGetter,
    required String dataSourceType,
    String? Function()? getDoctorFilter,
    bool Function()? shouldFilterByDoctor,
    Future<bool> Function()? testMySqlConnection,
  }) : _sqliteDatabase = sqliteDatabase,
       _mysqlConnection = mysqlConnection,
       _mysqlConnectionGetter = mysqlConnectionGetter,
       _dataSourceType = dataSourceType,
       _getDoctorFilter = getDoctorFilter,
       _shouldFilterByDoctor = shouldFilterByDoctor,
       _testMySqlConnection = testMySqlConnection;

  MySqlConnection? get _currentMysqlConnection =>
      _mysqlConnectionGetter?.call() ?? _mysqlConnection;

  /// 获取采购统计信息
  Future<Map<String, dynamic>> getPurchaseStatistics() async {
    Map<String, dynamic> stats = {
      'totalRecords': 0,
      'totalAmount': 0.0,
      'totalQuantity': 0,
      'supplierCount': 0,
    };

    if (_dataSourceType == 'sqlite') {
      final db = _sqliteDatabase;
      if (db == null) return stats;

      // 权限过滤：基于医生字段
      final doctorFilter = _getDoctorFilter?.call();
      String query = '''
        SELECT 
          COUNT(*) as total_records,
          SUM(total_amount) as total_amount,
          SUM(total_quantity) as total_quantity,
          COUNT(DISTINCT supplier) as supplier_count
        FROM purchase_records
      ''';
      List<dynamic> queryArgs = [];

      if (doctorFilter != null && (_shouldFilterByDoctor?.call() ?? false)) {
        query += ' WHERE doctor = ?';
        queryArgs.add(doctorFilter);
      }

      final result = await db.rawQuery(query, queryArgs);

      if (result.isNotEmpty) {
        stats['totalRecords'] =
            int.tryParse(result.first['total_records'].toString()) ?? 0;
        stats['totalAmount'] =
            (result.first['total_amount'] as num?)?.toDouble() ?? 0.0;
        stats['totalQuantity'] =
            int.tryParse(result.first['total_quantity'].toString()) ?? 0;
        stats['supplierCount'] = result.first['supplier_count'] ?? 0;
      }
    } else if (_dataSourceType == 'mysql') {
      final conn = _currentMysqlConnection;
      if (conn == null) return stats;

      // 测试连接是否有效
      final isConnected = await _testMySqlConnection?.call() ?? false;
      if (!isConnected) {
        return stats;
      }

      // 权限过滤：基于医生字段
      final doctorFilter = _getDoctorFilter?.call();
      String query = '''
        SELECT 
          COUNT(*) as total_records,
          SUM(total_amount) as total_amount,
          SUM(total_quantity) as total_quantity,
          COUNT(DISTINCT supplier) as supplier_count
        FROM purchase_records
      ''';
      List<dynamic> queryArgs = [];

      if (doctorFilter != null && (_shouldFilterByDoctor?.call() ?? false)) {
        query += ' WHERE doctor = ?';
        queryArgs.add(doctorFilter);
      }

      final results = await conn.query(query, queryArgs);

      if (results.isNotEmpty) {
        final row = results.first;
        stats['totalRecords'] =
            int.tryParse(row['total_records'].toString()) ?? 0;
        stats['totalAmount'] = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
        stats['totalQuantity'] =
            int.tryParse(row['total_quantity'].toString()) ?? 0;
        stats['supplierCount'] =
            int.tryParse(row['supplier_count'].toString()) ?? 0;
      }
    }

    return stats;
  }

  /// 根据日期范围获取采购统计
  Future<Map<String, dynamic>> getPurchaseStatisticsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    Map<String, dynamic> stats = {
      'totalRecords': 0,
      'totalAmount': 0.0,
      'totalQuantity': 0,
    };

    if (_dataSourceType == 'sqlite') {
      final db = _sqliteDatabase;
      if (db == null) return stats;

      // 权限过滤：基于医生字段
      final doctorFilter = _getDoctorFilter?.call();
      String query = '''
        SELECT 
          COUNT(*) as total_records,
          SUM(total_amount) as total_amount,
          SUM(total_quantity) as total_quantity
        FROM purchase_records 
        WHERE purchase_date BETWEEN ? AND ?
      ''';
      List<dynamic> queryArgs = [
        DateTimeFormatter.toDbString(startDate),
        DateTimeFormatter.toDbString(endDate),
      ];

      if (doctorFilter != null && (_shouldFilterByDoctor?.call() ?? false)) {
        query += ' AND doctor = ?';
        queryArgs.add(doctorFilter);
      }

      final result = await db.rawQuery(query, queryArgs);

      if (result.isNotEmpty) {
        stats['totalRecords'] = result.first['total_records'] ?? 0;
        stats['totalAmount'] =
            (result.first['total_amount'] as num?)?.toDouble() ?? 0.0;
        stats['totalQuantity'] = result.first['total_quantity'] ?? 0;
      }
    } else if (_dataSourceType == 'mysql') {
      final conn = _currentMysqlConnection;
      if (conn == null) return stats;

      // 测试连接是否有效
      final isConnected = await _testMySqlConnection?.call() ?? false;
      if (!isConnected) {
        return stats;
      }

      // 权限过滤：基于医生字段
      final doctorFilter = _getDoctorFilter?.call();
      String query = '''
        SELECT 
          COUNT(*) as total_records,
          SUM(total_amount) as total_amount,
          SUM(total_quantity) as total_quantity
        FROM purchase_records 
        WHERE purchase_date BETWEEN ? AND ?
      ''';
      List<dynamic> queryArgs = [
        DateTimeFormatter.toDbString(startDate),
        DateTimeFormatter.toDbString(endDate),
      ];

      if (doctorFilter != null && (_shouldFilterByDoctor?.call() ?? false)) {
        query += ' AND doctor = ?';
        queryArgs.add(doctorFilter);
      }

      final results = await conn.query(query, queryArgs);

      if (results.isNotEmpty) {
        final row = results.first;
        stats['totalRecords'] =
            int.tryParse(row['total_records'].toString()) ?? 0;
        stats['totalAmount'] = (row['total_amount'] as num?)?.toDouble() ?? 0.0;
        stats['totalQuantity'] =
            int.tryParse(row['total_quantity'].toString()) ?? 0;
      }
    }

    return stats;
  }
}

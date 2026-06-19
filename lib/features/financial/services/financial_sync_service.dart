import 'package:mysql1/mysql1.dart';

/// 财务同步服务
/// 负责处理 SQLite → MySQL 的数据同步逻辑（从 FinancialProvider 中提取）
class FinancialSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  FinancialSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 判断是否需要同步（当前使用 SQLite 数据源时需要同步到 MySQL）
  bool get needsSync => getEffectiveDataSourceType() == 'sqlite';

  /// 尝试将SQLite中的财务记录同步到MySQL（非阻塞操作）
  Future<void> syncFinancialRecordToMySQL(
      Map<String, dynamic> recordMap, int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          print('MySQL连接不可用，跳过财务记录同步(id=$recordId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT id FROM financial_records WHERE id = ? LIMIT 1',
            [recordId],
          );

          if (existResult.isNotEmpty) {
            final result = await conn.query('''
              UPDATE financial_records SET
                patient_id = ?, total_quantity = ?, notes = ?,
                created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              recordMap['patient_id'],
              recordMap['total_quantity'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
              recordId,
            ]);
            print('成功更新MySQL财务记录(id=$recordId)，影响行数: ${result.affectedRows}');
          } else {
            final result = await conn.query('''
              INSERT INTO financial_records
              (id, patient_id, total_quantity, notes, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              recordId,
              recordMap['patient_id'],
              recordMap['total_quantity'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
            ]);
            print('成功将财务记录(id=$recordId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          print('同步财务记录到MySQL时出错: $e');
        }
      } catch (e) {
        print('财务记录同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除财务记录（非阻塞操作，级联删除财务项目）
  Future<void> syncDeleteFinancialRecordToMySQL(int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          print('MySQL连接不可用，跳过财务记录删除同步(id=$recordId)');
          return;
        }

        try {
          // 先删除关联的财务项目
          final itemsResult = await conn.query(
            'DELETE FROM financial_items WHERE financial_record_id = ?',
            [recordId],
          );
          print('成功从MySQL删除财务项目，影响行数: ${itemsResult.affectedRows}');

          // 再删除财务记录
          final recordResult = await conn.query(
            'DELETE FROM financial_records WHERE id = ?',
            [recordId],
          );
          print('成功从MySQL删除财务记录(id=$recordId)，影响行数: ${recordResult.affectedRows}');
        } catch (e) {
          print('从MySQL删除财务记录(id=$recordId)时出错: $e');
        }
      } catch (e) {
        print('财务记录删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试将SQLite中的财务项目同步到MySQL（非阻塞操作）
  Future<void> syncFinancialItemToMySQL(
      Map<String, dynamic> itemMap, int itemId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          print('MySQL连接不可用，跳过财务项目同步(id=$itemId)');
          return;
        }

        final existResult = await conn.query(
          'SELECT id FROM financial_items WHERE id = ? LIMIT 1',
          [itemId],
        );

        if (existResult.isNotEmpty) {
          final result = await conn.query('''
              UPDATE financial_items SET
              financial_record_id = ?, item_name = ?, item_price = ?,
              processing_fee = ?, quantity = ?, total_price = ?,
              charge_date = ?, created_at = ?, updated_at = ?, payment_method = ?
            WHERE id = ?
          ''', [
            itemMap['financial_record_id'],
            itemMap['item_name'],
            itemMap['item_price'],
            itemMap['processing_fee'],
            itemMap['quantity'],
            itemMap['total_price'],
            itemMap['charge_date'],
            itemMap['created_at'],
            itemMap['updated_at'],
            itemMap['payment_method'],
            itemId,
          ]);
          print('成功更新MySQL财务项目(id=$itemId)，影响行数: ${result.affectedRows}');
        } else {
          final result = await conn.query('''
            INSERT INTO financial_items
            (id, financial_record_id, item_name, item_price, processing_fee, quantity, total_price, charge_date, created_at, updated_at, payment_method)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            itemId,
            itemMap['financial_record_id'],
            itemMap['item_name'],
            itemMap['item_price'],
            itemMap['processing_fee'],
            itemMap['quantity'],
            itemMap['total_price'],
            itemMap['charge_date'],
            itemMap['created_at'],
            itemMap['updated_at'],
            itemMap['payment_method'],
          ]);
          print('成功将财务项目(id=$itemId)同步到MySQL，插入ID: ${result.insertId}');
        }
      } catch (e) {
        print('财务项目同步到MySQL发生不可预期错误: $e');
      }
    });
  }

  /// 尝试从MySQL删除财务项目（非阻塞操作）
  Future<void> syncDeleteFinancialItemToMySQL(int itemId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          print('MySQL连接不可用，跳过财务项目删除同步(id=$itemId)');
          return;
        }

        final result = await conn.query(
          'DELETE FROM financial_items WHERE id = ?',
          [itemId],
        );
        print('成功从MySQL删除财务项目(id=$itemId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        print('财务项目删除同步到MySQL发生不可预期错误: $e');
      }
    });
  }
}

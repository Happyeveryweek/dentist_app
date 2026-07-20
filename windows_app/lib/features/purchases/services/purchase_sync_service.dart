import 'package:mysql1/mysql1.dart';
import '../../../utils/log_manager.dart';
import '../../../models/data_source.dart';

/// 采购同步服务
/// 负责处理 SQLite → MySQL 的数据同步逻辑（从 PurchaseProvider 中提取）
class PurchaseSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  PurchaseSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 判断是否需要同步（当前使用 SQLite 数据源时需要同步到 MySQL）
  bool get needsSync => getEffectiveDataSourceType().isSqliteDataSource;

  /// 尝试将SQLite中的采购记录同步到MySQL（非阻塞操作）
  Future<void> syncPurchaseRecordToMySQL(
      Map<String, dynamic> recordMap, int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w(
              'PurchaseSyncService', 'MySQL连接不可用，跳过采购记录同步(id=$recordId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT id FROM purchase_records WHERE id = ? LIMIT 1',
            [recordId],
          );

          if (existResult.isNotEmpty) {
            final result = await conn.query('''
              UPDATE purchase_records SET
                purchase_date = ?, total_quantity = ?, total_amount = ?,
                supplier = ?, doctor = ?, notes = ?,
                created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              recordMap['purchase_date'],
              recordMap['total_quantity'],
              recordMap['total_amount'],
              recordMap['supplier'],
              recordMap['doctor'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
              recordId,
            ]);
            LogManager.i('PurchaseSyncService',
                '成功更新MySQL采购记录(id=$recordId)，影响行数: ${result.affectedRows}');
          } else {
            final result = await conn.query('''
              INSERT INTO purchase_records
              (id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              recordId,
              recordMap['purchase_date'],
              recordMap['total_quantity'],
              recordMap['total_amount'],
              recordMap['supplier'],
              recordMap['doctor'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
            ]);
            LogManager.i('PurchaseSyncService',
                '成功将采购记录(id=$recordId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          LogManager.e('PurchaseSyncService', '同步采购记录到MySQL时出错', error: e);
        }
      } catch (e) {
        LogManager.e('PurchaseSyncService', '采购记录同步到MySQL发生不可预期错误', error: e);
      }
    });
  }

  /// 尝试从MySQL删除采购记录（非阻塞操作，级联删除采购项目）
  Future<void> syncDeletePurchaseRecordToMySQL(int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w(
              'PurchaseSyncService', 'MySQL连接不可用，跳过采购记录删除同步(id=$recordId)');
          return;
        }

        try {
          // 先删除关联的采购项目
          final itemsResult = await conn.query(
            'DELETE FROM purchase_items WHERE purchase_record_id = ?',
            [recordId],
          );
          LogManager.i('PurchaseSyncService',
              '成功从MySQL删除采购项目，影响行数: ${itemsResult.affectedRows}');

          // 再删除采购记录
          final recordResult = await conn.query(
            'DELETE FROM purchase_records WHERE id = ?',
            [recordId],
          );
          LogManager.i('PurchaseSyncService',
              '成功从MySQL删除采购记录(id=$recordId)，影响行数: ${recordResult.affectedRows}');
        } catch (e) {
          LogManager.e('PurchaseSyncService', '从MySQL删除采购记录(id=$recordId)时出错',
              error: e);
        }
      } catch (e) {
        LogManager.e('PurchaseSyncService', '采购记录删除同步到MySQL发生不可预期错误', error: e);
      }
    });
  }

  /// 尝试将SQLite中的采购项目同步到MySQL（非阻塞操作）
  Future<void> syncPurchaseItemToMySQL(
      Map<String, dynamic> itemMap, int itemId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w(
              'PurchaseSyncService', 'MySQL连接不可用，跳过采购项目同步(id=$itemId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT id FROM purchase_items WHERE id = ? LIMIT 1',
            [itemId],
          );

          if (existResult.isNotEmpty) {
            final result = await conn.query('''
              UPDATE purchase_items SET
                purchase_record_id = ?, material_id = ?, material_name = ?,
                quantity = ?, unit = ?, unit_price = ?, total_price = ?,
                created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              itemMap['purchase_record_id'],
              itemMap['material_id'],
              itemMap['material_name'],
              itemMap['quantity'],
              itemMap['unit'],
              itemMap['unit_price'],
              itemMap['total_price'],
              itemMap['created_at'],
              itemMap['updated_at'],
              itemId,
            ]);
            LogManager.i('PurchaseSyncService',
                '成功更新MySQL采购项目(id=$itemId)，影响行数: ${result.affectedRows}');
          } else {
            final result = await conn.query('''
              INSERT INTO purchase_items
              (id, purchase_record_id, material_id, material_name, quantity, unit, unit_price, total_price, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              itemId,
              itemMap['purchase_record_id'],
              itemMap['material_id'],
              itemMap['material_name'],
              itemMap['quantity'],
              itemMap['unit'],
              itemMap['unit_price'],
              itemMap['total_price'],
              itemMap['created_at'],
              itemMap['updated_at'],
            ]);
            LogManager.i('PurchaseSyncService',
                '成功将采购项目(id=$itemId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          LogManager.e('PurchaseSyncService', '同步采购项目到MySQL时出错', error: e);
        }
      } catch (e) {
        LogManager.e('PurchaseSyncService', '采购项目同步到MySQL发生不可预期错误', error: e);
      }
    });
  }

  /// 尝试从MySQL删除采购项目（非阻塞操作）
  Future<void> syncDeletePurchaseItemToMySQL(int itemId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          LogManager.w(
              'PurchaseSyncService', 'MySQL连接不可用，跳过采购项目删除同步(id=$itemId)');
          return;
        }

        try {
          final result = await conn.query(
            'DELETE FROM purchase_items WHERE id = ?',
            [itemId],
          );
          LogManager.i('PurchaseSyncService',
              '成功从MySQL删除采购项目(id=$itemId)，影响行数: ${result.affectedRows}');
        } catch (e) {
          LogManager.e('PurchaseSyncService', '从MySQL删除采购项目(id=$itemId)时出错',
              error: e);
        }
      } catch (e) {
        LogManager.e('PurchaseSyncService', '采购项目删除同步到MySQL发生不可预期错误', error: e);
      }
    });
  }
}

import 'package:sqflite/sqflite.dart';

import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import 'purchase_data_source.dart';

class SqlitePurchaseDataSource implements PurchaseDataSource {
  final Database _database;

  SqlitePurchaseDataSource(this._database);

  @override
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter}) async {
    String query = 'SELECT * FROM purchase_records';
    final queryArgs = <dynamic>[];

    if (doctorFilter != null) {
      query += ' WHERE doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final result = await _database.rawQuery(query, queryArgs);
    return result
        .map((e) => PurchaseRecord.fromMap(e, dataSource: 'sqlite'))
        .toList();
  }

  @override
  Future<PurchaseRecord?> getPurchaseById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_records WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;
    return PurchaseRecord.fromMap(result.first, dataSource: 'sqlite');
  }

  @override
  Future<int> createPurchase(PurchaseRecord purchase) async {
    return _database.insert('purchase_records', purchase.toMap());
  }

  @override
  Future<bool> updatePurchase(PurchaseRecord purchase) async {
    final count = await _database.update(
      'purchase_records',
      purchase.toMap(),
      where: 'id = ?',
      whereArgs: [purchase.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deletePurchase(int id) async {
    return _database.transaction((txn) async {
      await txn.delete(
        'purchase_items',
        where: 'purchase_record_id = ?',
        whereArgs: [id],
      );
      final count = await txn.delete(
        'purchase_records',
        where: 'id = ?',
        whereArgs: [id],
      );
      return count > 0;
    });
  }

  @override
  Future<List<PurchaseRecord>> searchPurchases(
    String keyword, {
    String? doctorFilter,
  }) async {
    String query = '''
      SELECT * FROM purchase_records
      WHERE (
        supplier LIKE ?
        OR notes LIKE ?
        OR doctor LIKE ?
        OR CAST(id AS TEXT) LIKE ?
        OR CAST(total_amount AS TEXT) LIKE ?
        OR EXISTS (
          SELECT 1 FROM purchase_items pi
          WHERE pi.purchase_record_id = purchase_records.id
            AND pi.material_name LIKE ?
        )
      )
    ''';
    final pattern = '%$keyword%';
    final queryArgs = <dynamic>[
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
      pattern,
    ];

    if (doctorFilter != null) {
      query += ' AND doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final result = await _database.rawQuery(query, queryArgs);
    return result
        .map((e) => PurchaseRecord.fromMap(e, dataSource: 'sqlite'))
        .toList();
  }

  @override
  Future<double> getTotalPurchaseAmount({String? doctorFilter}) async {
    String query = 'SELECT SUM(total_amount) as total FROM purchase_records';
    final queryArgs = <dynamic>[];

    if (doctorFilter != null) {
      query += ' WHERE doctor = ?';
      queryArgs.add(doctorFilter);
    }

    final result = await _database.rawQuery(query, queryArgs);
    final row = result.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<PurchaseRecord>> getPurchasesByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  }) async {
    String query = '''
      SELECT * FROM purchase_records
      WHERE purchase_date BETWEEN ? AND ?
    ''';
    final queryArgs = [startDate.toIso8601String(), endDate.toIso8601String()];

    if (doctorFilter != null) {
      query += ' AND doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final result = await _database.rawQuery(query, queryArgs);
    return result
        .map((e) => PurchaseRecord.fromMap(e, dataSource: 'sqlite'))
        .toList();
  }

  @override
  Future<List<dynamic>> getPurchaseItemsByRecordId(int recordId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_items WHERE purchase_record_id = ? ORDER BY id',
      [recordId],
    );
    return result;
  }

  @override
  Future<int> createPurchaseItemWithTotals(PurchaseItem item) async {
    return _database.transaction((txn) async {
      final id = await txn.insert('purchase_items', item.toMap());
      await _updateTotals(txn, item.purchaseRecordId);
      return id;
    });
  }

  @override
  Future<bool> updatePurchaseItemWithTotals(PurchaseItem item) async {
    return _database.transaction((txn) async {
      final count = await txn.update(
        'purchase_items',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      if (count == 0) return false;
      await _updateTotals(txn, item.purchaseRecordId);
      return true;
    });
  }

  @override
  Future<bool> deletePurchaseItemWithTotals(
    int itemId, {
    required int purchaseRecordId,
  }) async {
    return _database.transaction((txn) async {
      final count = await txn.delete(
        'purchase_items',
        where: 'id = ? AND purchase_record_id = ?',
        whereArgs: [itemId, purchaseRecordId],
      );
      if (count == 0) return false;
      await _updateTotals(txn, purchaseRecordId);
      return true;
    });
  }

  Future<void> _updateTotals(
    DatabaseExecutor executor,
    int purchaseRecordId,
  ) async {
    final totals = await executor.rawQuery(
      '''
      SELECT COALESCE(SUM(quantity), 0) AS total_quantity,
             COALESCE(SUM(total_price), 0) AS total_amount
      FROM purchase_items
      WHERE purchase_record_id = ?
      ''',
      [purchaseRecordId],
    );
    final row = totals.first;
    final count = await executor.update(
      'purchase_records',
      {
        'total_quantity': (row['total_quantity'] as num).toInt(),
        'total_amount': (row['total_amount'] as num).toDouble(),
      },
      where: 'id = ?',
      whereArgs: [purchaseRecordId],
    );
    if (count == 0) {
      throw StateError('采购记录不存在，无法更新采购汇总');
    }
  }
}

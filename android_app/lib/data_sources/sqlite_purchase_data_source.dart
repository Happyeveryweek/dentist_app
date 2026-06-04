import 'package:sqflite/sqflite.dart';

import '../models/purchase_record.dart';
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
    return result.map((e) => PurchaseRecord.fromMap(e, dataSource: 'sqlite')).toList();
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
    await _database.delete(
      'purchase_items',
      where: 'purchase_record_id = ?',
      whereArgs: [id],
    );

    final count = await _database.delete(
      'purchase_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<List<PurchaseRecord>> searchPurchases(String keyword, {String? doctorFilter}) async {
    String query = '''
      SELECT * FROM purchase_records
      WHERE (supplier LIKE ? OR notes LIKE ? OR doctor LIKE ?)
    ''';
    final queryArgs = <dynamic>['%$keyword%', '%$keyword%', '%$keyword%'];

    if (doctorFilter != null) {
      query += ' AND doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final result = await _database.rawQuery(query, queryArgs);
    return result.map((e) => PurchaseRecord.fromMap(e, dataSource: 'sqlite')).toList();
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
  Future<List<PurchaseRecord>> getPurchasesByDateRange(DateTime startDate, DateTime endDate, {String? doctorFilter}) async {
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
    return result.map((e) => PurchaseRecord.fromMap(e, dataSource: 'sqlite')).toList();
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
  Future<int> createPurchaseItem(dynamic item) async {
    return _database.insert('purchase_items', item.toMap());
  }

  @override
  Future<bool> updatePurchaseItem(dynamic item) async {
    final count = await _database.update(
      'purchase_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deletePurchaseItem(int itemId) async {
    final count = await _database.delete(
      'purchase_items',
      where: 'id = ?',
      whereArgs: [itemId],
    );
    return count > 0;
  }
}

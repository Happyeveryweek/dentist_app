import 'package:mysql1/mysql1.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/purchase_record.dart';
import '../utils/datetime_formatter.dart';
import 'purchase_data_source.dart';

class MySqlPurchaseDataSource implements PurchaseDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlPurchaseDataSource.withConnectionGetter(this._getConnection);

  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];

      if (field == 'purchase_date' ||
          field == 'created_at' ||
          field == 'updated_at') {
        if (value is DateTime) {
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        if (field == 'supplier' || field == 'notes' || field == 'doctor') {
          try {
            final bytes = value.toBytes();
            map[field] =
                bytes.isNotEmpty
                    ? utf8.decode(bytes, allowMalformed: true)
                    : '';
          } catch (e) {
            print('Blob转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else if (value is Uint8List) {
        if (field == 'supplier' || field == 'notes' || field == 'doctor') {
          try {
            map[field] =
                value.isNotEmpty
                    ? utf8.decode(value, allowMalformed: true)
                    : '';
          } catch (e) {
            print('Uint8List转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else {
        map[field] = value;
      }
    }
    return map;
  }

  MySqlConnection _connection() {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');
    return connection;
  }

  @override
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter}) async {
    String query = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records
    ''';
    final queryArgs = <dynamic>[];

    if (doctorFilter != null) {
      query += ' WHERE doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final results = await _connection().query(query, queryArgs);
    return results
        .map(
          (row) => PurchaseRecord.fromMap(
            _convertMySqlRow(row),
            dataSource: 'mysql',
          ),
        )
        .toList();
  }

  @override
  Future<PurchaseRecord?> getPurchaseById(int id) async {
    final results = await _connection().query(
      '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records
      WHERE id = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;
    return PurchaseRecord.fromMap(
      _convertMySqlRow(results.first),
      dataSource: 'mysql',
    );
  }

  @override
  Future<int> createPurchase(PurchaseRecord purchase) async {
    final result = await _connection().query(
      '''
      INSERT INTO purchase_records (purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        DateTimeFormatter.toDbString(purchase.purchaseDate),
        purchase.totalQuantity,
        purchase.totalAmount,
        purchase.supplier,
        purchase.notes,
        purchase.doctor,
        DateTimeFormatter.toDbString(purchase.createdAt),
        DateTimeFormatter.toDbString(purchase.updatedAt),
      ],
    );

    return result.insertId ?? 0;
  }

  @override
  Future<bool> updatePurchase(PurchaseRecord purchase) async {
    final result = await _connection().query(
      '''
      UPDATE purchase_records
      SET purchase_date = ?, total_quantity = ?, total_amount = ?, supplier = ?, notes = ?, doctor = ?, updated_at = ?
      WHERE id = ?
    ''',
      [
        DateTimeFormatter.toDbString(purchase.purchaseDate),
        purchase.totalQuantity,
        purchase.totalAmount,
        purchase.supplier,
        purchase.notes,
        purchase.doctor,
        DateTimeFormatter.toDbString(purchase.updatedAt),
        purchase.id,
      ],
    );

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePurchase(int id) async {
    await _connection().query(
      'DELETE FROM purchase_items WHERE purchase_record_id = ?',
      [id],
    );
    final result = await _connection().query(
      'DELETE FROM purchase_records WHERE id = ?',
      [id],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<PurchaseRecord>> searchPurchases(
    String keyword, {
    String? doctorFilter,
  }) async {
    String query = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records
      WHERE (
        supplier LIKE ?
        OR notes LIKE ?
        OR doctor LIKE ?
        OR CAST(id AS CHAR) LIKE ?
        OR CAST(total_amount AS CHAR) LIKE ?
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

    final results = await _connection().query(query, queryArgs);
    return results
        .map(
          (row) => PurchaseRecord.fromMap(
            _convertMySqlRow(row),
            dataSource: 'mysql',
          ),
        )
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

    final results = await _connection().query(query, queryArgs);
    final row = results.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<PurchaseRecord>> getPurchasesByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  }) async {
    String query = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records
      WHERE purchase_date BETWEEN ? AND ?
    ''';
    final queryArgs = <dynamic>[
      DateTimeFormatter.toDbString(startDate),
      DateTimeFormatter.toDbString(endDate),
    ];

    if (doctorFilter != null) {
      query += ' AND doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final results = await _connection().query(query, queryArgs);
    return results
        .map(
          (row) => PurchaseRecord.fromMap(
            _convertMySqlRow(row),
            dataSource: 'mysql',
          ),
        )
        .toList();
  }

  @override
  Future<List<dynamic>> getPurchaseItemsByRecordId(int recordId) async {
    final results = await _connection().query(
      'SELECT * FROM purchase_items WHERE purchase_record_id = ? ORDER BY id',
      [recordId],
    );
    return results.map((row) => _convertMySqlRow(row)).toList();
  }

  @override
  Future<int> createPurchaseItem(dynamic item) async {
    final result = await _connection().query(
      '''
      INSERT INTO purchase_items
      (purchase_record_id, material_id, material_name, quantity, unit_price, total_price, unit, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''',
      [
        item.purchaseRecordId,
        item.materialId,
        item.materialName,
        item.quantity,
        item.unitPrice,
        item.totalPrice,
        item.unit,
        DateTimeFormatter.toDbString(item.createdAt),
        DateTimeFormatter.toDbString(item.updatedAt),
      ],
    );

    return result.insertId ?? 0;
  }

  @override
  Future<bool> updatePurchaseItem(dynamic item) async {
    final result = await _connection().query(
      '''
      UPDATE purchase_items SET
      purchase_record_id = ?, material_id = ?, material_name = ?, quantity = ?,
      unit_price = ?, total_price = ?, unit = ?, updated_at = ?
      WHERE id = ?
    ''',
      [
        item.purchaseRecordId,
        item.materialId,
        item.materialName,
        item.quantity,
        item.unitPrice,
        item.totalPrice,
        item.unit,
        DateTimeFormatter.toDbString(item.updatedAt),
        item.id,
      ],
    );

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePurchaseItem(int itemId) async {
    final result = await _connection().query(
      'DELETE FROM purchase_items WHERE id = ?',
      [itemId],
    );

    return (result.affectedRows ?? 0) > 0;
  }
}

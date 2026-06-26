import 'package:mysql1/mysql1.dart';
import '../models/purchase_record.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/app_logger.dart';

// 抽象采购数据源接口
abstract class PurchaseDataSource {
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter});
  Future<PurchaseRecord?> getPurchaseById(int id);
  Future<int> createPurchase(PurchaseRecord purchase);
  Future<bool> updatePurchase(PurchaseRecord purchase);
  Future<bool> deletePurchase(int id);
  Future<List<PurchaseRecord>> searchPurchases(
    String keyword, {
    String? doctorFilter,
  });
  Future<double> getTotalPurchaseAmount({String? doctorFilter});
  Future<List<PurchaseRecord>> getPurchasesByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  });

  // 采购项目明细相关方法
  Future<List<dynamic>> getPurchaseItemsByRecordId(int recordId);
  Future<int> createPurchaseItem(dynamic item);
  Future<bool> updatePurchaseItem(dynamic item);
  Future<bool> deletePurchaseItem(int itemId);
}

/*
// SQLite采购数据源实现
class SqlitePurchaseDataSource implements PurchaseDataSource {
  final Database _database;

  SqlitePurchaseDataSource(this._database);

  @override
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter}) async {
    String query = 'SELECT * FROM purchase_records';
    List<dynamic> queryArgs = [];
    
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
      'SELECT * FROM purchase_records WHERE id = ?', [id]
    );
    if (result.isEmpty) return null;
    return PurchaseRecord.fromMap(result.first, dataSource: 'sqlite');
  }

  @override
  Future<int> createPurchase(PurchaseRecord purchase) async {
    return await _database.insert('purchase_records', purchase.toMap());
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
    // 先删除相关的采购项目（级联删除）
    await _database.delete(
      'purchase_items',
      where: 'purchase_record_id = ?',
      whereArgs: [id],
    );
    
    // 再删除采购记录
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
    List<dynamic> queryArgs = ['%$keyword%', '%$keyword%', '%$keyword%'];
    
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
    List<dynamic> queryArgs = [];
    
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
    List<dynamic> queryArgs = [DateTimeFormatter.toDbString(startDate), DateTimeFormatter.toDbString(endDate)];
    
    if (doctorFilter != null) {
      query += ' AND doctor = ?';
      queryArgs.add(doctorFilter);
    }
    
    query += ' ORDER BY purchase_date DESC';
    
    final result = await _database.rawQuery(query, queryArgs);
    return result.map((e) => PurchaseRecord.fromMap(e, dataSource: 'sqlite')).toList();
  }

  // 采购项目明细相关方法
  @override
  Future<List<dynamic>> getPurchaseItemsByRecordId(int recordId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_items WHERE purchase_record_id = ? ORDER BY id',
      [recordId]
    );
    return result;
  }

  @override
  Future<int> createPurchaseItem(dynamic item) async {
    return await _database.insert('purchase_items', item.toMap());
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
*/

// MySQL采购数据源实现（使用动态连接获取）
class MySqlPurchaseDataSource implements PurchaseDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlPurchaseDataSource.withConnectionGetter(this._getConnection);

  // 辅助方法：处理MySQL行数据转换
  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];

      // 处理日期字段 - 使用统一格式，确保转换为本地时间
      if (field == 'purchase_date' ||
          field == 'created_at' ||
          field == 'updated_at') {
        if (value is DateTime) {
          // 如果MySQL返回的是UTC时间，转换为本地时间
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        // 处理Blob字段，特别是supplier、notes和doctor
        if (field == 'supplier' || field == 'notes' || field == 'doctor') {
          try {
            final bytes = value.toBytes();
            if (bytes.isNotEmpty) {
              final stringValue = utf8.decode(bytes, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            AppLogger.info('Blob转换失败: $e');
            map[field] = '';
          }
        } else {
          map[field] = value;
        }
      } else if (value is Uint8List) {
        // 处理Uint8List类型
        if (field == 'supplier' || field == 'notes' || field == 'doctor') {
          try {
            if (value.isNotEmpty) {
              final stringValue = utf8.decode(value, allowMalformed: true);
              map[field] = stringValue;
            } else {
              map[field] = '';
            }
          } catch (e) {
            AppLogger.info('Uint8List转换失败: $e');
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

  @override
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter}) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records
    ''';
    List<dynamic> queryArgs = [];

    if (doctorFilter != null) {
      query += ' WHERE doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final results = await connection.query(query, queryArgs);

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
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records 
      WHERE id = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return PurchaseRecord.fromMap(_convertMySqlRow(row), dataSource: 'mysql');
  }

  @override
  Future<int> createPurchase(PurchaseRecord purchase) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
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

    final insertId = result.insertId;
    if (insertId == null) {
      throw Exception('创建采购记录失败：无法获取插入ID');
    }
    return insertId;
  }

  @override
  Future<bool> updatePurchase(PurchaseRecord purchase) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
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
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    // 先删除相关的采购项目（级联删除）
    await connection.query(
      'DELETE FROM purchase_items WHERE purchase_record_id = ?',
      [id],
    );

    // 再删除采购记录
    final result = await connection.query(
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
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records 
      WHERE (supplier LIKE ? OR notes LIKE ? OR doctor LIKE ?)
    ''';
    List<dynamic> queryArgs = ['%$keyword%', '%$keyword%', '%$keyword%'];

    if (doctorFilter != null) {
      query += ' AND doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final results = await connection.query(query, queryArgs);

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
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = 'SELECT SUM(total_amount) as total FROM purchase_records';
    List<dynamic> queryArgs = [];

    if (doctorFilter != null) {
      query += ' WHERE doctor = ?';
      queryArgs.add(doctorFilter);
    }

    final results = await connection.query(query, queryArgs);
    final row = results.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<PurchaseRecord>> getPurchasesByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  }) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    String query = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, notes, doctor, created_at, updated_at
      FROM purchase_records 
      WHERE purchase_date BETWEEN ? AND ?
    ''';
    List<dynamic> queryArgs = [startDate, endDate];

    if (doctorFilter != null) {
      query += ' AND doctor = ?';
      queryArgs.add(doctorFilter);
    }

    query += ' ORDER BY purchase_date DESC';

    final results = await connection.query(query, queryArgs);

    return results
        .map(
          (row) => PurchaseRecord.fromMap(
            _convertMySqlRow(row),
            dataSource: 'mysql',
          ),
        )
        .toList();
  }

  // 采购项目明细相关方法
  @override
  Future<List<dynamic>> getPurchaseItemsByRecordId(int recordId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      'SELECT * FROM purchase_items WHERE purchase_record_id = ? ORDER BY id',
      [recordId],
    );

    return results.map((row) => _convertMySqlRow(row)).toList();
  }

  @override
  Future<int> createPurchaseItem(dynamic item) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
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
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
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
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      'DELETE FROM purchase_items WHERE id = ?',
      [itemId],
    );
    return (result.affectedRows ?? 0) > 0;
  }
}

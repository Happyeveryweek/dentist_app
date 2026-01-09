import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'base_mysql_data_source.dart';

// 抽象采购数据源接口
abstract class PurchaseDataSource {
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter});
  Future<PurchaseRecord?> getPurchaseById(int id);
  Future<int> createPurchase(PurchaseRecord purchase);
  Future<bool> updatePurchase(PurchaseRecord purchase);
  Future<bool> deletePurchase(int id);
  Future<List<PurchaseRecord>> searchPurchases(String keyword, {String? doctorFilter});
  Future<double> getTotalPurchaseAmount({String? doctorFilter});
  Future<List<PurchaseRecord>> getPurchasesByDateRange(DateTime startDate, DateTime endDate, {String? doctorFilter});
  
  // 分页查询方法
  Future<int> getPurchasesCount({String? searchQuery, String? doctorFilter});
  Future<List<PurchaseRecord>> getPaginatedPurchases({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
    String? doctorFilter,
  });
  
  // 采购项目相关方法
  Future<List<PurchaseItem>> getPurchaseItemsByRecordId(int recordId);
  Future<int> createPurchaseItem(PurchaseItem item);
  Future<bool> updatePurchaseItem(PurchaseItem item);
  Future<bool> deletePurchaseItem(int id);
}

// SQLite采购数据源实现
class SqlitePurchaseDataSource implements PurchaseDataSource {
  final Database _database;

  SqlitePurchaseDataSource(this._database);

  @override
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter}) async {
    String sql = 'SELECT * FROM purchase_records';
    List<Object?> args = [];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' WHERE doctor = ?';
      args.add(doctorFilter);
    }
    
    sql += ' ORDER BY updated_at DESC';
    
    final result = await _database.rawQuery(sql, args);
    return result.map((e) => PurchaseRecord.fromMap(e)).toList();
  }

  @override
  Future<PurchaseRecord?> getPurchaseById(int id) async {
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_records WHERE id = ?', [id]
    );
    if (result.isEmpty) return null;
    return PurchaseRecord.fromMap(result.first);
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
    // 先删除相关的采购项目
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
    String sql = '''
      SELECT * FROM purchase_records 
      WHERE (supplier LIKE ? OR doctor LIKE ? OR notes LIKE ?)
    ''';
    List<Object?> args = ['%$keyword%', '%$keyword%', '%$keyword%'];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' AND doctor = ?';
      args.add(doctorFilter);
    }
    
    sql += ' ORDER BY updated_at DESC';
    
    final result = await _database.rawQuery(sql, args);
    return result.map((e) => PurchaseRecord.fromMap(e)).toList();
  }

  @override
  Future<double> getTotalPurchaseAmount({String? doctorFilter}) async {
    String sql = 'SELECT SUM(total_amount) as total FROM purchase_records';
    List<Object?> args = [];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' WHERE doctor = ?';
      args.add(doctorFilter);
    }
    
    final result = await _database.rawQuery(sql, args);
    final row = result.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<PurchaseRecord>> getPurchasesByDateRange(DateTime startDate, DateTime endDate, {String? doctorFilter}) async {
    String sql = '''
      SELECT * FROM purchase_records 
      WHERE purchase_date BETWEEN ? AND ?
    ''';
    List<Object?> args = [DateTimeFormatter.toDbString(startDate), DateTimeFormatter.toDbString(endDate)];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' AND doctor = ?';
      args.add(doctorFilter);
    }
    
    sql += ' ORDER BY updated_at DESC';
    
    final result = await _database.rawQuery(sql, args);
    return result.map((e) => PurchaseRecord.fromMap(e)).toList();
  }

  @override
  Future<int> getPurchasesCount({String? searchQuery, String? doctorFilter}) async {
    String sql = 'SELECT COUNT(*) AS cnt FROM purchase_records';
    final whereConditions = <String>[];
    final whereArgs = <Object?>[];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereConditions.add('(supplier LIKE ? OR doctor LIKE ? OR notes LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      whereConditions.add('doctor = ?');
      whereArgs.add(doctorFilter);
    }
    
    if (whereConditions.isNotEmpty) {
      sql += ' WHERE ' + whereConditions.join(' AND ');
    }
    
    final result = await _database.rawQuery(sql, whereArgs);
    final count = result.isNotEmpty ? (result.first['cnt'] as int?) : 0;
    return count ?? 0;
  }

  @override
  Future<List<PurchaseRecord>> getPaginatedPurchases({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
    String? doctorFilter,
  }) async {
    final offset = (page - 1) * pageSize;
    String sql = 'SELECT * FROM purchase_records';
    final whereConditions = <String>[];
    final whereArgs = <Object?>[];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereConditions.add('(supplier LIKE ? OR doctor LIKE ? OR notes LIKE ?)');
      whereArgs.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      whereConditions.add('doctor = ?');
      whereArgs.add(doctorFilter);
    }
    
    if (whereConditions.isNotEmpty) {
      sql += ' WHERE ' + whereConditions.join(' AND ');
    }
    
    final orderBy = '$sortBy $sortOrder';
    sql += ' ORDER BY $orderBy LIMIT ? OFFSET ?';
    whereArgs.addAll([pageSize, offset]);
    
    final result = await _database.rawQuery(sql, whereArgs);
    return result.map((e) => PurchaseRecord.fromMap(e)).toList();
  }

  @override
  Future<List<PurchaseItem>> getPurchaseItemsByRecordId(int recordId) async {
    final result = await _database.query(
      'purchase_items',
      where: 'purchase_record_id = ?',
      whereArgs: [recordId],
      orderBy: 'updated_at DESC',
    );
    return result.map((e) => PurchaseItem.fromMap(e)).toList();
  }

  @override
  Future<int> createPurchaseItem(PurchaseItem item) async {
    return await _database.insert('purchase_items', item.toMap());
  }

  @override
  Future<bool> updatePurchaseItem(PurchaseItem item) async {
    // 使用 toMap() 方法会自动包含 material_id 字段
    final count = await _database.update(
      'purchase_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deletePurchaseItem(int id) async {
    final count = await _database.delete(
      'purchase_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }
}

// MySQL采购数据源实现（使用动态连接获取）
class MySqlPurchaseDataSource extends BaseMySqlDataSource implements PurchaseDataSource {
  MySqlPurchaseDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );

  @override
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter}) async {
    String sql = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at
      FROM purchase_records
    ''';
    List<Object?> args = [];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' WHERE doctor = ?';
      args.add(doctorFilter);
    }
    
    sql += ' ORDER BY updated_at DESC';
    
    final results = await executeQuery(sql, args);
    return results.map((row) => PurchaseRecord.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<PurchaseRecord?> getPurchaseById(int id) async {
    final results = await executeQuery('''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at
      FROM purchase_records 
      WHERE id = ?
    ''', [id]);
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    return PurchaseRecord.fromMap(convertRowToMap(row));
  }

  @override
  Future<int> createPurchase(PurchaseRecord purchase) async {
    final result = await executeQuery('''
      INSERT INTO purchase_records (purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      DateTimeFormatter.toDbString(purchase.purchaseDate),
      purchase.totalQuantity,
      purchase.totalAmount,
      purchase.supplier,
      purchase.doctor,
      purchase.notes,
      DateTimeFormatter.toDbString(purchase.createdAt),
      DateTimeFormatter.toDbString(purchase.updatedAt),
    ]);
    
    return result.insertId!;
  }

  @override
  Future<bool> updatePurchase(PurchaseRecord purchase) async {
    final result = await executeQuery('''
      UPDATE purchase_records 
      SET purchase_date = ?, total_quantity = ?, total_amount = ?, supplier = ?, doctor = ?, notes = ?, updated_at = ?
      WHERE id = ?
    ''', [
      DateTimeFormatter.toDbString(purchase.purchaseDate),
      purchase.totalQuantity,
      purchase.totalAmount,
      purchase.supplier,
      purchase.doctor,
      purchase.notes,
      DateTimeFormatter.toDbString(purchase.updatedAt),
      purchase.id,
    ]);
    
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deletePurchase(int id) async {
    // 先删除相关的采购项目
    await executeQuery('DELETE FROM purchase_items WHERE purchase_record_id = ?', [id]);
    
    // 再删除采购记录
    final result = await executeQuery('DELETE FROM purchase_records WHERE id = ?', [id]);
    return result.affectedRows! > 0;
  }

  @override
  Future<List<PurchaseRecord>> searchPurchases(String keyword, {String? doctorFilter}) async {
    String sql = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at
      FROM purchase_records 
      WHERE (supplier LIKE ? OR doctor LIKE ? OR notes LIKE ?)
    ''';
    List<Object?> args = ['%$keyword%', '%$keyword%', '%$keyword%'];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' AND doctor = ?';
      args.add(doctorFilter);
    }
    
    sql += ' ORDER BY updated_at DESC';
    
    final results = await executeQuery(sql, args);
    return results.map((row) => PurchaseRecord.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<double> getTotalPurchaseAmount({String? doctorFilter}) async {
    String sql = 'SELECT SUM(total_amount) as total FROM purchase_records';
    List<Object?> args = [];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' WHERE doctor = ?';
      args.add(doctorFilter);
    }
    
    final results = await executeQuery(sql, args);
    final row = results.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<PurchaseRecord>> getPurchasesByDateRange(DateTime startDate, DateTime endDate, {String? doctorFilter}) async {
    String sql = '''
      SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at
      FROM purchase_records 
      WHERE purchase_date BETWEEN ? AND ?
    ''';
    List<Object?> args = [startDate, endDate];
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      sql += ' AND doctor = ?';
      args.add(doctorFilter);
    }
    
    sql += ' ORDER BY updated_at DESC';
    
    final results = await executeQuery(sql, args);
    return results.map((row) => PurchaseRecord.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<int> getPurchasesCount({String? searchQuery, String? doctorFilter}) async {
    final conditions = <String>[];
    final args = <Object?>[];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(supplier LIKE ? OR doctor LIKE ? OR notes LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      conditions.add('doctor = ?');
      args.add(doctorFilter);
    }
    
    final whereClause = conditions.isNotEmpty ? (' WHERE ' + conditions.join(' AND ')) : '';
    final results = await executeQuery('SELECT COUNT(*) AS cnt FROM purchase_records$whereClause', args);
    if (results.isEmpty) return 0;
    final row = results.first;
    final dynamic valNamed = row['cnt'];
    if (valNamed is int) return valNamed;
    if (valNamed is BigInt) return valNamed.toInt();
    final dynamic valIndex = row[0];
    if (valIndex is int) return valIndex;
    if (valIndex is BigInt) return valIndex.toInt();
    return 0;
  }

  @override
  Future<List<PurchaseRecord>> getPaginatedPurchases({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
    String? doctorFilter,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('(supplier LIKE ? OR doctor LIKE ? OR notes LIKE ?)');
      args.addAll(['%$searchQuery%', '%$searchQuery%', '%$searchQuery%']);
    }
    
    if (doctorFilter != null && doctorFilter.isNotEmpty) {
      conditions.add('doctor = ?');
      args.add(doctorFilter);
    }
    
    final whereClause = conditions.isNotEmpty ? (' WHERE ' + conditions.join(' AND ')) : '';
    final orderBy = '$sortBy $sortOrder';
    final offset = (page - 1) * pageSize;
    final sql = 'SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at FROM purchase_records$whereClause ORDER BY $orderBy LIMIT $offset, $pageSize';
    final results = await executeQuery(sql, args);
    
    return results.map((row) => PurchaseRecord.fromMap(convertRowToMap(row))).toList();
  }

  @override
  Future<List<PurchaseItem>> getPurchaseItemsByRecordId(int recordId) async {
    final results = await executeQuery('''
      SELECT * FROM purchase_items 
      WHERE purchase_record_id = ? 
      ORDER BY updated_at DESC
    ''', [recordId]);
    
    final items = <PurchaseItem>[];
    for (var row in results) {
      final map = convertRowToMap(row);
      items.add(PurchaseItem.fromMap(map));
    }
    return items;
  }

  @override
  Future<int> createPurchaseItem(PurchaseItem item) async {
    final result = await executeQuery('''
      INSERT INTO purchase_items (purchase_record_id, material_id, material_name, quantity, unit_price, total_price, unit, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      item.purchaseRecordId,
      item.materialId,
      item.materialName,
      item.quantity,
      item.unitPrice,
      item.totalPrice,
      item.unit ?? '个',
      DateTimeFormatter.toDbString(item.createdAt),
      DateTimeFormatter.toDbString(item.updatedAt),
    ]);
    
    return result.insertId!;
  }

  @override
  Future<bool> updatePurchaseItem(PurchaseItem item) async {
    final result = await executeQuery('''
      UPDATE purchase_items 
      SET material_id = ?, material_name = ?, quantity = ?, unit_price = ?, total_price = ?, unit = ?, updated_at = ?
      WHERE id = ?
    ''', [
      item.materialId,
      item.materialName,
      item.quantity,
      item.unitPrice,
      item.totalPrice,
      item.unit,
      DateTimeFormatter.toDbString(item.updatedAt),
      item.id
    ]);
    
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deletePurchaseItem(int id) async {
    final result = await executeQuery('DELETE FROM purchase_items WHERE id = ?', [id]);
    return result.affectedRows! > 0;
  }
}
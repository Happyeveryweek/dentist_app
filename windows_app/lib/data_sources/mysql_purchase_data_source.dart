import 'package:mysql1/mysql1.dart';
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../utils/datetime_formatter.dart';
import 'base_mysql_data_source.dart';
import 'purchase_data_source.dart';

/// MySQL 采购数据源实现
class MySqlPurchaseDataSource extends BaseMySqlDataSource
    implements PurchaseDataSource {
  MySqlPurchaseDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );

  _PurchaseQueryParts _buildPurchaseQueryParts({
    String? searchQuery,
    String? doctorFilter,
    DateTime? startDate,
    DateTime? endDate,
    bool includeSearchFields = false,
  }) {
    final conditions = <String>[];
    final args = <Object?>[];

    final trimmedSearch = searchQuery?.trim();
    if (includeSearchFields &&
        trimmedSearch != null &&
        trimmedSearch.isNotEmpty) {
      conditions.add('''
        (
          supplier LIKE ?
          OR doctor LIKE ?
          OR notes LIKE ?
          OR EXISTS (
            SELECT 1
            FROM purchase_items pi
            WHERE pi.purchase_record_id = purchase_records.id
              AND pi.material_name LIKE ?
          )
        )
      ''');
      args.addAll([
        '%$trimmedSearch%',
        '%$trimmedSearch%',
        '%$trimmedSearch%',
        '%$trimmedSearch%',
      ]);
    }

    final trimmedDoctor = doctorFilter?.trim();
    if (trimmedDoctor != null && trimmedDoctor.isNotEmpty) {
      conditions.add('doctor = ?');
      args.add(trimmedDoctor);
    }

    if (startDate != null) {
      conditions.add('purchase_date >= ?');
      args.add(DateTimeFormatter.toDbString(startDate));
    }
    if (endDate != null) {
      conditions.add('purchase_date <= ?');
      args.add(DateTimeFormatter.toDbString(endDate));
    }

    return _PurchaseQueryParts(
      whereClause: _whereOrEmpty(conditions),
      whereArgs: args,
    );
  }

  String _whereOrEmpty(List<String> conditions) {
    if (conditions.isEmpty) {
      return '';
    }
    return ' WHERE ${conditions.join(' AND ')}';
  }

  @override
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(doctorFilter: doctorFilter);
    final results = await executeQuery(
      'SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at FROM purchase_records${parts.whereClause} ORDER BY updated_at DESC',
      parts.whereArgs,
    );
    return results
        .map((row) => PurchaseRecord.fromMap(convertRowToMap(row)))
        .toList();
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

    final insertId = result.insertId;
    if (insertId == null) {
      throw Exception('创建采购记录后未返回 insertId');
    }
    return insertId;
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

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePurchase(int id) async {
    // 先删除相关的采购项目
    await executeQuery(
        'DELETE FROM purchase_items WHERE purchase_record_id = ?', [id]);

    // 再删除采购记录
    final result =
        await executeQuery('DELETE FROM purchase_records WHERE id = ?', [id]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<PurchaseRecord>> searchPurchases(String keyword,
      {String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(
      searchQuery: keyword,
      doctorFilter: doctorFilter,
      includeSearchFields: true,
    );
    final results = await executeQuery(
      'SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at FROM purchase_records${parts.whereClause} ORDER BY updated_at DESC',
      parts.whereArgs,
    );
    return results
        .map((row) => PurchaseRecord.fromMap(convertRowToMap(row)))
        .toList();
  }

  @override
  Future<double> getTotalPurchaseAmount({String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(doctorFilter: doctorFilter);
    final results = await executeQuery(
      'SELECT SUM(total_amount) as total FROM purchase_records${parts.whereClause}',
      parts.whereArgs,
    );
    final row = results.first;
    final total = row['total'];
    if (total == null) return 0.0;
    if (total is double) return total;
    if (total is int) return total.toDouble();
    if (total is BigInt) return total.toDouble();
    if (total is num) return total.toDouble();
    return double.tryParse(total.toString()) ?? 0.0;
  }

  @override
  Future<List<PurchaseRecord>> getPurchasesByDateRange(
      DateTime startDate, DateTime endDate,
      {String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(
      doctorFilter: doctorFilter,
      startDate: startDate,
      endDate: endDate,
    );
    final results = await executeQuery(
      'SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at FROM purchase_records${parts.whereClause} ORDER BY updated_at DESC',
      parts.whereArgs,
    );
    return results
        .map((row) => PurchaseRecord.fromMap(convertRowToMap(row)))
        .toList();
  }

  @override
  Future<int> getPurchasesCount(
      {String? searchQuery, String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(
      searchQuery: searchQuery,
      doctorFilter: doctorFilter,
      includeSearchFields: true,
    );
    final results = await executeQuery(
      'SELECT COUNT(*) AS cnt FROM purchase_records${parts.whereClause}',
      parts.whereArgs,
    );
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
    final parts = _buildPurchaseQueryParts(
      searchQuery: searchQuery,
      doctorFilter: doctorFilter,
      includeSearchFields: true,
    );
    final orderBy = '$sortBy $sortOrder';
    final offset = (page - 1) * pageSize;
    final results = await executeQuery(
      'SELECT id, purchase_date, total_quantity, total_amount, supplier, doctor, notes, created_at, updated_at FROM purchase_records${parts.whereClause} ORDER BY $orderBy LIMIT $offset, $pageSize',
      parts.whereArgs,
    );

    return results
        .map((row) => PurchaseRecord.fromMap(convertRowToMap(row)))
        .toList();
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

    final insertId = result.insertId;
    if (insertId == null) {
      throw Exception('创建采购项目后未返回 insertId');
    }
    return insertId;
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

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deletePurchaseItem(int id) async {
    final result =
        await executeQuery('DELETE FROM purchase_items WHERE id = ?', [id]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<void> ensureTablesExist() async {
    await executeQuery('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        purchase_record_id INT NOT NULL,
        material_id INT,
        material_name VARCHAR(255) NOT NULL,
        quantity INT NOT NULL DEFAULT 1,
        unit_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        total_price DECIMAL(10,2) NOT NULL DEFAULT 0.00,
        unit VARCHAR(50) DEFAULT '个',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purchase_record_id) REFERENCES purchase_records(id) ON DELETE CASCADE
      )
    ''');
  }
}

class _PurchaseQueryParts {
  final String whereClause;
  final List<Object?> whereArgs;

  const _PurchaseQueryParts({
    required this.whereClause,
    required this.whereArgs,
  });
}

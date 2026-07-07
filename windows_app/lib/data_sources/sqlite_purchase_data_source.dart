import 'package:sqflite/sqflite.dart';
import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../utils/datetime_formatter.dart';
import 'purchase_data_source.dart';

/// SQLite采购数据源实现
class SqlitePurchaseDataSource implements PurchaseDataSource {
  final Database _database;

  SqlitePurchaseDataSource(this._database);

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
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_records${parts.whereClause} ORDER BY updated_at DESC',
      parts.whereArgs,
    );
    return result.map((e) => PurchaseRecord.fromMap(e)).toList();
  }

  @override
  Future<PurchaseRecord?> getPurchaseById(int id) async {
    final result = await _database
        .rawQuery('SELECT * FROM purchase_records WHERE id = ?', [id]);
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
  Future<List<PurchaseRecord>> searchPurchases(String keyword,
      {String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(
      searchQuery: keyword,
      doctorFilter: doctorFilter,
      includeSearchFields: true,
    );
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_records${parts.whereClause} ORDER BY updated_at DESC',
      parts.whereArgs,
    );
    return result.map((e) => PurchaseRecord.fromMap(e)).toList();
  }

  @override
  Future<double> getTotalPurchaseAmount({String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(doctorFilter: doctorFilter);
    final result = await _database.rawQuery(
      'SELECT SUM(total_amount) as total FROM purchase_records${parts.whereClause}',
      parts.whereArgs,
    );
    final row = result.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
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
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_records${parts.whereClause} ORDER BY updated_at DESC',
      parts.whereArgs,
    );
    return result.map((e) => PurchaseRecord.fromMap(e)).toList();
  }

  @override
  Future<int> getPurchasesCount(
      {String? searchQuery, String? doctorFilter}) async {
    final parts = _buildPurchaseQueryParts(
      searchQuery: searchQuery,
      doctorFilter: doctorFilter,
      includeSearchFields: true,
    );
    final result = await _database.rawQuery(
      'SELECT COUNT(*) AS cnt FROM purchase_records${parts.whereClause}',
      parts.whereArgs,
    );
    final row = result.first;
    final dynamic count = row['cnt'] ?? row[0];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
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
    final offset = (page - 1) * pageSize;
    final parts = _buildPurchaseQueryParts(
      searchQuery: searchQuery,
      doctorFilter: doctorFilter,
      includeSearchFields: true,
    );
    final result = await _database.rawQuery(
      'SELECT * FROM purchase_records${parts.whereClause} ORDER BY $sortBy $sortOrder LIMIT ? OFFSET ?',
      [...parts.whereArgs, pageSize, offset],
    );
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

  @override
  Future<void> ensureTablesExist() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_record_id INTEGER NOT NULL,
        material_id INTEGER,
        material_name TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        unit_price REAL NOT NULL DEFAULT 0.0,
        total_price REAL NOT NULL DEFAULT 0.0,
        unit TEXT DEFAULT '个',
        created_at TEXT NOT NULL DEFAULT (datetime('now')),
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        FOREIGN KEY (purchase_record_id) REFERENCES purchase_records(id)
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

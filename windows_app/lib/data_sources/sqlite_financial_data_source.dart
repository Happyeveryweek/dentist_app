import 'package:sqflite/sqflite.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../utils/datetime_formatter.dart';
import 'financial_data_source.dart';

/// SQLite 财务数据源实现
class SqliteFinancialDataSource implements FinancialDataSource {
  final Database _database;

  SqliteFinancialDataSource(this._database);

  _FinancialQueryParts _buildPatientAggregateQueryParts({
    List<int>? patientIds,
    DateTime? startDate,
    DateTime? endDate,
    String? doctorFilter,
  }) {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (doctorFilter != null) {
      conditions.add('p.doctor = ?');
      args.add(doctorFilter);
    }

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add('fr.patient_id IN ($placeholders)');
      args.addAll(patientIds);
    }
    if (startDate != null) {
      conditions.add('fi.charge_date >= ?');
      args.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('fi.charge_date <= ?');
      args.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }

    return _FinancialQueryParts(
      whereClause: _whereOrEmpty(conditions),
      whereArgs: args,
    );
  }

  _FinancialQueryParts _buildFinancialItemQueryParts({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
    String? doctorFilter,
    bool joinPatients = false,
  }) {
    final conditions = <String>[];
    final args = <dynamic>[];
    final itemPrefix = joinPatients ? 'fi.' : '';

    if (doctorFilter != null && joinPatients) {
      conditions.add('p.doctor = ?');
      args.add(doctorFilter);
    }
    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      if (joinPatients) {
        conditions.add('fr.patient_id IN ($placeholders)');
      } else {
        conditions.add(
          'financial_record_id IN (SELECT id FROM financial_records WHERE patient_id IN ($placeholders))',
        );
      }
      args.addAll(patientIds);
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      conditions.add('${itemPrefix}item_name LIKE ?');
      args.add('%${searchQuery.trim()}%');
    }
    if (chargeItemQuery != null && chargeItemQuery.trim().isNotEmpty) {
      conditions.add('${itemPrefix}item_name LIKE ?');
      args.add('%${chargeItemQuery.trim()}%');
    }
    if (startDate != null) {
      conditions.add('${itemPrefix}charge_date >= ?');
      args.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('${itemPrefix}charge_date <= ?');
      args.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }
    if (receivableMin != null) {
      conditions.add('${itemPrefix}item_price >= ?');
      args.add(receivableMin);
    }
    if (receivableMax != null) {
      conditions.add('${itemPrefix}item_price <= ?');
      args.add(receivableMax);
    }
    if (receivedMin != null) {
      conditions.add('${itemPrefix}total_price >= ?');
      args.add(receivedMin);
    }
    if (receivedMax != null) {
      conditions.add('${itemPrefix}total_price <= ?');
      args.add(receivedMax);
    }
    if (processingMin != null) {
      conditions.add('${itemPrefix}processing_fee >= ?');
      args.add(processingMin);
    }
    if (processingMax != null) {
      conditions.add('${itemPrefix}processing_fee <= ?');
      args.add(processingMax);
    }

    return _FinancialQueryParts(
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
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    final result = await _database
        .rawQuery('SELECT * FROM financial_records ORDER BY updated_at DESC');
    return result.map((e) => FinancialRecord.fromMap(e)).toList();
  }

  @override
  Future<FinancialRecord?> getFinancialRecordById(int id) async {
    final result = await _database.query(
      'financial_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return FinancialRecord.fromMap(result.first);
  }

  @override
  Future<int> createFinancialRecord(FinancialRecord record) async {
    return await _database.insert('financial_records', record.toMap());
  }

  @override
  Future<bool> updateFinancialRecord(FinancialRecord record) async {
    final count = await _database.update(
      'financial_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteFinancialRecord(int id) async {
    // 先删除相关的财务项目
    await _database.delete(
      'financial_items',
      where: 'financial_record_id = ?',
      whereArgs: [id],
    );

    // 再删除财务记录
    final count = await _database.delete(
      'financial_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    final result = await _database.query(
      'financial_items',
      where: 'financial_record_id = ?',
      whereArgs: [recordId],
      orderBy: 'updated_at DESC',
    );
    return result.map((e) => FinancialItem.fromMap(e)).toList();
  }

  @override
  Future<int> createFinancialItem(FinancialItem item) async {
    return await _database.insert('financial_items', item.toMap());
  }

  @override
  Future<bool> updateFinancialItem(FinancialItem item) async {
    final count = await _database.update(
      'financial_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
    return count > 0;
  }

  @override
  Future<bool> deleteFinancialItem(int id) async {
    final count = await _database.delete(
      'financial_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<double> getTotalReceivableAmount() async {
    final result = await _database
        .rawQuery('SELECT SUM(total_price) AS total FROM financial_items');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<double> getTotalReceivedAmount() async {
    final result = await _database.rawQuery(
        'SELECT SUM(total_price - processing_fee) AS total FROM financial_items WHERE processing_fee >= 0');
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<Map<String, dynamic>> getFinancialStatistics() async {
    final receivable = await getTotalReceivableAmount();
    final received = await getTotalReceivedAmount();

    return {
      'totalReceivable': receivable,
      'totalReceived': received,
      'totalPending': receivable - received,
    };
  }

  // ========== 查询/聚合方法实现 ==========

  @override
  Future<Map<String, dynamic>> getPatientAggregatesPage({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    List<int>? patientIds,
    DateTime? startDate,
    DateTime? endDate,
    String? doctorFilter,
  }) async {
    final offset = (page - 1) * pageSize;
    final parts = _buildPatientAggregateQueryParts(
      patientIds: patientIds,
      startDate: startDate,
      endDate: endDate,
      doctorFilter: doctorFilter,
    );

    late final String orderExprSql;
    final bool isDateOrder;
    if (sortBy == 'charge_date') {
      orderExprSql = 'MAX(COALESCE(fi.charge_date, fr.created_at))';
      isDateOrder = true;
    } else if (sortBy == 'updated_at') {
      orderExprSql = 'MAX(COALESCE(fi.updated_at, fr.updated_at))';
      isDateOrder = true;
    } else if (sortBy == 'received_sum') {
      orderExprSql = 'COALESCE(SUM(fi.total_price), 0)';
      isDateOrder = false;
    } else if (sortBy == 'receivable_sum') {
      orderExprSql =
          'COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0)';
      isDateOrder = false;
    } else if (sortBy == 'debt_sum') {
      orderExprSql =
          'COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0) - COALESCE(SUM(fi.total_price), 0)';
      isDateOrder = false;
    } else {
      orderExprSql = 'MAX(fr.updated_at)';
      isDateOrder = true;
    }

    final totalQuery = '''
      SELECT COUNT(*) AS cnt FROM (
        SELECT fr.patient_id
        FROM financial_records fr
        LEFT JOIN patients p ON p.id = fr.patient_id
        LEFT JOIN financial_items fi ON fi.financial_record_id = fr.id
        ${parts.whereClause}
        GROUP BY fr.patient_id
      ) t
    ''';
    final totalRes = await _database.rawQuery(totalQuery, parts.whereArgs);
    final total = Sqflite.firstIntValue(totalRes) ?? 0;

    final rowsQuery = '''
      SELECT fr.patient_id AS patient_id,
             MAX(COALESCE(fi.charge_date, fr.created_at)) AS latest_charge_date,
             MAX(COALESCE(fi.updated_at, fr.updated_at)) AS last_updated,
             COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0) AS receivable_sum,
             COALESCE(SUM(fi.total_price), 0) AS received_sum,
             COALESCE(SUM(fi.processing_fee), 0) AS processing_sum
      FROM financial_records fr
      LEFT JOIN patients p ON p.id = fr.patient_id
      LEFT JOIN financial_items fi ON fi.financial_record_id = fr.id
      ${parts.whereClause}
      GROUP BY fr.patient_id
      ORDER BY ${isDateOrder ? 'datetime($orderExprSql)' : orderExprSql} $sortOrder
      LIMIT ? OFFSET ?
    ''';
    final rowsArgs = [...parts.whereArgs, pageSize, offset];
    final rowsRes = await _database.rawQuery(rowsQuery, rowsArgs);
    final rows = rowsRes
        .map((r) => {
              'patient_id': r['patient_id'],
              'latest_charge_date': r['latest_charge_date'],
              'last_updated': r['last_updated'],
              'receivable_sum': r['receivable_sum'],
              'received_sum': r['received_sum'],
              'processing_sum': r['processing_sum'],
            })
        .toList();
    return {'total': total, 'rows': rows};
  }

  @override
  Future<FinancialRecord?> getLatestRecordForPatient(int patientId) async {
    final res = await _database.query(
      'financial_records',
      columns: [
        'id',
        'patient_id',
        'total_quantity',
        'notes',
        'created_at',
        'updated_at'
      ],
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (res.isEmpty) return null;
    return FinancialRecord.fromMap(res.first);
  }

  @override
  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(
      int patientId) async {
    final List<Map<String, dynamic>> maps = await _database.query(
      'financial_records',
      columns: [
        'id',
        'patient_id',
        'total_quantity',
        'notes',
        'created_at',
        'updated_at'
      ],
      where: 'patient_id = ?',
      whereArgs: [patientId],
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => FinancialRecord.fromMap(maps[i]));
  }

  @override
  Future<int> getFinancialItemsCount({
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
    String? doctorFilter,
  }) async {
    final parts = _buildFinancialItemQueryParts(
      searchQuery: searchQuery,
      patientIds: patientIds,
      startDate: startDate,
      endDate: endDate,
      chargeItemQuery: chargeItemQuery,
      receivableMin: receivableMin,
      receivableMax: receivableMax,
      receivedMin: receivedMin,
      receivedMax: receivedMax,
      processingMin: processingMin,
      processingMax: processingMax,
      doctorFilter: doctorFilter,
      joinPatients: doctorFilter != null,
    );

    final result = await _database.rawQuery(
      'SELECT COUNT(*) FROM financial_items fi '
      'JOIN financial_records fr ON fi.financial_record_id = fr.id '
      '${doctorFilter != null ? 'JOIN patients p ON p.id = fr.patient_id ' : ''}'
      '${parts.whereClause}',
      parts.whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getFinancialItemsWithDetails({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
    String? doctorFilter,
  }) async {
    final offset = (page - 1) * pageSize;
    final parts = _buildFinancialItemQueryParts(
      searchQuery: searchQuery,
      patientIds: patientIds,
      startDate: startDate,
      endDate: endDate,
      chargeItemQuery: chargeItemQuery,
      receivableMin: receivableMin,
      receivableMax: receivableMax,
      receivedMin: receivedMin,
      receivedMax: receivedMax,
      processingMin: processingMin,
      processingMax: processingMax,
      doctorFilter: doctorFilter,
      joinPatients: true,
    );

    final orderBy = 'fi.$sortBy $sortOrder';
    final query = '''
      SELECT fi.*, fr.patient_id, fr.notes
      FROM financial_items fi
      JOIN financial_records fr ON fi.financial_record_id = fr.id
      JOIN patients p ON p.id = fr.patient_id
      ${parts.whereClause}
      ORDER BY $orderBy
      LIMIT ? OFFSET ?
    ''';

    final results =
        await _database.rawQuery(query, [...parts.whereArgs, pageSize, offset]);
    return results
        .map((row) => {
              'item': FinancialItem.fromMap({
                'id': row['id'],
                'financial_record_id': row['financial_record_id'],
                'item_name': row['item_name'],
                'item_price': row['item_price'],
                'processing_fee': row['processing_fee'],
                'payment_method': row['payment_method'],
                'quantity': row['quantity'],
                'total_price': row['total_price'],
                'charge_date': row['charge_date'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at'],
              }),
              'patient_id': row['patient_id'],
              'record_notes': row['notes'],
            })
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllFinancialItemsWithDetailsFiltered({
    String sortBy = 'charge_date',
    String sortOrder = 'DESC',
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    List<int>? patientIds,
    String? chargeItemQuery,
    double? receivableMin,
    double? receivableMax,
    double? receivedMin,
    double? receivedMax,
    double? processingMin,
    double? processingMax,
    String? doctorFilter,
  }) async {
    final parts = _buildFinancialItemQueryParts(
      searchQuery: searchQuery,
      patientIds: patientIds,
      startDate: startDate,
      endDate: endDate,
      chargeItemQuery: chargeItemQuery,
      receivableMin: receivableMin,
      receivableMax: receivableMax,
      receivedMin: receivedMin,
      receivedMax: receivedMax,
      processingMin: processingMin,
      processingMax: processingMax,
      doctorFilter: doctorFilter,
      joinPatients: true,
    );

    final orderBy = 'fi.$sortBy $sortOrder';
    final query = '''
      SELECT fi.*, fr.patient_id, fr.notes
      FROM financial_items fi
      JOIN financial_records fr ON fi.financial_record_id = fr.id
      JOIN patients p ON fr.patient_id = p.id
      ${parts.whereClause}
      ORDER BY $orderBy
    ''';
    final results = await _database.rawQuery(query, parts.whereArgs);
    return results
        .map((row) => {
              'item': FinancialItem.fromMap({
                'id': row['id'],
                'financial_record_id': row['financial_record_id'],
                'item_name': row['item_name'],
                'item_price': row['item_price'],
                'processing_fee': row['processing_fee'],
                'payment_method': row['payment_method'],
                'quantity': row['quantity'],
                'total_price': row['total_price'],
                'charge_date': row['charge_date'],
                'created_at': row['created_at'],
                'updated_at': row['updated_at'],
              }),
              'patient_id': row['patient_id'],
              'record_notes': row['notes'],
            })
        .toList();
  }

  @override
  Future<void> ensureTablesExist() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS financial_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patient_id INTEGER NOT NULL,
        total_quantity INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _database.execute('''
      CREATE TABLE IF NOT EXISTS financial_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        financial_record_id INTEGER NOT NULL,
        item_name TEXT NOT NULL,
        item_price REAL NOT NULL,
        processing_fee REAL DEFAULT 0,
        payment_method TEXT,
        quantity INTEGER DEFAULT 1,
        total_price REAL NOT NULL,
        charge_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (financial_record_id) REFERENCES financial_records (id) ON DELETE CASCADE
      )
    ''');
  }
}

class _FinancialQueryParts {
  final String whereClause;
  final List<dynamic> whereArgs;

  const _FinancialQueryParts({
    required this.whereClause,
    required this.whereArgs,
  });
}

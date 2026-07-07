import 'dart:convert';
import 'package:mysql1/mysql1.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../utils/datetime_formatter.dart';
import 'base_mysql_data_source.dart';
import 'financial_data_source.dart';

/// MySQL 财务数据源实现
class MySqlFinancialDataSource extends BaseMySqlDataSource
    implements FinancialDataSource {
  MySqlFinancialDataSource.withConnectionGetter(
    Future<MySqlConnection?> Function() connectionGetter, {
    Future<void> Function()? reconnectCallback,
  }) : super(
          connectionProvider: connectionGetter,
          reconnectCallback: reconnectCallback,
        );

  @override
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    final result = await executeQuery(
        'SELECT * FROM financial_records ORDER BY updated_at DESC');

    final records = <FinancialRecord>[];
    for (final row in result) {
      final recordMap = convertRowToMap(row);
      records.add(FinancialRecord.fromMap(recordMap));
    }
    return records;
  }

  @override
  Future<FinancialRecord?> getFinancialRecordById(int id) async {
    final result = await executeQuery(
      'SELECT * FROM financial_records WHERE id = ?',
      [id],
    );
    if (result.isEmpty) return null;

    final recordMap = convertRowToMap(result.first);
    return FinancialRecord.fromMap(recordMap);
  }

  @override
  Future<int> createFinancialRecord(FinancialRecord record) async {
    final result = await executeQuery('''
      INSERT INTO financial_records (patient_id, notes, created_at, updated_at, total_quantity)
      VALUES (?, ?, ?, ?, ?)
    ''', [
      record.patientId,
      record.notes,
      DateTimeFormatter.toDbString(record.createdAt),
      DateTimeFormatter.toDbString(record.updatedAt),
      record.totalQuantity,
    ]);
    final insertId = result.insertId;
    if (insertId == null) {
      throw Exception('创建财务记录后未返回 insertId');
    }
    return insertId;
  }

  @override
  Future<bool> updateFinancialRecord(FinancialRecord record) async {
    final result = await executeQuery('''
      UPDATE financial_records SET
      patient_id = ?, notes = ?, updated_at = ?, total_quantity = ?
      WHERE id = ?
    ''', [
      record.patientId,
      record.notes,
      DateTimeFormatter.toDbString(record.updatedAt),
      record.totalQuantity,
      record.id,
    ]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteFinancialRecord(int id) async {
    // 先删除相关的财务项目
    await executeQuery(
      'DELETE FROM financial_items WHERE financial_record_id = ?',
      [id],
    );

    // 再删除财务记录
    final result = await executeQuery(
      'DELETE FROM financial_records WHERE id = ?',
      [id],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<int> getFinancialRecordsCount({String? searchQuery}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause = ' WHERE notes LIKE ?';
      whereArgs.add('%$searchQuery%');
    }

    final result = await executeQuery(
      'SELECT COUNT(*) AS count FROM financial_records$whereClause',
      whereArgs,
    );
    final row = result.first;
    final dynamic count = row['count'] ?? row[0];
    if (count is int) return count;
    if (count is BigInt) return count.toInt();
    return 0;
  }

  @override
  Future<List<FinancialRecord>> getPaginatedFinancialRecords({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  }) async {
    final offset = (page - 1) * pageSize;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause = ' WHERE notes LIKE ?';
      whereArgs.add('%$searchQuery%');
    }

    final sql =
        'SELECT * FROM financial_records$whereClause ORDER BY $sortBy $sortOrder LIMIT $offset, $pageSize';
    final result = await executeQuery(sql, whereArgs);

    final records = <FinancialRecord>[];
    for (final row in result) {
      final recordMap = convertRowToMap(row);
      records.add(FinancialRecord.fromMap(recordMap));
    }
    return records;
  }

  @override
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    final result = await executeQuery(
      'SELECT * FROM financial_items WHERE financial_record_id = ? ORDER BY updated_at DESC',
      [recordId],
    );

    final items = <FinancialItem>[];
    for (final row in result) {
      final itemMap = convertRowToMap(row);
      items.add(FinancialItem.fromMap(itemMap));
    }
    return items;
  }

  @override
  Future<int> createFinancialItem(FinancialItem item) async {
    final result = await executeQuery('''
      INSERT INTO financial_items (financial_record_id, item_name, item_price, quantity, total_price, charge_date, created_at, updated_at, processing_fee, payment_method)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      item.financialRecordId,
      item.itemName,
      item.itemPrice,
      item.quantity,
      item.totalPrice,
      DateTimeFormatter.toDbString(item.chargeDate).split(' ')[0],
      DateTimeFormatter.toDbString(item.createdAt),
      DateTimeFormatter.toDbString(item.updatedAt),
      item.processingFee,
      item.paymentMethod,
    ]);
    final insertId = result.insertId;
    if (insertId == null) {
      throw Exception('创建财务项目后未返回 insertId');
    }
    return insertId;
  }

  @override
  Future<bool> updateFinancialItem(FinancialItem item) async {
    final result = await executeQuery('''
      UPDATE financial_items SET
      item_name = ?, item_price = ?, quantity = ?, total_price = ?, charge_date = ?, updated_at = ?, processing_fee = ?, payment_method = ?
      WHERE id = ?
    ''', [
      item.itemName,
      item.itemPrice,
      item.quantity,
      item.totalPrice,
      DateTimeFormatter.toDbString(item.chargeDate).split(' ')[0],
      DateTimeFormatter.toDbString(item.updatedAt),
      item.processingFee,
      item.paymentMethod,
      item.id,
    ]);
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteFinancialItem(int id) async {
    final result = await executeQuery(
      'DELETE FROM financial_items WHERE id = ?',
      [id],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<double> getTotalReceivableAmount() async {
    final result = await executeQuery(
        'SELECT SUM(total_price) AS total FROM financial_items');
    final row = result.first;
    final dynamic total = row['total'] ?? row[0];
    if (total is num) return total.toDouble();
    return 0.0;
  }

  @override
  Future<double> getTotalReceivedAmount() async {
    final result = await executeQuery(
        'SELECT SUM(total_price - processing_fee) AS total FROM financial_items WHERE processing_fee >= 0');
    final row = result.first;
    final dynamic total = row['total'] ?? row[0];
    if (total is num) return total.toDouble();
    return 0.0;
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

  /// 安全获取 notes 字段（处理 UTF-8 字节解码）
  String _safeGetNotes(dynamic notes) {
    if (notes == null) return '';
    if (notes is String) return notes;
    if (notes is Blob) {
      try {
        return utf8.decode(notes.toBytes());
      } catch (e) {
        return '';
      }
    }
    if (notes is List<int>) {
      try {
        return utf8.decode(notes);
      } catch (e) {
        return '';
      }
    }
    return notes.toString();
  }

  @override
  Future<Map<String, dynamic>> getPatientAggregatesPage({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    List<int>? patientIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final offset = (page - 1) * pageSize;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add('fr.patient_id IN ($placeholders)');
      whereArgs.addAll(patientIds);
    }
    if (startDate != null) {
      conditions.add('fi.charge_date >= ?');
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('fi.charge_date <= ?');
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }
    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }

    late final String orderExprSql;
    if (sortBy == 'charge_date') {
      orderExprSql = 'MAX(COALESCE(fi.charge_date, fr.created_at))';
    } else if (sortBy == 'updated_at') {
      orderExprSql = 'MAX(COALESCE(fi.updated_at, fr.updated_at))';
    } else if (sortBy == 'received_sum') {
      orderExprSql = 'COALESCE(SUM(fi.total_price), 0)';
    } else if (sortBy == 'receivable_sum') {
      orderExprSql =
          'COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0)';
    } else if (sortBy == 'debt_sum') {
      orderExprSql =
          'COALESCE(SUM(fi.item_price * COALESCE(fi.quantity, 1)), 0) - COALESCE(SUM(fi.total_price), 0)';
    } else {
      orderExprSql = 'MAX(fr.updated_at)';
    }

    final totalQuery = '''
      SELECT COUNT(*) AS cnt FROM (
        SELECT fr.patient_id
        FROM financial_records fr
        LEFT JOIN patients p ON p.id = fr.patient_id
        LEFT JOIN financial_items fi ON fi.financial_record_id = fr.id
        $whereClause
        GROUP BY fr.patient_id
      ) t
    ''';
    final totalRes = await executeQuery(totalQuery, whereArgs);
    final totalRow = totalRes.first;
    final int total = (totalRow['cnt'] is BigInt)
        ? (totalRow['cnt'] as BigInt).toInt()
        : (totalRow['cnt'] ?? 0);

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
      $whereClause
      GROUP BY fr.patient_id
      ORDER BY $orderExprSql $sortOrder
      LIMIT ? OFFSET ?
    ''';
    final rowsArgs = [...whereArgs, pageSize, offset];
    final rowsRes = await executeQuery(rowsQuery, rowsArgs);
    final rows = rowsRes
        .map((r) => {
              'patient_id': (r['patient_id'] is BigInt)
                  ? (r['patient_id'] as BigInt).toInt()
                  : r['patient_id'],
              'latest_charge_date': r['latest_charge_date']?.toString(),
              'last_updated': r['last_updated']?.toString(),
              'receivable_sum': (r['receivable_sum'] is BigInt)
                  ? (r['receivable_sum'] as BigInt).toDouble()
                  : (r['receivable_sum'] as num?)?.toDouble() ?? 0.0,
              'received_sum': (r['received_sum'] is BigInt)
                  ? (r['received_sum'] as BigInt).toDouble()
                  : (r['received_sum'] as num?)?.toDouble() ?? 0.0,
              'processing_sum': (r['processing_sum'] is BigInt)
                  ? (r['processing_sum'] as BigInt).toDouble()
                  : (r['processing_sum'] as num?)?.toDouble() ?? 0.0,
            })
        .toList();
    return {'total': total, 'rows': rows};
  }

  @override
  Future<FinancialRecord?> getLatestRecordForPatient(int patientId) async {
    final rows = await executeQuery(
      'SELECT id, patient_id, total_quantity, notes, created_at, updated_at FROM financial_records WHERE patient_id = ? ORDER BY updated_at DESC LIMIT 1',
      [patientId],
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return FinancialRecord.fromMap({
      'id': row['id'],
      'patient_id': row['patient_id'],
      'total_quantity': row['total_quantity'],
      'notes': _safeGetNotes(row['notes']),
      'created_at': row['created_at']?.toString(),
      'updated_at': row['updated_at']?.toString(),
    });
  }

  @override
  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(
      int patientId) async {
    final results = await executeQuery(
      'SELECT id, patient_id, total_quantity, notes, created_at, updated_at FROM financial_records WHERE patient_id = ? ORDER BY updated_at DESC',
      [patientId],
    );
    return results
        .map((row) => FinancialRecord.fromMap({
              'id': row['id'],
              'patient_id': row['patient_id'],
              'total_quantity': row['total_quantity'],
              'notes': _safeGetNotes(row['notes']),
              'created_at': row['created_at']?.toString(),
              'updated_at': row['updated_at']?.toString(),
            }))
        .toList();
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
  }) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add(
          'financial_record_id IN (SELECT id FROM financial_records WHERE patient_id IN ($placeholders))');
      whereArgs.addAll(patientIds);
    }
    if (chargeItemQuery != null && chargeItemQuery.isNotEmpty) {
      conditions.add('item_name LIKE ?');
      whereArgs.add('%$chargeItemQuery%');
    }
    if (startDate != null) {
      conditions.add('charge_date >= ?');
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('charge_date <= ?');
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }
    if (receivableMin != null) {
      conditions.add('item_price >= ?');
      whereArgs.add(receivableMin);
    }
    if (receivableMax != null) {
      conditions.add('item_price <= ?');
      whereArgs.add(receivableMax);
    }
    if (receivedMin != null) {
      conditions.add('total_price >= ?');
      whereArgs.add(receivedMin);
    }
    if (receivedMax != null) {
      conditions.add('total_price <= ?');
      whereArgs.add(receivedMax);
    }
    if (processingMin != null) {
      conditions.add('processing_fee >= ?');
      whereArgs.add(processingMin);
    }
    if (processingMax != null) {
      conditions.add('processing_fee <= ?');
      whereArgs.add(processingMax);
    }

    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }

    final results = await executeQuery(
      'SELECT COUNT(*) as count FROM financial_items$whereClause',
      whereArgs,
    );
    final row = results.first;
    final dynamic v = row['count'] ?? row[0];
    if (v is int) return v;
    if (v is BigInt) return v.toInt();
    return 0;
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
  }) async {
    final offset = (page - 1) * pageSize;
    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add(
          'fi.financial_record_id IN (SELECT id FROM financial_records WHERE patient_id IN ($placeholders))');
      whereArgs.addAll(patientIds);
    }
    if (chargeItemQuery != null && chargeItemQuery.isNotEmpty) {
      conditions.add('fi.item_name LIKE ?');
      whereArgs.add('%$chargeItemQuery%');
    }
    if (startDate != null) {
      conditions.add('fi.charge_date >= ?');
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('fi.charge_date <= ?');
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }
    if (receivableMin != null) {
      conditions.add('fi.item_price >= ?');
      whereArgs.add(receivableMin);
    }
    if (receivableMax != null) {
      conditions.add('fi.item_price <= ?');
      whereArgs.add(receivableMax);
    }
    if (receivedMin != null) {
      conditions.add('fi.total_price >= ?');
      whereArgs.add(receivedMin);
    }
    if (receivedMax != null) {
      conditions.add('fi.total_price <= ?');
      whereArgs.add(receivedMax);
    }
    if (processingMin != null) {
      conditions.add('fi.processing_fee >= ?');
      whereArgs.add(processingMin);
    }
    if (processingMax != null) {
      conditions.add('fi.processing_fee <= ?');
      whereArgs.add(processingMax);
    }

    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }

    final orderBy = 'fi.$sortBy $sortOrder';
    final query = '''
      SELECT fi.*, fr.patient_id, fr.notes
      FROM financial_items fi
      JOIN financial_records fr ON fi.financial_record_id = fr.id
      $whereClause
      ORDER BY $orderBy
      LIMIT $offset, $pageSize
    ''';

    final results = await executeQuery(query, whereArgs);
    return results
        .map((row) => {
              'item': FinancialItem.fromMap({
                'id': row['id'],
                'financial_record_id': row['financial_record_id'],
                'item_name': row['item_name']?.toString(),
                'item_price': row['item_price'],
                'processing_fee': row['processing_fee'],
                'payment_method': row['payment_method'],
                'quantity': row['quantity'],
                'total_price': row['total_price'],
                'charge_date': row['charge_date']?.toString(),
                'created_at': row['created_at']?.toString(),
                'updated_at': row['updated_at']?.toString(),
              }),
              'patient_id': row['patient_id'],
              'record_notes': row['notes']?.toString(),
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
    String whereClause = '';
    List<dynamic> whereArgs = [];
    List<String> conditions = [];

    if (doctorFilter != null) {
      conditions.add('p.doctor = ?');
      whereArgs.add(doctorFilter);
    }
    if (patientIds != null && patientIds.isNotEmpty) {
      final placeholders = List.filled(patientIds.length, '?').join(',');
      conditions.add('fr.patient_id IN ($placeholders)');
      whereArgs.addAll(patientIds);
    }
    if (chargeItemQuery != null && chargeItemQuery.isNotEmpty) {
      conditions.add('fi.item_name LIKE ?');
      whereArgs.add('%$chargeItemQuery%');
    }
    if (startDate != null) {
      conditions.add('fi.charge_date >= ?');
      whereArgs.add(DateTimeFormatter.toDbString(startDate).split(' ')[0]);
    }
    if (endDate != null) {
      conditions.add('fi.charge_date <= ?');
      whereArgs.add(DateTimeFormatter.toDbString(endDate).split(' ')[0]);
    }
    if (receivableMin != null) {
      conditions.add('fi.item_price >= ?');
      whereArgs.add(receivableMin);
    }
    if (receivableMax != null) {
      conditions.add('fi.item_price <= ?');
      whereArgs.add(receivableMax);
    }
    if (receivedMin != null) {
      conditions.add('fi.total_price >= ?');
      whereArgs.add(receivedMin);
    }
    if (receivedMax != null) {
      conditions.add('fi.total_price <= ?');
      whereArgs.add(receivedMax);
    }
    if (processingMin != null) {
      conditions.add('fi.processing_fee >= ?');
      whereArgs.add(processingMin);
    }
    if (processingMax != null) {
      conditions.add('fi.processing_fee <= ?');
      whereArgs.add(processingMax);
    }

    if (conditions.isNotEmpty) {
      whereClause = ' WHERE ${conditions.join(' AND ')}';
    }

    final orderBy = 'fi.$sortBy $sortOrder';
    final query = '''
      SELECT fi.*, fr.patient_id, fr.notes
      FROM financial_items fi
      JOIN financial_records fr ON fi.financial_record_id = fr.id
      JOIN patients p ON fr.patient_id = p.id
      $whereClause
      ORDER BY $orderBy
    ''';
    final results = await executeQuery(query, whereArgs);
    return results
        .map((row) => {
              'item': FinancialItem.fromMap({
                'id': row['id'],
                'financial_record_id': row['financial_record_id'],
                'item_name': row['item_name']?.toString(),
                'item_price': row['item_price'],
                'processing_fee': row['processing_fee'],
                'payment_method': row['payment_method'],
                'quantity': row['quantity'],
                'total_price': row['total_price'],
                'charge_date': row['charge_date']?.toString(),
                'created_at': row['created_at']?.toString(),
                'updated_at': row['updated_at']?.toString(),
              }),
              'patient_id': row['patient_id'],
              'record_notes': row['notes']?.toString(),
            })
        .toList();
  }

  @override
  Future<void> ensureTablesExist() async {
    await executeQuery('''
      CREATE TABLE IF NOT EXISTS financial_records (
        id INT AUTO_INCREMENT PRIMARY KEY,
        patient_id INT NOT NULL,
        total_quantity INT DEFAULT 0,
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
      )
    ''');

    await executeQuery('''
      CREATE TABLE IF NOT EXISTS financial_items (
        id INT AUTO_INCREMENT PRIMARY KEY,
        financial_record_id INT NOT NULL,
        item_name VARCHAR(255) NOT NULL,
        item_price DECIMAL(10,2) NOT NULL,
        processing_fee DECIMAL(10,2) DEFAULT 0,
        quantity INT DEFAULT 1,
        total_price DECIMAL(10,2) NOT NULL,
        charge_date DATE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (financial_record_id) REFERENCES financial_records (id) ON DELETE CASCADE
      )
    ''');
  }
}

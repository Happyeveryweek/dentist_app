import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'base_mysql_data_source.dart';

// 抽象财务数据源接口
abstract class FinancialDataSource {
  Future<List<FinancialRecord>> getAllFinancialRecords();
  Future<FinancialRecord?> getFinancialRecordById(int id);
  Future<int> createFinancialRecord(FinancialRecord record);
  Future<bool> updateFinancialRecord(FinancialRecord record);
  Future<bool> deleteFinancialRecord(int id);
  
  // 分页查询方法
  Future<int> getFinancialRecordsCount({String? searchQuery});
  Future<List<FinancialRecord>> getPaginatedFinancialRecords({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
  });
  
  // 财务项目相关方法
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId);
  Future<int> createFinancialItem(FinancialItem item);
  Future<bool> updateFinancialItem(FinancialItem item);
  Future<bool> deleteFinancialItem(int id);
  
  // 统计方法
  Future<double> getTotalReceivableAmount();
  Future<double> getTotalReceivedAmount();
  Future<Map<String, dynamic>> getFinancialStatistics();
}

// SQLite财务数据源实现
class SqliteFinancialDataSource implements FinancialDataSource {
  final Database _database;

  SqliteFinancialDataSource(this._database);

  @override
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    final result = await _database.rawQuery(
      'SELECT * FROM financial_records ORDER BY updated_at DESC'
    );
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
  Future<int> getFinancialRecordsCount({String? searchQuery}) async {
    String whereClause = '';
    List<dynamic> whereArgs = [];
    
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      whereClause = ' WHERE notes LIKE ?';
      whereArgs.add('%$searchQuery%');
    }
    
    final result = await _database.rawQuery(
      'SELECT COUNT(*) AS count FROM financial_records$whereClause',
      whereArgs,
    );
    return result.first['count'] as int;
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
    
    final result = await _database.rawQuery(
      'SELECT * FROM financial_records$whereClause ORDER BY $sortBy $sortOrder LIMIT ? OFFSET ?',
      [...whereArgs, pageSize, offset],
    );
    return result.map((e) => FinancialRecord.fromMap(e)).toList();
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
    final result = await _database.rawQuery(
      'SELECT SUM(total_price) AS total FROM financial_items'
    );
    return (result.first['total'] as double?) ?? 0.0;
  }

  @override
  Future<double> getTotalReceivedAmount() async {
    final result = await _database.rawQuery(
      'SELECT SUM(total_price - processing_fee) AS total FROM financial_items WHERE processing_fee >= 0'
    );
    return (result.first['total'] as double?) ?? 0.0;
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
}

// MySQL财务数据源实现
class MySqlFinancialDataSource extends BaseMySqlDataSource implements FinancialDataSource {
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
      'SELECT * FROM financial_records ORDER BY updated_at DESC'
    );
    
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
    return result.insertId!;
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
    return result.affectedRows! > 0;
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
    return result.affectedRows! > 0;
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
    
    final sql = 'SELECT * FROM financial_records$whereClause ORDER BY $sortBy $sortOrder LIMIT $offset, $pageSize';
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
      INSERT INTO financial_items (financial_record_id, item_name, item_price, quantity, total_price, charge_date, created_at, updated_at, processing_fee)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
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
    ]);
    return result.insertId!;
  }

  @override
  Future<bool> updateFinancialItem(FinancialItem item) async {
    final result = await executeQuery('''
      UPDATE financial_items SET
      item_name = ?, item_price = ?, quantity = ?, total_price = ?, charge_date = ?, updated_at = ?, processing_fee = ?
      WHERE id = ?
    ''', [
      item.itemName,
      item.itemPrice,
      item.quantity,
      item.totalPrice,
      DateTimeFormatter.toDbString(item.chargeDate).split(' ')[0],
      DateTimeFormatter.toDbString(item.updatedAt),
      item.processingFee,
      item.id,
    ]);
    return result.affectedRows! > 0;
  }

  @override
  Future<bool> deleteFinancialItem(int id) async {
    final result = await executeQuery(
      'DELETE FROM financial_items WHERE id = ?',
      [id],
    );
    return result.affectedRows! > 0;
  }

  @override
  Future<double> getTotalReceivableAmount() async {
    final result = await executeQuery(
      'SELECT SUM(total_price) AS total FROM financial_items'
    );
    final row = result.first;
    final dynamic total = row['total'] ?? row[0];
    if (total is num) return total.toDouble();
    return 0.0;
  }

  @override
  Future<double> getTotalReceivedAmount() async {
    final result = await executeQuery(
      'SELECT SUM(total_price - processing_fee) AS total FROM financial_items WHERE processing_fee >= 0'
    );
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
}
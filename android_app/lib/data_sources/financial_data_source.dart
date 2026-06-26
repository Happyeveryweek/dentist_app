import 'package:mysql1/mysql1.dart';
import 'package:sqflite/sqflite.dart';
import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../utils/datetime_formatter.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/app_logger.dart';

// 抽象财务数据源接口
abstract class FinancialDataSource {
  Future<List<FinancialRecord>> getAllFinancialRecords();
  Future<FinancialRecord?> getFinancialRecordById(int id);
  Future<int> createFinancialRecord(FinancialRecord record);
  Future<bool> updateFinancialRecord(FinancialRecord record);
  Future<bool> deleteFinancialRecord(int id);
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId);
  Future<int> createFinancialItem(FinancialItem item);
  Future<bool> updateFinancialItem(FinancialItem item);
  Future<bool> deleteFinancialItem(int id);
  Future<double> getTotalAmount();
  Future<List<FinancialRecord>> getFinancialRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );
}

// SQLite财务数据源实现
class SqliteFinancialDataSource implements FinancialDataSource {
  final Database _database;

  SqliteFinancialDataSource(this._database);

  @override
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    final result = await _database.rawQuery('''
      SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
             COALESCE(p.name, '未知患者') as patient_name,
             p.name_pinyin as patient_name_pinyin,
             p.name_initials as patient_name_initials
      FROM financial_records fr 
      LEFT JOIN patients p ON fr.patient_id = p.id 
      ORDER BY fr.created_at DESC
    ''');
    return result
        .map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite'))
        .toList();
  }

  @override
  Future<FinancialRecord?> getFinancialRecordById(int id) async {
    final result = await _database.rawQuery(
      '''
      SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
             COALESCE(p.name, '未知患者') as patient_name,
             p.name_pinyin as patient_name_pinyin,
             p.name_initials as patient_name_initials
      FROM financial_records fr 
      LEFT JOIN patients p ON fr.patient_id = p.id 
      WHERE fr.id = ?
    ''',
      [id],
    );
    if (result.isEmpty) return null;
    return FinancialRecord.fromMap(result.first, dataSource: 'sqlite');
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
    // 先删除关联的财务项目记录
    await _database.delete(
      'financial_items',
      where: 'financial_record_id = ?',
      whereArgs: [id],
    );

    // 然后删除财务记录
    final count = await _database.delete(
      'financial_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  @override
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    final result = await _database.rawQuery(
      'SELECT * FROM financial_items WHERE financial_record_id = ? ORDER BY id',
      [recordId],
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
  Future<double> getTotalAmount() async {
    final result = await _database.rawQuery(
      'SELECT SUM(total_quantity) as total FROM financial_records',
    );
    final row = result.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<FinancialRecord>> getFinancialRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final result = await _database.rawQuery(
      '''
      SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
             COALESCE(p.name, '未知患者') as patient_name
      FROM financial_records fr 
      LEFT JOIN patients p ON fr.patient_id = p.id 
      WHERE fr.created_at BETWEEN ? AND ?
      ORDER BY fr.created_at DESC
    ''',
      [
        DateTimeFormatter.toDbString(startDate),
        DateTimeFormatter.toDbString(endDate),
      ],
    );
    return result
        .map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite'))
        .toList();
  }
}

// MySQL财务数据源实现（使用动态连接获取）
class MySqlFinancialDataSource implements FinancialDataSource {
  final MySqlConnection? Function() _getConnection;

  MySqlFinancialDataSource.withConnectionGetter(this._getConnection);

  // 辅助方法：处理MySQL行数据转换
  Map<String, dynamic> _convertMySqlRow(ResultRow row) {
    final map = <String, dynamic>{};
    for (var field in row.fields.keys) {
      var value = row[field];

      // 处理日期字段 - 使用统一格式
      if (field == 'created_at' || field == 'updated_at') {
        if (value is DateTime) {
          // 如果MySQL返回的是UTC时间，转换为本地时间
          final localDateTime = value.isUtc ? value.toLocal() : value;
          map[field] = DateTimeFormatter.toDbString(localDateTime);
        } else {
          map[field] = value?.toString();
        }
      } else if (value is Blob) {
        // 处理Blob字段，特别是notes等文本字段
        if (field == 'notes' ||
            field == 'description' ||
            field == 'patient_name' ||
            field == 'payment_method') {
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
        if (field == 'notes' ||
            field == 'description' ||
            field == 'patient_name' ||
            field == 'payment_method') {
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
  Future<List<FinancialRecord>> getAllFinancialRecords() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query('''
      SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
             COALESCE(p.name, '未知患者') as patient_name,
             p.name_pinyin as patient_name_pinyin,
             p.name_initials as patient_name_initials
      FROM financial_records fr 
      LEFT JOIN patients p ON fr.patient_id = p.id 
      ORDER BY fr.created_at DESC
    ''');

    return results
        .map(
          (row) => FinancialRecord.fromMap(
            _convertMySqlRow(row),
            dataSource: 'mysql',
          ),
        )
        .toList();
  }

  @override
  Future<FinancialRecord?> getFinancialRecordById(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      '''
      SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
             COALESCE(p.name, '未知患者') as patient_name,
             p.name_pinyin as patient_name_pinyin,
             p.name_initials as patient_name_initials
      FROM financial_records fr 
      LEFT JOIN patients p ON fr.patient_id = p.id 
      WHERE fr.id = ?
    ''',
      [id],
    );

    if (results.isEmpty) return null;

    final row = results.first;
    return FinancialRecord.fromMap(_convertMySqlRow(row), dataSource: 'mysql');
  }

  @override
  Future<int> createFinancialRecord(FinancialRecord record) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      '''
      INSERT INTO financial_records (patient_id, total_quantity, notes, created_at, updated_at)
      VALUES (?, ?, ?, NOW(), NOW())
    ''',
      [record.patientId, record.totalQuantity, record.notes],
    );

    final insertId = result.insertId;
    if (insertId == null) {
      throw Exception('创建财务记录失败：无法获取插入ID');
    }
    return insertId;
  }

  @override
  Future<bool> updateFinancialRecord(FinancialRecord record) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      '''
      UPDATE financial_records 
      SET patient_id = ?, total_quantity = ?, notes = ?, updated_at = NOW()
      WHERE id = ?
    ''',
      [record.patientId, record.totalQuantity, record.notes, record.id],
    );

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteFinancialRecord(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    // 先删除关联的财务项目记录
    await connection.query(
      'DELETE FROM financial_items WHERE financial_record_id = ?',
      [id],
    );

    // 然后删除财务记录
    final result = await connection.query(
      'DELETE FROM financial_records WHERE id = ?',
      [id],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      '''
      SELECT id, financial_record_id, item_name, payment_method, quantity, item_price, processing_fee, total_price, charge_date, created_at, updated_at
      FROM financial_items 
      WHERE financial_record_id = ? 
      ORDER BY id
    ''',
      [recordId],
    );

    return results.map((row) {
      final map = _convertMySqlRow(row);
      return FinancialItem.fromMap(map);
    }).toList();
  }

  @override
  Future<int> createFinancialItem(FinancialItem item) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      '''
      INSERT INTO financial_items (financial_record_id, item_name, payment_method, quantity, item_price, processing_fee, total_price, charge_date, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
    ''',
      [
        item.financialRecordId,
        item.itemName,
        item.paymentMethod,
        item.quantity,
        item.itemPrice,
        item.processingFee,
        item.totalPrice,
        DateTimeFormatter.toDbString(item.chargeDate),
      ],
    );

    final insertId = result.insertId;
    if (insertId == null) {
      throw Exception('创建财务项目失败：无法获取插入ID');
    }
    return insertId;
  }

  @override
  Future<bool> updateFinancialItem(FinancialItem item) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      '''
      UPDATE financial_items 
      SET financial_record_id = ?, item_name = ?, payment_method = ?, quantity = ?, item_price = ?, processing_fee = ?, total_price = ?, charge_date = ?, updated_at = NOW()
      WHERE id = ?
    ''',
      [
        item.financialRecordId,
        item.itemName,
        item.paymentMethod,
        item.quantity,
        item.itemPrice,
        item.processingFee,
        item.totalPrice,
        DateTimeFormatter.toDbString(item.chargeDate),
        item.id,
      ],
    );

    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<bool> deleteFinancialItem(int id) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final result = await connection.query(
      'DELETE FROM financial_items WHERE id = ?',
      [id],
    );
    return (result.affectedRows ?? 0) > 0;
  }

  @override
  Future<double> getTotalAmount() async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      'SELECT SUM(total_quantity) as total FROM financial_records',
    );
    final row = results.first;
    return (row['total'] as num?)?.toDouble() ?? 0.0;
  }

  @override
  Future<List<FinancialRecord>> getFinancialRecordsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final connection = _getConnection();
    if (connection == null) throw Exception('MySQL连接不可用');

    final results = await connection.query(
      '''
      SELECT fr.id, fr.patient_id, fr.total_quantity, fr.notes, fr.created_at, fr.updated_at,
             COALESCE(p.name, '未知患者') as patient_name
      FROM financial_records fr 
      LEFT JOIN patients p ON fr.patient_id = p.id 
      WHERE fr.created_at BETWEEN ? AND ?
      ORDER BY fr.created_at DESC
    ''',
      [startDate, endDate],
    );

    return results
        .map(
          (row) => FinancialRecord.fromMap(
            _convertMySqlRow(row),
            dataSource: 'mysql',
          ),
        )
        .toList();
  }
}

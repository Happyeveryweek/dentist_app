import 'package:mysql1/mysql1.dart';
import '../../patients/services/patient_sync_log_helper.dart';
import '../../../models/patient_sync_log.dart';
import '../../../utils/log_manager.dart';

/// 财务同步服务
/// 负责处理 SQLite → MySQL 的数据同步逻辑（从 FinancialProvider 中提取）
class FinancialSyncService {
  final MySqlConnection? Function() getSyncMysqlConnection;
  final String Function() getEffectiveDataSourceType;

  FinancialSyncService({
    required this.getSyncMysqlConnection,
    required this.getEffectiveDataSourceType,
  });

  /// 判断是否需要同步（当前使用 SQLite 数据源时需要同步到 MySQL）
  bool get needsSync => getEffectiveDataSourceType() == 'sqlite';

  /// 尝试将SQLite中的财务记录同步到MySQL（非阻塞操作）
  Future<void> syncFinancialRecordToMySQL(
      Map<String, dynamic> recordMap, int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await _addPatientSyncLog(
            entityType: 'financial_record',
            entityName: '财务记录',
            action: 'upsert',
            status: 'skipped',
            patientId: _intValue(recordMap['patient_id']),
            recordId: recordId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w(
              'FinancialSyncService', 'MySQL连接不可用，跳过财务记录同步(id=$recordId)');
          return;
        }

        try {
          final existResult = await conn.query(
            'SELECT * FROM financial_records WHERE id = ? LIMIT 1',
            [recordId],
          );

          if (existResult.isNotEmpty) {
            final fieldChanges = PatientSyncLogHelper.buildFieldChanges(
              oldValues: existResult.first.fields,
              newValues: recordMap,
              fields: _financialRecordSyncFields,
            );
            final result = await conn.query('''
              UPDATE financial_records SET
                patient_id = ?, total_quantity = ?, notes = ?,
                created_at = ?, updated_at = ?
              WHERE id = ?
            ''', [
              recordMap['patient_id'],
              recordMap['total_quantity'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
              recordId,
            ]);
            await _addPatientSyncLog(
              entityType: 'financial_record',
              entityName: '财务记录',
              action: 'update',
              status: 'success',
              patientId: _intValue(recordMap['patient_id']),
              recordId: recordId,
              fieldChanges: fieldChanges,
            );
            LogManager.i('FinancialSyncService',
                '成功更新MySQL财务记录(id=$recordId)，影响行数: ${result.affectedRows}');
          } else {
            final fieldChanges = PatientSyncLogHelper.buildCreateChanges(
                recordMap, _financialRecordSyncFields);
            final result = await conn.query('''
              INSERT INTO financial_records
              (id, patient_id, total_quantity, notes, created_at, updated_at)
              VALUES (?, ?, ?, ?, ?, ?)
            ''', [
              recordId,
              recordMap['patient_id'],
              recordMap['total_quantity'],
              recordMap['notes'],
              recordMap['created_at'],
              recordMap['updated_at'],
            ]);
            await _addPatientSyncLog(
              entityType: 'financial_record',
              entityName: '财务记录',
              action: 'create',
              status: 'success',
              patientId: _intValue(recordMap['patient_id']),
              recordId: recordId,
              fieldChanges: fieldChanges,
            );
            LogManager.i('FinancialSyncService',
                '成功将财务记录(id=$recordId)同步到MySQL，插入ID: ${result.insertId}');
          }
        } catch (e) {
          await _addPatientSyncLog(
            entityType: 'financial_record',
            entityName: '财务记录',
            action: 'upsert',
            status: 'failed',
            patientId: _intValue(recordMap['patient_id']),
            recordId: recordId,
            error: e.toString(),
          );
          LogManager.e('FinancialSyncService', '同步财务记录到MySQL时出错', error: e);
        }
      } catch (e) {
        await _addPatientSyncLog(
          entityType: 'financial_record',
          entityName: '财务记录',
          action: 'upsert',
          status: 'failed',
          patientId: _intValue(recordMap['patient_id']),
          recordId: recordId,
          error: e.toString(),
        );
        LogManager.e('FinancialSyncService', '财务记录同步到MySQL发生不可预期错误', error: e);
      }
    });
  }

  /// 尝试从MySQL删除财务记录（非阻塞操作，级联删除财务项目）
  Future<void> syncDeleteFinancialRecordToMySQL(int recordId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await _addPatientSyncLog(
            entityType: 'financial_record',
            entityName: '财务记录',
            action: 'delete',
            status: 'skipped',
            recordId: recordId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w(
              'FinancialSyncService', 'MySQL连接不可用，跳过财务记录删除同步(id=$recordId)');
          return;
        }

        try {
          final patientId = await _getPatientIdByFinancialRecordId(
            conn,
            recordId,
          );
          // 先删除关联的财务项目
          final itemsResult = await conn.query(
            'DELETE FROM financial_items WHERE financial_record_id = ?',
            [recordId],
          );
          LogManager.i('FinancialSyncService',
              '成功从MySQL删除财务项目，影响行数: ${itemsResult.affectedRows}');

          // 再删除财务记录
          final recordResult = await conn.query(
            'DELETE FROM financial_records WHERE id = ?',
            [recordId],
          );
          await _addPatientSyncLog(
            entityType: 'financial_record',
            entityName: '财务记录',
            action: 'delete',
            status: 'success',
            patientId: patientId,
            recordId: recordId,
          );
          LogManager.i('FinancialSyncService',
              '成功从MySQL删除财务记录(id=$recordId)，影响行数: ${recordResult.affectedRows}');
        } catch (e) {
          await _addPatientSyncLog(
            entityType: 'financial_record',
            entityName: '财务记录',
            action: 'delete',
            status: 'failed',
            recordId: recordId,
            error: e.toString(),
          );
          LogManager.e('FinancialSyncService', '从MySQL删除财务记录(id=$recordId)时出错',
              error: e);
        }
      } catch (e) {
        LogManager.e('FinancialSyncService', '财务记录删除同步到MySQL发生不可预期错误',
            error: e);
      }
    });
  }

  /// 尝试将SQLite中的财务项目同步到MySQL（非阻塞操作）
  Future<void> syncFinancialItemToMySQL(
      Map<String, dynamic> itemMap, int itemId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await _addPatientSyncLog(
            entityType: 'financial_item',
            entityName: '财务明细',
            action: 'upsert',
            status: 'skipped',
            recordId: itemId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w(
              'FinancialSyncService', 'MySQL连接不可用，跳过财务项目同步(id=$itemId)');
          return;
        }

        final existResult = await conn.query(
          '''
          SELECT fi.*, fr.patient_id
          FROM financial_items fi
          LEFT JOIN financial_records fr ON fr.id = fi.financial_record_id
          WHERE fi.id = ?
          LIMIT 1
          ''',
          [itemId],
        );
        final patientId = existResult.isNotEmpty
            ? _intValue(existResult.first['patient_id'])
            : await _getPatientIdByFinancialRecordId(
                conn,
                _intValue(itemMap['financial_record_id']),
              );

        if (existResult.isNotEmpty) {
          final fieldChanges = PatientSyncLogHelper.buildFieldChanges(
            oldValues: existResult.first.fields,
            newValues: itemMap,
            fields: _financialItemSyncFields,
          );
          final result = await conn.query('''
              UPDATE financial_items SET
              financial_record_id = ?, item_name = ?, item_price = ?,
              processing_fee = ?, quantity = ?, total_price = ?,
              charge_date = ?, created_at = ?, updated_at = ?, payment_method = ?
            WHERE id = ?
          ''', [
            itemMap['financial_record_id'],
            itemMap['item_name'],
            itemMap['item_price'],
            itemMap['processing_fee'],
            itemMap['quantity'],
            itemMap['total_price'],
            itemMap['charge_date'],
            itemMap['created_at'],
            itemMap['updated_at'],
            itemMap['payment_method'],
            itemId,
          ]);
          await _addPatientSyncLog(
            entityType: 'financial_item',
            entityName: '财务明细',
            action: 'update',
            status: 'success',
            patientId: patientId,
            recordId: itemId,
            fieldChanges: fieldChanges,
          );
          LogManager.i('FinancialSyncService',
              '成功更新MySQL财务项目(id=$itemId)，影响行数: ${result.affectedRows}');
        } else {
          final fieldChanges = PatientSyncLogHelper.buildCreateChanges(
              itemMap, _financialItemSyncFields);
          final result = await conn.query('''
            INSERT INTO financial_items
            (id, financial_record_id, item_name, item_price, processing_fee, quantity, total_price, charge_date, created_at, updated_at, payment_method)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            itemId,
            itemMap['financial_record_id'],
            itemMap['item_name'],
            itemMap['item_price'],
            itemMap['processing_fee'],
            itemMap['quantity'],
            itemMap['total_price'],
            itemMap['charge_date'],
            itemMap['created_at'],
            itemMap['updated_at'],
            itemMap['payment_method'],
          ]);
          await _addPatientSyncLog(
            entityType: 'financial_item',
            entityName: '财务明细',
            action: 'create',
            status: 'success',
            patientId: patientId,
            recordId: itemId,
            fieldChanges: fieldChanges,
          );
          LogManager.i('FinancialSyncService',
              '成功将财务项目(id=$itemId)同步到MySQL，插入ID: ${result.insertId}');
        }
      } catch (e) {
        await _addPatientSyncLog(
          entityType: 'financial_item',
          entityName: '财务明细',
          action: 'upsert',
          status: 'failed',
          recordId: itemId,
          error: e.toString(),
        );
        LogManager.e('FinancialSyncService', '财务项目同步到MySQL发生不可预期错误', error: e);
      }
    });
  }

  /// 尝试从MySQL删除财务项目（非阻塞操作）
  Future<void> syncDeleteFinancialItemToMySQL(int itemId) async {
    Future.microtask(() async {
      try {
        final conn = getSyncMysqlConnection();
        if (conn == null) {
          await _addPatientSyncLog(
            entityType: 'financial_item',
            entityName: '财务明细',
            action: 'delete',
            status: 'skipped',
            recordId: itemId,
            error: 'mysql_connection_unavailable',
          );
          LogManager.w(
              'FinancialSyncService', 'MySQL连接不可用，跳过财务项目删除同步(id=$itemId)');
          return;
        }

        final existing = await conn.query(
          '''
          SELECT fr.patient_id
          FROM financial_items fi
          LEFT JOIN financial_records fr ON fr.id = fi.financial_record_id
          WHERE fi.id = ?
          LIMIT 1
          ''',
          [itemId],
        );
        final patientId = existing.isNotEmpty
            ? _intValue(existing.first['patient_id'])
            : null;
        final result = await conn.query(
          'DELETE FROM financial_items WHERE id = ?',
          [itemId],
        );
        await _addPatientSyncLog(
          entityType: 'financial_item',
          entityName: '财务明细',
          action: 'delete',
          status: 'success',
          patientId: patientId,
          recordId: itemId,
        );
        LogManager.i('FinancialSyncService',
            '成功从MySQL删除财务项目(id=$itemId)，影响行数: ${result.affectedRows}');
      } catch (e) {
        await _addPatientSyncLog(
          entityType: 'financial_item',
          entityName: '财务明细',
          action: 'delete',
          status: 'failed',
          recordId: itemId,
          error: e.toString(),
        );
        LogManager.e('FinancialSyncService', '财务项目删除同步到MySQL发生不可预期错误',
            error: e);
      }
    });
  }

  Future<void> _addPatientSyncLog({
    required String entityType,
    required String entityName,
    required String action,
    required String status,
    int? patientId,
    int? recordId,
    List<PatientSyncFieldChange> fieldChanges = const [],
    String? error,
  }) {
    return PatientSyncLog.addLog(
      PatientSyncLog(
        syncTime: DateTime.now(),
        entityType: entityType,
        entityName: entityName,
        action: action,
        status: status,
        patientId: patientId,
        recordId: recordId,
        fieldChanges: fieldChanges,
        errorMessage: error,
      ),
    );
  }

  Future<int?> _getPatientIdByFinancialRecordId(
    MySqlConnection conn,
    int? financialRecordId,
  ) async {
    if (financialRecordId == null) return null;
    final result = await conn.query(
      'SELECT patient_id FROM financial_records WHERE id = ? LIMIT 1',
      [financialRecordId],
    );
    if (result.isEmpty) return null;
    return _intValue(result.first['patient_id']);
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is BigInt) return value.toInt();
    return int.tryParse(value.toString());
  }

  static const Map<String, String> _financialRecordSyncFields = {
    'patient_id': '患者ID',
    'total_quantity': '收费项数量',
    'notes': '备注',
  };

  static const Map<String, String> _financialItemSyncFields = {
    'financial_record_id': '财务记录ID',
    'item_name': '收费项目',
    'item_price': '应收费',
    'processing_fee': '加工费',
    'quantity': '数量',
    'total_price': '已收费',
    'charge_date': '收费日期',
    'payment_method': '收款方式',
  };
}

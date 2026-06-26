import '../../../models/financial_record.dart';
import '../../../data_sources/financial_data_source.dart';
import '../../../utils/database_operation_wrapper.dart';
import 'financial_data_source_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../utils/app_logger.dart';

/// 财务记录 CRUD 服务
/// 职责：管理财务记录的增删改查操作
class FinancialRecordService {
  final FinancialDataSourceService _dataSourceService;
  DatabaseOperationWrapper? _dbWrapper;
  String _dataSourceType = 'sqlite';
  Database? _database;
  MySqlConnection? _mysqlConnection;

  FinancialRecordService({
    required FinancialDataSourceService dataSourceService,
  }) : _dataSourceService = dataSourceService;

  /// 设置数据库连接
  void setDatabaseConnection({
    required String dataSourceType,
    Database? database,
    MySqlConnection? mysqlConnection,
    DatabaseOperationWrapper? dbWrapper,
  }) {
    _dataSourceType = dataSourceType;
    _dataSourceService.setDataSourceType(dataSourceType);
    _database = database;
    _mysqlConnection = mysqlConnection;
    _dbWrapper = dbWrapper;
  }

  /// 获取当前数据源
  FinancialDataSource get _currentDataSource {
    return _dataSourceService.currentDataSource;
  }

  MySqlConnection? get _currentMysqlConnection {
    if (_dataSourceType != 'mysql') return _mysqlConnection;
    return _dataSourceService.currentMysqlConnection ?? _mysqlConnection;
  }

  /// 添加财务记录
  Future<int> addFinancialRecord(
    FinancialRecord record, {
    required Future<void> Function() clearCache,
    required Function() markFinancialsNeedRefresh,
  }) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return -1;

    return await wrapper.wrapOperation('addFinancialRecord', () async {
      try {
        // 确保财务记录表存在
        await _dataSourceService.ensureFinancialRecordsTableExists(
          dataSourceType: _dataSourceType,
          sqliteDatabase: _database,
          mysqlConnection: _currentMysqlConnection,
        );

        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createFinancialRecord(record);
        AppLogger.info('✅ 数据源模式添加成功，ID: $id');

        if (id > 0) {
          // 清除缓存并标记需要刷新
          await clearCache();
          markFinancialsNeedRefresh();
          AppLogger.info('✅ 财务记录添加成功，已清除缓存并标记刷新');
        }

        return id;
      } catch (e) {
        AppLogger.info('添加财务记录失败: $e');
        rethrow;
      }
    });
  }

  /// 更新财务记录
  Future<int> updateFinancialRecord(
    FinancialRecord record, {
    required Future<void> Function() clearCache,
    required Function() markFinancialsNeedRefresh,
  }) async {
    if (record.id == null) {
      throw Exception('记录ID为空');
    }

    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('updateFinancialRecord', () async {
      try {
        // 确保财务记录表存在
        await _dataSourceService.ensureFinancialRecordsTableExists(
          dataSourceType: _dataSourceType,
          sqliteDatabase: _database,
          mysqlConnection: _currentMysqlConnection,
        );

        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updateFinancialRecord(record);
        final count = success ? 1 : 0;
        AppLogger.info('✅ 数据源模式更新${success ? "成功" : "失败"}');

        if (count > 0) {
          // 清除缓存并标记需要刷新
          await clearCache();
          markFinancialsNeedRefresh();
          AppLogger.info('✅ 财务记录更新成功，已清除缓存并标记刷新');
        }

        return count;
      } catch (e) {
        AppLogger.info('更新财务记录失败: $e');
        rethrow;
      }
    });
  }

  /// 删除财务记录
  Future<int> deleteFinancialRecord(
    int recordId, {
    required Future<void> Function() clearCache,
    required Function() markFinancialsNeedRefresh,
  }) async {
    final wrapper = _dbWrapper;
    if (wrapper == null) return 0;

    return await wrapper.wrapOperation('deleteFinancialRecord', () async {
      try {
        // 确保财务记录表存在
        await _dataSourceService.ensureFinancialRecordsTableExists(
          dataSourceType: _dataSourceType,
          sqliteDatabase: _database,
          mysqlConnection: _currentMysqlConnection,
        );

        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deleteFinancialRecord(
          recordId,
        );
        final count = success ? 1 : 0;

        if (count > 0) {
          // 清除缓存并标记需要刷新
          await clearCache();
          markFinancialsNeedRefresh();
          AppLogger.info('✅ 财务记录删除成功，已清除缓存并标记刷新');
        }

        return count;
      } catch (e) {
        AppLogger.info('删除财务记录失败: $e');
        rethrow;
      }
    });
  }

  /// 根据患者ID获取财务记录
  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(
    int patientId,
  ) async {
    // 如果patientId为0或无效，直接返回空列表
    if (patientId == 0) {
      AppLogger.info('⚠️ 无效的patientId: $patientId，返回空列表');
      return [];
    }

    try {
      // 确保财务记录表存在
      await _dataSourceService.ensureFinancialRecordsTableExists(
        dataSourceType: _dataSourceType,
        sqliteDatabase: _database,
        mysqlConnection: _currentMysqlConnection,
      );

      List<FinancialRecord> records = [];

      if (_dataSourceType == 'sqlite') {
        final db = _database;
        if (db == null) throw Exception('SQLite数据库未初始化');

        // 通过JOIN查询获取患者姓名
        final result = await db.rawQuery(
          '''
          SELECT fr.*, COALESCE(p.name, '未知患者') as patient_name
          FROM financial_records fr
          LEFT JOIN patients p ON fr.patient_id = p.id
          WHERE fr.patient_id = ?
          ORDER BY fr.updated_at DESC
        ''',
          [patientId],
        );
        records =
            result
                .map((e) => FinancialRecord.fromMap(e, dataSource: 'sqlite'))
                .toList();
      } else if (_dataSourceType == 'mysql') {
        final conn = _currentMysqlConnection;
        if (conn == null) throw Exception('MySQL连接未初始化');

        // 通过JOIN查询获取患者姓名
        final results = await conn.query(
          '''
          SELECT fr.*, p.name as patient_name
          FROM financial_records fr
          LEFT JOIN patients p ON fr.patient_id = p.id
          WHERE fr.patient_id = ?
          ORDER BY fr.updated_at DESC
        ''',
          [patientId],
        );

        records =
            results
                .map(
                  (row) => FinancialRecord.fromMap({
                    'id': row['id'],
                    'patient_id': row['patient_id'] ?? 0,
                    'total_quantity': row['total_quantity'] ?? 0,
                    'notes': row['notes']?.toString(),
                    'created_at': row['created_at']?.toString(),
                    'updated_at': row['updated_at']?.toString(),
                    'patient_name': row['patient_name']?.toString(),
                  }, dataSource: 'mysql'),
                )
                .toList();
      }

      return records;
    } catch (e) {
      AppLogger.info('获取患者财务记录失败: $e');
      rethrow;
    }
  }
}

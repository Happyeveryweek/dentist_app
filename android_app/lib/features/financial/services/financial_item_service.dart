import '../../../models/financial_item.dart';
import '../../../data_sources/financial_data_source.dart';
import '../../../utils/database_operation_wrapper.dart';
import 'financial_data_source_service.dart';
import 'package:sqflite/sqflite.dart';
import 'package:mysql1/mysql1.dart';
import '../../../utils/app_logger.dart';

/// 财务项目 CRUD 服务
/// 职责：管理财务项目的增删改查操作
class FinancialItemService {
  final FinancialDataSourceService _dataSourceService;
  DatabaseOperationWrapper? _dbWrapper;
  String _dataSourceType = 'sqlite';
  Database? _database;
  MySqlConnection? _mysqlConnection;

  FinancialItemService({required FinancialDataSourceService dataSourceService})
    : _dataSourceService = dataSourceService;

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

  /// 根据财务记录ID获取项目明细
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    if (_dbWrapper == null) return [];

    return await _dbWrapper!.wrapOperation(
      'getFinancialItemsByRecordId',
      () async {
        try {
          // 确保财务记录表存在
          await _dataSourceService.ensureFinancialRecordsTableExists(
            dataSourceType: _dataSourceType,
            sqliteDatabase: _database,
            mysqlConnection: _currentMysqlConnection,
          );

          // 使用数据源模式（统一接口）
          return await _currentDataSource.getFinancialItemsByRecordId(recordId);
        } catch (e) {
          AppLogger.info('获取财务项目明细失败: $e');
          rethrow;
        }
      },
    );
  }

  /// 添加财务项目明细
  Future<int> addFinancialItem(
    FinancialItem item, {
    required Function() markFinancialsNeedRefresh,
  }) async {
    if (_dbWrapper == null) return -1;

    return await _dbWrapper!.wrapOperation('addFinancialItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final id = await _currentDataSource.createFinancialItem(item);

        if (id > 0) {
          markFinancialsNeedRefresh();
        }

        return id;
      } catch (e) {
        AppLogger.info('添加财务项目明细失败: $e');
        rethrow;
      }
    });
  }

  /// 更新财务项目明细
  Future<int> updateFinancialItem(
    FinancialItem item, {
    required Function() markFinancialsNeedRefresh,
  }) async {
    if (item.id == null) {
      throw Exception('项目ID为空');
    }

    if (_dbWrapper == null) return 0;

    return await _dbWrapper!.wrapOperation('updateFinancialItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.updateFinancialItem(item);
        final count = success ? 1 : 0;

        if (count > 0) {
          markFinancialsNeedRefresh();
        }

        return count;
      } catch (e) {
        AppLogger.info('更新财务项目明细失败: $e');
        rethrow;
      }
    });
  }

  /// 删除财务项目明细
  Future<int> deleteFinancialItem(
    int itemId, {
    required Function() markFinancialsNeedRefresh,
  }) async {
    if (_dbWrapper == null) return 0;

    return await _dbWrapper!.wrapOperation('deleteFinancialItem', () async {
      try {
        // 使用数据源模式（统一接口）
        final success = await _currentDataSource.deleteFinancialItem(itemId);
        final count = success ? 1 : 0;

        if (count > 0) {
          markFinancialsNeedRefresh();
        }

        return count;
      } catch (e) {
        AppLogger.info('删除财务项目明细失败: $e');
        rethrow;
      }
    });
  }
}

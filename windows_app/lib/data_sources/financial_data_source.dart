import '../models/financial_record.dart';
import '../models/financial_item.dart';

export 'sqlite_financial_data_source.dart';
export 'mysql_financial_data_source.dart';

/// 抽象财务数据源接口
/// 定义了所有财务管理、收费记录及统计相关的底层数据库操作协议
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

  // ========== 查询/聚合方法（从 FinancialQueryService 下沉） ==========

  /// 按患者维度分页聚合查询
  Future<Map<String, dynamic>> getPatientAggregatesPage({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    List<int>? patientIds,
    DateTime? startDate,
    DateTime? endDate,
  });

  /// 获取某患者最近更新的财务记录
  Future<FinancialRecord?> getLatestRecordForPatient(int patientId);

  /// 按患者ID获取全部财务记录
  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(int patientId);

  /// 获取收费项总数（多条件过滤）
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
  });

  /// 分页获取收费项明细（JOIN 查询）
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
  });

  /// 获取全部收费项明细用于统计（含权限过滤 JOIN）
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
  });

  /// 确保财务相关表存在（DDL）
  Future<void> ensureTablesExist();
}

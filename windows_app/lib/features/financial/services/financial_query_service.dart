import '../../../data_sources/financial_data_source.dart';
import '../../../models/financial_record.dart';
import '../../../utils/log_manager.dart';

/// 财务查询服务
/// 负责处理财务相关的查询与聚合逻辑（从 FinancialProvider 中提取）
/// SQL 全部下沉到 Data Source 层，Service 只做初始化检查和委托
class FinancialQueryService {
  final FinancialDataSource Function() getCurrentDataSource;
  final String? Function() getDoctorFilter;
  final bool Function() isInitialized;

  FinancialQueryService({
    required this.getCurrentDataSource,
    required this.getDoctorFilter,
    required this.isInitialized,
  });

  /// 按患者维度分页聚合查询
  Future<Map<String, dynamic>> getPatientAggregatesPage({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    List<int>? patientIds,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (!isInitialized()) return {'total': 0, 'rows': <Map<String, dynamic>>[]};
    try {
      return await getCurrentDataSource().getPatientAggregatesPage(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        patientIds: patientIds,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      LogManager.e('FinancialQueryService', 'getPatientAggregatesPage 失败',
          error: e);
      rethrow;
    }
  }

  /// 获取某患者最近更新的财务记录
  Future<FinancialRecord?> getLatestRecordForPatient(int patientId) async {
    if (!isInitialized()) return null;
    try {
      return await getCurrentDataSource().getLatestRecordForPatient(patientId);
    } catch (e) {
      LogManager.e('FinancialQueryService', 'getLatestRecordForPatient 失败',
          error: e);
    }
    return null;
  }

  /// 按患者ID获取全部财务记录
  Future<List<FinancialRecord>> getFinancialRecordsByPatientId(
      int patientId) async {
    if (!isInitialized()) return [];
    try {
      return await getCurrentDataSource()
          .getFinancialRecordsByPatientId(patientId);
    } catch (e) {
      LogManager.e('FinancialQueryService', '获取患者财务记录失败', error: e);
    }
    return [];
  }

  /// 按ID获取单条财务记录
  Future<FinancialRecord?> getFinancialRecordById(int id) async {
    if (!isInitialized()) return null;
    try {
      return await getCurrentDataSource().getFinancialRecordById(id);
    } catch (e) {
      LogManager.e('FinancialQueryService', '获取财务记录失败', error: e);
    }
    return null;
  }

  /// 获取收费项总数
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
    if (!isInitialized()) return 0;
    try {
      return await getCurrentDataSource().getFinancialItemsCount(
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        patientIds: patientIds,
        chargeItemQuery: chargeItemQuery,
        receivableMin: receivableMin,
        receivableMax: receivableMax,
        receivedMin: receivedMin,
        receivedMax: receivedMax,
        processingMin: processingMin,
        processingMax: processingMax,
      );
    } catch (e) {
      LogManager.e('FinancialQueryService', '获取收费项总数失败', error: e);
      rethrow;
    }
  }

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
  }) async {
    if (!isInitialized()) return [];
    try {
      return await getCurrentDataSource().getFinancialItemsWithDetails(
        page: page,
        pageSize: pageSize,
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        patientIds: patientIds,
        chargeItemQuery: chargeItemQuery,
        receivableMin: receivableMin,
        receivableMax: receivableMax,
        receivedMin: receivedMin,
        receivedMax: receivedMax,
        processingMin: processingMin,
        processingMax: processingMax,
      );
    } catch (e) {
      LogManager.e('FinancialQueryService', '获取分页收费项失败', error: e);
      rethrow;
    }
  }

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
  }) async {
    if (!isInitialized()) return [];
    try {
      return await getCurrentDataSource()
          .getAllFinancialItemsWithDetailsFiltered(
        sortBy: sortBy,
        sortOrder: sortOrder,
        searchQuery: searchQuery,
        startDate: startDate,
        endDate: endDate,
        patientIds: patientIds,
        chargeItemQuery: chargeItemQuery,
        receivableMin: receivableMin,
        receivableMax: receivableMax,
        receivedMin: receivedMin,
        receivedMax: receivedMax,
        processingMin: processingMin,
        processingMax: processingMax,
        doctorFilter: getDoctorFilter(),
      );
    } catch (e) {
      LogManager.e('FinancialQueryService', '获取所有收费项(用于统计)失败', error: e);
      rethrow;
    }
  }
}

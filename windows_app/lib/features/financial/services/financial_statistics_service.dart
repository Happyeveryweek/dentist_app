import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../../../providers/financial_provider.dart';
import '../../../providers/patient_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../models/data_source.dart';

/// 财务统计服务
///
/// 提供财务统计数据获取逻辑
class FinancialStatisticsService {
  /// 获取财务统计数据
  static Future<FinancialStatisticsData> getStatisticsData({
    required BuildContext context,
    required String searchQuery,
    required String sortBy,
    required bool sortAscending,
    required DateTime? startDate,
    required DateTime? endDate,
    required String chargeItemQuery,
    required double? receivableMin,
    required double? receivableMax,
    required double? receivedMin,
    required double? receivedMax,
    required double? processingMin,
    required double? processingMax,
  }) async {
    final financialProvider =
        Provider.of<FinancialProvider>(context, listen: false);
    final patientProvider =
        Provider.of<PatientProvider>(context, listen: false);
    final settingsProvider =
        Provider.of<SettingsProvider>(context, listen: false);

    // 依据设置确定"患者管理"数据源（用于按姓名搜索患者ID）
    final String patientsDataSource =
        settingsProvider.dataSourceMode.isModularDataSourceMode
            ? (settingsProvider.moduleDataSources['patients'] ??
                settingsProvider.dataSourceType)
            : settingsProvider.dataSourceType;

    // 若有搜索词，先在SQLite中查患者ID；否则不限制
    List<int>? filterPatientIds;
    if (searchQuery.isNotEmpty) {
      try {
        filterPatientIds = await patientProvider.searchPatientIds(
          searchQuery,
          effectiveDataSourceType: patientsDataSource,
        );
      } catch (e) {
        filterPatientIds = [];
      }
    }

    // 取全量（当前筛选）收费明细，包含 patientId
    final itemsWithDetails =
        await financialProvider.getAllFinancialItemsWithDetailsFiltered(
      sortBy: sortBy,
      sortOrder: sortAscending ? 'ASC' : 'DESC',
      startDate: startDate,
      endDate: endDate,
      patientIds: filterPatientIds,
      chargeItemQuery: chargeItemQuery.isNotEmpty ? chargeItemQuery : null,
      receivableMin: receivableMin,
      receivableMax: receivableMax,
      receivedMin: receivedMin,
      receivedMax: receivedMax,
      processingMin: processingMin,
      processingMax: processingMax,
    );

    // 构建 FinancialItem 列表 + FinancialRecord（最小字段）列表 + 患者列表
    final List<FinancialItem> allFinancialItems = [];
    final Map<int, FinancialRecord> recordMap = {};
    final Set<int> patientIdSet = {};

    for (final row in itemsWithDetails) {
      final FinancialItem item = row['item'] as FinancialItem;
      final int pid = row['patient_id'] as int;
      allFinancialItems.add(item);
      patientIdSet.add(pid);
      recordMap[item.financialRecordId] = recordMap[item.financialRecordId] ??
          FinancialRecord(
            id: item.financialRecordId,
            patientId: pid,
            totalQuantity: 0,
            createdAt: item.chargeDate,
            updatedAt: item.updatedAt,
            notes: row['record_notes'] as String?,
          );
    }

    // 批量获取患者信息
    final patients = await patientProvider.getPatientsByIds(
      patientIdSet.toList(),
      effectiveDataSourceType: patientsDataSource,
    );

    return FinancialStatisticsData(
      financialRecords: recordMap.values.toList(),
      financialItems: allFinancialItems,
      patients: patients,
      searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      initialStartDate: startDate,
      initialEndDate: endDate,
      chargeItemQuery: chargeItemQuery.isNotEmpty ? chargeItemQuery : null,
    );
  }
}

/// 财务统计数据
class FinancialStatisticsData {
  final List<FinancialRecord> financialRecords;
  final List<FinancialItem> financialItems;
  final List<Patient> patients;
  final String? searchQuery;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? chargeItemQuery;

  FinancialStatisticsData({
    required this.financialRecords,
    required this.financialItems,
    required this.patients,
    this.searchQuery,
    this.initialStartDate,
    this.initialEndDate,
    this.chargeItemQuery,
  });
}

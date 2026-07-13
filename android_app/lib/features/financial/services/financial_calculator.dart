import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../utils/app_logger.dart';

/// 财务计算服务类
/// 职责：提供财务金额计算、患者统计、欠费计算等纯计算逻辑
class FinancialCalculator {
  static List<FinancialItem> _getItemsForRecord(
    FinancialRecord record,
    Map<int, List<FinancialItem>> recordItemsMap,
  ) {
    final id = record.id;
    if (id == null) return [];
    return recordItemsMap[id] ?? [];
  }

  /// 获取患者最新财务记录
  static FinancialRecord? getLatestFinancialRecord(
    int patientId,
    List<FinancialRecord> financialRecords,
  ) {
    try {
      final patientRecords =
          financialRecords
              .where((record) => record.patientId == patientId)
              .toList();

      if (patientRecords.isEmpty) return null;

      // 按更新时间排序，最新的排到最前面
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return patientRecords.first;
    } catch (e) {
      AppLogger.info('获取患者最新财务记录失败: $e');
      return null;
    }
  }

  /// 计算患者最新应收费金额
  static double calculatePatientLatestReceivableAmount(
    int patientId,
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
  ) {
    try {
      final latestRecord = getLatestFinancialRecord(
        patientId,
        financialRecords,
      );
      if (latestRecord == null) return 0.0;

      final items = _getItemsForRecord(latestRecord, recordItemsMap);
      if (items.isEmpty) return 0.0;

      // 计算应收费总额（仅项目价格，不包含加工费）
      double totalReceivable = 0.0;
      for (final item in items) {
        totalReceivable += item.itemPrice;
      }
      return totalReceivable;
    } catch (e) {
      AppLogger.info('计算患者最新应收费金额失败: $e');
      return 0.0;
    }
  }

  /// 计算患者最新已收费金额
  static double calculatePatientLatestCollectedAmount(
    int patientId,
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
  ) {
    try {
      final latestRecord = getLatestFinancialRecord(
        patientId,
        financialRecords,
      );
      if (latestRecord == null) return 0.0;

      final items = _getItemsForRecord(latestRecord, recordItemsMap);
      if (items.isEmpty) return 0.0;

      // 计算已收费总额
      double totalCollected = 0.0;
      for (final item in items) {
        totalCollected += item.totalPrice;
      }
      return totalCollected;
    } catch (e) {
      AppLogger.info('计算患者最新已收费金额失败: $e');
      return 0.0;
    }
  }

  /// 获取过滤后的财务项目（按收费日期过滤，与统计图表逻辑一致）
  static List<FinancialItem> getFilteredItems(
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
    DateTime? startDate,
    DateTime? endDate,
    String searchQuery,
  ) {
    final List<FinancialItem> allItems = [];

    // 获取所有财务项目
    for (final record in financialRecords) {
      allItems.addAll(_getItemsForRecord(record, recordItemsMap));
    }

    // 按收费日期过滤（与统计图表逻辑完全一致）
    List<FinancialItem> timeFilteredItems = allItems;
    if (startDate != null || endDate != null) {
      timeFilteredItems =
          allItems.where((item) {
            return isWithinRange(item.chargeDate, startDate, endDate);
          }).toList();
    }

    // 如果有搜索条件，进一步过滤（只影响显示的记录，不影响统计数据）
    if (searchQuery.isNotEmpty) {
      // 获取匹配搜索条件的患者ID
      final Set<int> matchingPatientIds = {};
      for (final record in financialRecords) {
        final patientName = record.patientName ?? '';
        final patientNamePinyin = record.patientNamePinyin ?? '';
        final patientNameInitials = record.patientNameInitials ?? '';
        final lowercaseQuery = searchQuery.toLowerCase();
        final noSpaceQuery = lowercaseQuery.replaceAll(' ', '');

        if (patientName.toLowerCase().contains(lowercaseQuery) ||
            patientNamePinyin.toLowerCase().contains(lowercaseQuery) ||
            patientNamePinyin.toLowerCase().contains(noSpaceQuery) ||
            patientNamePinyin
                .replaceAll(' ', '')
                .toLowerCase()
                .contains(lowercaseQuery) ||
            patientNameInitials.toLowerCase().contains(lowercaseQuery)) {
          matchingPatientIds.add(record.patientId);
        }
      }

      // 只返回匹配患者的财务项目
      return timeFilteredItems.where((item) {
        final record = financialRecords.firstWhere(
          (r) => r.id == item.financialRecordId,
          orElse:
              () => FinancialRecord(
                id: 0,
                patientId: 0,
                totalQuantity: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
        );
        return matchingPatientIds.contains(record.patientId);
      }).toList();
    }

    return timeFilteredItems;
  }

  /// 检查日期是否在范围内
  static bool isWithinRange(
    DateTime date,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    if (startDate == null && endDate == null) return true;
    final d = DateTime(date.year, date.month, date.day);
    if (startDate != null) {
      final s = DateTime(startDate.year, startDate.month, startDate.day);
      if (d.isBefore(s)) return false;
    }
    if (endDate != null) {
      final e = DateTime(endDate.year, endDate.month, endDate.day);
      if (d.isAfter(e)) {
        return false;
      }
    }

    return true;
  }
}

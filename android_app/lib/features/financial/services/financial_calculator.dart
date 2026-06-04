import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';

/// 财务计算服务类
/// 职责：提供财务金额计算、患者统计、欠费计算等纯计算逻辑
class FinancialCalculator {
  /// 获取患者最新财务记录
  static FinancialRecord? getLatestFinancialRecord(
    int patientId,
    List<FinancialRecord> financialRecords,
  ) {
    try {
      final patientRecords = financialRecords
          .where((record) => record.patientId == patientId)
          .toList();

      if (patientRecords.isEmpty) return null;

      // 按更新时间排序，最新的排到最前面
      patientRecords.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      return patientRecords.first;
    } catch (e) {
      print('获取患者最新财务记录失败: $e');
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
      final latestRecord = getLatestFinancialRecord(patientId, financialRecords);
      if (latestRecord == null) return 0.0;

      final items = recordItemsMap[latestRecord.id!] ?? [];
      if (items.isEmpty) return 0.0;

      // 计算应收费总额（仅项目价格，不包含加工费）
      double totalReceivable = 0.0;
      for (final item in items) {
        totalReceivable += item.itemPrice;
      }
      return totalReceivable;
    } catch (e) {
      print('计算患者最新应收费金额失败: $e');
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
      final latestRecord = getLatestFinancialRecord(patientId, financialRecords);
      if (latestRecord == null) return 0.0;

      final items = recordItemsMap[latestRecord.id!] ?? [];
      if (items.isEmpty) return 0.0;

      // 计算已收费总额
      double totalCollected = 0.0;
      for (final item in items) {
        totalCollected += item.totalPrice;
      }
      return totalCollected;
    } catch (e) {
      print('计算患者最新已收费金额失败: $e');
      return 0.0;
    }
  }

  /// 计算总金额
  static double calculateTotalAmount(
    List<FinancialRecord> filteredRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
  ) {
    double total = 0.0;
    for (final record in filteredRecords) {
      final items = recordItemsMap[record.id!] ?? [];
      for (final item in items) {
        total += item.totalPrice;
      }
    }
    return total;
  }

  /// 计算已结清记录数
  static int calculateSettledCount(
    List<FinancialRecord> filteredRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
  ) {
    return filteredRecords.where((record) {
      final items = recordItemsMap[record.id!] ?? [];
      return items.isNotEmpty && items.every((item) => item.totalPrice > 0);
    }).length;
  }

  /// 计算唯一患者数量（基于财务项目，与财务图表逻辑保持一致）
  static int calculateUniquePatientCount(
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
    DateTime? startDate,
    DateTime? endDate,
    String searchQuery,
  ) {
    final Set<int> patientIds = {};
    final filteredItems = getFilteredItems(
      financialRecords,
      recordItemsMap,
      startDate,
      endDate,
      searchQuery,
    );

    // 遍历过滤后的财务项目
    for (final item in filteredItems) {
      final record = financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(
          id: 0,
          patientId: 0,
          totalQuantity: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (record.patientId != 0) {
        patientIds.add(record.patientId);
      }
    }

    return patientIds.length;
  }

  /// 计算总记录数
  static int calculateTotalRecords(List<FinancialRecord> filteredRecords) {
    return filteredRecords.length;
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
      if (record.id != null && recordItemsMap.containsKey(record.id)) {
        allItems.addAll(recordItemsMap[record.id]!);
      }
    }

    // 按收费日期过滤（与统计图表逻辑完全一致）
    List<FinancialItem> timeFilteredItems = allItems;
    if (startDate != null || endDate != null) {
      timeFilteredItems = allItems.where((item) {
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
            patientNamePinyin.replaceAll(' ', '').toLowerCase().contains(lowercaseQuery) ||
            patientNameInitials.toLowerCase().contains(lowercaseQuery)) {
          matchingPatientIds.add(record.patientId);
        }
      }

      // 只返回匹配患者的财务项目
      return timeFilteredItems.where((item) {
        final record = financialRecords.firstWhere(
          (r) => r.id == item.financialRecordId,
          orElse: () => FinancialRecord(
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

  /// 计算总应收费金额（基于过滤后的财务项目）
  static double calculateTotalReceivable(
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
    DateTime? startDate,
    DateTime? endDate,
    String searchQuery,
  ) {
    final filteredItems = getFilteredItems(
      financialRecords,
      recordItemsMap,
      startDate,
      endDate,
      searchQuery,
    );
    return filteredItems.fold<double>(0.0, (sum, item) => sum + item.itemPrice);
  }

  /// 计算总已收费金额（基于过滤后的财务项目）
  static double calculateTotalCollected(
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
    DateTime? startDate,
    DateTime? endDate,
    String searchQuery,
  ) {
    final filteredItems = getFilteredItems(
      financialRecords,
      recordItemsMap,
      startDate,
      endDate,
      searchQuery,
    );
    return filteredItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// 计算总欠费金额（按患者维度计算，与统计图表逻辑完全一致）
  static double calculateTotalOutstanding(
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
    DateTime? endDate,
    String searchQuery,
  ) {
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};

    // 获取所有财务项目
    final List<FinancialItem> allItems = [];
    for (final record in financialRecords) {
      if (record.id != null && recordItemsMap.containsKey(record.id)) {
        allItems.addAll(recordItemsMap[record.id]!);
      }
    }

    // 按截止日期过滤：只计算结束日期之前的所有财务项目（与统计图表逻辑一致）
    List<FinancialItem> itemsBeforeEndDate = allItems;
    if (endDate != null) {
      final endDateDate = DateTime(endDate.year, endDate.month, endDate.day);
      itemsBeforeEndDate = allItems.where((item) {
        final itemDate = DateTime(item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
        return itemDate.isBefore(endDateDate) || itemDate.isAtSameMomentAs(endDateDate);
      }).toList();
    }

    // 如果有搜索条件，进一步过滤
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
            patientNamePinyin.replaceAll(' ', '').toLowerCase().contains(lowercaseQuery) ||
            patientNameInitials.toLowerCase().contains(lowercaseQuery)) {
          matchingPatientIds.add(record.patientId);
        }
      }

      // 只计算匹配患者的欠费
      itemsBeforeEndDate = itemsBeforeEndDate.where((item) {
        final record = financialRecords.firstWhere(
          (r) => r.id == item.financialRecordId,
          orElse: () => FinancialRecord(
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

    // 按患者分组计算应收和实收
    for (final item in itemsBeforeEndDate) {
      final record = financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(
          id: 0,
          patientId: 0,
          totalQuantity: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (record.patientId != 0) {
        final pid = record.patientId;
        receivableByPatient[pid] = (receivableByPatient[pid] ?? 0) + item.itemPrice;
        receivedByPatient[pid] = (receivedByPatient[pid] ?? 0) + item.totalPrice;
      }
    }

    // 计算每个患者的欠费，只累加正数欠费
    double totalDebt = 0.0;
    receivableByPatient.forEach((pid, receivable) {
      final received = receivedByPatient[pid] ?? 0.0;
      final debt = receivable - received;
      if (debt > 0) {
        totalDebt += debt;
      }
    });

    return totalDebt;
  }

  /// 计算总加工费金额（基于过滤后的财务项目）
  static double calculateTotalProcessingFee(
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
    DateTime? startDate,
    DateTime? endDate,
    String searchQuery,
  ) {
    final filteredItems = getFilteredItems(
      financialRecords,
      recordItemsMap,
      startDate,
      endDate,
      searchQuery,
    );
    return filteredItems.fold<double>(0.0, (sum, item) => sum + item.processingFee);
  }

  /// 检查日期是否在范围内
  static bool isWithinRange(DateTime date, DateTime? startDate, DateTime? endDate) {
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

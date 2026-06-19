import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';

/// 患者计算辅助类
/// 
/// 提供患者相关的纯计算函数，不涉及状态管理
class PatientCalculationHelper {
  /// 获取患者的应收费总额
  static double getPatientTotalReceivable(
    int patientId,
    List<FinancialRecord> financialRecords,
    Map<int, List<FinancialItem>> recordItemsMap,
  ) {
    double totalReceivable = 0.0;
    for (final record in financialRecords.where((record) => record.patientId == patientId)) {
      final items = recordItemsMap[record.id] ?? [];
      totalReceivable += items.fold(0.0, (sum, item) => sum + (item.itemPrice * (item.quantity ?? 1)));
    }
    return totalReceivable;
  }

  /// 获取患者最近财务更新时间（最近财务记录的 updatedAt）
  static DateTime? getPatientLastFinancialUpdateDate(
    int patientId,
    List<FinancialRecord> financialRecords,
  ) {
    try {
      final records = financialRecords
          .where((record) => record.patientId == patientId)
          .toList();
      if (records.isEmpty) return null;

      // 按更新时间排序，找到最近的财务记录
      records.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // 返回最近财务记录的更新时间
      return records.first.updatedAt;
    } catch (e) {
      return null;
    }
  }
}

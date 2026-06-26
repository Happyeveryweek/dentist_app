import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';

/// 财务明细项映射辅助类
///
/// 提供记录模式的数据映射逻辑
class FinancialItemsMapper {
  /// 获取所有收费记录明细项数据（用于按收费记录显示）
  static List<Map<String, dynamic>> getAllFinancialItemsData({
    required List<FinancialRecord> financialRecords,
    required Map<int, List<FinancialItem>> recordItemsMap,
    required Patient? Function(int) getPatientById,
  }) {
    final List<Map<String, dynamic>> result = [];

    for (final record in financialRecords) {
      final patient = getPatientById(record.patientId);
      if (patient != null) {
        final items = recordItemsMap[record.id] ?? [];
        for (final item in items) {
          result.add({
            'patient': patient,
            'record': record,
            'item': item,
          });
        }
      }
    }

    // 按收费日期降序排序
    result.sort((a, b) {
      final itemA = a['item'] as FinancialItem;
      final itemB = b['item'] as FinancialItem;
      return itemB.chargeDate.compareTo(itemA.chargeDate);
    });

    return result;
  }
}

import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../widgets/financial_date_range_selector.dart';

/// 财务数据过滤辅助类
/// 
/// 提供财务数据过滤、排序、搜索的纯函数
class FinancialDataFilterHelper {
  /// 过滤和排序财务数据
  static List<Map<String, dynamic>> filterAndSortFinancialData({
    required String displayMode,
    required List<Map<String, dynamic>> sourceData,
    required String sortBy,
    required bool sortAscending,
    required String searchQuery,
    required DateTime? startDate,
    required DateTime? endDate,
  }) {
    // 先进行时间范围筛选
    List<Map<String, dynamic>> timeFilteredData = sourceData.where((data) {
      final record = data['record'] as FinancialRecord;
      final item = data['item'] as FinancialItem?;

      // 使用不同维度的日期作为过滤基准：
      // - 记录模式：用收费明细的 charge_date（没有明细时回退到记录 created_at）。
      // - 患者模式：用聚合后的 patientLatestChargeDate。
      DateTime dateToCheck;
      if (displayMode == 'patient') {
        dateToCheck = (data['patientLatestChargeDate'] as DateTime?) ?? record.createdAt;
      } else if (item != null) {
        dateToCheck = item.chargeDate;
      } else {
        dateToCheck = record.createdAt;
      }

      return FinancialDateRangeSelector.isWithinRange(dateToCheck, startDate, endDate);
    }).toList();

    // 在搜索之前进行排序
    timeFilteredData.sort((a, b) {
      final recordA = a['record'] as FinancialRecord;
      final recordB = b['record'] as FinancialRecord;
      final itemA = a['item'] as FinancialItem?;
      final itemB = b['item'] as FinancialItem?;

      // 根据显示模式和排序字段决定比较值
      int compareNum(num va, num vb) => sortAscending ? va.compareTo(vb) : vb.compareTo(va);
      int compareDate(DateTime da, DateTime db) => sortAscending ? da.compareTo(db) : db.compareTo(da);

      // 患者模式：按患者聚合后的日期排序（已在 _getFinancialData() 中计算）
      if (displayMode == 'patient') {
        final pa = a['patientLastUpdated'] as DateTime? ?? recordA.updatedAt;
        final pb = b['patientLastUpdated'] as DateTime? ?? recordB.updatedAt;
        if (sortBy == 'charge_date') {
          final ca = a['patientLatestChargeDate'] as DateTime? ?? recordA.createdAt;
          final cb = b['patientLatestChargeDate'] as DateTime? ?? recordB.createdAt;
          return compareDate(ca, cb);
        }
        return compareDate(pa, pb);
      }

      // 记录模式：金额与日期皆可排序
      if (sortBy == 'updated_at') {
        return compareDate(recordA.updatedAt, recordB.updatedAt);
      }
      if (sortBy == 'charge_date') {
        final da = itemA?.chargeDate ?? recordA.createdAt;
        final db = itemB?.chargeDate ?? recordB.createdAt;
        return compareDate(da, db);
      }

      if (displayMode == 'record') {
        final receivableA = itemA?.itemPrice ?? 0.0;
        final receivableB = itemB?.itemPrice ?? 0.0;
        final receivedA = itemA?.totalPrice ?? 0.0;
        final receivedB = itemB?.totalPrice ?? 0.0;
        final procA = itemA?.processingFee ?? 0.0;
        final procB = itemB?.processingFee ?? 0.0;

        switch (sortBy) {
          case 'receivable':
            return compareNum(receivableA, receivableB);
          case 'received':
            return compareNum(receivedA, receivedB);
          case 'processing_fee':
            return compareNum(procA, procB);
        }
      } else {
        // 兜底（患者模式不会走到这里）
      }

      // 兜底：按更新时间
      return compareDate(recordA.updatedAt, recordB.updatedAt);
    });

    // 再进行搜索筛选
    if (searchQuery.isEmpty) {
      return timeFilteredData;
    }

    final query = searchQuery.toLowerCase();
    return timeFilteredData.where((data) {
      final patient = data['patient'] as Patient;
      final record = data['record'] as FinancialRecord;
      final item = data['item'] as FinancialItem?;

      final nameMatch = patient.name.toLowerCase().contains(query);
      final pinyinMatch = patient.name_pinyin?.toLowerCase().contains(query) ?? false;
      final pinyinInitialMatch = patient.name_initials?.toLowerCase().contains(query) ?? false;
      final medicalRecordMatch = patient.medical_record_number?.toString().contains(query) ?? false;
      final notesMatch = record.notes?.toLowerCase().contains(query) ?? false;

      // 如果是按收费记录显示模式，还要搜索收费项目名称
      bool itemNameMatch = false;
      if (item != null) {
        itemNameMatch = item.itemName.toLowerCase().contains(query);
      }

      return nameMatch || pinyinMatch || pinyinInitialMatch || medicalRecordMatch || notesMatch || itemNameMatch;
    }).toList();
  }
}

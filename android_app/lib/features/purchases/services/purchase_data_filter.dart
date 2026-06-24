import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import 'purchase_date_range_service.dart';

/// 采购数据过滤服务
class PurchaseDataFilter {
  /// 获取过滤后的记录
  static List<PurchaseRecord> getFilteredRecords(
    List<PurchaseRecord> records,
    DateTime startDate,
    DateTime endDate,
  ) {
    return records
        .where(
          (record) => PurchaseDateRangeService.isWithinRange(
            record.purchaseDate,
            startDate,
            endDate,
          ),
        )
        .toList();
  }

  /// 获取过滤后的采购项目
  static List<PurchaseItem> getFilteredItems(
    List<PurchaseRecord> filteredRecords,
    Map<int, List<PurchaseItem>> recordItemsMap,
  ) {
    final filteredRecordIds = filteredRecords.map((r) => r.id).toSet();
    final List<PurchaseItem> allItems = [];

    for (final recordId in filteredRecordIds) {
      if (recordId != null && recordItemsMap.containsKey(recordId)) {
        allItems.addAll(recordItemsMap[recordId]!);
      }
    }

    return allItems;
  }
}

import '../models/purchase_record.dart';

// 抽象采购数据源接口
abstract class PurchaseDataSource {
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter});
  Future<PurchaseRecord?> getPurchaseById(int id);
  Future<int> createPurchase(PurchaseRecord purchase);
  Future<bool> updatePurchase(PurchaseRecord purchase);
  Future<bool> deletePurchase(int id);
  Future<List<PurchaseRecord>> searchPurchases(
    String keyword, {
    String? doctorFilter,
  });
  Future<double> getTotalPurchaseAmount({String? doctorFilter});
  Future<List<PurchaseRecord>> getPurchasesByDateRange(
    DateTime startDate,
    DateTime endDate, {
    String? doctorFilter,
  });

  // 采购项目明细相关方法
  Future<List<dynamic>> getPurchaseItemsByRecordId(int recordId);
  Future<int> createPurchaseItem(dynamic item);
  Future<bool> updatePurchaseItem(dynamic item);
  Future<bool> deletePurchaseItem(int itemId);
}

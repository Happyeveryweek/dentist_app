import '../models/purchase_record.dart';
import '../models/purchase_item.dart';

export 'sqlite_purchase_data_source.dart';
export 'mysql_purchase_data_source.dart';

/// 抽象采购数据源接口
/// 定义了所有采购管理相关的底层数据库操作协议
abstract class PurchaseDataSource {
  Future<List<PurchaseRecord>> getAllPurchases({String? doctorFilter});
  Future<PurchaseRecord?> getPurchaseById(int id);
  Future<int> createPurchase(PurchaseRecord purchase);
  Future<bool> updatePurchase(PurchaseRecord purchase);
  Future<bool> deletePurchase(int id);
  Future<List<PurchaseRecord>> searchPurchases(String keyword,
      {String? doctorFilter});
  Future<double> getTotalPurchaseAmount({String? doctorFilter});
  Future<List<PurchaseRecord>> getPurchasesByDateRange(
      DateTime startDate, DateTime endDate,
      {String? doctorFilter});

  // 分页查询方法
  Future<int> getPurchasesCount({String? searchQuery, String? doctorFilter});
  Future<List<PurchaseRecord>> getPaginatedPurchases({
    int page = 1,
    int pageSize = 10,
    String sortBy = 'updated_at',
    String sortOrder = 'DESC',
    String? searchQuery,
    String? doctorFilter,
  });

  // 采购项目相关方法
  Future<List<PurchaseItem>> getPurchaseItemsByRecordId(int recordId);
  Future<int> createPurchaseItem(PurchaseItem item);
  Future<bool> updatePurchaseItem(PurchaseItem item);
  Future<bool> deletePurchaseItem(int id);

  /// 确保采购相关表存在（DDL）
  Future<void> ensureTablesExist();
}

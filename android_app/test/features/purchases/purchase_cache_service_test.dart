import 'package:dentist_app/features/purchases/services/purchase_cache_service.dart';
import 'package:dentist_app/models/purchase_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PurchaseItem buildItem(int id) {
    return PurchaseItem(
      id: id,
      purchaseRecordId: 10,
      materialName: '测试材料',
      quantity: 1,
      unitPrice: 10,
      totalPrice: 10,
    );
  }

  test('按采购记录缓存明细，并返回独立列表', () {
    final cache = PurchaseCacheService();
    cache.cacheItems(10, [buildItem(1)]);

    final cachedItems = cache.getCachedItems(10);

    expect(cachedItems, hasLength(1));
    cachedItems!.clear();
    expect(cache.getCachedItems(10), hasLength(1));
  });

  test('清除采购缓存时一并清除明细缓存', () {
    final cache = PurchaseCacheService();
    cache.cacheItems(10, [buildItem(1)]);

    cache.clearCache();

    expect(cache.getCachedItems(10), isNull);
  });
}

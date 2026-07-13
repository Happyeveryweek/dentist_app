import 'package:dentist_app/features/financial/helpers/financial_cache_helper.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FinancialItem buildItem() => FinancialItem(
    id: 1,
    financialRecordId: 20,
    itemName: '测试收费项',
    itemPrice: 100,
    processingFee: 0,
    quantity: 1,
    totalPrice: 100,
    chargeDate: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('按财务记录缓存收费明细，并返回独立列表', () {
    final cache = FinancialCacheHelper();
    cache.cacheDetailItems(20, [buildItem()]);

    final cachedItems = cache.getCachedDetailItems(20);

    expect(cachedItems, hasLength(1));
    cachedItems!.clear();
    expect(cache.getCachedDetailItems(20), hasLength(1));
  });

  test('清除财务缓存时一并清除收费明细缓存', () {
    final cache = FinancialCacheHelper();
    cache.cacheDetailItems(20, [buildItem()]);

    cache.clearCache();

    expect(cache.getCachedDetailItems(20), isNull);
  });
}

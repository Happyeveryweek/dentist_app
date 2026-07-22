import 'package:dentist_app/features/financial/helpers/financial_cache_helper.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:dentist_app/models/financial_record.dart';
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

  test('分页记录和总数按查询条件缓存并随财务缓存清除', () {
    final cache = FinancialCacheHelper();
    final record = FinancialRecord(
      id: 20,
      patientId: 1,
      totalQuantity: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    cache.cacheRecordQuery('page|1|20||', [record]);
    cache.cacheRecordCount('count||', 1);

    final records = cache.getCachedRecordQuery('page|1|20||');
    expect(records, hasLength(1));
    records!.clear();
    expect(cache.getCachedRecordQuery('page|1|20||'), hasLength(1));
    expect(cache.getCachedRecordCount('count||'), 1);

    cache.clearCache();
    expect(cache.getCachedRecordQuery('page|1|20||'), isNull);
    expect(cache.getCachedRecordCount('count||'), isNull);
  });
}

import 'package:dentist_app_windows/features/financial/helpers/financial_cache_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('收费记录分页缓存按查询键隔离', () {
    final cache = FinancialCacheHelper();
    final firstKey = FinancialCacheHelper.buildQueryKey(['sqlite', 1]);
    final secondKey = FinancialCacheHelper.buildQueryKey(['sqlite', 2]);

    cache.putItemPage(firstKey, [
      {'patient_id': 1},
    ]);
    cache.putItemPage(secondKey, [
      {'patient_id': 2},
    ]);

    expect(cache.getItemPage(firstKey), [
      {'patient_id': 1},
    ]);
    expect(cache.getItemPage(secondKey), [
      {'patient_id': 2},
    ]);
  });

  test('患者 ID 顺序不影响查询键', () {
    final firstKey = FinancialCacheHelper.buildQueryKey([
      'sqlite',
      [2, 1],
    ]);
    final secondKey = FinancialCacheHelper.buildQueryKey([
      'sqlite',
      [1, 2],
    ]);

    expect(firstKey, secondKey);
  });

  test('clearCache 同时清除分页查询缓存', () {
    final cache = FinancialCacheHelper();
    cache.putItemCount('count', 3);
    cache.putItemPage('items', [
      {'patient_id': 1},
    ]);
    cache.putPatientPage('patients', {
      'total': 1,
      'rows': <Map<String, dynamic>>[
        {'patient_id': 1},
      ],
    });

    cache.clearCache();

    expect(cache.getItemCount('count'), isNull);
    expect(cache.getItemPage('items'), isNull);
    expect(cache.getPatientPage('patients'), isNull);
  });
}

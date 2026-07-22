import 'package:dentist_app_windows/features/medical_records/helpers/medical_record_cache_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('不同患者的病历缓存分别计算有效期', () {
    var now = DateTime(2026, 7, 22, 10);
    final cache = MedicalRecordCacheHelper(now: () => now);

    cache.updateCache(1, []);
    now = now.add(const Duration(minutes: 10));
    cache.updateCache(2, []);
    now = now.add(const Duration(minutes: 6));

    expect(cache.isCacheValid(1), isFalse);
    expect(cache.isCacheValid(2), isTrue);
  });

  test('不同模板分类的缓存分别计算有效期', () {
    var now = DateTime(2026, 7, 22, 10);
    final cache = MedicalRecordCacheHelper(now: () => now);

    cache.updateTemplateCache('disease', []);
    now = now.add(const Duration(minutes: 15));
    cache.updateTemplateCache('allergy', []);
    now = now.add(const Duration(minutes: 6));

    expect(cache.isTemplateCacheValid('disease'), isFalse);
    expect(cache.isTemplateCacheValid('allergy'), isTrue);
  });

  test('失效指定患者缓存时同步清理有效期', () {
    final cache = MedicalRecordCacheHelper();
    cache.updateCache(1, []);

    cache.invalidateMedicalRecords(1);

    expect(cache.cachedMedicalRecords.containsKey(1), isFalse);
    expect(cache.isCacheValid(1), isFalse);
  });
}

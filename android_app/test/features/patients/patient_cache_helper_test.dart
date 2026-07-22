import 'package:dentist_app/features/patients/helpers/patient_cache_helper.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Patient buildPatient(int id) => Patient(
    id: id,
    name: '患者$id',
    age: 30,
    gender: 'male',
    phone: '13800000000',
  );

  test('按查询条件缓存患者列表并返回独立列表', () {
    final cache = PatientCacheHelper();
    cache.cacheQuery('page|1|60|updated|false', [buildPatient(1)]);

    final patients = cache.getCachedQuery('page|1|60|updated|false');

    expect(patients, hasLength(1));
    patients!.clear();
    expect(cache.getCachedQuery('page|1|60|updated|false'), hasLength(1));
    expect(cache.getCachedQuery('page|2|60|updated|false'), isNull);
  });

  test('清除患者缓存时一并清除详情和查询缓存', () {
    final cache = PatientCacheHelper();
    final patient = buildPatient(1);
    cache.setCachedPatients([patient]);
    cache.cacheQuery('search|患者', [patient]);

    cache.clearCache();

    expect(cache.cachedPatients, isNull);
    expect(cache.getCachedPatientById(1), isNull);
    expect(cache.getCachedQuery('search|患者'), isNull);
  });
}

import 'package:dentist_app_windows/features/financial/services/patient_cache_service.dart';
import 'package:dentist_app_windows/models/patient.dart';
import 'package:flutter_test/flutter_test.dart';

Patient _patient(int id, String name) {
  return Patient(
    id: id,
    name: name,
    age: 30,
    gender: '男',
    phone: '',
    firstVisitDate: DateTime(2026, 7, 22),
  );
}

void main() {
  test('批量患者缓存可同步读取，避免列表行进入异步等待态', () {
    final cache = PatientCacheService();
    cache.replaceAll([
      _patient(1, '患者一'),
      _patient(2, '患者二'),
    ]);

    expect(cache.getPatientByIdSync(2, const []), isNotNull);
    expect(cache.getPatientByIdSync(2, const [])?.name, '患者二');
  });

  test('replaceAll 会移除上一页患者', () {
    final cache = PatientCacheService();
    cache.replaceAll([_patient(1, '患者一')]);
    cache.replaceAll([_patient(2, '患者二')]);

    expect(cache.getPatientByIdSync(1, const []), isNull);
    expect(cache.getPatientByIdSync(2, const []), isNotNull);
  });
}

import '../../../models/database_models.dart';

/// 患者缓存管理助手
/// 职责：管理患者数据的缓存、缓存刷新
class PatientCacheHelper {
  List<Patient>? _cachedPatients;
  final Map<int, Patient> _cachedPatientsById = {};

  /// 获取缓存的患者数据
  List<Patient>? get cachedPatients => _cachedPatients;

  /// 设置缓存的患者数据
  void setCachedPatients(List<Patient>? patients) {
    _cachedPatients = patients;
    _cachedPatientsById
      ..clear()
      ..addEntries(
        patients
                ?.where((patient) => patient.id != null)
                .map((patient) => MapEntry(patient.id!, patient)) ??
            const [],
      );
  }

  Patient? getCachedPatientById(int id) => _cachedPatientsById[id];

  void cachePatient(Patient patient) {
    final id = patient.id;
    if (id != null) {
      _cachedPatientsById[id] = patient;
    }
  }

  /// 清除缓存
  void clearCache() {
    _cachedPatients = null;
    _cachedPatientsById.clear();
  }

  /// 检查是否有缓存
  bool hasCache() {
    return _cachedPatients != null;
  }
}

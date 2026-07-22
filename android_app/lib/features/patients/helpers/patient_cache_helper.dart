import '../../../models/database_models.dart';

/// 患者缓存管理助手
/// 职责：管理患者数据的缓存、缓存刷新
class PatientCacheHelper {
  List<Patient>? _cachedPatients;
  DateTime? _patientsCachedAt;
  final Map<int, _CachedPatient> _cachedPatientsById = {};
  final Map<String, _CachedPatientList> _cachedQueries = {};
  static const Duration _cacheValidDuration = Duration(minutes: 20);

  /// 获取缓存的患者数据
  List<Patient>? get cachedPatients {
    final patients = _cachedPatients;
    final cachedAt = _patientsCachedAt;
    if (patients == null || cachedAt == null || !_isValid(cachedAt)) {
      _cachedPatients = null;
      _patientsCachedAt = null;
      return null;
    }
    return List.from(patients);
  }

  /// 设置缓存的患者数据
  void setCachedPatients(List<Patient>? patients) {
    _cachedPatients = patients;
    _patientsCachedAt = DateTime.now();
    _cachedPatientsById
      ..clear()
      ..addEntries(
        patients
                ?.where((patient) => patient.id != null)
                .map(
                  (patient) => MapEntry(
                    patient.id!,
                    _CachedPatient(patient, DateTime.now()),
                  ),
                ) ??
            const [],
      );
  }

  Patient? getCachedPatientById(int id) {
    final cached = _cachedPatientsById[id];
    if (cached == null || !_isValid(cached.cachedAt)) {
      _cachedPatientsById.remove(id);
      return null;
    }
    return cached.patient;
  }

  void cachePatient(Patient patient) {
    final id = patient.id;
    if (id != null) {
      _cachedPatientsById[id] = _CachedPatient(patient, DateTime.now());
    }
  }

  List<Patient>? getCachedQuery(String key) {
    final cached = _cachedQueries[key];
    if (cached == null || !_isValid(cached.cachedAt)) {
      _cachedQueries.remove(key);
      return null;
    }
    return List.from(cached.patients);
  }

  void cacheQuery(String key, List<Patient> patients) {
    _cachedQueries[key] = _CachedPatientList(
      List.from(patients),
      DateTime.now(),
    );
  }

  /// 清除缓存
  void clearCache() {
    _cachedPatients = null;
    _patientsCachedAt = null;
    _cachedPatientsById.clear();
    _cachedQueries.clear();
  }

  /// 检查是否有缓存
  bool hasCache() {
    return cachedPatients != null;
  }

  bool _isValid(DateTime cachedAt) =>
      DateTime.now().difference(cachedAt) < _cacheValidDuration;
}

class _CachedPatient {
  final Patient patient;
  final DateTime cachedAt;

  const _CachedPatient(this.patient, this.cachedAt);
}

class _CachedPatientList {
  final List<Patient> patients;
  final DateTime cachedAt;

  const _CachedPatientList(this.patients, this.cachedAt);
}

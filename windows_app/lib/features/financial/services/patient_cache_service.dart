import '../../../models/patient.dart';

/// 患者缓存服务
///
/// 提供患者信息缓存和查询功能
class PatientCacheService {
  final Map<int, Patient> _cache = {};

  /// 从预加载列表中获取患者信息
  Patient? getFromPreloadedList(
      int patientId, List<Patient> preloadedPatients) {
    try {
      return preloadedPatients.firstWhere((p) => p.id == patientId);
    } catch (e) {
      return null;
    }
  }

  void replaceAll(Iterable<Patient> patients) {
    _cache.clear();
    for (final patient in patients) {
      final patientId = patient.id;
      if (patientId != null) {
        _cache[patientId] = patient;
      }
    }
  }

  /// 同步获取患者信息（仅用于已缓存的情况）
  Patient? getPatientByIdSync(int patientId, List<Patient> preloadedPatients) {
    return _cache[patientId] ??
        getFromPreloadedList(patientId, preloadedPatients);
  }
}

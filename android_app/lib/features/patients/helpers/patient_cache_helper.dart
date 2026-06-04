import '../../../models/database_models.dart';

/// 患者缓存管理助手
/// 职责：管理患者数据的缓存、缓存刷新
class PatientCacheHelper {
  List<Patient>? _cachedPatients;

  /// 获取缓存的患者数据
  List<Patient>? get cachedPatients => _cachedPatients;

  /// 设置缓存的患者数据
  void setCachedPatients(List<Patient>? patients) {
    _cachedPatients = patients;
  }

  /// 清除缓存
  void clearCache() {
    _cachedPatients = null;
  }

  /// 检查是否有缓存
  bool hasCache() {
    return _cachedPatients != null;
  }
}

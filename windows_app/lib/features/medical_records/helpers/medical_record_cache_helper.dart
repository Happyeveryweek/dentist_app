import '../../../models/patient_medical_record.dart';
import '../../../models/medical_record_template.dart';

/// 病历缓存管理助手
/// 负责处理病历记录和模板数据的缓存管理
class MedicalRecordCacheHelper {
  // 病历记录缓存
  Map<int, List<PatientMedicalRecord>> cachedMedicalRecords = {};
  DateTime? lastCacheTime;
  static const Duration cacheValidDuration = Duration(minutes: 15);

  // 模板数据缓存
  Map<String, List<MedicalRecordTemplate>> cachedTemplates = {};
  DateTime? lastTemplateCacheTime;
  static const Duration templateCacheValidDuration = Duration(minutes: 20);

  /// 检查病历记录缓存是否有效
  bool isCacheValid() {
    return lastCacheTime != null &&
           DateTime.now().difference(lastCacheTime!) < cacheValidDuration;
  }

  /// 检查模板缓存是否有效
  bool isTemplateCacheValid() {
    return lastTemplateCacheTime != null &&
           DateTime.now().difference(lastTemplateCacheTime!) < templateCacheValidDuration;
  }

  /// 更新病历记录缓存
  void updateCache(int patientId, List<PatientMedicalRecord> records) {
    cachedMedicalRecords[patientId] = records;
    lastCacheTime = DateTime.now();
  }

  /// 更新模板缓存
  void updateTemplateCache(String category, List<MedicalRecordTemplate> templates) {
    cachedTemplates[category] = templates;
    lastTemplateCacheTime = DateTime.now();
  }

  /// 清除病历记录缓存
  void clearCache() {
    cachedMedicalRecords.clear();
    lastCacheTime = null;
  }

  /// 清除模板缓存
  void clearTemplateCache() {
    cachedTemplates.clear();
    lastTemplateCacheTime = null;
  }

  /// 清除所有缓存
  void clearAllCache() {
    clearCache();
    clearTemplateCache();
  }

  /// 获取缓存模板数量
  int get cachedTemplatesCount =>
      cachedTemplates.values.fold(0, (sum, list) => sum + list.length);
}

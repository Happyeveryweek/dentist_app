import '../../../models/patient_medical_record.dart';
import '../../../models/medical_record_template.dart';

/// 病历缓存管理助手
/// 负责处理病历记录和模板数据的缓存管理
class MedicalRecordCacheHelper {
  MedicalRecordCacheHelper({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  // 病历记录缓存
  Map<int, List<PatientMedicalRecord>> cachedMedicalRecords = {};
  final Map<int, DateTime> _medicalRecordCacheTimes = {};
  static const Duration cacheValidDuration = Duration(minutes: 15);

  // 模板数据缓存
  Map<String, List<MedicalRecordTemplate>> cachedTemplates = {};
  final Map<String, DateTime> _templateCacheTimes = {};
  static const Duration templateCacheValidDuration = Duration(minutes: 20);

  /// 检查病历记录缓存是否有效
  bool isCacheValid(int patientId) {
    final cacheTime = _medicalRecordCacheTimes[patientId];
    return cacheTime != null &&
        _now().difference(cacheTime) < cacheValidDuration;
  }

  /// 检查模板缓存是否有效
  bool isTemplateCacheValid([String? category]) {
    if (category != null) {
      final cacheTime = _templateCacheTimes[category];
      return cacheTime != null &&
          _now().difference(cacheTime) < templateCacheValidDuration;
    }
    return cachedTemplates.isNotEmpty &&
        cachedTemplates.keys.every((key) => isTemplateCacheValid(key));
  }

  DateTime? lastTemplateCacheTimeFor(String category) =>
      _templateCacheTimes[category];

  /// 更新病历记录缓存
  void updateCache(int patientId, List<PatientMedicalRecord> records) {
    cachedMedicalRecords[patientId] = records;
    _medicalRecordCacheTimes[patientId] = _now();
  }

  /// 更新模板缓存
  void updateTemplateCache(
      String category, List<MedicalRecordTemplate> templates) {
    cachedTemplates[category] = templates;
    _templateCacheTimes[category] = _now();
  }

  /// 插入或替换单个模板缓存
  void upsertTemplate(MedicalRecordTemplate template) {
    final categoryTemplates = List<MedicalRecordTemplate>.from(
      cachedTemplates[template.category] ?? const <MedicalRecordTemplate>[],
    );
    final index =
        categoryTemplates.indexWhere((item) => item.id == template.id);
    if (index >= 0) {
      categoryTemplates[index] = template;
    } else {
      categoryTemplates.add(template);
    }
    cachedTemplates[template.category] = categoryTemplates;
    _templateCacheTimes[template.category] = _now();
  }

  /// 从模板缓存中移除指定ID
  void removeTemplateById(int id) {
    final keysToUpdate = <String>[];
    for (final entry in cachedTemplates.entries) {
      final next = entry.value.where((item) => item.id != id).toList();
      if (next.length != entry.value.length) {
        cachedTemplates[entry.key] = next;
        keysToUpdate.add(entry.key);
      }
    }
    if (keysToUpdate.isNotEmpty) {
      final now = _now();
      for (final key in keysToUpdate) {
        _templateCacheTimes[key] = now;
      }
    }
  }

  void invalidateMedicalRecords(int patientId) {
    cachedMedicalRecords.remove(patientId);
    _medicalRecordCacheTimes.remove(patientId);
  }

  /// 清除病历记录缓存
  void clearCache() {
    cachedMedicalRecords.clear();
    _medicalRecordCacheTimes.clear();
  }

  /// 清除模板缓存
  void clearTemplateCache() {
    cachedTemplates.clear();
    _templateCacheTimes.clear();
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

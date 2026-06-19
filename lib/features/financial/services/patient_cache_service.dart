import '../../../models/patient.dart';
import '../../../providers/patient_provider.dart';
import '../../../utils/pinyin_util.dart';
import 'package:flutter/material.dart';

/// 患者缓存服务
/// 
/// 提供患者信息缓存和查询功能
class PatientCacheService {
  final Map<int, Patient?> _cache = {};
  final PatientProvider _patientProvider;

  PatientCacheService(this._patientProvider);

  /// 从缓存获取患者信息
  Patient? getFromCache(int patientId) {
    return _cache[patientId];
  }

  /// 将患者信息添加到缓存
  void addToCache(int patientId, Patient patient) {
    _cache[patientId] = patient;
  }

  /// 从预加载列表中获取患者信息
  Patient? getFromPreloadedList(int patientId, List<Patient> preloadedPatients) {
    try {
      return preloadedPatients.firstWhere((p) => p.id == patientId);
    } catch (e) {
      return null;
    }
  }

  /// 异步获取患者信息（带缓存）
  Future<Patient?> getPatientById(
    int patientId, {
    required List<Patient> preloadedPatients,
    required String effectiveDataSourceType,
    required Function(Patient) onPatientAdded,
  }) async {
    // 先从缓存中查找
    if (_cache.containsKey(patientId)) {
      return _cache[patientId];
    }

    // 从预加载的列表中查找
    final patient = getFromPreloadedList(patientId, preloadedPatients);
    if (patient != null) {
      _cache[patientId] = patient;
      return patient;
    }

    // 从数据库重新加载所有患者
    try {
      final allPatients = await _patientProvider.getAllPatients();

      // 查找目标患者
      try {
        final targetPatient = allPatients.firstWhere((p) => p.id == patientId);
        final patientWithPinyin = targetPatient.copyWith(
          name_pinyin: PinyinUtil.toPinyin(targetPatient.name),
          name_initials: PinyinUtil.getInitials(targetPatient.name),
        );

        // 更新患者列表和缓存
        onPatientAdded(patientWithPinyin);
        _cache[patientId] = patientWithPinyin;

        return patientWithPinyin;
      } catch (e) {
        _cache[patientId] = null;
        return null;
      }
    } catch (e) {
      _cache[patientId] = null;
      return null;
    }
  }

  /// 同步获取患者信息（仅用于已缓存的情况）
  Patient? getPatientByIdSync(int patientId, List<Patient> preloadedPatients) {
    return getFromPreloadedList(patientId, preloadedPatients);
  }

  /// 清空缓存
  void clearCache() {
    _cache.clear();
  }
}

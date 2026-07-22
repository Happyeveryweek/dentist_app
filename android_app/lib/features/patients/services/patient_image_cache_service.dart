import 'package:flutter/material.dart';
import 'package:dentist_app/models/patient_material.dart';
import 'package:dentist_app/models/material_image.dart';
import 'dart:async';

/// 患者图片缓存管理服务
///
/// 职责：
/// - 缓存有效性检查
/// - 缓存更新/清除
/// - 缓存数据获取
/// - 加载/错误状态管理
class PatientImageCacheService {
  // 缓存患者图片数据
  final Map<int, List<PatientMaterial>> _patientMaterialsCache = {};
  final Map<int, List<MaterialImage>> _materialImagesCache = {};
  final Map<int, DateTime> _patientMaterialsCacheTimes = {};
  final Map<int, DateTime> _materialImagesCacheTimes = {};
  static const Duration _cacheValidDuration = Duration(minutes: 20);

  // 加载状态
  final Map<int, bool> _loadingStates = {};

  // 错误状态
  final Map<int, String?> _errorStates = {};

  // 防抖定时器
  Timer? _notifyTimer;
  final VoidCallback _notifyCallback;

  PatientImageCacheService(this._notifyCallback);

  /// 获取患者材料缓存
  List<PatientMaterial>? getPatientMaterialsCache(int patientId) {
    final cachedAt = _patientMaterialsCacheTimes[patientId];
    if (cachedAt == null) {
      return null;
    }
    if (!_isValid(cachedAt)) {
      clearPatientCache(patientId);
      return null;
    }
    final materials = _patientMaterialsCache[patientId];
    return materials == null ? null : List.from(materials);
  }

  /// 更新患者材料缓存
  void updatePatientMaterialsCache(
    int patientId,
    List<PatientMaterial> materials,
  ) {
    _patientMaterialsCache[patientId] = List.from(materials);
    _patientMaterialsCacheTimes[patientId] = DateTime.now();
    _safeNotifyListeners();
  }

  /// 获取材料图片缓存
  List<MaterialImage>? getMaterialImagesCache(int materialId) {
    final cachedAt = _materialImagesCacheTimes[materialId];
    if (cachedAt == null || !_isValid(cachedAt)) {
      _materialImagesCache.remove(materialId);
      _materialImagesCacheTimes.remove(materialId);
      return null;
    }
    final images = _materialImagesCache[materialId];
    return images == null ? null : List.from(images);
  }

  /// 更新材料图片缓存
  void updateMaterialImagesCache(int materialId, List<MaterialImage> images) {
    _materialImagesCache[materialId] = List.from(images);
    _materialImagesCacheTimes[materialId] = DateTime.now();
    _safeNotifyListeners();
  }

  /// 清除患者缓存
  void clearPatientCache(int patientId) {
    final materials = _patientMaterialsCache.remove(patientId);
    _patientMaterialsCacheTimes.remove(patientId);
    _loadingStates.remove(patientId);
    _errorStates.remove(patientId);

    // 清除相关的材料图片缓存
    if (materials != null) {
      for (final material in materials) {
        final materialId = material.id;
        if (materialId != null) {
          _materialImagesCache.remove(materialId);
          _materialImagesCacheTimes.remove(materialId);
        }
      }
    }

    _safeNotifyListeners();
  }

  /// 清除所有缓存
  void clearAllCache() {
    _patientMaterialsCache.clear();
    _materialImagesCache.clear();
    _patientMaterialsCacheTimes.clear();
    _materialImagesCacheTimes.clear();
    _loadingStates.clear();
    _errorStates.clear();
    _safeNotifyListeners();
  }

  /// 设置加载状态
  void setLoadingState(int patientId, bool isLoading) {
    _loadingStates[patientId] = isLoading;
    _safeNotifyListeners();
  }

  /// 获取加载状态
  bool isLoading(int patientId) {
    return _loadingStates[patientId] ?? false;
  }

  /// 设置错误状态
  void setError(int patientId, String error) {
    _errorStates[patientId] = error;
    _safeNotifyListeners();
  }

  /// 获取错误状态
  String? getError(int patientId) {
    return _errorStates[patientId];
  }

  /// 清除错误状态
  void clearError(int patientId) {
    _errorStates.remove(patientId);
    _safeNotifyListeners();
  }

  /// 检查是否有缓存数据
  bool hasCachedData(int patientId) {
    final materials = getPatientMaterialsCache(patientId);
    if (materials == null) return false;
    return materials.every((material) {
      final materialId = material.id;
      return materialId == null || getMaterialImagesCache(materialId) != null;
    });
  }

  /// 获取缓存的患者材料数量
  int getCachedMaterialCount(int patientId) {
    return getPatientMaterialsCache(patientId)?.length ?? 0;
  }

  /// 获取缓存的图片数量
  int getCachedImageCount(int patientId) {
    int count = 0;
    final materials = getPatientMaterialsCache(patientId);
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          count += getMaterialImagesCache(material.id!)?.length ?? 0;
        }
      }
    }
    return count;
  }

  /// 同步获取缓存的图片数据
  List<MaterialImage> getCachedImages(int patientId) {
    List<MaterialImage> allImages = [];
    final materials = getPatientMaterialsCache(patientId);
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          final images = getMaterialImagesCache(material.id!);
          if (images != null) {
            allImages.addAll(images);
          }
        }
      }
    }
    return allImages;
  }

  /// 同步获取缓存的材料数据
  List<PatientMaterial> getCachedMaterials(int patientId) {
    return getPatientMaterialsCache(patientId) ?? [];
  }

  bool _isValid(DateTime cachedAt) =>
      DateTime.now().difference(cachedAt) < _cacheValidDuration;

  /// 安全地通知监听器，避免在build过程中调用
  void _safeNotifyListeners() {
    // 取消之前的定时器
    _notifyTimer?.cancel();

    // 使用防抖机制，延迟50ms后通知，避免频繁触发
    _notifyTimer = Timer(const Duration(milliseconds: 50), () {
      _notifyCallback();
    });
  }

  /// 清理定时器
  void dispose() {
    _notifyTimer?.cancel();
  }
}

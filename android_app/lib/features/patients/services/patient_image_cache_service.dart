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

  // 加载状态
  final Map<int, bool> _loadingStates = {};

  // 错误状态
  final Map<int, String?> _errorStates = {};

  // 防抖定时器
  Timer? _notifyTimer;
  final VoidCallback _notifyCallback;

  PatientImageCacheService(this._notifyCallback);

  /// 检查是否有患者材料缓存
  bool hasPatientMaterialsCache(int patientId) {
    return _patientMaterialsCache.containsKey(patientId);
  }

  /// 获取患者材料缓存
  List<PatientMaterial>? getPatientMaterialsCache(int patientId) {
    return _patientMaterialsCache[patientId];
  }

  /// 更新患者材料缓存
  void updatePatientMaterialsCache(
    int patientId,
    List<PatientMaterial> materials,
  ) {
    _patientMaterialsCache[patientId] = materials;
    _safeNotifyListeners();
  }

  /// 检查是否有材料图片缓存
  bool hasMaterialImagesCache(int materialId) {
    return _materialImagesCache.containsKey(materialId);
  }

  /// 获取材料图片缓存
  List<MaterialImage>? getMaterialImagesCache(int materialId) {
    return _materialImagesCache[materialId];
  }

  /// 更新材料图片缓存
  void updateMaterialImagesCache(int materialId, List<MaterialImage> images) {
    _materialImagesCache[materialId] = images;
    _safeNotifyListeners();
  }

  /// 清除患者缓存
  void clearPatientCache(int patientId) {
    _patientMaterialsCache.remove(patientId);
    _loadingStates.remove(patientId);
    _errorStates.remove(patientId);

    // 清除相关的材料图片缓存
    final materials = _patientMaterialsCache[patientId];
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          _materialImagesCache.remove(material.id);
        }
      }
    }

    _safeNotifyListeners();
  }

  /// 清除所有缓存
  void clearAllCache() {
    _patientMaterialsCache.clear();
    _materialImagesCache.clear();
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
    return _patientMaterialsCache.containsKey(patientId);
  }

  /// 获取缓存的患者材料数量
  int getCachedMaterialCount(int patientId) {
    return _patientMaterialsCache[patientId]?.length ?? 0;
  }

  /// 获取缓存的图片数量
  int getCachedImageCount(int patientId) {
    int count = 0;
    final materials = _patientMaterialsCache[patientId];
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          count += _materialImagesCache[material.id]?.length ?? 0;
        }
      }
    }
    return count;
  }

  /// 同步获取缓存的图片数据
  List<MaterialImage> getCachedImages(int patientId) {
    List<MaterialImage> allImages = [];
    final materials = _patientMaterialsCache[patientId];
    if (materials != null) {
      for (final material in materials) {
        if (material.id != null) {
          final images = _materialImagesCache[material.id];
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
    return _patientMaterialsCache[patientId] ?? [];
  }

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

import 'package:flutter/foundation.dart';
import '../../../models/database_models.dart';

/// 预约缓存管理 mixin
/// 提供预约数据的缓存功能，包括缓存有效性检查、更新和清除
mixin AppointmentCacheMixin on ChangeNotifier {
  // 缓存数据
  List<Appointment>? _cachedAppointments;

  // 缓存机制
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 15);

  // 刷新标志
  bool _appointmentsNeedRefresh = false;

  // Getters
  bool get appointmentsNeedRefresh => _appointmentsNeedRefresh;
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedAppointmentsCount => _cachedAppointments?.length ?? 0;
  bool get hasValidCache => isCacheValid();

  // 检查缓存是否有效
  bool isCacheValid() {
    return _cachedAppointments != null &&
           _lastCacheTime != null &&
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  // 更新缓存
  void updateCache(List<Appointment> appointments) {
    _cachedAppointments = List.from(appointments);
    _lastCacheTime = DateTime.now();
    print('预约数据缓存已更新: ${appointments.length} 条记录');
  }

  // 清除缓存
  void clearCache() {
    _cachedAppointments = null;
    _lastCacheTime = null;
    _appointmentsNeedRefresh = true; // 标记需要刷新
    print('预约数据缓存已清除，标记需要刷新');
    // 延迟通知以避免在build阶段调用setState
    Future.microtask(() => notifyListeners());
  }

  // 标记需要刷新
  void markAppointmentsNeedRefresh() {
    _appointmentsNeedRefresh = true;
    notifyListeners();
  }

  // 清除刷新标志
  void clearAppointmentsNeedRefresh() {
    _appointmentsNeedRefresh = false;
  }

  // 强制刷新预约数据缓存
  void forceRefreshAppointments() {
    print('强制刷新预约数据缓存');
    _cachedAppointments = null;
    // 通知监听器
    notifyListeners();
  }

  // 获取缓存数据（供子类使用）
  List<Appointment>? get cachedAppointments => _cachedAppointments;
}

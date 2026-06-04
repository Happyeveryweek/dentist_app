import 'package:dentist_app/models/purchase_record.dart';

/// 采购数据缓存服务
/// 职责：缓存有效性检查、缓存更新、缓存清除、缓存数据获取
class PurchaseCacheService {
  // 缓存数据
  List<PurchaseRecord>? _cachedRecords;
  Map<String, dynamic>? _cachedStatistics;
  DateTime? _lastCacheTime;
  
  // 缓存有效期：20分钟
  static const Duration _cacheValidDuration = Duration(minutes: 20);
  
  // Getters
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;
  bool get hasCache => _cachedRecords != null && _cachedRecords!.isNotEmpty;
  List<PurchaseRecord> get cachedRecords => _cachedRecords ?? [];
  
  /// 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedRecords != null && 
           _lastCacheTime != null &&
           DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }
  
  /// 更新缓存
  void updateCache(List<PurchaseRecord> records, Map<String, dynamic> statistics) {
    _cachedRecords = List.from(records);
    _cachedStatistics = Map.from(statistics);
    _lastCacheTime = DateTime.now();
    print('采购数据缓存已更新: ${records.length} 条记录');
  }
  
  /// 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _cachedStatistics = null;
    _lastCacheTime = null;
    print('采购数据缓存已清除');
  }
  
  /// 检查缓存是否有效（公开方法）
  bool isCacheValid() {
    return _isCacheValid();
  }
}

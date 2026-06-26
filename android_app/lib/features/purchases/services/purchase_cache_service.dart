import 'package:dentist_app/models/purchase_record.dart';
import '../../../utils/app_logger.dart';

/// 采购数据缓存服务
/// 职责：缓存有效性检查、缓存更新、缓存清除、缓存数据获取
class PurchaseCacheService {
  // 缓存数据
  List<PurchaseRecord>? _cachedRecords;
  DateTime? _lastCacheTime;

  // 缓存有效期：20分钟
  static const Duration _cacheValidDuration = Duration(minutes: 20);

  // Getters
  bool get hasValidCache => _isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;
  bool get hasCache {
    final cachedRecords = _cachedRecords;
    return cachedRecords != null && cachedRecords.isNotEmpty;
  }

  List<PurchaseRecord> get cachedRecords => _cachedRecords ?? [];

  /// 检查缓存是否有效
  bool _isCacheValid() {
    final cachedRecords = _cachedRecords;
    final lastCacheTime = _lastCacheTime;
    return cachedRecords != null &&
        lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheValidDuration;
  }

  /// 更新缓存
  void updateCache(
    List<PurchaseRecord> records,
    Map<String, dynamic> statistics,
  ) {
    _cachedRecords = List.from(records);
    _lastCacheTime = DateTime.now();
    AppLogger.info('采购数据缓存已更新: ${records.length} 条记录');
  }

  /// 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _lastCacheTime = null;
    AppLogger.info('采购数据缓存已清除');
  }

  /// 检查缓存是否有效（公开方法）
  bool isCacheValid() {
    return _isCacheValid();
  }
}

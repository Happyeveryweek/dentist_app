import '../../../models/financial_record.dart';
import '../../../utils/timed_cache.dart';

/// 财务数据缓存管理助手
/// 负责财务记录的缓存验证、更新和清除
class FinancialCacheHelper {
  // 缓存数据
  List<FinancialRecord>? _cachedRecords;
  DateTime? _lastCacheTime;

  // 缓存有效期：20分钟
  static const Duration _cacheValidDuration = Duration(minutes: 20);
  final TimedCache<String, Map<String, dynamic>> _patientPageCache =
      TimedCache(validDuration: _cacheValidDuration);
  final TimedCache<String, int> _itemCountCache =
      TimedCache(validDuration: _cacheValidDuration);
  final TimedCache<String, List<Map<String, dynamic>>> _itemPageCache =
      TimedCache(validDuration: _cacheValidDuration);

  static String buildQueryKey(Iterable<Object?> parts) {
    return buildCacheKey(parts);
  }

  // 检查缓存是否有效
  bool isCacheValid() {
    final cacheTime = _lastCacheTime;
    return _cachedRecords != null &&
        cacheTime != null &&
        DateTime.now().difference(cacheTime) < _cacheValidDuration;
  }

  // 更新缓存
  void updateCache(List<FinancialRecord> records) {
    _cachedRecords = List.from(records);
    _lastCacheTime = DateTime.now();
  }

  // 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _lastCacheTime = null;
    _patientPageCache.clear();
    _itemCountCache.clear();
    _itemPageCache.clear();
  }

  Map<String, dynamic>? getPatientPage(String key) {
    final cached = _patientPageCache.get(key);
    if (cached == null) return null;
    return {
      'total': cached['total'],
      'rows': List<Map<String, dynamic>>.from(cached['rows'] as List),
    };
  }

  void putPatientPage(String key, Map<String, dynamic> value) {
    _patientPageCache.put(key, {
      'total': value['total'],
      'rows': List<Map<String, dynamic>>.from(value['rows'] as List),
    });
  }

  int? getItemCount(String key) => _itemCountCache.get(key);

  void putItemCount(String key, int value) => _itemCountCache.put(key, value);

  List<Map<String, dynamic>>? getItemPage(String key) {
    final cached = _itemPageCache.get(key);
    return cached == null ? null : List<Map<String, dynamic>>.from(cached);
  }

  void putItemPage(String key, List<Map<String, dynamic>> value) {
    _itemPageCache.put(key, List<Map<String, dynamic>>.from(value));
  }

  // Getters
  bool get hasValidCache => isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;
  List<FinancialRecord>? get cachedRecords => _cachedRecords;
}

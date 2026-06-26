import '../../../models/financial_record.dart';

/// 财务数据缓存管理助手
/// 负责财务记录的缓存验证、更新和清除
class FinancialCacheHelper {
  // 缓存数据
  List<FinancialRecord>? _cachedRecords;
  DateTime? _lastCacheTime;

  // 缓存有效期：20分钟
  static const Duration _cacheValidDuration = Duration(minutes: 20);

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
  }

  // Getters
  bool get hasValidCache => isCacheValid();
  DateTime? get lastCacheTime => _lastCacheTime;
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;
  List<FinancialRecord>? get cachedRecords => _cachedRecords;
}

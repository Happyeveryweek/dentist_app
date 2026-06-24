import '../../../models/financial_item.dart';
import '../../../models/financial_record.dart';
import '../../../utils/app_logger.dart';

/// 财务缓存管理助手
/// 职责：管理财务数据的缓存、缓存刷新、缓存有效性检查
class FinancialCacheHelper {
  List<FinancialRecord>? _cachedRecords;
  Map<int, List<FinancialItem>>? _cachedItemsMap;
  DateTime? _lastCacheTime;
  static const Duration _cacheValidDuration = Duration(minutes: 30); // 缓存30分钟有效

  // 全量统计缓存
  Map<String, dynamic>? _cachedStats;
  DateTime? _lastStatsCacheTime;
  static const Duration _statsCacheValidDuration = Duration(days: 1);

  // 全量 itemsMap 缓存（图表用，与统计缓存同生命周期）
  Map<int, List<FinancialItem>>? _cachedFullItemsMap;

  // 后台加载任务标志（防止重复启动）
  bool _isBackgroundLoadingFull = false;

  /// 检查缓存是否有效
  bool _isCacheValid() {
    return _cachedRecords != null &&
        _lastCacheTime != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheValidDuration;
  }

  /// 更新缓存（供外部调用，用于后台加载过程中实时更新）
  void updateCacheManually(
    List<FinancialRecord> records,
    Map<int, List<FinancialItem>> itemsMap,
  ) {
    _cachedRecords = List.from(records);
    _cachedItemsMap = Map.from(itemsMap);
    _lastCacheTime = DateTime.now();
    // 不打印重复日志，因为_updateCache已经打印过了
  }

  /// 检查是否有缓存
  bool get hasCache => _cachedRecords != null && _cachedRecords!.isNotEmpty;

  /// 检查缓存是否有效
  bool get hasValidCache => _isCacheValid();

  /// 获取缓存的记录
  List<FinancialRecord> get cachedRecords => _cachedRecords ?? [];

  /// 获取缓存的明细项映射
  Map<int, List<FinancialItem>> get cachedItemsMap => _cachedItemsMap ?? {};

  /// 获取最后缓存时间
  DateTime? get lastCacheTime => _lastCacheTime;

  /// 获取缓存记录数量
  int get cachedRecordsCount => _cachedRecords?.length ?? 0;

  /// 清除缓存
  void clearCache() {
    _cachedRecords = null;
    _cachedItemsMap = null;
    _lastCacheTime = null;
    AppLogger.info('财务数据缓存已清除');
  }

  /// 是否有有效的统计缓存
  bool get hasValidStatsCache =>
      _cachedStats != null &&
      _lastStatsCacheTime != null &&
      DateTime.now().difference(_lastStatsCacheTime!) <
          _statsCacheValidDuration;

  /// 是否有完整的 itemsMap 缓存（记录数与全量记录一致）
  bool get hasFullItemsCache =>
      hasValidStatsCache &&
      _cachedFullItemsMap != null &&
      _cachedRecords != null &&
      _cachedFullItemsMap!.length >= _cachedRecords!.length;

  /// 获取缓存的统计数据
  Map<String, dynamic>? get cachedStats => _cachedStats;

  /// 获取完整的 itemsMap 缓存
  Map<int, List<FinancialItem>>? get cachedFullItemsMap => _cachedFullItemsMap;

  /// 更新统计缓存
  void updateStatsCache(Map<String, dynamic> stats) {
    _cachedStats = Map.from(stats);
    _lastStatsCacheTime = DateTime.now();
  }

  /// 清除统计缓存
  void clearStatsCache() {
    _cachedStats = null;
    _cachedFullItemsMap = null;
    _lastStatsCacheTime = null;
    _isBackgroundLoadingFull = false;
  }

  /// 是否正在后台加载
  bool get isBackgroundLoadingFull => _isBackgroundLoadingFull;

  /// 启动后台全量加载任务（widget 无关，加载完自动缓存）
  /// 如果已在加载中或缓存有效则跳过
  void ensureFullDataCached({
    bool forceRefresh = false,
    required Future<List<FinancialRecord>> Function() getAllRecords,
    required Future<List<FinancialItem>> Function(int recordId)
    getItemsByRecordId,
    required Function() notifyListeners,
  }) {
    if (!forceRefresh && hasFullItemsCache) return;
    if (_isBackgroundLoadingFull) return;
    _isBackgroundLoadingFull = true;
    _runFullBackgroundLoad(getAllRecords, getItemsByRecordId, notifyListeners);
  }

  Future<void> _runFullBackgroundLoad(
    Future<List<FinancialRecord>> Function() getAllRecords,
    Future<List<FinancialItem>> Function(int recordId) getItemsByRecordId,
    Function() notifyListeners,
  ) async {
    try {
      AppLogger.info('📦 后台全量加载开始...');
      final allRecords = await getAllRecords();
      final allItemsMap = <int, List<FinancialItem>>{};

      // 先复制已有的缓存 itemsMap
      if (_cachedFullItemsMap != null) {
        allItemsMap.addAll(_cachedFullItemsMap!);
      }

      const batchSize = 20;
      final missing =
          allRecords
              .where((r) => r.id != null && !allItemsMap.containsKey(r.id))
              .toList();

      for (int i = 0; i < missing.length; i += batchSize) {
        final batch = missing.skip(i).take(batchSize).toList();
        for (final r in batch) {
          if (r.id != null) {
            try {
              allItemsMap[r.id!] = await getItemsByRecordId(r.id!);
            } catch (_) {
              allItemsMap[r.id!] = [];
            }
          }
        }
        // 每批完成后更新缓存（即使 widget 已关闭也会保存）
        _cachedFullItemsMap = Map.from(allItemsMap);
        final partialStats = _buildStatsFromData(allRecords, allItemsMap);
        updateStatsCache(partialStats);
        // 通知监听者（如果有 widget 还在监听）
        notifyListeners();
      }

      // 全部完成
      _cachedFullItemsMap = allItemsMap;
      final finalStats = _buildStatsFromData(allRecords, allItemsMap);
      updateStatsCache(finalStats);
      _isBackgroundLoadingFull = false;
      notifyListeners();
      AppLogger.info('✅ 后台全量加载完成，共 ${allRecords.length} 条记录，${allItemsMap.length} 个明细项');
    } catch (e) {
      AppLogger.info('❌ 后台全量加载失败: $e');
      _isBackgroundLoadingFull = false;
    }
  }

  /// 从记录和明细项计算统计数据
  Map<String, dynamic> _buildStatsFromData(
    List<FinancialRecord> records,
    Map<int, List<FinancialItem>> itemsMap,
  ) {
    final Set<int> patientIds = {};
    double totalCollected = 0;
    double totalProcessingFee = 0;
    int totalItems = 0;
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};

    for (final record in records) {
      if (record.id == null) continue;
      final items = itemsMap[record.id!] ?? [];
      for (final item in items) {
        patientIds.add(record.patientId);
        totalCollected += item.totalPrice;
        totalProcessingFee += item.processingFee;
        totalItems++;
        receivableByPatient[record.patientId] =
            (receivableByPatient[record.patientId] ?? 0) + item.itemPrice;
        receivedByPatient[record.patientId] =
            (receivedByPatient[record.patientId] ?? 0) + item.totalPrice;
      }
    }

    double totalOutstanding = 0;
    for (final entry in receivableByPatient.entries) {
      final pid = entry.key;
      final receivable = entry.value;
      final debt = receivable - (receivedByPatient[pid] ?? 0.0);
      if (debt > 0) totalOutstanding += debt;
    }

    return {
      'patientCount': patientIds.length,
      'itemCount': totalItems,
      'totalCollected': totalCollected,
      'totalOutstanding': totalOutstanding,
      'totalProcessingFee': totalProcessingFee,
    };
  }
}

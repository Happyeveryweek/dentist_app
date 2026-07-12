import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/providers/financial_provider.dart';
import 'package:dentist_app/models/financial_record.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:dentist_app/screens/financial_detail_screen.dart';
import 'package:dentist_app/features/financial/widgets/financial_record_dialog.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../providers/database_provider.dart';
import '../features/financial/services/financial_calculator.dart';
import '../features/financial/widgets/financial_sort_dialog.dart'
    as sort_dialog;
import '../features/financial/widgets/financial_statistics_dialog.dart';
import '../features/financial/widgets/financial_management_screen_body.dart';
import '../utils/app_logger.dart';

/// 财务管理主页面
class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({super.key});

  @override
  State<FinancialManagementScreen> createState() =>
      _FinancialManagementScreenState();
}

class _FinancialManagementScreenState extends State<FinancialManagementScreen> {
  List<FinancialRecord> _financialRecords = [];
  List<FinancialRecord> _filteredRecords = [];
  Map<int, List<FinancialItem>> _recordItemsMap = {};
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // 排序相关
  String _currentSort = 'updated_time';
  bool _ascending = false;

  // 时间筛选相关变量
  DateTime? _startDate;
  DateTime? _endDate;

  // 分页相关
  int _currentPage = 1;
  static const int _pageSize = 30;
  bool _hasMoreData = true;
  int _totalRecordsInDatabase = 0;
  bool _isSearchMode = false;
  final ScrollController _scrollController = ScrollController();

  // 全量统计缓存（顶部卡片用）
  Map<String, dynamic> _globalStats = {};
  bool _isStatsLoading = false;
  Timer? _searchDebounce;
  int _requestVersion = 0;
  List<FinancialRecord> _statisticsRecords = [];
  Map<int, List<FinancialItem>> _statisticsItemsMap = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadData(showToast: false);
  }

  void _scrollListener() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (!_isLoadingMore && _hasMoreData && !_isSearchMode) {
        _loadMoreRecords();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ❌ 完全移除自动刷新逻辑，避免任何意外触发
    // 所有数据刷新都由用户明确操作触发（手动刷新、下拉刷新、增删改操作）
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FinancialManagementScreenBody(
        isLoading: _isLoading,
        hasError: _hasError,
        errorMessage: _errorMessage,
        globalStats: _globalStats,
        isStatsLoading: _isStatsLoading,
        searchController: _searchController,
        searchQuery: _searchQuery,
        startDate: _startDate,
        endDate: _endDate,
        onSearchChanged: _onSearchChanged,
        financialRecords: _financialRecords,
        filteredRecords: _filteredRecords,
        recordItemsMap: _recordItemsMap,
        totalRecordsInDatabase: _totalRecordsInDatabase,
        currentPage: _currentPage,
        hasMoreData: _hasMoreData,
        isLoadingMore: _isLoadingMore,
        isSearchMode: _isSearchMode,
        scrollController: _scrollController,
        onShowStatistics: _showStatisticsDialog,
        onSearchSubmitted: (value) {
          _searchDebounce?.cancel();
          setState(() {
            _searchQuery = value.trim();
          });
          _performSearch();
        },
        onClearSearch: () {
          _searchDebounce?.cancel();
          setState(() {
            _searchQuery = '';
            _searchController.clear();
          });
          _loadData(showToast: false);
        },
        onSortPressed: () => _showSortOptions(context),
        onDateFilterPressed: _showCustomDateRangePicker,
        onPresetDateFilter: _applyPresetDateFilter,
        onClearDateFilter: () {
          setState(() {
            _startDate = null;
            _endDate = null;
          });
          _onDateFilterChanged();
        },
        onRefresh: () async {
          await _loadData(showToast: false, forceRefresh: true);
          if (context.mounted) {
            SuccessToastManager.show(context, message: '刷新成功');
          }
        },
        onReconnect: _reconnectDatabase,
        onShowRecordDetails:
            (record) => _showFinancialRecordDetails(context, record),
        onDeleteRecord: (record) => _deleteFinancialRecord(record),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFinancialRecordDialog(context),
        backgroundColor: Theme.of(context).primaryColor,
        heroTag: 'financial_add_button',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 重新连接数据库
  Future<void> _reconnectDatabase() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
      if (dbProvider.dbType == 'mysql') {
        // 直接重新加载数据，如果连接有问题会自动提示
        await _loadData(showToast: true, forceRefresh: true);
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '重连过程中出错: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// 加载数据 - 分页加载（时间筛选走数据库）
  Future<void> _loadData({
    bool showToast = true,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    final requestVersion = ++_requestVersion;

    try {
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );
      final databaseProvider = Provider.of<DatabaseProvider>(
        context,
        listen: false,
      );

      if (!financialProvider.initialized) {
        setState(() {
          _isLoading = true;
        });
        await financialProvider.initializeFromDatabase(databaseProvider);
      }

      if (databaseProvider.dbType == 'mysql' && !databaseProvider.isConnected) {
        throw Exception('数据库连接失败，请检查网络连接');
      }

      if (forceRefresh) {
        financialProvider.clearCache();
        financialProvider.clearStatsCache();
      }

      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = '';
        _currentPage = 1;
        _hasMoreData = true;
        _isSearchMode = false;
      });

      // 获取当前筛选条件下的总数
      _totalRecordsInDatabase = await financialProvider
          .getFinancialRecordCountWithDateFilter(
            startDate: _startDate,
            endDate: _endDate,
          );

      // 加载第一页（带日期筛选）
      final records = await financialProvider
          .getPaginatedFinancialRecordsWithDateFilter(
            1,
            _pageSize,
            startDate: _startDate,
            endDate: _endDate,
          );

      // 加载明细项
      final itemsMap = <int, List<FinancialItem>>{};
      for (final record in records) {
        if (!mounted || requestVersion != _requestVersion) return;
        final recordId = record.id;
        if (recordId != null) {
          itemsMap[recordId] = await financialProvider
              .getFinancialItemsByRecordId(recordId);
        }
      }

      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _financialRecords = records;
        _filteredRecords = records;
        _recordItemsMap = itemsMap;
        _isLoading = false;
        _hasMoreData = records.length >= _pageSize;
      });

      // 异步加载全量统计（不阻塞列表显示）
      unawaited(_loadStatisticsForCurrentQuery(financialProvider));

      if (mounted && showToast) {
        SuccessToastManager.show(context, message: '数据已刷新');
      }
    } catch (e) {
      AppLogger.info('❌ 加载财务数据失败: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '加载数据失败: $e';
      });
      if (mounted && showToast) {
        SuccessToastManager.showError(
          context,
          message: '加载数据失败: $e',
          duration: const Duration(seconds: 4),
        );
      }
    }
  }

  /// 加载与当前列表相同查询条件的完整统计数据。
  Future<void> _loadStatisticsForCurrentQuery(
    FinancialProvider financialProvider,
  ) async {
    final requestVersion = ++_requestVersion;
    final query = _searchQuery.trim();
    final startDate = _startDate;
    final endDate = _endDate;
    final initialRecords = List<FinancialRecord>.from(_financialRecords);
    final initialItemsMap = Map<int, List<FinancialItem>>.from(_recordItemsMap);
    if (mounted) {
      setState(() {
        _isStatsLoading = true;
        if (initialRecords.isNotEmpty) {
          _statisticsRecords = initialRecords;
          _statisticsItemsMap = initialItemsMap;
          _globalStats = {
            ...financialProvider.calculateStatsFromData(
              initialRecords,
              initialItemsMap,
            ),
            '_isPartial': true,
            '_loadedRecordCount': initialRecords.length,
          };
        } else {
          _globalStats = {};
          _statisticsRecords = [];
          _statisticsItemsMap = {};
        }
      });
    }

    try {
      final records = <FinancialRecord>[];
      if (query.isNotEmpty) {
        records.addAll(
          await financialProvider.searchFinancialRecords(
            query,
            startDate: startDate,
            endDate: endDate,
          ),
        );
      } else {
        final total = await financialProvider
            .getFinancialRecordCountWithDateFilter(
              startDate: startDate,
              endDate: endDate,
            );
        for (var page = 1; records.length < total; page++) {
          final pageRecords = await financialProvider
              .getPaginatedFinancialRecordsWithDateFilter(
                page,
                _pageSize,
                startDate: startDate,
                endDate: endDate,
              );
          if (pageRecords.isEmpty) break;
          records.addAll(pageRecords);
        }
      }

      final itemsMap = <int, List<FinancialItem>>{};
      if (records.isEmpty) {
        if (!mounted || requestVersion != _requestVersion) return;
        setState(() {
          _statisticsRecords = [];
          _statisticsItemsMap = {};
          _globalStats = financialProvider.calculateStatsFromData([], {});
          _isStatsLoading = false;
        });
        return;
      }

      const statsBatchSize = 20;
      for (var index = 0; index < records.length; index++) {
        final record = records[index];
        final recordId = record.id;
        if (recordId != null) {
          itemsMap[recordId] = await financialProvider
              .getFinancialItemsByRecordId(recordId);
        }

        final loadedRecordCount = index + 1;
        final hasMoreItems = loadedRecordCount < records.length;
        if (loadedRecordCount % statsBatchSize == 0 || !hasMoreItems) {
          if (!mounted || requestVersion != _requestVersion) return;
          setState(() {
            _statisticsRecords = records;
            _statisticsItemsMap = Map.from(itemsMap);
            _globalStats = {
              ...financialProvider.calculateStatsFromData(records, itemsMap),
              if (hasMoreItems) ...{
                '_isPartial': true,
                '_loadedRecordCount': loadedRecordCount,
              },
            };
            _isStatsLoading = hasMoreItems;
          });
        }
      }
    } catch (e) {
      AppLogger.info('加载财务统计数据失败: $e');
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _globalStats = {'_error': '统计数据加载失败，请下拉刷新后重试'};
        _isStatsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  /// 加载更多（下一页，带日期筛选）
  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || !_hasMoreData || _isSearchMode) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );
      final nextPage = _currentPage + 1;
      final records = await financialProvider
          .getPaginatedFinancialRecordsWithDateFilter(
            nextPage,
            _pageSize,
            startDate: _startDate,
            endDate: _endDate,
          );

      final itemsMap = Map<int, List<FinancialItem>>.from(_recordItemsMap);
      for (final record in records) {
        if (!mounted) return;
        final recordId = record.id;
        if (recordId != null) {
          itemsMap[recordId] = await financialProvider
              .getFinancialItemsByRecordId(recordId);
        }
      }

      if (mounted) {
        setState(() {
          _financialRecords.addAll(records);
          _filteredRecords = List.from(_financialRecords);
          _recordItemsMap = itemsMap;
          _currentPage = nextPage;
          _hasMoreData = records.length >= _pageSize;
          _isLoadingMore = false;
        });
        _sortLoadedRecords();
      }
    } catch (e) {
      AppLogger.info('❌ 加载更多财务记录失败: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = value.trim();
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _performSearch();
    });
  }

  /// 执行数据库搜索
  Future<void> _performSearch() async {
    if (!mounted) return;
    final query = _searchQuery.trim();
    final requestVersion = ++_requestVersion;

    if (query.isEmpty) {
      _loadData(showToast: false);
      return;
    }

    setState(() {
      _isLoading = true;
      _isSearchMode = true;
      _hasMoreData = false;
    });

    try {
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );
      final records = await financialProvider.searchFinancialRecords(
        query,
        startDate: _startDate,
        endDate: _endDate,
      );

      final itemsMap = <int, List<FinancialItem>>{};
      for (final record in records) {
        if (!mounted) return;
        final recordId = record.id;
        if (recordId != null) {
          itemsMap[recordId] = await financialProvider
              .getFinancialItemsByRecordId(recordId);
        }
      }

      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _financialRecords = records;
        _filteredRecords = records;
        _recordItemsMap = itemsMap;
        _totalRecordsInDatabase = records.length;
        _isLoading = false;
      });
      _sortLoadedRecords();
      unawaited(_loadStatisticsForCurrentQuery(financialProvider));
    } catch (e) {
      AppLogger.info('❌ 搜索财务记录失败: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '搜索失败: $e';
      });
    }
  }

  /// 时间筛选变更 - 重新从数据库加载
  void _onDateFilterChanged() {
    if (_searchQuery.trim().isNotEmpty) {
      _performSearch();
    } else {
      _loadData(showToast: false);
    }
  }

  /// 时间范围选择方法
  Future<void> _showCustomDateRangePicker() async {
    final now = DateTime.now();
    final DateTime initialStart =
        _startDate ?? DateTime(now.year, now.month, 1);
    final DateTime initialEnd = _endDate ?? now;
    final picked = await ReusableDateRangePicker.show(
      context,
      start: initialStart,
      end: initialEnd,
      title: '选择财务记录日期范围',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _onDateFilterChanged();
    }
  }

  void _applyPresetDateFilter(String preset) {
    final now = DateTime.now();
    DateTime? start;
    DateTime? end;

    switch (preset) {
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 0);
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        start = DateTime(lastMonth.year, lastMonth.month, 1);
        end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case '30d':
        start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(const Duration(days: 29));
        end = DateTime(now.year, now.month, now.day);
        break;
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year, 12, 31);
        break;
      case 'all':
        break;
      default:
        return;
    }

    setState(() {
      _startDate = start;
      _endDate = end;
    });
    _onDateFilterChanged();
  }

  /// 显示排序选项对话框
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => sort_dialog.FinancialSortDialogContent(
            currentSort: _currentSort,
            isAscending: _ascending,
            onSortChanged: (sortType) {
              setState(() {
                if (_currentSort == sortType) {
                  // 如果已经是当前排序项，则切换顺序
                  _ascending = !_ascending;
                } else {
                  // 否则更改排序项并设置为降序
                  _currentSort = sortType;
                  _ascending = false;
                }
              });
              // 应用排序
              _applySort();
            },
          ),
    );
  }

  /// 对记录进行排序（基于缓存数据）
  Future<void> _applySort() async {
    if (_currentSort != 'updated_time') {
      final financialProvider = Provider.of<FinancialProvider>(
        context,
        listen: false,
      );
      await _loadStatisticsForCurrentQuery(financialProvider);
      if (!mounted) return;
      setState(() {
        _financialRecords = List.from(_statisticsRecords);
        _filteredRecords = List.from(_statisticsRecords);
        _recordItemsMap = Map.from(_statisticsItemsMap);
        _totalRecordsInDatabase = _statisticsRecords.length;
        _hasMoreData = false;
      });
    }
    _sortLoadedRecords();
  }

  void _sortLoadedRecords() {
    setState(() {
      switch (_currentSort) {
        case 'updated_time':
          _filteredRecords.sort((a, b) {
            return _ascending
                ? a.updatedAt.compareTo(b.updatedAt)
                : b.updatedAt.compareTo(a.updatedAt);
          });
          break;
        case 'collected_amount':
          _filteredRecords.sort((a, b) {
            final aCollected =
                FinancialCalculator.calculatePatientLatestCollectedAmount(
                  a.patientId,
                  _financialRecords,
                  _recordItemsMap,
                );
            final bCollected =
                FinancialCalculator.calculatePatientLatestCollectedAmount(
                  b.patientId,
                  _financialRecords,
                  _recordItemsMap,
                );
            return _ascending
                ? aCollected.compareTo(bCollected)
                : bCollected.compareTo(aCollected);
          });
          break;
        case 'outstanding_amount':
          _filteredRecords.sort((a, b) {
            final aReceivable =
                FinancialCalculator.calculatePatientLatestReceivableAmount(
                  a.patientId,
                  _financialRecords,
                  _recordItemsMap,
                );
            final aCollected =
                FinancialCalculator.calculatePatientLatestCollectedAmount(
                  a.patientId,
                  _financialRecords,
                  _recordItemsMap,
                );
            final aOutstanding = aReceivable - aCollected;

            final bReceivable =
                FinancialCalculator.calculatePatientLatestReceivableAmount(
                  b.patientId,
                  _financialRecords,
                  _recordItemsMap,
                );
            final bCollected =
                FinancialCalculator.calculatePatientLatestCollectedAmount(
                  b.patientId,
                  _financialRecords,
                  _recordItemsMap,
                );
            final bOutstanding = bReceivable - bCollected;

            return _ascending
                ? aOutstanding.compareTo(bOutstanding)
                : bOutstanding.compareTo(aOutstanding);
          });
          break;
      }
    });
  }

  /// 显示添加财务记录对话框
  void _showAddFinancialRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止误触关闭
      builder: (context) => const FinancialRecordDialog(),
    ).then((result) {
      if (result == true) {
        AppLogger.info('🔄 财务记录添加成功，正在刷新数据...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true, forceRefresh: true); // 添加成功后显示提示并强制刷新
          }
        });
      }
    });
  }

  /// 显示财务记录详情
  void _showFinancialRecordDetails(
    BuildContext context,
    FinancialRecord record,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialDetailScreen(record: record),
      ),
    ).then((result) {
      // 如果从详情页返回true，说明有数据变更，需要刷新
      if (result == true) {
        AppLogger.info('🔄 从详情页返回，检测到数据变更，正在刷新...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true, forceRefresh: true); // 有数据变更时显示提示并强制刷新
          }
        });
      }
    });
  }

  /// 显示当前列表查询范围内的统计图表。
  void _showStatisticsDialog() async {
    final financialProvider = Provider.of<FinancialProvider>(
      context,
      listen: false,
    );

    if (_isStatsLoading || _statisticsRecords.isEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      await _loadStatisticsForCurrentQuery(financialProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
    }

    final statsError = _globalStats['_error'] as String?;
    if (statsError != null) {
      SuccessToastManager.showError(context, message: statsError);
      return;
    }

    _openStatisticsDialog(
      financialProvider,
      _statisticsRecords,
      itemsMap: _statisticsItemsMap,
    );
  }

  void _openStatisticsDialog(
    FinancialProvider financialProvider,
    List<FinancialRecord> records, {
    required Map<int, List<FinancialItem>> itemsMap,
  }) {
    if (records.isEmpty) {
      SuccessToastManager.showInfo(
        context,
        message: '暂无财务数据可统计',
        duration: const Duration(seconds: 2),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height * 0.9,
              child: FinancialStatisticsDialog(
                financialProvider: financialProvider,
                financialRecords: records,
                recordItemsMap: itemsMap,
                initialStartDate: _startDate,
                initialEndDate: _endDate,
              ),
            ),
          ),
    );
  }

  /// 删除财务记录
  Future<void> _deleteFinancialRecord(FinancialRecord record) async {
    final recordId = record.id;
    if (recordId == null) {
      if (mounted) {
        SuccessToastManager.showError(context, message: '记录ID无效，无法删除');
      }
      return;
    }
    // 直接使用记录中的患者姓名
    final patientName = record.patientName ?? '未知患者';

    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showFinancialDelete(
      context,
      financialInfo: '患者 "$patientName" 的财务记录',
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        final provider = Provider.of<FinancialProvider>(context, listen: false);
        await provider.deleteFinancialRecord(recordId);

        if (mounted) {
          // 使用新的成功提示组件
          SuccessToastManager.show(
            context,
            message: '财务记录删除成功',
            duration: const Duration(seconds: 2),
          );
          // 延迟重新加载数据，确保数据库操作完成
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _loadData(showToast: true, forceRefresh: true); // 删除成功后显示提示并强制刷新
            }
          });
        }
      } catch (e) {
        if (mounted) {
          // 使用新的错误提示组件
          SuccessToastManager.showError(
            context,
            message: '删除失败: $e',
            duration: const Duration(seconds: 4),
          );
        }
      }
    }
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/providers/financial_provider.dart';
import 'package:dentist_app/models/financial_record.dart';
import 'package:dentist_app/models/financial_item.dart';
import 'package:dentist_app/screens/financial_detail_screen.dart';
import 'package:dentist_app/features/financial/widgets/financial_record_dialog.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import '../widgets/app_card.dart';
import 'package:dentist_app/features/financial/widgets/financial_statistics_dialog.dart';
import '../widgets/reusable_date_range_picker.dart';
import '../providers/database_provider.dart';
import '../features/financial/services/financial_calculator.dart';
import '../features/financial/widgets/financial_search_bar.dart';
import '../features/financial/widgets/financial_statistics_card.dart';
import '../features/financial/widgets/financial_record_card.dart';
import '../features/financial/widgets/financial_sort_dialog.dart' as sort_dialog;
import '../features/financial/widgets/progressive_statistics_dialog.dart';
import '../features/financial/widgets/financial_management_screen_body.dart';

/// 财务管理主页面
class FinancialManagementScreen extends StatefulWidget {
  const FinancialManagementScreen({super.key});

  @override
  State<FinancialManagementScreen> createState() => _FinancialManagementScreenState();
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
  // 保存 provider 引用，用于 dispose 时安全移除监听
  FinancialProvider? _financialProviderRef;

  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _loadData(showToast: false);
    _hasInitialized = true;
  }

  void _scrollListener() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
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
          setState(() { _searchQuery = value.trim(); });
          _performSearch();
        },
        onClearSearch: () {
          setState(() {
            _searchQuery = '';
            _searchController.clear();
          });
          _loadData(showToast: false);
        },
        onSortPressed: () => _showSortOptions(context),
        onDateFilterPressed: _showCustomDateRangePicker,
        onClearDateFilter: () {
          setState(() { _startDate = null; _endDate = null; });
          _onDateFilterChanged();
        },
        onRefresh: () async {
          await _loadData(showToast: false, forceRefresh: true);
          if (mounted) {
            SuccessToastManager.show(
              context,
              message: '刷新成功',
            );
          }
        },
        onReconnect: _reconnectDatabase,
        onShowRecordDetails: (record) => _showFinancialRecordDetails(context, record),
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
  Future<void> _loadData({bool showToast = true, bool forceRefresh = false}) async {
    if (!mounted) return;

    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final databaseProvider = Provider.of<DatabaseProvider>(context, listen: false);

      if (!financialProvider.initialized) {
        setState(() { _isLoading = true; });
        await financialProvider.initializeFromDatabase(databaseProvider);
      }

      if (databaseProvider.dbType == 'mysql' && !databaseProvider.isConnected) {
        throw Exception('数据库连接失败，请检查网络连接');
      }

      if (forceRefresh) {
        financialProvider.clearCache();
        financialProvider.clearStatsCache();
      }

      // 有分页缓存且无时间筛选且不强制刷新，直接用缓存
      if (!forceRefresh && financialProvider.hasCache && _startDate == null && _endDate == null) {
        final cached = financialProvider.cachedRecords;
        final cachedItems = financialProvider.cachedItemsMap;
        setState(() {
          _financialRecords = cached.take(_pageSize).toList();
          _filteredRecords = _financialRecords;
          _recordItemsMap = cachedItems;
          _totalRecordsInDatabase = cached.length;
          _currentPage = 1;
          _hasMoreData = cached.length > _pageSize;
          _isSearchMode = false;
          _isLoading = false;
        });
        // 统计数据
        if (financialProvider.cachedStats != null) {
          setState(() { _globalStats = financialProvider.cachedStats!; });
        }
        _loadGlobalStats(financialProvider, forceRefresh: false);
        return;
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
      _totalRecordsInDatabase = await financialProvider.getFinancialRecordCountWithDateFilter(
        startDate: _startDate,
        endDate: _endDate,
      );

      // 加载第一页（带日期筛选）
      final records = await financialProvider.getPaginatedFinancialRecordsWithDateFilter(
        1, _pageSize,
        startDate: _startDate,
        endDate: _endDate,
      );

      // 加载明细项
      final itemsMap = <int, List<FinancialItem>>{};
      for (final record in records) {
        if (!mounted) return;
        if (record.id != null) {
          try {
            itemsMap[record.id!] = await financialProvider.getFinancialItemsByRecordId(record.id!);
          } catch (e) {
            itemsMap[record.id!] = [];
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _financialRecords = records;
        _filteredRecords = records;
        _recordItemsMap = itemsMap;
        _isLoading = false;
        _hasMoreData = records.length >= _pageSize;
      });

      // 异步加载全量统计（不阻塞列表显示）
      _loadGlobalStats(financialProvider, forceRefresh: forceRefresh);

      if (mounted && showToast) {
        SuccessToastManager.show(context, message: '数据已刷新');
      }
    } catch (e) {
      print('❌ 加载财务数据失败: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '加载数据失败: $e';
      });
      if (mounted && showToast) {
        SuccessToastManager.showError(context, message: '加载数据失败: $e', duration: const Duration(seconds: 4));
      }
    }
  }

  /// 渐进式加载全量统计（先快速显示，后台独立任务继续更新）
  Future<void> _loadGlobalStats(FinancialProvider financialProvider, {bool forceRefresh = false}) async {
    if (mounted) setState(() { _isStatsLoading = true; });

    await financialProvider.loadStatsProgressively(
      initialCount: 10,
      batchSize: 20,
      forceRefresh: forceRefresh,
      onProgress: (stats, isDone) {
        if (mounted) {
          setState(() {
            _globalStats = stats;
            if (isDone) _isStatsLoading = false;
          });
        }
      },
    );

    // 确保后台全量加载任务已启动（独立于 widget 生命周期）
    financialProvider.ensureFullDataCached(forceRefresh: forceRefresh);

    // 只添加一次监听
    if (_financialProviderRef == null) {
      _financialProviderRef = financialProvider;
      financialProvider.addListener(_onProviderStatsUpdated);
    }
  }

  void _onProviderStatsUpdated() {
    if (!mounted) return; // 安全检查，unmount 后不执行
    final financialProvider = _financialProviderRef;
    if (financialProvider != null && financialProvider.cachedStats != null) {
      setState(() {
        _globalStats = financialProvider.cachedStats!;
        _isStatsLoading = financialProvider.isBackgroundLoadingFull;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    // 用保存的引用安全移除监听，不访问 context
    _financialProviderRef?.removeListener(_onProviderStatsUpdated);
    _financialProviderRef = null;
    super.dispose();
  }

  /// 加载更多（下一页，带日期筛选）
  Future<void> _loadMoreRecords() async {
    if (_isLoadingMore || !_hasMoreData || _isSearchMode) return;
    setState(() { _isLoadingMore = true; });

    try {
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final nextPage = _currentPage + 1;
      final records = await financialProvider.getPaginatedFinancialRecordsWithDateFilter(
        nextPage, _pageSize,
        startDate: _startDate,
        endDate: _endDate,
      );

      final itemsMap = Map<int, List<FinancialItem>>.from(_recordItemsMap);
      for (final record in records) {
        if (!mounted) return;
        if (record.id != null) {
          try {
            itemsMap[record.id!] = await financialProvider.getFinancialItemsByRecordId(record.id!);
          } catch (e) {
            itemsMap[record.id!] = [];
          }
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
        _sortRecords();
      }
    } catch (e) {
      print('❌ 加载更多财务记录失败: $e');
      if (mounted) setState(() { _isLoadingMore = false; });
    }
  }

  /// 执行数据库搜索
  Future<void> _performSearch() async {
    if (!mounted) return;
    final query = _searchQuery.trim();

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
      final financialProvider = Provider.of<FinancialProvider>(context, listen: false);
      final records = await financialProvider.searchFinancialRecords(query);

      final itemsMap = <int, List<FinancialItem>>{};
      for (final record in records) {
        if (!mounted) return;
        if (record.id != null) {
          try {
            itemsMap[record.id!] = await financialProvider.getFinancialItemsByRecordId(record.id!);
          } catch (e) {
            itemsMap[record.id!] = [];
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _financialRecords = records;
        _filteredRecords = records;
        _recordItemsMap = itemsMap;
        _totalRecordsInDatabase = records.length;
        _isLoading = false;
      });
      _sortRecords();
    } catch (e) {
      print('❌ 搜索财务记录失败: $e');
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
    _loadData(showToast: false);
  }

  /// 时间范围选择方法
  Future<void> _showCustomDateRangePicker() async {
    final now = DateTime.now();
    final DateTime initialStart = _startDate ?? DateTime(now.year, now.month, 1);
    final DateTime initialEnd = _endDate ?? now;
    final picked = await ReusableDateRangePicker.show(
      context,
      start: initialStart,
      end: initialEnd,
      title: '选择财务记录日期范围'
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _onDateFilterChanged();
    }
  }

  /// 显示排序选项对话框
  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => sort_dialog.FinancialSortDialogContent(
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
          _sortRecords();
        },
      ),
    );
  }

  /// 对记录进行排序（基于缓存数据）
  void _sortRecords() {
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
            final aCollected = FinancialCalculator.calculatePatientLatestCollectedAmount(
              a.patientId,
              _financialRecords,
              _recordItemsMap,
            );
            final bCollected = FinancialCalculator.calculatePatientLatestCollectedAmount(
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
            final aReceivable = FinancialCalculator.calculatePatientLatestReceivableAmount(
              a.patientId,
              _financialRecords,
              _recordItemsMap,
            );
            final aCollected = FinancialCalculator.calculatePatientLatestCollectedAmount(
              a.patientId,
              _financialRecords,
              _recordItemsMap,
            );
            final aOutstanding = aReceivable - aCollected;
            
            final bReceivable = FinancialCalculator.calculatePatientLatestReceivableAmount(
              b.patientId,
              _financialRecords,
              _recordItemsMap,
            );
            final bCollected = FinancialCalculator.calculatePatientLatestCollectedAmount(
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
        print('🔄 财务记录添加成功，正在刷新数据...');
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
  void _showFinancialRecordDetails(BuildContext context, FinancialRecord record) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialDetailScreen(record: record),
      ),
    ).then((result) {
      // 如果从详情页返回true，说明有数据变更，需要刷新
      if (result == true) {
        print('🔄 从详情页返回，检测到数据变更，正在刷新...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true, forceRefresh: true); // 有数据变更时显示提示并强制刷新
          }
        });
      }
    });
  }

  /// 显示统计信息对话框 - 渐进式加载全量数据
  void _showStatisticsDialog() async {
    final financialProvider = Provider.of<FinancialProvider>(context, listen: false);

    // 有完整 itemsMap 缓存，直接打开，不转圈
    if (financialProvider.hasFullItemsCache) {
      final allRecords = financialProvider.cachedRecords;
      final allItemsMap = financialProvider.cachedFullItemsMap!;
      _openStatisticsDialog(financialProvider, allRecords, initialItemsMap: allItemsMap);
      return;
    }

    // 没有完整缓存，先加载前10条快速打开
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final initialRecords = await financialProvider.getPaginatedFinancialRecords(1, 10);
      final initialItemsMap = <int, List<FinancialItem>>{};
      for (final r in initialRecords) {
        if (r.id != null) {
          try {
            initialItemsMap[r.id!] = await financialProvider.getFinancialItemsByRecordId(r.id!);
          } catch (_) {
            initialItemsMap[r.id!] = [];
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      // 用初步数据先打开图表
      _openStatisticsDialog(financialProvider, initialRecords, initialItemsMap: initialItemsMap);

      // 启动后台全量加载（独立于 widget，关闭图表也继续跑）
      financialProvider.ensureFullDataCached();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        SuccessToastManager.showError(context, message: '加载统计数据失败: $e');
      }
    }
  }

  void _openStatisticsDialog(
    FinancialProvider financialProvider,
    List<FinancialRecord> records, {
    Map<int, List<FinancialItem>>? initialItemsMap,
  }) {
    if (records.isEmpty) {
      SuccessToastManager.showInfo(context, message: '暂无财务数据可统计', duration: const Duration(seconds: 2));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height * 0.9,
          child: ProgressiveStatisticsDialog(
            financialProvider: financialProvider,
            initialRecords: records,
            initialItemsMap: initialItemsMap ?? {},
          ),
        ),
      ),
    );
  }

  /// 删除财务记录
  Future<void> _deleteFinancialRecord(FinancialRecord record) async {
    // 直接使用记录中的患者姓名
    final patientName = record.patientName ?? '未知患者';
    
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showFinancialDelete(
      context,
      financialInfo: '患者 "$patientName" 的财务记录',
    );

    if (confirmed == true) {
      try {
        final provider = Provider.of<FinancialProvider>(context, listen: false);
        await provider.deleteFinancialRecord(record.id!);
        
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

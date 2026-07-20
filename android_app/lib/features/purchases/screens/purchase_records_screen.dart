import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dentist_app/providers/purchase_provider.dart';
import 'package:dentist_app/screens/purchase_detail_screen.dart';
import '../widgets/purchase_statistics_dialog.dart';
import 'package:dentist_app/widgets/toast_manager.dart';
import 'package:dentist_app/widgets/confirm_dialogs.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../providers/database_provider.dart';
import '../widgets/purchase_record_dialog.dart';
import '../widgets/purchase_statistics_card.dart';
import '../widgets/purchase_search_bar.dart';
import '../widgets/purchase_record_card.dart';
import '../widgets/purchase_records_empty_state.dart';
import '../services/purchase_statistics_service.dart';
import '../../../utils/app_logger.dart';

/// 采购记录管理主页面
class PurchaseRecordsScreen extends StatefulWidget {
  const PurchaseRecordsScreen({super.key});

  @override
  State<PurchaseRecordsScreen> createState() => _PurchaseRecordsScreenState();
}

class _PurchaseRecordsScreenState extends State<PurchaseRecordsScreen> {
  List<PurchaseRecord> _purchaseRecords = [];
  List<PurchaseRecord> _filteredRecords = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _statistics = {};
  Map<int, int> _projectCountsByRecordId = {};
  String? _loadErrorMessage;
  int _requestVersion = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _loadData(showToast: false); // 初始加载时不显示提示
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 统计信息卡片
          PurchaseStatisticsCard(
            statistics: _statistics,
            onTap: _showPurchaseStatistics,
          ),

          // 搜索栏
          PurchaseSearchBar(
            controller: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: _onSearchChanged,
            onSearchSubmitted: () {
              _searchDebounce?.cancel();
              setState(() {
                _searchQuery = _searchController.text.trim();
              });
              _performSearch();
            },
            onClear: () {
              _searchDebounce?.cancel();
              setState(() {
                _searchQuery = '';
                _searchController.clear();
              });
              _filterRecords();
              _updateStatistics(_filteredRecords, ++_requestVersion);
            },
          ),

          // 采购记录列表 - 添加下拉刷新
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                      onRefresh: () async {
                        await _loadData(showToast: false, forceRefresh: true);
                        if (context.mounted) {
                          SuccessToastManager.show(context, message: '刷新成功');
                        }
                      },
                      child: _buildPurchaseRecordsList(),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPurchaseRecordDialog(context),
        backgroundColor: Theme.of(context).primaryColor,
        heroTag: 'purchase_add_button',
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 构建采购记录列表
  Widget _buildPurchaseRecordsList() {
    final loadErrorMessage = _loadErrorMessage;
    if (loadErrorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text(loadErrorMessage, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _loadData(forceRefresh: true),
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_filteredRecords.isEmpty) {
      return const PurchaseRecordsEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _filteredRecords.length,
      itemBuilder: (context, index) {
        final record = _filteredRecords[index];
        return PurchaseRecordCard(
          record: record,
          projectCount:
              record.id == null ? null : _projectCountsByRecordId[record.id],
          onTap: () => _showPurchaseRecordDetails(context, record),
          onDelete: () => _deletePurchaseRecord(record),
        );
      },
    );
  }

  /// 加载数据
  Future<void> _loadData({
    bool showToast = true,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;
    final requestVersion = ++_requestVersion;

    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });

    try {
      final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);

      // 确保PurchaseProvider已初始化
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      if (!provider.isInitialized) {
        await provider.initializeFromDatabase(dbProvider);
      }

      // 检查MySQL连接状态
      if (dbProvider.dbType == 'mysql') {
        if (!dbProvider.isConnected) {
          throw Exception('数据库连接失败，请检查网络连接');
        }
      }

      AppLogger.info('🔄 开始${forceRefresh ? "强制" : ""}刷新采购记录数据...');

      // 如果不是强制刷新且有缓存，使用缓存
      if (!forceRefresh &&
          provider.hasValidCache &&
          !provider.purchasesNeedRefresh) {
        AppLogger.info('✅ 使用缓存的采购数据，跳过重新加载');
        final records = provider.cachedRecords;
        final filteredRecords =
            _searchQuery.isEmpty
                ? records
                : await provider.searchPurchaseRecords(_searchQuery);
        if (mounted && requestVersion == _requestVersion) {
          setState(() {
            _purchaseRecords = records;
            _filteredRecords = filteredRecords;
            _isLoading = false;
          });
          _updateStatistics(filteredRecords, requestVersion);
        }
        return;
      }

      // 只在强制刷新时清除缓存
      if (forceRefresh) {
        AppLogger.info('🔄 强制刷新：清除缓存');
        provider.clearCache();
      }

      // 直接调用getAllPurchaseRecords获取最新数据
      final records = await provider.getAllPurchaseRecords();
      final filteredRecords =
          _searchQuery.isEmpty
              ? records
              : await provider.searchPurchaseRecords(_searchQuery);

      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _purchaseRecords = records;
          _filteredRecords = filteredRecords;
          _isLoading = false;
        });

        // 异步更新统计信息
        _updateStatistics(filteredRecords, requestVersion);

        AppLogger.info('✅ 采购记录数据刷新完成: ${records.length} 条记录');

        // 只有在showToast为true时才显示刷新成功提示
        if (mounted && showToast) {
          SuccessToastManager.show(context, message: '数据已刷新');
        }
      }
    } catch (e) {
      AppLogger.info('❌ 刷新采购记录数据失败: $e');
      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _isLoading = false;
          _loadErrorMessage = '加载采购记录失败：$e';
        });

        SuccessToastManager.showError(context, message: '刷新数据失败: $e');
      }
    }
  }

  /// 过滤记录
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    setState(() {
      _searchQuery = value.trim();
      _loadErrorMessage = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _performSearch();
    });
  }

  /// 过滤记录
  void _filterRecords() {
    if (_searchQuery.isEmpty) {
      setState(() {
        _filteredRecords = _purchaseRecords;
      });
    } else {
      setState(() {
        _filteredRecords =
            _purchaseRecords.where((record) {
              return (record.supplier?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false) ||
                  (record.notes?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false) ||
                  (record.doctor?.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ??
                      false);
            }).toList();
      });
    }
  }

  Future<void> _performSearch() async {
    if (!mounted) return;
    final requestVersion = ++_requestVersion;

    final query = _searchQuery.trim();
    if (query.isEmpty) {
      _filterRecords();
      _updateStatistics(_filteredRecords, requestVersion);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final records = await provider.searchPurchaseRecords(query);

      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _filteredRecords = records;
        _isLoading = false;
      });
      _updateStatistics(records, requestVersion);
    } catch (e) {
      AppLogger.info('❌ 搜索采购记录失败: $e');
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _isLoading = false;
      });
      SuccessToastManager.showError(context, message: '搜索失败: $e');
    }
  }

  /// 更新统计信息
  Future<void> _updateStatistics(
    List<PurchaseRecord> records,
    int requestVersion,
  ) async {
    if (records.isEmpty) {
      if (!mounted || requestVersion != _requestVersion) return;
      setState(() {
        _statistics = {
          'totalRecords': 0,
          'totalAmount': 0.0,
          'totalQuantity': 0,
          'materialCount': 0,
        };
        _projectCountsByRecordId = {};
      });
      return;
    }

    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);

      // 使用统计服务计算统计信息
      final statistics = await PurchaseStatisticsService.calculateStatistics(
        records,
        (recordId) => provider.getPurchaseItemsByRecordId(recordId),
      );

      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _statistics = statistics.toMap();
          _projectCountsByRecordId = statistics.projectCountsByRecordId;
        });
      }
    } catch (e) {
      AppLogger.info('❌ 更新统计信息失败: $e');

      // 如果完全失败，使用基础统计计算
      final statistics = PurchaseStatisticsService.calculateBasicStatistics(
        records,
      );

      if (mounted && requestVersion == _requestVersion) {
        setState(() {
          _statistics = statistics.toMap();
          _projectCountsByRecordId = {};
        });
      }
    }
  }

  /// 显示添加采购记录对话框
  void _showAddPurchaseRecordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false, // 防止误触关闭
      builder: (context) => const PurchaseRecordDialog(),
    ).then((result) {
      if (result == true) {
        AppLogger.info('🔄 采购记录添加成功，正在刷新数据...');
        // 延迟刷新，确保数据库操作完成
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _loadData(showToast: true); // 添加成功后显示提示
          }
        });
      }
    });
  }

  /// 显示采购记录详情
  void _showPurchaseRecordDetails(BuildContext context, PurchaseRecord record) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PurchaseDetailScreen(record: record),
          ),
        )
        .then((result) {
          // 如果从详情页返回true，说明有数据变更，需要刷新
          if (result == true) {
            AppLogger.info('🔄 从详情页返回，检测到数据变更，正在刷新...');
            // 延迟刷新，确保数据库操作完成
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _loadData(showToast: true); // 有数据变更时显示提示
              }
            });
          }
        });
  }

  /// 删除采购记录
  Future<void> _deletePurchaseRecord(PurchaseRecord record) async {
    // 使用公共的删除确认框组件
    final confirmed = await ModernDeleteDialogManager.showPurchaseDelete(
      context,
      purchaseInfo: '采购记录 #${record.id}',
    );

    if (confirmed) {
      _confirmDeletePurchaseRecord(record);
    }
  }

  /// 确认删除采购记录
  Future<void> _confirmDeletePurchaseRecord(PurchaseRecord record) async {
    final recordId = record.id;
    if (recordId == null) {
      if (mounted) {
        SuccessToastManager.showError(context, message: '记录ID无效');
      }
      return;
    }
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final result = await provider.deletePurchaseRecord(recordId);

      if (mounted) {
        if (result > 0) {
          // 删除成功，立即从本地列表中移除
          setState(() {
            _purchaseRecords.removeWhere((r) => r.id == record.id);
            _filteredRecords =
                _purchaseRecords
                    .where(
                      (item) =>
                          _searchQuery.isEmpty ||
                          (item.supplier?.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ??
                              false) ||
                          (item.notes?.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ??
                              false) ||
                          (item.doctor?.toLowerCase().contains(
                                _searchQuery.toLowerCase(),
                              ) ??
                              false),
                    )
                    .toList();
          });

          // 重新计算统计信息
          _updateStatistics(_filteredRecords, ++_requestVersion);

          // 强制刷新Provider状态
          provider.markPurchasesNeedRefresh();

          // 显示成功提示
          if (mounted) {
            SuccessToastManager.show(context, message: '采购记录删除成功');
          }
        } else {
          if (mounted) {
            SuccessToastManager.showError(context, message: '删除失败：未找到记录');
          }
        }
      }
    } catch (e) {
      AppLogger.info('删除采购记录时出错: $e');
      if (mounted) {
        SuccessToastManager.showError(context, message: '删除失败: $e');
      }
    }
  }

  /// 显示采购统计图表
  Future<void> _showPurchaseStatistics() async {
    final provider = Provider.of<PurchaseProvider>(context, listen: false);
    final records = List<PurchaseRecord>.from(_filteredRecords);
    final statisticsSnapshot = ValueNotifier(
      PurchaseStatisticsSnapshot(
        recordItemsMap: const {},
        failedRecordIds: const [],
        isLoading: records.isNotEmpty,
        loadedRecordCount: 0,
        totalRecordCount: records.length,
      ),
    );
    var isDialogOpen = true;

    try {
      final dialogFuture = showDialog<void>(
        context: context,
        builder:
            (context) => ProgressivePurchaseStatisticsDialog(
              purchaseRecords: records,
              purchaseProvider: provider,
              statisticsListenable: statisticsSnapshot,
            ),
      );

      unawaited(
        _loadPurchaseStatisticsItems(
          provider: provider,
          records: records,
          statisticsSnapshot: statisticsSnapshot,
          isDialogOpen: () => isDialogOpen,
        ),
      );

      await dialogFuture;
    } catch (e) {
      AppLogger.info('显示采购统计图表失败: $e');
      if (mounted) {
        SuccessToastManager.showError(context, message: '加载统计数据失败: $e');
      }
    } finally {
      isDialogOpen = false;
      statisticsSnapshot.dispose();
    }
  }

  /// 后台并发加载采购明细，每完成一条即刷新已打开的图表。
  Future<void> _loadPurchaseStatisticsItems({
    required PurchaseProvider provider,
    required List<PurchaseRecord> records,
    required ValueNotifier<PurchaseStatisticsSnapshot> statisticsSnapshot,
    required bool Function() isDialogOpen,
  }) async {
    final recordItemsMap = <int, List<PurchaseItem>>{};
    final failedRecordIds = <int>[];
    var loadedRecordCount = 0;

    await Future.wait(
      records.map((record) async {
        final recordId = record.id;
        List<PurchaseItem> items = [];
        var loadFailed = recordId == null;

        if (recordId != null) {
          try {
            items = await provider.getPurchaseItemsByRecordId(recordId);
          } catch (e) {
            loadFailed = true;
            AppLogger.info('加载采购记录 $recordId 的项目失败: $e');
          }
        }

        if (!isDialogOpen()) return;

        if (recordId != null) {
          recordItemsMap[recordId] = items;
          if (loadFailed) {
            failedRecordIds.add(recordId);
          }
        }
        loadedRecordCount++;
        statisticsSnapshot.value = PurchaseStatisticsSnapshot(
          recordItemsMap: Map<int, List<PurchaseItem>>.from(recordItemsMap),
          failedRecordIds: List<int>.from(failedRecordIds),
          isLoading: loadedRecordCount < records.length,
          loadedRecordCount: loadedRecordCount,
          totalRecordCount: records.length,
        );
      }),
    );
  }
}

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

class _PurchaseRecordsScreenState extends State<PurchaseRecordsScreen>
    with WidgetsBindingObserver {
  List<PurchaseRecord> _purchaseRecords = [];
  List<PurchaseRecord> _filteredRecords = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _statistics = {};
  late FocusNode _focusNode;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    _loadData(showToast: false); // 初始加载时不显示提示
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.removeListener(_onFocusChange);
    _searchDebounce?.cancel();
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // 当应用从后台恢复时刷新数据
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshData();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ❌ 完全移除自动刷新逻辑，避免任何意外触发
    // 所有数据刷新都由用户明确操作触发（手动刷新、下拉刷新、增删改操作）
  }

  /// 检查并刷新数据（已废弃，不再使用）
  void _checkAndRefreshData() {
    // ❌ 不再使用这个方法，避免不必要的刷新检查
  }

  /// 焦点变化监听（已废弃，不再使用）
  void _onFocusChange() {
    // ❌ 不再监听焦点变化来触发刷新，避免从其他页面返回时误触发
    // 只在明确的操作（增删改）后通过回调触发刷新
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      child: Scaffold(
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
      ),
    );
  }

  /// 构建采购记录列表
  Widget _buildPurchaseRecordsList() {
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

    setState(() {
      _isLoading = true;
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
      if (!forceRefresh && provider.hasCache) {
        AppLogger.info('✅ 使用缓存的采购数据，跳过重新加载');
        final records = provider.cachedRecords;
        final filteredRecords =
            _searchQuery.isEmpty
                ? records
                : await provider.searchPurchaseRecords(_searchQuery);
        if (mounted) {
          setState(() {
            _purchaseRecords = records;
            _filteredRecords = filteredRecords;
            _isLoading = false;
          });
          _updateStatistics();
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

      if (mounted) {
        setState(() {
          _purchaseRecords = records;
          _filteredRecords = filteredRecords;
          _isLoading = false;
        });

        // 异步更新统计信息
        _updateStatistics();

        AppLogger.info('✅ 采购记录数据刷新完成: ${records.length} 条记录');

        // 只有在showToast为true时才显示刷新成功提示
        if (mounted && showToast) {
          SuccessToastManager.show(context, message: '数据已刷新');
        }
      }
    } catch (e) {
      AppLogger.info('❌ 刷新采购记录数据失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
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

    final query = _searchQuery.trim();
    if (query.isEmpty) {
      _filterRecords();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final records = await provider.searchPurchaseRecords(query);

      if (!mounted) return;
      setState(() {
        _filteredRecords = records;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.info('❌ 搜索采购记录失败: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      SuccessToastManager.showError(context, message: '搜索失败: $e');
    }
  }

  /// 更新统计信息
  Future<void> _updateStatistics() async {
    if (_purchaseRecords.isEmpty) {
      setState(() {
        _statistics = {
          'totalRecords': 0,
          'totalAmount': 0.0,
          'totalQuantity': 0,
          'materialCount': 0,
        };
      });
      return;
    }

    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);

      // 使用统计服务计算统计信息
      final statistics = await PurchaseStatisticsService.calculateStatistics(
        _purchaseRecords,
        (recordId) => provider.getPurchaseItemsByRecordId(recordId),
      );

      if (mounted) {
        setState(() {
          _statistics = statistics.toMap();
        });
      }
    } catch (e) {
      AppLogger.info('❌ 更新统计信息失败: $e');

      // 如果完全失败，使用基础统计计算
      final statistics = PurchaseStatisticsService.calculateBasicStatistics(
        _purchaseRecords,
      );

      if (mounted) {
        setState(() {
          _statistics = statistics.toMap();
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
    try {
      final provider = Provider.of<PurchaseProvider>(context, listen: false);
      final result = await provider.deletePurchaseRecord(record.id!);

      if (mounted) {
        if (result > 0) {
          // 删除成功，立即从本地列表中移除
          setState(() {
            _purchaseRecords.removeWhere((r) => r.id == record.id);
            _filterRecords(); // 重新过滤
          });

          // 重新计算统计信息
          _updateStatistics();

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
    try {
      // 显示加载提示
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final provider = Provider.of<PurchaseProvider>(context, listen: false);

      // 准备采购项目数据映射
      final Map<int, List<PurchaseItem>> recordItemsMap = {};

      for (final record in _purchaseRecords) {
        if (record.id != null) {
          try {
            final items = await provider.getPurchaseItemsByRecordId(record.id!);
            recordItemsMap[record.id!] = items;
          } catch (e) {
            AppLogger.info('加载采购记录 ${record.id} 的项目失败: $e');
            recordItemsMap[record.id!] = [];
          }
        }
      }

      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }

      // 显示统计图表对话框
      if (mounted) {
        await showDialog(
          context: context,
          builder:
              (context) => PurchaseStatisticsDialog(
                purchaseRecords: _purchaseRecords,
                recordItemsMap: recordItemsMap,
                purchaseProvider: provider,
              ),
        );
      }
    } catch (e) {
      // 关闭加载提示
      if (mounted) {
        Navigator.of(context).pop();
      }

      AppLogger.info('显示采购统计图表失败: $e');
      if (mounted) {
        SuccessToastManager.showError(context, message: '加载统计数据失败: $e');
      }
    }
  }
}

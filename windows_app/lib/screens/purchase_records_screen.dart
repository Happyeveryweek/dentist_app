import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../providers/purchase_provider.dart';
import '../widgets/mysql_connection_warning.dart';
import '../widgets/dental_icons.dart';
import '../widgets/hoverable_list_card.dart';
import '../widgets/unified_search_field.dart';
import '../widgets/success_toast.dart';
import '../features/purchases/widgets/purchase_statistics_dialog.dart';
import '../features/purchases/widgets/purchase_detail_dialog.dart';
import '../features/purchases/widgets/purchase_form_dialog.dart'
    show showPurchaseFormDialog;
import '../features/purchases/widgets/stat_card.dart';
import '../widgets/pagination_control.dart';
import '../services/purchase_export_service.dart';
import '../utils/log_manager.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class PurchaseRecordsScreen extends StatefulWidget {
  const PurchaseRecordsScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseRecordsScreen> createState() => _PurchaseRecordsScreenState();
}

class _PurchaseRecordsScreenState extends State<PurchaseRecordsScreen> {
  static const _searchDebounceDuration = Duration(milliseconds: 350);

  List<PurchaseRecord> _purchaseRecords = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  late TextEditingController _searchController;
  Timer? _searchDebounceTimer;
  int _loadGeneration = 0;

  // 分页状态
  int _currentPage = 1;
  final int _recordsPerPage = 10;
  int _totalRecords = 0;

  // 统计信息
  int _totalQuantity = 0;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 检查采购提供者中的刷新标志
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    if (purchaseProvider.purchasesNeedRefresh) {
      // 如果采购数据需要刷新，则重新加载
      _loadData(showLoading: false);
      // 重置刷新标志
      purchaseProvider.resetPurchasesRefreshFlag();
    }
  }

  Future<void> _loadData({bool showLoading = true}) async {
    final loadGeneration = ++_loadGeneration;
    final searchQuery = _searchQuery;
    var page = _currentPage;

    if (!mounted) return;
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    } else {
      setState(() {
        _hasError = false;
      });
    }

    try {
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);

      // 先获取总数
      final total = await purchaseProvider.getPurchaseRecordsCount(
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      );
      if (!mounted || loadGeneration != _loadGeneration) return;

      // 获取统计信息（所有记录的汇总）
      final statisticsRecords =
          await _loadStatistics(purchaseProvider, searchQuery);
      if (!mounted || loadGeneration != _loadGeneration) return;

      // 计算总页数并校正当前页
      final computedTotalPages =
          (total / _recordsPerPage).ceil().clamp(1, 1 << 30);
      if (page > computedTotalPages && computedTotalPages > 0) {
        page = computedTotalPages;
      }

      // 再获取当前页
      List<PurchaseRecord> records = await purchaseProvider.getPurchaseRecords(
        page: page,
        pageSize: _recordsPerPage,
        sortBy: 'updated_at',
        sortOrder: 'DESC',
        searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
      );
      if (!mounted || loadGeneration != _loadGeneration) return;

      // 如果存在数据但当前页为空，回退到第一页重试
      if (records.isEmpty && total > 0 && page != 1) {
        page = 1;
        records = await purchaseProvider.getPurchaseRecords(
          page: page,
          pageSize: _recordsPerPage,
          sortBy: 'updated_at',
          sortOrder: 'DESC',
          searchQuery: searchQuery.isNotEmpty ? searchQuery : null,
        );
        if (!mounted || loadGeneration != _loadGeneration) return;
      }

      setState(() {
        _purchaseRecords = records;
        _totalRecords = total;
        _currentPage = page;
        _totalQuantity = statisticsRecords.fold<int>(
          0,
          (sum, record) => sum + record.totalQuantity,
        );
        _totalAmount = statisticsRecords.fold<double>(
          0.0,
          (sum, record) => sum + record.totalAmount,
        );
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted || loadGeneration != _loadGeneration) return;
      setState(() {
        _hasError = true;
        _errorMessage = '加载采购记录失败: $e';
        _isLoading = false;
      });
    }
  }

  // 加载统计信息
  Future<List<PurchaseRecord>> _loadStatistics(
    PurchaseProvider purchaseProvider,
    String searchQuery,
  ) async {
    try {
      return searchQuery.isEmpty
          ? await purchaseProvider.getAllPurchaseRecords()
          : await purchaseProvider.searchPurchaseRecords(searchQuery);
    } catch (e) {
      LogManager.e('PurchaseRecordsScreen', '加载统计信息失败', error: e);
      return [];
    }
  }

  void _applySearch(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
    });
    _searchDebounceTimer?.cancel();
    _loadGeneration++;
    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (mounted) {
        _loadData(showLoading: false);
      }
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _loadGeneration++;
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showPurchaseDetail(PurchaseRecord record) async {
    // 获取该采购记录的所有采购项目
    List<PurchaseItem> purchaseItems = [];
    try {
      final recordId = record.id;
      if (recordId == null) {
        AppToastManager.showError(context, message: '采购记录 ID 为空');
        return;
      }
      final purchaseProvider =
          Provider.of<PurchaseProvider>(context, listen: false);
      purchaseItems =
          await purchaseProvider.getPurchaseItemsByRecordId(recordId);
    } catch (e) {
      LogManager.e('PurchaseRecordsScreen', '加载采购项目失败', error: e);
    }

    if (!mounted) return;
    await PurchaseDetailDialog.show(
      context: context,
      record: record,
      purchaseItems: purchaseItems,
      onEdit: () async {
        Navigator.of(context).pop();
        await showPurchaseFormDialog(
          context: context,
          record: record,
          onSaved: () {
            _loadData(showLoading: false);
            _showPurchaseDetail(record);
          },
        );
      },
      onExport: (record, items) => PurchaseExportService.showExportDialog(
        context,
        record,
        items,
      ),
    );
  }

  Future<void> _deletePurchaseRecord(PurchaseRecord record) async {
    final confirmed = await DeleteConfirmDialogManager.showPurchaseRecordDelete(
      context,
      purchaseInfo:
          '采购记录 "${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}"',
    );

    if (confirmed == true) {
      try {
        final recordId = record.id;
        if (recordId == null) {
          if (!mounted) return;
          AppToastManager.showError(context, message: '无法删除无 ID 的采购记录');
          return;
        }
        if (!mounted) return;
        final purchaseProvider =
            Provider.of<PurchaseProvider>(context, listen: false);
        final success = await purchaseProvider.deletePurchaseRecord(recordId);

        if (success) {
          _loadData(showLoading: false);
          if (!mounted) return;
          AppToastManager.showDelete(context, message: '采购记录删除成功');
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('删除失败'),
              backgroundColor: context.tokens.error,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: context.tokens.error,
          ),
        );
      }
    }
  }

  Widget _buildPurchaseRecordCard(PurchaseRecord record) {
    return HoverableListCard(
      onTap: () => _showPurchaseDetail(record),
      child: Row(
        children: [
          // 采购图标
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.tokens.primaryAccent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              DentalIcons.shoppingCart,
              color: context.colors.onPrimary,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          // 采购信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 第一行：日期和供应商
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.tokens.info.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today,
                              size: 11, color: context.tokens.info),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat('yyyy-MM-dd')
                                .format(record.purchaseDate),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.tokens.info,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (record.supplier != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                context.tokens.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.business,
                                  size: 11, color: context.tokens.warning),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  record.supplier ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: context.tokens.warning,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (record.doctor != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.tokens.primaryAccent
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person,
                                  size: 11,
                                  color: context.tokens.primaryAccent),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  record.doctor ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: context.tokens.primaryAccent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 6),

                // 第二行：数量和金额
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.tokens.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory,
                              size: 11, color: context.tokens.success),
                          const SizedBox(width: 3),
                          Text(
                            '数量: ${record.totalQuantity}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: context.tokens.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.tokens.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.attach_money,
                              size: 11, color: context.tokens.error),
                          const SizedBox(width: 3),
                          Text(
                            '¥${record.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (record.notes != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: context.tokens.inputBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.note,
                                  size: 11, color: context.tokens.textMuted),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  record.notes ?? '',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: context.tokens.textMuted,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // 操作按钮
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactActionButton(
                icon: Icons.visibility,
                color: context.tokens.info,
                tooltip: '查看',
                onPressed: () => _showPurchaseDetail(record),
              ),
              const SizedBox(width: 6),
              _buildCompactActionButton(
                icon: Icons.edit,
                color: context.tokens.warning,
                tooltip: '编辑',
                onPressed: () => showPurchaseFormDialog(
                  context: context,
                  record: record,
                  onSaved: () => _loadData(showLoading: false),
                ),
              ),
              const SizedBox(width: 6),
              _buildCompactActionButton(
                icon: Icons.delete,
                color: context.tokens.error,
                tooltip: '删除',
                onPressed: () => _deletePurchaseRecord(record),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 紧凑型操作按钮
  Widget _buildCompactActionButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: context.tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                DentalIcons.shoppingCart,
                color: colors.onPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '采购管理',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: context.tokens.shellBackground,
        foregroundColor: context.colors.onSurface,
        elevation: 0,
        actions: [
          // 刷新按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: context.tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded, color: colors.onPrimary),
              onPressed: () async {
                await _loadData(showLoading: false);
                if (!context.mounted) return;
                // 使用公用成功提示组件
                AppToastManager.showSuccess(context, message: '数据已刷新');
              },
              tooltip: '刷新数据',
            ),
          ),
          // 添加按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: context.tokens.primaryHeaderGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: colors.onPrimary),
              onPressed: () => showPurchaseFormDialog(
                context: context,
                onSaved: () => _loadData(showLoading: false),
              ),
              tooltip: '添加采购记录',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: context.tokens.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: context.tokens.success.withValues(alpha: 0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.bar_chart_rounded,
                color: context.tokens.success,
              ),
              onPressed: _showPurchaseChart,
              tooltip: '采购图表统计',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // MySQL连接状态检查
          const MySQLConnectionWarning(moduleName: '采购管理'),

          // 搜索栏（白色模块容器包裹）
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.tokens.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.tokens.border),
                boxShadow: [
                  BoxShadow(
                      color: context.tokens.shadow,
                      blurRadius: 12,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: UnifiedSearchField(
                      controller: _searchController,
                      hintText: '输入材料、供应商、医生或备注信息',
                      labelText: '搜索采购记录',
                      prefixIcon: Icons.search_rounded,
                      searchQuery: _searchQuery,
                      onChanged: (value) {
                        _applySearch(value);
                      },
                      onClear: () {
                        _searchController.clear();
                        _applySearch('');
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 统计信息
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: StatCard(
                    icon: Icons.shopping_cart_rounded,
                    label: '采购记录数',
                    value: _totalRecords.toString(),
                    color: context.tokens.primaryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.inventory_rounded,
                    label: '总采购数量',
                    value: _totalQuantity.toString(),
                    color: context.tokens.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.attach_money_rounded,
                    label: '总采购金额',
                    value: '¥${_totalAmount.toStringAsFixed(2)}',
                    color: context.tokens.warning,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 采购记录列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: context.tokens.error),
                              const SizedBox(height: 16),
                              Text(
                                '加载失败',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      color: context.tokens.error,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: context.tokens.error,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('重试'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _purchaseRecords.isEmpty
                        ? Center(
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _searchQuery.isEmpty
                                        ? Icons.shopping_cart_outlined
                                        : Icons.search_off,
                                    size: 64,
                                    color: context.tokens.iconMuted,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty
                                        ? '暂无采购记录'
                                        : '未找到匹配的采购记录',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: context.tokens.textMuted,
                                        ),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '点击"添加采购记录"开始创建您的第一个采购记录',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: context.tokens.textMuted,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => showPurchaseFormDialog(
                                        context: context,
                                        onSaved: () =>
                                            _loadData(showLoading: false),
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('添加采购记录'),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  itemCount: _purchaseRecords.length,
                                  itemBuilder: (context, index) {
                                    return _buildPurchaseRecordCard(
                                        _purchaseRecords[index]);
                                  },
                                ),
                              ),
                              PaginationControl(
                                currentPage: _currentPage,
                                pageSize: _recordsPerPage,
                                totalRecords: _totalRecords,
                                onPageChanged: (page) {
                                  setState(() {
                                    _currentPage = page;
                                  });
                                  _loadData(showLoading: false);
                                },
                              ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPurchaseChart() async {
    final purchaseProvider =
        Provider.of<PurchaseProvider>(context, listen: false);
    final data = await _loadPurchaseStatistics(purchaseProvider);

    // 移除数据为空时的弹窗提示，直接显示统计页面
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 5 / 6,
              height: MediaQuery.of(context).size.height * 5 / 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: PurchaseStatsDialog(
                  purchaseRecords: data.purchaseRecords,
                  purchaseItems: data.purchaseItems,
                  searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
                  onRefresh: () => _loadPurchaseStatistics(
                    purchaseProvider,
                    forceRefresh: true,
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  Future<PurchaseStatisticsData> _loadPurchaseStatistics(
    PurchaseProvider purchaseProvider, {
    bool forceRefresh = false,
  }) async {
    final records = _searchQuery.isNotEmpty
        ? await purchaseProvider.searchPurchaseRecords(
            _searchQuery,
            forceRefresh: forceRefresh,
          )
        : await purchaseProvider.getAllPurchaseRecords(
            forceRefresh: forceRefresh,
          );
    final items = await purchaseProvider.getPurchaseStatisticsItems(
      records.map((record) => record.id).whereType<int>(),
      forceRefresh: forceRefresh,
    );
    return PurchaseStatisticsData(
      purchaseRecords: records,
      purchaseItems: items,
    );
  }
}

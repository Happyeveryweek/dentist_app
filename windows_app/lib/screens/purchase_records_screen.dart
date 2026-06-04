import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../models/material.dart' as material_models;
import '../providers/purchase_provider.dart';
import '../providers/material_provider.dart';
import '../providers/database_provider.dart';
import '../providers/user_provider.dart';
import '../providers/app_state.dart';
import '../widgets/mysql_connection_warning.dart';
import '../theme/app_theme.dart';
import '../widgets/dental_icons.dart';
import '../widgets/unified_search_field.dart';
import '../widgets/modern_date_picker.dart';
import '../features/purchases/widgets/purchase_export_dialog.dart';
import '../widgets/success_toast.dart';
import '../features/purchases/widgets/purchase_statistics_dialog.dart';
import '../features/purchases/widgets/material_selection_dialog.dart';
import '../features/purchases/widgets/purchase_detail_dialog.dart';
import '../features/purchases/widgets/purchase_form_dialog.dart' show showPurchaseFormDialog;
import '../features/purchases/widgets/stat_card.dart';
import '../features/purchases/widgets/pagination_widget.dart';
import '../services/purchase_export_service.dart';

class PurchaseRecordsScreen extends StatefulWidget {
  const PurchaseRecordsScreen({Key? key}) : super(key: key);

  @override
  State<PurchaseRecordsScreen> createState() => _PurchaseRecordsScreenState();
}

class _PurchaseRecordsScreenState extends State<PurchaseRecordsScreen> {
  List<PurchaseRecord> _purchaseRecords = [];
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _searchQuery = '';
  late TextEditingController _searchController;

  // 分页状态
  int _currentPage = 1;
  final int _recordsPerPage = 10;
  int _totalRecords = 0;
  int _totalPages = 0;
  
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
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    if (purchaseProvider.purchasesNeedRefresh) {
      // 如果采购数据需要刷新，则重新加载
      _loadData();
      // 重置刷新标志
      purchaseProvider.resetPurchasesRefreshFlag();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 先获取总数
      final total = await purchaseProvider.getPurchaseRecordsCount(
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      // 获取统计信息（所有记录的汇总）
      await _loadStatistics();
      
      // 计算总页数并校正当前页
      final computedTotalPages = (total / _recordsPerPage).ceil().clamp(1, 1 << 30);
      if (_currentPage > computedTotalPages && computedTotalPages > 0) {
        _currentPage = computedTotalPages;
      }
      
      // 再获取当前页
      List<PurchaseRecord> records = await purchaseProvider.getPurchaseRecords(
        page: _currentPage,
        pageSize: _recordsPerPage,
        sortBy: 'updated_at',
        sortOrder: 'DESC',
        searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      
      // 如果存在数据但当前页为空，回退到第一页重试
      if (records.isEmpty && total > 0 && _currentPage != 1) {
        _currentPage = 1;
        records = await purchaseProvider.getPurchaseRecords(
          page: _currentPage,
          pageSize: _recordsPerPage,
          sortBy: 'updated_at',
          sortOrder: 'DESC',
          searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
        );
      }
      
      setState(() {
        _purchaseRecords = records;
        _totalRecords = total;
        _totalPages = computedTotalPages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = '加载采购记录失败: $e';
        _isLoading = false;
      });
    }
  }

  // 加载统计信息
  Future<void> _loadStatistics() async {
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      
      // 如果没有搜索条件，获取所有记录统计
      if (_searchQuery.isEmpty) {
        final allRecords = await purchaseProvider.getAllPurchaseRecords();
        _totalQuantity = allRecords.fold<int>(0, (sum, record) => sum + record.totalQuantity);
        _totalAmount = allRecords.fold<double>(0.0, (sum, record) => sum + record.totalAmount);
      } else {
        // 有搜索条件时，获取所有记录然后过滤
        final allRecords = await purchaseProvider.getAllPurchaseRecords();
        final filteredRecords = allRecords.where((record) {
          final query = _searchQuery.toLowerCase();
          return (record.supplier?.toLowerCase().contains(query) ?? false) ||
                 (record.doctor?.toLowerCase().contains(query) ?? false) ||
                 (record.notes?.toLowerCase().contains(query) ?? false);
        }).toList();
        
        _totalQuantity = filteredRecords.fold<int>(0, (sum, record) => sum + record.totalQuantity);
        _totalAmount = filteredRecords.fold<double>(0.0, (sum, record) => sum + record.totalAmount);
      }
      
    } catch (e) {
      print('加载统计信息失败: $e');
      _totalQuantity = 0;
      _totalAmount = 0.0;
    }
  }

  void _applySearch(String value) {
    setState(() {
      _searchQuery = value;
      _currentPage = 1;
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showPurchaseDetail(PurchaseRecord record) async {
    // 获取该采购记录的所有采购项目
    List<PurchaseItem> purchaseItems = [];
    try {
      final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
      purchaseItems = await purchaseProvider.getPurchaseItemsByRecordId(record.id!);
      print('成功加载采购项目: ${purchaseItems.length} 项');
    } catch (e) {
      print('加载采购项目失败: $e');
    }

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
            _loadData();
            _showPurchaseDetail(record);
          },
        );
      },
      onExport: (record, items) => _showExportDialog(record, items),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailItemCard(PurchaseItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 材料名称
            Expanded(
              flex: 3,
              child: Text(
                item.materialName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 数量
            Expanded(
              flex: 1,
              child: Text(
                '${item.quantity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 单价
            Expanded(
              flex: 1,
              child: Text(
                '¥${item.unitPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 单位
            Expanded(
              flex: 1,
              child: Text(
                item.formattedUnit,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.purple[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 总价
            Expanded(
              flex: 1,
              child: Text(
                '¥${item.totalPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deletePurchaseRecord(PurchaseRecord record) async {
    final confirmed = await DeleteConfirmDialogManager.showPurchaseRecordDelete(
      context,
      purchaseInfo: '采购记录 "${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}"',
    );

    if (confirmed == true) {
      try {
        final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
        final success = await purchaseProvider.deletePurchaseRecord(record.id!);
        
        if (success) {
          _loadData();
          AppToastManager.showDelete(context, message: '采购记录删除成功');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('删除失败'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('删除失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPurchaseRecordCard(PurchaseRecord record) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPurpleTheme = Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    return _HoverablePurchaseRecordCard(
      onTap: () => _showPurchaseDetail(record),
      isPurpleTheme: isPurpleTheme,
      child: Row(
              children: [
                // 采购图标
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isPurpleTheme ? AppTheme.purpleColor : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    DentalIcons.shoppingCart,
                    color: Colors.white,
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_today, size: 11, color: Colors.blue[700]),
                                const SizedBox(width: 3),
                                Text(
                                  DateFormat('yyyy-MM-dd').format(record.purchaseDate),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (record.supplier != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.business, size: 11, color: Colors.orange[700]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        record.supplier!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.orange[700],
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
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.purple.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person, size: 11, color: Colors.purple[700]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        record.doctor!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.purple[700],
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.inventory, size: 11, color: Colors.green[700]),
                                const SizedBox(width: 3),
                                Text(
                                  '数量: ${record.totalQuantity}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.attach_money, size: 11, color: Colors.red[700]),
                                const SizedBox(width: 3),
                                Text(
                                  '¥${record.totalAmount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (record.notes != null) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.note, size: 11, color: Colors.grey[600]),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        record.notes!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
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
                      color: Colors.blue,
                      tooltip: '查看',
                      onPressed: () => _showPurchaseDetail(record),
                    ),
                    const SizedBox(width: 6),
                    _buildCompactActionButton(
                      icon: Icons.edit,
                      color: Colors.orange,
                      tooltip: '编辑',
                      onPressed: () => showPurchaseFormDialog(
                        context: context,
                        record: record,
                        onSaved: _loadData,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _buildCompactActionButton(
                      icon: Icons.delete,
                      color: Colors.red,
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
    required MaterialColor color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20, color: color[600]),
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: DentalColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                DentalIcons.shoppingCart,
                color: Colors.white,
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
        backgroundColor: Colors.white,
        foregroundColor: DentalColors.onSurface,
        elevation: 0,
        actions: [
          // 刷新按钮
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () async {
                await _loadData();
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
              gradient: DentalColors.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              onPressed: () => showPurchaseFormDialog(
                context: context,
                onSaved: _loadData,
              ),
              tooltip: '添加采购记录',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: DentalColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.success.withOpacity(0.3),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.bar_chart_rounded,
                color: DentalColors.success,
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
              children: [
                Expanded(
                  child: UnifiedSearchField(
                    controller: _searchController,
                    hintText: '输入供应商、医生或备注信息',
                    labelText: '搜索采购记录',
                    prefixIcon: Icons.search_rounded,
                    searchQuery: _searchQuery,
                    onChanged: (value) {
                      _applySearch(value);
                    },
                    onClear: () {
                      setState(() { _searchQuery = ''; _currentPage = 1; });
                      _searchController.clear();
                      _loadData();
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
                    color: DentalColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.inventory_rounded,
                    label: '总采购数量',
                    value: _totalQuantity.toString(),
                    color: DentalColors.success,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    icon: Icons.attach_money_rounded,
                    label: '总采购金额',
                    value: '¥${_totalAmount.toStringAsFixed(2)}',
                    color: DentalColors.warning,
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
                              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                '加载失败',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: Colors.red[300],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _errorMessage,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.red[300],
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
                                    _searchQuery.isEmpty ? Icons.shopping_cart_outlined : Icons.search_off,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _searchQuery.isEmpty ? '暂无采购记录' : '未找到匹配的采购记录',
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  if (_searchQuery.isEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '点击"添加采购记录"开始创建您的第一个采购记录',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => showPurchaseFormDialog(
                                        context: context,
                                        onSaved: _loadData,
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _purchaseRecords.length,
                                  itemBuilder: (context, index) {
                                    return _buildPurchaseRecordCard(_purchaseRecords[index]);
                                  },
                                ),
                              ),
                              PaginationWidget(
                                currentPage: _currentPage,
                                totalPages: _totalPages,
                                recordsPerPage: _recordsPerPage,
                                totalRecords: _totalRecords,
                                onPageChanged: (page) {
                                  setState(() {
                                    _currentPage = page;
                                  });
                                  _loadData();
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
    final purchaseProvider = Provider.of<PurchaseProvider>(context, listen: false);
    
    // 根据搜索条件获取记录
    List<PurchaseRecord> records;
    if (_searchQuery.isNotEmpty) {
      // 如果有搜索条件，获取所有记录并在内存中过滤
      final allRecords = await purchaseProvider.getAllPurchaseRecords();
      final query = _searchQuery.toLowerCase();
      records = allRecords.where((record) {
        return (record.supplier?.toLowerCase().contains(query) ?? false) ||
               (record.doctor?.toLowerCase().contains(query) ?? false) ||
               (record.notes?.toLowerCase().contains(query) ?? false);
      }).toList();
    } else {
      records = await purchaseProvider.getAllPurchaseRecords();
    }

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
                  purchaseRecords: records,
                  purchaseProvider: purchaseProvider,
                  searchQuery: _searchQuery.isNotEmpty ? _searchQuery : null,
                ),
              ),
            ),
          );
        },
      );
    }
  }

  /// 显示导出内容选择对话框
  Future<void> _showExportDialog(PurchaseRecord record, List<PurchaseItem> purchaseItems) async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PurchaseExportDialog(),
    );
    
    // 如果用户选择了导出选项，则执行导出
    if (result != null) {
      _exportPurchaseRecordAsImage(record, purchaseItems, result);
    }
  }

  /// 导出采购记录为图片
  Future<void> _exportPurchaseRecordAsImage(PurchaseRecord record, List<PurchaseItem> purchaseItems, Map<String, bool> exportOptions) async {
    try {
      final exportService = PurchaseExportService();
      // 创建图片数据
      final imageData = await exportService.generatePurchaseRecordImage(record, purchaseItems, exportOptions);

      // 直接保存到下载目录
      final result = await exportService.saveImageToDownloads(imageData);

      if (result != null) {
        // 显示成功提示
        AppToastManager.showSuccess(context, message: '导出成功！图片已保存到下载目录');
      } else {
        // 显示失败提示
        AppToastManager.showError(context, message: '图片保存失败');
      }
    } catch (e) {
      AppToastManager.showError(context, message: '导出失败: $e');
    }
  }
}

// 可悬浮的采购记录卡片组件
class _HoverablePurchaseRecordCard extends StatefulWidget {
  final VoidCallback onTap;
  final bool isPurpleTheme;
  final Widget child;

  const _HoverablePurchaseRecordCard({
    Key? key,
    required this.onTap,
    required this.isPurpleTheme,
    required this.child,
  }) : super(key: key);

  @override
  State<_HoverablePurchaseRecordCard> createState() => _HoverablePurchaseRecordCardState();
}

class _HoverablePurchaseRecordCardState extends State<_HoverablePurchaseRecordCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered 
                ? Color(0xFFE3F2FD)  // 淡蓝色
                : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

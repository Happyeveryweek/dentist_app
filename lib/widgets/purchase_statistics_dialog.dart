import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/purchase_record.dart';
import '../models/purchase_item.dart';
import '../providers/purchase_provider.dart';
import '../utils/datetime_formatter.dart';
import 'modern_date_range_picker.dart';

/// 采购统计图表对话框 - 移动端版本
class PurchaseStatisticsDialog extends StatefulWidget {
  final List<PurchaseRecord> purchaseRecords;
  final Map<int, List<PurchaseItem>> recordItemsMap;
  final PurchaseProvider purchaseProvider;

  const PurchaseStatisticsDialog({
    super.key,
    required this.purchaseRecords,
    required this.recordItemsMap,
    required this.purchaseProvider,
  });

  @override
  State<PurchaseStatisticsDialog> createState() => _PurchaseStatisticsDialogState();
}

class _PurchaseStatisticsDialogState extends State<PurchaseStatisticsDialog>
    with SingleTickerProviderStateMixin {
  DateTime _startDate = DateTimeFormatter.nowLocal().subtract(const Duration(days: 180)); // 初始化为6个月前
  DateTime _endDate = DateTimeFormatter.nowLocal();
  
  late TabController _tabController;
  
  // 预设时间范围
  final List<Map<String, dynamic>> _presets = [
    {'label': '本月', 'key': 'this_month'},
    {'label': '上月', 'key': 'last_month'},
    {'label': '近90天', 'key': '90d'},
    {'label': '今年', 'key': 'this_year'},
    {'label': '全部', 'key': 'all'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setDefaultDateRange();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _setDefaultDateRange() {
    final now = DateTimeFormatter.nowLocal();
    _startDate = DateTime(now.year, now.month - 5, 1); // 默认显示最近6个月（半年）
    _endDate = DateTime(now.year, now.month, now.day); // 设置为今天
  }

  /// 获取最早的采购记录日期
  DateTime _getEarliestPurchaseDate() {
    if (widget.purchaseRecords.isEmpty) {
      final now = DateTimeFormatter.nowLocal();
      return DateTime(now.year, now.month - 11, 1);
    }
    DateTime earliest = DateTime(9999);
    for (final record in widget.purchaseRecords) {
      final date = DateTime(record.purchaseDate.year, record.purchaseDate.month, record.purchaseDate.day);
      if (date.isBefore(earliest)) earliest = date;
    }
    return earliest;
  }

  /// 应用预设时间范围
  void _applyPreset(String preset) {
    final now = DateTimeFormatter.nowLocal();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);
    
    switch (preset) {
      case 'this_month':
        start = DateTime(now.year, now.month, 1);
        break;
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        start = DateTime(lastMonth.year, lastMonth.month, 1);
        end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        break;
      case '90d':
        start = now.subtract(const Duration(days: 89));
        break;
      case 'this_year':
        start = DateTime(now.year, 1, 1);
        break;
      case 'all':
        start = _getEarliestPurchaseDate();
        end = DateTimeFormatter.nowLocal();
        break;
      default:
        start = DateTime(now.year, now.month - 2, 1);
    }
    
    setState(() {
      _startDate = start;
      _endDate = end;
    });
  }

  /// 检查预设是否激活
  bool _isPresetActive(String preset) {
    final now = DateTimeFormatter.nowLocal();
    final s = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final e = DateTime(_endDate.year, _endDate.month, _endDate.day);
    
    switch (preset) {
      case 'this_month':
        final ps = DateTime(now.year, now.month, 1);
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      case 'last_month':
        final lastMonth = DateTime(now.year, now.month - 1);
        final ps = DateTime(lastMonth.year, lastMonth.month, 1);
        final pe = DateTime(lastMonth.year, lastMonth.month + 1, 0);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      case '90d':
        final ps = now.subtract(const Duration(days: 89));
        final psNormalized = DateTime(ps.year, ps.month, ps.day);
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(psNormalized) && e.isAtSameMomentAs(pe);
      case 'this_year':
        final ps = DateTime(now.year, 1, 1);
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      case 'all':
        final ps = _getEarliestPurchaseDate();
        final pe = DateTime(now.year, now.month, now.day);
        return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
      default:
        return false;
    }
  }

  /// 判断记录是否在时间范围内
  bool _isWithinRange(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final e = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) && (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  /// 获取过滤后的记录
  List<PurchaseRecord> _getFilteredRecords() {
    return widget.purchaseRecords.where((record) => _isWithinRange(record.purchaseDate)).toList();
  }

  /// 获取过滤后的采购项目
  List<PurchaseItem> _getFilteredItems() {
    final filteredRecordIds = _getFilteredRecords().map((r) => r.id).toSet();
    final List<PurchaseItem> allItems = [];
    
    for (final recordId in filteredRecordIds) {
      if (recordId != null && widget.recordItemsMap.containsKey(recordId)) {
        allItems.addAll(widget.recordItemsMap[recordId]!);
      }
    }
    
    return allItems;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('采购统计图表'),
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  color: Colors.green[600],
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: const [
                      Tab(text: '概览'),
                      Tab(text: '趋势'),
                      Tab(text: '排行'),
                    ],
                  ),
                ),
              ),
            ),
            body: Column(
              children: [
                // 时间范围选择器
                _buildDateRangeSelector(),
                
                // 内容区域
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildTrendTab(),
                      _buildRankingTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建时间范围选择器
  Widget _buildDateRangeSelector() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前时间范围显示
          Row(
            children: [
              Icon(Icons.date_range, color: Colors.grey[600], size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${DateFormat('yyyy-MM-dd').format(_startDate)} 至 ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              TextButton(
                onPressed: _showCustomDatePicker,
                child: const Text('自定义'),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // 预设时间范围按钮 - 调整为单行显示
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _presets.map((preset) {
                final isActive = _isPresetActive(preset['key']);
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      preset['label'],
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: isActive,
                    onSelected: (_) => _applyPreset(preset['key']),
                    selectedColor: Colors.green.shade100,
                    checkmarkColor: Colors.green.shade600,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.green.shade600 : Colors.grey.shade700,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示自定义日期选择器 - 使用新的美观组件
  Future<void> _showCustomDatePicker() async {
    await showDialog(
      context: context,
      builder: (context) => ModernDateRangePicker(
        initialStartDate: _startDate,
        initialEndDate: _endDate,
        firstDate: DateTime(2020),
        lastDate: DateTimeFormatter.nowLocal().add(const Duration(days: 365)),
        onDateRangeSelected: (startDate, endDate) {
          setState(() {
            _startDate = startDate;
            _endDate = endDate;
          });
        },
      ),
    );
  }

  /// 构建概览标签页
  Widget _buildOverviewTab() {
    final filteredRecords = _getFilteredRecords();
    final filteredItems = _getFilteredItems();
    
    final totalRecords = filteredRecords.length;
    final totalAmount = filteredRecords.fold<double>(0.0, (sum, record) => sum + record.totalAmount);
    final totalQuantity = filteredRecords.fold<int>(0, (sum, record) => sum + record.totalQuantity);
    final uniqueMaterials = filteredItems.map((item) => item.materialName).toSet().length;
    final uniqueSuppliers = filteredRecords.map((record) => record.supplier).where((s) => s != null && s.isNotEmpty).toSet().length;
    final averageAmount = totalRecords > 0 ? totalAmount / totalRecords : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计卡片网格
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildStatCard('记录数', totalRecords.toString(), Icons.receipt_long, Colors.blue),
              _buildStatCard('材料种类', uniqueMaterials.toString(), Icons.category, Colors.purple),
              _buildStatCard('供应商数', uniqueSuppliers.toString(), Icons.business, Colors.green),
              _buildStatCard('总采购量', NumberFormat('#,##0').format(totalQuantity), Icons.inventory_2, Colors.orange),
              _buildStatCard('总采购额', '¥${NumberFormat('#,##0').format(totalAmount)}', Icons.monetization_on, Colors.teal),
              _buildStatCard('平均金额', '¥${NumberFormat('#,##0').format(averageAmount)}', Icons.trending_up, Colors.indigo),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 采购分布图表
          _buildPurchaseDistributionChart(totalAmount, totalQuantity, uniqueMaterials),
        ],
      ),
    );
  }

  /// 构建统计卡片
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 24),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建采购分布图表
  Widget _buildPurchaseDistributionChart(double totalAmount, int totalQuantity, int uniqueMaterials) {
    if (totalAmount <= 0) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '采购概况分析',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // 平均单价分析
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                '平均单价分析',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '总采购金额',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      '¥${NumberFormat('#,##0').format(totalAmount)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '总采购数量',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      NumberFormat('#,##0').format(totalQuantity),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '平均单价',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                      ),
                    ),
                    Text(
                      '¥${totalQuantity > 0 ? (totalAmount / totalQuantity).toStringAsFixed(2) : '0.00'}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // 材料多样性分析
          Row(
            children: [
              Icon(Icons.diversity_3, color: Colors.blue[700], size: 20),
              const SizedBox(width: 8),
              Text(
                '材料多样性',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '材料种类数量',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  '$uniqueMaterials 种',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建趋势标签页
  Widget _buildTrendTab() {
    final filteredRecords = _getFilteredRecords();
    final monthlyData = _calculateMonthlyData(filteredRecords);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildMonthlyTrendChart(monthlyData),
          const SizedBox(height: 24),
          _buildMonthlyStatsTable(monthlyData),
        ],
      ),
    );
  }

  /// 计算月度数据
  Map<String, Map<String, double>> _calculateMonthlyData(List<PurchaseRecord> records) {
    final Map<String, Map<String, double>> monthlyData = {};
    
    // 生成时间范围内的所有月份
    DateTime currentMonth = DateTime(_startDate.year, _startDate.month, 1);
    final endMonth = DateTime(_endDate.year, _endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyData[monthKey] = {
        'amount': 0.0,
        'quantity': 0.0,
        'records': 0.0,
      };
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    // 填充实际数据
    for (final record in records) {
      final monthKey = DateFormat('yyyy-MM').format(record.purchaseDate);
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey]!['amount'] = (monthlyData[monthKey]!['amount'] ?? 0) + record.totalAmount;
        monthlyData[monthKey]!['quantity'] = (monthlyData[monthKey]!['quantity'] ?? 0) + record.totalQuantity;
        monthlyData[monthKey]!['records'] = (monthlyData[monthKey]!['records'] ?? 0) + 1;
      }
    }
    
    return monthlyData;
  }

  /// 构建月度趋势图表
  Widget _buildMonthlyTrendChart(Map<String, Map<String, double>> monthlyData) {
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    if (sortedMonths.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final maxAmount = sortedMonths.fold<double>(0.0, (max, month) {
      final amount = monthlyData[month]!['amount']!;
      return amount > max ? amount : max;
    });

    final maxQuantity = sortedMonths.fold<double>(0.0, (max, month) {
      final quantity = monthlyData[month]!['quantity']!;
      return quantity > max ? quantity : max;
    });

    return Container(
      height: 400,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '月度采购趋势',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // 简化的柱状图表示
          Expanded(
            child: ListView.builder(
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                // 反转索引，使最近的月份显示在最上面
                final reversedIndex = sortedMonths.length - 1 - index;
                final month = sortedMonths[reversedIndex];
                final data = monthlyData[month]!;
                final amount = data['amount']!;
                final quantity = data['quantity']!;
                final records = data['records']!.toInt();
                
                final amountRate = maxAmount > 0 ? amount / maxAmount : 0.0;
                final quantityRate = maxQuantity > 0 ? quantity / maxQuantity : 0.0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            month,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '$records条记录',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // 采购金额条
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              '采购额',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green[700],
                              ),
                            ),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: amountRate,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              '¥${NumberFormat('#,##0').format(amount)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      // 采购数量条
                      Row(
                        children: [
                          SizedBox(
                            width: 60,
                            child: Text(
                              '采购量',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: quantityRate,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              NumberFormat('#,##0').format(quantity),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建月度统计表格
  Widget _buildMonthlyStatsTable(Map<String, Map<String, double>> monthlyData) {
    final sortedMonths = monthlyData.keys.toList()..sort();
    // 反转月份列表，使最近的月份显示在最上面
    final reversedMonths = sortedMonths.reversed.toList();
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '月度统计详情',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('月份')),
                DataColumn(label: Text('记录数')),
                DataColumn(label: Text('采购金额')),
                DataColumn(label: Text('采购数量')),
                DataColumn(label: Text('平均单价')),
              ],
              rows: reversedMonths.map((month) {
                final data = monthlyData[month]!;
                final amount = data['amount']!;
                final quantity = data['quantity']!;
                final records = data['records']!.toInt();
                final avgPrice = quantity > 0 ? amount / quantity : 0.0;
                
                return DataRow(
                  cells: [
                    DataCell(Text(month)),
                    DataCell(Text(records.toString())),
                    DataCell(Text('¥${NumberFormat('#,##0').format(amount)}')),
                    DataCell(Text(NumberFormat('#,##0').format(quantity))),
                    DataCell(Text('¥${avgPrice.toStringAsFixed(2)}')),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建排行标签页
  Widget _buildRankingTab() {
    final topMaterialsByAmount = _calculateTopMaterialsByAmount();
    final topMaterialsByQuantity = _calculateTopMaterialsByQuantity();
    final topSuppliers = _calculateTopSuppliers();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTopMaterialsCard(topMaterialsByAmount, '材料采购排行 (按金额)', '¥', Colors.green),
          const SizedBox(height: 24),
          _buildTopMaterialsCard(topMaterialsByQuantity, '材料采购排行 (按数量)', '', Colors.orange),
          const SizedBox(height: 24),
          _buildTopSuppliersCard(topSuppliers, '供应商排行 (按金额)'),
        ],
      ),
    );
  }

  /// 计算材料排行（按金额）
  List<MapEntry<String, double>> _calculateTopMaterialsByAmount() {
    final Map<String, double> materialTotals = {};
    final filteredItems = _getFilteredItems();
    
    for (final item in filteredItems) {
      materialTotals[item.materialName] = (materialTotals[item.materialName] ?? 0) + item.totalPrice;
    }
    
    final sortedMaterials = materialTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedMaterials.take(20).toList();
  }

  /// 计算材料排行（按数量）
  List<MapEntry<String, int>> _calculateTopMaterialsByQuantity() {
    final Map<String, int> materialTotals = {};
    final filteredItems = _getFilteredItems();
    
    for (final item in filteredItems) {
      materialTotals[item.materialName] = (materialTotals[item.materialName] ?? 0) + item.quantity;
    }
    
    final sortedMaterials = materialTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedMaterials.take(20).toList();
  }

  /// 计算供应商排行
  List<MapEntry<String, double>> _calculateTopSuppliers() {
    final Map<String, double> supplierTotals = {};
    final filteredRecords = _getFilteredRecords();
    
    for (final record in filteredRecords) {
      final supplier = record.supplier ?? '未知供应商';
      supplierTotals[supplier] = (supplierTotals[supplier] ?? 0) + record.totalAmount;
    }
    
    final sortedSuppliers = supplierTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedSuppliers.take(10).toList();
  }

  /// 构建材料排行卡片
  Widget _buildTopMaterialsCard(List<MapEntry<String, num>> topMaterials, String title, String prefix, Color color) {
    final double totalValue = topMaterials.fold(0.0, (sum, item) => sum + item.value);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.inventory, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (topMaterials.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topMaterials.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final material = topMaterials[index];
                final rank = index + 1;
                final percentage = totalValue == 0 ? 0.0 : (material.value / totalValue) * 100;
                
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    material.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                  trailing: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$prefix${prefix == '¥' ? NumberFormat('#,##0').format(material.value) : material.value}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${percentage.toStringAsFixed(1)}%',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 构建供应商排行卡片
  Widget _buildTopSuppliersCard(List<MapEntry<String, double>> topSuppliers, String title) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.business, color: Colors.blue[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),
          if (topSuppliers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topSuppliers.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final supplier = topSuppliers[index];
                final rank = index + 1;
                
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _getRankColor(rank).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          color: _getRankColor(rank),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    supplier.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    '¥${NumberFormat('#,##0').format(supplier.value)}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 获取排名颜色
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber[600]!; // 金色
      case 2:
        return Colors.grey[600]!; // 银色
      case 3:
        return Colors.brown[400]!; // 铜色
      default:
        return Colors.blue[600]!;
    }
  }
}

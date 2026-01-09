import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/financial_record.dart';
import '../models/financial_item.dart';
import '../providers/financial_provider.dart';
import '../utils/datetime_formatter.dart';
import 'modern_date_range_picker.dart';

/// 财务统计图表对话框 - 移动端版本
class FinancialStatisticsDialog extends StatefulWidget {
  final List<FinancialRecord> financialRecords;
  final Map<int, List<FinancialItem>> recordItemsMap;
  final FinancialProvider financialProvider;

  const FinancialStatisticsDialog({
    super.key,
    required this.financialRecords,
    required this.recordItemsMap,
    required this.financialProvider,
  });

  @override
  State<FinancialStatisticsDialog> createState() => _FinancialStatisticsDialogState();
}

class _FinancialStatisticsDialogState extends State<FinancialStatisticsDialog>
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

  /// 获取最早的财务记录日期（基于收费日期，与统计逻辑一致）
  DateTime _getEarliestFinancialDate() {
    if (widget.financialRecords.isEmpty) {
      final now = DateTimeFormatter.nowLocal();
      return DateTime(now.year, now.month - 11, 1);
    }
    
    DateTime earliest = DateTime(9999);
    
    // 遍历所有财务项目，找到最早的收费日期
    for (final record in widget.financialRecords) {
      if (record.id != null && widget.recordItemsMap.containsKey(record.id)) {
        final items = widget.recordItemsMap[record.id]!;
        for (final item in items) {
          final date = DateTime(item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
          if (date.isBefore(earliest)) {
            earliest = date;
          }
        }
      }
    }
    
    // 如果没有找到任何项目，使用记录创建时间作为后备
    if (earliest.year == 9999) {
      for (final record in widget.financialRecords) {
        final date = DateTime(record.createdAt.year, record.createdAt.month, record.createdAt.day);
        if (date.isBefore(earliest)) {
          earliest = date;
        }
      }
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
        start = _getEarliestFinancialDate();
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
        final ps = _getEarliestFinancialDate();
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
  List<FinancialRecord> _getFilteredRecords() {
    return widget.financialRecords.where((record) => _isWithinRange(record.createdAt)).toList();
  }

  /// 获取过滤后的财务项目（按收费日期过滤，与Windows端逻辑一致）
  List<FinancialItem> _getFilteredItems() {
    final List<FinancialItem> allItems = [];
    
    // 获取所有财务项目
    for (final record in widget.financialRecords) {
      if (record.id != null && widget.recordItemsMap.containsKey(record.id)) {
        allItems.addAll(widget.recordItemsMap[record.id]!);
      }
    }
    
    // 按收费日期过滤（与Windows端一致）
    return allItems.where((item) {
      return _isWithinRange(item.chargeDate);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('财务统计图表'),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.blue[600],
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
                    selectedColor: Colors.blue.shade100,
                    checkmarkColor: Colors.blue.shade600,
                    backgroundColor: Colors.grey.shade100,
                    labelStyle: TextStyle(
                      color: isActive ? Colors.blue.shade600 : Colors.grey.shade700,
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
    
    final totalItems = filteredItems.length; // 改为统计财务项目数量，与Windows端保持一致
    final totalCollected = filteredItems.fold<double>(0.0, (sum, item) => sum + item.totalPrice);
    final totalOutstanding = _calculateTotalDebtByPatient(); // 使用按患者维度计算的欠费
    final totalProcessingFee = filteredItems.fold<double>(0.0, (sum, item) => sum + item.processingFee);
    final uniquePatients = _calculateTotalPatients(); // 修改为使用与Windows端一致的计算方法

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 统计卡片容器
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // 第一排：患者数和记录数 (基础统计)
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatCard(
                        '患者数', 
                        uniquePatients.toString(), 
                        Icons.people_outline, 
                        Colors.purple,
                        '人'
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildCompactStatCard(
                        '记录数', 
                        totalItems.toString(), 
                        Icons.receipt_long_outlined, 
                        Colors.blue,
                        '条'
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // 分割线
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.grey.shade200,
                        Colors.grey.shade300,
                        Colors.grey.shade200,
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 第二排：金额统计 (财务数据)
                Row(
                  children: [
                    Expanded(
                      child: _buildCompactStatCard(
                        '已收费', 
                        NumberFormat('#,##0').format(totalCollected), 
                        Icons.payments_outlined, 
                        Colors.green,
                        '¥'
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatCard(
                        '欠费', 
                        NumberFormat('#,##0').format(totalOutstanding), 
                        Icons.money_off_outlined, 
                        Colors.red[700]!,
                        '¥'
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactStatCard(
                        '加工费', 
                        NumberFormat('#,##0').format(totalProcessingFee), 
                        Icons.build_outlined, 
                        Colors.teal,
                        '¥'
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 收费状态图表
          _buildPaymentStatusChart(totalCollected, totalOutstanding),
        ],
      ),
    );
  }

  /// 构建紧凑型统计卡片
  Widget _buildCompactStatCard(String title, String value, IconData icon, Color color, String prefix) {
    return Container(
      height: 80, // 固定高度确保一致性
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 图标和标题行
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  icon, 
                  color: color, 
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          // 数值显示 - 统一布局
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: prefix == '¥'
                ? Text(
                    '$prefix$value',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  )
                : RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: value,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        TextSpan(
                          text: prefix,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建统计卡片（保留原方法以防其他地方使用）
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

  /// 构建收费状态图表
  Widget _buildPaymentStatusChart(double totalCollected, double totalOutstanding) {
    final totalAmount = totalCollected + totalOutstanding;
    
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

    final collectedRate = (totalCollected / totalAmount);
    final outstandingRate = (totalOutstanding / totalAmount);

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
            '收费状态分布',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          
          // 已收费进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '已收费',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.green[700],
                    ),
                  ),
                  Text(
                    '¥${NumberFormat('#,##0').format(totalCollected)} (${(collectedRate * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: collectedRate,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                minHeight: 8,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 欠费进度条
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '欠费',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.red[700],
                    ),
                  ),
                  Text(
                    '¥${NumberFormat('#,##0').format(totalOutstanding)} (${(outstandingRate * 100).toStringAsFixed(1)}%)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: outstandingRate,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red[600]!),
                minHeight: 8,
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // 总计信息
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '总金额',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[700],
                  ),
                ),
                Text(
                  '¥${NumberFormat('#,##0').format(totalAmount)}',
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
    final monthlyProcessingData = _calculateMonthlyProcessingFee();
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: _buildMonthlyTrendChart(monthlyData),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildMonthlyProcessingChart(monthlyProcessingData),
          ),
        ],
      ),
    );
  }

  /// 计算月度数据（与Windows端逻辑完全一致）
  Map<String, Map<String, double>> _calculateMonthlyData(List<FinancialRecord> records) {
    final Map<String, Map<String, double>> monthlyData = {};
    final filteredItems = _getFilteredItems();
    
    // 生成时间范围内的所有月份
    DateTime currentMonth = DateTime(_startDate.year, _startDate.month, 1);
    final endMonth = DateTime(_endDate.year, _endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyData[monthKey] = {
        'receivable': 0.0,
        'collected': 0.0,
        'outstanding': 0.0,
        'records': 0.0,
      };
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    // 填充实际数据（按收费日期分组，与Windows端一致）
    for (final item in filteredItems) {
      final monthKey = DateFormat('yyyy-MM').format(item.chargeDate);
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey]!['receivable'] = (monthlyData[monthKey]!['receivable'] ?? 0) + item.itemPrice;
        monthlyData[monthKey]!['collected'] = (monthlyData[monthKey]!['collected'] ?? 0) + item.totalPrice;
        monthlyData[monthKey]!['outstanding'] = (monthlyData[monthKey]!['outstanding'] ?? 0) + (item.itemPrice - item.totalPrice);
        monthlyData[monthKey]!['records'] = (monthlyData[monthKey]!['records'] ?? 0) + 1;
      }
    }
    
    return monthlyData;
  }

  /// 计算月度加工费数据（与Windows端逻辑一致）
  Map<String, double> _calculateMonthlyProcessingFee() {
    final Map<String, double> monthlyData = {};
    final filteredItems = _getFilteredItems();
    
    // 生成时间范围内的所有月份
    DateTime currentMonth = DateTime(_startDate.year, _startDate.month, 1);
    final endMonth = DateTime(_endDate.year, _endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyData[monthKey] = 0.0;
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    // 填充实际数据
    for (final item in filteredItems) {
      final monthKey = DateFormat('yyyy-MM').format(item.chargeDate);
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + (item.processingFee ?? 0.0);
      }
    }
    
    return monthlyData;
  }

  /// 构建月度收费趋势图表
  Widget _buildMonthlyTrendChart(Map<String, Map<String, double>> monthlyData) {
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    if (sortedMonths.isEmpty) {
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
        child: const Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final maxValue = sortedMonths.fold<double>(0.0, (max, month) {
      final collected = monthlyData[month]!['collected']!;
      return collected > max ? collected : max;
    });

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
            children: [
              Icon(Icons.trending_up, color: Colors.blue[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '月度收费趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 使用紧凑的列表布局
          Expanded(
            child: ListView.builder(
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                // 反转索引，使最近的月份显示在最上面
                final reversedIndex = sortedMonths.length - 1 - index;
                final month = sortedMonths[reversedIndex];
                final data = monthlyData[month]!;
                final collected = data['collected']!;
                final records = data['records']!.toInt();
                
                final collectedRate = maxValue > 0 ? collected / maxValue : 0.0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 左侧：月份标签
                      Container(
                        width: 40,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.blue[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            month.substring(5),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // 中间：进度条和金额
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '收费',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '¥${NumberFormat('#,##0').format(collected)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: collectedRate,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                              minHeight: 3,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 8),
                      
                      // 右侧：记录数
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$records条',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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

  /// 构建月度加工费趋势图表
  Widget _buildMonthlyProcessingChart(Map<String, double> monthlyData) {
    final sortedMonths = monthlyData.keys.toList()..sort();
    
    if (sortedMonths.isEmpty) {
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
        child: const Center(
          child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final maxValue = monthlyData.values.isEmpty ? 1.0 : monthlyData.values.reduce((a, b) => a > b ? a : b);

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
            children: [
              Icon(Icons.build, color: Colors.green[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '加工费月趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 使用紧凑的列表布局
          Expanded(
            child: ListView.builder(
              itemCount: sortedMonths.length,
              itemBuilder: (context, index) {
                // 反转索引，使最近的月份显示在最上面
                final reversedIndex = sortedMonths.length - 1 - index;
                final month = sortedMonths[reversedIndex];
                final amount = monthlyData[month]!;
                
                final amountRate = maxValue > 0 ? amount / maxValue : 0.0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      // 左侧：月份标签
                      Container(
                        width: 40,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.green[400],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Center(
                          child: Text(
                            month.substring(5),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // 中间：进度条和金额
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '加工费',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '¥${NumberFormat('#,##0').format(amount)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: amountRate,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                              minHeight: 3,
                            ),
                          ],
                        ),
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
                DataColumn(label: Text('应收费')),
                DataColumn(label: Text('已收费')),
                DataColumn(label: Text('收费率')),
              ],
              rows: sortedMonths.map((month) {
                final data = monthlyData[month]!;
                final receivable = data['receivable']!;
                final collected = data['collected']!;
                final records = data['records']!.toInt();
                final rate = receivable > 0 ? (collected / receivable) * 100 : 0.0;
                
                return DataRow(
                  cells: [
                    DataCell(Text(month)),
                    DataCell(Text(records.toString())),
                    DataCell(Text('¥${NumberFormat('#,##0').format(receivable)}')),
                    DataCell(Text('¥${NumberFormat('#,##0').format(collected)}')),
                    DataCell(Text('${rate.toStringAsFixed(1)}%')),
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
    final topPatientsByOutstanding = _calculateTopPatientsByOutstanding();
    final topPatientsByAmount = _calculateTopPatientsByAmount();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTopPatientsOutstandingCard(topPatientsByOutstanding, '患者欠费排行 (前20名)'),
          const SizedBox(height: 24),
          _buildTopPatientsCard(topPatientsByAmount, '患者收费排行 (按金额)'),
        ],
      ),
    );
  }

  /// 按患者维度计算总欠费（按截止日期计算累计欠费）
  double _calculateTotalDebtByPatient() {
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};
    
    // 获取所有财务项目
    final List<FinancialItem> allItems = [];
    for (final record in widget.financialRecords) {
      if (record.id != null && widget.recordItemsMap.containsKey(record.id)) {
        allItems.addAll(widget.recordItemsMap[record.id]!);
      }
    }
    
    // 按截止日期过滤：只计算结束日期之前的所有财务项目
    final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final itemsBeforeEndDate = allItems.where((item) {
      final itemDate = DateTime(item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
      return itemDate.isBefore(endDate) || itemDate.isAtSameMomentAs(endDate);
    }).toList();

    // 按患者分组计算应收和实收
    for (final item in itemsBeforeEndDate) {
      // 找到对应的财务记录获取患者ID
      final record = widget.financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTimeFormatter.nowLocal(), updatedAt: DateTimeFormatter.nowLocal()),
      );
      final pid = record.patientId;
      receivableByPatient[pid] = (receivableByPatient[pid] ?? 0) + item.itemPrice;
      receivedByPatient[pid] = (receivedByPatient[pid] ?? 0) + item.totalPrice;
    }

    // 计算每个患者的欠费，只累加正数欠费
    double totalDebt = 0.0;
    receivableByPatient.forEach((pid, receivable) {
      final received = receivedByPatient[pid] ?? 0.0;
      final debt = receivable - received;
      if (debt > 0) {
        totalDebt += debt;
      }
    });

    return totalDebt;
  }

  /// 计算患者欠费排行（按截止日期计算累计欠费）
  List<MapEntry<String, double>> _calculateTopPatientsByOutstanding() {
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};
    
    // 获取所有财务项目
    final List<FinancialItem> allItems = [];
    for (final record in widget.financialRecords) {
      if (record.id != null && widget.recordItemsMap.containsKey(record.id)) {
        allItems.addAll(widget.recordItemsMap[record.id]!);
      }
    }
    
    // 按截止日期过滤：只计算结束日期之前的所有财务项目
    final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final itemsBeforeEndDate = allItems.where((item) {
      final itemDate = DateTime(item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
      return itemDate.isBefore(endDate) || itemDate.isAtSameMomentAs(endDate);
    }).toList();

    // 按患者分组计算应收和实收
    for (final item in itemsBeforeEndDate) {
      final record = widget.financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTimeFormatter.nowLocal(), updatedAt: DateTimeFormatter.nowLocal()),
      );
      final pid = record.patientId;
      receivableByPatient[pid] = (receivableByPatient[pid] ?? 0) + item.itemPrice;
      receivedByPatient[pid] = (receivedByPatient[pid] ?? 0) + item.totalPrice;
    }

    // 计算欠费金额（只包含有欠费的患者）
    final Map<String, double> patientDebts = {};
    receivableByPatient.forEach((pid, receivable) {
      final received = receivedByPatient[pid] ?? 0.0;
      final debt = receivable - received;
      if (debt > 0) {
        // 找到患者姓名
        String patientName = '未知患者';
        for (final record in widget.financialRecords) {
          if (record.patientId == pid) {
            patientName = record.patientName ?? '未知患者';
            break;
          }
        }
        patientDebts[patientName] = debt;
      }
    });

    final sortedDebtors = patientDebts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedDebtors.take(30).toList();
  }

  /// 计算患者排行（按金额，与Windows端逻辑完全一致）
  List<MapEntry<String, double>> _calculateTopPatientsByAmount() {
    final Map<String, double> patientTotals = {};
    final filteredItems = _getFilteredItems();

    // 按患者分组计算总收费金额（与Windows端逻辑一致）
    for (final item in filteredItems) {
      final record = widget.financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTimeFormatter.nowLocal(), updatedAt: DateTimeFormatter.nowLocal()),
      );
      
      // 找到患者姓名
      String patientName = '未知患者';
      if (record.patientName != null && record.patientName!.isNotEmpty) {
        patientName = record.patientName!;
      }
      
      patientTotals[patientName] = (patientTotals[patientName] ?? 0) + item.totalPrice;
    }

    final sortedPatients = patientTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    return sortedPatients.take(20).toList();
  }

  /// 构建患者欠费排行卡片
  Widget _buildTopPatientsOutstandingCard(List<MapEntry<String, double>> topPatients, String title) {
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
                Icon(Icons.money_off, color: Colors.red[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          ),
          if (topPatients.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('暂无欠费患者', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topPatients.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final patient = topPatients[index];
                final rank = index + 1;
                
                return ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        rank.toString(),
                        style: TextStyle(
                          color: Colors.red[600],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  title: Text(
                    patient.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    '¥${NumberFormat('#,##0').format(patient.value)}',
                    style: TextStyle(
                      color: Colors.red[600],
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

  /// 构建患者排行卡片
  Widget _buildTopPatientsCard(List<MapEntry<String, double>> topPatients, String title) {
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
                Icon(Icons.people, color: Colors.blue[600], size: 20),
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
          if (topPatients.isEmpty)
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
              itemCount: topPatients.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final patient = topPatients[index];
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
                    patient.key,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    '¥${NumberFormat('#,##0').format(patient.value)}',
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

  /// 计算总患者数（与Windows端逻辑一致）
  int _calculateTotalPatients() {
    final filteredItems = _getFilteredItems();
    final Set<int> patientIds = {};
    
    for (final item in filteredItems) {
      final record = widget.financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(id: 0, patientId: 0, totalQuantity: 0, createdAt: DateTimeFormatter.nowLocal(), updatedAt: DateTimeFormatter.nowLocal()),
      );
      patientIds.add(record.patientId);
    }
    
    return patientIds.length;
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

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../providers/financial_provider.dart';
import '../../../utils/datetime_formatter.dart';
import '../helpers/financial_payment_method_helper.dart';
import '../../../widgets/modern_date_range_picker.dart';
import '../../../widgets/single_line_amount_text.dart';
import 'compact_stat_card.dart';
import 'payment_status_chart.dart';
import 'monthly_trend_chart.dart';
import 'monthly_processing_chart.dart';

/// 财务统计图表对话框 - 移动端版本
class FinancialStatisticsDialog extends StatefulWidget {
  final List<FinancialRecord> financialRecords;
  final Map<int, List<FinancialItem>> recordItemsMap;
  final FinancialProvider financialProvider;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const FinancialStatisticsDialog({
    super.key,
    required this.financialRecords,
    required this.recordItemsMap,
    required this.financialProvider,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<FinancialStatisticsDialog> createState() =>
      _FinancialStatisticsDialogState();
}

class _FinancialStatisticsDialogState extends State<FinancialStatisticsDialog>
    with SingleTickerProviderStateMixin {
  late DateTime _startDate;
  late DateTime _endDate;

  TabController? _tabController;

  List<FinancialItem> _getItemsForRecord(FinancialRecord record) {
    final id = record.id;
    if (id == null) return [];
    return widget.recordItemsMap[id] ?? [];
  }

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
    _setInitialDateRange();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _setInitialDateRange() {
    final initialStart = widget.initialStartDate;
    final initialEnd = widget.initialEndDate;
    if (initialStart != null && initialEnd != null) {
      _startDate = initialStart;
      _endDate = initialEnd;
      return;
    }
    final now = DateTimeFormatter.nowLocal();
    _startDate = _getEarliestFinancialDate();
    _endDate = DateTime(now.year, now.month, now.day);
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
      final items = _getItemsForRecord(record);
      if (items.isNotEmpty) {
        for (final item in items) {
          final date = DateTime(
            item.chargeDate.year,
            item.chargeDate.month,
            item.chargeDate.day,
          );
          if (date.isBefore(earliest)) {
            earliest = date;
          }
        }
      }
    }

    // 如果没有找到任何项目，使用记录创建时间作为后备
    if (earliest.year == 9999) {
      for (final record in widget.financialRecords) {
        final date = DateTime(
          record.createdAt.year,
          record.createdAt.month,
          record.createdAt.day,
        );
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
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
        (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  /// 获取过滤后的记录
  List<FinancialRecord> _getFilteredRecords() {
    return widget.financialRecords
        .where((record) => _isWithinRange(record.createdAt))
        .toList();
  }

  /// 获取过滤后的财务项目（按收费日期过滤，与Windows端逻辑一致）
  List<FinancialItem> _getFilteredItems() {
    final List<FinancialItem> allItems = [];

    // 获取所有财务项目
    for (final record in widget.financialRecords) {
      allItems.addAll(_getItemsForRecord(record));
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
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: '关闭',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
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
              tabs: const [Tab(text: '概览'), Tab(text: '趋势'), Tab(text: '排行')],
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
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
              children:
                  _presets.map((preset) {
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
                          color:
                              isActive
                                  ? Colors.blue.shade600
                                  : Colors.grey.shade700,
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.normal,
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
      builder:
          (context) => ModernDateRangePicker(
            initialStartDate: _startDate,
            initialEndDate: _endDate,
            firstDate: DateTime(2020),
            lastDate: DateTimeFormatter.nowLocal().add(
              const Duration(days: 365),
            ),
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
    final filteredItems = _getFilteredItems();

    final totalItems = filteredItems.length; // 改为统计财务项目数量，与Windows端保持一致
    final totalCollected = filteredItems.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    final totalOutstanding = _calculateTotalDebtByPatient(); // 使用按患者维度计算的欠费
    final totalProcessingFee = filteredItems.fold<double>(
      0.0,
      (sum, item) => sum + item.processingFee,
    );
    final uniquePatients = _calculateTotalPatients(); // 修改为使用与Windows端一致的计算方法
    final paymentMethodTotals = _calculatePaymentMethodTotals();

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
                      child: CompactStatCard(
                        title: '患者数',
                        value: uniquePatients.toString(),
                        icon: Icons.people_outline,
                        color: Colors.purple,
                        prefix: '人',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CompactStatCard(
                        title: '记录数',
                        value: totalItems.toString(),
                        icon: Icons.receipt_long_outlined,
                        color: Colors.blue,
                        prefix: '条',
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
                      child: CompactStatCard(
                        title: '已收费',
                        value: NumberFormat('#,##0').format(totalCollected),
                        icon: Icons.payments_outlined,
                        color: Colors.green,
                        prefix: '¥',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CompactStatCard(
                        title: '欠费',
                        value: NumberFormat('#,##0').format(totalOutstanding),
                        icon: Icons.money_off_outlined,
                        color: Colors.red.shade700,
                        prefix: '¥',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CompactStatCard(
                        title: '加工费',
                        value: NumberFormat('#,##0').format(totalProcessingFee),
                        icon: Icons.build_outlined,
                        color: Colors.teal,
                        prefix: '¥',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildPaymentMethodSummaryCard(paymentMethodTotals),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 收费状态图表
          PaymentStatusChart(
            totalCollected: totalCollected,
            totalOutstanding: totalOutstanding,
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
          Expanded(child: MonthlyTrendChart(monthlyData: monthlyData)),
          const SizedBox(height: 16),
          Expanded(
            child: MonthlyProcessingChart(monthlyData: monthlyProcessingData),
          ),
        ],
      ),
    );
  }

  /// 计算月度数据（与Windows端逻辑完全一致）
  Map<String, Map<String, double>> _calculateMonthlyData(
    List<FinancialRecord> records,
  ) {
    final Map<String, Map<String, double>> monthlyData = {};
    final filteredItems = _getFilteredItems();

    // 生成时间范围内的所有月份
    DateTime currentMonth = DateTime(_startDate.year, _startDate.month, 1);
    final endMonth = DateTime(_endDate.year, _endDate.month, 1);

    while (currentMonth.isBefore(endMonth) ||
        currentMonth.isAtSameMomentAs(endMonth)) {
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
      final data = monthlyData[monthKey];
      if (data != null) {
        data['receivable'] = (data['receivable'] ?? 0) + item.itemPrice;
        data['collected'] = (data['collected'] ?? 0) + item.totalPrice;
        data['outstanding'] =
            (data['outstanding'] ?? 0) + (item.itemPrice - item.totalPrice);
        data['records'] = (data['records'] ?? 0) + 1;
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

    while (currentMonth.isBefore(endMonth) ||
        currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyData[monthKey] = 0.0;
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    // 填充实际数据
    for (final item in filteredItems) {
      final monthKey = DateFormat('yyyy-MM').format(item.chargeDate);
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] =
            (monthlyData[monthKey] ?? 0) + item.processingFee;
      }
    }

    return monthlyData;
  }

  Map<String, double> _calculatePaymentMethodTotals() {
    final totals = <String, double>{
      FinancialPaymentMethodHelper.displayName('wechat'): 0.0,
      FinancialPaymentMethodHelper.displayName('alipay'): 0.0,
      FinancialPaymentMethodHelper.displayName('cash'): 0.0,
    };

    for (final item in _getFilteredItems()) {
      final methodName = FinancialPaymentMethodHelper.displayName(
        item.paymentMethod,
      );
      if (methodName.isEmpty) {
        continue;
      }
      totals[methodName] = (totals[methodName] ?? 0.0) + item.totalPrice;
    }

    return totals;
  }

  /// 构建排行标签页
  Widget _buildRankingTab() {
    final topPatientsByOutstanding = _calculateTopPatientsByOutstanding();
    final topPatientsByAmount = _calculateTopPatientsByAmount();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildTopPatientsOutstandingCard(
            topPatientsByOutstanding,
            '患者欠费排行 (前20名)',
          ),
          const SizedBox(height: 24),
          _buildTopPatientsCard(topPatientsByAmount, '患者收费排行 (按金额)'),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSummaryCard(
    Map<String, double> paymentMethodTotals,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4ECFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD9B8FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payment_rounded, color: Color(0xFF7B1FA2), size: 20),
              SizedBox(width: 8),
              Text(
                '收费方式统计',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildPaymentMethodItem(
                  method: 'wechat',
                  amount:
                      paymentMethodTotals[FinancialPaymentMethodHelper.displayName(
                        'wechat',
                      )] ??
                      0.0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPaymentMethodItem(
                  method: 'alipay',
                  amount:
                      paymentMethodTotals[FinancialPaymentMethodHelper.displayName(
                        'alipay',
                      )] ??
                      0.0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPaymentMethodItem(
                  method: 'cash',
                  amount:
                      paymentMethodTotals[FinancialPaymentMethodHelper.displayName(
                        'cash',
                      )] ??
                      0.0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem({
    required String method,
    required double amount,
  }) {
    final iconPath = FinancialPaymentMethodHelper.iconAssetPathOrNull(method);
    final label = FinancialPaymentMethodHelper.displayName(method);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (iconPath != null) ...[
                Image.asset(
                  iconPath,
                  width: 16,
                  height: 16,
                  errorBuilder:
                      (_, __, ___) => const Icon(Icons.payment, size: 16),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7B1FA2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleLineAmountText(
            text: '¥${NumberFormat('#,##0').format(amount)}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF7B1FA2),
            ),
            textAlign: TextAlign.center,
            alignment: Alignment.center,
          ),
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
      allItems.addAll(_getItemsForRecord(record));
    }

    // 按截止日期过滤：只计算结束日期之前的所有财务项目
    final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final itemsBeforeEndDate =
        allItems.where((item) {
          final itemDate = DateTime(
            item.chargeDate.year,
            item.chargeDate.month,
            item.chargeDate.day,
          );
          return itemDate.isBefore(endDate) ||
              itemDate.isAtSameMomentAs(endDate);
        }).toList();

    // 按患者分组计算应收和实收
    for (final item in itemsBeforeEndDate) {
      // 找到对应的财务记录获取患者ID
      final record = widget.financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse:
            () => FinancialRecord(
              id: 0,
              patientId: 0,
              totalQuantity: 0,
              createdAt: DateTimeFormatter.nowLocal(),
              updatedAt: DateTimeFormatter.nowLocal(),
            ),
      );
      final pid = record.patientId;
      receivableByPatient[pid] =
          (receivableByPatient[pid] ?? 0) + item.itemPrice;
      receivedByPatient[pid] = (receivedByPatient[pid] ?? 0) + item.totalPrice;
    }

    // 计算每个患者的欠费，只累加正数欠费
    double totalDebt = 0.0;
    for (final entry in receivableByPatient.entries) {
      final pid = entry.key;
      final receivable = entry.value;
      final received = receivedByPatient[pid] ?? 0.0;
      final debt = receivable - received;
      if (debt > 0) {
        totalDebt += debt;
      }
    }

    return totalDebt;
  }

  /// 计算患者欠费排行（按截止日期计算累计欠费）
  List<MapEntry<String, double>> _calculateTopPatientsByOutstanding() {
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};

    // 获取所有财务项目
    final List<FinancialItem> allItems = [];
    for (final record in widget.financialRecords) {
      allItems.addAll(_getItemsForRecord(record));
    }

    // 按截止日期过滤：只计算结束日期之前的所有财务项目
    final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final itemsBeforeEndDate =
        allItems.where((item) {
          final itemDate = DateTime(
            item.chargeDate.year,
            item.chargeDate.month,
            item.chargeDate.day,
          );
          return itemDate.isBefore(endDate) ||
              itemDate.isAtSameMomentAs(endDate);
        }).toList();

    // 按患者分组计算应收和实收
    for (final item in itemsBeforeEndDate) {
      final record = widget.financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse:
            () => FinancialRecord(
              id: 0,
              patientId: 0,
              totalQuantity: 0,
              createdAt: DateTimeFormatter.nowLocal(),
              updatedAt: DateTimeFormatter.nowLocal(),
            ),
      );
      final pid = record.patientId;
      receivableByPatient[pid] =
          (receivableByPatient[pid] ?? 0) + item.itemPrice;
      receivedByPatient[pid] = (receivedByPatient[pid] ?? 0) + item.totalPrice;
    }

    // 计算欠费金额（只包含有欠费的患者）
    final Map<String, double> patientDebts = {};
    for (final entry in receivableByPatient.entries) {
      final pid = entry.key;
      final receivable = entry.value;
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
    }

    final sortedDebtors =
        patientDebts.entries.toList()
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
        orElse:
            () => FinancialRecord(
              id: 0,
              patientId: 0,
              totalQuantity: 0,
              createdAt: DateTimeFormatter.nowLocal(),
              updatedAt: DateTimeFormatter.nowLocal(),
            ),
      );

      // 找到患者姓名
      final name = record.patientName;
      String patientName = name != null && name.isNotEmpty ? name : '未知患者';

      patientTotals[patientName] =
          (patientTotals[patientName] ?? 0) + item.totalPrice;
    }

    final sortedPatients =
        patientTotals.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPatients.take(20).toList();
  }

  /// 构建患者欠费排行卡片
  Widget _buildTopPatientsOutstandingCard(
    List<MapEntry<String, double>> topPatients,
    String title,
  ) {
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
                  trailing: SingleLineAmountText(
                    text: '¥${NumberFormat('#,##0').format(patient.value)}',
                    style: TextStyle(
                      color: Colors.red[600],
                      fontWeight: FontWeight.bold,
                    ),
                    alignment: Alignment.centerRight,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  /// 构建患者排行卡片
  Widget _buildTopPatientsCard(
    List<MapEntry<String, double>> topPatients,
    String title,
  ) {
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
                  trailing: SingleLineAmountText(
                    text: '¥${NumberFormat('#,##0').format(patient.value)}',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontWeight: FontWeight.bold,
                    ),
                    alignment: Alignment.centerRight,
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
        orElse:
            () => FinancialRecord(
              id: 0,
              patientId: 0,
              totalQuantity: 0,
              createdAt: DateTimeFormatter.nowLocal(),
              updatedAt: DateTimeFormatter.nowLocal(),
            ),
      );
      patientIds.add(record.patientId);
    }

    return patientIds.length;
  }

  /// 获取排名颜色
  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600; // 金色
      case 2:
        return Colors.grey.shade600; // 银色
      case 3:
        return Colors.brown.shade400; // 铜色
      default:
        return Colors.blue.shade600;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui' as ui;

import '../../../theme/app_theme.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../providers/purchase_provider.dart';
import '../../../widgets/modern_date_picker.dart';
import '../../../widgets/reusable_date_range_picker.dart';

class PurchaseStatsDialog extends StatefulWidget {
  final List<PurchaseRecord> purchaseRecords;
  final PurchaseProvider purchaseProvider;
  final String? searchQuery;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const PurchaseStatsDialog({
    Key? key,
    required this.purchaseRecords,
    required this.purchaseProvider,
    this.searchQuery,
    this.initialStartDate,
    this.initialEndDate,
  }) : super(key: key);

  @override
  _PurchaseStatsDialogState createState() => _PurchaseStatsDialogState();
}

class _PurchaseStatsDialogState extends State<PurchaseStatsDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  String _activePreset = '6m'; // 记录当前激活的预设按钮
  List<PurchaseItem> _allItems = [];
  bool _isLoading = true;

  // 获取最早的采购日期（用于"全部"时间范围）
  DateTime _getEarliestPurchaseDate() {
    if (widget.purchaseRecords.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - 11, 1);
    }
    DateTime earliest = DateTime(9999);
    for (final r in widget.purchaseRecords) {
      final d = DateTime(r.purchaseDate.year, r.purchaseDate.month, r.purchaseDate.day);
      if (d.isBefore(earliest)) earliest = d;
    }
    return earliest;
  }

  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
    _loadAllPurchaseItems();
  }

  Future<void> _loadAllPurchaseItems() async {
    setState(() => _isLoading = true);
    try {
      final List<PurchaseItem> allItems = [];
      for (final record in widget.purchaseRecords) {
        final items = await widget.purchaseProvider.getPurchaseItemsByRecordId(record.id!);
        allItems.addAll(items);
      }
      if (mounted) {
        setState(() {
          _allItems = allItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading purchase items: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setDefaultDateRange() {
    // 如果父页面传递了日期范围，使用父页面的日期范围
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      _startDate = widget.initialStartDate!;
      _endDate = widget.initialEndDate!;
      _activePreset = ''; // 自定义日期范围
    } else {
      // 默认显示全部数据
      _startDate = _getEarliestPurchaseDate();
      _endDate = DateTime.now();
      _activePreset = 'all'; // 默认是全部
    }
  }

  Future<void> _showCustomDateRangePicker() async {
    final picked = await ReusableDateRangePicker.show(context, start: _startDate, end: _endDate, title: '选择日期范围');
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _activePreset = ''; // 自定义日期范围，清除预设
      });
    }
  }

  bool _isWithinRange(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final e = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) && (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  List<PurchaseRecord> _getFilteredRecords() {
    return widget.purchaseRecords.where((r) => _isWithinRange(r.purchaseDate)).toList();
  }

  List<PurchaseItem> _getFilteredItems() {
    final filteredRecordIds = _getFilteredRecords().map((r) => r.id).toSet();
    return _allItems.where((item) => filteredRecordIds.contains(item.purchaseRecordId)).toList();
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = DateTime(now.year, now.month, now.day);
    if (preset == 'this_month') {
      start = DateTime(now.year, now.month, 1);
    } else if (preset == 'last_month') {
      final lastMonth = DateTime(now.year, now.month - 1);
      start = DateTime(lastMonth.year, lastMonth.month, 1);
      end = DateTime(lastMonth.year, lastMonth.month + 1, 0);
    } else if (preset == '6m') {
      start = DateTime(now.year, now.month - 5, 1);
    } else if (preset == '30d') {
      // 30天：严格的最近30天（包括今天），起始日期是30天前
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
    } else if (preset == '90d') {
      start = now.subtract(const Duration(days: 90));
    } else if (preset == '12m') {
      start = DateTime(now.year, now.month - 11, 1);
    } else if (preset == 'this_year') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == 'last_year') {
      start = DateTime(now.year - 1, 1, 1);
      end = DateTime(now.year - 1, 12, 31);
    } else { // 'all'
      start = _getEarliestPurchaseDate();
      end = DateTime.now();
    }
    if (mounted) {
      setState(() {
        _startDate = start;
        _endDate = end;
        _activePreset = preset; // 记录当前激活的预设
      });
    }
  }
  
  bool _isPresetActive(String preset) {
    // 直接比较是否是当前激活的预设
    return _activePreset == preset;
  }

  bool _isPresetActive_OLD(String preset) {
    final now = DateTime.now();
    final s = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final e = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final pe = DateTime(now.year, now.month, now.day);
    
    if (preset == 'this_month') {
      final ps = DateTime(now.year, now.month, 1);
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
    } else if (preset == 'last_month') {
      final lastMonth = DateTime(now.year, now.month - 1);
      final ps = DateTime(lastMonth.year, lastMonth.month, 1);
      final peLast = DateTime(lastMonth.year, lastMonth.month + 1, 0);
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(peLast);
    } else if (preset == 'this_year') {
      final ps = DateTime(now.year, 1, 1);
      // 今年必须是从1月1日开始，且结束日期是今天
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
    } else if (preset == 'last_year') {
      final ps = DateTime(now.year - 1, 1, 1);
      final peLast = DateTime(now.year - 1, 12, 31);
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(peLast);
    } else if (preset == '30d') {
      // 30天：严格的最近30天，起始日期是30天前
      final ps = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
    } else if (preset == '90d') {
      final ps = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
    } else if (preset == '6m') {
      final ps = DateTime(now.year, now.month - 5, 1);
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
    } else if (preset == '12m') {
      final ps = DateTime(now.year, now.month - 11, 1);
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
    } else if (preset == 'all') {
      final ps = _getEarliestPurchaseDate();
      return s.isAtSameMomentAs(ps) && e.isAtSameMomentAs(pe);
    }
    return false;
  }

  Widget _buildPresetButton(String label, String key) {
    final active = _isPresetActive(key);
    return ElevatedButton(
      onPressed: () => _applyPreset(key),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? AppTheme.primaryColor : Colors.white,
        foregroundColor: active ? Colors.white : Colors.black87,
        elevation: active ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: active ? Colors.transparent : Colors.grey.withOpacity(0.12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, color: active ? Colors.white : Colors.black87)),
    );
  }

  // 计算统计数据
  double _calculateTotalAmount() {
    return _getFilteredRecords().fold(0.0, (sum, record) => sum + record.totalAmount);
  }

  int _calculateTotalQuantity() {
    return _getFilteredRecords().fold(0, (sum, record) => sum + record.totalQuantity);
  }
  
  int _getUniqueMaterialCount() {
    return _getFilteredItems().map((item) => item.materialName).toSet().length;
  }

  Map<String, double> _calculateMonthlyAmount() {
    final Map<String, double> monthlyData = {};
    
    // 生成时间范围内的所有月份
    DateTime currentMonth = DateTime(_startDate.year, _startDate.month, 1);
    final endMonth = DateTime(_endDate.year, _endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyData[monthKey] = 0.0;
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    // 填充实际数据
    for (final record in _getFilteredRecords()) {
      final monthKey = DateFormat('yyyy-MM').format(record.purchaseDate);
      if (monthlyData.containsKey(monthKey)) {
        monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + record.totalAmount;
      }
    }
    
    return monthlyData;
  }

  List<MapEntry<String, double>> _calculateTopMaterialsByAmount() {
    final Map<String, double> materialTotals = {};
    for (final item in _getFilteredItems()) {
      materialTotals[item.materialName] = (materialTotals[item.materialName] ?? 0) + item.totalPrice;
    }
    final sortedMaterials = materialTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedMaterials.take(30).toList();
  }

  List<MapEntry<String, int>> _calculateTopMaterialsByQuantity() {
    final Map<String, int> materialTotals = {};
    for (final item in _getFilteredItems()) {
      materialTotals[item.materialName] = (materialTotals[item.materialName] ?? 0) + item.quantity;
    }
    final sortedMaterials = materialTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedMaterials.take(30).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    final totalAmount = _calculateTotalAmount();
    final totalQuantity = _calculateTotalQuantity();
    final totalRecords = _getFilteredRecords().length;
    final uniqueMaterials = _getUniqueMaterialCount();
    
    final monthlyAmountData = _calculateMonthlyAmount();
    final sortedMonths = monthlyAmountData.keys.toList()..sort();

    final topMaterialsByAmount = _calculateTopMaterialsByAmount();
    final topMaterialsByQuantity = _calculateTopMaterialsByQuantity();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.bar_chart_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text('采购图表统计', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryText,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPresetButton('本月', 'this_month'),
                  const SizedBox(width: 4),
                  _buildPresetButton('上个月', 'last_month'),
                  const SizedBox(width: 4),
                  _buildPresetButton('今年', 'this_year'),
                  const SizedBox(width: 4),
                  _buildPresetButton('上一年', 'last_year'),
                  const SizedBox(width: 4),
                  _buildPresetButton('30天', '30d'),
                  const SizedBox(width: 4),
                  _buildPresetButton('90天', '90d'),
                  const SizedBox(width: 4),
                  _buildPresetButton('半年', '6m'),
                  const SizedBox(width: 4),
                  _buildPresetButton('一年', '12m'),
                  const SizedBox(width: 4),
                  _buildPresetButton('全部', 'all'),
                ],
              ),
            ),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: SizedBox(
                height: 36,
                child: Material(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.withOpacity(0.12)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _showCustomDateRangePicker,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 140, maxWidth: 180),
                            child: Text(
                              '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                              style: const TextStyle(color: Colors.black87, fontSize: 11),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 显示搜索条件提示
                    if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '当前显示搜索结果的统计数据：${widget.searchQuery}',
                                style: TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    _buildSummaryCards(totalRecords, totalAmount, totalQuantity, uniqueMaterials),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 1,
                            child: _buildChartCard(
                              '月度采购金额趋势',
                              _buildMonthlyAmountChart(sortedMonths, monthlyAmountData),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTopMaterialsCard(topMaterialsByAmount, '采购材料排行 (按金额)', '¥'),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildTopMaterialsCard(topMaterialsByQuantity, '采购材料排行 (按数量)', ''),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSummaryCards(int totalRecords, double totalAmount, int totalQuantity, int uniqueMaterials) {
    return Row(
      children: [
        Expanded(child: _buildSummaryCard('总记录数', totalRecords.toString(), Icons.receipt_long, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('总采购额', '¥${totalAmount.toStringAsFixed(2)}', Icons.monetization_on, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('总采购量', totalQuantity.toString(), Icons.inventory_2, Colors.orange)),
        const SizedBox(width: 16),
        Expanded(child: _buildSummaryCard('材料种类', uniqueMaterials.toString(), Icons.category, Colors.purple)),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500)),
              Icon(icon, color: color, size: 24),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(child: chart),
        ],
      ),
    );
  }

  Widget _buildMonthlyAmountChart(List<String> sortedMonths, Map<String, double> monthlyAmountData) {
    if (sortedMonths.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxValue = monthlyAmountData.values.isEmpty ? 1 : monthlyAmountData.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue * 1.2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool enableScroll = sortedMonths.length > 6;
        // 动态计算宽度：如果启用滚动，每个数据点分配一定宽度（例如60），且总宽度不小于容器宽度
        // 额外增加 40 宽度防止最后一个月被遮挡
        // 动态计算宽度：增加每个点的宽度和额外缓冲，防止右侧标签被遮挡
        final double chartWidth = enableScroll 
            ? (sortedMonths.length * 70.0 + 60.0).clamp(constraints.maxWidth, double.infinity)
            : constraints.maxWidth;

        // 计算刻度间隔
        final double interval = maxY / 4 == 0 ? 1.0 : maxY / 4;

        // 定义左侧标题配置（用于保持一致性）
        SideTitles leftTitlesConfig() => SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const Text('¥0', style: TextStyle(fontSize: 10, color: Colors.black54));
            return Text('¥${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.black54));
          },
        );

        // 定义底部标题配置
        SideTitles bottomTitlesConfig({bool showLabels = true}) => SideTitles(
          showTitles: true,
          reservedSize: 22,
          interval: 1,
          getTitlesWidget: (value, meta) {
            if (!showLabels) return const Text('');
            if (value % 1 != 0) return const Text('');
            final index = value.toInt();
            if (index >= 0 && index < sortedMonths.length) {
              final month = sortedMonths[index];
              if (!enableScroll && 
                  sortedMonths.length > 8 && 
                  index % 2 != 0 && 
                  index != sortedMonths.length - 1) {
                return const Text('');
              }
              return Text(month.substring(5), style: const TextStyle(fontSize: 10));
            }
            return const Text('');
          },
        );

        // 主图表配置
        LineChartData mainChartData(bool showLeftTitles) => LineChartData(
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.white,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final index = spot.x.toInt();
                  if (index >= 0 && index < sortedMonths.length) {
                    final month = sortedMonths[index];
                    final amount = monthlyAmountData[month] ?? 0;
                    return LineTooltipItem(
                      '$month\n¥${amount.toStringAsFixed(2)}',
                      const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
                    );
                  }
                  return const LineTooltipItem('', TextStyle());
                }).toList();
              },
              fitInsideHorizontally: true,
              fitInsideVertically: true,
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: interval, // 显式设置水平网格间隔
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: bottomTitlesConfig(showLabels: true)),
            leftTitles: AxisTitles(sideTitles: showLeftTitles ? leftTitlesConfig() : SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 20)), // 增加顶部预留空间防止数值遮挡
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 30, // 增加右侧预留空间，防止最后一个标签被裁剪
                getTitlesWidget: (value, meta) => const Text(''),
              ),
            ),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 1)),
          minX: 0,
          maxX: sortedMonths.length - 1,
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: sortedMonths.asMap().entries.map((entry) {
                final amount = monthlyAmountData[entry.value] ?? 0;
                return FlSpot(entry.key.toDouble(), amount);
              }).toList(),
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: AppTheme.primaryColor,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.3),
                    AppTheme.primaryColor.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ],
        );

        if (enableScroll) {
          final ScrollController scrollController = ScrollController();
          return Row(
            children: [
              // 固定左侧Y轴
              SizedBox(
                width: 40, // 与 leftTitles reservedSize 一致
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(enabled: false),
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: bottomTitlesConfig(showLabels: false)), // 占位保持对齐
                      leftTitles: AxisTitles(sideTitles: leftTitlesConfig()),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 20)), // 保持对齐
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 0, // 不重要
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [], // 空数据
                  ),
                ),
              ),
              // 可滚动区域
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      child: LineChart(mainChartData(false)), // 不显示左侧标题
                    ),
                  ),
                ),
              ),
            ],
          );
        } else {
          return LineChart(mainChartData(true));
        }
      },
    );
  }

  Widget _buildTopMaterialsCard(List<MapEntry<String, num>> topMaterials, String title, String prefix) {
    final double totalValue = topMaterials.fold(0.0, (sum, item) => sum + item.value);
    
    // 根据标题判断是金额排行还是数量排行，使用不同的颜色
    final bool isAmountRanking = title.contains('金额');
    final Color primaryColor = isAmountRanking ? Colors.green : Colors.orange;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.inventory, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: primaryColor)),
              ],
            ),
            const Divider(height: 24),
            Expanded(
              child: topMaterials.isEmpty
                  ? const Center(child: Text('暂无数据', style: TextStyle(color: Colors.grey)))
                  : ListView(
                      children: topMaterials.map((material) {
                        final percentage = totalValue == 0 ? 0.0 : (material.value / totalValue) * 100;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: primaryColor.withOpacity(0.1),
                                    child: Text(
                                      '${topMaterials.indexOf(material) + 1}',
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      material.key,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '$prefix${prefix == '¥' ? material.value.toStringAsFixed(2) : material.value}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primaryColor),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

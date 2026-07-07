import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'dart:ui' as ui; // 导入 dart:ui
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../../../models/patient.dart';
import '../../../widgets/reusable_date_range_picker.dart';
import '../helpers/financial_payment_method_helper.dart';
import '../services/financial_statistics_service.dart';

class FinancialStatsDialog extends StatefulWidget {
  final List<FinancialRecord> financialRecords;
  final List<FinancialItem> financialItems;
  final List<Patient> patients;
  final String? searchQuery;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? chargeItemQuery;
  final Future<FinancialStatisticsData> Function()? onRefresh;

  const FinancialStatsDialog({
    Key? key,
    required this.financialRecords,
    required this.financialItems,
    required this.patients,
    this.searchQuery,
    this.initialStartDate,
    this.initialEndDate,
    this.chargeItemQuery,
    this.onRefresh,
  }) : super(key: key);

  @override
  FinancialStatsDialogState createState() => FinancialStatsDialogState();
}

class FinancialStatsDialogState extends State<FinancialStatsDialog> {
  late List<FinancialRecord> _financialRecords;
  late List<FinancialItem> _financialItems;
  late List<Patient> _patients;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  String _activePreset = '6m';
  bool _isRefreshing = false;
  bool _showFinancialAmounts = false;

  // 获取最早的收费日期（用于“全部”时间范围）
  DateTime _getEarliestFinancialDate() {
    if (_financialItems.isEmpty) {
      // 无数据时回退到近12个月的开始
      final now = DateTime.now();
      return DateTime(now.year, now.month - 11, 1);
    }
    DateTime earliest = DateTime(9999);
    for (final item in _financialItems) {
      final d = DateTime(
          item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
      if (d.isBefore(earliest)) earliest = d;
    }
    return earliest;
  }

  @override
  void initState() {
    super.initState();
    _financialRecords = List<FinancialRecord>.from(widget.financialRecords);
    _financialItems = List<FinancialItem>.from(widget.financialItems);
    _patients = List<Patient>.from(widget.patients);
    _setDefaultDateRange();
  }

  void _setDefaultDateRange() {
    final startDate = widget.initialStartDate;
    final endDate = widget.initialEndDate;
    // 如果父页面传递了日期范围，使用父页面的日期范围
    if (startDate != null && endDate != null) {
      _startDate = startDate;
      _endDate = endDate;
      _activePreset = ''; // 自定义日期范围
    } else {
      // 默认显示全部数据
      _startDate = _getEarliestFinancialDate();
      _endDate = DateTime.now();
      _activePreset = 'all'; // 默认是全部
    }
  }

  Future<void> _showCustomDateRangePicker() async {
    final picked = await ReusableDateRangePicker.show(
      context,
      start: _startDate,
      end: _endDate,
      title: '选择日期范围',
    );
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
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) &&
        (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  List<FinancialItem> _getFilteredItems() {
    return _financialItems.where((item) {
      return _isWithinRange(item.chargeDate);
    }).toList();
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
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == '30d') {
      // 30天：严格的最近30天（包括今天），起始日期是30天前
      start = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 30));
    } else if (preset == '90d') {
      start = now.subtract(const Duration(days: 90));
    } else if (preset == '12m') {
      start = DateTime(now.year, now.month - 11, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == 'this_year') {
      start = DateTime(now.year, 1, 1);
      end = DateTime(now.year, now.month, now.day);
    } else if (preset == 'last_year') {
      start = DateTime(now.year - 1, 1, 1);
      end = DateTime(now.year - 1, 12, 31);
    } else {
      // 'all'
      start = _getEarliestFinancialDate();
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
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + item.processingFee;
    }

    return monthlyData;
  }

  Map<String, double> _calculateMonthlyRevenue() {
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
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + item.totalPrice;
    }

    return monthlyData;
  }

  Map<String, double> _calculatePaymentMethodTotals() {
    final totals = <String, double>{
      '微信': 0.0,
      '支付宝': 0.0,
      '现金': 0.0,
    };

    for (final item in _getFilteredItems()) {
      final methodKey = _resolvePaymentMethodKey(item.paymentMethod);
      if (methodKey == null) continue;
      final methodName = _paymentMethodDisplayName(methodKey);
      totals[methodName] = (totals[methodName] ?? 0.0) + item.totalPrice;
    }

    return totals;
  }

  String? _resolvePaymentMethodKey(String? value) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return null;
    if (normalized.contains('wechat') || normalized.contains('微信')) {
      return 'wechat';
    }
    if (normalized.contains('alipay') || normalized.contains('支付宝')) {
      return 'alipay';
    }
    if (normalized.contains('cash') || normalized.contains('现金')) {
      return 'cash';
    }
    switch (normalized) {
      default:
        return null;
    }
  }

  String _paymentMethodDisplayName(String key) {
    switch (key) {
      case 'alipay':
        return '支付宝';
      case 'cash':
        return '现金';
      case 'wechat':
      default:
        return '微信';
    }
  }

  double _calculateTotalProcessingFee() {
    return _getFilteredItems().fold(0, (sum, item) => sum + item.processingFee);
  }

  int _calculateTotalItems() {
    return _getFilteredItems().length;
  }

  int _calculateTotalPatients() {
    final filteredItems = _getFilteredItems();
    final Set<int> patientIds = {};

    for (final item in filteredItems) {
      final record = _financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(
            id: 0,
            patientId: 0,
            totalQuantity: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()),
      );
      patientIds.add(record.patientId);
    }

    return patientIds.length;
  }

  double _calculateTotalReceived() {
    return _getFilteredItems().fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  double _calculateTotalDebt() {
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};

    // 按截止日期过滤：只计算结束日期之前的所有财务项目
    final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final itemsBeforeEndDate = _financialItems.where((item) {
      final itemDate = DateTime(
          item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
      return itemDate.isBefore(endDate) || itemDate.isAtSameMomentAs(endDate);
    }).toList();

    // 按患者分组计算应收和实收
    for (final item in itemsBeforeEndDate) {
      final record = _financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(
            id: 0,
            patientId: 0,
            totalQuantity: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()),
      );
      final pid = record.patientId;
      receivableByPatient[pid] =
          (receivableByPatient[pid] ?? 0) + item.itemPrice;
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

  List<MapEntry<String, double>> _calculateTopPatients() {
    final Map<String, double> patientTotals = {};
    final filteredItems = _getFilteredItems();

    for (final item in filteredItems) {
      final record = _financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(
            id: 0,
            patientId: 0,
            totalQuantity: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()),
      );
      final patient = _patients.firstWhere(
        (p) => p.id == record.patientId,
        orElse: () => Patient(
            id: 0,
            name: '未知患者',
            age: 0,
            gender: '未知',
            phone: '',
            firstVisitDate: DateTime.now()),
      );
      patientTotals[patient.name] =
          (patientTotals[patient.name] ?? 0) + item.totalPrice;
    }

    final sortedPatients = patientTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedPatients.take(20).toList();
  }

  double _calculatePatientPercentage(double patientTotal, double grandTotal) {
    if (grandTotal == 0) return 0.0;
    return (patientTotal / grandTotal) * 100;
  }

  List<MapEntry<String, double>> _calculateTopDebtors() {
    final Map<int, double> receivableByPatient = {};
    final Map<int, double> receivedByPatient = {};

    // 按截止日期过滤：只计算结束日期之前的所有财务项目
    final endDate = DateTime(_endDate.year, _endDate.month, _endDate.day);
    final itemsBeforeEndDate = _financialItems.where((item) {
      final itemDate = DateTime(
          item.chargeDate.year, item.chargeDate.month, item.chargeDate.day);
      return itemDate.isBefore(endDate) || itemDate.isAtSameMomentAs(endDate);
    }).toList();

    for (final item in itemsBeforeEndDate) {
      final record = _financialRecords.firstWhere(
        (r) => r.id == item.financialRecordId,
        orElse: () => FinancialRecord(
            id: 0,
            patientId: 0,
            totalQuantity: 0,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now()),
      );
      final pid = record.patientId;
      // 患者维度应收= item_price 累加
      receivableByPatient[pid] =
          (receivableByPatient[pid] ?? 0) + item.itemPrice;
      receivedByPatient[pid] = (receivedByPatient[pid] ?? 0) + item.totalPrice;
    }

    final Map<String, double> patientDebts = {};
    receivableByPatient.forEach((pid, receivable) {
      final received = receivedByPatient[pid] ?? 0.0;
      final debt = receivable - received;
      if (debt > 0) {
        final patient = _patients.firstWhere(
          (p) => p.id == pid,
          orElse: () => Patient(
              id: 0,
              name: '未知患者',
              age: 0,
              gender: '未知',
              phone: '',
              firstVisitDate: DateTime.now()),
        );
        patientDebts[patient.name] = debt;
      }
    });

    final sortedDebtors = patientDebts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedDebtors.take(30).toList();
  }

  bool _isPresetActive(String preset) {
    // 直接比较是否是当前激活的预设
    return _activePreset == preset;
  }

  Widget _buildPresetButton(String label, String key) {
    final tokens = context.tokens;
    final colors = context.colors;
    final active = _isPresetActive(key);
    return ElevatedButton(
      onPressed: () => _applyPreset(key),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? tokens.primaryAccent : tokens.cardBackground,
        foregroundColor: active ? tokens.cardBackground : colors.onSurface,
        elevation: active ? 3 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(
            color: active
                ? Colors.transparent
                : tokens.textMuted.withValues(alpha: 0.12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 13, color: active ? tokens.cardBackground : colors.onSurface)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    final totalPatients = _calculateTotalPatients();
    final totalItems = _calculateTotalItems();
    final totalReceived = _calculateTotalReceived();
    final paymentMethodTotals = _calculatePaymentMethodTotals();
    final totalDebt = _calculateTotalDebt();
    final totalProcessingFee = _calculateTotalProcessingFee();
    final monthlyRevenueData = _calculateMonthlyRevenue();
    final monthlyProcessingData = _calculateMonthlyProcessingFee();
    final topPatients = _calculateTopPatients();
    final topDebtors = _calculateTopDebtors();
    final searchQuery = widget.searchQuery;
    final chargeItemQuery = widget.chargeItemQuery;

    final sortedRevenueMonths = monthlyRevenueData.keys.toList()..sort();
    final sortedProcessingMonths = monthlyProcessingData.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: tokens.primaryHeaderGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.bar_chart_rounded,
                color: tokens.cardBackground,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '收费图表统计',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        backgroundColor: tokens.cardBackground,
        foregroundColor: colors.onSurface,
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
                color: tokens.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: tokens.textMuted.withValues(alpha: 0.12)),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await _showCustomDateRangePicker();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: tokens.textMuted),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                              minWidth: 140, maxWidth: 180),
                          child: Text(
                            '${DateFormat('yyyy-MM-dd').format(_startDate)} - ${DateFormat('yyyy-MM-dd').format(_endDate)}',
                            style: TextStyle(
                                color: colors.onSurface, fontSize: 11),
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
            tooltip: _showFinancialAmounts ? '隐藏金额' : '显示金额',
            onPressed: () {
              setState(() {
                _showFinancialAmounts = !_showFinancialAmounts;
              });
            },
            icon: Icon(
              _showFinancialAmounts ? Icons.visibility_off : Icons.visibility,
            ),
          ),
          IconButton(
            tooltip: '刷新',
            onPressed: _isRefreshing ? null : _refreshData,
            icon: _isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 显示搜索条件提示
            if ((searchQuery != null && searchQuery.isNotEmpty) ||
                (chargeItemQuery != null && chargeItemQuery.isNotEmpty))
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: tokens.infoContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: tokens.info),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: tokens.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前显示搜索结果的统计数据：${[
                          if (searchQuery != null && searchQuery.isNotEmpty)
                            '患者搜索"$searchQuery"',
                          if (chargeItemQuery != null &&
                              chargeItemQuery.isNotEmpty)
                            '收费项目"$chargeItemQuery"',
                        ].join('、')}',
                        style: TextStyle(
                            color: tokens.info,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            _buildSummaryCards(
              totalPatients,
              totalItems,
              totalReceived,
              totalDebt,
              totalProcessingFee,
              paymentMethodTotals,
            ),
            const SizedBox(height: 20),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalW = constraints.maxWidth;
                  const gap = 12.0;
                  // 固定切分：在原基础上将右侧整体再增加 100px（两个榜单各 +50px）
                  double rightW = (totalW / 3) < 520 ? 520 : (totalW / 3);
                  rightW += 100; // 两个榜单各 +50px
                  if (rightW > totalW - 300) {
                    rightW = totalW - 300; // 左侧至少保留 300px
                  }
                  final double leftW =
                      totalW - rightW - gap; // 折线图宽度相应增加 100px（相对上次）

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧：两个折线图上下排列
                      SizedBox(
                        width: leftW,
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildChartCard(
                                '月度收费趋势',
                                _buildMonthlyRevenueChart(
                                    sortedRevenueMonths, monthlyRevenueData),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildChartCard(
                                '加工费月趋势',
                                _buildMonthlyProcessingChart(
                                    sortedProcessingMonths,
                                    monthlyProcessingData),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: gap),
                      // 右侧：两个排行左右并排
                      SizedBox(
                        width: rightW,
                        child: Row(
                          children: [
                            Expanded(child: _buildTopPatientsCard(topPatients)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTopDebtorsCard(topDebtors)),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyRevenueChart(
      List<String> sortedMonths, Map<String, double> monthlyData) {
    final tokens = context.tokens;
    final colors = context.colors;
    if (sortedMonths.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxValue = monthlyData.values.isEmpty
        ? 1
        : monthlyData.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue * 1.2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool enableScroll = sortedMonths.length > 12;
        // 动态计算宽度：增加每个点的宽度和额外缓冲，防止右侧标签被遮挡
        final double chartWidth = enableScroll
            ? (sortedMonths.length * 70.0 + 60.0)
                .clamp(constraints.maxWidth, double.infinity)
            : constraints.maxWidth;

        // 计算刻度间隔
        final double interval = maxY / 4 == 0 ? 1.0 : maxY / 4;

        // 定义左侧标题配置
        SideTitles leftTitlesConfig() => SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return Text('¥0',
                      style: TextStyle(fontSize: 10, color: tokens.textMuted));
                }
                return Text('¥${value.toInt()}',
                    style:
                        TextStyle(fontSize: 10, color: tokens.textMuted));
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
                  // 如果启用滚动，显示所有标签；否则适度稀疏
                  // 始终显示最后一个标签
                  if (!enableScroll &&
                      sortedMonths.length > 8 &&
                      index % 2 != 0 &&
                      index != sortedMonths.length - 1) {
                    return const Text('');
                  }
                  return Text(month.substring(5),
                      style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            );

        // 主图表配置
        LineChartData mainChartData(bool showLeftTitles) => LineChartData(
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => tokens.cardBackground,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      if (index >= 0 && index < sortedMonths.length) {
                        final month = sortedMonths[index];
                        final amount = monthlyData[month] ?? 0;
                        return LineTooltipItem(
                          '$month\n¥${amount.toStringAsFixed(0)}',
                          TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold),
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
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: tokens.divider, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                    sideTitles: bottomTitlesConfig(showLabels: true)),
                leftTitles: AxisTitles(
                    sideTitles: showLeftTitles
                        ? leftTitlesConfig()
                        : const SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: false, reservedSize: 20)), // 增加顶部预留空间
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30, // 增加右侧预留空间，防止最后一个标签被裁剪
                    getTitlesWidget: (value, meta) => const Text(''),
                  ),
                ),
              ),
              borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: tokens.border, width: 1)),
              minX: 0,
              maxX: sortedMonths.length - 1,
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: sortedMonths.asMap().entries.map((entry) {
                    final amount = monthlyData[entry.value] ?? 0;
                    return FlSpot(entry.key.toDouble(), amount);
                  }).toList(),
                  isCurved: true,
                  color: tokens.primaryAccent,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: tokens.primaryAccent,
                      strokeWidth: 2,
                      strokeColor: tokens.cardBackground,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tokens.primaryAccent.withValues(alpha: 0.3),
                        tokens.primaryAccent.withValues(alpha: 0.1),
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
                width: 40,
                child: LineChart(
                  LineChartData(
                    lineTouchData: const LineTouchData(enabled: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                          sideTitles: bottomTitlesConfig(showLabels: false)),
                      leftTitles: AxisTitles(sideTitles: leftTitlesConfig()),
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false, reservedSize: 20)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 0,
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [],
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
                      child: LineChart(mainChartData(false)),
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

  Widget _buildMonthlyProcessingChart(
      List<String> sortedMonths, Map<String, double> monthlyData) {
    final tokens = context.tokens;
    final colors = context.colors;
    if (sortedMonths.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxValue = monthlyData.values.isEmpty
        ? 1
        : monthlyData.values.reduce((a, b) => a > b ? a : b);
    final maxY = maxValue * 1.2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool enableScroll = sortedMonths.length > 12;
        final double chartWidth = enableScroll
            ? (sortedMonths.length * 70.0 + 60.0)
                .clamp(constraints.maxWidth, double.infinity)
            : constraints.maxWidth;

        // 计算刻度间隔
        final double interval = maxY / 4 == 0 ? 1.0 : maxY / 4;

        // 定义左侧标题配置
        SideTitles leftTitlesConfig() => SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: interval,
              getTitlesWidget: (value, meta) {
                if (value == 0) {
                  return Text('¥0',
                      style: TextStyle(fontSize: 10, color: tokens.textMuted));
                }
                return Text('¥${value.toInt()}',
                    style:
                        TextStyle(fontSize: 10, color: tokens.textMuted));
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
                  // 如果启用滚动，显示所有标签；否则适度稀疏
                  // 始终显示最后一个标签
                  if (!enableScroll &&
                      sortedMonths.length > 8 &&
                      index % 2 != 0 &&
                      index != sortedMonths.length - 1) {
                    return const Text('');
                  }
                  return Text(month.substring(5),
                      style: const TextStyle(fontSize: 10));
                }
                return const Text('');
              },
            );

        // 主图表配置
        LineChartData mainChartData(bool showLeftTitles) => LineChartData(
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => tokens.cardBackground,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      if (index >= 0 && index < sortedMonths.length) {
                        final month = sortedMonths[index];
                        final amount = monthlyData[month] ?? 0;
                        return LineTooltipItem(
                          '$month\n¥${amount.toStringAsFixed(0)}',
                          TextStyle(
                              color: colors.onSurface,
                              fontWeight: FontWeight.bold),
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
                getDrawingHorizontalLine: (value) =>
                    FlLine(color: tokens.divider, strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                    sideTitles: bottomTitlesConfig(showLabels: true)),
                leftTitles: AxisTitles(
                    sideTitles: showLeftTitles
                        ? leftTitlesConfig()
                        : const SideTitles(showTitles: false)),
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: false, reservedSize: 20)), // 增加顶部预留空间
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30, // 增加右侧预留空间，防止最后一个标签被裁剪
                    getTitlesWidget: (value, meta) => const Text(''),
                  ),
                ),
              ),
              borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: tokens.border, width: 1)),
              minX: 0,
              maxX: sortedMonths.length - 1,
              minY: 0,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: sortedMonths.asMap().entries.map((entry) {
                    final amount = monthlyData[entry.value] ?? 0;
                    return FlSpot(entry.key.toDouble(), amount);
                  }).toList(),
                  isCurved: true,
                  color: tokens.chartPalette[1],
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) =>
                        FlDotCirclePainter(
                      radius: 3,
                      color: tokens.chartPalette[1],
                      strokeWidth: 2,
                      strokeColor: tokens.cardBackground,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        tokens.chartPalette[1].withValues(alpha: 0.3),
                        tokens.chartPalette[1].withValues(alpha: 0.1),
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
                width: 40,
                child: LineChart(
                  LineChartData(
                    lineTouchData: const LineTouchData(enabled: false),
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                          sideTitles: bottomTitlesConfig(showLabels: false)),
                      leftTitles: AxisTitles(sideTitles: leftTitlesConfig()),
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false, reservedSize: 20)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    minX: 0,
                    maxX: 0,
                    minY: 0,
                    maxY: maxY,
                    lineBarsData: [],
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
                      child: LineChart(mainChartData(false)),
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

  Widget _buildSummaryCards(
    int totalPatients,
    int totalItems,
    double totalReceived,
    double totalDebt,
    double totalProcessingFee,
    Map<String, double> paymentMethodTotals,
  ) {
    final tokens = context.tokens;
    const summaryCardHeight = 120.0;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: summaryCardHeight,
            child: _buildStatCard('总患者数', totalPatients.toString(),
                Icons.people, tokens.primaryAccent),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: summaryCardHeight,
            child: _buildStatCard('总记录数', totalItems.toString(),
                Icons.insert_drive_file, tokens.success),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: summaryCardHeight,
            child: _buildStatCard(
              '总收费',
              _showFinancialAmounts
                  ? '¥${totalReceived.toStringAsFixed(0)}'
                  : '****',
              Icons.check_circle_outline,
              tokens.warning,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: summaryCardHeight,
            child: _buildStatCard(
              '总欠费',
              _showFinancialAmounts
                  ? '¥${totalDebt.toStringAsFixed(0)}'
                  : '****',
              Icons.error_outline,
              tokens.error,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: summaryCardHeight,
            child: _buildStatCard(
              '总加工费',
              _showFinancialAmounts
                  ? '¥${totalProcessingFee.toStringAsFixed(0)}'
                  : '****',
              Icons.build,
              tokens.info,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: summaryCardHeight,
            child: _buildPaymentMethodCard(paymentMethodTotals),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color cardColor,
  ) {
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(tokens.borderRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: tokens.cardBackground, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.cardBackground,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: tokens.cardBackground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, double> paymentMethodTotals) {
    final tokens = context.tokens;
    const cardHeight = 120.0;
    final paymentCardColor = tokens.secondaryAccent;

    return SizedBox(
      height: cardHeight,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: paymentCardColor,
          borderRadius: BorderRadius.circular(tokens.borderRadius),
          boxShadow: tokens.cardShadow,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.payment_rounded, color: tokens.cardBackground, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      '收费方式',
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.cardBackground,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _buildPaymentMethodChip(
                        methodKey: 'cash',
                        amount: paymentMethodTotals['现金'] ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildPaymentMethodChip(
                        methodKey: 'alipay',
                        amount: paymentMethodTotals['支付宝'] ?? 0.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: constraints.maxWidth * 0.62,
                  child: _buildPaymentMethodChip(
                    methodKey: 'wechat',
                    amount: paymentMethodTotals['微信'] ?? 0.0,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPaymentMethodChip({
    required String methodKey,
    required double amount,
  }) {
    final tokens = context.tokens;
    if (amount <= 0) {
      return const SizedBox(height: 26);
    }

    final iconPath =
        FinancialPaymentMethodHelper.iconAssetPathOrNull(methodKey);
    return Container(
      constraints: const BoxConstraints(minHeight: 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.cardBackground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconPath != null && iconPath.isNotEmpty) ...[
            Image.asset(
              iconPath,
              width: 11,
              height: 11,
            ),
            const SizedBox(width: 3),
          ],
          Text(
            _showFinancialAmounts ? '¥${amount.toStringAsFixed(0)}' : '****',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: tokens.cardBackground,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshData() async {
    final onRefresh = widget.onRefresh;
    if (onRefresh == null || _isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      final data = await onRefresh();
      if (!mounted) return;
      setState(() {
        _financialRecords = List<FinancialRecord>.from(data.financialRecords);
        _financialItems = List<FinancialItem>.from(data.financialItems);
        _patients = List<Patient>.from(data.patients);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Widget _buildChartCard(String title, Widget chart) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(tokens.borderRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
            ),
            const SizedBox(height: 16),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPatientsCard(List<MapEntry<String, double>> topPatients) {
    final tokens = context.tokens;
    final colors = context.colors;
    final grandTotal =
        topPatients.fold(0.0, (double sum, item) => sum + item.value);
    return _buildListCard(
      '患者收费统计 (前20名)',
      Icons.person_search,
      topPatients.map((entry) {
        final percentage = _calculatePatientPercentage(entry.value, grandTotal);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor:
                        tokens.primaryAccent.withValues(alpha: 0.1),
                    child: Text(
                      entry.key.substring(0, 1),
                      style: TextStyle(
                          color: tokens.primaryAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '¥${entry.value.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: tokens.primaryAccent,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 11, color: tokens.textMuted)),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: tokens.divider,
                valueColor:
                    AlwaysStoppedAnimation<Color>(tokens.primaryAccent),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopDebtorsCard(List<MapEntry<String, double>> topDebtors) {
    final tokens = context.tokens;
    final colors = context.colors;
    return _buildListCard(
      '患者欠费排行 (前30名)',
      Icons.money_off_csred_outlined,
      topDebtors.map((entry) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: tokens.error.withValues(alpha: 0.1),
                child: Icon(Icons.person,
                    color: tokens.error, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500, color: colors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '¥${entry.value.toStringAsFixed(0)}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: tokens.error,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildListCard(String title, IconData icon, List<Widget> children) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(tokens.borderRadius),
        boxShadow: tokens.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colors.onSurface, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600, color: colors.onSurface),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            if (children.isEmpty)
              Expanded(
                child: Center(
                  child: Text('暂无数据', style: TextStyle(color: tokens.textMuted)),
                ),
              )
            else
              Expanded(
                child: ListView(
                  children: children,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

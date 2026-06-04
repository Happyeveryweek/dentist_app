import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui' as ui;
import '../../../theme/app_theme.dart';
import '../../../models/patient.dart';
import 'interactable_pie_chart.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/reusable_date_range_picker.dart';
import '../../../screens/filtered_patients_screen.dart';

class PatientStatisticsDialog extends StatefulWidget {
  final List<Patient> patients;
  final String? searchQuery;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final String? dateFilterType;

  const PatientStatisticsDialog({
    Key? key,
    required this.patients,
    this.searchQuery,
    this.initialStartDate,
    this.initialEndDate,
    this.dateFilterType,
  }) : super(key: key);

  @override
  _PatientStatisticsDialogState createState() => _PatientStatisticsDialogState();
}

class _PatientStatisticsDialogState extends State<PatientStatisticsDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 365));
  DateTime _endDate = DateTime.now();
  String _activePreset = '6m'; // 记录当前激活的预设按钮

  @override
  void initState() {
    super.initState();
    _setDefaultDateRange();
  }

  void _setDefaultDateRange() {
    // 如果父页面传递了日期范围，使用父页面的日期范围
    if (widget.initialStartDate != null && widget.initialEndDate != null) {
      _startDate = widget.initialStartDate!;
      _endDate = widget.initialEndDate!;
      _activePreset = ''; // 自定义日期范围
    } else {
      // 默认显示全部数据
      _startDate = _getEarliestPatientDate();
      _endDate = DateTime.now();
      _activePreset = 'all'; // 默认是全部
    }
  }

  DateTime _getEarliestPatientDate() {
    if (widget.patients.isEmpty) {
      final now = DateTime.now();
      return DateTime(now.year, now.month - 11, 1);
    }
    DateTime earliest = DateTime(9999);
    for (final patient in widget.patients) {
      final d = DateTime(patient.first_visit_date.year, patient.first_visit_date.month, patient.first_visit_date.day);
      if (d.isBefore(earliest)) earliest = d;
    }
    return earliest;
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

  void _selectAllTime() {
    if (mounted) {
      setState(() {
        _startDate = _getEarliestPatientDate();
        _endDate = DateTime.now();
      });
    }
  }

  bool _isWithinRange(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final s = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final e = DateTime(_endDate.year, _endDate.month, _endDate.day);
    return (d.isAtSameMomentAs(s) || d.isAfter(s)) && (d.isAtSameMomentAs(e) || d.isBefore(e));
  }

  List<Patient> _getFilteredPatients() {
    return widget.patients.where((patient) {
      return _isWithinRange(patient.first_visit_date);
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
      start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30));
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
      start = _getEarliestPatientDate();
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

  // 计算月度初诊患者数
  Map<String, int> _calculateMonthlyNewPatients() {
    final Map<String, int> monthlyData = {};
    final filteredPatients = _getFilteredPatients();

    DateTime currentMonth = DateTime(_startDate.year, _startDate.month, 1);
    final endMonth = DateTime(_endDate.year, _endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyData[monthKey] = 0;
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    for (final patient in filteredPatients) {
      final monthKey = DateFormat('yyyy-MM').format(patient.first_visit_date);
      monthlyData[monthKey] = (monthlyData[monthKey] ?? 0) + 1;
    }

    return monthlyData;
  }

  // 计算月度就诊患者数（包括复诊）
  Map<String, int> _calculateMonthlyVisitPatients() {
    final Map<String, Set<int>> monthlyPatients = {};

    DateTime currentMonth = DateTime(_startDate.year, _startDate.month, 1);
    final endMonth = DateTime(_endDate.year, _endDate.month, 1);
    
    while (currentMonth.isBefore(endMonth) || currentMonth.isAtSameMomentAs(endMonth)) {
      final monthKey = DateFormat('yyyy-MM').format(currentMonth);
      monthlyPatients[monthKey] = {};
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    for (final patient in widget.patients) {
      // 首诊日期
      if (_isWithinRange(patient.first_visit_date)) {
        final monthKey = DateFormat('yyyy-MM').format(patient.first_visit_date);
        monthlyPatients[monthKey]?.add(patient.id!);
      }

      // 牙齿状况记录的日期（复诊）
      if (patient.dental_condition != null && patient.dental_condition!.isNotEmpty) {
        try {
          final dentalCharts = patient.dentalCharts;
          int rowCount = 0;
          for (String key in dentalCharts.keys) {
            if (key.startsWith('date-')) {
              int index = int.tryParse(key.split('-').last) ?? 0;
              rowCount = rowCount > index ? rowCount : index + 1;
            }
          }

          for (int i = 0; i < rowCount; i++) {
            String dateStr = dentalCharts['date-$i'] ?? '';
            if (dateStr.isNotEmpty) {
              try {
                DateTime visitDate;
                if (dateStr.contains('-')) {
                  visitDate = DateFormat('yyyy-MM-dd').parse(dateStr);
                } else if (dateStr.contains('/')) {
                  visitDate = DateFormat('yyyy/MM/dd').parse(dateStr);
                } else {
                  visitDate = DateTime.parse(dateStr);
                }

                if (_isWithinRange(visitDate)) {
                  final monthKey = DateFormat('yyyy-MM').format(visitDate);
                  monthlyPatients[monthKey]?.add(patient.id!);
                }
              } catch (e) {
                // 忽略日期解析错误
              }
            }
          }
        } catch (e) {
          // 忽略解析错误
        }
      }
    }

    return monthlyPatients.map((key, value) => MapEntry(key, value.length));
  }

  // 计算地址分布
  Map<String, int> _calculateAddressDistribution() {
    final Map<String, int> addressData = {};
    final filteredPatients = _getFilteredPatients();

    for (final patient in filteredPatients) {
      String address = patient.address ?? '未填写';
      if (address.isEmpty) address = '未填写';
      
      // 提取地址的主要部分（如城市或区）
      String mainAddress = _extractMainAddress(address);
      addressData[mainAddress] = (addressData[mainAddress] ?? 0) + 1;
    }

    // 按数量排序，取前30个
    final sortedEntries = addressData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final Map<String, int> topAddresses = {};
    int otherCount = 0;
    
    for (int i = 0; i < sortedEntries.length; i++) {
      if (i < 30) {
        topAddresses[sortedEntries[i].key] = sortedEntries[i].value;
      } else {
        otherCount += sortedEntries[i].value;
      }
    }
    
    if (otherCount > 0) {
      topAddresses['其他'] = otherCount;
    }

    return topAddresses;
  }

  String _extractMainAddress(String address) {
    // 简单提取地址的主要部分
    if (address.contains('市')) {
      final parts = address.split('市');
      if (parts.isNotEmpty) {
        return parts[0] + '市';
      }
    }
    if (address.contains('区')) {
      final parts = address.split('区');
      if (parts.length > 1) {
        return parts[0] + '区';
      }
    }
    if (address.contains('县')) {
      final parts = address.split('县');
      if (parts.isNotEmpty) {
        return parts[0] + '县';
      }
    }
    // 如果地址太长，截取前10个字符
    if (address.length > 10) {
      return address.substring(0, 10) + '...';
    }
    return address;
  }

  // 计算年龄分布
  Map<String, int> _calculateAgeDistribution() {
    final Map<String, int> ageData = {
      '0-18岁': 0,
      '19-30岁': 0,
      '31-45岁': 0,
      '46-60岁': 0,
      '60岁以上': 0,
    };
    final filteredPatients = _getFilteredPatients();

    for (final patient in filteredPatients) {
      if (patient.age <= 18) {
        ageData['0-18岁'] = ageData['0-18岁']! + 1;
      } else if (patient.age <= 30) {
        ageData['19-30岁'] = ageData['19-30岁']! + 1;
      } else if (patient.age <= 45) {
        ageData['31-45岁'] = ageData['31-45岁']! + 1;
      } else if (patient.age <= 60) {
        ageData['46-60岁'] = ageData['46-60岁']! + 1;
      } else {
        ageData['60岁以上'] = ageData['60岁以上']! + 1;
      }
    }

    return ageData;
  }

  // 计算性别分布
  Map<String, int> _calculateGenderDistribution() {
    final Map<String, int> genderData = {'男': 0, '女': 0};
    final filteredPatients = _getFilteredPatients();

    for (final patient in filteredPatients) {
      if (patient.gender == '男') {
        genderData['男'] = genderData['男']! + 1;
      } else if (patient.gender == '女') {
        genderData['女'] = genderData['女']! + 1;
      }
    }

    return genderData;
  }

  int _calculateTotalPatients() {
    return _getFilteredPatients().length;
  }

  int _calculateMalePatients() {
    return _getFilteredPatients().where((p) => p.gender == '男').length;
  }

  int _calculateFemalePatients() {
    return _getFilteredPatients().where((p) => p.gender == '女').length;
  }

  double _calculateAverageAge() {
    final filteredPatients = _getFilteredPatients();
    if (filteredPatients.isEmpty) return 0;
    final totalAge = filteredPatients.fold(0, (sum, p) => sum + p.age);
    return totalAge / filteredPatients.length;
  }

  bool _isPresetActive(String preset) {
    // 直接比较是否是当前激活的预设
    return _activePreset == preset;
  }

  Widget _buildPresetButton(String label, String key) {
    final active = _isPresetActive(key);
    return ElevatedButton(
      onPressed: () => _applyPreset(key),
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? DentalColors.primary : Colors.white,
        foregroundColor: active ? Colors.white : Colors.black87,
        elevation: active ? 3 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: active ? Colors.transparent : Colors.grey.withOpacity(0.12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, color: active ? Colors.white : Colors.black87)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalPatients = _calculateTotalPatients();
    final malePatients = _calculateMalePatients();
    final femalePatients = _calculateFemalePatients();
    final averageAge = _calculateAverageAge();
    final monthlyNewData = _calculateMonthlyNewPatients();
    final monthlyVisitData = _calculateMonthlyVisitPatients();
    final addressData = _calculateAddressDistribution();
    final ageData = _calculateAgeDistribution();
    final genderData = _calculateGenderDistribution();
    
    final sortedNewMonths = monthlyNewData.keys.toList()..sort();
    final sortedVisitMonths = monthlyVisitData.keys.toList()..sort();

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
              child: const Icon(
                Icons.bar_chart_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              '患者统计图表',
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
                  onTap: () async { await _showCustomDateRangePicker(); },
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
      body: Padding(
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
                  color: DentalColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: DentalColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: DentalColors.info, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '当前显示搜索结果的统计数据：${widget.searchQuery}${widget.dateFilterType != null ? " (按${widget.dateFilterType == 'first_visit_date' ? '首诊时间' : '最后就诊时间'}筛选)" : ""}',
                        style: TextStyle(color: DentalColors.info, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            _buildSummaryCards(totalPatients, malePatients, femalePatients, averageAge),
            const SizedBox(height: 20),
            
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalW = constraints.maxWidth;
                  const gap = 12.0;
                  double rightW = (totalW / 3) < 400 ? 400 : (totalW / 3);
                  if (rightW > totalW - 300) rightW = totalW - 300;
                  final double leftW = totalW - rightW - gap;

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 左侧：折线图
                      SizedBox(
                        width: leftW,
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildChartCard(
                                '月度初诊患者趋势',
                                _buildMonthlyNewPatientsChart(sortedNewMonths, monthlyNewData),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: _buildChartCard(
                                '月度就诊患者趋势（含复诊）',
                                _buildMonthlyVisitPatientsChart(sortedVisitMonths, monthlyVisitData),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: gap),
                      // 右侧：饼图
                      SizedBox(
                        width: rightW,
                        child: Column(
                          children: [
                            Expanded(child: _buildPieChartCard('地址分布', addressData)),
                            const SizedBox(height: 12),
                            Expanded(child: _buildPieChartCard('年龄分布', ageData)),
                            const SizedBox(height: 12),
                            Expanded(child: _buildPieChartCard('性别分布', genderData)),
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

  Widget _buildSummaryCards(int totalPatients, int malePatients, int femalePatients, double averageAge) {
    return Row(
      children: [
        Expanded(child: _buildStatCard('总患者数', totalPatients.toString(), Icons.people, Colors.purple)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('男性患者', malePatients.toString(), Icons.male, Colors.blue)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('女性患者', femalePatients.toString(), Icons.female, Colors.pink)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('平均年龄', '${averageAge.toStringAsFixed(1)}岁', Icons.cake, DentalColors.warning)),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Expanded(child: chart),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyNewPatientsChart(List<String> sortedMonths, Map<String, int> monthlyData) {
    if (sortedMonths.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxValue = monthlyData.values.isEmpty ? 1 : monthlyData.values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.2).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool enableScroll = sortedMonths.length > 12;
        final double chartWidth = enableScroll 
            ? (sortedMonths.length * 70.0 + 60.0).clamp(constraints.maxWidth, double.infinity)
            : constraints.maxWidth;

        final double interval = maxY / 4 == 0 ? 1.0 : maxY / 4;

        SideTitles leftTitlesConfig() => SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const Text('0', style: TextStyle(fontSize: 10, color: Colors.black54));
            return Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.black54));
          },
        );

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

              return Text(month.substring(5), style: const TextStyle(fontSize: 10));
            }
            return const Text('');
          },
        );

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
                    final count = monthlyData[month] ?? 0;
                    return LineTooltipItem(
                      '$month\n$count人',
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
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: bottomTitlesConfig(showLabels: true)),
            leftTitles: AxisTitles(sideTitles: showLeftTitles ? leftTitlesConfig() : SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 20)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 30,
                getTitlesWidget: (value, meta) => const Text(''),
              ),
            ),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 1)),
          minX: 0,
          maxX: (sortedMonths.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: sortedMonths.asMap().entries.map((entry) {
                final count = monthlyData[entry.value] ?? 0;
                return FlSpot(entry.key.toDouble(), count.toDouble());
              }).toList(),
              isCurved: true,
              color: DentalColors.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: DentalColors.primary,
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
                    DentalColors.primary.withOpacity(0.3),
                    DentalColors.primary.withOpacity(0.1),
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
              SizedBox(
                width: 40,
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(enabled: false),
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: bottomTitlesConfig(showLabels: false)),
                      leftTitles: AxisTitles(sideTitles: leftTitlesConfig()),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 20)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  Widget _buildMonthlyVisitPatientsChart(List<String> sortedMonths, Map<String, int> monthlyData) {
    if (sortedMonths.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final maxValue = monthlyData.values.isEmpty ? 1 : monthlyData.values.reduce((a, b) => a > b ? a : b);
    final maxY = (maxValue * 1.2).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool enableScroll = sortedMonths.length > 12;
        final double chartWidth = enableScroll 
            ? (sortedMonths.length * 70.0 + 60.0).clamp(constraints.maxWidth, double.infinity)
            : constraints.maxWidth;

        final double interval = maxY / 4 == 0 ? 1.0 : maxY / 4;

        SideTitles leftTitlesConfig() => SideTitles(
          showTitles: true,
          reservedSize: 40,
          interval: interval,
          getTitlesWidget: (value, meta) {
            if (value == 0) return const Text('0', style: TextStyle(fontSize: 10, color: Colors.black54));
            return Text('${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.black54));
          },
        );

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

              return Text(month.substring(5), style: const TextStyle(fontSize: 10));
            }
            return const Text('');
          },
        );

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
                    final count = monthlyData[month] ?? 0;
                    return LineTooltipItem(
                      '$month\n$count人',
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
            horizontalInterval: interval,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(sideTitles: bottomTitlesConfig(showLabels: true)),
            leftTitles: AxisTitles(sideTitles: showLeftTitles ? leftTitlesConfig() : SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 20)),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, 
                reservedSize: 30,
                getTitlesWidget: (value, meta) => const Text(''),
              ),
            ),
          ),
          borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300, width: 1)),
          minX: 0,
          maxX: (sortedMonths.length - 1).toDouble(),
          minY: 0,
          maxY: maxY,
          lineBarsData: [
            LineChartBarData(
              spots: sortedMonths.asMap().entries.map((entry) {
                final count = monthlyData[entry.value] ?? 0;
                return FlSpot(entry.key.toDouble(), count.toDouble());
              }).toList(),
              isCurved: true,
              color: Colors.green,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 3,
                  color: Colors.green,
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
                    Colors.green.withOpacity(0.3),
                    Colors.green.withOpacity(0.1),
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
              SizedBox(
                width: 40,
                child: LineChart(
                  LineChartData(
                    lineTouchData: LineTouchData(enabled: false),
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(sideTitles: bottomTitlesConfig(showLabels: false)),
                      leftTitles: AxisTitles(sideTitles: leftTitlesConfig()),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false, reservedSize: 20)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

  Widget _buildPieChartCard(String title, Map<String, int> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: data.isEmpty || data.values.every((v) => v == 0)
                  ? const Center(child: Text('暂无数据'))
                  : InteractablePieChart(
                      data: data,
                      chartType: title,
                      onSectionTap: (String category) {
                        _navigateToFilteredPatients(title, category);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // 导航到患者管理页面并显示筛选后的患者列表
  void _navigateToFilteredPatients(String chartType, String category) {
    // 根据图表类型和分类筛选患者
    List<Patient> filteredPatients = [];
    
    print('导航到筛选患者: chartType=$chartType, category=$category');
    print('当前日期范围内的患者总数: ${_getFilteredPatients().length}');
    
    if (chartType == '地址分布') {
      // 按地址筛选
      if (category == '其他') {
        // 处理"其他"分类：获取所有不在前10名的地址
        final addressData = _calculateAddressDistribution();
        // 移除"其他"项，获取前10名的地址列表
        final topAddresses = addressData.keys.where((key) => key != '其他').toSet();
        
        print('前10名地址: $topAddresses');
        
        // 筛选出地址不在前10名的患者
        filteredPatients = _getFilteredPatients().where((patient) {
          String address = patient.address ?? '未填写';
          if (address.isEmpty) address = '未填写';
          String mainAddress = _extractMainAddress(address);
          return !topAddresses.contains(mainAddress);
        }).toList();
      } else {
        // 普通地址筛选
        filteredPatients = _getFilteredPatients().where((patient) {
          String address = patient.address ?? '未填写';
          if (address.isEmpty) address = '未填写';
          String mainAddress = _extractMainAddress(address);
          return mainAddress == category;
        }).toList();
      }
    } else if (chartType == '年龄分布') {
      // 按年龄段筛选
      filteredPatients = _getFilteredPatients().where((patient) {
        if (category == '0-18岁') {
          return patient.age <= 18;
        } else if (category == '19-30岁') {
          return patient.age >= 19 && patient.age <= 30;
        } else if (category == '31-45岁') {
          return patient.age >= 31 && patient.age <= 45;
        } else if (category == '46-60岁') {
          return patient.age >= 46 && patient.age <= 60;
        } else if (category == '60岁以上') {
          return patient.age > 60;
        }
        return false;
      }).toList();
    } else if (chartType == '性别分布') {
      // 按性别筛选
      filteredPatients = _getFilteredPatients().where((patient) {
        return patient.gender == category;
      }).toList();
    }

    print('筛选后的患者数量: ${filteredPatients.length}');

    // 导航到患者列表页面
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FilteredPatientsScreen(
          patients: filteredPatients,
          filterTitle: '$chartType - $category',
          filterDescription: '共 ${filteredPatients.length} 位患者',
        ),
      ),
    );
  }

}



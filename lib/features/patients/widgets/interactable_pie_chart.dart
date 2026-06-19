import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/dental_icons.dart';

class InteractablePieChart extends StatefulWidget {
  final Map<String, int> data;
  final String chartType;
  final Function(String category) onSectionTap;

  const InteractablePieChart({
    Key? key,
    required this.data,
    required this.chartType,
    required this.onSectionTap,
  }) : super(key: key);

  @override
  _InteractablePieChartState createState() => _InteractablePieChartState();
}

class _InteractablePieChartState extends State<InteractablePieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final total = widget.data.values.fold(0, (sum, value) => sum + value);
    // Safety check, though parent handles empty case often
    if (total == 0) {
      return const Center(child: Text('暂无数据'));
    }

    final colors = [
      DentalColors.primary,
      DentalColors.success,
      DentalColors.warning,
      DentalColors.error,
      DentalColors.info,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.indigo,
      Colors.brown,
      Colors.cyan,
    ];

    // 按数量从大到小排序，最多的排最上面
    final sortedEntries = widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = sortedEntries.asMap().entries.map((entry) {
      final index = entry.key;
      final dataEntry = entry.value;
      final percentage = (dataEntry.value / total * 100);
      final isTouched = index == touchedIndex;
      final double radius = isTouched ? 60 : 50;
      final double fontSize = isTouched ? 14 : 12;

      // Show title if touched OR if percentage >= 5
      final showTitle = isTouched || percentage >= 5;
      
      return PieChartSectionData(
        color: colors[index % colors.length],
        value: dataEntry.value.toDouble(),
        title: showTitle ? '${percentage.toStringAsFixed(1)}%' : '',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    }).toList();

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                    
                    // 处理点击事件
                    if (event is FlTapUpEvent) {
                      final tappedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                      final category = sortedEntries[tappedIndex].key;
                      widget.onSectionTap(category);
                    }
                  });
                },
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sortedEntries.asMap().entries.map((entry) {
                final index = entry.key;
                final dataEntry = entry.value;
                final percentage = (dataEntry.value / total * 100);
                final isTouched = index == touchedIndex;
                
                return InkWell(
                  onTap: () {
                    widget.onSectionTap(dataEntry.key);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isTouched ? colors[index % colors.length].withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${dataEntry.key}: ${dataEntry.value}人 (${percentage.toStringAsFixed(1)}%)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                              color: isTouched ? colors[index % colors.length] : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

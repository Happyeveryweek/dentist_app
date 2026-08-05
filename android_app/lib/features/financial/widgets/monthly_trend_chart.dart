import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../widgets/single_line_amount_text.dart';

/// 月度趋势图表组件
/// 职责：显示月度收费趋势图表
class MonthlyTrendChart extends StatelessWidget {
  final Map<String, Map<String, double>> monthlyData;

  const MonthlyTrendChart({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
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
      final collected = monthlyData[month]?['collected'] ?? 0.0;
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
                final data = monthlyData[month];
                final collected = data?['collected'] ?? 0.0;
                final records = (data?['records'] ?? 0.0).toInt();

                final collectedRate = maxValue > 0 ? collected / maxValue : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                              children: [
                                Text(
                                  '收费',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: SingleLineAmountText(
                                      text:
                                          '¥${NumberFormat('#,##0').format(collected)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                      ),
                                      alignment: Alignment.centerRight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: collectedRate,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.blue.shade600,
                              ),
                              minHeight: 3,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // 右侧：记录数
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
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
}

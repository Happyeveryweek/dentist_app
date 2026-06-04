import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 月度加工费图表组件
/// 职责：显示月度加工费趋势图表
class MonthlyProcessingChart extends StatelessWidget {
  final Map<String, double> monthlyData;

  const MonthlyProcessingChart({
    super.key,
    required this.monthlyData,
  });

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
      final value = monthlyData[month]!;
      return value > max ? value : max;
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
              Icon(Icons.build, color: Colors.teal[600], size: 20),
              const SizedBox(width: 8),
              Text(
                '月度加工费趋势',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal[600],
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
                final value = monthlyData[month]!;
                
                final valueRate = maxValue > 0 ? value / maxValue : 0.0;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.2),
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
                          color: Colors.teal[400],
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
                                  '¥${NumberFormat('#,##0').format(value)}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal[700],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            LinearProgressIndicator(
                              value: valueRate,
                              backgroundColor: Colors.grey[200],
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[600]!),
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
}

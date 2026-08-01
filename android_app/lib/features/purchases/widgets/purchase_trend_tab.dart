import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/purchase_record.dart';
import '../services/purchase_statistics_calculator.dart';
import '../services/purchase_amount_formatter.dart';

/// 采购统计趋势 Tab 页面组件
class PurchaseTrendTab extends StatelessWidget {
  final List<PurchaseRecord> filteredRecords;
  final DateTime startDate;
  final DateTime endDate;

  const PurchaseTrendTab({
    super.key,
    required this.filteredRecords,
    required this.startDate,
    required this.endDate,
  });

  @override
  Widget build(BuildContext context) {
    final monthlyData = PurchaseStatisticsCalculator.calculateMonthlyData(
      filteredRecords,
      startDate,
      endDate,
    );

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
      final amount = monthlyData[month]?['amount'] ?? 0.0;
      return amount > max ? amount : max;
    });

    final maxQuantity = sortedMonths.fold<double>(0.0, (max, month) {
      final quantity = monthlyData[month]?['quantity'] ?? 0.0;
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
                final data = monthlyData[month];
                final amount = data?['amount'] ?? 0.0;
                final quantity = data?['quantity'] ?? 0.0;
                final records = (data?['records'] ?? 0.0).toInt();

                final amountRate = maxAmount > 0 ? amount / maxAmount : 0.0;
                final quantityRate =
                    maxQuantity > 0 ? quantity / maxQuantity : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.green.shade600,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              PurchaseAmountFormatter.formatCurrency(amount),
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.orange.shade600,
                              ),
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
              rows:
                  reversedMonths.map((month) {
                    final data = monthlyData[month];
                    final amount = data?['amount'] ?? 0.0;
                    final quantity = data?['quantity'] ?? 0.0;
                    final records = (data?['records'] ?? 0.0).toInt();
                    final avgPrice = quantity > 0 ? amount / quantity : 0.0;

                    return DataRow(
                      cells: [
                        DataCell(Text(month)),
                        DataCell(Text(records.toString())),
                        DataCell(
                          Text(PurchaseAmountFormatter.formatCurrency(amount)),
                        ),
                        DataCell(Text(NumberFormat('#,##0').format(quantity))),
                        DataCell(
                          Text(
                            PurchaseAmountFormatter.formatCurrency(avgPrice),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

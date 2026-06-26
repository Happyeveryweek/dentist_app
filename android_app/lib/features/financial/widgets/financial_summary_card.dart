import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../widgets/app_card.dart';
import '../../../models/financial_item.dart';

/// 财务统计卡片组件
/// 职责：显示财务统计信息卡片
class FinancialSummaryCard extends StatelessWidget {
  final List<FinancialItem> items;

  const FinancialSummaryCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final totalReceivable = items.fold<double>(
      0.0,
      (sum, item) => sum + item.itemPrice, // 与Windows端一致，不乘数量
    );
    final totalCollected = items.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    final totalOutstanding = totalReceivable - totalCollected;

    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '财务统计',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // 显示应收费、已收费、欠费
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '应收费',
                    '¥${NumberFormat('#,##0').format(totalReceivable)}',
                    Icons.account_balance_wallet,
                    Colors.green.shade600,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '已收费',
                    '¥${NumberFormat('#,##0').format(totalCollected)}',
                    Icons.payment,
                    Colors.orange.shade600,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    '总欠费',
                    '¥${NumberFormat('#,##0').format(totalOutstanding)}',
                    Icons.money_off,
                    totalOutstanding > 0 ? Colors.red.shade600 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

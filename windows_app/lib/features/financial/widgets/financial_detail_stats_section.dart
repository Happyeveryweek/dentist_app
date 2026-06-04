import 'package:flutter/material.dart';
import 'financial_stat_item.dart';

/// 财务详情页统计区域组件
/// 用于显示患者的财务统计信息（应收费、已收费、欠费金额）
class FinancialDetailStatsSection extends StatelessWidget {
  final double totalReceivable;
  final double totalPaid;
  final double totalOutstanding;

  const FinancialDetailStatsSection({
    super.key,
    required this.totalReceivable,
    required this.totalPaid,
    required this.totalOutstanding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            child: FinancialStatItem(
              icon: Icons.square,
              label: '应收费',
              value: '¥${(totalReceivable % 1 == 0 ? totalReceivable.toInt().toString() : totalReceivable.toStringAsFixed(2))}',
              color: Colors.blue[700]!,
            ),
          ),
          Expanded(
            child: FinancialStatItem(
              icon: Icons.check_circle,
              label: '已收费',
              value: '¥${(totalPaid % 1 == 0 ? totalPaid.toInt().toString() : totalPaid.toStringAsFixed(2))}',
              color: Colors.green[700]!,
            ),
          ),
          Expanded(
            child: FinancialStatItem(
              icon: Icons.more_horiz,
              label: '欠费金额',
              value: '¥${(totalOutstanding % 1 == 0 ? totalOutstanding.toInt().toString() : totalOutstanding.toStringAsFixed(2))}',
              color: totalOutstanding > 0 ? Colors.red[700]! : Colors.grey[600]!,
            ),
          ),
        ],
      ),
    );
  }
}

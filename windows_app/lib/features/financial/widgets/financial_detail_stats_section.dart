import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.tokens.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: FinancialStatItem(
              icon: Icons.square,
              label: '应收费',
              value:
                  '¥${(totalReceivable % 1 == 0 ? totalReceivable.toInt().toString() : totalReceivable.toStringAsFixed(2))}',
              color: context.tokens.primaryAccent,
            ),
          ),
          Expanded(
            child: FinancialStatItem(
              icon: Icons.check_circle,
              label: '已收费',
              value:
                  '¥${(totalPaid % 1 == 0 ? totalPaid.toInt().toString() : totalPaid.toStringAsFixed(2))}',
              color: context.tokens.success,
            ),
          ),
          Expanded(
            child: FinancialStatItem(
              icon: Icons.more_horiz,
              label: '欠费金额',
              value:
                  '¥${(totalOutstanding % 1 == 0 ? totalOutstanding.toInt().toString() : totalOutstanding.toStringAsFixed(2))}',
              color: totalOutstanding > 0
                  ? context.tokens.error
                  : context.colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

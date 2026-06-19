import 'package:flutter/material.dart';

/// 财务记录列表标题组件
/// 用于显示记录列表的标题和添加按钮
class FinancialRecordsListHeader extends StatelessWidget {
  final int recordCount;
  final bool showProcessingFee;
  final VoidCallback onToggleProcessingFee;
  final VoidCallback onAddRecord;

  const FinancialRecordsListHeader({
    super.key,
    required this.recordCount,
    required this.showProcessingFee,
    required this.onToggleProcessingFee,
    required this.onAddRecord,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.list_alt, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '收费记录历史 ($recordCount条)',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Spacer(),
        Tooltip(
          message: showProcessingFee ? '隐藏加工费' : '显示加工费',
          child: OutlinedButton(
            onPressed: onToggleProcessingFee,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Icon(
              showProcessingFee ? Icons.visibility_off : Icons.visibility,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          onPressed: onAddRecord,
          icon: const Icon(Icons.add),
          label: const Text('添加记录'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

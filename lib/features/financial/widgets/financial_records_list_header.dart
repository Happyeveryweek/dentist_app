import 'package:flutter/material.dart';

/// 财务记录列表标题组件
/// 用于显示记录列表的标题和添加按钮
class FinancialRecordsListHeader extends StatelessWidget {
  final int recordCount;
  final VoidCallback onAddRecord;

  const FinancialRecordsListHeader({
    super.key,
    required this.recordCount,
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

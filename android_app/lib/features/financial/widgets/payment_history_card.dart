import 'package:flutter/material.dart';
import '../../../widgets/app_card.dart';
import '../../../models/financial_item.dart';

/// 收费记录历史卡片组件
/// 职责：显示收费记录历史卡片
class PaymentHistoryCard extends StatelessWidget {
  final List<FinancialItem> items;
  final VoidCallback onAddItem;
  final Widget Function(FinancialItem item) itemBuilder;

  const PaymentHistoryCard({
    super.key,
    required this.items,
    required this.onAddItem,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '收费记录历史 (${items.length}条)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onAddItem,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('添加记录', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      '暂无收费记录',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: items.map((item) => itemBuilder(item)).toList(),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

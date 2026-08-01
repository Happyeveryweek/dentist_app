import 'package:flutter/material.dart';
import '../../../models/purchase_record.dart';
import '../../../widgets/app_card.dart';
import 'purchase_amount_item.dart';
import '../services/purchase_amount_formatter.dart';

/// 采购金额统计卡片
class PurchaseAmountCard extends StatelessWidget {
  final PurchaseRecord record;
  final int itemCount;

  const PurchaseAmountCard({
    super.key,
    required this.record,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '金额信息',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PurchaseAmountItem(
                  '总金额',
                  PurchaseAmountFormatter.formatCurrency(record.totalAmount),
                  icon: Icons.account_balance_wallet,
                  color: Colors.green,
                ),
              ),
              Expanded(
                child: PurchaseAmountItem(
                  '总数量',
                  record.totalQuantity.toString(),
                  icon: Icons.inventory,
                  color: Colors.blue,
                ),
              ),
              Expanded(
                child: PurchaseAmountItem(
                  '项目数',
                  itemCount.toString(),
                  icon: Icons.list,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

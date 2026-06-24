import 'package:flutter/material.dart';
import '../../../models/purchase_item.dart';
import '../../../widgets/app_card.dart';
import 'purchase_item_row.dart';
import 'purchase_empty_state.dart';
import 'purchase_error_state.dart';

/// 采购项目明细卡片
class PurchaseItemsCard extends StatelessWidget {
  final List<PurchaseItem> purchaseItems;
  final bool isLoading;
  final bool hasError;
  final String errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onAddItem;

  const PurchaseItemsCard({
    super.key,
    required this.purchaseItems,
    required this.isLoading,
    required this.hasError,
    required this.errorMessage,
    required this.onRetry,
    required this.onAddItem,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '采购项目明细',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                onPressed: onAddItem,
                icon: const Icon(Icons.add),
                label: const Text('添加项目'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (hasError)
            PurchaseErrorState(errorMessage: errorMessage, onRetry: onRetry)
          else if (purchaseItems.isEmpty)
            const PurchaseEmptyState()
          else
            Column(
              children: [
                // 表头
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          '材料名称',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '数量',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '单价',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '单位',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '总价',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // 项目列表
                ...purchaseItems
                    .map((item) => PurchaseItemRow(item: item))
                    .toList(),
              ],
            ),
        ],
      ),
    );
  }
}

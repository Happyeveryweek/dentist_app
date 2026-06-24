import 'package:flutter/material.dart';
import 'package:dentist_app/models/financial_item.dart';

/// 财务项目行组件
/// 职责：显示财务项目列表中的单个项目
class FinancialItemRow extends StatelessWidget {
  final FinancialItem item;
  final int index;
  final VoidCallback onRemove;

  const FinancialItemRow({
    super.key,
    required this.item,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // 项目名称列
          Expanded(
            flex: 3,
            child: Text(
              item.itemName,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 数量列
          SizedBox(
            width: 50,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 单价列
          SizedBox(
            width: 60,
            child: Text(
              '¥${item.itemPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 总价列
          SizedBox(
            width: 60,
            child: Text(
              '¥${item.totalPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 操作列
          SizedBox(
            width: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

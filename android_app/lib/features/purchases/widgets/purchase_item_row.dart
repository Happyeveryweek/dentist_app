import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/purchase_item.dart';

/// 单个采购项目行组件
class PurchaseItemRow extends StatelessWidget {
  final PurchaseItem item;

  const PurchaseItemRow({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.materialName,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.quantity.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.blue[700]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '¥${NumberFormat('#,##0.00').format(item.unitPrice)}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.orange[700]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              item.unit ?? '-',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '¥${NumberFormat('#,##0.00').format(item.totalPrice)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/financial_item.dart';
import '../../../widgets/single_line_amount_text.dart';
import '../helpers/financial_payment_method_helper.dart';

/// 收费项目卡片组件
/// 职责：显示单个收费项目的卡片
class FinancialItemCard extends StatelessWidget {
  final FinancialItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FinancialItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：日期和操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MM-dd HH:mm').format(item.chargeDate),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                    onPressed: onEdit,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                    onPressed: onDelete,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 第二行：收费项目名称
          Text(
            item.itemName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          if (FinancialPaymentMethodHelper.displayName(
            item.paymentMethod,
          ).isNotEmpty)
            Row(
              children: [
                Icon(Icons.payment, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Builder(
                  builder: (context) {
                    final iconPath =
                        FinancialPaymentMethodHelper.iconAssetPathOrNull(
                          item.paymentMethod,
                        );
                    if (iconPath == null) return const SizedBox.shrink();
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          iconPath,
                          width: 16,
                          height: 16,
                          errorBuilder:
                              (_, __, ___) => Icon(
                                Icons.payment,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    );
                  },
                ),
                Text(
                  FinancialPaymentMethodHelper.displayName(item.paymentMethod),
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // 第三行：金额信息（已移除每行欠费列，保留应收费/已收费/加工费）
          Row(
            children: [
              Expanded(
                child: _buildAmountInfo(
                  '应收费',
                  '¥${NumberFormat('#,##0').format(item.itemPrice * item.quantity)}',
                  Theme.of(context).primaryColor,
                ),
              ),
              Expanded(
                child: _buildAmountInfo(
                  '已收费',
                  '¥${NumberFormat('#,##0').format(item.totalPrice)}',
                  Colors.orange.shade600,
                ),
              ),
              Expanded(
                child: _buildAmountInfo(
                  '加工费',
                  '¥${NumberFormat('#,##0').format(item.processingFee)}',
                  Colors.green.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfo(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 4),
        SingleLineAmountText(
          text: value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

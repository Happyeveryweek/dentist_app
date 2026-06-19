import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/financial_record.dart';
import '../../../models/financial_item.dart';
import '../helpers/financial_payment_method_helper.dart';
import 'financial_detail_table_layout.dart';

/// 财务详情页记录卡片组件
/// 用于显示单个财务记录的详细信息
class FinancialDetailRecordCard extends StatelessWidget {
  final FinancialRecord record;
  final FinancialItem? item;
  final bool isDetail;
  final bool isHighlighted;
  final bool isEditing;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FinancialDetailRecordCard({
    super.key,
    required this.record,
    this.item,
    this.isDetail = false,
    this.isHighlighted = false,
    this.isEditing = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FinancialDetailTableLayout.rowHeight,
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.grey[200]!, width: 1),
          boxShadow: isHighlighted
              ? [
                  BoxShadow(
                    color: Colors.blue[200]!.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.grey[300]!.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FinancialDetailTableLayout.buildRow(
          children: [
            Text(
              isDetail && item != null
                  ? DateFormat('yyyy-MM-dd').format(item!.chargeDate)
                  : DateFormat('yyyy-MM-dd').format(record.createdAt),
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              isDetail && item != null ? item!.itemName : (record.notes ?? '收费项目'),
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Center(
              child: isDetail && item != null
                  ? (() {
                      final iconPath =
                          FinancialPaymentMethodHelper.iconAssetPathOrNull(
                        item!.paymentMethod,
                      );
                      if (iconPath == null) {
                        return const SizedBox.shrink();
                      }
                      return Tooltip(
                        message: FinancialPaymentMethodHelper
                            .displayNameOrDefault(item!.paymentMethod),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: Image.asset(
                            iconPath,
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                      );
                    })()
                  : const SizedBox.shrink(),
            ),
            Text(
              isDetail && item != null
                  ? '¥${((item!.itemPrice * (item!.quantity ?? 1)) % 1 == 0 ? (item!.itemPrice * (item!.quantity ?? 1)).toInt().toString() : (item!.itemPrice * (item!.quantity ?? 1)).toStringAsFixed(2))}'
                  : '¥0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              isDetail && item != null
                  ? '¥${(item!.totalPrice % 1 == 0 ? item!.totalPrice.toInt().toString() : item!.totalPrice.toStringAsFixed(2))}'
                  : '¥0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              isDetail && item != null
                  ? '¥${(item!.processingFee % 1 == 0 ? item!.processingFee.toInt().toString() : item!.processingFee.toStringAsFixed(2))}'
                  : '¥0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                isEditing
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                        ),
                      )
                    : IconButton(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit, color: Colors.blue[600]),
                        tooltip: '编辑',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                IconButton(
                  onPressed: isEditing ? null : onDelete,
                  icon: Icon(
                    Icons.delete,
                    color: isEditing ? Colors.grey[400] : Colors.red[600],
                  ),
                  tooltip: isEditing ? '正在编辑中...' : '删除',
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

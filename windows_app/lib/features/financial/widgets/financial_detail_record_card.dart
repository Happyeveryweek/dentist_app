import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
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
  final bool showProcessingFee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FinancialDetailRecordCard({
    super.key,
    required this.record,
    this.item,
    this.isDetail = false,
    this.isHighlighted = false,
    this.isEditing = false,
    this.showProcessingFee = false,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final detailItem = item;
    final hasItem = isDetail && detailItem != null;
    return SizedBox(
      height: FinancialDetailTableLayout.rowHeight,
      child: Container(
        decoration: BoxDecoration(
          color: isHighlighted
              ? tokens.primaryAccent.withValues(alpha: 0.08)
              : tokens.cardBackground,
          border: Border(
            bottom: BorderSide(
              color: tokens.divider,
              width: 0.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FinancialDetailTableLayout.buildRow(
          children: [
            Text(
              hasItem
                  ? DateFormat('yyyy-MM-dd').format(detailItem.chargeDate)
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
              hasItem ? detailItem.itemName : (record.notes ?? '收费项目'),
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Center(
              child: hasItem
                  ? (() {
                      final iconPath =
                          FinancialPaymentMethodHelper.iconAssetPathOrNull(
                        detailItem.paymentMethod,
                      );
                      if (iconPath == null) {
                        return const SizedBox.shrink();
                      }
                      return Tooltip(
                        message:
                            FinancialPaymentMethodHelper.displayNameOrDefault(
                                detailItem.paymentMethod),
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
              hasItem
                  ? '¥${((detailItem.itemPrice * detailItem.quantity) % 1 == 0 ? (detailItem.itemPrice * detailItem.quantity).toInt().toString() : (detailItem.itemPrice * detailItem.quantity).toStringAsFixed(2))}'
                  : '¥0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.primaryAccent,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              hasItem
                  ? '¥${(detailItem.totalPrice % 1 == 0 ? detailItem.totalPrice.toInt().toString() : detailItem.totalPrice.toStringAsFixed(2))}'
                  : '¥0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.success,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              !showProcessingFee
                  ? '****'
                  : hasItem
                      ? '¥${(detailItem.processingFee % 1 == 0 ? detailItem.processingFee.toInt().toString() : detailItem.processingFee.toStringAsFixed(2))}'
                      : '¥0',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.warning,
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
                          valueColor: AlwaysStoppedAnimation<Color>(
                              tokens.primaryAccent),
                        ),
                      )
                    : IconButton(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit, color: tokens.primaryAccent),
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
                    color: isEditing ? tokens.textMuted : tokens.error,
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

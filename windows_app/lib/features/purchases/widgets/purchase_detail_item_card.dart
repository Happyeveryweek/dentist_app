import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/purchase_item.dart';

/// 采购记录详情中的项目卡片
/// 用于显示单个采购项目的详细信息
class PurchaseDetailItemCard extends StatelessWidget {
  final PurchaseItem item;

  const PurchaseDetailItemCard({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // 材料名称
            Expanded(
              flex: 7,
              child: Text(
                item.materialName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 数量
            Expanded(
              flex: 3,
              child: Text(
                '${item.quantity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.success,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // 单价
            Expanded(
              flex: 4,
              child: Text(
                '¥${item.unitPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.primaryAccent,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // 单位
            Expanded(
              flex: 3,
              child: Text(
                item.formattedUnit,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.secondaryAccent,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            // 总价
            Expanded(
              flex: 4,
              child: Text(
                '¥${item.totalPrice.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: tokens.warning,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

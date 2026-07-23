import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../widgets/dental_icons.dart';

/// 采购记录详情对话框
class PurchaseDetailDialog extends StatefulWidget {
  final PurchaseRecord record;
  final List<PurchaseItem> purchaseItems;
  final VoidCallback? onEdit;
  final void Function(PurchaseRecord record, List<PurchaseItem> items)?
      onExport;

  const PurchaseDetailDialog({
    Key? key,
    required this.record,
    required this.purchaseItems,
    this.onEdit,
    this.onExport,
  }) : super(key: key);

  @override
  State<PurchaseDetailDialog> createState() => _PurchaseDetailDialogState();

  /// 显示采购记录详情对话框
  static Future<void> show({
    required BuildContext context,
    required PurchaseRecord record,
    required List<PurchaseItem> purchaseItems,
    VoidCallback? onEdit,
    void Function(PurchaseRecord record, List<PurchaseItem> items)? onExport,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PurchaseDetailDialog(
        record: record,
        purchaseItems: purchaseItems,
        onEdit: onEdit,
        onExport: onExport,
      ),
    );
  }
}

class _PurchaseDetailDialogState extends State<PurchaseDetailDialog> {
  final ScrollController _itemsScrollController = ScrollController();

  @override
  void dispose() {
    _itemsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exportCallback = widget.onExport;
    final record = widget.record;
    final purchaseItems = widget.purchaseItems;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(DentalIcons.shoppingCart, color: context.colors.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('采购记录详情'),
          ),
          // 导出按钮
          if (exportCallback != null)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.tokens.success,
                    context.tokens.secondaryAccent,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => exportCallback(record, purchaseItems),
                icon: Icon(Icons.download_rounded,
                    color: context.colors.onPrimary, size: 20),
                tooltip: '导出为图片',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: '关闭',
          ),
        ],
      ),
      content: SizedBox(
        width: 688,
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 采购记录基本信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.tokens.infoContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.tokens.info),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: context.colors.primary,
                    child: Icon(
                      DentalIcons.shoppingCart,
                      color: context.colors.onPrimary,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '采购记录 #${record.id}',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                            '采购日期: ${DateFormat('yyyy-MM-dd').format(record.purchaseDate)}'),
                        if (record.supplier != null)
                          Text('供应商: ${record.supplier}'),
                        if (record.doctor != null)
                          Text('采购医生: ${record.doctor}'),
                        if (record.notes != null) Text('备注: ${record.notes}'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 采购统计信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.tokens.successContainer,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.tokens.success),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context: context,
                      icon: Icons.inventory,
                      label: '总采购数量',
                      value: '${record.totalQuantity}',
                      color: context.tokens.success,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context: context,
                      icon: Icons.attach_money,
                      label: '总采购金额',
                      value: '¥${record.totalAmount.toStringAsFixed(2)}',
                      color: context.tokens.info,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      context: context,
                      icon: Icons.shopping_cart,
                      label: '采购项目数',
                      value: '${purchaseItems.length}',
                      color: context.tokens.warning,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 采购项目列表标题
            Row(
              children: [
                Icon(Icons.list_alt, color: context.tokens.iconMuted, size: 20),
                const SizedBox(width: 6),
                Text(
                  '采购项目明细 (${purchaseItems.length}项)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // 采购项目列表
            Expanded(
              child: purchaseItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: context.tokens.iconMuted,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无采购项目',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: context.colors.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击上方按钮编辑记录添加采购项目',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: context.tokens.textMuted,
                                ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: context.tokens.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.tokens.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // 表头
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 12),
                            decoration: BoxDecoration(
                              color: context.tokens.mutedBackground,
                              border: Border(
                                bottom:
                                    BorderSide(color: context.tokens.border),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 7,
                                  child: Text(
                                    '材料名称',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '数量',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    '单价',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    '单位',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    '总价',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: context.colors.onSurfaceVariant,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // 项目列表
                          Expanded(
                            child: Scrollbar(
                              controller: _itemsScrollController,
                              thumbVisibility: purchaseItems.length > 5,
                              child: ListView.builder(
                                controller: _itemsScrollController,
                                itemCount: purchaseItems.length,
                                itemBuilder: (context, index) {
                                  final item = purchaseItems[index];
                                  return _buildDetailItemCard(context, item);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onEdit != null)
          ElevatedButton.icon(
            onPressed: widget.onEdit,
            icon: const Icon(Icons.edit, size: 18),
            label: const Text('编辑'),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close, size: 18),
          label: const Text('取消'),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: context.tokens.textMuted,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailItemCard(BuildContext context, PurchaseItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        border: Border(
          bottom: BorderSide(color: context.tokens.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Text(
              item.materialName,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              '${item.quantity}',
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '¥${item.unitPrice.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              item.unit ?? '',
              style: const TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              '¥${item.totalPrice.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: context.tokens.info,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

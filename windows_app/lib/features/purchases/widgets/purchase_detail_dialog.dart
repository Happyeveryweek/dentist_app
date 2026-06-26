import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/purchase_record.dart';
import '../../../models/purchase_item.dart';
import '../../../widgets/dental_icons.dart';

/// 采购记录详情对话框
class PurchaseDetailDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final exportCallback = onExport;
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      title: Row(
        children: [
          Icon(DentalIcons.shoppingCart, color: Theme.of(context).primaryColor),
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
                  colors: [Colors.green.shade400, Colors.green.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: () => exportCallback(record, purchaseItems),
                icon: const Icon(Icons.download_rounded,
                    color: Colors.white, size: 20),
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
        height: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 采购记录基本信息
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: Theme.of(context).primaryColor,
                    child: const Icon(
                      DentalIcons.shoppingCart,
                      color: Colors.white,
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
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.inventory,
                      label: '总采购数量',
                      value: '${record.totalQuantity}',
                      color: Colors.green.shade700,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.attach_money,
                      label: '总采购金额',
                      value: '¥${record.totalAmount.toStringAsFixed(2)}',
                      color: Colors.blue.shade700,
                    ),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.shopping_cart,
                      label: '采购项目数',
                      value: '${purchaseItems.length}',
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 采购项目列表标题
            Row(
              children: [
                Icon(Icons.list_alt, color: Colors.grey[600], size: 20),
                const SizedBox(width: 6),
                Text(
                  '采购项目明细 (${purchaseItems.length}项)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                if (onEdit != null)
                  ElevatedButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('编辑记录'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '暂无采购项目',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点击上方按钮编辑记录添加采购项目',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[500],
                                ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // 表头
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 7,
                                child: Text(
                                  '材料名称',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
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
                                    color: Colors.grey[700],
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
                                    color: Colors.grey[700],
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
                                    color: Colors.grey[700],
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
                                    color: Colors.grey[700],
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
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: purchaseItems.length,
                            itemBuilder: (context, index) {
                              final item = purchaseItems[index];
                              return _buildDetailItemCard(item);
                            },
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildStatItem({
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
                color: Colors.grey[600],
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

  Widget _buildDetailItemCard(PurchaseItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade200),
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
                color: Colors.blue[700],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

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

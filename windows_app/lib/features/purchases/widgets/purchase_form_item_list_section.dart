import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 采购记录表单的采购项目列表区域
/// 包含：项目列表、添加项目按钮、项目编辑（材料名称、数量、单位、单价、总价）
class PurchaseFormItemListSection extends StatelessWidget {
  final List<Map<String, dynamic>> purchaseItems;
  final List<TextEditingController> materialNameControllers;
  final List<TextEditingController> quantityControllers;
  final List<TextEditingController> unitPriceControllers;
  final List<TextEditingController> unitControllers;
  final Function(int) onAddItem;
  final Function(int) onRemoveItem;
  final Function(int, String) onMaterialNameChanged;
  final Function(int, int) onQuantityChanged;
  final Function(int, String) onUnitChanged;
  final Function(int, double) onUnitPriceChanged;
  final Function(int) onMaterialSelect;

  const PurchaseFormItemListSection({
    super.key,
    required this.purchaseItems,
    required this.materialNameControllers,
    required this.quantityControllers,
    required this.unitPriceControllers,
    required this.unitControllers,
    required this.onAddItem,
    required this.onRemoveItem,
    required this.onMaterialNameChanged,
    required this.onQuantityChanged,
    required this.onUnitChanged,
    required this.onUnitPriceChanged,
    required this.onMaterialSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.successContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.tokens.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.shopping_cart, color: context.tokens.success, size: 20),
              const SizedBox(width: 8),
              Text(
                '采购项目',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.tokens.success,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.tokens.primaryAccent.withValues(alpha: 0.3)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => onAddItem(0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add,
                              color: context.tokens.primaryAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '添加项目',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.tokens.primaryAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (purchaseItems.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.tokens.mutedBackground,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.tokens.border),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 7,
                  child: Text(
                    '材料名称',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '选择',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    '数量',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: Text(
                    '单位',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Text(
                    '单价',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Text(
                    '总价',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '操作',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: context.colors.onSurface,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: purchaseItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: context.tokens.inputBackground,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: context.tokens.iconMuted,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无采购项目',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击"添加项目"开始添加采购项目',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.tokens.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: purchaseItems.length,
                  itemBuilder: (context, index) {
                    final item = purchaseItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.tokens.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.tokens.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 7,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.tokens.inputBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextField(
                                controller: materialNameControllers[index],
                                decoration: const InputDecoration(
                                  hintText: '材料名称',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: (value) =>
                                    onMaterialNameChanged(index, value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 40,
                            child: Center(
                              child: InkWell(
                                onTap: () => onMaterialSelect(index),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: context.tokens.primaryAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(Icons.search,
                                      size: 16, color: context.tokens.primaryAccent),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.tokens.inputBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextField(
                                controller: quantityControllers[index],
                                decoration: const InputDecoration(
                                  hintText: '数量',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final quantity = int.tryParse(value) ?? 1;
                                  onQuantityChanged(index, quantity);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.tokens.inputBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextField(
                                controller: unitControllers[index],
                                decoration: const InputDecoration(
                                  hintText: '单位',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                                onChanged: (value) =>
                                    onUnitChanged(index, value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.tokens.inputBackground,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextField(
                                controller: unitPriceControllers[index],
                                decoration: const InputDecoration(
                                  hintText: '单价',
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 14),
                                textAlign: TextAlign.center,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                onChanged: (value) {
                                  final unitPrice =
                                      double.tryParse(value) ?? 0.0;
                                  onUnitPriceChanged(index, unitPrice);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Container(
                              height: 40,
                              decoration: BoxDecoration(
                                color: context.tokens.successContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '¥${item['totalPrice'].toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: context.tokens.success,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => onRemoveItem(index),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: context.tokens.errorContainer,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(Icons.delete_outline,
                                  size: 16, color: context.tokens.error),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

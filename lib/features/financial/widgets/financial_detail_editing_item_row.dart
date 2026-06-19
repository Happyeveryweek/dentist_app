import 'package:flutter/material.dart';
import '../../../widgets/modern_date_picker.dart';
import '../helpers/amount_input_formatter.dart';
import '../helpers/financial_payment_method_helper.dart';
import 'financial_detail_table_layout.dart';

/// 财务详情页编辑行组件
/// 用于内联编辑收费项的表单行
class FinancialDetailEditingItemRow extends StatelessWidget {
  final TextEditingController chargeDateController;
  final TextEditingController itemNameController;
  final String? paymentMethod;
  final TextEditingController itemPriceController;
  final TextEditingController processingFeeController;
  final TextEditingController totalPriceController;
  final DateTime chargeDate;
  final Future<DateTime?> Function() onDateSelect;
  final ValueChanged<String?> onPaymentMethodChanged;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  const FinancialDetailEditingItemRow({
    super.key,
    required this.chargeDateController,
    required this.itemNameController,
    required this.paymentMethod,
    required this.itemPriceController,
    required this.processingFeeController,
    required this.totalPriceController,
    required this.chargeDate,
    required this.onDateSelect,
    required this.onPaymentMethodChanged,
    required this.onSave,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: FinancialDetailTableLayout.rowHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.blue[100]!, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.blue[200]!.withOpacity(0.2),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: FinancialDetailTableLayout.buildRow(
          children: [
            InkWell(
              onTap: () async {
                final date = await onDateSelect();
                if (date != null) {
                  // The parent widget should handle the state update.
                }
              },
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 12, color: Colors.blue[600]),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        chargeDateController.text,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: itemNameController,
                onTap: () {
                  if (itemNameController.text == '综合收费') {
                    itemNameController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: itemNameController.text.length,
                    );
                  }
                },
                decoration: const InputDecoration(
                  hintText: '收费项目',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: DropdownButtonFormField<String>(
                value: FinancialPaymentMethodHelper.uiValue(paymentMethod),
                hint: Text(
                  '未选择',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 2),
                ),
                icon: Icon(Icons.arrow_drop_down,
                    color: Colors.grey[600], size: 16),
                isExpanded: true,
                menuMaxHeight: 220,
                borderRadius: BorderRadius.circular(6),
                dropdownColor: Colors.white,
                items: FinancialPaymentMethodHelper.dropdownMethods
                    .map(
                      (method) => DropdownMenuItem<String>(
                        value: method,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Row(
                            children: [
                              if (method ==
                                  FinancialPaymentMethodHelper.nonePaymentMethod)
                                Icon(
                                  Icons.do_not_disturb_alt,
                                  size: 14,
                                  color: Colors.grey[500],
                                )
                              else
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: Image.asset(
                                    FinancialPaymentMethodHelper.iconAssetPath(method),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  method == FinancialPaymentMethodHelper.nonePaymentMethod
                                      ? '无'
                                      : FinancialPaymentMethodHelper
                                          .displayNameOrDefault(method),
                                  style: const TextStyle(fontSize: 12),
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onPaymentMethodChanged,
              ),
            ),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: itemPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [amountInputFormatter],
                textAlign: TextAlign.center,
                onTap: () {
                  if (itemPriceController.text == '0') {
                    itemPriceController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: itemPriceController.text.length,
                    );
                  }
                },
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: totalPriceController,
                keyboardType: TextInputType.number,
                inputFormatters: [amountInputFormatter],
                textAlign: TextAlign.center,
                onTap: () {
                  if (totalPriceController.text == '0') {
                    totalPriceController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: totalPriceController.text.length,
                    );
                  }
                },
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextField(
                controller: processingFeeController,
                keyboardType: TextInputType.number,
                inputFormatters: [amountInputFormatter],
                textAlign: TextAlign.center,
                onTap: () {
                  if (processingFeeController.text == '0') {
                    processingFeeController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: processingFeeController.text.length,
                    );
                  }
                },
                decoration: const InputDecoration(
                  hintText: '0',
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onSave,
                  icon: Icon(Icons.check, color: Colors.green[600], size: 16),
                  tooltip: '保存',
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(Icons.close, color: Colors.grey[600], size: 16),
                  tooltip: '取消',
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

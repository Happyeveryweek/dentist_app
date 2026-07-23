import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/widgets/compact_dropdown_form_field.dart';
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
    final tokens = context.tokens;
    return SizedBox(
      height: FinancialDetailTableLayout.rowHeight,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.primaryAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: tokens.primaryAccent.withValues(alpha: 0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: tokens.primaryAccent.withValues(alpha: 0.2),
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
              mouseCursor: SystemMouseCursors.click,
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
                  color: tokens.cardBackground,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: tokens.primaryAccent),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today,
                        size: 12, color: tokens.primaryAccent),
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
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.divider),
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
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.divider),
              ),
              child: CompactDropdownFormField<String>(
                key: const Key('financial-payment-method-editor'),
                value: FinancialPaymentMethodHelper.uiValue(paymentMethod),
                centerSelectedItem: true,
                menuWidth: 140,
                menuMaxHeight: 160,
                borderRadius: 6,
                hint: Text(
                  '未选择',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11),
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.fromLTRB(2, 0, 2, 4),
                ),
                selectedItemBuilder: (context, method) => Center(
                  child: method ==
                          FinancialPaymentMethodHelper.nonePaymentMethod
                      ? Icon(
                          Icons.do_not_disturb_alt,
                          size: 16,
                          color: tokens.textMuted,
                        )
                      : SizedBox(
                          width: 18,
                          height: 18,
                          child: Image.asset(
                            FinancialPaymentMethodHelper.iconAssetPath(method),
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                          ),
                        ),
                ),
                items: FinancialPaymentMethodHelper.dropdownMethods
                    .map(
                      (method) => CompactDropdownItem<String>(
                        value: method,
                        child: Row(
                          children: [
                            if (method ==
                                FinancialPaymentMethodHelper.nonePaymentMethod)
                              Icon(
                                Icons.do_not_disturb_alt,
                                size: 14,
                                color: tokens.textMuted,
                              )
                            else
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: Image.asset(
                                  FinancialPaymentMethodHelper.iconAssetPath(
                                      method),
                                  fit: BoxFit.contain,
                                ),
                              ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                method ==
                                        FinancialPaymentMethodHelper
                                            .nonePaymentMethod
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
                    )
                    .toList(),
                onChanged: onPaymentMethodChanged,
              ),
            ),
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.divider),
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
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.divider),
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
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tokens.divider),
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
                  icon: Icon(Icons.check, color: tokens.success, size: 16),
                  tooltip: '保存',
                  padding: const EdgeInsets.all(4),
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: Icon(Icons.close, color: tokens.textMuted, size: 16),
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

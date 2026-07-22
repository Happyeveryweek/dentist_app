import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/utils/datetime_formatter.dart';
import 'package:dentist_app/widgets/modern_date_picker.dart';
import '../helpers/amount_input_formatter.dart';
import 'payment_method_dropdown_field.dart';
import 'section_title.dart';

class ChargeInfoSection extends StatelessWidget {
  final TextEditingController chargeDateController;
  final TextEditingController itemNameController;
  final TextEditingController receivableAmountController;
  final TextEditingController collectedAmountController;
  final TextEditingController processingFeeController;
  final String? paymentMethod;
  final FocusNode receivableFocusNode;
  final FocusNode collectedFocusNode;
  final FocusNode processingFocusNode;
  final ValueChanged<String?> onPaymentMethodChanged;
  final String? Function(String?) itemNameValidator;
  final String? Function(String?) receivableValidator;
  final String? Function(String?) collectedValidator;
  final String? Function(String?) processingValidator;

  const ChargeInfoSection({
    super.key,
    required this.chargeDateController,
    required this.itemNameController,
    required this.receivableAmountController,
    required this.collectedAmountController,
    required this.processingFeeController,
    required this.paymentMethod,
    required this.receivableFocusNode,
    required this.collectedFocusNode,
    required this.processingFocusNode,
    required this.onPaymentMethodChanged,
    required this.itemNameValidator,
    required this.receivableValidator,
    required this.collectedValidator,
    required this.processingValidator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(
          title: '收费信息',
          icon: Icons.receipt,
          color: Colors.green,
        ),
        const SizedBox(height: 8),

        // 收费日期和项目名称 - 紧凑布局
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: chargeDateController,
                decoration: InputDecoration(
                  labelText: '收费日期',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  suffixIcon: const Icon(Icons.calendar_today, size: 18),
                ),
                readOnly: true,
                onTap: () async {
                  final date = await showDialog<DateTime>(
                    context: context,
                    builder: (BuildContext context) {
                      return ModernDatePickerDialog(
                        initialDate: DateTimeFormatter.nowLocal(),
                        firstDate: DateTime(2020),
                        lastDate: DateTimeFormatter.nowLocal().add(
                          const Duration(days: 365),
                        ),
                        title: '选择收费日期',
                      );
                    },
                  );
                  if (date != null) {
                    chargeDateController.text = DateFormat(
                      'yyyy-MM-dd',
                    ).format(date);
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 收费项目名称
        TextFormField(
          controller: itemNameController,
          decoration: InputDecoration(
            labelText: '项目名称',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 14,
            ),
            hintText: '请输入收费项目名称',
          ),
          validator: itemNameValidator,
        ),

        const SizedBox(height: 12),

        // 金额信息 - 紧凑的网格布局
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: receivableAmountController,
                focusNode: receivableFocusNode,
                decoration: InputDecoration(
                  labelText: '应收费',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  prefixText: '¥',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [amountInputFormatter],
                validator: receivableValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: collectedAmountController,
                focusNode: collectedFocusNode,
                decoration: InputDecoration(
                  labelText: '已收费',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  prefixText: '¥',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [amountInputFormatter],
                validator: collectedValidator,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // 加工费 + 收费方式
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: processingFeeController,
                focusNode: processingFocusNode,
                decoration: InputDecoration(
                  labelText: '加工费',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  prefixText: '¥',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [amountInputFormatter],
                validator: processingValidator,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PaymentMethodDropdownField(
                value: paymentMethod,
                onChanged: onPaymentMethodChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

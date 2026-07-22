import 'package:dentist_app/features/financial/helpers/financial_payment_method_helper.dart';
import 'package:flutter/material.dart';

class PaymentMethodDropdownField extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  final Color iconColor;

  const PaymentMethodDropdownField({
    super.key,
    required this.value,
    required this.onChanged,
    this.iconColor = Colors.green,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue = FinancialPaymentMethodHelper.uiValue(value);
    return LayoutBuilder(
      builder:
          (context, constraints) => PopupMenuButton<String>(
            initialValue: selectedValue,
            onSelected: onChanged,
            position: PopupMenuPosition.under,
            offset: const Offset(0, 4),
            constraints: BoxConstraints.tightFor(width: constraints.maxWidth),
            color: Colors.white,
            elevation: 6,
            menuPadding: const EdgeInsets.symmetric(vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            itemBuilder:
                (context) =>
                    FinancialPaymentMethodHelper.dropdownMethods.map((method) {
                      return PopupMenuItem<String>(
                        value: method,
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: _PaymentMethodRow(method: method),
                      );
                    }).toList(),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: '收费方式',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                prefixIcon: Icon(Icons.payment, size: 18, color: iconColor),
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
              ),
              child: Text(
                _displayName(selectedValue),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  final String method;

  const _PaymentMethodRow({required this.method});

  @override
  Widget build(BuildContext context) {
    final iconPath = FinancialPaymentMethodHelper.iconAssetPathOrNull(method);
    return Row(
      children: [
        SizedBox(
          width: 20,
          child:
              iconPath == null
                  ? const Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 16,
                    color: Colors.grey,
                  )
                  : Image.asset(
                    iconPath,
                    width: 16,
                    height: 16,
                    errorBuilder:
                        (_, __, ___) => const Icon(Icons.payment, size: 16),
                  ),
        ),
        const SizedBox(width: 8),
        Text(_displayName(method)),
      ],
    );
  }
}

String _displayName(String method) {
  return method == FinancialPaymentMethodHelper.nonePaymentMethod
      ? '未选择'
      : FinancialPaymentMethodHelper.displayName(method);
}

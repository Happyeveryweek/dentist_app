import 'package:dentist_app/features/financial/helpers/financial_payment_method_helper.dart';
import 'package:dentist_app/features/financial/widgets/payment_method_dropdown_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('收费方式菜单使用紧凑行高并可正常选择', (tester) async {
    String? selected = FinancialPaymentMethodHelper.nonePaymentMethod;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 220,
              child: StatefulBuilder(
                builder:
                    (context, setState) => PaymentMethodDropdownField(
                      value: selected,
                      onChanged: (value) {
                        setState(() => selected = value);
                      },
                    ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('未选择'));
    await tester.pumpAndSettle();

    final items = tester.widgetList<PopupMenuItem<String>>(
      find.byType(PopupMenuItem<String>),
    );
    expect(items, hasLength(4));
    expect(items.every((item) => item.height == 40), isTrue);

    await tester.tap(find.text('微信'));
    await tester.pumpAndSettle();

    expect(selected, 'wechat');
  });
}

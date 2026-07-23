import 'package:dentist_app_windows/features/financial/helpers/financial_payment_method_helper.dart';
import 'package:dentist_app_windows/features/financial/widgets/financial_detail_editing_item_row.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/widgets/compact_dropdown_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('收费方式选中图标使用居中布局', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme.copyWith(
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          iconButtonTheme: const IconButtonThemeData(
            style: ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(28, 28)),
              padding: WidgetStatePropertyAll(EdgeInsets.all(3)),
            ),
          ),
        ),
        home: Scaffold(
          body: SizedBox(
            width: 1000,
            child: FinancialDetailEditingItemRow(
              chargeDateController: TextEditingController(text: '2026-07-22'),
              itemNameController: TextEditingController(text: '综合收费'),
              paymentMethod: FinancialPaymentMethodHelper.defaultPaymentMethod,
              itemPriceController: TextEditingController(text: '30'),
              processingFeeController: TextEditingController(text: '0'),
              totalPriceController: TextEditingController(text: '30'),
              chargeDate: DateTime(2026, 7, 22),
              onDateSelect: () async => null,
              onPaymentMethodChanged: (_) {},
              onSave: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final dropdownCenter =
        tester.getCenter(find.byType(CompactDropdownFormField<String>));
    final editorCenter = tester.getCenter(
      find.byKey(const Key('financial-payment-method-editor')),
    );
    final iconCenter = tester.getCenter(find.byType(Image));
    final rowCenter =
        tester.getCenter(find.byType(FinancialDetailEditingItemRow));

    expect(
      (rowCenter.dy - iconCenter.dy).abs(),
      lessThanOrEqualTo(1),
      reason: 'row=$rowCenter, dropdown=$dropdownCenter, icon=$iconCenter',
    );
    expect(
      (editorCenter.dx - iconCenter.dx).abs(),
      lessThanOrEqualTo(1),
      reason:
          'editor=$editorCenter, dropdown=$dropdownCenter, icon=$iconCenter',
    );
  });
}

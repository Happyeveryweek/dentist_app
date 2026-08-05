import 'package:dentist_app/widgets/single_line_amount_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('7位金额在窄卡片中保持单行显示', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 64,
            child: SingleLineAmountText(text: '¥1,234,567'),
          ),
        ),
      ),
    );

    final amountText = tester.widget<Text>(find.text('¥1,234,567'));
    expect(amountText.maxLines, 1);
    expect(amountText.softWrap, isFalse);
    expect(tester.takeException(), isNull);
  });
}

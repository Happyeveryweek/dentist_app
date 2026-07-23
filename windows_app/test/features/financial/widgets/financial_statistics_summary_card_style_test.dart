import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('收费统计顶部卡片使用浅色底板', () {
    final source = File(
      'lib/features/financial/widgets/financial_statistics_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('color: cardColor.withValues(alpha: 0.1)'));
    expect(source, contains('color: paymentCardColor.withValues(alpha: 0.1)'));
    expect(
        source,
        isNot(contains('color: cardColor,\n'
            '        borderRadius: BorderRadius.circular(tokens.borderRadius),\n'
            '        boxShadow: tokens.cardShadow')));
  });
}

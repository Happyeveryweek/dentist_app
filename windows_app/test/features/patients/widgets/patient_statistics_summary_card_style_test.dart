import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('患者统计顶部卡片使用浅色底板', () {
    final source = File(
      'lib/features/patients/widgets/patient_statistics_dialog.dart',
    ).readAsStringSync();

    expect(source, contains('color: cardColor.withValues(alpha: 0.1)'));
    expect(source, isNot(contains('color: cardColor.withValues(alpha: 0.3)')));
  });
}

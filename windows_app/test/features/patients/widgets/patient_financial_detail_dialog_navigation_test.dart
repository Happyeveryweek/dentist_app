import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('患者详情查看收费记录复用财务详情弹窗', () {
    final source =
        File('lib/screens/patient_detail_screen.dart').readAsStringSync();

    expect(source, contains('await showFinancialDetailDialog('));
    expect(
        source,
        isNot(contains('Navigator.push(\n'
            '      context,\n'
            '      MaterialPageRoute(\n'
            '        builder: (context) => FinancialDetailScreen(')));
  });
}

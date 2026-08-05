import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('患者表单预约设置独立于牙位输入区', () {
    final source = File(
      'lib/features/patients/widgets/patient_form_dental_section.dart',
    ).readAsStringSync();

    expect(source, contains("'已安排预约'"));
    expect(source, contains("'安排下次预约'"));
    expect(source, contains('开启后可选择需要关联的牙位'));
    expect(source, contains('const BoxConstraints(maxWidth: 210)'));
    expect(source, contains('const SizedBox(width: 12)'));
    expect(source, contains('cursor: SystemMouseCursors.click'));
    expect(source, isNot(contains("'预约：是'")));
    expect(source, isNot(contains("'预约：否'")));
  });

  test('患者表单治疗项目与底部操作栏保留间距', () {
    final source = File(
      'lib/features/patients/widgets/patient_form_dialog.dart',
    ).readAsStringSync();
    final treatmentIndex = source.indexOf('PatientFormTreatmentSection(');
    final actionsIndex = source.indexOf('PatientFormActions(');

    expect(treatmentIndex, isNonNegative);
    expect(actionsIndex, greaterThan(treatmentIndex));
    expect(
      source.substring(treatmentIndex, actionsIndex),
      contains('const SizedBox(height: 16)'),
    );
  });
}

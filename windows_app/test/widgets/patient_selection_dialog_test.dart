import 'package:dentist_app_windows/models/patient.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/widgets/patient_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('患者选择弹窗使用紧凑布局且不展示电话', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final patients = [
      Patient(
        name: '张三',
        namePinyin: 'zhang san',
        nameInitials: 'zs',
        age: 30,
        gender: '男',
        phone: '13800138000',
        medicalRecordNumber: 1001,
        firstVisitDate: DateTime(2024),
        updatedAt: DateTime(2026, 7, 20),
      ),
      Patient(
        name: '李四',
        age: 28,
        gender: '女',
        phone: '13900139000',
        medicalRecordNumber: 1002,
        firstVisitDate: DateTime(2024),
        updatedAt: DateTime(2026, 7, 21),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PatientSelectionDialog(patients: patients),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panel = find.byWidgetPredicate(
      (widget) =>
          widget is Container &&
          widget.constraints?.minWidth == 480 &&
          widget.constraints?.maxWidth == 480,
    );
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, 480);
    expect(tester.getSize(panel).height, lessThanOrEqualTo(352));
    expect(find.text('病历号'), findsOneWidget);
    expect(find.text('姓名'), findsOneWidget);
    expect(find.text('最近就诊'), findsOneWidget);
    expect(find.text('姓名 / 电话'), findsNothing);
    expect(find.text('13800138000'), findsNothing);
    expect(find.text('13900139000'), findsNothing);

    await tester.enterText(find.byType(TextField), '13800138000');
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    expect(find.text('李四'), findsNothing);
  });
}

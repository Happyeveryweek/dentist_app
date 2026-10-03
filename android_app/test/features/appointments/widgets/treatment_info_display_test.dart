import 'dart:convert';

import 'package:dentist_app/features/appointments/widgets/treatment_info_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('查看预约没有牙位时仍显示三个十字', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: TreatmentInfoDisplay(treatmentTypeJson: '')),
      ),
    );

    expect(find.text('牙位 1'), findsOneWidget);
    expect(find.text('牙位 2'), findsOneWidget);
    expect(find.text('牙位 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('查看预约只有一个牙位时补齐三个十字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TreatmentInfoDisplay(
            treatmentTypeJson: jsonEncode({
              'teethData': [
                {
                  'topLeft': '6',
                  'topRight': '',
                  'bottomLeft': '',
                  'bottomRight': '',
                },
              ],
            }),
          ),
        ),
      ),
    );

    expect(find.text('牙位 3'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

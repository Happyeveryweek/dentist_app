import 'dart:convert';

import 'package:dentist_app_windows/features/appointments/widgets/appointment_treatment_utils.dart';
import 'package:dentist_app_windows/features/appointments/widgets/teeth_condition_widget.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts and deduplicates treatment items from appointment JSON', () {
    const source = '{"teethData":[],"treatments":["综合治疗","洁牙","综合治疗"]}';

    expect(
      extractAppointmentTreatments(source),
      ['综合治疗', '洁牙'],
    );
  });

  test('builds treatment data accepted by the appointment form', () {
    final encoded = buildAppointmentTreatmentData(
      ['综合治疗'],
      teethData: [
        {
          'topLeft': '11',
          'topRight': '',
          'bottomLeft': '',
          'bottomRight': '48',
        },
      ],
    );

    expect(extractAppointmentTreatments(encoded), ['综合治疗']);
    final decoded = json.decode(encoded) as Map<String, dynamic>;
    expect(decoded['teethData'], hasLength(1));
    expect(decoded['teethData'][0]['topLeft'], '11');
    expect(decoded['teethData'][0]['bottomRight'], '48');
  });

  testWidgets('appointment editor renders imported teeth cross count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TeethConditionWidget(
            key: const ValueKey('single-cross'),
            teethData: const [
              {
                'topLeft': '5',
                'topRight': '6',
                'bottomLeft': '',
                'bottomRight': '',
              },
            ],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('牙位 1'), findsOneWidget);
    expect(find.text('牙位 2'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: TeethConditionWidget(
            key: const ValueKey('three-crosses'),
            teethData: List.generate(
              3,
              (_) => {
                'topLeft': '',
                'topRight': '',
                'bottomLeft': '',
                'bottomRight': '',
              },
            ),
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('牙位 1'), findsOneWidget);
    expect(find.text('牙位 2'), findsOneWidget);
    expect(find.text('牙位 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

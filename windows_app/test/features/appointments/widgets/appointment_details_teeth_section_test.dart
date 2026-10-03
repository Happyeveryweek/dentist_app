import 'package:dentist_app_windows/features/appointments/widgets/appointment_details_teeth_section.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('查看预约没有牙位时仍显示三个十字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AppointmentDetailsTeethSection(teethData: []),
        ),
      ),
    );

    expect(find.text('牙位 1'), findsOneWidget);
    expect(find.text('牙位 2'), findsOneWidget);
    expect(find.text('牙位 3'), findsOneWidget);
    expect(find.text('暂无牙位信息'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('查看预约旧的两个十字时补齐第三个', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AppointmentDetailsTeethSection(
            teethData: [
              {
                'topLeft': '5',
                'topRight': '6',
                'bottomLeft': '',
                'bottomRight': '',
              },
              {
                'topLeft': '',
                'topRight': '',
                'bottomLeft': '',
                'bottomRight': '',
              },
            ],
          ),
        ),
      ),
    );

    expect(find.text('牙位 3'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('查看预约三个十字靠左紧凑排列', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1100, 400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: AppointmentDetailsTeethSection(teethData: []),
        ),
      ),
    );

    final first = tester.getCenter(find.text('牙位 1'));
    final second = tester.getCenter(find.text('牙位 2'));
    final third = tester.getCenter(find.text('牙位 3'));

    expect(first.dx, lessThan(160));
    expect(second.dx - first.dx, lessThan(220));
    expect(third.dx - second.dx, lessThan(220));
    expect(tester.takeException(), isNull);
  });
}

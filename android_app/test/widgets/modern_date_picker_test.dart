import 'package:dentist_app/widgets/modern_date_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('单日期选择器支持左右滑动切换月份', (tester) async {
    final originalPhysicalSize = tester.view.physicalSize;
    final originalDevicePixelRatio = tester.view.devicePixelRatio;
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(() {
      tester.view
        ..physicalSize = originalPhysicalSize
        ..devicePixelRatio = originalDevicePixelRatio;
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ModernDatePickerDialog(
          initialDate: DateTime(2026, 8, 5),
          title: '选择日期',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('八月 2026'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(find.text('九月 2026'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(find.text('八月 2026'), findsOneWidget);
  });
}

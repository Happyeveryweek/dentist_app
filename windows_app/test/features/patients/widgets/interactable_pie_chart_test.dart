import 'dart:ui';

import 'package:dentist_app_windows/features/patients/widgets/interactable_pie_chart.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('悬停右侧比例时饼图对应扇区和文字一起高亮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.resolve(WindowsThemeVariant.purplePinkGray),
        home: Scaffold(
          body: SizedBox(
            width: 520,
            height: 280,
            child: InteractablePieChart(
              data: const {'女': 10, '男': 5},
              chartType: '性别分布',
              onSectionTap: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_sectionRadius(tester, 0), 50);
    expect(_sectionRadius(tester, 1), 50);
    expect(_legendWeight(tester, '男'), FontWeight.normal);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.textContaining('男:')));
    await tester.pump();

    expect(_legendWeight(tester, '男'), FontWeight.bold);
    expect(_legendWeight(tester, '女'), FontWeight.normal);
    expect(_sectionRadius(tester, 1), 60);
    expect(_sectionRadius(tester, 0), 50);

    await gesture.moveTo(Offset.zero);
    await tester.pump();

    expect(_legendWeight(tester, '男'), FontWeight.normal);
    expect(_sectionRadius(tester, 1), 50);
  });
}

double _sectionRadius(WidgetTester tester, int index) {
  final chart = tester.widget<PieChart>(find.byType(PieChart));
  return chart.data.sections[index].radius;
}

FontWeight? _legendWeight(WidgetTester tester, String category) {
  final text = tester.widget<Text>(find.textContaining('$category:'));
  return text.style?.fontWeight;
}

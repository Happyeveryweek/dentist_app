import 'package:dentist_app_windows/features/materials/widgets/material_type_filter_dropdown.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _types = [
  '全部',
  '药品',
  '局部麻醉药',
  '消毒用品',
  '一次性用品',
  '牙科材料',
  '牙科器械',
  '根管治疗器械',
  '牙科耗材',
  '正畸材料',
  '口腔护理用品',
  '防护用品',
  '办公用品',
  '其他',
];

void main() {
  testWidgets('滚动材料类型时标题和全部保持在顶部并可选择', (tester) async {
    var selected = '其他';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.resolve(WindowsThemeVariant.purplePinkGray),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: StatefulBuilder(
              builder: (context, setState) {
                return MaterialTypeFilterDropdown(
                  value: selected,
                  items: _types,
                  onChanged: (value) {
                    setState(() => selected = value);
                  },
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(MaterialTypeFilterDropdown));
    await tester.pumpAndSettle();

    final header = find.text('材料类型');
    final all = find.text('全部');
    expect(header, findsOneWidget);
    expect(all, findsOneWidget);

    final headerDy = tester.getTopLeft(header).dy;
    final allDy = tester.getTopLeft(all).dy;
    expect(headerDy, lessThan(allDy));

    final listPosition = tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        )
        .position;
    expect(listPosition.pixels, 0);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(listPosition.pixels, greaterThan(80));
    expect(tester.getTopLeft(header).dy, closeTo(headerDy, 0.5));
    expect(tester.getTopLeft(all).dy, closeTo(allDy, 0.5));

    final lastType = find.descendant(
      of: find.byType(ListView),
      matching: find.text('其他'),
    );
    expect(lastType, findsOneWidget);
    expect(
        tester.getTopLeft(lastType).dy, greaterThan(tester.getTopLeft(all).dy));

    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(selected, '全部');
    expect(find.text('材料类型'), findsNothing);
  });
}

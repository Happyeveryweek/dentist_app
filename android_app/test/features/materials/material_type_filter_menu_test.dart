import 'package:dentist_app/features/materials/services/material_catalog.dart';
import 'package:dentist_app/features/materials/widgets/material_type_filter_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('滚动材料类型时标题和全部保持在顶部并可选择', (tester) async {
    var selected = '其他';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 220,
            child: StatefulBuilder(
              builder: (context, setState) {
                return MaterialTypeFilterMenu(
                  value: selected,
                  items: materialTypeOptions,
                  onSelected: (value) => setState(() => selected = value),
                );
              },
            ),
          ),
        ),
      ),
    );

    final header = find.text('材料类型');
    final all = find.text('全部');
    expect(header, findsOneWidget);
    expect(all, findsOneWidget);
    final headerDy = tester.getTopLeft(header).dy;
    final allDy = tester.getTopLeft(all).dy;
    expect(headerDy, lessThan(allDy));

    await tester.scrollUntilVisible(
      find.text('其他'),
      80,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(header).dy, closeTo(headerDy, 0.5));
    expect(tester.getTopLeft(all).dy, closeTo(allDy, 0.5));
    expect(
      tester.getTopLeft(find.text('其他')).dy,
      greaterThan(tester.getTopLeft(all).dy),
    );

    await tester.tap(all);
    await tester.pump();
    expect(selected, '全部');
  });
}

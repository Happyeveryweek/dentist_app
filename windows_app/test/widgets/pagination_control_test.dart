import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/widgets/pagination_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('页码跳转的文字和输入框在同一中线', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PaginationControl(
            currentPage: 1,
            pageSize: 10,
            totalRecords: 2118,
            onPageChanged: (_) {},
          ),
        ),
      ),
    );

    final label = tester.getRect(find.text('转到'));
    final hint = tester.getRect(find.text('页码'));
    final button = tester.getRect(find.text('确定'));
    final field = tester.getRect(find.byType(TextField));

    expect((hint.center.dy - label.center.dy).abs(), lessThan(2));
    expect((button.center.dy - label.center.dy).abs(), lessThan(2));
    expect((field.center.dy - label.center.dy).abs(), lessThan(2));

    final decoration =
        tester.widget<TextField>(find.byType(TextField)).decoration;
    expect(decoration?.enabledBorder, InputBorder.none);
    expect(decoration?.focusedBorder, InputBorder.none);
    expect(decoration?.filled, isFalse);
  });

  testWidgets('输入页码后跳转并限制在总页数内', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final pages = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PaginationControl(
            currentPage: 1,
            pageSize: 10,
            totalRecords: 30,
            onPageChanged: pages.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '2');
    await tester.tap(find.text('确定'));
    await tester.pump();
    expect(pages, [2]);

    await tester.enterText(find.byType(TextField), '99');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(pages, [2, 3]);
  });
}

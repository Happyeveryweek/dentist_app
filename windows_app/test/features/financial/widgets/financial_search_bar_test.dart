import 'dart:ui';

import 'package:dentist_app_windows/features/financial/widgets/financial_search_bar.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/theme/app_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('排序按钮悬浮时显示小手光标和悬浮背景色', (tester) async {
    final theme = AppTheme.resolve(WindowsThemeVariant.purplePinkGray);
    final tokens = theme.extension<AppThemeTokens>()!;
    final searchController = TextEditingController();
    addTearDown(searchController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: FinancialSearchBar(
            displayMode: 'patient',
            searchController: searchController,
            searchQuery: '',
            sortBy: 'charge_date',
            sortAscending: false,
            startDate: null,
            endDate: null,
            hasAdvancedFilter: false,
            searchReadOnly: false,
            onSearchChanged: (_) {},
            onSearchCleared: () {},
            onSortChanged: (_) {},
            onDateRangeTap: () {},
            onDateRangeCleared: () {},
            onAdvancedFilterTap: () {},
          ),
        ),
      ),
    );

    final sortIcon = find.byIcon(Icons.sort_rounded);
    final anchorMouseRegion = find.ancestor(
      of: sortIcon,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is MouseRegion &&
            widget.cursor == SystemMouseCursors.click &&
            widget.onEnter != null,
      ),
    );
    expect(anchorMouseRegion, findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(sortIcon));
    await tester.pumpAndSettle();

    final container = tester.widget<AnimatedContainer>(
      find.ancestor(of: sortIcon, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (container.decoration as BoxDecoration).color,
      tokens.hoverBackground,
    );

    await gesture.removePointer();
  });
}

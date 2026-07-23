import 'package:dentist_app_windows/features/materials/widgets/material_stat_card.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('材料统计卡保持紧凑横向布局', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.resolve(WindowsThemeVariant.purplePinkGray),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            child: MaterialStatCard(
              icon: Icons.inventory,
              label: '材料总数',
              value: '217',
              color: Color(0xFF9C72B0),
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(MaterialStatCard)).height,
        lessThanOrEqualTo(72));
    expect(
        find.descendant(
          of: find.byType(MaterialStatCard),
          matching: find.byType(Row),
        ),
        findsOneWidget);
  });
}

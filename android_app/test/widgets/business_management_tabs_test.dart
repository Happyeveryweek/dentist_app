import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dentist_app/screens/home_screen.dart';
import 'package:dentist_app/theme/app_theme.dart';

void main() {
  testWidgets('点击业务标签后第一帧即切换选中态', (tester) async {
    final controller = TabController(length: 3, vsync: tester);
    await _pumpTabs(tester, controller);

    await tester.tap(find.text('采购'));
    await tester.pump();

    expect(_isSelected(tester, Icons.account_balance_wallet_rounded), false);
    expect(_isSelected(tester, Icons.shopping_cart_rounded), true);
    expect(_isSelected(tester, Icons.inventory_2_rounded), false);
    expect(
      _tabBackground(tester, '采购').colors.first.withValues(alpha: 1),
      AppTheme.infoColor,
    );

    await tester.tap(find.text('材料'));
    await tester.pump();
    expect(_isSelected(tester, Icons.inventory_2_rounded), true);
    expect(
      _tabBackground(tester, '材料').colors.first.withValues(alpha: 1),
      AppTheme.warningColor,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('业务内容横向拖动过半时标签同步切换选中态', (tester) async {
    final controller = TabController(length: 3, vsync: tester);
    await _pumpTabs(tester, controller);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('财务页面')),
    );
    for (var i = 0; i < 5; i++) {
      await gesture.moveBy(const Offset(-100, 0));
      await tester.pump();
    }

    expect(_isSelected(tester, Icons.account_balance_wallet_rounded), false);
    expect(_isSelected(tester, Icons.shopping_cart_rounded), true);
    expect(_isSelected(tester, Icons.inventory_2_rounded), false);

    await gesture.up();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

Future<void> _pumpTabs(WidgetTester tester, TabController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BusinessManagementTabs(controller: controller),
            ),
            Expanded(
              child: TabBarView(
                controller: controller,
                children: const [
                  Center(child: Text('财务页面')),
                  Center(child: Text('采购页面')),
                  Center(child: Text('材料页面')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _isSelected(WidgetTester tester, IconData icon) {
  final iconWidget = tester.widget<Icon>(find.byIcon(icon));
  final expectedColor = switch (icon) {
    Icons.account_balance_wallet_rounded => AppTheme.successColor,
    Icons.shopping_cart_rounded => AppTheme.infoColor,
    Icons.inventory_2_rounded => AppTheme.warningColor,
    _ => throw ArgumentError('未知的业务标签图标: $icon'),
  };
  return iconWidget.color == expectedColor;
}

LinearGradient _tabBackground(WidgetTester tester, String label) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(label), matching: find.byType(Container)).last,
  );
  final decoration = container.decoration;
  final gradient = decoration is BoxDecoration ? decoration.gradient : null;
  if (gradient is! LinearGradient) {
    throw AssertionError('业务标签选中背景缺少线性渐变: $label');
  }
  return gradient;
}

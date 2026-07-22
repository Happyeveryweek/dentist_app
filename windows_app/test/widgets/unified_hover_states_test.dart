import 'dart:ui';

import 'package:dentist_app_windows/features/dashboard/widgets/hoverable_stat_card.dart';
import 'package:dentist_app_windows/features/settings/widgets/theme_card.dart';
import 'package:dentist_app_windows/providers/settings_provider.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/theme/app_theme_tokens.dart';
import 'package:dentist_app_windows/widgets/hoverable_list_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  test('五套主题使用统一层级的悬浮色和选中色', () {
    for (final variant in WindowsThemeVariant.values) {
      final theme = AppTheme.resolve(variant);
      final tokens = theme.extension<AppThemeTokens>()!;

      expect(
          tokens.hoverBackground, tokens.primaryAccent.withValues(alpha: 0.08));
      expect(
        tokens.listItemHoverBackground,
        tokens.hoverBackground,
      );
      expect(
        tokens.selectedBackground,
        tokens.primaryAccent.withValues(alpha: 0.14),
      );
      expect(
        tokens.menuItemHoverBackground,
        tokens.primaryAccent.withValues(alpha: 0.10),
      );
      expect(
        tokens.menuItemSelectedHoverBackground,
        tokens.primaryAccent.withValues(alpha: 0.18),
      );
      expect(theme.hoverColor, tokens.hoverBackground);
      expect(theme.focusColor, tokens.focusRing);
    }
  });

  testWidgets('列表和仪表盘卡片悬浮时使用普通悬浮色', (tester) async {
    final theme = AppTheme.resolve(WindowsThemeVariant.purplePinkGray);
    final tokens = theme.extension<AppThemeTokens>()!;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Column(
            children: [
              HoverableListCard(
                onTap: () {},
                child: const Text('列表项'),
              ),
              HoverableStatCard(
                onTap: () {},
                child: const Text('统计卡片'),
              ),
            ],
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);

    await gesture.moveTo(tester.getCenter(find.text('列表项')));
    await tester.pumpAndSettle();
    expect(_animatedContainerColor(tester, find.text('列表项')),
        tokens.hoverBackground);

    await gesture.moveTo(tester.getCenter(find.text('统计卡片')));
    await tester.pumpAndSettle();
    expect(
      _animatedContainerColor(tester, find.text('统计卡片')),
      tokens.hoverBackground,
    );

    await gesture.removePointer();
  });

  testWidgets('设置主题卡片区分悬浮状态和选中状态', (tester) async {
    final theme = AppTheme.resolve(WindowsThemeVariant.purplePinkGray);
    final tokens = theme.extension<AppThemeTokens>()!;
    final settingsProvider = SettingsProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider<SettingsProvider>.value(
        value: settingsProvider,
        child: MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: ThemeCard(
              variant: WindowsThemeVariant.medicalBlue,
              title: '医疗蓝',
              subtitle: '专业清爽',
              icon: Icons.palette,
              swatches: [Color(0xFF2E7DB8)],
              isSelected: false,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.byType(ThemeCard)));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration,
      isA<BoxDecoration>().having(
        (decoration) => decoration.color,
        'color',
        tokens.hoverBackground,
      ),
    );

    await gesture.removePointer();
    settingsProvider.dispose();
  });
}

Color? _animatedContainerColor(
  WidgetTester tester,
  Finder descendant,
) {
  final finder = find.ancestor(
    of: descendant,
    matching: find.byType(AnimatedContainer),
  );
  final container = tester.widget<AnimatedContainer>(finder.first);
  return (container.decoration as BoxDecoration).color;
}

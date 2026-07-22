import 'dart:ui';

import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/features/appointments/widgets/appointment_treatment_section.dart';
import 'package:dentist_app_windows/features/patients/widgets/patient_form_fields.dart';
import 'package:dentist_app_windows/widgets/compact_dropdown_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('患者性别下拉使用36像素选项行高', (tester) async {
    String selectedGender = '男';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: StatefulBuilder(
              builder: (context, setState) => PatientFormDropdown(
                value: selectedGender,
                labelText: '性别',
                icon: Icons.person,
                items: const [
                  CompactDropdownItem(value: '男', child: Text('男')),
                  CompactDropdownItem(value: '女', child: Text('女')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => selectedGender = value);
                  }
                },
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(PatientFormDropdown));
    await tester.pumpAndSettle();

    final menuItems = _popupMenuEntries<String>();
    expect(menuItems, findsNWidgets(2));
    for (final element in menuItems.evaluate()) {
      expect(tester.getSize(find.byWidget(element.widget)).height, 36);
    }

    await tester.tap(find.text('女'));
    await tester.pumpAndSettle();
    expect(selectedGender, '女');
  });

  testWidgets('已有治疗项目未选择时不显示暂无占位文字', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SizedBox(
            width: 700,
            child: TreatmentSectionWidget(
              selectedTreatments: const [],
              treatmentTypeController: TextEditingController(),
              suggestions: const ['洗牙'],
              onTreatmentsChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('选择已有项目'), findsOneWidget);
    expect(find.text('暂无'), findsNothing);
  });

  testWidgets('紧凑下拉菜单使用受控宽度和桌面端行高', (tester) async {
    String? selectedValue = 'one';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => SizedBox(
                width: 180,
                child: CompactDropdownFormField<String>(
                  value: selectedValue,
                  decoration: const InputDecoration(
                    labelText: '预约状态',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    CompactDropdownItem(value: 'one', child: Text('选项一')),
                    CompactDropdownItem(value: 'two', child: Text('选项二')),
                    CompactDropdownItem(value: 'three', child: Text('选项三')),
                    CompactDropdownItem(value: 'four', child: Text('选项四')),
                  ],
                  onChanged: (value) {
                    setState(() => selectedValue = value);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CompactDropdownFormField<String>));
    await tester.pumpAndSettle();

    final menuItems = _popupMenuEntries<String>();
    expect(menuItems, findsNWidgets(4));
    for (final element in menuItems.evaluate()) {
      final itemFinder = find.byWidget(element.widget);
      expect(tester.getSize(itemFinder).height, 36);
      expect(tester.getSize(itemFinder).width, 180);
    }

    await tester.tap(find.text('选项二'));
    await tester.pumpAndSettle();
    expect(selectedValue, 'two');
  });

  testWidgets('紧凑下拉菜单为悬浮、选中和选中悬浮绘制单层背景', (tester) async {
    final theme = AppTheme.resolve(WindowsThemeVariant.purplePinkGray);
    final tokens = WindowsThemeVariant.purplePinkGray.tokens;

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 180,
            child: CompactDropdownFormField<String>(
              value: 'one',
              decoration: const InputDecoration(labelText: '选项'),
              items: const [
                CompactDropdownItem(value: 'one', child: Text('选项一')),
                CompactDropdownItem(value: 'two', child: Text('选项二')),
              ],
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CompactDropdownFormField<String>));
    await tester.pumpAndSettle();

    final selectedItem = _menuItemBackground(tester, find.text('选项一'));
    final unselectedItem = _menuItemBackground(tester, find.text('选项二'));
    expect(_backgroundColor(selectedItem), tokens.selectedBackground);
    expect(_backgroundColor(unselectedItem), Colors.transparent);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(
      tester.getCenter(_menuItemBackgroundFinder(find.text('选项一'))),
    );
    await tester.pumpAndSettle();

    expect(
      _backgroundColor(_menuItemBackground(tester, find.text('选项一'))),
      tokens.menuItemSelectedHoverBackground,
    );

    await gesture.moveTo(
      tester.getCenter(_menuItemBackgroundFinder(find.text('选项二'))),
    );
    await tester.pumpAndSettle();

    expect(
      _backgroundColor(_menuItemBackground(tester, find.text('选项一'))),
      tokens.selectedBackground,
    );
    expect(
      _backgroundColor(_menuItemBackground(tester, find.text('选项二'))),
      tokens.menuItemHoverBackground,
    );

    await gesture.removePointer();
  });
}

AnimatedContainer _menuItemBackground(WidgetTester tester, Finder itemLabel) {
  final background = _menuItemBackgroundFinder(itemLabel);
  expect(background, findsOneWidget);
  return tester.widget<AnimatedContainer>(background);
}

Finder _menuItemBackgroundFinder(Finder itemLabel) {
  return find.ancestor(
    of: itemLabel,
    matching: find.byType(AnimatedContainer),
  );
}

Color? _backgroundColor(AnimatedContainer container) {
  return (container.decoration as BoxDecoration).color;
}

Finder _popupMenuEntries<T>() {
  return find.byWidgetPredicate((widget) => widget is PopupMenuEntry<T>);
}

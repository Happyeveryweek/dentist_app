import 'package:dentist_app_windows/features/materials/widgets/material_stat_card.dart';
import 'package:dentist_app_windows/features/materials/widgets/material_type_filter_dropdown.dart';
import 'package:dentist_app_windows/models/material.dart';
import 'package:dentist_app_windows/providers/material_provider.dart';
import 'package:dentist_app_windows/providers/settings_provider.dart';
import 'package:dentist_app_windows/screens/materials_screen.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('材料数量标题跟随当前分类', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final materials = [
      MaterialInfo(materialName: '利多卡因', materialType: '药品'),
      MaterialInfo(materialName: '一次性口镜', materialType: '其他'),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider<MaterialProvider>(
            create: (_) => _FakeMaterialProvider(materials),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.resolve(WindowsThemeVariant.purplePinkGray),
          home: const MaterialsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(_cardValue('材料数量-全部'), '2');
    expect(find.text('总价值'), findsOneWidget);

    await tester.tap(find.byType(MaterialTypeFilterDropdown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('药品').last);
    await tester.pumpAndSettle();

    expect(_cardValue('材料数量-药品'), '1');
    expect(find.text('材料数量-全部'), findsNothing);
  });
}

String _cardValue(String label) {
  final card = find.ancestor(
    of: find.text(label),
    matching: find.byType(MaterialStatCard),
  );
  expect(card, findsOneWidget);
  final value = find.descendant(
    of: card,
    matching: find.byWidgetPredicate(
      (widget) => widget is Text && widget.data != label,
    ),
  );
  expect(value, findsOneWidget);
  return (value.evaluate().single.widget as Text).data!;
}

class _FakeMaterialProvider extends MaterialProvider {
  _FakeMaterialProvider(this.materials);

  final List<MaterialInfo> materials;

  @override
  Future<List<MaterialInfo>> getAllMaterials(
      {bool forceRefresh = false}) async {
    return materials;
  }
}

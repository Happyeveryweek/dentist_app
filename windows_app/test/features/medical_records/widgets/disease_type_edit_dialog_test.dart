import 'package:dentist_app_windows/features/medical_records/widgets/disease_type_edit_dialog.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('疾病类型单选项使用独立 Material 层', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.resolve(WindowsThemeVariant.purplePinkGray),
        home: const DiseaseTypeEditDialog(),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(RadioListTile<bool>), findsNWidgets(2));
    expect(find.byType(Material), findsWidgets);
  });
}

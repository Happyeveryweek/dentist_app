import 'package:dentist_app/features/materials/widgets/material_detail_sheet.dart';
import 'package:dentist_app/models/material.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('材料详情展示名称、分组信息和编辑删除', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MaterialDetailPage(
          material: DentalMaterial(
            materialName: '阿莫西林胶囊',
            materialCode: 'M001',
            materialType: '药品',
            unit: '盒',
            defaultPrice: 12,
            stockQuantity: 3,
            supplier: '华南医药',
            description: '口服抗生素',
            createdAt: DateTime(2026, 8, 8, 9, 30),
          ),
          onEdit: () async => false,
          onDelete: () async => false,
        ),
      ),
    );

    expect(find.text('材料详情'), findsOneWidget);
    expect(find.text('阿莫西林胶囊'), findsOneWidget);
    expect(find.text('M001'), findsWidgets);
    expect(find.text('基本信息'), findsOneWidget);
    expect(find.text('补充说明'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('记录时间'), 200);
    expect(find.text('记录时间'), findsOneWidget);
    expect(find.text('华南医药'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    final deleteButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, '删除'),
    );
    expect(
      deleteButton.style?.backgroundColor?.resolve(const <WidgetState>{}),
      AppTheme.errorColor,
    );
  });
}

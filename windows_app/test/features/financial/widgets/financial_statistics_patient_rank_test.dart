import 'dart:ui';

import 'package:dentist_app_windows/features/financial/widgets/financial_statistics_dialog.dart';
import 'package:dentist_app_windows/models/financial_item.dart';
import 'package:dentist_app_windows/models/financial_record.dart';
import 'package:dentist_app_windows/models/patient.dart';
import 'package:dentist_app_windows/models/user.dart';
import 'package:dentist_app_windows/models/user_role.dart';
import 'package:dentist_app_windows/providers/financial_provider.dart';
import 'package:dentist_app_windows/providers/user_provider.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('收费排行和欠费排行可打开对应用户的财务详情', (tester) async {
    tester.view.physicalSize = const Size(1800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final patients = [
      Patient(
        id: 11,
        name: '李四',
        age: 28,
        gender: '男',
        phone: '13800000000',
        firstVisitDate: now,
      ),
      Patient(
        id: 22,
        name: '王五',
        age: 36,
        gender: '女',
        phone: '13900000000',
        firstVisitDate: now,
      ),
    ];
    final records = [
      FinancialRecord(
        id: 101,
        patientId: 11,
        totalQuantity: 1,
        createdAt: now,
        updatedAt: now,
      ),
      FinancialRecord(
        id: 202,
        patientId: 22,
        totalQuantity: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    final items = [
      FinancialItem(
        id: 1,
        financialRecordId: 101,
        itemName: '补牙',
        itemPrice: 200,
        processingFee: 0,
        quantity: 1,
        totalPrice: 200,
        chargeDate: now,
        createdAt: now,
        updatedAt: now,
      ),
      FinancialItem(
        id: 2,
        financialRecordId: 202,
        itemName: '根管治疗',
        itemPrice: 300,
        processingFee: 0,
        quantity: 1,
        totalPrice: 80,
        chargeDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FinancialProvider>(
            create: (_) => _RankFinancialProvider(records, items),
          ),
          ChangeNotifierProvider(
            create: (_) => UserProvider(
              currentUser: User(
                username: 'admin',
                password: 'password',
                role: UserRole.admin.value,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.resolve(WindowsThemeVariant.purplePinkGray),
          home: FinancialStatsDialog(
            financialRecords: records,
            financialItems: items,
            patients: patients,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final chargeRank = find.byKey(const ValueKey('patient-charge-rank-11'));
    final debtRank = find.byKey(const ValueKey('patient-debt-rank-22'));
    expect(chargeRank, findsOneWidget);
    expect(
      tester.widget<InkWell>(chargeRank).mouseCursor,
      SystemMouseCursors.click,
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(chargeRank));
    await tester.pumpAndSettle();
    expect(_rankBackground(tester, 'charge', 11), isNot(Colors.transparent));
    expect(_rankBackground(tester, 'debt', 22), Colors.transparent);

    await gesture.moveTo(tester.getCenter(debtRank));
    await tester.pumpAndSettle();
    expect(_rankBackground(tester, 'debt', 22), isNot(Colors.transparent));
    expect(_rankBackground(tester, 'charge', 11), Colors.transparent);

    await tester.tap(chargeRank);
    await tester.pumpAndSettle();
    expect(find.text('李四 - 财务详情'), findsOneWidget);
    expect(find.text('补牙'), findsOneWidget);

    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('patient-debt-rank-22')));
    await tester.pumpAndSettle();
    expect(find.text('王五 - 财务详情'), findsOneWidget);
    expect(find.text('根管治疗'), findsOneWidget);
    expect(find.text('补牙'), findsNothing);
  });
}

Color _rankBackground(WidgetTester tester, String rankKind, int patientId) {
  final container = tester.widget<AnimatedContainer>(
    find.byKey(ValueKey('patient-$rankKind-rank-bg-$patientId')),
  );
  final decoration = container.decoration;
  if (decoration is BoxDecoration) {
    return decoration.color ?? Colors.transparent;
  }
  return Colors.transparent;
}

class _RankFinancialProvider extends FinancialProvider {
  _RankFinancialProvider(this.records, this.items);

  final List<FinancialRecord> records;
  final List<FinancialItem> items;

  @override
  Future<List<FinancialRecord>> getAllFinancialRecords() async => records;

  @override
  Future<List<FinancialItem>> getFinancialItemsByRecordId(int recordId) async {
    return items.where((item) => item.financialRecordId == recordId).toList();
  }
}

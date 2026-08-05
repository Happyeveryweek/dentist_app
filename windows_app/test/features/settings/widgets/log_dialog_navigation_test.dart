import 'package:dentist_app_windows/features/settings/widgets/backup_log_dialog.dart';
import 'package:dentist_app_windows/features/settings/widgets/patient_sync_log_dialog.dart';
import 'package:dentist_app_windows/features/settings/widgets/structure_log_dialog.dart';
import 'package:dentist_app_windows/models/backup_log.dart';
import 'package:dentist_app_windows/models/database_structure_log.dart';
import 'package:dentist_app_windows/models/patient_sync_log.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final theme = AppTheme.resolve(WindowsThemeVariant.purplePinkGray);

  testWidgets('结构检测日志详情可返回日志列表', (tester) async {
    final log = DatabaseStructureLog(
      dataSourceType: 'sqlite',
      detectionTime: DateTime(2026, 8, 5, 13, 0),
      status: 'success',
      requiredTables: 13,
      missingTables: 0,
      structureChanges: 0,
      errors: const [],
      details: const {
        'detectedTables': ['patients'],
      },
      summary: '数据库结构正常，无需更新',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: StructureLogDialog(logs: [log]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据库结构检测日志'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
    await tester.tap(find.text('点击查看详情'));
    await tester.pumpAndSettle();

    expect(find.text('检测日志详情'), findsOneWidget);
    expect(find.text('返回日志列表'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsNWidgets(2));
    await tester.tap(find.text('返回日志列表'));
    await tester.pumpAndSettle();

    expect(find.text('检测日志详情'), findsNothing);
    expect(find.text('数据库结构检测日志'), findsOneWidget);
  });

  testWidgets('备份日志和患者同步日志弹窗提供返回按钮', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: BackupLogDialog(
          logs: [
            BackupLog(
              backupDate: DateTime(2026, 8, 5),
              backupPath: 'D:/backup.db',
              success: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('返回'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: PatientSyncLogDialog(
          logs: [
            PatientSyncLog(
              syncTime: DateTime(2026, 8, 5),
              action: 'update',
              status: 'success',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('返回'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsOneWidget);
  });
}

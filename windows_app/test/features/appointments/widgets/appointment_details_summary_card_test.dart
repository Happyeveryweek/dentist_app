import 'package:dentist_app_windows/features/appointments/widgets/appointment_details_summary_card.dart';
import 'package:dentist_app_windows/features/dashboard/helpers/dashboard_status_helper.dart';
import 'package:dentist_app_windows/models/appointment.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/theme/app_theme_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('zh_CN');
  });

  testWidgets('已预约状态跟随当前主题主色', (tester) async {
    for (final variant in WindowsThemeVariant.values) {
      final theme = AppTheme.resolve(variant);
      final tokens = theme.extension<AppThemeTokens>()!;
      late Color scheduledColor;

      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(variant),
          theme: theme,
          home: Builder(
            builder: (context) {
              scheduledColor = DashboardStatusHelper.getStatusColor(
                context,
                'scheduled',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(scheduledColor, tokens.primaryAccent);
    }
  });

  testWidgets('预约摘要卡使用实色背景和主题状态色', (tester) async {
    final theme = AppTheme.resolve(WindowsThemeVariant.freshGreen);
    final tokens = theme.extension<AppThemeTokens>()!;
    final appointment = Appointment(
      patientId: 1,
      appointmentDate: DateTime(2026, 7, 7, 17),
      status: 'scheduled',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: AppointmentDetailsSummaryCard(appointment: appointment),
        ),
      ),
    );

    final outerContainer = tester.widget<Container>(
      find.byType(Container).first,
    );
    final decoration = outerContainer.decoration! as BoxDecoration;
    expect(decoration.color, tokens.cardBackground);
    expect(decoration.gradient, isNull);

    final statusText = tester.widget<Text>(find.text('已预约'));
    expect(statusText.style?.color, tokens.primaryAccent);
  });
}

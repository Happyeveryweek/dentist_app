import 'package:dentist_app/features/appointments/widgets/appointment_card.dart';
import 'package:dentist_app/models/database_models.dart' show Appointment;
import 'package:dentist_app/models/user.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('预约列表头像颜色按患者性别显示', (tester) async {
    final userProvider = UserProvider(
      currentUser: User(
        username: 'admin',
        email: 'admin@example.com',
        password: 'test-password',
        role: 'admin',
      ),
    );

    Future<void> pumpAppointment(String? gender) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
          child: MaterialApp(
            home: Scaffold(
              body: AppointmentCard(
                appointment: Appointment(
                  patientId: 1,
                  appointmentDate: DateTime(2026, 8, 5, 9),
                  patientName: '张三',
                ),
                formatTreatmentType: (_) => '常规复诊',
                patientGender: gender,
                getAppointmentPatientDoctor: (_) async => null,
                onEdit: (_) {},
                onDelete: (_) {},
                onDetailUpdated: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      final initial = tester.widget<Text>(find.text('张'));
      final expectedColor = switch (gender) {
        '男' => AppTheme.infoColor,
        '女' => AppTheme.accentColor,
        _ => AppTheme.secondaryText,
      };

      expect(avatar.backgroundColor, expectedColor.withValues(alpha: 0.2));
      expect(initial.style?.color, expectedColor);
    }

    await pumpAppointment('男');
    await pumpAppointment('女');
    await pumpAppointment(null);
  });
}

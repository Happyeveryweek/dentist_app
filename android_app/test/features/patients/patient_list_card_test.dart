import 'package:dentist_app/features/patients/widgets/patient_list_card.dart';
import 'package:dentist_app/models/database_models.dart' show Patient;
import 'package:dentist_app/models/user.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('患者列表头像颜色按性别显示', (tester) async {
    final userProvider = UserProvider(
      currentUser: User(
        username: 'admin',
        email: 'admin@example.com',
        password: 'test-password',
        role: 'admin',
      ),
    );

    Future<void> pumpPatient(String gender) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<UserProvider>.value(
          value: userProvider,
          child: MaterialApp(
            home: Scaffold(
              body: PatientListCard(
                patient: Patient(
                  name: '李明',
                  age: 30,
                  gender: gender,
                  phone: '13800000000',
                ),
                onTap: () {},
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      final initial = tester.widget<Text>(find.text('李'));
      final expectedColor = switch (gender) {
        '男' => AppTheme.infoColor,
        '女' => AppTheme.accentColor,
        _ => AppTheme.secondaryText,
      };

      expect(avatar.backgroundColor, expectedColor.withValues(alpha: 0.15));
      expect(initial.style?.color, expectedColor);
    }

    await pumpPatient('男');
    await pumpPatient('女');
    await pumpPatient('未知');
  });
}

import 'package:dentist_app/features/settings/widgets/system_settings_section.dart';
import 'package:dentist_app/models/user.dart';
import 'package:dentist_app/providers/settings_provider.dart';
import 'package:dentist_app/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('管理员在账户管理中看到用户管理', (tester) async {
    await _pump(tester, role: UserRole.admin);
    expect(find.text('用户管理'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
  });

  testWidgets('医生在账户管理中看不到用户管理', (tester) async {
    await _pump(tester, role: UserRole.doctor);
    expect(find.text('用户管理'), findsNothing);
    expect(find.text('退出登录'), findsOneWidget);
  });
}

Future<void> _pump(WidgetTester tester, {required String role}) {
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(
          create:
              (_) => UserProvider(
                currentUser: User(
                  username: 'clinic',
                  password: 'secret',
                  role: role,
                ),
              ),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(body: SystemSettingsSection(onLogout: _noop)),
      ),
    ),
  );
}

void _noop() {}

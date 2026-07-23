import 'package:dentist_app_windows/features/users/widgets/user_form_dialog.dart';
import 'package:dentist_app_windows/models/user.dart';
import 'package:dentist_app_windows/models/user_role.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('编辑用户表单为顶部浮动标签保留裁切安全间距', (tester) async {
    final user = User(
      id: 1,
      username: '王测试',
      email: 'test@admin.com',
      password: 'password',
      role: UserRole.doctor.value,
      doctor: '王测试',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.resolve(WindowsThemeVariant.purplePinkGray),
        home: Scaffold(
          body: UserFormDialog(
            user: user,
            availableRoles: UserRole.values.map((role) => role.value).toList(),
          ),
        ),
      ),
    );

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scrollView.padding, const EdgeInsets.only(top: 8));

    await tester.tap(find.widgetWithText(TextFormField, '王测试').first);
    await tester.pump();
    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isTrue,
    );

    await tester.ensureVisible(find.text('模块权限配置'));
    await tester.tap(find.text('模块权限配置'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasFocus,
      isFalse,
    );
    expect(find.text('选择用户可以访问的功能模块（仪表盘默认对所有用户可见）'), findsOneWidget);
  });
}

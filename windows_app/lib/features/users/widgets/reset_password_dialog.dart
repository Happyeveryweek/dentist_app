import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../providers/user_provider.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/success_toast.dart';
import '../../../models/user.dart';
import 'user_form_field.dart';

class ResetPasswordDialog extends StatelessWidget {
  final User user;

  const ResetPasswordDialog({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final passwordController = TextEditingController();

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isPurpleTheme =
        Theme.of(context).scaffoldBackgroundColor == AppTheme.purpleBackground;

    final accentColor = isPurpleTheme
        ? AppTheme.purpleColor
        : isDarkMode
            ? AppTheme.primaryColor
            : AppTheme.primaryColor;

    final textColor = isPurpleTheme
        ? AppTheme.purplePrimaryText
        : isDarkMode
            ? AppTheme.darkPrimaryText
            : null;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.lock_reset, color: accentColor, size: 24),
          const SizedBox(width: 12),
          Text('修改${user.username}的密码',
              style: TextStyle(
                  color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Form(
        key: formKey,
        child: UserFormField(
          controller: passwordController,
          label: '新密码',
          hint: '请输入新密码',
          icon: Icons.lock,
          isPassword: true,
        ),
      ),
      actions: [
        DentalGradientButton(
          text: '取消',
          onPressed: () => Navigator.of(context).pop(),
          isOutlined: true,
        ),
        const SizedBox(width: 12),
        DentalGradientButton(
          text: '保存',
          onPressed: () async {
            if (formKey.currentState?.validate() != true) {
              return;
            }

            final userId = user.id;
            if (userId == null) {
              AppToastManager.showError(
                context,
                message: '用户ID为空，无法修改密码',
              );
              return;
            }

            try {
              final userProvider =
                  Provider.of<UserProvider>(context, listen: false);

              // 使用专用的密码更新方法，而不是通用的updateUser方法
              await userProvider.updateUserPassword(
                userId,
                passwordController.text,
              );

                if (!context.mounted) return;
                Navigator.of(context).pop();

                AppToastManager.showSuccess(
                  context,
                  message: '密码修改成功',
                );
              } catch (e) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
                AppToastManager.showError(
                  context,
                  message: '密码修改失败: $e',
                );
              }
            }
          ),
        ],
    );
  }
}

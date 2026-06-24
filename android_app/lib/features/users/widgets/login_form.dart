import 'dart:ui';
import 'package:flutter/material.dart';
import 'username_field.dart';
import 'password_field.dart';
import 'remember_password_checkbox.dart';
import 'login_button.dart';

/// 登录表单组件
class LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberPassword;
  final bool isInitializing;
  final bool isSmallScreen;
  final ValueChanged<bool> onObscurePasswordChanged;
  final ValueChanged<bool> onRememberPasswordChanged;
  final VoidCallback onLogin;

  const LoginForm({
    super.key,
    required this.formKey,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberPassword,
    required this.isInitializing,
    required this.isSmallScreen,
    required this.onObscurePasswordChanged,
    required this.onRememberPasswordChanged,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    final formPadding = isSmallScreen ? 16.0 : 24.0;
    final fieldSpacing = isSmallScreen ? 12.0 : 16.0;

    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(formPadding),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, -1),
                spreadRadius: 0,
              ),
            ],
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6),
              width: 1.5,
            ),
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题区域
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.shade50.withValues(alpha: 0.6),
                            Colors.indigo.shade50.withValues(alpha: 0.6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.login_rounded,
                        color: Colors.blue.shade700,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '用户登录',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            '请输入您的用户名和密码',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: fieldSpacing * 1.75),

                UsernameField(
                  controller: usernameController,
                  isSmallScreen: isSmallScreen,
                ),
                SizedBox(height: fieldSpacing),
                PasswordField(
                  controller: passwordController,
                  obscurePassword: obscurePassword,
                  onObscurePasswordChanged: onObscurePasswordChanged,
                  isSmallScreen: isSmallScreen,
                ),
                SizedBox(height: fieldSpacing * 0.8),
                RememberPasswordCheckbox(
                  rememberPassword: rememberPassword,
                  onChanged: onRememberPasswordChanged,
                ),
                SizedBox(height: fieldSpacing * 1.2),
                LoginButton(
                  isInitializing: isInitializing,
                  onPressed: onLogin,
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

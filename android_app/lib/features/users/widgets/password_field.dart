import 'package:flutter/material.dart';

/// 密码字段组件
class PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscurePassword;
  final ValueChanged<bool> onObscurePasswordChanged;
  final bool isSmallScreen;

  const PasswordField({
    super.key,
    required this.controller,
    required this.obscurePassword,
    required this.onObscurePasswordChanged,
    required this.isSmallScreen,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 350;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.blue.shade600,
                  size: isSmall ? 16 : 18,
                ),
                const SizedBox(width: 8),
                Text(
                  '密码',
                  style: TextStyle(
                    fontSize: isSmall ? 13 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextFormField(
                controller: controller,
                obscureText: obscurePassword,
                style: TextStyle(fontSize: isSmall ? 13 : 14),
                decoration: InputDecoration(
                  hintText: '请输入密码',
                  hintStyle: TextStyle(
                    color: Colors.grey[400],
                    fontSize: isSmall ? 12 : 13,
                  ),
                  prefixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.lock_rounded,
                      color: Colors.blue.shade600,
                      size: isSmall ? 18 : 20,
                    ),
                  ),
                  suffixIcon: Container(
                    margin: const EdgeInsets.all(10),
                    child: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        color: Colors.blue.shade500,
                        size: isSmall ? 18 : 20,
                      ),
                      onPressed: () {
                        onObscurePasswordChanged(!obscurePassword);
                      },
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade200,
                      width: 1.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade200,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.blue.shade500,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.blue.shade50.withValues(alpha: 0.4),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: isSmall ? 12 : 16,
                    vertical: isSmall ? 12 : 14,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入密码';
                  }
                  return null;
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

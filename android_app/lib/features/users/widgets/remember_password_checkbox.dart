import 'package:flutter/material.dart';

/// 记住密码复选框组件
class RememberPasswordCheckbox extends StatelessWidget {
  final bool rememberPassword;
  final ValueChanged<bool> onChanged;

  const RememberPasswordCheckbox({
    super.key,
    required this.rememberPassword,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: rememberPassword,
            onChanged: (value) {
              onChanged(value ?? false);
            },
            activeColor: Colors.blue.shade600,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            onChanged(!rememberPassword);
          },
          child: Text(
            '记住密码',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

/// 患者信息行显示组件
/// 职责：显示患者的基本信息行（图标+标签+值）
class PatientInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool alignTop;
  final Color? valueColor;
  final bool isPhone;
  final VoidCallback? onPhoneCall;

  const PatientInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.alignTop = false,
    this.valueColor,
    this.isPhone = false,
    this.onPhoneCall,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: isPhone
              ? Row(
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onPhoneCall,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.call,
                          size: 16,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppTheme.textColor,
                    fontSize: 14,
                    fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
        ),
      ],
    );
  }
}

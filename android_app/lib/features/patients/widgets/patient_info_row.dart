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
  final VoidCallback? onTap;

  const PatientInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.alignTop = false,
    this.valueColor,
    this.isPhone = false,
    this.onPhoneCall,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment:
          alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
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
              ? InkWell(
                  onTap: onPhoneCall,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      value,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    color:
                        onTap != null
                            ? AppTheme.primaryColor
                            : (valueColor ?? AppTheme.textColor),
                    fontSize: 14,
                    fontWeight:
                        onTap != null || valueColor != null
                            ? FontWeight.bold
                            : FontWeight.normal,
                    decoration:
                        onTap != null
                            ? TextDecoration.underline
                            : TextDecoration.none,
                  ),
                ),
        ),
        if (onTap != null) ...[
          const SizedBox(width: 8),
          const Icon(
            CupertinoIcons.chevron_right,
            size: 14,
            color: AppTheme.primaryColor,
          ),
        ],
      ],
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: row,
      ),
    );
  }
}

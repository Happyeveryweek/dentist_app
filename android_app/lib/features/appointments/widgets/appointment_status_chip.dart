import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

class AppointmentStatusChip extends StatelessWidget {
  final String status;

  const AppointmentStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case 'scheduled':
      case '已预约':
        color = AppTheme.infoColor;
        text = '已预约';
        break;
      case 'completed':
      case '已完成':
        color = AppTheme.successColor;
        text = '已完成';
        break;
      case 'cancelled':
      case '已取消':
        color = AppTheme.errorColor;
        text = '已取消';
        break;
      case 'missed':
      case 'no_show':
      case '未到诊':
        color = Colors.orange;
        text = '未到诊';
        break;
      default:
        color = AppTheme.secondaryText;
        text = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

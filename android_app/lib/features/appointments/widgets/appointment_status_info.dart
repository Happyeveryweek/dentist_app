import 'package:flutter/material.dart';
import 'package:dentist_app/theme/app_theme.dart';

class StatusInfo {
  final String text;
  final Color color;
  final IconData icon;

  StatusInfo({required this.text, required this.color, required this.icon});
}

StatusInfo getStatusInfo(String status) {
  switch (status) {
    case 'scheduled':
    case '已预约':
      return StatusInfo(
        text: '已预约',
        color: AppTheme.infoColor,
        icon: Icons.event_available,
      );
    case 'completed':
    case '已完成':
      return StatusInfo(
        text: '已完成',
        color: AppTheme.successColor,
        icon: Icons.check_circle_outline,
      );
    case 'cancelled':
    case '已取消':
      return StatusInfo(
        text: '已取消',
        color: AppTheme.errorColor,
        icon: Icons.cancel_outlined,
      );
    case 'missed':
    case 'no_show':
    case '未到诊':
      return StatusInfo(
        text: '未到诊',
        color: AppTheme.warningColor,
        icon: Icons.hourglass_empty,
      );
    default:
      return StatusInfo(
        text: '未知',
        color: AppTheme.secondaryText,
        icon: Icons.help_outline,
      );
  }
}

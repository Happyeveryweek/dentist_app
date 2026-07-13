import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// 预约状态信息类
class StatusInfo {
  final Color color;
  final String text;

  StatusInfo({required this.color, required this.text});
}

/// 预约状态辅助类
class AppointmentStatusHelper {
  /// 获取状态信息
  static StatusInfo getStatusInfo(String status) {
    switch (status) {
      case 'scheduled':
      case '已预约':
        return StatusInfo(color: AppTheme.infoColor, text: '已预约');
      case 'completed':
      case '已完成':
        return StatusInfo(color: AppTheme.successColor, text: '已完成');
      case 'cancelled':
      case '已取消':
        return StatusInfo(color: AppTheme.errorColor, text: '已取消');
      case 'in_progress':
        return StatusInfo(color: AppTheme.warningColor, text: '进行中');
      case 'missed':
      case 'no_show':
      case '未到诊':
        return StatusInfo(color: Colors.orange, text: '未到诊');
      default:
        return StatusInfo(color: AppTheme.secondaryText, text: status);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:dentist_app_windows/widgets/dental_icons.dart';

/// 仪表盘状态颜色辅助类
/// 职责：预约状态颜色映射
class DashboardStatusHelper {
  static String normalizeStatus(String status) {
    final normalized = status.trim().toLowerCase();

    switch (normalized) {
      case 'scheduled':
      case '已预约':
        return '已预约';
      case 'completed':
      case '已完成':
        return '已完成';
      case 'cancelled':
      case '已取消':
        return '已取消';
      case 'missed':
      case '未到诊':
        return '未到诊';
      default:
        return status.trim();
    }
  }

  static bool isScheduled(String status) => normalizeStatus(status) == '已预约';

  static bool isCompleted(String status) => normalizeStatus(status) == '已完成';

  static bool isUnfinished(String status) =>
      !isScheduled(status) && !isCompleted(status);

  /// 根据预约状态获取对应的颜色
  static Color getStatusColor(String status) {
    switch (normalizeStatus(status)) {
      case '已完成':
        return DentalColors.success;
      case '已预约':
        return DentalColors.info;
      case '已取消':
        return DentalColors.error;
      case '未到诊':
        return DentalColors.warning;
      default:
        return DentalColors.onSurfaceVariant;
    }
  }
}

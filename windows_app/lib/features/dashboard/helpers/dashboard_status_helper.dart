import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/models/appointment_status.dart';

/// 仪表盘状态颜色辅助类
/// 职责：预约状态颜色映射
class DashboardStatusHelper {
  static AppointmentStatus? parseStatus(String status) =>
      AppointmentStatus.tryParse(status);

  static bool isScheduled(String status) =>
      parseStatus(status) == AppointmentStatus.scheduled;

  static bool isCompleted(String status) =>
      parseStatus(status) == AppointmentStatus.completed;

  static bool isUnfinished(String status) =>
      !isScheduled(status) && !isCompleted(status);

  /// 根据预约状态获取对应的颜色
  static Color getStatusColor(BuildContext context, String status) {
    switch (parseStatus(status)) {
      case AppointmentStatus.completed:
        return context.tokens.success;
      case AppointmentStatus.scheduled:
        return context.tokens.info;
      case AppointmentStatus.cancelled:
        return context.tokens.error;
      case AppointmentStatus.missed:
        return context.tokens.warning;
      default:
        return context.colors.onSurfaceVariant;
    }
  }
}

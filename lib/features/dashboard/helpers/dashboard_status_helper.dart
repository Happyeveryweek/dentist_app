import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/app_theme.dart';
import 'package:dentist_app_windows/widgets/dental_icons.dart';

/// 仪表盘状态颜色辅助类
/// 职责：预约状态颜色映射
class DashboardStatusHelper {
  /// 根据预约状态获取对应的颜色
  static Color getStatusColor(String status) {
    switch (status) {
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

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/permission_utils.dart';
import '../../../screens/patients_screen.dart';
import '../../../screens/appointments_screen.dart';
import 'stat_card.dart';

/// 统计卡片组组件
class StatisticsCards extends StatelessWidget {
  final int patientCount;
  final int appointmentCount;
  final int completedAppointments;
  final int upcomingAppointments;
  final Animation<double> fadeAnimation;

  const StatisticsCards({
    super.key,
    required this.patientCount,
    required this.appointmentCount,
    required this.completedAppointments,
    required this.upcomingAppointments,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: '患者总数',
                  value: patientCount.toString(),
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.infoColor,
                  onTap: () async {
                    final hasPermission = await PermissionUtils.canEdit(context, 'patients');
                    if (hasPermission) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PatientsScreen(),
                        ),
                      );
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问患者管理',
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: '预约总数',
                  value: appointmentCount.toString(),
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.primaryColor,
                  onTap: () async {
                    final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                    if (hasPermission) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppointmentsScreen(),
                        ),
                      );
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问预约管理',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  title: '已完成',
                  value: completedAppointments.toString(),
                  icon: Icons.check_circle_outline_rounded,
                  color: AppTheme.successColor,
                  onTap: () async {
                    final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                    if (hasPermission) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppointmentsScreen(
                            initialFilterStatus: '已完成',
                          ),
                        ),
                      );
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问预约管理',
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: StatCard(
                  title: '待处理',
                  value: upcomingAppointments.toString(),
                  icon: Icons.schedule_rounded,
                  color: AppTheme.warningColor,
                  onTap: () async {
                    final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                    if (hasPermission) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppointmentsScreen(
                            initialFilterStatus: '已预约',
                          ),
                        ),
                      );
                    } else {
                      PermissionUtils.showPermissionDeniedMessage(
                        context,
                        customMessage: '您没有权限访问预约管理',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

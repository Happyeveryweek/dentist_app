import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/database_models.dart';
import '../../../providers/patient_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/permission_utils.dart';
import '../../../screens/appointment_detail_screen.dart';
import '../../../screens/home_screen.dart';
import 'appointment_card.dart';

/// 今日预约区域组件
class TodayAppointmentsSection extends StatelessWidget {
  final List<Appointment> todayAppointments;
  final Animation<double> fadeAnimation;

  const TodayAppointmentsSection({
    super.key,
    required this.todayAppointments,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '今日预约',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryText,
                ),
              ),
              TextButton(
                onPressed: () async {
                  final hasPermission = await PermissionUtils.canEdit(context, 'appointments');
                  if (hasPermission) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (context) => const HomeScreen(initialIndex: 2),
                      ),
                    );
                  } else {
                    PermissionUtils.showPermissionDeniedMessage(
                      context,
                      customMessage: '您没有权限访问预约管理',
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: const Row(
                  children: [
                    Text(
                      '查看全部',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          todayAppointments.isEmpty
              ? Container(
                  constraints: const BoxConstraints(minHeight: 180),
                  width: double.infinity,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.event_available_rounded,
                          color: AppTheme.primaryColor,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        '今日暂无预约',
                        style: TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: todayAppointments.map((appointment) {
                    return FutureBuilder<Patient?>(
                      future: Provider.of<PatientProvider>(
                        context,
                        listen: false,
                      ).getPatientById(appointment.patientId),
                      builder: (context, snapshot) {
                        final patient = snapshot.data;
                        return AppointmentCard(
                          appointment: appointment,
                          patient: patient,
                        );
                      },
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }
}

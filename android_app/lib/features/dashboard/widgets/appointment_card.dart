import 'package:flutter/material.dart';
import '../../../models/database_models.dart';
import '../../../theme/app_theme.dart';
import '../../../screens/appointment_detail_screen.dart';
import '../services/appointment_status_helper.dart';
import '../services/phone_formatter.dart';
import '../services/treatment_type_formatter.dart';
import 'info_item.dart';
import 'status_chip.dart';

/// 预约卡片组件
class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final Patient? patient;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.patient,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = AppointmentStatusHelper.getStatusInfo(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
        border: Border.all(
          color: statusInfo.color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppointmentDetailScreen(
                  appointment: appointment,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusInfo.color.withOpacity(0.2),
                            statusInfo.color.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          patient?.name.isNotEmpty == true
                              ? patient!.name.substring(0, 1)
                              : '?',
                          style: TextStyle(
                            color: statusInfo.color,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patient?.name ?? '加载中...',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryText,
                            ),
                          ),
                          if (patient?.medicalRecordNumber != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '病历号: ${patient!.medicalRecordNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    StatusChip(status: appointment.status),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      InfoItem(
                        icon: Icons.access_time_rounded,
                        text: _formatTime(appointment.appointmentDate),
                        color: AppTheme.infoColor,
                        expanded: true,
                      ),
                      if (patient?.phone != null && patient!.phone.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        InfoItem(
                          icon: Icons.phone_rounded,
                          text: PhoneFormatter.getDisplayPhone(patient!.phone),
                          color: AppTheme.successColor,
                          expanded: true,
                        ),
                      ],
                    ],
                  ),
                ),
                if (appointment.treatmentType != null) ...[
                  const SizedBox(height: 12),
                  InfoItem(
                    icon: Icons.medical_services_rounded,
                    text: TreatmentTypeFormatter.formatTreatmentType(appointment.treatmentType),
                    color: AppTheme.primaryColor,
                  ),
                ],
                if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InfoItem(
                    icon: Icons.notes_rounded,
                    text: appointment.notes!,
                    color: AppTheme.warningColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

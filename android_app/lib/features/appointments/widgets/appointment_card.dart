import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/theme/app_theme.dart';
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/screens/appointment_detail_screen.dart';
import 'package:dentist_app/utils/permission_utils.dart';
import 'package:dentist_app/features/appointments/widgets/appointment_status_info.dart';

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final Function(String) formatTreatmentType;
  final Color Function(String) getPatientAvatarColor;
  final Future<String?> Function(Appointment) getAppointmentPatientDoctor;
  final Function(Appointment) onEdit;
  final Function(Appointment) onDelete;
  final VoidCallback onDetailUpdated;

  const AppointmentCard({super.key, 
    required this.appointment,
    required this.formatTreatmentType,
    required this.getPatientAvatarColor,
    required this.getAppointmentPatientDoctor,
    required this.onEdit,
    required this.onDelete,
    required this.onDetailUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = getStatusInfo(appointment.status);
    final patientName = appointment.patientName ?? '未知患者';
    final avatarColor = getPatientAvatarColor(patientName);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shadowColor: AppTheme.lightText.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            CupertinoPageRoute(
              builder:
                  (context) =>
                      AppointmentDetailScreen(appointment: appointment),
            ),
          );

          if (result == true) {
            onDetailUpdated();
          }
        },
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: avatarColor.withValues(alpha: 0.2),
                    child: Text(
                      patientName.isNotEmpty
                          ? patientName.substring(0, 1)
                          : '?',
                      style: TextStyle(
                        color: avatarColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppTheme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('yyyy-MM-dd').format(appointment.appointmentDate)} ${DateFormat.Hm().format(appointment.appointmentDate)}',
                          style: const TextStyle(
                            color: AppTheme.secondaryText,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusInfo.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          statusInfo.icon,
                          color: statusInfo.color,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusInfo.text,
                          style: TextStyle(
                            color: statusInfo.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.dividerColor),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.medical_services_outlined,
                    color: AppTheme.secondaryText,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formatTreatmentType(appointment.treatmentType ?? ''),
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (appointment.notes != null &&
                  appointment.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.notes_outlined,
                      color: AppTheme.secondaryText,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        appointment.notes!,
                        style: const TextStyle(
                          color: AppTheme.secondaryText,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FutureBuilder<String?>(
                    future: getAppointmentPatientDoctor(appointment),
                    builder: (context, snapshot) {
                      final patientDoctor = snapshot.data;
                      return PermissionWrapper(
                        module: 'appointments',
                        action: 'edit',
                        recordDoctor: patientDoctor,
                        onPermissionDenied: () {
                          PermissionUtils.showPermissionDeniedMessage(
                            context,
                            customMessage: '您只能编辑自己负责患者的预约',
                          );
                        },
                        child: IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => onEdit(appointment),
                        ),
                      );
                    },
                  ),
                  FutureBuilder<String?>(
                    future: getAppointmentPatientDoctor(appointment),
                    builder: (context, snapshot) {
                      final patientDoctor = snapshot.data;
                      return PermissionWrapper(
                        module: 'appointments',
                        action: 'delete',
                        recordDoctor: patientDoctor,
                        onPermissionDenied: () {
                          PermissionUtils.showPermissionDeniedMessage(
                            context,
                            customMessage: '您只能删除自己负责患者的预约',
                          );
                        },
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => onDelete(appointment),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

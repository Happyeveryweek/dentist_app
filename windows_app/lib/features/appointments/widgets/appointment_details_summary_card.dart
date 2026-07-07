import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/appointment.dart';

class AppointmentDetailsSummaryCard extends StatelessWidget {
  final Appointment appointment;

  const AppointmentDetailsSummaryCard({
    Key? key,
    required this.appointment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statusColor =
        Color(int.parse(appointment.statusColor.replaceAll('#', '0xff')));
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.tokens.cardBackground,
            context.tokens.primaryAccent.withValues(alpha: 0.025),
            context.tokens.secondaryAccent.withValues(alpha: 0.015),
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.tokens.primaryAccent.withValues(alpha: 0.035),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: context.tokens.shadow.withValues(alpha: 0.16),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: context.tokens.primaryAccent.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        context.tokens.primaryAccent,
                        context.tokens.secondaryAccent,
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            context.tokens.primaryAccent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.event_note_rounded,
                    color: context.tokens.cardBackground,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('yyyy年MM月dd日 EEEE', 'zh_CN')
                            .format(appointment.appointmentDate),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '时间: ${DateFormat('HH:mm').format(appointment.appointmentDate)}',
                        style: TextStyle(
                          fontSize: 16,
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusColor.withValues(alpha: 0.1),
                        statusColor.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    appointment.statusDisplay,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

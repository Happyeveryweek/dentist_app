import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/widgets/app_card.dart';
import 'package:dentist_app/features/appointments/widgets/treatment_info_display.dart';
import 'package:dentist_app/features/appointments/widgets/appointment_status_chip.dart';

class AppointmentInfoCard extends StatelessWidget {
  final Appointment appointment;

  const AppointmentInfoCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '预约信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              AppointmentStatusChip(status: appointment.status ?? ''),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(
            CupertinoIcons.calendar,
            '预约日期',
            DateFormat('yyyy年MM月dd日').format(appointment.appointmentDate),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            CupertinoIcons.clock,
            '预约时间',
            DateFormat('HH:mm').format(appointment.appointmentDate),
          ),
          if (appointment.treatmentType != null && appointment.treatmentType!.isNotEmpty) ...[
            const SizedBox(height: 12),
            TreatmentInfoDisplay(treatmentTypeJson: appointment.treatmentType!),
          ],
          if (appointment.cost > 0) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.money_dollar,
              '费用',
              '¥${appointment.cost.toStringAsFixed(2)}',
              valueColor: AppTheme.accentColor,
            ),
          ],
          if (appointment.notes != null && appointment.notes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.doc_text,
              '备注',
              appointment.notes!,
              alignTop: true,
            ),
          ],
          const SizedBox(height: 12),
          _buildInfoRow(
            CupertinoIcons.time,
            '创建时间',
            DateFormat('yyyy-MM-dd HH:mm').format(appointment.createdAt),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            CupertinoIcons.time,
            '更新时间',
            DateFormat('yyyy-MM-dd HH:mm').format(appointment.updatedAt),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool alignTop = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textColor,
              fontSize: 14,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

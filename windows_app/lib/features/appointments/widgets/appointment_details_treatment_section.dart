import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/appointment.dart';

class AppointmentDetailsTreatmentSection extends StatelessWidget {
  final Appointment appointment;

  const AppointmentDetailsTreatmentSection({
    Key? key,
    required this.appointment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    final treatmentContent = _buildTreatmentContent();
    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tokens.divider.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.medical_services_rounded,
                  size: 18,
                  color: tokens.success,
                ),
                const SizedBox(width: 8),
                Text(
                  '治疗项目',
                  style: TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            treatmentContent,
          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentContent() {
    try {
      final treatmentData = jsonDecode(appointment.treatmentType ?? '[]');

      if (treatmentData is Map<String, dynamic>) {
        final List<Widget> contentWidgets = [];

        if (treatmentData.containsKey('treatments') &&
            treatmentData['treatments'] is List &&
            (treatmentData['treatments'] as List).isNotEmpty) {
          List<String> treatments =
              List<String>.from(treatmentData['treatments']);
          contentWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  treatments.join('、'),
                  style: const TextStyle(fontSize: 14.0),
                ),
              ],
            ),
          );
        } else if (treatmentData.containsKey('treatmentTypes')) {
          final List<dynamic> treatmentTypes = treatmentData['treatmentTypes'];
          contentWidgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  treatmentTypes.map((item) => item.toString()).join('、'),
                  style: const TextStyle(fontSize: 14.0),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets.isEmpty
              ? const [Text('无治疗项目', style: TextStyle(fontSize: 14.0))]
              : contentWidgets,
        );
      } else if (treatmentData is List) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              treatmentData.map((item) => item.toString()).join('、'),
              style: const TextStyle(fontSize: 14.0),
            ),
          ],
        );
      } else {
        return Text(
          treatmentData.toString(),
          style: const TextStyle(fontSize: 14.0),
        );
      }
    } catch (e) {
      return Text(
        appointment.treatmentType ?? '无治疗项目',
        style: const TextStyle(fontSize: 14.0),
      );
    }
  }
}

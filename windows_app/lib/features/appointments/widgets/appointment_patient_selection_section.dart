import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/patient.dart';

class AppointmentPatientSelectionSection extends StatelessWidget {
  final Patient? selectedPatient;
  final bool hasPreselectedPatient;
  final bool isLoadingPatients;
  final VoidCallback onSelectPatient;

  const AppointmentPatientSelectionSection({
    Key? key,
    required this.selectedPatient,
    required this.hasPreselectedPatient,
    required this.isLoadingPatients,
    required this.onSelectPatient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patient = selectedPatient;
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: tokens.primaryAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '患者信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: tokens.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hasPreselectedPatient)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: tokens.primaryAccent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, color: tokens.primaryAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '患者: ${patient?.name ?? '未选择'}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: tokens.primaryAccent,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isLoadingPatients)
            const Center(child: CircularProgressIndicator())
          else
            Material(
              color: Colors.transparent,
              child: InkWell(
                mouseCursor: SystemMouseCursors.click,
                onTap: onSelectPatient,
                borderRadius: BorderRadius.circular(8),
                child: Ink(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.cardBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person, color: tokens.primaryAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: patient == null
                            ? Text(
                                '请选择患者',
                                style: TextStyle(
                                  color: tokens.iconMuted,
                                  fontSize: 14,
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patient.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '最近就诊: ${patient.updatedAt.year.toString().padLeft(4, '0')}-${patient.updatedAt.month.toString().padLeft(2, '0')}-${patient.updatedAt.day.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: tokens.iconMuted,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.search,
                        color: tokens.primaryAccent,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

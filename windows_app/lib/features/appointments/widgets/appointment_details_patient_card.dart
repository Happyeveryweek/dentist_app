import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/theme/medical_semantic_colors.dart';
import '../../../models/patient.dart';

class AppointmentDetailsPatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onViewDetails;

  const AppointmentDetailsPatientCard({
    Key? key,
    required this.patient,
    required this.onViewDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patientAddress = patient.address;
    final tokens = context.tokens;
    final colors = context.colors;
    final baseColor = patient.gender == '女'
        ? MedicalSemanticColors.femaleGender
        : MedicalSemanticColors.maleGender;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.divider.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.tokens.primaryAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: context.tokens.primaryAccent.withValues(alpha: 0.2)),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: context.tokens.primaryAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '患者信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: baseColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      patient.name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: baseColor,
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
                        patient.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: tokens.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      context.tokens.info.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '${patient.age}岁 | ${patient.gender} | ${patient.phone}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: context.tokens.info,
                              ),
                            ),
                          ),
                          if (patient.medicalRecordNumber != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: context.tokens.primaryAccent
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.badge_rounded,
                                      size: 14, color: context.tokens.primaryAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    '病历号 ${patient.medicalRecordNumber}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.tokens.primaryAccent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (patientAddress != null &&
                              patientAddress.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: tokens.cardBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: colors.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.location_on_outlined,
                                      size: 14,
                                      color: colors.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    patientAddress,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.info_outline_rounded,
                    color: context.tokens.primaryAccent,
                  ),
                  tooltip: '查看患者详情',
                  onPressed: onViewDetails,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

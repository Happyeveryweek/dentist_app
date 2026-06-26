import 'package:flutter/material.dart';
import '../../../models/patient.dart';
import '../../../widgets/dental_icons.dart';

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
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: DentalColors.divider.withValues(alpha: 0.5),
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
                    color: DentalColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: DentalColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: DentalColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '患者信息',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: DentalColors.onSurface,
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
                    color: patient.gender == '女'
                        ? const Color(0xFFFCE4EC)
                        : const Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      patient.name.substring(0, 1),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: patient.gender == '女'
                            ? Colors.pink.shade600
                            : Colors.blue.shade600,
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
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: DentalColors.onSurface,
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
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      DentalColors.info.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '${patient.age}岁 | ${patient.gender} | ${patient.phone}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: DentalColors.info,
                              ),
                            ),
                          ),
                          if (patient.medicalRecordNumber != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: DentalColors.primary
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.badge_rounded,
                                      size: 14, color: DentalColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    '病历号 ${patient.medicalRecordNumber}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: DentalColors.primary,
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
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: DentalColors.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on_outlined,
                                      size: 14,
                                      color: DentalColors.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    patientAddress,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: DentalColors.onSurfaceVariant,
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
                  icon: const Icon(
                    Icons.info_outline_rounded,
                    color: DentalColors.primary,
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

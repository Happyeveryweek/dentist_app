import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../models/patient.dart';
import 'patient_detail_common_widgets.dart';

class PatientPersonalInfoCard extends StatelessWidget {
  final Patient patient;

  const PatientPersonalInfoCard({
    Key? key,
    required this.patient,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final patientAddress = patient.address;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.tokens.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: PatientCompactPersonalInfoItem(
                icon: Icons.badge,
                label: '病历号',
                value: patient.medicalRecordNumber?.toString() ?? '无',
                color: const Color(0xFF2ecc71),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: PatientCompactPersonalInfoItem(
                icon: Icons.medical_services,
                label: '主治医生',
                value: patient.doctor ?? '无',
                color: const Color(0xFF2ecc71),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: PatientCompactPersonalInfoItem(
                icon: Icons.phone,
                label: '联系电话',
                value: patient.phoneList.isNotEmpty
                    ? (patient.phoneList.length > 1
                        ? '${patient.mainPhone} (+${patient.phoneList.length - 1})'
                        : patient.mainPhone)
                    : '无',
                color: const Color(0xFF2ecc71),
              ),
            ),
            if (patientAddress != null && patientAddress.isNotEmpty) ...[
              const SizedBox(width: 16),
              Expanded(
                flex: 4,
                child: PatientCompactPersonalInfoItem(
                  icon: Icons.home,
                  label: '住址',
                  value: patientAddress,
                  color: const Color(0xFF2ecc71),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

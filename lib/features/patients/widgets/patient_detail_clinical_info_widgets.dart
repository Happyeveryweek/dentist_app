import 'package:flutter/material.dart';

import 'patient_detail_common_widgets.dart';

class PatientClinicalInfoCard extends StatelessWidget {
  final Widget dentalCondition;
  final String? treatmentItems;
  final bool showDivider;
  final bool showEmptyState;

  const PatientClinicalInfoCard({
    Key? key,
    required this.dentalCondition,
    required this.treatmentItems,
    required this.showDivider,
    required this.showEmptyState,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final hasTreatmentItems =
        treatmentItems != null && treatmentItems!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            dentalCondition,
            if (showDivider)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      const Color(0xFFe74c3c).withOpacity(0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            if (hasTreatmentItems)
              PatientDetailItem(
                label: '治疗项目',
                value: treatmentItems!,
                icon: Icons.medical_services,
                color: const Color(0xFFe74c3c),
              ),
            if (showEmptyState) const PatientClinicalInfoEmptyState(),
          ],
        ),
      ),
    );
  }
}

class PatientClinicalInfoEmptyState extends StatelessWidget {
  const PatientClinicalInfoEmptyState({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: const Color(0xFFe74c3c).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFe74c3c).withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.medical_information_outlined,
            size: 48,
            color: const Color(0xFFe74c3c).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无诊疗信息',
            style: TextStyle(
              color: const Color(0xFFe74c3c).withOpacity(0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

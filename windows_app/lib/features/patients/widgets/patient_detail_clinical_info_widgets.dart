import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

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
    final items = treatmentItems;
    final hasTreatmentItems = items != null && items.isNotEmpty;
    final tokens = context.tokens;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: tokens.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow.withValues(alpha: 0.1),
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
                      tokens.error.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            if (hasTreatmentItems)
              PatientDetailItem(
                label: '治疗项目',
                value: items,
                icon: Icons.medical_services,
                color: tokens.error,
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
    final tokens = context.tokens;
    return Container(
      padding: const EdgeInsets.all(32.0),
      decoration: BoxDecoration(
        color: tokens.errorContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: tokens.error.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.medical_information_outlined,
            size: 48,
            color: tokens.error.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无诊疗信息',
            style: TextStyle(
              color: tokens.error.withValues(alpha: 0.7),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

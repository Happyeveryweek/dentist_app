import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/theme/medical_semantic_colors.dart';
import '../../../models/patient.dart';

/// 财务详情页患者基本信息区域组件
/// 用于显示患者头像、姓名、病历号、首诊日期、备注信息
class FinancialPatientInfoSection extends StatelessWidget {
  final Patient patient;
  final String notes;

  const FinancialPatientInfoSection({
    super.key,
    required this.patient,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final bool isFemale =
        (patient.gender == '女') || (patient.gender.toLowerCase() == 'female');
    final Color baseColor =
        isFemale ? MedicalSemanticColors.femaleGender : MedicalSemanticColors.maleGender;
    final Color infoBgColor = baseColor.withValues(alpha: 0.14);
    final Color infoBorderColor = baseColor.withValues(alpha: 0.5);
    final Color avatarBgColor = baseColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: infoBgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: infoBorderColor),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: avatarBgColor,
            child: Text(
              patient.name.substring(0, 1),
              style: TextStyle(
                color: context.tokens.cardBackground,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: 4),
                Text('病历号: ${patient.medicalRecordNumber ?? '未设置'}'),
                Text(
                    '首诊日期: ${DateFormat('yyyy-MM-dd').format(patient.firstVisitDate)}'),
                const SizedBox(height: 4),
                Text(
                  '备注信息: $notes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

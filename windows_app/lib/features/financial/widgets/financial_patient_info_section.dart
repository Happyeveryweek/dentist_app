import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:dentist_app_windows/widgets/dental_icons.dart';
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.tokens.border),
      ),
      child: Row(
        children: [
          DentalAvatar(
            gender: patient.gender,
            name: patient.name,
            size: 48,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '病历号: ${patient.medicalRecordNumber ?? '未设置'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                    '首诊日期: ${DateFormat('yyyy-MM-dd').format(patient.firstVisitDate)}'),
                const SizedBox(height: 2),
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

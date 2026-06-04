import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
    final bool isFemale = (patient.gender == '女') ||
        (patient.gender.toLowerCase() == 'female');
    final Color? infoBgColor = isFemale ? Colors.pink[50] : Colors.blue[50];
    final Color infoBorderColor =
        isFemale ? Colors.pink[200]! : Colors.blue[200]!;
    final Color avatarBgColor = isFemale ? Colors.pink[400]! : Colors.blue[300]!;

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
              style: const TextStyle(
                color: Colors.white,
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
                Text('病历号: ${patient.medical_record_number ?? '未设置'}'),
                Text('首诊日期: ${DateFormat('yyyy-MM-dd').format(patient.first_visit_date)}'),
                const SizedBox(height: 4),
                Text(
                  '备注信息: $notes',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
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

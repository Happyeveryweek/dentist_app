import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/widgets/app_card.dart';
import 'package:dentist_app/features/patients/widgets/patient_info_row.dart';
import 'package:dentist_app/features/patients/widgets/patient_phone_display.dart';

/// 患者基本信息显示卡片组件
/// 职责：显示患者的基本信息（姓名、年龄、性别、病历号、医生、地址、身份证号、初诊日期、总费用、治疗项目）
class PatientBasicInfoCard extends StatelessWidget {
  final Patient patient;
  final ValueChanged<String>? onPhoneCall;
  final double? displayedTotalCost;
  final VoidCallback? onTotalCostTap;

  const PatientBasicInfoCard({
    super.key,
    required this.patient,
    this.onPhoneCall,
    this.displayedTotalCost,
    this.onTotalCostTap,
  });

  @override
  Widget build(BuildContext context) {
    final doctor = patient.doctor;
    final address = patient.address;
    final identificationNumber = patient.identificationNumber;
    final treatmentItems = patient.treatmentItems;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '基本信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      patient.gender == '男'
                          ? Colors.blue.withValues(alpha: 0.1)
                          : Colors.pink.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  patient.gender,
                  style: TextStyle(
                    color: patient.gender == '男' ? Colors.blue : Colors.pink,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          PatientInfoRow(
            icon: CupertinoIcons.person,
            label: '姓名',
            value: patient.name,
          ),
          const SizedBox(height: 12),
          PatientInfoRow(
            icon: CupertinoIcons.number,
            label: '年龄',
            value: '${patient.age}岁',
          ),
          const SizedBox(height: 12),
          PatientPhoneDisplay(
            phoneNumbers: parsePatientPhoneNumbers(patient.phone),
            onPhoneCall: onPhoneCall,
          ),
          const SizedBox(height: 12),
          if (patient.medicalRecordNumber != null) ...[
            PatientInfoRow(
              icon: CupertinoIcons.doc_text,
              label: '病历号',
              value: patient.medicalRecordNumber.toString(),
            ),
            const SizedBox(height: 12),
          ],
          if (doctor != null && doctor.isNotEmpty) ...[
            PatientInfoRow(
              icon: CupertinoIcons.person_2,
              label: '主治医生',
              value: doctor,
            ),
            const SizedBox(height: 12),
          ],
          if (address != null && address.isNotEmpty) ...[
            PatientInfoRow(
              icon: CupertinoIcons.location,
              label: '地址',
              value: address,
              alignTop: true,
            ),
            const SizedBox(height: 12),
          ],
          if (identificationNumber != null && identificationNumber.isNotEmpty) ...[
            PatientInfoRow(
              icon: CupertinoIcons.creditcard,
              label: '身份证号',
              value: identificationNumber,
            ),
            const SizedBox(height: 12),
          ],
          PatientInfoRow(
            icon: CupertinoIcons.calendar,
            label: '初诊日期',
            value: DateFormat('yyyy年MM月dd日').format(patient.firstVisitDate),
          ),
          const SizedBox(height: 12),
          PatientInfoRow(
            icon: CupertinoIcons.money_dollar,
            label: '已收费',
            value:
                '¥${(displayedTotalCost ?? patient.totalCost).toStringAsFixed(2)}',
            valueColor: AppTheme.accentColor,
            onTap: onTotalCostTap,
          ),
          if (treatmentItems != null && treatmentItems.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '治疗项目',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const Divider(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Text(
                treatmentItems,
                style: const TextStyle(fontSize: 14, color: AppTheme.textColor),
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

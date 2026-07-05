import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/patient.dart';

/// 患者信息展示组件
class PatientInfoDisplayWidget extends StatelessWidget {
  final Patient patient;
  final Widget Function(String label, String value) buildInfoItem;

  const PatientInfoDisplayWidget({
    Key? key,
    required this.patient,
    required this.buildInfoItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final identificationNumber = patient.identificationNumber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.tokens.primaryAccent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.tokens.primaryAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_rounded,
                size: 18,
                color: context.tokens.primaryAccent,
              ),
              const SizedBox(width: 8),
              Text(
                '患者信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 第一行：姓名、年龄、性别
          Row(
            children: [
              Expanded(
                child: buildInfoItem('姓名', patient.name),
              ),
              Expanded(
                child: buildInfoItem('年龄', '${patient.age}岁'),
              ),
              Expanded(
                child: buildInfoItem('性别', patient.gender),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 第二行：电话、病历号、首诊日期
          Row(
            children: [
              Expanded(
                child: buildInfoItem('电话', patient.displayPhone()),
              ),
              Expanded(
                child: buildInfoItem(
                    '病历号', patient.medicalRecordNumber?.toString() ?? '无'),
              ),
              Expanded(
                child: buildInfoItem('首诊',
                    DateFormat('yyyy-MM-dd').format(patient.firstVisitDate)),
              ),
            ],
          ),

          // 身份证号（如果有）
          if (identificationNumber != null) ...[
            const SizedBox(height: 12),
            buildInfoItem('身份证号', identificationNumber.toString()),
          ],
        ],
      ),
    );
  }
}

/// 病历信息展示组件
class MedicalRecordInfoDisplayWidget extends StatelessWidget {
  final TextEditingController recordNumberController;
  final DateTime recordDate;
  final String doctorName;
  final bool hasEditPermission;
  final Function(DateTime) onDateChanged;
  final Widget Function({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines,
    bool enabled,
    String? Function(String?)? validator,
  }) buildInputField;
  final Widget Function({
    required String label,
    required DateTime value,
    required Function(DateTime) onChanged,
  }) buildDateField;

  const MedicalRecordInfoDisplayWidget({
    Key? key,
    required this.recordNumberController,
    required this.recordDate,
    required this.doctorName,
    required this.hasEditPermission,
    required this.onDateChanged,
    required this.buildInputField,
    required this.buildDateField,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.medical_services_rounded,
              size: 18,
              color: context.tokens.secondaryAccent,
            ),
            const SizedBox(width: 8),
            Text(
              '病历信息',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: context.colors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 病历编号和日期
        Row(
          children: [
            Expanded(
              child: buildInputField(
                controller: recordNumberController,
                label: '病历编号',
                enabled: hasEditPermission,
                hint: '自动生成',
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入病历编号';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: buildDateField(
                label: '病历日期',
                value: recordDate,
                onChanged: onDateChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 医生信息
        buildInputField(
          controller: TextEditingController(text: doctorName),
          label: '医生',
          hint: '主治医生姓名',
          icon: Icons.medical_services_rounded,
          enabled: false,
        ),
      ],
    );
  }
}

/// 病历摘要展示组件
class RecordSummaryDisplayWidget extends StatelessWidget {
  final Patient patient;
  final String recordNumber;
  final DateTime recordDate;
  final String doctorName;
  final String chiefComplaint;
  final String diagnosis;
  final Set<String> selectedDentalConditionDates;
  final Set<String> selectedSystemicDiseases;
  final Set<String> selectedDentalDiseases;
  final Set<String> selectedAllergies;
  final Widget Function(String label, String value) buildSummaryItem;

  const RecordSummaryDisplayWidget({
    Key? key,
    required this.patient,
    required this.recordNumber,
    required this.recordDate,
    required this.doctorName,
    required this.chiefComplaint,
    required this.diagnosis,
    required this.selectedDentalConditionDates,
    required this.selectedSystemicDiseases,
    required this.selectedDentalDiseases,
    required this.selectedAllergies,
    required this.buildSummaryItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.summarize_rounded,
              size: 16,
              color: context.tokens.primaryAccent,
            ),
            const SizedBox(width: 8),
            Text(
              '病历摘要',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.tokens.primaryAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.primaryAccent.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: context.tokens.primaryAccent.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildSummaryItem('患者姓名', patient.name),
              buildSummaryItem('病历编号', recordNumber),
              buildSummaryItem(
                  '病历日期', DateFormat('yyyy年MM月dd日').format(recordDate)),
              buildSummaryItem('主治医生', doctorName),
              if (chiefComplaint.isNotEmpty)
                buildSummaryItem('主诉', chiefComplaint),
              if (diagnosis.isNotEmpty) buildSummaryItem('诊断', diagnosis),
              if (selectedDentalConditionDates.isNotEmpty)
                buildSummaryItem(
                    '关联牙齿状况', selectedDentalConditionDates.join(', ')),
              if (selectedSystemicDiseases.isNotEmpty)
                buildSummaryItem(
                    '全身疾病既往史', selectedSystemicDiseases.join(', ')),
              if (selectedDentalDiseases.isNotEmpty)
                buildSummaryItem('口腔疾病既往史', selectedDentalDiseases.join(', ')),
              if (selectedAllergies.isNotEmpty)
                buildSummaryItem('过敏史', selectedAllergies.join(', ')),
            ],
          ),
        ),
      ],
    );
  }
}

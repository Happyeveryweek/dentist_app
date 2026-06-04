import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:dentist_app/theme/app_theme.dart' hide AppCard;
import 'package:dentist_app/models/database_models.dart';
import 'package:dentist_app/widgets/app_card.dart';

class PatientInfoCard extends StatelessWidget {
  final Patient? patient;

  const PatientInfoCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    if (patient == null) {
      return const AppCard(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('无法加载患者信息')),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '患者信息',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: patient!.gender == '男'
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.pink.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  patient!.gender,
                  style: TextStyle(
                    color: patient!.gender == '男' ? Colors.blue : Colors.pink,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          _buildInfoRow(CupertinoIcons.person, '姓名', patient!.name),
          const SizedBox(height: 12),
          _buildInfoRow(CupertinoIcons.number, '年龄', '${patient!.age}岁'),
          const SizedBox(height: 12),
          _buildInfoRow(CupertinoIcons.phone, '联系电话', patient!.phone),
          if (patient!.medicalRecordNumber != null) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.doc_text,
              '病历号',
              patient!.medicalRecordNumber.toString(),
            ),
          ],
          if (patient!.doctor != null && patient!.doctor!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(CupertinoIcons.person_2, '主治医生', patient!.doctor!),
          ],
          if (patient!.address != null && patient!.address!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildInfoRow(
              CupertinoIcons.location,
              '地址',
              patient!.address!,
              alignTop: true,
            ),
          ],
          if (patient!.treatmentItems != null && patient!.treatmentItems!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '患者治疗项目',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Text(
                patient!.treatmentItems!,
                style: const TextStyle(fontSize: 14, color: AppTheme.textColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool alignTop = false,
    Color? valueColor,
  }) {
    return Row(
      crossAxisAlignment: alignTop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.secondaryTextColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.textColor,
              fontSize: 14,
              fontWeight: valueColor != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../widgets/app_card.dart';
import '../../../models/database_models.dart';
import '../../../models/financial_record.dart';

/// 患者信息卡片组件
/// 职责：显示患者基本信息卡片
class PatientInfoCard extends StatelessWidget {
  final Patient? patient;
  final FinancialRecord record;

  const PatientInfoCard({
    super.key,
    required this.patient,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    // 优先使用FinancialRecord中的patientName，如果为空再使用patient
    final displayName = record.patientName ?? patient?.name ?? '未知患者';
    
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 患者头像
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  displayName.substring(0, 1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // 患者信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '病历号: ${patient?.medicalRecordNumber ?? patient?.id ?? record.patientId}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '首诊日期: ${patient?.firstVisitDate != null ? _formatDate(patient!.firstVisitDate) : '未知'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  // 添加备注字段显示
                  if (record.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 4),
                    Text(
                      '备注: ${record.notes}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

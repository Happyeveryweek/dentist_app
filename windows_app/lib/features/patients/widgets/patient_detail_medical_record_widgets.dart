import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

import '../../../models/patient_medical_record.dart';

class PatientMedicalRecordsEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const PatientMedicalRecordsEmptyState({
    Key? key,
    required this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: tokens.primaryAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.medical_services_rounded,
              size: 64,
              color: tokens.primaryAccent.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '暂无病历记录',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '为患者创建第一份病历记录',
            style: TextStyle(
              fontSize: 14,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('新建病历'),
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.primaryAccent,
              foregroundColor: colors.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class PatientMedicalRecordsListSection extends StatelessWidget {
  final int recordCount;
  final List<Widget> recordCards;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  const PatientMedicalRecordsListSection({
    Key? key,
    required this.recordCount,
    required this.recordCards,
    required this.onRefresh,
    required this.onAdd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: tokens.cardBackground,
            boxShadow: [
              BoxShadow(
                color: tokens.shadow.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                Icons.medical_services_rounded,
                color: tokens.primaryAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                '病历记录 ($recordCount)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: tokens.infoContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: tokens.info.withValues(alpha: 0.3),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: tokens.info,
                    size: 18,
                  ),
                  tooltip: '刷新病历数据',
                  onPressed: onRefresh,
                ),
              ),
              ElevatedButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('新建病历'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.primaryAccent,
                  foregroundColor: colors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 1,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: recordCards,
          ),
        ),
      ],
    );
  }
}

class PatientMedicalRecordCard extends StatelessWidget {
  final PatientMedicalRecord record;
  final bool canEdit;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onExport;

  const PatientMedicalRecordCard({
    Key? key,
    required this.record,
    required this.canEdit,
    required this.onView,
    required this.onEdit,
    required this.onExport,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: onView,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MedicalRecordCardHeader(record: record),
              const SizedBox(height: 12),
              if (record.chiefComplaint.isNotEmpty) ...[
                _MedicalRecordSummaryBlock(
                  icon: Icons.chat_bubble_outline_rounded,
                  title: '主诉',
                  text: record.chiefComplaint,
                  color: tokens.primaryAccent,
                  backgroundColor: tokens.mutedBackground,
                  borderColor: tokens.border,
                ),
                const SizedBox(height: 8),
              ],
              if (record.diagnosis.isNotEmpty) ...[
                _MedicalRecordSummaryBlock(
                  icon: Icons.medical_information_rounded,
                  title: '诊断',
                  text: record.diagnosis,
                  color: tokens.success,
                  backgroundColor: tokens.success.withValues(alpha: 0.05),
                  borderColor: tokens.success.withValues(alpha: 0.2),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onView,
                    icon: Icon(
                      Icons.visibility_rounded,
                      size: 16,
                      color: tokens.primaryAccent,
                    ),
                    label: Text(
                      '查看详情',
                      style: TextStyle(
                        color: tokens.primaryAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (canEdit) ...[
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                      label: Text(
                        '编辑',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  TextButton.icon(
                    onPressed: onExport,
                    icon: Icon(
                      Icons.picture_as_pdf_rounded,
                      size: 16,
                      color: tokens.warning,
                    ),
                    label: Text(
                      'PDF',
                      style: TextStyle(
                        color: tokens.warning,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '创建于 ${DateFormat('MM-dd HH:mm').format(record.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MedicalRecordCardHeader extends StatelessWidget {
  final PatientMedicalRecord record;

  const _MedicalRecordCardHeader({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tokens.primaryAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.description_rounded,
            color: tokens.primaryAccent,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '病历编号: ${record.recordNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('yyyy-MM-dd').format(record.recordDate),
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (record.doctorName.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '医生: ${record.doctorName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MedicalRecordSummaryBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Color color;
  final Color backgroundColor;
  final Color borderColor;

  const _MedicalRecordSummaryBlock({
    required this.icon,
    required this.title,
    required this.text,
    required this.color,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/patient.dart';
import '../../../models/patient_medical_record.dart';
import '../../../theme/theme_context_extensions.dart';
import '../../../theme/medical_semantic_colors.dart';
import '../../../utils/dental_condition_integration.dart';
import '../../../utils/log_manager.dart';

class PatientMedicalRecordDetailDialog extends StatelessWidget {
  final Patient patient;
  final PatientMedicalRecord record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onExport;
  final bool canEdit;
  final bool canDelete;

  const PatientMedicalRecordDetailDialog({
    Key? key,
    required this.patient,
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onExport,
    this.canEdit = true,
    this.canDelete = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.96,
          maxWidth: 900,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MedicalRecordDetailHeader(record: record),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MedicalRecordBasicInfoSection(
                      patient: patient,
                      record: record,
                    ),
                    ..._buildRecordContentSections(),
                  ],
                ),
              ),
            ),
            _MedicalRecordDetailActions(
              canEdit: canEdit,
              canDelete: canDelete,
              onExport: onExport,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecordContentSections() {
    final sections = <Widget>[];

    void addSection(Widget section) {
      sections
        ..add(const SizedBox(height: 20))
        ..add(section);
    }

    if (record.chiefComplaint.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '主诉',
        icon: Icons.chat_bubble_outline,
        content: record.chiefComplaint,
      ));
    }

    if (record.presentIllness.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '现病史',
        icon: Icons.history,
        content: record.presentIllness,
      ));
    }

    if (record.pastMedicalHistory.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '全身疾病既往史',
        icon: Icons.medical_services,
        content: record.pastMedicalHistory,
      ));
    }

    if (record.pastDentalHistory.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '口腔疾病既往史',
        icon: Icons.local_hospital,
        content: record.pastDentalHistory,
      ));
    }

    if (record.allergyHistory.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '过敏史',
        icon: Icons.warning_amber,
        content: record.allergyHistory,
        isWarning: true,
      ));
    }

    if (record.oralExamination.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '口腔检查',
        icon: Icons.search,
        content: record.oralExamination,
      ));
    }

    final selectedDentalDate = record.selectedDentalConditionDate;
    if (selectedDentalDate != null && selectedDentalDate.isNotEmpty) {
      addSection(_MedicalRecordDentalConditionsSection(
        patient: patient,
        selectedDatesJson: selectedDentalDate,
      ));
    }

    if (record.diagnosis.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '诊断',
        icon: Icons.medical_information,
        content: record.diagnosis,
        isHighlight: true,
      ));
    }

    if (record.treatmentPlan.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '治疗方案',
        icon: Icons.healing,
        content: record.treatmentPlan,
      ));
    }

    if (record.notes.isNotEmpty) {
      addSection(_MedicalRecordContentSection(
        title: '注意事项',
        icon: Icons.note_alt,
        content: record.notes,
      ));
    }

    return sections;
  }
}

class _MedicalRecordDetailHeader extends StatelessWidget {
  final PatientMedicalRecord record;

  const _MedicalRecordDetailHeader({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.primaryAccent.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: tokens.primaryAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.description_rounded,
              color: tokens.primaryAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '病历详情',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '病历编号: ${record.recordNumber}',
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _MedicalRecordBasicInfoSection extends StatelessWidget {
  final Patient patient;
  final PatientMedicalRecord record;

  const _MedicalRecordBasicInfoSection({
    required this.patient,
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: tokens.primaryAccent),
              const SizedBox(width: 8),
              Text(
                '基本信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: tokens.primaryAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _PatientInfoCard(patient: patient),
          const SizedBox(height: 12),
          _MedicalRecordInfoCard(record: record),
        ],
      ),
    );
  }
}

class _PatientInfoCard extends StatelessWidget {
  final Patient patient;

  const _PatientInfoCard({
    required this.patient,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _InfoCard(
      title: '患者信息',
      backgroundColor: tokens.infoContainer,
      borderColor: tokens.info.withValues(alpha: 0.3),
      rows: [
        [
          _CompactInfoCell(label: '姓名', value: patient.name),
          _CompactInfoCell(label: '年龄', value: '${patient.age}岁'),
          _CompactInfoCell(label: '性别', value: patient.gender),
        ],
        [
          _CompactInfoCell(label: '电话', value: patient.displayPhone()),
          _CompactInfoCell(
            label: '病历号',
            value: patient.medicalRecordNumber?.toString() ?? '无',
          ),
          _CompactInfoCell(
            label: '首诊',
            value: DateFormat('yyyy-MM-dd').format(patient.firstVisitDate),
          ),
        ],
        [
          _CompactInfoCell(
            label: '身份证号',
            value: patient.identificationNumber ?? '无',
            flex: 2,
          ),
          _CompactInfoCell(
            label: '住址',
            value: patient.address ?? '无',
            flex: 2,
          ),
        ],
      ],
    );
  }
}

class _MedicalRecordInfoCard extends StatelessWidget {
  final PatientMedicalRecord record;

  const _MedicalRecordInfoCard({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return _InfoCard(
      title: '病历信息',
      backgroundColor: tokens.warningContainer,
      borderColor: tokens.warning.withValues(alpha: 0.3),
      rows: [
        [
          _CompactInfoCell(
            label: '日期',
            value: DateFormat('yyyy-MM-dd').format(record.recordDate),
          ),
          _CompactInfoCell(label: '医生', value: record.doctorName),
          _CompactInfoCell(
            label: '创建',
            value: DateFormat('MM-dd HH:mm').format(record.createdAt),
          ),
        ],
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final Color backgroundColor;
  final Color borderColor;
  final List<List<_CompactInfoCell>> rows;

  const _InfoCard({
    required this.title,
    required this.backgroundColor,
    required this.borderColor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: tokens.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            Row(children: rows[i]),
            if (i < rows.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _CompactInfoCell extends StatelessWidget {
  final String label;
  final String value;
  final int flex;

  const _CompactInfoCell({
    required this.label,
    required this.value,
    this.flex = 1,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: tokens.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: tokens.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicalRecordContentSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool isWarning;
  final bool isHighlight;

  const _MedicalRecordContentSection({
    required this.title,
    required this.icon,
    required this.content,
    this.isWarning = false,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    Color backgroundColor = tokens.mutedBackground;
    Color borderColor = tokens.border;
    Color iconColor = tokens.primaryAccent;

    if (isWarning) {
      backgroundColor = tokens.warningContainer;
      borderColor = tokens.warning.withValues(alpha: 0.3);
      iconColor = tokens.warning;
    } else if (isHighlight) {
      backgroundColor = tokens.success.withValues(alpha: 0.05);
      borderColor = tokens.success.withValues(alpha: 0.2);
      iconColor = tokens.success;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicalRecordDentalConditionsSection extends StatelessWidget {
  final Patient patient;
  final String selectedDatesJson;

  const _MedicalRecordDentalConditionsSection({
    required this.patient,
    required this.selectedDatesJson,
  });

  @override
  Widget build(BuildContext context) {
    final selectedDates = _parseSelectedDates(selectedDatesJson);
    if (selectedDates.isEmpty) {
      return const SizedBox.shrink();
    }

    final dentalData = _parseDentalData();
    final dentalWidgets = <Widget>[];

    for (int i = 0; i < selectedDates.length; i++) {
      final selectedDate = selectedDates[i];
      final dentalRecord = DentalConditionIntegration.getDentalConditionByDate(
        dentalData,
        selectedDate,
      );

      if (dentalRecord.isNotEmpty) {
        dentalWidgets.add(_DentalConditionRecordCard(
          selectedDate: selectedDate,
          dentalRecord: dentalRecord,
          index: i + 1,
        ));
      } else {
        dentalWidgets.add(_MedicalRecordContentSection(
          title: '关联牙齿状况 ${i + 1}',
          icon: Icons.grid_view,
          content: '关联日期: $selectedDate（数据不可用）',
          isWarning: true,
        ));
      }

      if (i < selectedDates.length - 1) {
        dentalWidgets.add(const SizedBox(height: 16));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: dentalWidgets,
    );
  }

  List<String> _parseSelectedDates(String selectedDatesJson) {
    try {
      final List<dynamic> dates = jsonDecode(selectedDatesJson);
      return dates.map((date) => date.toString()).toList();
    } catch (e) {
      return [selectedDatesJson];
    }
  }

  Map<String, dynamic> _parseDentalData() {
    final dentalCondition = patient.dentalCondition;
    if (dentalCondition == null || dentalCondition.isEmpty) {
      return {};
    }

    try {
      return DentalConditionIntegration.parseDentalCondition(
        dentalCondition,
      );
    } catch (e) {
      LogManager.e('PatientMedicalRecordDetailDialog', '解析牙齿状况数据失败', error: e);
      return {};
    }
  }
}

class _DentalConditionRecordCard extends StatelessWidget {
  final String selectedDate;
  final Map<String, dynamic> dentalRecord;
  final int index;

  const _DentalConditionRecordCard({
    required this.selectedDate,
    required this.dentalRecord,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DentalConditionRecordHeader(
            selectedDate: selectedDate,
            index: index,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _buildChart('图表1', 'chart1')),
                const SizedBox(width: 12),
                Expanded(child: _buildChart('图表2', 'chart2')),
                const SizedBox(width: 12),
                Expanded(child: _buildChart('图表3', 'chart3')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(String title, String prefix) {
    return _CompactCrossChart(
      title: title,
      topLeft: dentalRecord['$prefix-top-left'] ?? '',
      topRight: dentalRecord['$prefix-top-right'] ?? '',
      bottomLeft: dentalRecord['$prefix-bottom-left'] ?? '',
      bottomRight: dentalRecord['$prefix-bottom-right'] ?? '',
      note: dentalRecord['$prefix-note'] ?? '',
    );
  }
}

class _DentalConditionRecordHeader extends StatelessWidget {
  final String selectedDate;
  final int index;

  const _DentalConditionRecordHeader({
    required this.selectedDate,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.8),
            MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.grid_view, size: 20, color: colors.onPrimary),
              const SizedBox(width: 8),
              Text(
                '关联牙齿状况 $index',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.onPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '关联日期: ${DentalConditionIntegration.formatDateForDisplay(selectedDate)}',
            style: TextStyle(
              fontSize: 14,
              color: colors.onPrimary.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactCrossChart extends StatelessWidget {
  final String title;
  final String topLeft;
  final String topRight;
  final String bottomLeft;
  final String bottomRight;
  final String note;

  const _CompactCrossChart({
    required this.title,
    required this.topLeft,
    required this.topRight,
    required this.bottomLeft,
    required this.bottomRight,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MedicalSemanticColors.dentalRecordTeal,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Stack(
            children: [
              Center(
                child: Container(
                  width: double.infinity,
                  height: 1.5,
                  color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.6),
                ),
              ),
              Center(
                child: Container(
                  width: 1.5,
                  height: 40,
                  color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.6),
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _ChartQuadrantText(
                          text: topLeft,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 3, top: 12),
                          textAlign: TextAlign.right,
                        ),
                        _ChartQuadrantText(
                          text: topRight,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 3, top: 12),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        _ChartQuadrantText(
                          text: bottomLeft,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 3, bottom: 12),
                          textAlign: TextAlign.right,
                        ),
                        _ChartQuadrantText(
                          text: bottomRight,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 3, bottom: 12),
                          textAlign: TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 4),
          height: 20,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (note.isNotEmpty)
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      note,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 9,
                        color: tokens.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              Container(
                height: 1,
                width: double.infinity,
                color: MedicalSemanticColors.dentalRecordTeal.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartQuadrantText extends StatelessWidget {
  final String text;
  final Alignment alignment;
  final EdgeInsets padding;
  final TextAlign textAlign;

  const _ChartQuadrantText({
    required this.text,
    required this.alignment,
    required this.padding,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        alignment: alignment,
        padding: padding,
        child: Text(
          text,
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 10,
            color: context.tokens.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _MedicalRecordDetailActions extends StatelessWidget {
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onExport;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicalRecordDetailActions({
    required this.canEdit,
    required this.canDelete,
    required this.onExport,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onExport,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('导出PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.warning,
                foregroundColor: colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          if (canEdit) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('编辑'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.primaryAccent,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
          if (canDelete) ...[
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('删除'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.error,
                  foregroundColor: colors.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

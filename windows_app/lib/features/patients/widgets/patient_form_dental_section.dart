import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/dental_chart.dart';
import '../../../widgets/compact_dropdown_form_field.dart';
import '../models/patient_form_state.dart';

class PatientFormDentalSection extends StatelessWidget {
  final List<DentalChartRow> rows;
  final VoidCallback onAddRow;
  final ValueChanged<DentalChartRow> onSelectDate;
  final ValueChanged<DentalChartRow> onDeleteRow;
  final bool Function(DentalChartRow row) canEditRow;
  final bool Function(DentalChartRow row) canDeleteRow;
  final DentalAppointmentDraft Function(DentalChartRow row) appointmentDraftFor;
  final List<String> treatmentSuggestions;
  final ValueChanged<DentalChartRow> onToggleAppointment;
  final ValueChanged<DentalChartRow> onSelectAppointmentDate;
  final ValueChanged<DentalChartRow> onSelectAppointmentTime;
  final void Function(DentalChartRow row, String treatment) onTreatmentChanged;
  final void Function(DentalChartRow row, int chartIndex, bool selected)
      onChartSelectionChanged;

  const PatientFormDentalSection({
    Key? key,
    required this.rows,
    required this.onAddRow,
    required this.onSelectDate,
    required this.onDeleteRow,
    required this.canEditRow,
    required this.canDeleteRow,
    required this.appointmentDraftFor,
    required this.treatmentSuggestions,
    required this.onToggleAppointment,
    required this.onSelectAppointmentDate,
    required this.onSelectAppointmentTime,
    required this.onTreatmentChanged,
    required this.onChartSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.mutedBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.tokens.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.medical_services,
                    color: context.tokens.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '牙齿状况',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: context.tokens.primaryAccent,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加记录', style: TextStyle(fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.tokens.primaryAccent,
                  foregroundColor: context.colors.onPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: onAddRow,
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(),
          const SizedBox(height: 2),
          SizedBox(
            height: rows.length > 1
                ? 420
                : rows.any((row) => appointmentDraftFor(row).enabled)
                    ? 360
                    : 280,
            child: SingleChildScrollView(
              child: Column(
                children: rows
                    .map(
                      (row) => PatientFormDentalChartRow(
                        row: row,
                        rowCount: rows.length,
                        canEdit: canEditRow(row),
                        canDelete: canDeleteRow(row),
                        onSelectDate: () => onSelectDate(row),
                        onDelete: () => onDeleteRow(row),
                        appointmentDraft: appointmentDraftFor(row),
                        treatmentSuggestions: treatmentSuggestions,
                        onToggleAppointment: () => onToggleAppointment(row),
                        onSelectAppointmentDate: () =>
                            onSelectAppointmentDate(row),
                        onSelectAppointmentTime: () =>
                            onSelectAppointmentTime(row),
                        onTreatmentChanged: (value) =>
                            onTreatmentChanged(row, value),
                        onChartSelectionChanged: (chartIndex, selected) =>
                            onChartSelectionChanged(row, chartIndex, selected),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientFormDentalChartRow extends StatelessWidget {
  final DentalChartRow row;
  final int rowCount;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onSelectDate;
  final VoidCallback onDelete;
  final DentalAppointmentDraft appointmentDraft;
  final List<String> treatmentSuggestions;
  final VoidCallback onToggleAppointment;
  final VoidCallback onSelectAppointmentDate;
  final VoidCallback onSelectAppointmentTime;
  final ValueChanged<String> onTreatmentChanged;
  final void Function(int chartIndex, bool selected) onChartSelectionChanged;

  const PatientFormDentalChartRow({
    Key? key,
    required this.row,
    required this.rowCount,
    required this.canEdit,
    required this.canDelete,
    required this.onSelectDate,
    required this.onDelete,
    required this.appointmentDraft,
    required this.treatmentSuggestions,
    required this.onToggleAppointment,
    required this.onSelectAppointmentDate,
    required this.onSelectAppointmentTime,
    required this.onTreatmentChanged,
    required this.onChartSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final createdByDoctor = row.createdByDoctor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: context.tokens.cardBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canEdit
              ? context.tokens.success.withValues(alpha: 0.3)
              : context.tokens.border.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.tokens.shadow,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (createdByDoctor != null && createdByDoctor.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: canEdit
                    ? context.tokens.successContainer
                    : context.tokens.mutedBackground,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    canEdit ? Icons.edit : Icons.visibility,
                    size: 12,
                    color: canEdit
                        ? context.tokens.success
                        : context.tokens.iconMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '创建医生: $createdByDoctor',
                    style: TextStyle(
                      fontSize: 10,
                      color: canEdit
                          ? context.tokens.success
                          : context.colors.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (!canEdit)
                    Text(
                      '只读',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.colors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 110,
                margin: const EdgeInsets.only(right: 6),
                child: InkWell(
                  mouseCursor: SystemMouseCursors.click,
                  onTap: canEdit ? onSelectDate : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: canEdit
                            ? context.tokens.divider
                            : context.tokens.border,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      color: canEdit
                          ? context.tokens.cardBackground
                          : context.tokens.mutedBackground,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: canEdit
                              ? context.tokens.primaryAccent
                              : context.tokens.iconMuted,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            DateFormat('yyyy-MM-dd').format(row.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: canEdit
                                  ? context.colors.onSurface
                                  : context.tokens.iconMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (canEdit)
                          const Icon(Icons.arrow_drop_down, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: PatientFormSimpleCrossChart(
                        chart: row.chart1,
                        chartIndex: 1,
                        enabled: canEdit,
                        showAppointmentSelection: appointmentDraft.enabled,
                        appointmentSelected:
                            appointmentDraft.selectedChartIndexes.contains(1),
                        onAppointmentSelectionChanged: (selected) =>
                            onChartSelectionChanged(1, selected),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: PatientFormSimpleCrossChart(
                        chart: row.chart2,
                        chartIndex: 2,
                        enabled: canEdit,
                        showAppointmentSelection: appointmentDraft.enabled,
                        appointmentSelected:
                            appointmentDraft.selectedChartIndexes.contains(2),
                        onAppointmentSelectionChanged: (selected) =>
                            onChartSelectionChanged(2, selected),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: PatientFormSimpleCrossChart(
                        chart: row.chart3,
                        chartIndex: 3,
                        enabled: canEdit,
                        showAppointmentSelection: appointmentDraft.enabled,
                        appointmentSelected:
                            appointmentDraft.selectedChartIndexes.contains(3),
                        onAppointmentSelectionChanged: (selected) =>
                            onChartSelectionChanged(3, selected),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 116,
                child: OutlinedButton.icon(
                  onPressed: canEdit ? onToggleAppointment : null,
                  icon: Icon(
                    appointmentDraft.enabled
                        ? Icons.event_available
                        : Icons.event_outlined,
                    size: 16,
                  ),
                  label: Text(
                    appointmentDraft.enabled ? '预约：是' : '预约：否',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
              if (rowCount > 1 && canDelete)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.tokens.error,
                    size: 18,
                  ),
                  tooltip: '删除此记录',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  onPressed: onDelete,
                ),
              if (rowCount > 1 && !canDelete)
                Container(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: context.tokens.iconMuted,
                    size: 18,
                  ),
                ),
            ],
          ),
          if (appointmentDraft.enabled) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 116),
                Expanded(
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: onSelectAppointmentDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '下次预约日期',
                        isDense: true,
                        prefixIcon: Icon(Icons.calendar_today, size: 17),
                      ),
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(
                          appointmentDraft.appointmentDateTime,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 150,
                  child: InkWell(
                    mouseCursor: SystemMouseCursors.click,
                    onTap: onSelectAppointmentTime,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '时间',
                        isDense: true,
                        prefixIcon: Icon(Icons.schedule, size: 17),
                      ),
                      child: Text(
                        DateFormat('HH:mm').format(
                          appointmentDraft.appointmentDateTime,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: appointmentDraft.treatmentController,
                    decoration: InputDecoration(
                      labelText: '预约内容',
                      hintText: '可手动填写或选择已有内容',
                      isDense: true,
                      suffixIcon: CompactPopupMenuButton<String>(
                        value: null,
                        menuWidth: 220,
                        menuMaxHeight: 220,
                        items: <String>{
                          '综合治疗',
                          ...treatmentSuggestions,
                        }
                            .map(
                              (item) => CompactDropdownItem<String>(
                                value: item,
                                child: Text(
                                  item,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onSelected: (value) {
                          if (value != null) {
                            onTreatmentChanged(value);
                          }
                        },
                        childBuilder: (context, isOpen) => Icon(
                          isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class PatientFormSimpleCrossChart extends StatelessWidget {
  final DentalChart chart;
  final int chartIndex;
  final bool enabled;
  final bool showAppointmentSelection;
  final bool appointmentSelected;
  final ValueChanged<bool> onAppointmentSelectionChanged;

  const PatientFormSimpleCrossChart({
    Key? key,
    required this.chart,
    required this.chartIndex,
    required this.enabled,
    required this.showAppointmentSelection,
    required this.appointmentSelected,
    required this.onAppointmentSelectionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final crossLineColor = enabled
        ? context.tokens.primaryAccent.withValues(alpha: 0.72)
        : context.tokens.iconMuted.withValues(alpha: 0.55);
    final noteLineColor = enabled
        ? context.tokens.primaryAccent.withValues(alpha: 0.72)
        : context.tokens.iconMuted.withValues(alpha: 0.55);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 5.0),
          child: Stack(
            children: [
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 250),
                  height: 2.2,
                  decoration: BoxDecoration(
                    color: crossLineColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 2.2,
                  height: 50,
                  decoration: BoxDecoration(
                    color: crossLineColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Column(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: Row(
                          children: [
                            Expanded(
                              child: _QuadrantTextField(
                                controller: chart.topLeftController,
                                enabled: enabled,
                                textAlign: TextAlign.right,
                                contentPadding: const EdgeInsets.only(
                                  left: 0,
                                  bottom: 0,
                                  right: 4,
                                  top: 18,
                                ),
                                onChanged: (value) => chart.topLeft = value,
                              ),
                            ),
                            Expanded(
                              child: _QuadrantTextField(
                                controller: chart.topRightController,
                                enabled: enabled,
                                textAlign: TextAlign.left,
                                contentPadding: const EdgeInsets.only(
                                  left: 4,
                                  bottom: 0,
                                  right: 0,
                                  top: 18,
                                ),
                                onChanged: (value) => chart.topRight = value,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 250),
                        child: Row(
                          children: [
                            Expanded(
                              child: _QuadrantTextField(
                                controller: chart.bottomLeftController,
                                enabled: enabled,
                                textAlign: TextAlign.right,
                                contentPadding: const EdgeInsets.only(
                                  left: 0,
                                  top: 0,
                                  right: 4,
                                  bottom: 18,
                                ),
                                onChanged: (value) => chart.bottomLeft = value,
                              ),
                            ),
                            Expanded(
                              child: _QuadrantTextField(
                                controller: chart.bottomRightController,
                                enabled: enabled,
                                textAlign: TextAlign.left,
                                contentPadding: const EdgeInsets.only(
                                  left: 4,
                                  top: 0,
                                  right: 0,
                                  bottom: 18,
                                ),
                                onChanged: (value) => chart.bottomRight = value,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (showAppointmentSelection)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Tooltip(
                    message: '将此牙位十字带入预约记录',
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: appointmentSelected,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: enabled
                            ? (value) => onAppointmentSelectionChanged(
                                  value ?? false,
                                )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 0),
            height: 30,
            constraints: const BoxConstraints(maxWidth: 250),
            child: TextField(
              controller: chart.noteController,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: '',
                contentPadding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
                isDense: true,
                border: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: noteLineColor,
                    width: 2.2,
                  ),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: noteLineColor,
                    width: 2.2,
                  ),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: noteLineColor,
                    width: 2.2,
                  ),
                ),
                disabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(
                    color: noteLineColor,
                    width: 2.2,
                  ),
                ),
                fillColor: Colors.transparent,
                filled: false,
              ),
              style: TextStyle(
                fontSize: 12,
                color: enabled
                    ? context.colors.onSurface
                    : context.tokens.iconMuted,
              ),
              textAlign: TextAlign.left,
              onChanged: (value) => chart.note = value,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuadrantTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final TextAlign textAlign;
  final EdgeInsets contentPadding;
  final ValueChanged<String> onChanged;

  const _QuadrantTextField({
    Key? key,
    required this.controller,
    required this.enabled,
    required this.textAlign,
    required this.contentPadding,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        contentPadding: contentPadding,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        hintText: '',
        hintStyle: const TextStyle(fontSize: 0),
        isDense: true,
        filled: false,
      ),
      textAlign: textAlign,
      style: TextStyle(
        fontSize: 12,
        color: enabled ? context.colors.onSurface : context.tokens.iconMuted,
      ),
      cursorColor: context.tokens.primaryAccent.withValues(alpha: 0.5),
      maxLines: 1,
      onChanged: onChanged,
    );
  }
}

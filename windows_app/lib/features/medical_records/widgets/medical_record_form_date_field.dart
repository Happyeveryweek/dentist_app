import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../widgets/dental_icons.dart';
import '../../../widgets/modern_date_picker.dart';

/// 病历表单日期字段组件
class MedicalRecordFormDateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final Function(DateTime) onChanged;
  final bool enabled;

  const MedicalRecordFormDateField({
    Key? key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: DentalColors.primary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: DentalColors.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: enabled ? () async {
            final date = await showDialog<DateTime>(
              context: context,
              builder: (context) => ModernDatePickerDialog(
                initialDate: value,
                firstDate: DateTime(2000),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              ),
            );
            if (date != null) {
              onChanged(date);
            }
          } : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: DentalColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: DentalColors.divider,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('yyyy年MM月dd日').format(value),
                    style: const TextStyle(
                      fontSize: 16,
                      color: DentalColors.onSurface,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  color: DentalColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';

/// 病历摘要项组件
class MedicalRecordSummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const MedicalRecordSummaryItem({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: DentalColors.primary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: DentalColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

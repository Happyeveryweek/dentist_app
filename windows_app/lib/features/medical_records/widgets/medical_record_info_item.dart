import 'package:flutter/material.dart';
import '../../../widgets/dental_icons.dart';

/// 病历信息项组件
class MedicalRecordInfoItem extends StatelessWidget {
  final String label;
  final String value;

  const MedicalRecordInfoItem({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: DentalColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: DentalColors.onSurface,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import '../../../models/appointment_status.dart';

class AppointmentCostStatusSection extends StatelessWidget {
  final TextEditingController costController;
  final String status;
  final ValueChanged<String?> onStatusChanged;

  const AppointmentCostStatusSection({
    Key? key,
    required this.costController,
    required this.status,
    required this.onStatusChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final parsedStatus = AppointmentStatus.tryParse(status);
    final statusItems = [
      if (parsedStatus == null)
        DropdownMenuItem(
          value: status,
          enabled: false,
          child: Text(status),
        ),
      ...AppointmentStatus.values.map(
        (status) => DropdownMenuItem(
          value: status.storageValue,
          child: Text(status.displayName),
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attach_money,
                color: context.tokens.success,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '费用与状态',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: costController,
                  decoration: InputDecoration(
                    labelText: '费用估计',
                    hintText: '预估费用(可选)',
                    prefixText: '¥ ',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: context.tokens.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: context.tokens.cardBackground,
                  focusColor: Colors.transparent,
                  decoration: InputDecoration(
                    labelText: '预约状态',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: context.tokens.cardBackground,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                  key: ValueKey<String?>(status),
                  initialValue: status,
                  items: statusItems,
                  onChanged: onStatusChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

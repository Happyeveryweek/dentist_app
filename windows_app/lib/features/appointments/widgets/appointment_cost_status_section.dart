import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.attach_money,
                color: Color(0xFF4CAF50),
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                '费用与状态',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4CAF50),
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
                  items: const [
                    DropdownMenuItem(value: '已预约', child: Text('已预约')),
                    DropdownMenuItem(value: '已完成', child: Text('已完成')),
                    DropdownMenuItem(value: '已取消', child: Text('已取消')),
                    DropdownMenuItem(value: '未到诊', child: Text('未到诊')),
                  ],
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

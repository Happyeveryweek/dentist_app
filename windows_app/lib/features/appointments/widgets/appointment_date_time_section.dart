import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

class AppointmentDateTimeSection extends StatelessWidget {
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;

  const AppointmentDateTimeSection({
    Key? key,
    required this.date,
    required this.time,
    required this.onSelectDate,
    required this.onSelectTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                Icons.schedule,
                color: context.tokens.warning,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                '预约时间',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: context.tokens.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSelectDate,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.tokens.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.tokens.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: context.tokens.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: InkWell(
                  onTap: onSelectTime,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: context.tokens.cardBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.tokens.border),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time, color: context.tokens.warning),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

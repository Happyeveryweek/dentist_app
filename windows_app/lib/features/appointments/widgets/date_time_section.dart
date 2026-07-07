import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';

/// 预约时间区域
///
/// 显示日期选择框和时间选择框
class DateTimeSection extends StatelessWidget {
  final DateTime date;
  final TimeOfDay time;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;

  const DateTimeSection({
    Key? key,
    required this.date,
    required this.time,
    required this.onSelectDate,
    required this.onSelectTime,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tokens.mutedBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tokens),
          const SizedBox(height: 16),
          _buildDateTimeRow(tokens),
        ],
      ),
    );
  }

  Widget _buildHeader(AppThemeTokens tokens) {
    return Row(
      children: [
        Icon(
          Icons.schedule,
          color: tokens.primaryAccent,
          size: 18,
        ),
        const SizedBox(width: 8),
        Text(
          '预约时间',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.primaryAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow(AppThemeTokens tokens) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onSelectDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: tokens.primaryAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('yyyy-MM-dd').format(date),
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
                color: tokens.cardBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tokens.divider),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: tokens.primaryAccent),
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
    );
  }
}

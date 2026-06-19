import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildDateTimeRow(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.schedule,
          color: const Color(0xFFFF8A65),
          size: 18,
        ),
        const SizedBox(width: 8),
        const Text(
          '预约时间',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFF8A65),
          ),
        ),
      ],
    );
  }

  Widget _buildDateTimeRow() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onSelectDate,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, color: const Color(0xFFFF8A65)),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: const Color(0xFFFF8A65)),
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

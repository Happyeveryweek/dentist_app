import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'modern_date_picker.dart';

class ReusableDateRangePicker extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;
  final void Function(DateTime start, DateTime end) onConfirm;
  final String title;

  const ReusableDateRangePicker({
    Key? key,
    required this.initialStart,
    required this.initialEnd,
    required this.onConfirm,
    this.title = '选择日期范围',
  }) : super(key: key);

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTime? start,
    DateTime? end,
    String title = '选择日期范围',
  }) async {
    final now = DateTime.now();
    final DateTime s = start ?? DateTime(now.year, now.month, 1);
    final DateTime e = end ?? now;
    DateTime? pickedStart;
    DateTime? pickedEnd;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              pickedStart ??= s;
              pickedEnd ??= e;
              final selectedStart = pickedStart;
              final selectedEnd = pickedEnd;
              if (selectedStart == null || selectedEnd == null) {
                return const SizedBox.shrink();
              }

              void applyPreset(String preset) {
                final now = DateTime.now();
                DateTime start;
                DateTime end = DateTime(now.year, now.month, now.day);
                switch (preset) {
                  case 'this_month':
                    start = DateTime(now.year, now.month, 1);
                    break;
                  case 'last_month':
                    final last = DateTime(now.year, now.month - 1, 1);
                    start = last;
                    end = DateTime(last.year, last.month + 1, 0);
                    break;
                  case '30d':
                    start = now.subtract(const Duration(days: 29));
                    break;
                  case '6m':
                    start = DateTime(now.year, now.month - 5, 1);
                    end = DateTime(now.year, now.month, now.day);
                    break;
                  case 'this_year':
                    start = DateTime(now.year, 1, 1);
                    end = DateTime(now.year, now.month, now.day);
                    break;

                  default:
                    start = selectedStart;
                }
                setState(() {
                  pickedStart = start;
                  pickedEnd = end;
                });
              }

              Widget buildDateTile(
                String label,
                DateTime date, {
                required VoidCallback onTap,
              }) {
                return GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Colors.blueAccent,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$label: ${DateFormat('yyyy年MM月dd日').format(date)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PresetChip(
                          label: '本月',
                          onTap: () => applyPreset('this_month'),
                        ),
                        _PresetChip(
                          label: '上月',
                          onTap: () => applyPreset('last_month'),
                        ),
                        _PresetChip(
                          label: '30天',
                          onTap: () => applyPreset('30d'),
                        ),
                        _PresetChip(
                          label: '半年',
                          onTap: () => applyPreset('6m'),
                        ),
                        _PresetChip(
                          label: '今年',
                          onTap: () => applyPreset('this_year'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('开始日期:', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    buildDateTile(
                      '开始',
                      selectedStart,
                      onTap: () async {
                        final d = await showDialog<DateTime>(
                          context: context,
                          builder:
                              (c) => ModernDatePickerDialog(
                                initialDate: selectedStart,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                title: '选择开始日期',
                              ),
                        );
                        if (d != null) {
                          setState(() {
                            pickedStart = d;
                            if (selectedEnd.isBefore(d)) {
                              pickedEnd = d;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text('结束日期:', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    buildDateTile(
                      '结束',
                      selectedEnd,
                      onTap: () async {
                        final d = await showDialog<DateTime>(
                          context: context,
                          builder:
                              (c) => ModernDatePickerDialog(
                                initialDate: selectedEnd,
                                firstDate: selectedStart,
                                lastDate: DateTime(2100),
                                title: '选择结束日期',
                              ),
                        );
                        if (d != null) {
                          setState(() {
                            pickedEnd = d;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('确定'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (ok == true) {
      final start = pickedStart;
      final end = pickedEnd;
      if (start == null || end == null) {
        return null;
      }
      return DateTimeRange(start: start, end: end);
    }
    return null;
  }

  @override
  State<ReusableDateRangePicker> createState() =>
      _ReusableDateRangePickerState();
}

class _ReusableDateRangePickerState extends State<ReusableDateRangePicker> {
  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _PresetChip extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

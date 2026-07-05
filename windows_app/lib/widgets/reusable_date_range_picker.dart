import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
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

  static Future<DateTimeRange?> show(BuildContext context,
      {DateTime? start, DateTime? end, String title = '选择日期范围'}) async {
    final now = DateTime.now();
    final DateTime s = start ?? DateTime(now.year, now.month, 1);
    final DateTime e = end ?? now;
    DateTime pickedStart = s;
    DateTime pickedEnd = e;
    String? activePreset;

    bool hoverStart = false;
    bool hoverEnd = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: StatefulBuilder(
            builder: (context, setState) {
              void applyPreset(String preset) {
                final now = DateTime.now();
                DateTime start;
                DateTime end = DateTime(now.year, now.month, now.day);
                switch (preset) {
                  case 'today':
                    start = DateTime(now.year, now.month, now.day);
                    end = DateTime(now.year, now.month, now.day);
                    break;
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
                  case 'last_year':
                    start = DateTime(now.year - 1, 1, 1);
                    end = DateTime(now.year - 1, 12, 31);
                    break;
                  default:
                    start = pickedStart;
                }
                setState(() {
                  pickedStart = start;
                  pickedEnd = end;
                  activePreset = preset;
                });
              }

              Widget buildDateTile(String label, DateTime date,
                  {required VoidCallback onTap,
                  required bool hovering,
                  required void Function(bool) onHover}) {
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onEnter: (_) => onHover(true),
                  onExit: (_) => onHover(false),
                  child: GestureDetector(
                    onTap: onTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: hovering
                            ? context.tokens.primaryAccent.withValues(alpha: 0.06)
                            : context.tokens.inputBackground,
                        border: Border.all(
                            color: hovering
                                ? context.tokens.primaryAccent
                                : context.tokens.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18,
                              color: hovering
                                  ? context.tokens.primaryAccent
                                  : context.tokens.iconMuted),
                          const SizedBox(width: 10),
                          Text(
                              '${1}: ${DateFormat('yyyy年MM月dd日').format(date)}',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: hovering
                                      ? context.tokens.primaryAccent
                                      : context.colors.onSurface)),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return Container(
                width: 360,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w600))),
                      IconButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          icon: const Icon(Icons.close, size: 20),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints()),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _PresetChip(
                            label: '今天',
                            selected: activePreset == 'today',
                            onTap: () => applyPreset('today')),
                        _PresetChip(
                            label: '本月',
                            selected: activePreset == 'this_month',
                            onTap: () => applyPreset('this_month')),
                        _PresetChip(
                            label: '上月',
                            selected: activePreset == 'last_month',
                            onTap: () => applyPreset('last_month')),
                        _PresetChip(
                            label: '30天',
                            selected: activePreset == '30d',
                            onTap: () => applyPreset('30d')),
                        _PresetChip(
                            label: '半年',
                            selected: activePreset == '6m',
                            onTap: () => applyPreset('6m')),
                        _PresetChip(
                            label: '今年',
                            selected: activePreset == 'this_year',
                            onTap: () => applyPreset('this_year')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('开始日期:', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    buildDateTile('开始', pickedStart, hovering: hoverStart,
                        onHover: (v) {
                      setState(() {
                        hoverStart = v;
                      });
                    }, onTap: () async {
                      final d = await showDialog<DateTime>(
                        context: context,
                        builder: (c) => ModernDatePickerDialog(
                          initialDate: pickedStart,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          title: '选择开始日期',
                        ),
                      );
                      if (d != null) {
                        setState(() {
                          pickedStart = d;
                          activePreset = null;
                          if (pickedEnd.isBefore(pickedStart)) {
                            pickedEnd = pickedStart;
                          }
                        });
                      }
                    }),
                    const SizedBox(height: 10),
                    const Text('结束日期:', style: TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    buildDateTile('结束', pickedEnd, hovering: hoverEnd,
                        onHover: (v) {
                      setState(() {
                        hoverEnd = v;
                      });
                    }, onTap: () async {
                      final d = await showDialog<DateTime>(
                        context: context,
                        builder: (c) => ModernDatePickerDialog(
                          initialDate: pickedEnd,
                          firstDate: pickedStart,
                          lastDate: DateTime(2100),
                          title: '选择结束日期',
                        ),
                      );
                      if (d != null) {
                        setState(() {
                          pickedEnd = d;
                          activePreset = null;
                        });
                      }
                    }),
                    const SizedBox(height: 12),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('取消')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: context.tokens.primaryAccent,
                          foregroundColor: context.tokens.cardBackground,
                        ),
                        child: const Text('确定'),
                      ),
                    ])
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    if (ok == true) {
      return DateTimeRange(start: pickedStart, end: pickedEnd);
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
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  State<_PresetChip> createState() => _PresetChipState();
}

class _PresetChipState extends State<_PresetChip> {
  bool _hovering = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.selected
                ? context.tokens.primaryAccent
                : _hovering
                    ? context.tokens.primaryAccent.withValues(alpha: 0.08)
                    : context.tokens.inputBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.selected
                  ? context.tokens.primaryAccent
                  : _hovering
                      ? context.tokens.primaryAccent
                      : context.tokens.border,
            ),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                        color: context.tokens.primaryAccent.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2))
                  ]
                : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              color: widget.selected
                  ? context.tokens.cardBackground
                  : _hovering
                      ? context.tokens.primaryAccent
                      : context.colors.onSurface,
              fontWeight: widget.selected || _hovering
                  ? FontWeight.w600
                  : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

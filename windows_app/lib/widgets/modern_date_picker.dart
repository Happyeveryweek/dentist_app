import 'package:flutter/material.dart';
import 'package:dentist_app_windows/theme/theme_context_extensions.dart';
import 'package:intl/intl.dart';

class ModernDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final String? title;

  const ModernDatePickerDialog({
    Key? key,
    required this.initialDate,
    this.firstDate,
    this.lastDate,
    this.title,
  }) : super(key: key);

  @override
  State<ModernDatePickerDialog> createState() => _ModernDatePickerDialogState();
}

class _ModernDatePickerDialogState extends State<ModernDatePickerDialog>
    with TickerProviderStateMixin {
  late DateTime _selectedDate;
  late DateTime _currentMonth;
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  // 手动输入相关变量
  late TextEditingController _dateTextController;
  String? _dateErrorText;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth =
        DateTime(widget.initialDate.year, widget.initialDate.month, 1);

    // 初始化手动输入控制器
    _dateTextController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(widget.initialDate),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _dateTextController.dispose();
    super.dispose();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _currentMonth = DateTime(date.year, date.month, 1);
      _dateTextController.text = DateFormat('yyyy-MM-dd').format(date);
      _dateErrorText = null;
    });
  }

  // 解析文本输入的日期
  void _parseTextDate(String text) {
    if (text.isEmpty) {
      setState(() {
        _dateErrorText = '请输入日期';
      });
      return;
    }

    try {
      // 尝试多种日期格式
      DateTime? parsedDate;
      List<String> formats = [
        'yyyy-MM-dd',
        'yyyy/MM/dd',
        'yyyy.MM.dd',
        'yyyy年MM月dd日'
      ];

      for (String format in formats) {
        try {
          parsedDate = DateFormat(format).parse(text);
          break;
        } catch (e) {
          continue;
        }
      }

      if (parsedDate != null) {
        // 移除日期范围限制，允许输入任意日期
        final date = parsedDate;
        setState(() {
          _selectedDate = date;
          _currentMonth = DateTime(date.year, date.month, 1);
          _dateErrorText = null;
        });
      } else {
        setState(() {
          _dateErrorText = '日期格式不正确';
        });
      }
    } catch (e) {
      setState(() {
        _dateErrorText = '日期格式不正确';
      });
    }
  }

  // 验证日期格式
  bool _isValidDateFormat(String text) {
    if (text.isEmpty) return false;

    // 简单的日期格式验证
    RegExp dateRegex =
        RegExp(r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$|^\d{4}年\d{1,2}月\d{1,2}日$');
    return dateRegex.hasMatch(text);
  }

  List<DateTime> _getDaysInMonth() {
    final firstDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    // Flutter的weekday返回1-7（周一到周日），需要调整为周日为0
    final firstDayOfWeek = firstDayOfMonth.weekday % 7;

    List<DateTime> days = [];

    // 添加前一个月的最后几天
    for (int i = firstDayOfWeek; i > 0; i--) {
      days.add(firstDayOfMonth.subtract(Duration(days: i)));
    }

    // 添加当前月的所有天
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      days.add(DateTime(_currentMonth.year, _currentMonth.month, i));
    }

    // 添加下一个月的前几天
    final remainingDays = 42 - days.length; // 6行7列 = 42
    for (int i = 1; i <= remainingDays; i++) {
      days.add(lastDayOfMonth.add(Duration(days: i)));
    }

    return days;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final colors = Theme.of(context).colorScheme;
    final days = _getDaysInMonth();
    final monthNames = [
      '一月',
      '二月',
      '三月',
      '四月',
      '五月',
      '六月',
      '七月',
      '八月',
      '九月',
      '十月',
      '十一月',
      '十二月'
    ];
    final title = widget.title;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: tokens.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tokens.border),
              boxShadow: tokens.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  decoration: BoxDecoration(
                    color: tokens.cardBackground,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // 显示传入的 title（若有），并始终额外显示当前的 年月，方便用户知道当前查看的是哪一年哪一月
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != null) ...[
                              Text(
                                title,
                                style: TextStyle(
                                  color: colors.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                              style: TextStyle(
                                color: colors.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          onPressed: _previousMonth,
                          icon:
                              Icon(Icons.chevron_left, color: colors.onSurface),
                          tooltip: '上个月',
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: IconButton(
                          onPressed: _nextMonth,
                          icon: Icon(Icons.chevron_right,
                              color: colors.onSurface),
                          tooltip: '下个月',
                        ),
                      ),
                    ],
                  ),
                ),

                // 手动输入日期区域
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      TextField(
                        controller: _dateTextController,
                        decoration: InputDecoration(
                          labelText: '手动输入日期',
                          hintText: '格式：2024-01-01 或 2024年1月1日',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          suffixIcon: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              onPressed: () =>
                                  _parseTextDate(_dateTextController.text),
                              icon: const Icon(Icons.check_circle),
                              tooltip: '确认日期',
                            ),
                          ),
                          errorText: _dateErrorText,
                        ),
                        onSubmitted: _parseTextDate,
                        onChanged: (value) {
                          if (_isValidDateFormat(value)) {
                            setState(() {
                              _dateErrorText = null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // 星期标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: ['日', '一', '二', '三', '四', '五', '六']
                        .map((day) => Expanded(
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  day,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),

                // 日历网格
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Material(
                    color: Colors.transparent,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final date = days[index];
                        final isCurrentMonth =
                            date.month == _currentMonth.month;
                        final isSelected = date.year == _selectedDate.year &&
                            date.month == _selectedDate.month &&
                            date.day == _selectedDate.day;
                        final isToday = date.year == DateTime.now().year &&
                            date.month == DateTime.now().month &&
                            date.day == DateTime.now().day;

                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            mouseCursor: SystemMouseCursors.click,
                            onTap: () => _selectDate(date),
                            borderRadius: BorderRadius.circular(8),
                            hoverColor: tokens.hoverBackground,
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? tokens.primaryAccent
                                    : isToday
                                        ? tokens.warningContainer
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isToday
                                    ? Border.all(
                                        color: tokens.warning, width: 2)
                                    : Border.all(color: tokens.border),
                              ),
                              child: Center(
                                child: Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? colors.onPrimary
                                        : isCurrentMonth
                                            ? colors.onSurface
                                            : tokens.disabledText,
                                    fontWeight: isSelected || isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                // 当前选择的日期显示
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tokens.infoContainer,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: tokens.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, color: tokens.info),
                      const SizedBox(width: 8),
                      Text(
                        '已选择：${DateFormat('yyyy年MM月dd日').format(_selectedDate)}',
                        style: TextStyle(
                          color: tokens.info,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // 按钮区域
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '取消',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: ElevatedButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_selectedDate),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tokens.primaryAccent,
                              foregroundColor: colors.onPrimary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              '确定',
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

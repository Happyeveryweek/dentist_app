import 'package:flutter/material.dart';
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
  bool _isValidDate = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _currentMonth = DateTime(widget.initialDate.year, widget.initialDate.month, 1);
    
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
      _isValidDate = true;
    });
  }

  // 解析文本输入的日期
  void _parseTextDate(String text) {
    if (text.isEmpty) {
      setState(() {
        _dateErrorText = '请输入日期';
        _isValidDate = false;
      });
      return;
    }

    try {
      // 尝试多种日期格式
      DateTime? parsedDate;
      List<String> formats = ['yyyy-MM-dd', 'yyyy/MM/dd', 'yyyy.MM.dd', 'yyyy年MM月dd日'];
      
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
        setState(() {
          _selectedDate = parsedDate!;
          _currentMonth = DateTime(parsedDate!.year, parsedDate!.month, 1);
          _dateErrorText = null;
          _isValidDate = true;
        });
      } else {
        setState(() {
          _dateErrorText = '日期格式不正确';
          _isValidDate = false;
        });
      }
    } catch (e) {
      setState(() {
        _dateErrorText = '日期格式不正确';
        _isValidDate = false;
      });
    }
  }

  // 验证日期格式
  bool _isValidDateFormat(String text) {
    if (text.isEmpty) return false;
    
    // 简单的日期格式验证
    RegExp dateRegex = RegExp(r'^\d{4}[-/.]\d{1,2}[-/.]\d{1,2}$|^\d{4}年\d{1,2}月\d{1,2}日$');
    return dateRegex.hasMatch(text);
  }

  List<DateTime> _getDaysInMonth() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
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
    final days = _getDaysInMonth();
    final monthNames = [
      '一月', '二月', '三月', '四月', '五月', '六月',
      '七月', '八月', '九月', '十月', '十一月', '十二月'
    ];
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.06)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 标题栏
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.title != null) ...[
                              Text(
                                widget.title!,
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            Text(
                              '${monthNames[_currentMonth.month - 1]} ${_currentMonth.year}',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _selectDate(DateTime.now()),
                        icon: Icon(Icons.today_outlined, color: Colors.blue.shade600, size: 18),
                        label: const Text('今天'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      IconButton(
                        onPressed: _previousMonth,
                        icon: const Icon(Icons.chevron_left, color: Colors.black87),
                        tooltip: '上个月',
                      ),
                      IconButton(
                        onPressed: _nextMonth,
                        icon: const Icon(Icons.chevron_right, color: Colors.black87),
                        tooltip: '下个月',
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
                          suffixIcon: IconButton(
                            onPressed: () => _parseTextDate(_dateTextController.text),
                            icon: const Icon(Icons.check_circle),
                            tooltip: '确认日期',
                          ),
                          errorText: _dateErrorText,
                        ),
                        onSubmitted: _parseTextDate,
                        onChanged: (value) {
                          if (_isValidDateFormat(value)) {
                            setState(() {
                              _dateErrorText = null;
                              _isValidDate = true;
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
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(
                                  day,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
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
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final date = days[index];
                      final isCurrentMonth = date.month == _currentMonth.month;
                      final isSelected = date.year == _selectedDate.year &&
                          date.month == _selectedDate.month &&
                          date.day == _selectedDate.day;
                      final isToday = date.year == DateTime.now().year &&
                          date.month == DateTime.now().month &&
                          date.day == DateTime.now().day;

                      return GestureDetector(
                        onTap: () => _selectDate(date),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue.shade400
                                : isToday
                                    ? Colors.orange.shade100
                                    : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(color: Colors.orange.shade300, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : isCurrentMonth
                                        ? Colors.black87
                                        : Colors.grey.shade400,
                                fontWeight: isSelected || isToday
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                
                // 当前选择的日期显示
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '已选择：${DateFormat('yyyy年MM月dd日').format(_selectedDate)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
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
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '取消',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(_selectedDate),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '确定',
                            style: TextStyle(fontSize: 16),
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
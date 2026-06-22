import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

// 十字画笔
class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5;

    // 绘制水平线 - 占据整个宽度
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // 绘制垂直线 - 高度约为三个字符高度
    double verticalHeight = 40; // 调整为合适的高度
    double startY = size.height / 2 - verticalHeight / 2;
    double endY = size.height / 2 + verticalHeight / 2;

    canvas.drawLine(
      Offset(size.width / 2, startY),
      Offset(size.width / 2, endY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// 现代化时间选择器对话框
class ModernTimePickerDialog extends StatefulWidget {
  final TimeOfDay initialTime;
  final Function(TimeOfDay) onTimeSelected;

  const ModernTimePickerDialog({
    required this.initialTime,
    required this.onTimeSelected,
  });

  @override
  State<ModernTimePickerDialog> createState() => ModernTimePickerDialogState();
}

class ModernTimePickerDialogState extends State<ModernTimePickerDialog> {
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 360,
        height: 460,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor,
                    AppTheme.primaryColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      '选择时间',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            
            // 时间显示区域
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeSelector(
                    items: List.generate(24, (index) => index),
                    selectedValue: _selectedHour,
                    onChanged: (value) {
                      setState(() {
                        _selectedHour = value;
                      });
                    },
                    label: '时',
                    color: Colors.blue,
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: const Text(
                      ':',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.grey),
                    ),
                  ),
                  _buildTimeSelector(
                    items: [0, 15, 30, 45],
                    selectedValue: _selectedMinute,
                    onChanged: (value) {
                      setState(() {
                        _selectedMinute = value;
                      });
                    },
                    label: '分',
                    color: Colors.green,
                  ),
                ],
              ),
            ),
            // 快捷时间按钮（两行：上午/下午）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('快捷选择', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('上午', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildHourQuickChip(7),
                            _buildHourQuickChip(8),
                            _buildHourQuickChip(9),
                            _buildHourQuickChip(10),
                            _buildHourQuickChip(11),
                            _buildHourQuickChip(12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text('下午', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            _buildHourQuickChip(13),
                            _buildHourQuickChip(15),
                            _buildHourQuickChip(16),
                            _buildHourQuickChip(17),
                            _buildHourQuickChip(18),
                            _buildHourQuickChip(19),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // 底部按钮
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '取消',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onTimeSelected(
                          TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '确定',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildTimeSelector({
    required List<int> items,
    required int selectedValue,
    required Function(int) onChanged,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        // 时间选择器
        Container(
          height: 96,
          width: 64,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final value = items[index];
              final isSelected = value == selectedValue;
              
              return StatefulBuilder(
                builder: (context, setLocal) {
                  bool hovering = false;
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setLocal(() => hovering = true),
                    onExit: (_) => setLocal(() => hovering = false),
                    child: GestureDetector(
                      onTap: () => onChanged(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: hovering && !isSelected ? Colors.grey.shade100 : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          value.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: isSelected ? 24 : 18,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? color
                                : (hovering ? AppTheme.primaryColor : Colors.grey.shade600),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        // 标签
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildHourQuickChip(int hour) {
    final isSelected = _selectedHour == hour && _selectedMinute == 0;
    bool hovering = false;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setLocal(() => hovering = true),
          onExit: (_) => setLocal(() => hovering = false),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedHour = hour;
                _selectedMinute = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (hovering ? Colors.grey.shade200 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade300),
                ),
              ),
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade800),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickTimeButton(String label, String time, int hour, int minute) {
    final isSelected = _selectedHour == hour && _selectedMinute == minute;
    
    bool hovering = false;
    return StatefulBuilder(
      builder: (context, setLocal) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setLocal(() => hovering = true),
          onExit: (_) => setLocal(() => hovering = false),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedHour = hour;
                _selectedMinute = minute;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : (hovering ? Colors.grey.shade200 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade300),
                ),
                boxShadow: hovering && !isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryColor.withOpacity(0.15),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ]
                    : null,
              ),
              child: Text(
                '$label\n$time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Colors.white
                      : (hovering ? AppTheme.primaryColor : Colors.grey.shade700),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

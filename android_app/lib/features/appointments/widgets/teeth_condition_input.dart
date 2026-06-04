import 'package:flutter/material.dart';
import 'package:dentist_app/widgets/stateful_text_field.dart';

class TeethConditionInput extends StatefulWidget {
  final List<Map<String, String>> teethData;
  final Function(List<Map<String, String>>) onChanged;

  const TeethConditionInput({
    required this.teethData,
    required this.onChanged,
  });

  @override
  State<TeethConditionInput> createState() => TeethConditionInputState();
}

class TeethConditionInputState extends State<TeethConditionInput> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '从医生视角看患者',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: '显示的是患者的实际牙位（右上、左上、右下、左下）',
              child: Icon(
                Icons.info_outline,
                size: 14,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildTeethCrossInput(0)),
            const SizedBox(width: 12),
            Expanded(child: _buildTeethCrossInput(1)),
          ],
        ),
      ],
    );
  }

  Widget _buildTeethCrossInput(int crossIndex) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '牙位 ${crossIndex + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;
                final centerX = width / 2;
                final centerY = height / 2;
                
                return CustomPaint(
                  painter: _TeethCrossPainter(),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2, bottom: 1),
                            child: _buildTeethInput(crossIndex, 'topLeft', TextAlign.right),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2, bottom: 1),
                            child: _buildTeethInput(crossIndex, 'topRight', TextAlign.left),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 2, top: 1),
                            child: _buildTeethInput(crossIndex, 'bottomLeft', TextAlign.right),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        width: centerX - 2,
                        height: centerY - 2,
                        child: Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2, top: 1),
                            child: _buildTeethInput(crossIndex, 'bottomRight', TextAlign.left),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeethInput(int crossIndex, String position, TextAlign textAlign) {
    final value = widget.teethData[crossIndex][position] ?? '';
    return StatefulTextField(
      initialValue: value,
      onChanged: (newValue) {
        setState(() {
          widget.teethData[crossIndex][position] = newValue;
          widget.onChanged(widget.teethData);
        });
      },
      textAlign: textAlign,
      style: const TextStyle(fontSize: 11),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        contentPadding: EdgeInsets.all(2),
        isDense: true,
        filled: false,
      ),
      maxLines: 1,
    );
  }
}

class _TeethCrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade600
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );

    final verticalLineLength = size.width / 2;
    final verticalStartY = centerY - verticalLineLength / 2;
    final verticalEndY = centerY + verticalLineLength / 2;
    
    canvas.drawLine(
      Offset(centerX, verticalStartY),
      Offset(centerX, verticalEndY),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

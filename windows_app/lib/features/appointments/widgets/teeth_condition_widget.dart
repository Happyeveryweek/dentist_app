import 'package:flutter/material.dart';

class TeethConditionWidget extends StatefulWidget {
  final List<Map<String, String>> teethData;
  final ValueChanged<List<Map<String, String>>> onChanged;

  const TeethConditionWidget({
    Key? key,
    required this.teethData,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<TeethConditionWidget> createState() => _TeethConditionWidgetState();
}

class _TeethConditionWidgetState extends State<TeethConditionWidget> {
  late List<Map<String, String>> _localTeethData;

  @override
  void initState() {
    super.initState();
    _localTeethData = widget.teethData.map((item) => Map<String, String>.from(item)).toList();
  }

  void _updateTeethData(int crossIndex, String quadrant, String value) {
    setState(() {
      _localTeethData[crossIndex][quadrant] = value;
      widget.onChanged(_localTeethData);
    });
  }

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
          Row(
            children: [
              Icon(
                Icons.medical_services,
                color: const Color(0xFF2196F3),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                '牙齿情况',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(child: _buildCrossWidget(0)),
              const SizedBox(width: 4),
              Expanded(child: _buildCrossWidget(1)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCrossWidget(int crossIndex) {
    return Container(
      width: 140,
      height: 100,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '牙位 ${crossIndex + 1}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF2196F3),
              ),
            ),
          ),
          Expanded(child: _buildCross(crossIndex)),
        ],
      ),
    );
  }

  Widget _buildCross(int crossIndex) {
    final double width = 120.0;
    final double height = 65.0;
    final double centerX = width / 2;
    final double centerY = height / 2;

    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: Size(width, height),
          painter: CrossPainter(),
        ),
        Positioned(
          top: centerY - 20,
          left: 10,
          width: centerX - 12,
          height: 18,
          child: TextField(
            textAlign: TextAlign.right,
            textAlignVertical: TextAlignVertical.center,
            cursorHeight: 14,
            cursorWidth: 1.5,
            decoration: const InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.only(right: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
            ),
            style: const TextStyle(fontSize: 12),
            controller: TextEditingController(text: _localTeethData[crossIndex]['topLeft']),
            onChanged: (value) => _updateTeethData(crossIndex, 'topLeft', value),
          ),
        ),
        Positioned(
          top: centerY - 20,
          right: 10,
          width: centerX - 12,
          height: 18,
          child: TextField(
            textAlign: TextAlign.left,
            textAlignVertical: TextAlignVertical.center,
            cursorHeight: 14,
            cursorWidth: 1.5,
            decoration: const InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.only(left: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
            ),
            style: const TextStyle(fontSize: 12),
            controller: TextEditingController(text: _localTeethData[crossIndex]['topRight']),
            onChanged: (value) => _updateTeethData(crossIndex, 'topRight', value),
          ),
        ),
        Positioned(
          top: centerY + 3,
          left: 10,
          width: centerX - 12,
          height: 18,
          child: TextField(
            textAlign: TextAlign.right,
            textAlignVertical: TextAlignVertical.center,
            cursorHeight: 14,
            cursorWidth: 1.5,
            decoration: const InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.only(right: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
            ),
            style: const TextStyle(fontSize: 12),
            controller: TextEditingController(text: _localTeethData[crossIndex]['bottomLeft']),
            onChanged: (value) => _updateTeethData(crossIndex, 'bottomLeft', value),
          ),
        ),
        Positioned(
          top: centerY + 3,
          right: 10,
          width: centerX - 12,
          height: 18,
          child: TextField(
            textAlign: TextAlign.left,
            textAlignVertical: TextAlignVertical.center,
            cursorHeight: 14,
            cursorWidth: 1.5,
            decoration: const InputDecoration(
              isCollapsed: true,
              contentPadding: EdgeInsets.only(left: 4),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              filled: true,
              fillColor: Colors.transparent,
            ),
            style: const TextStyle(fontSize: 12),
            controller: TextEditingController(text: _localTeethData[crossIndex]['bottomRight']),
            onChanged: (value) => _updateTeethData(crossIndex, 'bottomRight', value),
          ),
        ),
      ],
    );
  }
}

class CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    double verticalHeight = 40;
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
